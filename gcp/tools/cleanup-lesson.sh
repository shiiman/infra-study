#!/usr/bin/env bash
#
# 受講者の残骸を講師がまとめて destroy するスクリプト
#
# 【なぜ必要か】
# 第5回以降は Cloud Run の Direct VPC egress がサブネット内にIPを確保し、
# 解放に1〜2時間かかる。そのため片付けが
#   「講義中に destroy → 翌朝もう1回 destroy」
# の2段構えになるが、**翌朝の1回をやらない人が必ず出る。**
# 残骸が残ると次回の `0. before` が同名リソースの衝突で落ち、冒頭で全員が止まる。
#
# そこで**受講者は講義中の1回だけ**にして、残りは講師がこれでまとめて消す。
#
# 【仕組み】
# 受講者の tfstate は GCS にあり、置き場所が命名規則で決まっている。
#   バケット: <プロジェクトID>-tfstate-<受講者名>
#   prefix  : lesson<N>
# つまり受講者名が分かれば、講師は各人の state に到達できる。
# リポジトリ内の「その回の最終スナップショット」を config として使い、
# backend だけ受講者のバケットに向けて destroy する。
#
# state を正しく使うので、実体と state がズレない。
# (state を無視して gcloud で消すと、次回の apply がもっと厄介な形で失敗する)
#
# 【使い方】
#   # まず必ず dry-run(既定)。何が消えるかを見る
#   ./cleanup-lesson.sh 8 --names-file=members.txt \
#       --project=<プロジェクトID> --var-file=cleanup.tfvars
#
#   # 中身を確認したうえで実行する
#   ./cleanup-lesson.sh 8 --names-file=members.txt \
#       --project=<プロジェクトID> --var-file=cleanup.tfvars --apply
#
# --var-file には全員共通の値を書いておく(cleanup.tfvars.example を参照)。
# user_name は名簿から1人ずつ上書きするので書かなくてよい。
#
# 終了コード: 0 = 全員成功 / 1 = 失敗した人がいる / 2 = 使い方が違う

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LESSON=""
NAMES=()
PROJECT=""
VAR_FILE=""
APPLY=0

# 各回の「最終スナップショット」= 一番進んだ宿題のディレクトリ。
# config が state のスーパーセットであれば destroy は通るので、
# 宿題をどこまでやった受講者でもこれ1つで消せる。
snapshot_dir() {
  case "$1" in
    1) echo "lesson1/syukudai2" ;;
    2) echo "lesson2/syukudai2" ;;
    3) echo "lesson3/syukudai3" ;;
    4) echo "lesson4/syukudai2" ;;
    5) echo "lesson5/syukudai1" ;;
    6) echo "lesson6/syukudai3" ;;
    7) echo "lesson7/syukudai3" ;;
    8) echo "lesson8/syukudai3" ;;
    *) return 1 ;;
  esac
}

for arg in "$@"; do
  case "$arg" in
    --project=*)    PROJECT="${arg#--project=}" ;;
    --var-file=*)   VAR_FILE="${arg#--var-file=}" ;;
    --apply)        APPLY=1 ;;
    --names-file=*)
      f="${arg#--names-file=}"
      if [[ ! -f "$f" ]]; then
        echo "名簿ファイルが見つかりません: $f" >&2
        exit 2
      fi
      while read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | tr -d '[:space:]')"
        [[ -n "$line" ]] && NAMES+=("$line")
      done < "$f"
      ;;
    -h|--help)
      sed -n '3,45p' "$0" | sed 's/^# \{0,1\}//'
      exit 2
      ;;
    -*)
      echo "不明なオプション: $arg" >&2
      exit 2
      ;;
    *)
      if [[ -z "$LESSON" ]]; then LESSON="$arg"; else NAMES+=("$arg"); fi
      ;;
  esac
done

