# 回答例

## 課題

1. Memorystore にリードレプリカを追加する
2. Spanner のインターリーブテーブルにデータを入れて、実行計画を見る

## 課題1: Memorystore のリードレプリカ

`cache.tf` を参照。変更点は3つ。

```hcl
resource "google_redis_instance" "cache" {
  memory_size_gb     = 5                          # 1 → 5 に変更
  tier               = "STANDARD_HA"
  read_replicas_mode = "READ_REPLICAS_ENABLED"    # 追加
  replica_count      = 1                          # 追加
}
```

### ハマりどころ

**リードレプリカは 5GB 以上でないと有効化できない。**
`memory_size_gb = 1` のまま `read_replicas_mode` を付けると apply が失敗する。

AWSのElastiCacheは `cache.t2.micro` でもレプリカを作れたので、
同じ感覚でいると引っかかる。

**tier は STANDARD_HA が必須。** BASIC ではレプリカを持てない。

### 確認方法

```
gcloud redis instances describe [自分の名前]-cache --region=asia-northeast1 \
  --format="yaml(host,readEndpoint,replicaCount,readReplicasMode)"
```

エンドポイントが2つある。

- `host` … 読み書き両方。プライマリに繋がる
- `readEndpoint` … 読み取り専用

読み取り専用エンドポイントに書き込もうとすると拒否される。

```
redis-cli -h [readEndpoint] set foo bar
(error) READONLY You can't write against a read only replica.
```

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

- [読み取りレプリカ](https://cloud.google.com/memorystore/docs/redis/about-read-replicas)
- [テーブルのインターリーブ](https://cloud.google.com/spanner/docs/schema-and-data-model#create-interleaved-tables)
- [クエリ実行プラン](https://cloud.google.com/spanner/docs/query-execution-plans)
