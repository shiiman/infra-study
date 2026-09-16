#!/usr/bin/env bash
#
# 勉強会のリソースが消し切れているかを確認するスクリプト
#
# 第5回以降は Cloud Run の Direct VPC egress が確保したIPアドレスの解放を
# 待たないとサブネットが消せない。そのため destroy が2段構えになり、
# 「1回目だけやって終わったつもり」になる人が出る。
# 残骸があると次回の apply が同名リソースの衝突で失敗するので、
# 次回に参加する前に各自これを流して確認する。
#
# 使い方:
#   ./check-leftover.sh tanaka                     # 自分の分だけ見る(受講者)
#   ./check-leftover.sh tanaka suzuki sato         # 複数人分を見る(講師)
#   ./check-leftover.sh --names-file=members.txt   # 名簿から読む(講師)
#   ./check-leftover.sh tanaka --project=xxxxx     # プロジェクトを明示する
#
# ★ 共有プロジェクトなので「全部見る」モードは意図的に作っていない。
#   名前で絞らないと業務用のリソースまで一覧に出てしまい、
#   消してよいものの判断を誤る。必ず受講者名を渡すこと。
#
# 終了コード:
#   0 = きれい / 1 = 残骸あり / 2 = 使い方が違う

set -uo pipefail

NAMES=()
PROJECT_ARG=()

for arg in "$@"; do
  case "$arg" in
    --project=*)
      PROJECT_ARG=("$arg")
      ;;
    --names-file=*)
      f="${arg#--names-file=}"
      if [[ ! -f "$f" ]]; then
        echo "名簿ファイルが見つかりません: $f" >&2
        exit 2
      fi
      # 空行と # で始まる行は読み飛ばす
      while read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | tr -d '[:space:]')"
        [[ -n "$line" ]] && NAMES+=("$line")
      done < "$f"
      ;;
    -h|--help)
      sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'
      exit 2
      ;;
    -*)
      echo "不明なオプション: $arg" >&2
      exit 2
      ;;
    *)
      NAMES+=("$arg")
      ;;
  esac
done

if [[ ${#NAMES[@]} -eq 0 ]]; then
  echo "使い方: $0 <受講者名> [受講者名...] | --names-file=<名簿>" >&2
  echo "  (共有プロジェクトなので、名前を渡さずに全件見るモードはありません)" >&2
  exit 2
fi

REGION="asia-northeast1"

# 受講者名のどれかで始まるものだけを残す grep パターンを作る
# 例: NAMES=(tanaka suzuki) → "^tanaka-|^suzuki-"
PATTERN=""
for n in "${NAMES[@]}"; do
  PATTERN+="${PATTERN:+|}^${n}-"
done

FOUND=0

# $1=見出し / $2以降=gcloud のコマンド列
check() {
  local title="$1"; shift
  local out
  out=$("$@" "${PROJECT_ARG[@]}" --format="value(name)" 2>/dev/null \
        | grep -E "$PATTERN" || true)
  if [[ -n "$out" ]]; then
    FOUND=1
    echo "  [残っている] $title"
    echo "$out" | sed 's/^/      /'
  fi
}

echo "=== リソース確認: ${NAMES[*]} ==="
echo

echo "--- 課金が続くもの(先に消したい) ---"
check "VM インスタンス"            gcloud compute instances list
check "Cloud SQL インスタンス"     gcloud sql instances list
check "Memorystore(Redis)"         gcloud redis instances list --region="$REGION"
check "Spanner インスタンス"       gcloud spanner instances list
check "ロードバランサの転送ルール" gcloud compute forwarding-rules list
check "静的な外部IP"               gcloud compute addresses list
check "Cloud Run サービス"         gcloud run services list --region="$REGION"
check "Cloud NAT の Router"        gcloud compute routers list
check "アラートポリシー"           gcloud alpha monitoring policies list
echo

echo "--- 課金はほぼ無いが、次回の apply が名前衝突で失敗する原因になるもの ---"
check "VPC ネットワーク"           gcloud compute networks list
check "サブネット"                 gcloud compute networks subnets list
check "Cloud Armor ポリシー"       gcloud compute security-policies list
echo

# Direct VPC egress が確保したIP。これが残っている間はサブネットが消せない。
# アドレス自体の名前は GCP が自動で付けるので、紐づくサブネット名で絞る。
echo "--- Direct VPC egress の予約IP(解放待ち) ---"
PENDING=$(gcloud compute addresses list "${PROJECT_ARG[@]}" \
            --filter="purpose=SERVERLESS" \
            --format="value(subnetwork.basename(),name)" 2>/dev/null \
          | grep -E "$PATTERN" || true)
if [[ -n "$PENDING" ]]; then
  echo "$PENDING" | sed 's/^/      /'
  echo
  echo "  ★ これは手動では消せません。解放されるまで1〜2時間かかります。"
  echo "    解放されてから terraform destroy をもう1回打つと、残りが消えます。"
  FOUND=1
else
  echo "      なし(解放済み。destroy を打ち直せば残りは消えます)"
fi
echo

if [[ $FOUND -eq 0 ]]; then
  echo "✅ きれいです。次回の apply はそのまま通ります。"
  exit 0
fi

cat <<'MSG'
⚠️ 残骸があります。このままだと次回の apply が同名リソースの衝突で失敗します。

  対処:
    1. 前回の作業ディレクトリに戻る (例: cd ~/works/lesson7)
    2. terraform destroy
    3. 上の「解放待ち」に何か出ていたら、1〜2時間おいてから 2 をやり直す

  ★ VPC とサブネットだけが残っている状態なら課金はありません。
    慌てず、翌日に destroy を打ち直せば大丈夫です。
MSG
exit 1
