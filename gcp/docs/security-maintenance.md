# GCP 教材のセキュリティ更新

## 対象と更新方針

2026-11-05 に GCP 教材の OS、コンテナ、Go の依存関係、GitHub Actions を確認した。
AWS 教材は対象外。Terraform やドキュメントの更新と、稼働環境の更新完了は区別する。
この変更だけで既存の VM・コンテナ・マネージドサービスが更新されるわけではない。

| 対象 | 更新前 | 更新後・取り扱い |
| --- | --- | --- |
| Compute Engine | Debian 12 | `debian-cloud/debian-13`。後続回の開始構成、宿題、試験問題も統一 |
| Go ビルダー | `golang:1.25-alpine` | `golang:1.26.10-alpine3.24` |
| アプリ実行 OS | Alpine 3.22 | Alpine 3.24。ビルド時に `apk upgrade` |
| ローカル MySQL | MySQL 8.0 | MySQL 8.4 LTS。OS 更新と未使用ツールの除去 |
| ローカル Redis | `redis:7-alpine` | `redis:8.8-alpine3.23`。ビルド時に `apk upgrade` |
| Cloud SQL（第4回宿題2） | `MYSQL_8_0` | `MYSQL_8_4`、`edition = "ENTERPRISE"` を明示し共有 CPU を維持 |
| Memorystore | `REDIS_7_2` | 維持。サービス側のパッチ適用状況・メンテナンスを実環境で確認 |
| GitHub Actions | checkout v4 / auth v2 / setup-gcloud v2 | checkout v7 / auth v3 / setup-gcloud v3 |
| Terraform CLI | インストール例 1.16.3、最低 1.9.0 / 1.11.0 | インストール例・最低バージョンとも 1.17.1 |
| Google provider | `~> 8.0` | `~> 8.10`。既存作業ディレクトリは `terraform init -upgrade` が必要 |

MySQL 8.4 の既定エディションは Enterprise Plus なので、`ENTERPRISE` を明示する。
既存の `db-g1-small` を維持し、バージョン変更に伴う意図しないマシン種別・料金の変更を避ける。

MySQL 公式イメージにはサーバー以外に MySQL Shell と `gosu` が含まれる。
スキャンでこれらの古い依存関係が検出されたため、教材で使わない Shell を削除し、
`USER mysql` で最初から一般ユーザーとして起動して `gosu` を不要にする。
教材の初期 SQL は公式 entrypoint で実行する。root 起動やホストの任意の既存データディレクトリの
所有権変更を前提にせず、既存 DB のデータはバックアップして移行する。

## Unbound の対応根拠

Debian Security Tracker は CVE-2026-81642 について Debian 12 の
`1.17.1-2+deb12u4` を vulnerable、Debian 13 の security パッケージを fixed としている。
修正境界は `1.26.1-0+deb13u1`。Debian 13 コンテナで security リポジトリから
`1.26.2-0+deb13u1` を取得し、`dpkg --compare-versions` で修正境界以上と確認した。
これはパッケージ配布の検証であり、Compute Engine イメージや既存 VM の検証ではない。

VM のイメージファミリーは新規作成時のイメージを選ぶ。既存 VM の OS を自動更新しない。
また、Debian 13 でもイメージ作成後の修正は別途取り込む必要がある。
インターネットへ接続できる段階で `apt-get update` と `apt-get upgrade` を実行する。
第2回の Cloud NAT 作成前の private VM は外部リポジトリへ接続できないため、
その段階で自動更新済みとは判断しない。長時間放置せず、演習後は自分の教材リソースを片付ける。

VM 内での確認例（Unbound を使わない VM に検査目的でインストールしない）:

```bash
cat /etc/os-release
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
for package in unbound libunbound8; do
  if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -qx 'install ok installed'; then
    version=$(dpkg-query -W -f='${Version}' "$package")
    printf '%s %s\n' "$package" "$version"
    dpkg --compare-versions "$version" ge '1.26.1-0+deb13u1' || exit 1
  fi
done
```

この比較は Debian 13 用。他の OS や Debian 12 のバックポート版にそのまま流用しない。
更新後は対象サービスを再起動し、カーネルなど再起動が必要な更新では VM も再起動して確認する。
最終的な解消確認には SCC 等の再スキャン結果も使用する。

## Go の依存関係

11 か所の `go.mod` / `go.sum` を同じ内容で維持する。
`govulncheck` は呼び出される脆弱性と、依存に含まれるだけのものを区別する。
今回の更新では両方を確認し、コンテナ内バイナリも別途スキャンする。

| モジュール | 更新前 | 更新後 |
| --- | --- | --- |
| `golang.org/x/net` | v0.58.0 | v0.62.0 |
| `golang.org/x/crypto` | v0.55.0 | v0.58.1-0.20261009181718-2f1f834330b2 |
| `go.opentelemetry.io/otel/sdk` 等 | v1.44.0 | v1.45.0 |
| `filippo.io/edwards25519` | v1.1.0 | v1.1.1 |
| `github.com/go-jose/go-jose/v4` | v4.1.4 | v4.1.6 |

`x/crypto` の pseudo-version は GO-2026-5932 の修正境界を指定したもの。
OpenPGP をアプリで使わない場合でも古い依存定義を残さない。
それに伴う `x/sys`、`x/text`、`x/sync`、`logr` も Go の依存解決結果に合わせる。
第3回の標準ライブラリだけのアプリは、Go 更新後も静的解析が通るように
`fmt.Fprintf` の書式文字列を定数へ変更している。表示内容は同じ。