if [[ -z "$LESSON" || ${#NAMES[@]} -eq 0 || -z "$PROJECT" ]]; then
  echo "使い方: $0 <回番号> --names-file=<名簿> --project=<プロジェクトID> [--var-file=<tfvars>] [--apply]" >&2
  exit 2
fi

SNAPSHOT="$(snapshot_dir "$LESSON")" || {
  echo "回番号は 1〜8 を指定してください(第9回はハンズオン無し、第10回は試験用)" >&2
  exit 2
}

SRC="$REPO_ROOT/$SNAPSHOT"
if [[ ! -d "$SRC" ]]; then
  echo "スナップショットが見つかりません: $SRC" >&2
  exit 2
fi

if [[ -n "$VAR_FILE" && ! -f "$VAR_FILE" ]]; then
  echo "変数ファイルが見つかりません: $VAR_FILE" >&2
  exit 2
fi
[[ -n "$VAR_FILE" ]] && VAR_FILE="$(cd "$(dirname "$VAR_FILE")" && pwd)/$(basename "$VAR_FILE")"

command -v terraform >/dev/null || { echo "terraform が見つかりません" >&2; exit 2; }

if [[ $APPLY -eq 1 ]]; then
  MODE="本当に削除します"
else
  MODE="dry-run(何も削除しません)"
fi

cat <<EOS
=== 第${LESSON}回の残骸をまとめて片付ける ===
  使う config : $SNAPSHOT
  プロジェクト: $PROJECT
  対象        : ${#NAMES[@]}人 (${NAMES[*]})
  モード      : $MODE

EOS

if [[ $APPLY -eq 1 ]]; then
  read -r -p "本当に削除しますか? 'yes' と入力してください: " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "中止しました。"
    exit 2
  fi
  echo
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

OK=()
NG=()
SKIP=()

for NAME in "${NAMES[@]}"; do
  BUCKET="${PROJECT}-tfstate-${NAME}"
  echo "────────────────────────────────────────"
  echo "▼ $NAME  (gs://$BUCKET, prefix=lesson${LESSON})"

  # state が無い人は飛ばす。片付け済みか、そもそも参加していない
  if ! gsutil -q stat "gs://${BUCKET}/lesson${LESSON}/default.tfstate" 2>/dev/null; then
    echo "  state がありません → スキップ(片付け済みか未参加)"
    SKIP+=("$NAME")
    continue
  fi

  DIR="$WORK/$NAME"
  mkdir -p "$DIR"
  cp "$SRC"/*.tf "$DIR"/ 2>/dev/null

  # backend のバケット名を受講者のものに差し替える。
  # 教材の common.tf には [プロジェクトID]-tfstate-[自分の名前] という
  # プレースホルダが入っているので、そこを置換する
  perl -0pi -e "s{bucket\s*=\s*\"[^\"]*\"}{bucket = \"${BUCKET}\"}" "$DIR/common.tf"

  # cd は使わない。ユーザーの shell 設定が cd に反応して余計な出力を混ぜることがある
  if ! terraform -chdir="$DIR" init -reconfigure -input=false > "$DIR/init.log" 2>&1; then
    echo "  ✗ terraform init に失敗しました"
    tail -20 "$DIR/init.log" | sed 's/^/      /'
    NG+=("$NAME")
    continue
  fi

  TF_ARGS=(-input=false)
  [[ -n "$VAR_FILE" ]] && TF_ARGS+=("-var-file=$VAR_FILE")
  # -var は -var-file より後に置くこと。後勝ちで上書きされる
  TF_ARGS+=("-var=project_id=$PROJECT" "-var=user_name=$NAME")

  if [[ $APPLY -eq 0 ]]; then
    if terraform -chdir="$DIR" plan -destroy "${TF_ARGS[@]}" -no-color > "$DIR/plan.log" 2>&1; then
      grep -E '^Plan:|will be destroyed' "$DIR/plan.log" | sed 's/^/      /' | head -60
      OK+=("$NAME")
    else
      echo "  ✗ plan に失敗しました"
      tail -20 "$DIR/plan.log" | sed 's/^/      /'
      NG+=("$NAME")
    fi
  else
    if terraform -chdir="$DIR" destroy -auto-approve "${TF_ARGS[@]}" -no-color > "$DIR/destroy.log" 2>&1; then
      grep -E '^Destroy complete' "$DIR/destroy.log" | sed 's/^/      /'
      OK+=("$NAME")
    else
      echo "  ✗ destroy に失敗しました"
      tail -25 "$DIR/destroy.log" | sed 's/^/      /'
      echo "      ★ サブネットだけ失敗しているなら、Direct VPC egress の"
      echo "        予約IPがまだ解放されていません。1〜2時間おいて流し直してください"
      NG+=("$NAME")
    fi
  fi
done

echo "────────────────────────────────────────"
echo
echo "=== 結果 ==="
echo "  成功       : ${#OK[@]}人 ${OK[*]:-}"
echo "  スキップ   : ${#SKIP[@]}人 ${SKIP[*]:-}"
echo "  失敗       : ${#NG[@]}人 ${NG[*]:-}"

if [[ $APPLY -eq 0 ]]; then
  echo
  echo "★ dry-run でした。中身を確認したら --apply を付けて流し直してください。"
fi

if [[ ${#NG[@]} -gt 0 ]]; then
  echo
  echo "★ 失敗した人は check-leftover.sh で残りを確認してください:"
  echo "    ./check-leftover.sh ${NG[*]} --project=$PROJECT"
  exit 1
fi
exit 0
