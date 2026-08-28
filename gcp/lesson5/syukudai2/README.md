# 回答例

## 課題

1. Cloud Run のログとメトリクスを見て、コンテナの中で何が起きているかを調べる
2. VM(第3回・第4回で使ったもの)と Cloud Run のどちらを選ぶかを考える

コードは書かない。調べ物と考察。

---

## 課題1: コンテナの中をどう見るか

### AWSでは ECS Exec でコンテナに入れた

```
aws ecs execute-command --cluster xxx --task xxx --container app \
  --interactive --command "/bin/sh"
```

シェルに入って `ps aux` や `env` を確認できた。

### Cloud Run には相当する機能が無い

Cloud Run のインスタンスにシェルで入る方法は提供されていない。
「入って調べる」のではなく「**外から観測する**」やり方に切り替える必要がある。

これは制約ではなく設計思想の違い。
インスタンスは使い捨てで、いつ消えてもよいものとして扱う。

### 代わりに使うもの

**ログ**

```
gcloud run services logs read [自分の名前]-app --region=asia-northeast1 --limit=20
```

構造化ログ(JSON)で出力すると、フィールドで検索できる。

```
gcloud logging read \
  'resource.type="cloud_run_revision" AND resource.labels.service_name="[自分の名前]-app"' \
  --limit=10 --format=json
```

**メトリクス**

コンソールの Cloud Run → サービス → 指標 で見られる。

- リクエスト数 / レイテンシ / エラー率
- インスタンス数
- CPU使用率 / メモリ使用率
- コンテナの起動レイテンシ(コールドスタートの実測)

### やってみてほしいこと

1. 何度かアクセスしてからログを読む
2. 環境変数がどう渡っているかをアプリのログから確認する
   (`env` が打てないので、必要ならアプリ側でログに出す設計にする)
3. メトリクスでコールドスタートの発生を確認する

**「入れないなら、必要な情報はログに出す」**という発想に切り替わる。
これはコンテナ運用の基本でもある。

第8回(監視・運用)でログの読み方を詳しくやります。

### デバッグしたいときは

ローカルで同じイメージを動かす。

```
docker run -p 8080:8080 \
  -e DB_KIND=spanner -e SPANNER_DATABASE=... \
  [イメージ]
```

Cloud Run で動くものと同じイメージなので、
「本番でだけ動かない」が起きにくい。これもコンテナの利点。

---

## 課題2: VM と Cloud Run のどちらを選ぶか

第3回・第4回では VM の上で `docker run` していた。
第5回で Cloud Run に移した。何が変わったかを整理してほしい。

### 消えたもの

| 第3回・第4回でやっていたこと | Cloud Run では |
|---|---|
| VMを作る | 不要 |
| OSのパッチ当て | 不要 |
| Docker のインストール | 不要 |
| systemd で自動起動(第3回 宿題1) | 不要 |
| インスタンスグループを作る | 不要 |
| ヘルスチェックを作る | 不要 |
| 130.211.0.0/22 の Firewall Rule(第3回のハマりどころ) | 不要 |
| 冗長化のために2台目を作る(第3回 宿題2) | 不要(自動) |
| スケールアウトの設定 | 属性1つ |

### 増えたもの・制約

| | 内容 |
|---|---|
| コンテナに入れない | ログとメトリクスで見る |
| VPCに繋ぐのに設定が要る | Direct VPC egress |
| 実行時間の上限 | 既定5分、最大60分 |
| 常駐プロセスが置けない | バッチは Cloud Run Jobs |
| コールドスタート | min_instance_count で回避(課金は増える) |

### 判断軸

**Cloud Run が向いているもの**

- HTTPリクエストに応答するWebアプリ・API
- アクセスに波がある
- 運用の手間を減らしたい

**VM(Compute Engine)が向いているもの**

- 常駐プロセス、長時間バッチ
- 特定のOS設定・カーネルパラメータが必要
- GPUを使う(Cloud Runでも使えるが制約がある)
- ライセンスの都合でインスタンスに紐づける必要がある

**GKE が向いているもの**

- 複数サービスを細かく制御したい
- Kubernetes のエコシステム(Istio、Argo CDなど)を使いたい
- 既にKubernetesの運用ノウハウがある

### 考えてみてほしいこと

**自分が担当しているサービスは、どれに載せるのが妥当か?**

「全部Cloud Runにできるか」を考えてみると、
たいてい1つか2つ「これは無理」というものが出てくる。
それが VM や GKE を残す理由になる。

## 参考

- [Cloud Run のログ](https://cloud.google.com/run/docs/logging)
- [Cloud Run のモニタリング](https://cloud.google.com/run/docs/monitoring)
- [Cloud Run vs GKE の選び方](https://cloud.google.com/hosting-options)
- [Cloud Run Jobs](https://cloud.google.com/run/docs/create-jobs)
