#!/usr/bin/env python3
"""
原稿(docs/slides/lessonN.md)と Google スライドのデッキを突き合わせる

【なぜ必要か】
原稿を直してデッキに反映し忘れると、両者が静かにズレる。
2026-09-18 に第1回 p72 で発覚した。2026-09-11 の「ハンズオンを gcloud 化」で
tfstate バケットを Terraform の管理外にしたのに、ブロックの説明スライドだけ
「そのバケットを Terraform で作る例」が残っていた。

【使い方】
  # 全10回
  python3 check-slide-sync.py --profile=<Google認証プロファイル名>

  # 特定の回だけ
  python3 check-slide-sync.py --profile=<プロファイル名> 4 7

【出力の読み方】
  ★★要確認  類似度 < 0.85  … 本当に古い可能性が高い。中身を見る
  △軽微      < 0.97         … 字下げ・言い回しの差が多い
  ・ほぼ同じ  それ以上        … 改行位置だけの差

【誤検出することが分かっているもの】
  - 図版化したスライド: 本文が図(テキストボックス群)に移っているため、
    BODY には残りだけが入る。第2回 p7/p8、第1回 p42/p48/p58 など。
    objectId が `g<長い16進>_*` の形なら図版由来を疑う
  - タイトルが重複する回: 同名スライドが2枚あると先に見つかった方に
    引き当ててしまう。第3回の「アクセス確認」は S34(HTTP)と S45(HTTPS)の2枚
  - 事前配布用のスキップスライド: 第1回 S22〜S39 はデッキ側で凝縮されていて
    原稿の S番号と対応しない

**差分の中身を見ないと判断できない。** 第1回では27枚が「不一致」と出たが、
実際に古かったのは3枚だった。
"""
import sys, io, re, unicodedata, difflib, argparse, os

LIB = os.path.expanduser(
    "~/.claude/plugins/cache/shiiman-claude-code-plugins/shiiman-google/3.4.2/lib")
sys.path.insert(0, LIB)
try:
    from google_utils import load_credentials, get_token_path
    from googleapiclient.discovery import build
except ImportError:
    sys.exit(f"shiiman-google プラグインの lib が見つかりません: {LIB}\n"
             "バージョンが上がっている場合はこのパスを直してください。")

SCOPES = ["https://www.googleapis.com/auth/presentations",
          "https://www.googleapis.com/auth/drive"]

# デッキのURLは docs/slides/README.md の表と同じもの
DECKS = {
    1: "1LGC9jpgPpKj1ObDw7JFDw1x_OG3sMO_ZdxkUQ4mqU6k",
    2: "1p0NGtqsvkGYxFewE8AjoPYqh8kgkvTjyVEjLA6Fmkvs",
    3: "1cxkYA6EAxoyUp-iMQILfCvJ_CjR8SuccNb7cRbhMc0s",
    4: "1Cn3LTns2BdgXLAwhyPbr-LbEZU1Je_4m3NZLSRkLufM",
    5: "1ow1DPEjkCakiMKhQ-TknYS3u_9yezEQYnRvaovz_sqs",
    6: "1kuYTeNuWkzd8-_Mj1u2RNBKO4-xh8ycWsvlxO0hbXYo",
    7: "1gRqC2I-lme3uUlA2DX2L3aRYAkpB0DQokDFzI2yKI3I",
    8: "1T5uKWZNngdzsw9JepsK4pJiwgir7dz3mwUgFueaoiDc",
    9: "18HRSIFBcPvDAH5Gg19AFevZtYdSj1R2hUVhX-U0vzLg",
    10: "1P4OApYaqHR4UPyu6Se5YiW0lZAORxva7wqCikm1-C_E",
}

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "slides")


def text_of(shape):
    t = shape.get("text") or {}
    return "".join(e.get("textRun", {}).get("content", "")
                   for e in t.get("textElements", []))


def unmask(t):
    """プレースホルダと実値の差を吸収する。デッキには実値が入るページがある"""
    t = unicodedata.normalize("NFKC", t)
    t = re.sub(r"\[プロジェクトID\]|infra-common-\d+", "PID", t)
    t = re.sub(r"\[自分の名前\]|\[講師のアカウント\]|yamada[-_]taro|shiiman", "NAME", t)
    t = re.sub(r"\[勉強会のドメイン\]|\[ドメイン\]", "DOM", t)
    t = re.sub(r"\[org\]|\[アプリ用リポジトリ\]|\[提出用リポジトリ\]|\[接続名\]", "REPO", t)
    return t


