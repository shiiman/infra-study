# 回答例

## 課題

1. Spanner の主キー設計を調べる
2. Spanner になぜフェイルオーバーが無いのかを考える

コードは書かない。調べ物と考察。

---

## 課題1: 主キー設計

### なぜ主キーが重要なのか

Spannerはデータを**主キーの順にソートして保持**し、
一定サイズごとに**スプリット**という単位に分割して複数のサーバに配る。

```
主キー順:  aaa... | bbb... | ccc... | ddd...
           └スプリット1┘└スプリット2┘...
              サーバA      サーバB
```

主キーが連番やタイムスタンプだと、**新しい行が常に末尾に集中する**。
末尾のスプリットを持つサーバ1台に書き込みが集まる。これがホットスポット。

```
連番の場合:  ...997 | 998 | 999 | 1000 ←ここに全部来る
                                   サーバZ だけが忙しい
```

台数を増やしても速くならない。Spannerの利点が消える。

### 避け方

| 方法 | 例 |
|---|---|
| UUID を使う | `user_id STRING(36)` に UUIDv4 |
| ハッシュを先頭に付ける | `shard_id = MOD(FARM_FINGERPRINT(user_id), 100)` |
| 順序を入れ替える | `(user_id, timestamp)` のように分散する列を先頭に |

講義で作った `users` は `user_id STRING(36)` を主キーにしている。
UUIDを入れる前提の設計。

### やってみてほしいこと

公式ドキュメントを読んで、
**自分のプロダクトのテーブルをSpannerに載せるとしたら主キーをどうするか**
を考えてみてください。

- https://cloud.google.com/spanner/docs/schema-design
- https://cloud.google.com/spanner/docs/whitepapers/optimizing-schema-design

### AWSとの対比

DynamoDBのパーティションキーと同じ悩み。
「書き込みが1箇所に集中しないキーを選ぶ」という考え方は共通している。

違うのは、DynamoDBはKVSなのでJOINやトランザクションが限定的なのに対し、
Spannerは普通にSQLが書けてトランザクションも効くこと。

---

## 課題2: なぜ Spanner にフェイルオーバーが無いのか

### Cloud SQL の場合

```
gcloud sql instances failover [インスタンス名]
```

というコマンドがある。

構成は「プライマリ1台 + スタンバイ1台」。
書き込みはプライマリだけが受ける。
プライマリが落ちたら、スタンバイを昇格させる**切り替え作業**が発生する。
その間(60秒程度)は書き込めない。

### Spanner の場合

```
gcloud spanner instances failover   ← このコマンドは存在しない
```

`regional-asia-northeast1` の構成は、3つのゾーンに
**投票権を持つレプリカ**が1つずつ置かれている。

書き込みは Paxos という合意アルゴリズムで、
**過半数(3つのうち2つ)の合意が取れれば成立**する。

```
  ゾーンa [レプリカ] ─┐
  ゾーンb [レプリカ] ─┼─ 2つ以上が生きていれば書き込める
  ゾーンc [レプリカ] ─┘
```

1ゾーンが落ちても、残り2つで過半数が成立する。
**昇格させる作業が要らない**ので、フェイルオーバーという概念自体が無い。

### まとめ

| | Cloud SQL (REGIONAL) | Spanner (regional) |
|---|---|---|
| 構成 | プライマリ + スタンバイ | 3ゾーンに投票権を持つレプリカ |
| 書き込みの成立条件 | プライマリが生きている | 過半数の合意 |
| ゾーン障害時 | 切り替え(60秒程度) | そのまま継続 |
| 運用の手間 | 切り替えを意識する | 意識しない |

**Spannerが高い理由の一部がこれ。「止まらないこと」にお金を払っている。**

### さらに調べてみたい人へ

- リージョン構成では、実は3つのうち1つは
  **読み取り専用レプリカではなく「ウィットネス」**である構成もある
- マルチリージョン構成では、レプリカの役割がさらに細かく分かれる
  (読み書きレプリカ / 読み取り専用レプリカ / ウィットネスレプリカ)

- https://cloud.google.com/spanner/docs/replication
- https://cloud.google.com/spanner/docs/instance-configurations

## 参考

- [Spanner のスキーマ設計](https://cloud.google.com/spanner/docs/schema-design)
- [Spanner のレプリケーション](https://cloud.google.com/spanner/docs/replication)
- [Cloud SQL の高可用性](https://cloud.google.com/sql/docs/mysql/high-availability)
