#!/usr/bin/env bash
# 各回のスナップショットを作業ディレクトリに展開する。
# 個人設定・backend・state を保持し、Terraform は実行しない。
set -euo pipefail

if [[ $# -ne 2 || ! "$1" =~ ^[3-8]$ ]]; then
  echo '使い方: bash ~/infra-study/gcp/tools/prepare-step.sh <回番号 3〜8> "0. before"' >&2
  exit 1
fi
lesson="$1"
step="$2"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_dir="$repo_root/gcp/lesson$lesson/$step"
work_root="${INFRA_STUDY_WORK_ROOT:-$HOME/works}"
work_dir="$work_root/lesson$lesson"

if [[ "$step" == */* || ! -f "$source_dir/before.tf" || ! -f "$source_dir/common.tf" ]]; then
  echo "指定したステップが見つかりません: $step" >&2
  exit 1
fi
mkdir -p "$work_dir"
if [[ "$work_dir" -ef "$source_dir" ]]; then
  echo 'リポジトリ自身には展開できません。' >&2
  exit 1
fi

# 別の宿題や後のステップから戻す場合、残った定義を黙って適用しない。
for existing in "$work_dir"/*.tf; do
  [[ -e "$existing" ]] || continue
  filename="$(basename "$existing")"
  if [[ ! -f "$source_dir/$filename" ]]; then
    echo "作業先に今回の例にない定義があります: $filename" >&2
    echo '後のステップから戻す／別の宿題へ切り替える前に、差分を確認してください。ファイルは変更していません。' >&2
    exit 1
  fi
done

# 初回だけ初期値を配布する。以降、受講者が設定した値を上書きしない。
for filename in common.tf terraform.tfvars; do
  if [[ ! -e "$work_dir/$filename" ]]; then
    cp "$source_dir/$filename" "$work_dir/$filename"
  fi
done
cp "$source_dir/terraform.tfvars" "$work_dir/terraform.tfvars.example"
rsync -a --exclude='common.tf' --exclude='terraform.tfvars' \
  --exclude='.*' --exclude='*.tfstate*' --exclude='*.tfplan' \
  "$source_dir/" "$work_dir/"

echo "展開しました: $work_dir ← $step"
echo 'common.tf の backend と terraform.tfvars の個人設定は保持しています。'
echo 'terraform.tfvars.example と比較し、このステップで増えた変数だけ設定してください。'
echo "次の操作: cd ~/works/lesson$lesson → terraform init → terraform plan"
echo 'plan の変更内容を確認してから terraform apply を実行してください。'
