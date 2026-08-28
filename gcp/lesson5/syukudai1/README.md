# 回答例

## 課題

1. Cloud Run の最小インスタンス数を 1 にして、コールドスタートの有無を比べる
2. 同時リクエスト数を調整して、オートスケールの挙動を見る

## 回答

`cloud_run.tf` を参照。

```hcl
scaling {
  min_instance_count = 1   # 0 → 1
  max_instance_count = 5   # 3 → 5
}

max_instance_request_concurrency = 10   # 既定は80
```

## 課題1: コールドスタート

### min_instance_count = 0 のとき(講義の設定)

リクエストが無い間、インスタンスは0台になる。
次のリクエストが来たときに起動から始まるので、最初の1回だけ遅い。
これが**コールドスタート**。

計測してみる。

```
# しばらく放置してから
curl -s -o /dev/null -w "%{time_total}\n" https://[自分の名前].[勉強会のドメイン]/
```

```
1.8       ← コールドスタート
```

続けてもう一度。

```
0.09      ← 2回目以降は速い
```

### min_instance_count = 1 にすると

常に1台起動しているので、放置後の1回目も速い。

```
0.09
```

### トレードオフ

| | min=0 | min=1 |
|---|---|---|
| コールドスタート | ある(1〜2秒) | ない |
| 課金 | リクエストがある間だけ | 常時 |
| 向いている用途 | 社内ツール、開発環境 | ユーザ向けサービス |

**ゲームのAPIサーバなら min は 1 以上にする。**
夜間にアクセスが途切れて、朝の最初のユーザだけ2秒待たされるのは避けたい。

### AWSとの対比

ECS + Fargate は `desired_count` で台数を指定する固定方式だった。
0台にするとサービスが止まる。「リクエストが来たら起動」という発想がない。

Cloud Run は**リクエスト数に応じて自動で増減**する。
これがサーバレスと呼ばれる所以。

## 課題2: 同時リクエスト数とオートスケール

### max_instance_request_concurrency とは

1つのインスタンスが同時に受けるリクエスト数の上限。既定は 80。

```
同時リクエスト 100件 / concurrency 80  → インスタンス 2台
同時リクエスト 100件 / concurrency 10  → インスタンス 10台
```

**AWSのECSには無い概念。** ECSは「タスク1つ = コンテナ1つ」で、
何リクエストさばくかはアプリ次第だった。

Cloud Run は同時実行数を明示できるので、
「1リクエストが重い処理」なら concurrency を下げて分散させる。

### 負荷をかけて確認する

Cloud Shell から。

```
# 100並列で30秒間
seq 1 3000 | xargs -P 100 -I{} curl -s -o /dev/null https://[自分の名前].[勉強会のドメイン]/
```

インスタンス数の推移を見る。

```
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/instance_count" AND resource.labels.service_name="[自分の名前]-app"' \
  --format=json 2>/dev/null | head -40
```

コンソールの Cloud Run → サービス → 指標 の方が見やすい。

### 見るポイント

- concurrency を 10 にすると、同じ負荷でもインスタンスが増える
- `max_instance_count` に達すると、それ以上は増えずにリクエストが待たされる
- 負荷が止まると、しばらくして `min_instance_count` まで減る

## 参考

- [インスタンスの自動スケーリング](https://cloud.google.com/run/docs/about-instance-autoscaling)
- [最小インスタンス数の設定](https://cloud.google.com/run/docs/configuring/min-instances)
- [同時実行数の設定](https://cloud.google.com/run/docs/configuring/concurrency)
