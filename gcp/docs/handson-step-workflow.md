# 第3〜8回のハンズオンの進め方

各回は `0. before` から開始し、同じ作業ディレクトリへ番号順に今回のコードを追加します。`start` ディレクトリは使いません。

## 初回の準備（第3回の例）

```bash
bash ~/infra-study/gcp/tools/prepare-step.sh 3 "0. before"
cd ~/works/lesson3
```

`common.tf` の GCS backend の bucket と `terraform.tfvars` の project_id・user_name・その他の必須値を、自分の環境に合わせて設定します。backend の prefix は回ごとに `lesson3` などを使います。前回のリソースの削除確認は従来どおり各回の準備で行います。

```bash
terraform init
terraform plan
terraform apply
```

## 次のステップ

```bash
bash ~/infra-study/gcp/tools/prepare-step.sh 3 "1. web_instance"
cd ~/works/lesson3
terraform init
terraform plan
```

スクリプトはコードを展開するだけで、Terraform は実行しません。`common.tf`・`terraform.tfvars`・`.terraform`・stateを上書きしません。各ステップの初期値は `terraform.tfvars.example` に配置されるので、増えた変数だけを自分の設定へ追加します。plan の内容を確認してから apply してください。

ステップは各回の番号順に進めます。前のステップへ戻すときや別の宿題へ切り替えるとき、作業先に余分な `.tf` がある場合は停止します。スクリプトによる削除やstateの初期化は行いません。

## コードの構成とstate

- `0. before/before.tf` に、今回の開始時点で必要な前回分のリソースを直接定義します。
- 後続の各スナップショットにも同じ `before.tf` を含めます。各回の途中で `module.before` に切り替えません。
- 既存リソースは `google_compute_network.vpc.id` などで直接参照します。
- 第5・6回は今回作り直すLBのフロント側を開始状態から外す既存の構成を維持します。第8回は第7回のCI/CDを含めません。
- 第9回は試験対策、第10回は実技課題で、前回分の一括作成手順はありません。

旧版の `module.before` で作成済みの環境向けに `before_moved.tf` を各スナップショットへ同梱しています。これは同一state内の管理名を引き継ぐための宣言で、別backendへの移行は行いません。既存環境では従来と同じbackendを選び、planで意図しない破棄・再作成が出ないことを確認してください。新規環境では移動元がないため影響しません。

この変更によってスライドに掲載した手順とローカルコードは揃いますが、受講者が `git pull` で取得できるようにするには、変更のcommit・pushが必要です。

## 検証結果（2026-10-27）

- 第3〜10回のGoogle Slidesを確認し、第3〜8回の計34ページを更新しました。再取得した本文に旧 `start/` 手順や `module.before` 参照が残っていないことを確認しました。
- 変更ページを画像で確認し、開始手順の古いコード枠と長いコード行の表示を調整しました。
- 宿題を含む42構成で `terraform fmt`・`terraform validate` とmock providerによるplanテストが成功しました。テストには架空のproject・DNS・サービスアカウントなどを使用しています。
- `python3 gcp/tools/check-step-workflow.py` で42構成の管理名・移行宣言と、6回分の個人設定・backend・state保持を確認しました。余分な定義がある場合に変更せず停止することも確認しています。
- `git diff --check` が成功しました。

実際のGCP環境に対するplan・apply・destroyは実行していません。既存環境での移行結果は、その環境のstateとbackendを使ったplanで確認する必要があります。
