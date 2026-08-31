# アプリ用リポジトリの中身(第7回)

このディレクトリは **教材ではなく、別リポジトリに置くもの**です。

第7回では、受講者全員が1つの GitHub リポジトリに push します。
そのリポジトリのルートに、ここのファイルをそのまま置いてください。

## 置くもの

| ファイル | 役割 |
|---|---|
| `main.go` / `go.mod` / `dockerfile` | アプリ本体。第5回のものに、バージョン表示を足したもの |
| `cloudbuild.yaml` | ビルド → push → Cloud Run へデプロイ(講義で使う) |
| `cloudbuild-ci.yaml` | ビルド → push まで(**宿題3**で使う) |
| `deploy/skaffold.yaml` | Cloud Deploy の設定(**宿題1・2**で使う) |
| `deploy/run-service.yaml` | Cloud Deploy が作る Cloud Run の定義(**宿題1・2**で使う) |

## 講師の準備

```
gh repo create [org]/[アプリ用リポジトリ] --private

git clone https://github.com/[org]/[アプリ用リポジトリ].git
cd [アプリ用リポジトリ]
cp -r [このディレクトリ]/. .
rm README.md          # この説明は不要
git add . && git commit -m "初期コード" && git push origin main
```

受講者に write 権限を付けてください。

## 受講者の使い方

自分の名前のブランチを切って push します。

```
git clone https://github.com/[org]/[アプリ用リポジトリ].git
cd [アプリ用リポジトリ]
git checkout -b [自分の名前]

# main.go を書き換えて
git commit -am "test"
git push origin [自分の名前]
```

**main ブランチには push しないでください。**

## 第5回のアプリとの違い

`main.go` にビルド時のバージョンを表示する処理を足しています。

```go
var version = "dev"   // -ldflags でビルド時に上書きされる
```

`dockerfile` 側で受け取っています。

```dockerfile
ARG APP_VERSION=dev
RUN go build -ldflags "-X main.version=${APP_VERSION}" -o /main ./main.go
```

Cloud Build が `--build-arg APP_VERSION=$SHORT_SHA` で
コミットのSHAを渡すので、
**動いているイメージがどのコミットのものか**が画面で分かります。

環境変数ではなくイメージに焼き込んでいるのは、
Cloud Run の環境変数を Terraform が管理しているためです。
CI/CD が環境変数を触ると Terraform と取り合いになります。