def squash(t):
    """改行・空白・箇条書き記号を落として比較する。折り返しの差を無害にする"""
    t = unmask(t)
    t = re.sub(r"^\s*[-・*◼■★→]+\s*", "", t, flags=re.M)
    return re.sub(r"[-・*◼■★→\s]+", "", t)


def visible_lines(t):
    return [l.rstrip() for l in unmask(t).split("\n") if l.strip()]


def script_blocks(path):
    """原稿から (S番号, タイトル, 本文フェンス) を取り出す"""
    md = io.open(path, encoding="utf-8").read()
    out = []
    for m in re.finditer(r"^### (S\d+) \| (.+?)$", md, re.M):
        sn, title = m.group(1), m.group(2)
        nx = md.find("\n### ", m.end())
        seg = md[m.end(): nx if nx > 0 else len(md)]
        if "**[本文]**" not in seg:
            continue
        j = seg.index("**[本文]**")
        k = seg.find("```", j)
        if k < 0:
            continue
        k = seg.index("\n", k) + 1
        e = seg.find("\n```", k)
        if e < 0:
            continue
        out.append((sn, re.sub(r"\s*★.*$", "", title).strip(), seg[k:e]))
    return out


def deck_pages(svc, pid):
    pres = svc.presentations().get(presentationId=pid).execute()
    pages = {}
    for i, sl in enumerate(pres["slides"], 1):
        ti = bo = oid = ""
        for el in sl.get("pageElements", []):
            sh = el.get("shape")
            if not sh:
                continue
            p = sh.get("placeholder", {}).get("type")
            if p == "TITLE":
                ti = text_of(sh).strip()
            elif p == "BODY":
                bo, oid = text_of(sh), el["objectId"]
        pages[i] = (ti, bo, oid)
    return pages


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("lessons", nargs="*", type=int, help="回番号(省略時は全10回)")
    ap.add_argument("--profile", required=True, help="Google認証プロファイル名")
    ap.add_argument("--show", type=int, default=8, help="1枚あたり表示する差分行数")
    a = ap.parse_args()

    tp = get_token_path(a.profile)
    if not tp:
        sys.exit(f"認証プロファイルが見つかりません: {a.profile}")
    svc = build("slides", "v1", credentials=load_credentials(tp, SCOPES))

    total = 0
    for n in (a.lessons or sorted(DECKS)):
        if n not in DECKS:
            print(f"第{n}回のデッキIDが未登録です"); continue
        blocks = script_blocks(os.path.join(SRC, f"lesson{n}.md"))
        pages = deck_pages(svc, DECKS[n])
        diffs, nomatch, nobody = [], 0, 0
        for sn, title, body in blocks:
            hits = [p for p, (ti, _, _) in pages.items()
                    if ti and squash(ti) == squash(title)]
            if not hits:
                nomatch += 1; continue
            p = hits[0]
            _, dbody, doid = pages[p]
            if not dbody.strip():
                nobody += 1; continue
            if squash(body) == squash(dbody):
                continue
            ratio = difflib.SequenceMatcher(None, squash(body), squash(dbody)).ratio()
            diffs.append((ratio, sn, title, p, doid, body, dbody))

        print(f"\n{'=' * 72}")
        print(f"第{n}回  原稿{len(blocks)}枚 / デッキ{len(pages)}枚  → 差分{len(diffs)}枚"
              f"  (タイトル不一致 {nomatch} / BODY無し(図版) {nobody})")
        diffs.sort()
        for ratio, sn, title, p, doid, body, dbody in diffs:
            mark = "★★要確認" if ratio < 0.85 else ("△軽微" if ratio < 0.97 else "・ほぼ同じ")
            if ratio < 0.85:
                total += 1
            d = [l for l in difflib.unified_diff(visible_lines(body), visible_lines(dbody),
                                                 lineterm="", n=0)
                 if l[:1] in "+-" and l[:3] not in ("+++", "---")]
            print(f"\n  {mark} {sn} / p{p} 「{title}」 類似度{ratio:.2f} ({doid}) 差分{len(d)}行")
            for l in d[:a.show]:
                tag = "原稿のみ" if l.startswith("-") else "デッキのみ"
                print(f"      [{tag}] {l[1:][:76]}")
            if len(d) > a.show:
                print(f"      ... 他 {len(d) - a.show} 行")

    print(f"\n{'=' * 72}\n★★要確認 の合計: {total}枚")
    print("誤検出しやすいものはこのファイル冒頭のコメントを参照。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
