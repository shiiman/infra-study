# 回答例

宿題1・2の内容を含みます。差分は `ci.tf` と、アプリのリポジトリに置く
`cloudbuild-ci.yaml` です。

## 課題

ブランチによってやることを変える。

- `<自分の名前>-dev` → ビルドと push だけ。デプロイしない
- `<自分の名前>` → ビルドしてデプロイ(講義で作ったもの)

## 回答

トリガーをもう1つ作り、**別のビルド構成ファイル**を読ませる。

```hcl
resource "google_cloudbuild_trigger" "ci" {
  name = "${var.user_name}-ci"

  repository_event_config {
    repository = var.cloudbuild_repository
    push {
      branch = "^${var.user_name}-dev$"
    }
  }

  filename = "cloudbuild-ci.yaml"   // deploy ステップが無いファイル
}
```

`cloudbuild-ci.yaml` は `cloudbuild.yaml` から deploy ステップを抜いただけ。

## ★ ポイント: 条件分岐ではなくファイルを分ける

1つの `cloudbuild.yaml` の中で「デプロイするかどうか」を
`$BRANCH_NAME` で分岐させることもできるが、
シェルの `if` をYAMLに埋めることになり読みにくい。

**やることが違うならファイルを分ける。**
Cloud Build のトリガーは軽いので、増やすのが安い。

AWS の CodePipeline は「パイプライン1本にソース1つ」なので、
ブランチごとにパイプラインを丸ごと複製する必要があった。
そこは GCP のほうが素直。

## 確認方法

```
terraform apply

gcloud builds triggers list --region=asia-northeast1 \
  --format="table(name,triggerTemplate.branchName,filename)"
```

トリガーが2つ見えるはず。

### dev ブランチに push する

```
git checkout -b [自分の名前]-dev
# 何か変更する
git commit -am "ci test"
git push origin [自分の名前]-dev
```

```
gcloud builds list --region=asia-northeast1 --limit=3 \
  --format="table(id,status,substitutions.BRANCH_NAME)"
```

`-ci` のビルドだけが動き、Cloud Run のリビジョンは増えないことを確認する。

```
gcloud run revisions list --service=[自分の名前]-app --region=asia-northeast1
```

### 本番ブランチに push する

```
git checkout [自分の名前]
git merge [自分の名前]-dev
git push origin [自分の名前]
```

こちらは Cloud Run のリビジョンが増える。

## 発展: もっと実務に近づけるなら

| やりたいこと | 設定 |
|---|---|
| プルリクエスト時にビルドしたい | `pull_request { branch = "^main$" }` |
| 特定のディレクトリが変わったときだけ | `included_files = ["app/**"]` |
| ドキュメントだけの変更は動かさない | `ignored_files = ["**/*.md"]` |

`included_files` / `ignored_files` はモノレポで効く。
「Terraform のコードを直しただけなのにアプリのビルドが走る」を防げる。

## 参考

- [ビルドトリガーの作成と管理](https://cloud.google.com/build/docs/automating-builds/create-manage-triggers)
- [ビルド構成ファイルのスキーマ](https://cloud.google.com/build/docs/build-config-file-schema)