## 既存環境に適用する際の注意

1. 自分の作業ディレクトリ、プロジェクト、Terraform state、所有リソースを確認する。
   共有環境で他の受講者のリソースを操作しない。
2. VM 内の必要なファイル・DB データをバックアップする。
   boot disk のイメージ変更は VM の再作成を伴う可能性がある。`terraform plan` で差分を確認する。
3. Cloud SQL の major upgrade は事前の互換性確認・バックアップと停止時間の確保が必要。
   既存インスタンスは専用の upgrade 手順を確認し、教材の新規作成例をそのまま適用しない。
4. コンテナは `docker build --pull --no-cache ...` で再ビルドする。
   `--pull` だけでは `RUN apk upgrade` のキャッシュが再利用される場合がある。
   Cloud Build と GitHub Actions の例にも両方を指定している。
5. 新しいイメージを push・デプロイし、実際の revision と稼働イメージを確認する。
   ローカルのビルド成功だけで Cloud Run の更新完了とはしない。
6. VM パッケージと起動中コンテナを再スキャンする。
   Cloud SQL / Memorystore はメンテナンスの適用済みバージョンも確認する。

キャッシュを使わないビルドと OS 更新で、演習の待ち時間・ダウンロード量は増える。
起動スクリプトはパッケージ更新に失敗したら停止するため、Cloud NAT と DNS の疎通を先に確認する。

## 継続的な確認

勉強会の実施前に、サポート期限と最新のセキュリティ情報を確認する。
Go は各 `go.mod` のディレクトリで次を実行する。第3回は `go test main.go` と `go vet main.go` を使う。

```bash
go mod verify
go test -race ./...
go vet ./...
govulncheck -show verbose ./...
GOOS=linux GOARCH=amd64 govulncheck -show verbose ./...
```

イメージも最新の脆弱性 DB で検査する。重大度や修正版の有無だけで隠さず結果を確認する。

```bash
trivy image --scanners vuln IMAGE
```

この記録やスキャン時点の検出ゼロは、将来の脆弱性やすべての稼働リソースの安全性を保証しない。

## 2026-11-05 の検証結果と残る制約

- Terraform CLI 1.17.1 は公式 ZIP の SHA-256 を公式 `SHA256SUMS` と照合した。
- Terraform CLI 1.17.1 / Google provider 8.10.0 で全 59 構成を
  `init -upgrade -backend=false`・`validate` し、すべて成功。`fmt -check -recursive gcp` も成功した。
- GCP の開始構成・ステップ間の整合性チェックと `configure.py` の 4 テストを実行した。
- 11 Go module で `go mod verify`、`go test -race -cover ./...`、`go vet ./...`、
  `govulncheck -show verbose ./...` が成功。第3回の 7 アプリも test / vet が成功。
  アプリに既存のユニットテスト・Benchmark はないため、これらのコマンドだけで動作を保証しない。
- 第3回・第4回・第7回の代表アプリと MySQL / Redis の計 5 イメージをビルドし、
  Trivy 0.76.1 の全重大度・修正版なしを含む検査で検出ゼロ。第7回は `linux/amd64` でビルドした。
- 隔離した Docker network 内で MySQL 初期 SQL（users 2 件）、Redis の PING、
  第3回の HTTP 応答、第4回・第7回の MySQL / Cache 接続成功を確認した。
  第7回の `APP_VERSION` 埋め込みも確認し、検証用コンテナと network は削除した。
- Compute Engine / Cloud SQL / Memorystore の実リソースの作成・更新・削除、
  Cloud Run へのデプロイ、SCC 再スキャンは実施していない。
  Google Slides 自体の編集・同期も対象外で、リポジトリ内の原稿だけを更新した。

**実行用イメージと別に残る、公式ツールの検出:**
検査時点で公開されていた最新の Terraform CLI 1.17.1 と Google provider 8.10.0 の
macOS arm64 公式バイナリにも `govulncheck -mode binary` を実施した。
Terraform は GO-2026-5932、Google provider は GO-2026-6866 / GO-2026-6860 /
GO-2026-5932 の該当シンボルを検出した。バイナリ内の検出であり、教材の操作からの
到達可能性・悪用可能性は未確認。公式のより新しい安定版がなかったため、ここは未解消として残す。
公式ツールの独自ビルドへの置換は行っていない。修正版公開後にバージョン条件と
インストール手順を更新し、再検査する必要がある。

## 参照

- [Debian: CVE-2026-81642](https://security-tracker.debian.org/tracker/CVE-2026-81642)
- [Compute Engine の OS と自動更新](https://docs.cloud.google.com/compute/docs/images/os-details)
- [Go の修正リリース](https://go.dev/doc/devel/release)
- [Alpine のサポート期間](https://www.alpinelinux.org/releases/)
- [Cloud SQL のバージョン方針](https://docs.cloud.google.com/sql/docs/mysql/db-versions)
- [Cloud SQL のエディション](https://docs.cloud.google.com/sql/docs/mysql/choose-edition)
- [GO-2026-5932](https://pkg.go.dev/vuln/GO-2026-5932)
- [GO-2026-6866](https://pkg.go.dev/vuln/GO-2026-6866)
- [MySQL 公式イメージの entrypoint](https://github.com/docker-library/mysql/blob/master/8.4/docker-entrypoint.sh)
- [Terraform 1.17.1 のリリース](https://github.com/hashicorp/terraform/releases/tag/v1.17.1)
