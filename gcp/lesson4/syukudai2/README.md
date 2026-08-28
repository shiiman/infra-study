# 回答例

## 課題

講義では概説だけだった Cloud SQL を実際に作り、アプリから繋ぐ。
そのあとフェイルオーバーを起こして復旧時間を測る。

## 回答

`db.tf` を参照。`syukudai1` の内容に Cloud SQL を足したもの。

```
export TF_VAR_db_password='任意のパスワード'
terraform plan
terraform apply
```

★ 作成に **約10分** かかる。

## ポイント1: 限定公開サービスアクセスを使い回す

講義の Step2(Memorystore)で作ったピアリングをそのまま使う。
Cloud SQL 側で新しく作るものはない。

```hcl
resource "google_sql_database_instance" "db" {
  settings {
    ip_configuration {
      ipv4_enabled    = false            # パブリックIPを持たせない
      private_network = module.before.vpc_id
    }
  }
  depends_on = [google_service_networking_connection.private_service]
}
```

**Firewall Rules は書かない。** ピアリング経由なので対象外。

## ポイント2: password_wo が本当に tfstate に残らないか

apply したあと、tfstate を確認する。

```
grep -c '任意のパスワード' terraform.tfstate
```

```
0
```

`google_sql_user` の中身も見てみる。

```
terraform show -json | python3 -c "
import sys,json
d=json.load(sys.stdin)
for r in d['values']['root_module']['resources']:
    if r['type']=='google_sql_user':
        print(r['values'])
"
```

```
{'name': 'app', 'password': None, 'password_wo': None, 'password_wo_version': 1, ...}
```

**パスワードは保存されていない。** バージョン番号だけが残る。

> パスワードを変えたいときは `password_wo_version` を 2 に上げる。
> 値だけ変えても Terraform は差分を検知できない(値を持っていないため)。

## ポイント3: アプリを Cloud SQL に向ける

```
# 初期データを入れる
mysql -u app -p -h [db_host] test_db

CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255));
INSERT INTO users (name) VALUES ('infra'), ('study');
```

```
docker rm -f app
docker run -d -p 80:8080 --network app-nw --name app \
  -e DB_KIND=mysql \
  -e DB_HOST=[db_host] -e DB_USER=app -e DB_PASS='任意のパスワード' \
  -e CACHE_HOST=[cache_host] \
  app:0.1

curl -X GET "http://localhost"
```

```
Hello, Infra Study
hostname: xxxx
DB接続(MySQL): 成功
Cache接続: 成功
```

**1つのイメージで Spanner にも MySQL にも繋がる。** 環境変数を変えただけ。

## ポイント4: フェイルオーバーの計測

ターミナルを2つ開く。

**1つ目: アプリを叩き続ける**

```
while true; do
  printf '%s ' "$(date +%H:%M:%S)"
  curl -s -m 5 http://localhost | tr '\n' ' '
  echo
  sleep 1
done
```

**2つ目: フェイルオーバーを起こす**

```
gcloud sql instances failover [自分の名前]-db
```

`DB接続` が `失敗` になってから `成功` に戻るまでの秒数を数える。

```
14:20:31 ... DB接続(MySQL): 成功
14:20:32 ... DB接続(MySQL): 失敗   ← ここから
...
14:21:35 ... DB接続(MySQL): 成功   ← ここまで
```

**60秒程度かかる。「HA構成なら無停止」ではない。**

切り替わったことを確認する。

```
gcloud sql instances describe [自分の名前]-db --format="value(gceZone)"
```

前後でゾーンが変わっている。

## 考えてみてほしいこと

**60秒落ちてもアプリを落とさないには?**

- コネクションプールのリトライ設定
- 読み取りだけでもキャッシュで返す
- ヘルスチェックの設計

**今日のアプリはどうなっているか?**

`DB接続: 失敗` と表示されるだけで、HTTPステータスは200のまま。
ロードバランサのヘルスチェックは `/` を見ているので、
**DBが落ちてもバックエンドはHEALTHYのまま**になる。

これは良いのか悪いのか。第8回(監視・運用)で扱います。

## 後片付け

★ destroy は1回では終わりません(講義の付録A-2参照)。

```
terraform destroy          # Cloud SQL などは消えるが、ピアリングの削除で失敗する
# しばらく待つ
terraform destroy          # 残りが消える
```

## 参考

- [Cloud SQL の高可用性](https://cloud.google.com/sql/docs/mysql/high-availability)
- [プライベートIPの構成](https://cloud.google.com/sql/docs/mysql/configure-private-ip)
- [書き込み専用引数(write-only arguments)](https://developer.hashicorp.com/terraform/language/resources/ephemeral/write-only)
