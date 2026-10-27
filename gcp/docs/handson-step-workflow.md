# ハンズオンのコピーと個人設定（第3〜8回共通）

教材のコピーは通常の `cp` で行います。`configure.py` はコピー済みファイルの個人設定3項目だけを反映します。Python 3の標準ライブラリのみを使用し、追加パッケージは不要です。

## 第3回の初回設定

第1回で作成済みのtfstate用GCSバケットを使用します。第3回の開始用教材をコピーします。第1・2回の講義資料と手順は変更しません。

```bash
mkdir -p ~/works/lesson3
cd ~/works/lesson3 && cp -rf ~/infra-study/gcp/lesson3/"0. before"/* ./ && \
  python3 ~/infra-study/gcp/tools/configure.py
```

初回は次の3項目を入力します。

- project ID
- user name（社用メールの `@` より前の `_` を `-` に置換）
- 作成済みのtfstate用GCSバケット名（`gs://` は不要）

設定は `~/.config/infra-study/profile.json` に、本人だけが読み書きできる権限で保存します。リポジトリ外なのでGit管理に含まれません。認証情報やパスワードは保存しません。保存値を変更するときは同じコマンドに `--edit` を付けます。

変更対象は `common.tf` のGCS backendの `bucket` と、`terraform.tfvars` の `project_id`・`user_name` だけです。回ごとのbackendの `prefix`、その他の変数、`.terraform`、stateは変更しません。コピー・バケット作成・認証設定・Terraform実行は行いません。

## 次回以降・次のステップ

各回の作業ディレクトリで、教材を番号順にコピーします。第3回以降は `0. before` から開始します。

```bash
mkdir -p ~/works/lesson3
cd ~/works/lesson3 && cp -rf ~/infra-study/gcp/lesson3/"0. before"/* ./ && \
  python3 ~/infra-study/gcp/tools/configure.py
```

次回以降は入力不要で、保存済みの3項目が反映されます。表示された値を確認してください。

```bash
terraform init
terraform plan
terraform apply
```

次のステップも同じ流れです。

```bash
cd ~/works/lesson3 && cp -rf ~/infra-study/gcp/lesson3/"1. web_instance"/* ./ && \
  python3 ~/infra-study/gcp/tools/configure.py
```

**掲載コマンドは移動・コピー・設定反映を `&&` でつないだ1コマンドです。** 行末の `\` は表示上の改行で、2行をまとめて実行します。途中で失敗した場合、後続の処理は実行しません。 `cp` は既存の教材ファイルを上書きします。DNS・サブネット・GitHub連携など3項目以外の値も教材の初期値に戻るので、各回の説明に従って確認・再設定してからplanします。独自に編集したコードも、必要ならコピー前に別途退避してください。

コピー元はGitから取得した未実行の教材を使い、Terraformは `~/works/lessonN` で実行します。`/*` によりディレクトリ自体でなく中身をコピーし、`.terraform` などの隠しファイルをコピーしません。コピー先の既存ファイルは削除しないため、前のステップや別の宿題へ切り替える場合は余分な `.tf` が残っていないか確認してください。

## リソースとstateの引き継ぎ

第3〜8回の `0. before/before.tf` は開始時点のリソースを直接定義します。後続のスナップショットにも同じ定義を含め、途中で `module.before` へ切り替えません。第5・6回のLBフロント側や、第8回のCI/CDの扱いは各回の説明どおりです。第9回は試験対策、第10回は実技課題のため、この共通コピー手順の対象外です。

旧 `module.before` からの `before_moved.tf` は維持しています。同一state内の管理名の移行用で、backendは移行しません。既存環境では従来と同じbackendを使い、planで意図しない破棄・再作成がないことを確認してください。

## ローカル検証

```bash
python3 -B gcp/tools/test_configure.py
python3 -B gcp/tools/check-step-workflow.py
git diff --check
```

個人設定の初回入力・再利用・変更、対象3項目以外の保持、不正入力時の非更新、リポジトリ内やシンボリックリンク経由の実行拒否を確認します。クラウドのplan・apply・destroyは実行しません。
