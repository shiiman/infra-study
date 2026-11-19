# 回答例

## 課題

1. Memorystore にレプリカを追加する
2. Spanner のインターリーブテーブルにデータを入れて、実行計画を見る

## 実行前の準備

このディレクトリには講義で作った Cloud SQL のコード(`db.tf`)も入っている。
`google_sql_user` の `precondition` が、パスワードが空のままの `plan` / `apply` を止めるので、
先に環境変数を設定する。パスワードは変えないので、講義と同じ値(自分の `user_name`。メールの `_` を `-` に変えたもの)を入れる(`password_wo_version` を上げない限り送られない)。

```
read -rs TF_VAR_db_password
export TF_VAR_db_password
terraform apply
unset TF_VAR_db_password
```

## 課題1: Memorystore のレプリカ

`cache.tf` を参照。変更点は1つ。

```hcl
resource "google_memorystore_instance" "cache" {
  replica_count = 1    # 0 → 1 に変更
}
```

`replica_count` はプライマリに付けるレプリカの数。0 は1ノードで、フェイルオーバーしない。
1 以上にすると、プライマリ + レプリカの構成になる。

### 読み取り専用のエンドポイントが使えるようになる

Memorystore for Valkey は、PSC のエンドポイントを2種類持つ。

- `CONNECTION_TYPE_PRIMARY` … 読み書き両方。プライマリに繋がる
- `CONNECTION_TYPE_READER` … 読み取り専用。レプリカに繋がる

`replica_count = 0` のときは、レプリカが無いので読み取り専用のエンドポイントは使えない
(接続すると `-ERR no replicas found` が返る)。
`replica_count = 1` にすると、レプリカが読み取りを受けるようになる。

`cache.tf` の output `cache_read_endpoint` に、読み取り専用のIPが出る。

```
terraform output cache_read_endpoint
```

★ レプリカの追加は、インスタンスを作り直さずに行われる(`terraform plan` で `~ update in-place` になる)。
  実測では、0 → 1 に約3分半、1 → 0 に約30〜40秒かかった。

### 確認方法

```
gcloud memorystore instances describe [自分の名前]-cache --location=asia-northeast1 \
  --format="yaml(state,replicaCount,endpoints)"
```

読み取り専用のエンドポイントに書き込もうとすると拒否される。

```
redis-cli -h [cache_read_endpoint] set foo bar
(error) READONLY You can't write against a read only replica.
```

### AWSとの違い

ElastiCache は、レプリケーショングループにレプリカを足す形だった。
Memorystore for Valkey は、同じインスタンスの `replica_count` を変えるだけで済む。

---

## 課題2: Spanner のインターリーブ

講義では `users` と `orders` を作っただけで、データを入れていない。
実際にデータを入れて、インターリーブの効果を確認する。

### データを入れる

```
gcloud spanner rows insert --table=users \
  --database=test-db --instance=[自分の名前]-spanner \
  --data=user_id=u001,name=infra

gcloud spanner rows insert --table=orders \
  --database=test-db --instance=[自分の名前]-spanner \
  --data=user_id=u001,order_id=o001,item=book

gcloud spanner rows insert --table=orders \
  --database=test-db --instance=[自分の名前]-spanner \
  --data=user_id=u001,order_id=o002,item=pen
```

### JOINしてみる

```
gcloud spanner databases execute-sql test-db \
  --instance=[自分の名前]-spanner \
  --sql="SELECT u.name, o.item FROM users u JOIN orders o ON u.user_id = o.user_id"
```

```
name   item
infra  book
infra  pen
```

### 実行計画を見る

```
gcloud spanner databases execute-sql test-db \
  --instance=[自分の名前]-spanner \
  --query-mode=PROFILE \
  --sql="SELECT u.name, o.item FROM users u JOIN orders o ON u.user_id = o.user_id"
```

インターリーブしてあると、親子の行が物理的に同じスプリットに置かれるため、
分散環境でもJOINがローカルで済む。

### 親を消すと子も消える

`ON DELETE CASCADE` を指定しているので、親を消すと子も消える。

```
gcloud spanner rows delete --table=users \
  --database=test-db --instance=[自分の名前]-spanner --keys=u001

gcloud spanner databases execute-sql test-db \
  --instance=[自分の名前]-spanner --sql="SELECT COUNT(*) FROM orders"
```

```
0
```

### 考えてみてほしいこと

**インターリーブすべきでないのはどんなケースか?**

- 子テーブルが親に対して極端に多い(1親に100万行など)
  → スプリットが分割できず、ホットスポットになる
- 子テーブルを親と関係なく単独で検索することが多い
- 親子の関係が後から変わりうる

インターリーブは「一緒に読むもの」を近くに置く最適化。
使わなくてもJOINはできる。迷ったら使わない方が安全。

## 参考

- [Memorystore for Valkey のネットワーク](https://docs.cloud.google.com/memorystore/docs/valkey/networking)
- [テーブルのインターリーブ](https://cloud.google.com/spanner/docs/schema-and-data-model#create-interleaved-tables)
- [クエリ実行プラン](https://cloud.google.com/spanner/docs/query-execution-plans)
