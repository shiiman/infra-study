#!/usr/bin/env bash
#
# 受講者ごとのビルド用サービスアカウントを作る(第7回・講師)
#
# 【なぜ講師がやるのか】
# ビルド用SAには `roles/logging.logWriter` と `roles/clouddeploy.jobRunner` が要る。
# どちらも**プロジェクト単位でしか付けられない**ロールで、それを付けるための
# `resourcemanager.projects.setIamPolicy` は共有プロジェクトでは配れない
# (付けると誰にでも好きなロールを渡せてしまう)。
# そのため SA の作成とプロジェクト単位のロール付与は講師が事前に行う。
#
# 受講者は `data "google_service_account"` で参照するだけ
# (`lesson7/2. cloud_build/artifact_registry.tf`)。
# リソース単位の権限(リポジトリ / Cloud Run / SA)は受講者が自分で付ける。
#
# 【使い方】
#   # まず dry-run(既定)。何が作られるかを見る
#   ./create-build-sa.sh --names-file=members.txt --project=<プロジェクトID>
#
#   # 中身を確認したうえで実行する
#   ./create-build-sa.sh --names-file=members.txt --project=<プロジェクトID> --apply
#
# ★ 名簿に書く名前は、受講者が `terraform.tfvars` の `user_name` に
#   入れるのと同じ文字列にすること。SA名が `<user_name>-build` になるため、
#   食い違うと第7回の apply が「SAが見つからない」で落ちる。
#
# 終了コード: 0 = 全員成功 / 1 = 失敗した人がいる / 2 = 使い方が違う

set -uo pipefail

NAMES=()
PROJECT=""
APPLY=0

# プロジェクト単位でしか付けられないロール
ROLES=(roles/logging.logWriter roles/clouddeploy.jobRunner)

for arg in "$@"; do
  case "$arg" in
    --project=*) PROJECT="${arg#--project=}" ;;
    --apply)     APPLY=1 ;;
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
      sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 2
      ;;
    -*)
      echo "不明なオプション: $arg" >&2
      exit 2
      ;;
    *) NAMES+=("$arg") ;;
  esac
done

if [[ ${#NAMES[@]} -eq 0 || -z "$PROJECT" ]]; then
  echo "使い方: $0 --names-file=<名簿> --project=<プロジェクトID> [--apply]" >&2
  echo "        $0 <名前> [名前...] --project=<プロジェクトID> [--apply]" >&2
  exit 2
fi

if [[ $APPLY -eq 1 ]]; then
  MODE="実行します"
else
  MODE="dry-run(何も作りません)"
fi

cat <<EOS
=== ビルド用サービスアカウントの作成(第7回) ===
  プロジェクト: $PROJECT
  対象        : ${#NAMES[@]}人 (${NAMES[*]})
  作る SA     : <名前>-build
  付けるロール: ${ROLES[*]}
  モード      : $MODE

EOS

# プロジェクトのIAMポリシーは1つしかないため、連続して更新すると
# 他の更新と etag が競合して落ちることがある(12人 x 2ロール = 24回の更新で実際に発生)。
# 競合は時間をおけば通るので、少し待って数回やり直す。
add_binding_with_retry() {
  local member="$1" role="$2" i
  for i in 1 2 3 4 5; do
    if gcloud projects add-iam-policy-binding "$PROJECT" \
         --member="$member" --role="$role" --condition=None >/dev/null 2>&1; then
      return 0
    fi
    sleep $((i * 2))
  done
  return 1
}

OK=()
NG=()
SKIP=()

for NAME in "${NAMES[@]}"; do
  SA="${NAME}-build"
  EMAIL="${SA}@${PROJECT}.iam.gserviceaccount.com"
  echo "────────────────────────────────────────"
  echo "▼ $NAME  ($EMAIL)"

  EXISTS=0
  if gcloud iam service-accounts describe "$EMAIL" --project="$PROJECT" >/dev/null 2>&1; then
    EXISTS=1
    echo "  SA は既にあります → 作成は飛ばし、ロールだけ確認します"
  fi

  if [[ $APPLY -eq 0 ]]; then
    [[ $EXISTS -eq 0 ]] && echo "  [作る] SA $SA"
    for R in "${ROLES[@]}"; do echo "  [付ける] $R"; done
    SKIP+=("$NAME")
    continue
  fi

  FAILED=0
  if [[ $EXISTS -eq 0 ]]; then
    if gcloud iam service-accounts create "$SA" \
         --display-name="${NAME} cloud build" --project="$PROJECT" >/dev/null 2>&1; then
      echo "  ✓ SA を作成しました"
    else
      echo "  ✗ SA の作成に失敗しました"
      FAILED=1
    fi
  fi

  if [[ $FAILED -eq 0 ]]; then
    for R in "${ROLES[@]}"; do
      if add_binding_with_retry "serviceAccount:${EMAIL}" "$R"; then
        echo "  ✓ $R"
      else
        echo "  ✗ $R の付与に失敗しました(5回試行)"
        echo "      ★ 他の更新と etag が競合している可能性があります。"
        echo "        少し待ってから、このスクリプトをもう一度流してください"
        echo "        (作成済みの SA は飛ばされ、足りないロールだけ付きます)"
        FAILED=1
      fi
    done
  fi

  if [[ $FAILED -eq 0 ]]; then OK+=("$NAME"); else NG+=("$NAME"); fi
done

echo "────────────────────────────────────────"
echo
echo "=== 結果 ==="
if [[ $APPLY -eq 0 ]]; then
  echo "  dry-run: ${#SKIP[@]}人分の作成内容を表示しました"
  echo
  echo "★ 中身を確認したら --apply を付けて流し直してください。"
else
  echo "  成功: ${#OK[@]}人 ${OK[*]:-}"
  echo "  失敗: ${#NG[@]}人 ${NG[*]:-}"
  echo
  echo "★ 確認:"
  echo "    gcloud iam service-accounts list --project=$PROJECT --filter='email~-build@'"
fi

[[ ${#NG[@]} -gt 0 ]] && exit 1
exit 0
