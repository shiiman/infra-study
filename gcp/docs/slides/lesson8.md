# 第8回 インフラ勉強会(GCP) — 監視・運用 + その他リソース

- **開催日**: 2027-03-01(月) 2時間
- **AWS版対応**: 第11回(その他・まとめ)+ **AWS版に無かった監視回**
- **Terraformコード**: `gcp/lesson8/`
- **ゴール**: ダッシュボードを作り、しきい値超過で Slack に通知が飛ぶ状態にする

> **この回の軸は「気づけるかどうか」。**
> ここまでの7回は「作る」話だった。今日は「作ったものが壊れたとき、
> どうやって気づくか」をやる。
> 監視は入れれば終わりではなく、**鳴ったら人が動くものだけを鳴らす**
> という設計がいる。

> **AWS版アンケートの「インフラの設計についてはまだ理解が及ばなかった」
> という声に応える回**として設計している。
> 個々のサービスではなく、**組み合わせて運用する話**をする。

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入 | 5分 | S01〜S04 |
| 監視の考え方 | 18分 | S05〜S12 |
| **監視ツールの使い分け(Datadog)** | 4分 | S12b〜S12c |
| 休憩 | 5分 | S13 |
| 準備 + Step1(ログ) | 20分 | S14〜S21 |
| Step2(ダッシュボード + 外形監視) | 23分 | S22〜S28 |
| Step3(アラート → Slack) | 18分 | S29〜S35 |
| その他リソース(Pub/Sub → BigQuery 含む) | 12分 | S36〜S39 |
| **料金と規模の見積もり** | 6分 | S39b〜S39d |
| まとめ・宿題 | 9分 | S40〜S48 |

> **待ち時間**
> - S15 `0. before` の apply: 約10分(第6回の完成状態、38リソース)
> - S26 Uptime check の反映: 数分。作った直後は結果が出ない
> - S33 アラートの発火: **約7分**(実測。`duration = 300s` + 評価の遅れ)
>
> **`0. before` を最初に流してから監視の話に入る構成にしてある。**
>
> 押した場合の削り所: S36〜S39(その他リソース)は口頭のみで圧縮できる。
>
> **削ってはいけないのは S08**(監視の3つの柱)、
> **S11**(何を鳴らすか)、**S28〜S31**(気づけない → 通知を繋ぐ)。この回の核心。

## 事前準備(講師)

### 1. ★ Slack 通知チャンネルを作る

**ブラウザでの作業。コードにはできない。**

Cloud Monitoring から Slack に投げるには、Slack 側で
「Google Cloud Monitoring」アプリを認可して `auth_token` を受け取る必要がある。
第7回の GitHub App と同じ形。

コンソール → **Monitoring → アラート → 通知チャンネルを管理**
→ **Slack** → 「新規追加」→ Slack の認可画面で投稿先チャンネルを選ぶ
→ 表示名を付けて保存。

**受講者に渡す値**

```
gcloud beta monitoring channels list --project=[プロジェクトID] \
  --filter='type="slack"' --format="table(displayName,labels.channel_name)"
```

表示名を `terraform.tfvars` の `notification_channel_name` に貼らせる。

> **★ 全員のアラートが同じチャンネルに飛ぶ。**
> 当日はにぎやかになるので、勉強会専用のチャンネルにしておくこと。

### 2. 受講者ロールに1つ追加する

`roles/logging.configWriter` を足す(**12個目**)。

監視まわりはほとんど `roles/editor` で足りるが、
**ログルーター系(シンク・除外・ログバケット)だけが入っていない。**

| 必要な権限 | どこにあるか |
|---|---|
| `monitoring.dashboards.create` / `alertPolicies.create` / `notificationChannels.create` | `roles/editor` |
| `monitoring.uptimeCheckConfigs.create` / `services.create` / `slos.create` | `roles/editor` |
| `logging.logMetrics.create` | `roles/editor` |
| **`logging.sinks.create` / `exclusions.create` / `buckets.create`** | **`roles/logging.configWriter`** |

### 3. API の追加は不要

Cloud Monitoring / Cloud Logging は既定で有効。

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない

---

# 導入

---

### S01 | タイトル

**[図版]** AWS版 第11回 表紙を複製。タイトルを差し替え。

**[本文]**

```
第8回 インフラ勉強会(GCP)

〜 監視・運用 編 〜

2027年3月1日
```

---

### S02 | ロードマップ

**[図版]** 第1回 S02 と同じスライドを複製。今日の行(3月1日)にマーカーを移す。

---

### S03 | 前回の振り返り

**[本文]**

```
◼前回やったこと

GitHub に push すると自動でビルド・デプロイされるようにした
デプロイには権限が2つ要った
  roles/run.developer          デプロイ先を更新する
  roles/iam.serviceAccountUser 実行SAになりすます
Terraform と CI/CD の責務を分けた
  インフラの形は Terraform、動かすバージョンは CI/CD

★ これで「作って、届ける」までが揃いました
★ 今日は「届けたあと、どう見るか」です
```

---

### S04 | 今日やること

**[図版]** **新規作成**。ログ・メトリクス・アラートの流れ。

```
   [Cloud Run / LB / Spanner / ...]
        │              │
     ログ           メトリクス
        │              │
        ▼              ▼
  [Cloud Logging]  [Cloud Monitoring]
        │              │
        │  ログベース指標 │
        └──────────────▶│
                       ├── ダッシュボード  (人が見に行く)
                       └── アラートポリシー (人に知らせに行く)
                              │
                              ▼
                          [Slack]
```

**[本文]**

```
◼壊れたときに気づける状態を作ります

  1. ログを見る / ログから指標を作る
  2. ダッシュボードで「いつも見る場所」を作る
  3. しきい値を超えたら Slack に飛ばす

★ 今日は最後に、わざと壊して Slack を鳴らします
```

---

# 監視の考え方

---

### S05 | なぜ監視するのか

**[本文]**

```
◼監視していないと、どうなるか

  ユーザからの問い合わせで障害を知る
  いつから壊れていたか分からない
  直したつもりが直っていないことに気づかない

◼監視の目的は2つだけ

  1. 壊れたことに気づく
  2. 原因を絞り込む

★ 「全部のグラフを並べる」ことが目的ではありません
★ 見ても何もしないグラフは、無いのと同じです
```

**[話す]** ここは強調したい。ダッシュボードにグラフを100個並べても、
障害のときに見るのは3つくらい。それ以外は判断を遅らせるだけ。

---

### S06 | 第5回で言ったことの回収

**[本文]**

```
◼第5回で、こう言いました

  「Cloud Run には インスタンスに入る 概念がありません」

  ECS Exec のようにコンテナへ入って調べる、ができない

◼では、どうやって中を見るのか

  ログとメトリクスで見る

  → 入れないからこそ、
     **出しておくもの**を設計する必要がある

★ サーバレスになるほど、監視の設計が効いてきます
```

---

### S07 | 3種類のデータ

**[図版]** **新規作成**。ログ / メトリクス / トレースの違い。

**[本文]**

```
                何が分かるか            量        いつ見るか
────────────────────────────────────────────────────────────
ログ        1つ1つの出来事の詳細      多い      原因を調べるとき
メトリクス  数の推移                  少ない    いつも / 異常検知
トレース    1リクエストの内訳         中くらい  遅い原因を探すとき

◼使い分け

  「なんか遅い」          → メトリクスで範囲を絞る
  「このリクエストが遅い」 → トレースでどこが遅いか見る
  「なぜ失敗した」        → ログで詳細を見る

★ ログだけでも運用はできますが、量が多くて高い
★ メトリクスだけだと原因が分かりません
```

---

### S08 | GCPの監視サービス ★

**[図版]** **新規作成**。この回の最重要図その1。AWSとの対応。

```
   AWS                          GCP

   CloudWatch Logs         →   Cloud Logging
   CloudWatch Metrics      →   Cloud Monitoring
   CloudWatch Alarms       →   Cloud Monitoring のアラートポリシー
   CloudWatch Dashboards   →   Cloud Monitoring のダッシュボード
   X-Ray                   →   Cloud Trace
   (相当なし)              →   Error Reporting
   Route53 ヘルスチェック   →   Uptime check
   (相当なし)              →   SLO モニタリング
```

**[本文]**

```
◼名前が違うだけのものが多い

  AWSは全部 CloudWatch という1つの名前だった
  GCPは Logging と Monitoring に分かれている

◼GCPにあってAWSに無いもの

  Error Reporting  例外を自動でまとめてくれる
  SLO モニタリング  「あと何回失敗してよいか」で見る

★ 逆にAWSにあってGCPに無いもの、はほぼありません
```

---

### S09 | Cloud Logging

**[本文]**

```
◼GCPのログは、黙っていても集まる

  Cloud Run / ロードバランサ / Cloud Build ...
  ほとんどのサービスが自動でログを出す

  アプリは標準出力に書くだけでよい
  (第5回のアプリも fmt.Fprintf しかしていない)

◼探し方

  gcloud logging read 'resource.type="cloud_run_revision"' --limit=10

  コンソールの「ログエクスプローラ」のほうが速い
  検索してから gcloud に写すのが実務的

◼保持期間

  既定30日。それ以上持ちたければシンクで外に出す(Step1)
```

---

### S10 | Cloud Monitoring

**[本文]**

```
◼メトリクスも、黙っていても集まる

  Cloud Run   リクエスト数 / レイテンシ / インスタンス数 / CPU / メモリ
  ロードバランサ リクエスト数 / レイテンシ / バックエンドの健全性
  Spanner     CPU使用率 / ストレージ / レイテンシ

◼指標の名前

  run.googleapis.com/request_count
  loadbalancing.googleapis.com/https/request_count
  spanner.googleapis.com/instance/cpu/utilization

  「サービス名/何の数字か」という形

★ 名前が分からないときは、コンソールで
   グラフを作ってから JSON を見るのが速い
```

---

### S11 | 何を鳴らすか ★

**[図版]** **新規作成**。この回の最重要図その2。

```
                  鳴らす？    どこに置く？
   ───────────────────────────────────────────
   サイトが落ちた      ◯      アラート(すぐ対応)
   エラー率が急増      ◯      アラート
   ディスクが90%       ◯      アラート(明日でよい)
   ───────────────────────────────────────────
   CPU使用率           ×      ダッシュボード
   リクエスト数        ×      ダッシュボード
   レイテンシの推移    ×      ダッシュボード
```

**[本文]**

```
◼鳴らす基準は1つだけ

  **鳴ったら人が何かするか**

  見るだけで何もしないなら、ダッシュボードに置く

◼CPU使用率90%は鳴らすべきか

  → それ自体では何もしない。鳴らさない
  → 「CPUが高くて応答が遅い」なら、遅いほうを鳴らす

  ★ 原因ではなく、症状を鳴らす

◼鳴りすぎるアラートは、無いより悪い

  「またあれか」と思われた時点で、そのアラートは死んでいる
  本当に必要なときに気づけなくなる

★ アラートは増やすより減らすほうが難しい
```

**[話す]** ここが今日一番大事なところ。
アラートを作るのは簡単で、消すのは難しい。
「とりあえず入れておく」を繰り返すと、3年後に誰も見ないSlackチャンネルができる。

---

### S12 | 症状で鳴らす、原因は調べる

**[本文]**

```
◼症状(ユーザに影響があること)

  サイトが開かない
  遅い
  エラーが返る

  → これを鳴らす

◼原因(内部の状態)

  CPUが高い
  メモリが足りない
  DBのコネクションが枯渇

  → これはダッシュボードとログで調べる

★ 原因を全部アラートにすると、鳴りっぱなしになります
★ 症状は数が少ないので、アラートも少なくて済みます
```

---

### S12b | GCP の監視だけで足りるのか ★

**[図版]** **新規作成**。1つのシステムに対して、
GCPの監視(Cloud Monitoring / Logging)と SaaS の監視(Datadog)が
両側から見ている図。真ん中にアプリ、左右から矢印。

```
                    [Cloud Run / LB / Spanner]
                      │                  │
        メトリクス・ログ │                  │ エージェント / API
                      ▼                  ▼
          [Cloud Monitoring]        [Datadog]
           GCPのことは全部見える      GCP以外もまとめて見える
```

**[本文]**

```
◼社内では Datadog を使っているプロダクトもあります

  ghost では Datadog を使っています

◼なぜ両方あるのか

  Cloud Monitoring   GCPのリソースは、何も入れなくても見える
                     GCPの外は見えない

  Datadog            GCP / AWS / オンプレ / SaaS を1つの画面で見られる
                     APM(アプリ内部の追跡)が強い
                     入れる手間と、料金がかかる

◼複数のクラウドやオンプレが混ざると、Cloud Monitoring だけでは足りません

  「このリクエストが遅い」を追うのに、
  GCPの画面とAWSの画面を行き来することになる

★ 今日やった考え方(症状を鳴らす / 平均でなく95%ile / 通知先は別リソース)は
   どちらでも同じです。道具が変わるだけです
```

**[話す]** 「GCPを勉強したのにDatadogの話?」と思われないように、
先に「考え方は同じ」と言ってから入る。
道具の名前ではなく、何をどう見るかが本題であることを強調する。

> **制作TODO**: ghost での Datadog の使い方(どのメトリクスを見ているか、
> アラートの分け方、Cloud Monitoring とどう併用しているか)を確認し、
> 実例を1枚足すこと。「うちだとこう」が入ると一気に実感が湧く。

---

### S12c | 道具が変わっても同じところ

**[図版]** 表。左に「今日やること(GCP)」、右に「Datadog だと」。

**[本文]**

```
                        Cloud Monitoring        Datadog
────────────────────────────────────────────────────────────
メトリクスの取得         自動(GCPリソース)        Integration を有効化
ログ                    Cloud Logging           Log Management
ダッシュボード            ダッシュボード            Dashboard
アラート条件             アラートポリシー          Monitor
通知先                  通知チャンネル            Notification (Slack など)
外形監視                 Uptime check            Synthetic Monitoring
分散トレース             Cloud Trace             APM
SLO                     SLO モニタリング          SLO

◼名前が違うだけで、構造は同じです

  「いつ鳴らすか」と「どこに鳴らすか」が分かれているのも同じ

★ 片方を覚えれば、もう片方はドキュメントを見れば書けます
★ 大事なのは、どのメトリクスを、どのしきい値で見るかの判断です
```

---

### S13 | 休憩

**[本文]**

```
5分休憩

後半はハンズオンです
```

---

# 準備と Step1

---

### S14 | 準備

**[本文]**

```
◼Cloud Shell を立ち上げる

◼作業ディレクトリを作る
  mkdir -p ~/works/lesson8
  cd ~/works/lesson8

◼サンプルコードを更新
  cd ~/infra-study && git pull
  cd ~/works/lesson8

★★ 第7回のリソースは destroy 済みですか ★★

  gcloud compute networks list
  gcloud compute addresses list --filter="purpose=SERVERLESS"
```

---

### S15 | 前回までの完成状態を読み込む

**[本文]**

```
参照: gcp/lesson8/1. logging/before.tf

module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson8/0. before"
  ...
}

◼中身は第2回〜第6回で作ったもの(38リソース)

  terraform init
  terraform apply

★ 10分ほどかかります。先に流してから解説に入ります

★★ 第7回の CI/CD は入れていません ★★

   「積み上げ」は原則ですが、
   ビルドトリガーがあってもなくても監視の話は変わりません
   変数が1つ増える分だけ邪魔になるので外しました

   その回に関係ないものまで積む必要はありません
```

---

### S16 | ログを見る

**[本文]**

```
◼まずコンソールで見てみましょう

  Cloud Logging → ログエクスプローラ

  resource.type="cloud_run_revision"
  resource.labels.service_name="[自分の名前]-app"

◼gcloud でも見られます

  gcloud logging read \
    'resource.type="cloud_run_revision"
     resource.labels.service_name="[自分の名前]-app"' \
    --limit=10 --format="value(timestamp,textPayload)"

★ 検索はコンソール、確認は gcloud、が実務的です
★ コンソールで作ったクエリはそのまま Terraform に貼れます
```

---

### S17 | ログベース指標

**[本文]**

```
参照: gcp/lesson8/1. logging/logging.tf

resource "google_logging_metric" "app_error" {
  name = "${var.user_name}-app-error"

  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${module.before.cloud_run_name}"
    textPayload:"失敗"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

◼ログから「数」を作る

  条件に合うログを数えて、メトリクスにする
  作った指標はダッシュボードにもアラートにも使える

◼なぜ要るのか

  Cloud Run はリクエスト数やエラー率を出してくれる
  でも **アプリが何をしたか** は出してくれない

    「DB接続に失敗した回数」
    「決済が失敗した回数」

  これはログにしかない。その穴を埋めるのがログベース指標

★ AWSの CloudWatch Logs メトリクスフィルタと同じ考え方
```

---

### S18 | ログルーター(シンク)

**[本文]**

```
resource "google_logging_project_sink" "app_logs" {
  name        = "${var.user_name}-app-logs"
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"

  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${module.before.cloud_run_name}"
  EOT

  unique_writer_identity = true
}

◼ログは黙っていると30日で消える

  それより長く持ちたい / 別の場所で分析したい
  → シンクで外に流す

◼流し先の選び方

  Cloud Storage  安い。長期保存・監査ログ向け
  BigQuery       SQLで分析できる
  Pub/Sub        他システムへリアルタイムに渡す

★ 今回は Cloud Storage
   「とりあえず消えないようにする」が一番多い用途
```

---

### S19 | シンクは作っただけでは動かない ★

**[本文]**

```
resource "google_storage_bucket_iam_member" "sink_writer" {
  bucket = google_storage_bucket.logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.app_logs.writer_identity
}

◼シンクは専用のサービスアカウントで書き込む

  unique_writer_identity = true にすると
  Google がそのSAを用意し、writer_identity に入れてくれる

◼そのSAに書き込み権限を付けないと、何も流れない

  ★ しかも **エラーが出ません** ★

  「シンクは作ったのにバケットが空のまま」
  という状態になり、気づくのに時間がかかります

★ 第7回の「権限が2つ要る」と同じ構図
★ ただしこちらは失敗しても静かなので、余計にたち悪い

★★ さらに厄介なこと ★★

   Cloud Storage への書き込みは1時間ごとのバッチで、
   最初のログが出るまで2〜3時間かかります

   つまり「バケットが空」のとき、原因が
     権限不足なのか
     まだ書き込まれていないだけなのか
   **見た目では区別できません**

   → 先に writer_identity の権限を確認する癖をつける
```

**[話す]** これは実際にハマる。シンクを作って満足して、
半年後に「監査ログが1件も無い」と気づくパターン。

---

### S20 | Step1 実行

**[本文]**

```
  terraform plan
  terraform apply

◼確認
  terraform output log_metric_name
  terraform output log_bucket_name
  terraform output sink_writer_identity
  → serviceAccount:service-....@gcp-sa-logging.iam.gserviceaccount.com

◼ログバケットの中を見てみる
  gcloud storage ls --recursive gs://[ログバケット]/

  → 今日は **空のままです**

★★ Cloud Storage へのエクスポートは1時間ごとのバッチ ★★

   最初のログが現れるまで **2〜3時間** かかります
   講義中には確認できません

   ファイルはこう並びます
     [バケット]/[ログID]/YYYY/MM/DD/08:00:00_08:59:59_S0.json

★ 「シンクを作ったのにバケットが空」は
   権限不足のときも、単に待ち時間のときも同じ見え方です
   **切り分けは writer_identity の権限を先に確認する**
```

---

### S21 | ログベース指標に数字が入るまで

**[本文]**

```
◼指標は「作ってから出たログ」しか数えません

  過去のログはさかのぼって数えられない

◼今すぐ数字を出したい場合

  アプリにアクセスして「失敗」ログを出させる
  → 今は全部成功しているので、まだ0のままです

★ 宿題2で、この指標を使ったアラートを作ります
★ Step2 のダッシュボードにも並べます(最初は0)
```

---

# Step2: ダッシュボードと外形監視

---

### S22 | Uptime check(外形監視)

**[本文]**

```
参照: gcp/lesson8/2. monitoring/monitoring.tf

resource "google_monitoring_uptime_check_config" "web" {
  display_name = "${var.user_name}-uptime"
  period       = "60s"
  timeout      = "10s"

  http_check {
    path         = "/this-path-does-not-exist"   ← ★ わざと
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = module.before.web_domain
    }
  }

  selected_regions = ["ASIA_PACIFIC", "USA_OREGON", "EUROPE"]
}

◼「外から見て生きているか」を確かめる

  Cloud Run のメトリクスは
  「リクエストが来たときに何が起きたか」しか分からない

  リクエストが0件のとき、それが
    「誰も使っていない」のか「繋がらない」のか
  区別できない

  Uptime check は Google が世界の複数拠点から定期的に叩くので、
  **誰も使っていない時間帯でも壊れていることに気づけます**

★ AWSの Route53 ヘルスチェック / CloudWatch Synthetics に相当
```

---

### S23 | わざと壊しています

**[本文]**

```
  path = "/this-path-does-not-exist"

◼存在しないパスに向けています

  すぐ失敗する状態を作って、
  「監視しているのに誰も気づかない」を体験するためです

  Step3 でアラートを繋いだあと、正しいパスに戻します

★ 本番でこれをやると、当然ずっと鳴り続けます
```

---

### S24 | ダッシュボード

**[本文]**

```
resource "google_monitoring_dashboard" "app" {
  dashboard_json = jsonencode({ ... })
}

◼JSON で書きます

  Terraform 側は文字列を渡すだけ
  中身は Cloud Monitoring のダッシュボード定義そのもの

◼一から JSON を書く人はいません

  1. コンソールで画面を作る
  2. 「JSON エディタ」でコピーする
  3. Terraform に貼って変数化する

  この順番が速いです

★ jsonencode を使うと HCL で書けるので、
   変数を埋め込むのが楽になります
```

---

### S25 | 何を並べるか ★

**[図版]** **新規作成**。4枚のタイル配置と、それぞれが何を答えるか。

**[本文]**

```
◼「まず見るもの」を左上から並べます

  1. 外形監視の成否        → 外から生きているか
  2. リクエスト数           → どれだけ来ているか
  3. レイテンシ(95%ile)   → 遅くなっていないか
  4. アプリのエラー数       → 中で失敗していないか

◼1〜3が「外から見た様子」、4が「中の様子」

  この2種類を並べておくと、障害のとき切り分けが速い

    外は正常・中でエラー → アプリの問題
    外が異常・中は静か   → 手前(LB/DNS/証明書)の問題

★ 平均ではなく95パーセンタイルを見る
   平均は「一部だけ極端に遅い」を隠してしまいます
```

---

### S26 | Step2 実行

**[本文]**

```
  terraform plan
  terraform apply

◼ダッシュボードを見る
  コンソール → Monitoring → ダッシュボード
  → 「[自分の名前] インフラ勉強会」

★ Uptime check の結果が出るまで数分かかります
   作った直後はグラフが空です

◼Uptime check の結果
  コンソール → Monitoring → 稼働時間チェック

  → しばらくすると **失敗** になります
```

---

### S27 | 失敗しているのが見える

**[図版]** ダッシュボードのスクリーンショット。
**開催前に実物を撮ること**(外形監視のタイルが0のまま)。

**[本文]**

```
◼外形監視のグラフが 0 のままです

  1 = 成功、0 = 失敗

  存在しないパスを叩いているので、当然失敗しています

◼リクエスト数のグラフには 404 が並びます

★ 見れば分かる。でも……
```

---

### S28 | 誰も見ていない ★

**[本文]**

```
◼このダッシュボード、誰が見ますか

  障害に気づいてから見に来るなら、
  気づくのはユーザからの問い合わせです

◼ダッシュボードは「調べる」ための道具

  「気づく」ためには、向こうから知らせに来る必要がある

  → アラートポリシー

★ ダッシュボードを作っただけでは、監視したことになりません
```

**[話す]** ここが今日の折り返し。
「監視を入れた」と言いながらダッシュボードしか無い現場は多い。

---

# Step3: アラート

---

### S29 | 通知チャンネルとアラートポリシー

**[図版]** **新規作成**。ポリシーとチャンネルが分かれている図。

**[本文]**

```
◼2つに分かれています

  アラートポリシー   いつ鳴らすか
  通知チャンネル     どこに鳴らすか

◼分かれていると何がうれしいか

  1つのポリシーに複数のチャンネルを付けられる
    → 「Slack と メール の両方に」

  重大度で使い分けられる
    → 「昼はSlack、深夜はPagerDuty」

★ AWSの CloudWatch Alarms + SNS トピックと同じ構造です
```

---

### S30 | Slack 連携は講師が用意しています

**[本文]**

```
data "google_monitoring_notification_channel" "slack" {
  display_name = var.notification_channel_name
}

◼Slack に投げるには auth_token が要ります

  Slack 側で「Google Cloud Monitoring」アプリを認可して受け取る
  → ブラウザでの作業。Terraform には書けません

◼第7回の GitHub 連携と同じ形です

  講師が1回だけ認可して通知チャンネルを作ってあります
  受講者は表示名で参照するだけ

★ terraform.tfvars に表示名を貼ってください

★ メール通知は auth_token が要らないので自分で作れます
   → 宿題2でやります
```

---

### S31 | アラートポリシー

**[本文]**

```
resource "google_monitoring_alert_policy" "uptime" {
  display_name = "${var.user_name} 外形監視が失敗"
  combiner     = "OR"

  conditions {
    condition_threshold {
      filter = "... uptime_check/check_passed ..."

      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "300s"      ← ★ ここが大事

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_FRACTION_TRUE"
      }
    }
  }

  notification_channels = [data.google_monitoring_notification_channel.slack.name]
}

◼duration = 300s の意味

  「その状態が5分続いたら」鳴らす

  1拠点が一瞬失敗しただけで鳴らすと、うるさくて誰も見なくなる
  **鳴らさない工夫**のほうが、しきい値より大事なことが多い

★ ALIGN_FRACTION_TRUE で「成功した割合」になります
   1未満 = どこかの拠点で失敗した
```

---

### S32 | documentation を書く ★

**[本文]**

```
  documentation {
    mime_type = "text/markdown"
    content   = <<-EOT
      ## [自分の名前] のサイトが外から見えなくなっています

      **確認すること**
      1. ブラウザで https://... を開く
      2. Cloud Run のログを見る
         gcloud logging read '...' --limit=20
      3. ダッシュボードでリクエスト数とエラー数を見る

      **よくある原因**
      - Cloud Run のリビジョンが起動に失敗している
      - ロードバランサのバックエンドが不健全
    EOT
  }

◼★ ここをちゃんと書くかで、対応の速さが変わります ★

  夜中に叩き起こされた人が最初に見るのがこの文章

  「何が起きたか」だけでなく
  「まず何を見ればいいか」 を書いておく

★★ Slack は Markdown を解釈しません ★★

   mime_type = "text/markdown" と書いても、
   Slack には ## や ** が **文字のまま** 出ます
   (コンソールの画面では整形されます)

   通知が届く先は Slack なので、
   **記号を使わず素のテキストで書く**のが正解

     × ## サイトが見えません / **確認すること**
     ◯ サイトが見えません   / 確認すること

★ アラートを作るとき、ここを空にしない
★ 書けないなら、そのアラートは要らないかもしれません
```

**[話す]** 「まず何を見るか」が書けないアラートは、
作った本人しか対応できない。それは運用として弱い。

---

### S33 | Step3 実行 → Slack が鳴る

**[図版]** Slack の通知画面。**開催前に実物のスクリーンショットを撮ること**。

**[本文]**

```
  terraform plan
  terraform apply

★ 5分ほどで Slack に飛びます
   duration = 300s なので、それより早くは鳴りません

◼Slack に届く内容(実測)

  [自分の名前] 外形監視が失敗

  Check passed for ... Uptime Check URL labels {...} with metric
  labels {check_id=...} is below the threshold of 1.000
  with a value of 0.389.

  Alert open   No severity

  Documentation
  (ここに documentation の文章がそのまま出る)

  View alert  ← コンソールへのリンク

★ 「0.389」は成功した拠点の割合です
   3拠点中1つだけ一時的に通った、という状態

★ 全員分が同じチャンネルに飛ぶので、にぎやかになります
```

---

### S34 | 直す

**[本文]**

```
◼監視対象の文字列を正しく直します

  gcp/lesson8/3. alert/monitoring.tf

    content = "ALL SYSTEMS NORMAL"
    ↓
    content = "DB接続"

  terraform apply

★ 5分ほどで Slack に「解決」の通知が届きます

★★ 宿題をやるときの注意 ★★

   宿題のディレクトリ(syukudai1〜3)にも monitoring.tf が入っていて、
   そちらは **"ALL SYSTEMS NORMAL" のまま**です

   宿題を apply すると、せっかく直した設定が戻ってアラートが再発します
   宿題側でも同じ1行を直してください

   → 「積み上げディレクトリは、前のステップで手で直した変更を
      持っていない」というのは、この勉強会で何度も出てくる注意点です

◼auto_close = 1800s

  障害が直ってもインシデントが開いたままだと、
  次の障害で鳴らないことがあります
  既定は7日。短めにしておくのが安全です
```

---

### S35 | ここまでの到達点

**[図版]** S04の構成図を再掲し、全要素にチェックを付ける。

**[本文]**

```
◼できたこと

ログを検索し、ログから指標を作った
ログを Cloud Storage に流して消えないようにした
外形監視で「外から見て生きているか」を測った
ダッシュボードで「いつも見る場所」を作った
しきい値超過で Slack に通知が飛ぶようにした
通知に「まず何を見るか」を書いた
```

---

# その他リソース

---

### S36 | まだ触っていないもの

**[本文]**

```
◼この勉強会で扱わなかった主要サービス

  Cloud Run functions   イベントで動く小さな処理
  Batch                 バッチジョブの実行基盤
  BigQuery              データ分析基盤
  Pub/Sub               メッセージング
  Cloud Tasks           非同期タスクのキュー
  Memorystore以外のDB   Bigtable / Firestore / AlloyDB

★ 全部は無理なので、よく使う3つだけ触れます
```

---

### S37 | Cloud Run functions

**[本文]**

```
◼旧 Cloud Functions。今は Cloud Run の一部

  第5回でやった Cloud Run と同じ基盤の上で動く
  違いは「コンテナを作らなくていい」こと

  ソースコードを渡すと、勝手にビルドしてくれる

◼何に使うか

  イベントで動く小さな処理
    Cloud Storage にファイルが置かれたら変換する
    Pub/Sub にメッセージが来たら通知する
    HTTPで叩かれたら何か返す

★ AWSの Lambda に相当
★ 「Cloud Run functions」と「Cloud Run」は今や地続き
   最初から Cloud Run で書いても困りません
```

---

### S38 | Batch と BigQuery

**[本文]**

```
◼Batch

  バッチ処理を動かす基盤
  VMを立てて、処理して、落とすまでを面倒見てくれる

  Cloud Run は最大60分。それを超える処理はこちら

  ★ AWSの AWS Batch に相当

◼BigQuery

  データ分析基盤。SQLで巨大なデータを集計できる

  今日のシンクの流し先にも選べました
    → ログをSQLで分析したいならこちら

  ★ AWSの Athena / Redshift に相当

★ どちらも「使う側」になることが多いサービスです
   インフラとして構築するより、繋ぎ方を知っておくとよい
```

---

### S38b | ログを BigQuery に貯める ★

**[図版]** **新規作成**。2つの経路の比較。
上が「Cloud Logging のシンク → BigQuery」、
下が「アプリ → Pub/Sub → BigQuery」。
下はさらに2つに枝分かれ(BigQuery サブスクリプション / Dataflow)。

```
  ① GCPのログを貯める
     [Cloud Logging] ──シンク──▶ [BigQuery]      今日 Step1 でやったやつ

  ② アプリのイベントを貯める
     [アプリ] ──▶ [Pub/Sub] ─┬─ BigQuery サブスクリプション ─▶ [BigQuery]
                              └─ [Dataflow] ──加工──────▶ [BigQuery]
```

**[本文]**

```
◼①は今日やりました

  ログルーターのシンク先に BigQuery を選ぶだけ
  GCPのログ(監査ログ / Cloud Run のログ)はこれで貯まります

◼②はアプリが出すイベントを貯めたいとき

  ゲームのプレイログ、行動ログなど
  Cloud Logging を経由させると量とコストが厳しい

  そこで Pub/Sub に流して、そこから BigQuery に入れます

◼Pub/Sub から BigQuery への入れ方は2つ

  BigQuery サブスクリプション
    Pub/Sub の設定だけで直接書き込まれる
    コードもDataflowも要らない。安い
    ★ 加工なしでそのまま入れるなら、まずこちら

  Dataflow
    間に処理を挟める(整形 / フィルタ / 結合 / 別テーブルへの振り分け)
    ストリーミング処理の基盤。テンプレートも用意されている
    その分、動かし続けるコストがかかる

★ 「まず BigQuery サブスクリプション。加工が要るなら Dataflow」
★ AWSでいうと Kinesis Data Firehose に近い立ち位置です
```

**[話す]** 第8回のシンクの話と地続きなので、
「さっきのシンク先をBigQueryにすると何ができるか」から入るとつながる。

> **制作TODO**: nishiki / ghost でどちらの構成を採っているかを確認し、
> 「うちはこちら」を明示すること。

---

### S39 | 選ぶときの考え方

**[図版]** **新規作成**。処理時間と起動方法での分類。

**[本文]**

```
              いつ動く         どれくらい動く    何を使うか
   ─────────────────────────────────────────────────────
   常に待つ    リクエスト       〜60分           Cloud Run
   イベント    ファイル/メッセージ 〜60分          Cloud Run functions
   定時        スケジュール      〜60分           Cloud Scheduler + Cloud Run
   長時間      任意             時間単位          Batch
   常時稼働    -                無制限            GCE / GKE

★ 「まず Cloud Run で書けないか」を考えるのが今風です
★ 60分を超える、GPUが要る、といった理由が出てから他を検討する
```

---

# 料金と規模の見積もり

### S39b | いくらかかるのかを、作る前に知る ★

**[図版]** **新規作成**。3ステップの横フロー。
「見積もる → 負荷をかける → 台数とスペックを決める」。
各ステップの下に使う道具を書く。

```
   ① 見積もる            ② 負荷をかける          ③ 決める
  Pricing Calculator  →  負荷試験ツール      →  台数・スペック・上限
  課金レポート             (k6 / Locust など)      オートスケールの設定
  予算アラート
```

**[本文]**

```
◼今日まで、料金の話をしてきませんでした

  勉強会の共有プロジェクトなので、講師が見ていました
  実務では、これを自分でやる必要があります

◼作る前に見積もる

  Pricing Calculator   cloud.google.com/products/calculator
                       リソースを並べると月額が出る

  無料枠を確認する      Always Free の対象と上限
                       第1回でやった「asia-northeast1 は対象外」の話

◼作ったあとに見る

  課金レポート          何にいくらかかっているか。ラベルで分解できる
  予算アラート          しきい値を超えたら通知。★ 必ず入れる
  コスト分析            推移を見る

★ 「作ってから請求書で気づく」が一番まずいです
★ 予算アラートは、リソースを作るのと同じタイミングで入れてください
```

**[話す]** 第1回で「Always Free の対象リージョンに東京は入っていない」と言った。
あれを覚えていれば、見積もりの入り口は分かっている。

---

### S39c | GCPで料金が跳ねるところ

**[図版]** 表。サービスごとの「何で課金されるか」と「気をつけるところ」。

**[本文]**

```
   サービス          何で課金されるか            気をつけるところ
────────────────────────────────────────────────────────────────
   Compute Engine    起動時間 × マシンタイプ      止め忘れ。ディスクは止めても課金
   Cloud Run         リクエスト数 + 実行時間      min-instances を入れると常時課金
   ロードバランサ      転送ルール1つあたり + 転送量  作るだけで固定費がかかる
   Cloud NAT          ゲートウェイ + 処理量        これも作るだけで固定費
   Cloud Storage      容量 + 取り出し + 操作回数    Nearline/Coldline は取り出しが高い
   Cloud CDN          キャッシュ配信量 + 埋め込み   ヒット率が低いと逆に高くなる
   Spanner            ノード数(または処理ユニット)  最小構成でも常時課金。今日一番高い
   Memorystore        容量 × 時間                 止められない
   ネットワーク        外向きの通信量               ★ リージョン間・ゾーン間も課金される

◼一番効くのは「作るだけで固定費がかかるもの」

  ロードバランサ / Cloud NAT / Spanner / Memorystore
  → 検証で作ったら、消す

★ この勉強会で毎回 destroy させているのは、これが理由です
★ ゾーンをまたぐ通信にも課金されます。冗長化の設計はコストと直結します
```

---

### S39d | 負荷試験とキャパシティプランニング

**[図版]** **新規作成**。負荷試験の結果グラフ(横軸=同時アクセス数、
縦軸=レイテンシとエラー率)を1枚描き、
「ここが限界」「ここを運用点にする」を矢印で示す。

```
  レイテンシ                              ┃ここから急に崩れる
      ↑                                 ┃
      │                            ╱━━━━┃
      │                    ╱━━━━━╱      ┃
      │━━━━━━━━━━╱                    ┃
      └────────────────────────────────→ 同時アクセス数
                    ↑                  ↑
              運用点(限界の6〜7割)      限界
```

**[本文]**

```
◼負荷試験は「壊れる点」を探すためにやります

  壊れない範囲を確かめるのではなく、
  どこで壊れるか、どう壊れるかを見る

  見るもの: レイテンシ(95%ile) / エラー率 / CPU / メモリ / DBの待ち

◼道具

  k6 / Locust / JMeter などをVMやGKEから流す
  ★ 本番に向けて流さない。同じ構成の検証環境を作って流す

◼結果から決めること(キャパシティプランニング)

  1. 限界を知る          同時Nでレイテンシが崩れた
  2. 運用点を決める       限界の6〜7割を上限とする
  3. 台数と上限を決める    Cloud Run の max-instances
                        インスタンスグループの最小・最大
  4. 予算と突き合わせる    その台数で月いくらか(S39b に戻る)

◼スケールの前に、詰まっている場所を見る

  台数を増やしても、DBが詰まっていれば速くなりません
  ★ 第4回でやった Spanner のホットスポットが、まさにこれです

★ 「見積もる → 流す → 決める → また見積もる」のループです
★ 今日の監視は、このループを回すための計器です
```

**[話す]** ここは触りだけ。1回分のテーマになる内容なので、
「こういう順番でやる」という地図だけ渡して終わる。
興味がある人は全体アンケートに書いてもらう。

> **制作TODO**: 社内で標準的に使っている負荷試験ツールがあれば、
> それに合わせて道具の名前を差し替えること。

---

# まとめ

---

### S40 | 本日のまとめ ①

**[本文]**

```
◼監視の考え方
目的は2つ。壊れたことに気づく / 原因を絞り込む
見ても何もしないグラフは、無いのと同じ
**症状を鳴らす。原因はダッシュボードとログで調べる**
鳴りすぎるアラートは、無いより悪い

◼3種類のデータ
ログ      1つ1つの詳細。多い。原因を調べるとき
メトリクス 数の推移。少ない。いつも見る
トレース   1リクエストの内訳。遅い原因を探すとき
```

---

### S41 | 本日のまとめ ②

**[本文]**

```
◼Cloud Logging
ログは黙っていても集まる。保持は既定30日
ログベース指標で「アプリが何をしたか」を数にできる
シンクで外に流せる。**書き込み権限を忘れると静かに失敗する**

◼Cloud Monitoring
Uptime check は「誰も使っていない時間帯」でも気づける
ダッシュボードは外から見た様子と中の様子を並べる
レイテンシは平均ではなく95パーセンタイルを見る

◼アラート
ポリシー(いつ)とチャンネル(どこ)は別
duration で「続いたら鳴らす」。鳴らさない工夫が大事
documentation に「まず何を見るか」を書く
書けないアラートは、たぶん要らない
```

---

### S42 | 本日はここまで

**[図版]** AWS版の同スライドを流用。

---

### S43 | 宿題1 アンケート

**[本文]**

```
◼アンケートのお願い

1分で終わりますのでぜひフィードバックお願い致します！！
次回開催のモチベになります！！！

https://docs.google.com/forms/d/e/1FAIpQLSeQjLfR6f6H_jDR1ZHRQUmJPkaw3BmBEnGPV-t8fUjjIoF37A/viewform
```

> **★ 全10回で同じフォームです。** 冒頭で「第何回か」を選ぶ形式なので、
> 回答は1つのシートに溜まり、回ごとの推移が見えます。

---

### S44 | 宿題2 実装課題

**[本文]**

```
◼1. SLO を1つ定義して、バーンレートでアラートしよう

  「30日で成功率99%」を目標にする
  エラーバジェットを速く使っているときだけ鳴らす

  ★ 「エラー率が高い」ではなく
     「使い切るまであと何日か」で見るのがSLO

  回答例: gcp/lesson8/syukudai1/


◼2. 自分あてのメール通知を足そう

  Slack に加えて、自分のメールにも飛ばす
  Step1で作ったログベース指標でアラートする

  ★ メールは auth_token が要らないので自分で作れます

  回答例: gcp/lesson8/syukudai2/


◼3. ログのコストを下げよう

  ヘルスチェックの成功ログを取り込まないようにする
  保持期間の短いログバケットを作る

  ★ 何を消してよいかは「障害のときに見るか」で決める

  回答例: gcp/lesson8/syukudai3/
```

---

### S45 | 宿題3 ドキュメント

**[本文]**

```
◼Cloud Monitoring のドキュメントを眺めてみよう
  https://cloud.google.com/monitoring/docs
  アラートポリシー / Uptime check / SLO

◼Cloud Logging のドキュメントを眺めてみよう
  https://cloud.google.com/logging/docs
  ログルーター / ログベース指標 / クエリ言語

◼SRE本の「アラート」の章を読んでみよう
  https://sre.google/sre-book/monitoring-distributed-systems/
  無料で公開されています
  「症状で鳴らす」の出典はここです
```

---

### S46 | 参考

**[本文]**

```
Cloud Monitoring ドキュメント
  https://cloud.google.com/monitoring/docs

Cloud Logging クエリ言語
  https://cloud.google.com/logging/docs/view/logging-query-language

SLO モニタリング
  https://cloud.google.com/stackdriver/docs/solutions/slo-monitoring

Google SRE Book(無料)
  https://sre.google/books/

ログの料金
  https://cloud.google.com/stackdriver/pricing
```

---

### S47 | 注意事項

**[本文]**

```
宿題などで作成したリソースは
必ず削除してください！

★★ destroy の手順 ★★

   1. terraform destroy   (private サブネットだけ失敗します)

   2. 2〜3時間待つ
        gcloud compute addresses list --filter="purpose=SERVERLESS"

   3. terraform destroy

★ アラートポリシーを消し忘れると、鳴り続けます
   Slack が荒れるので、必ず destroy してください

★ 次回(第9回)は3月25日(木)、試験対策です
   ★ 曜日が違うので注意してください
```

---

### S48 | おしまい

**[本文]**

```
次回は 試験対策 です(3月25日 木曜)

Associate Cloud Engineer と
Cloud Digital Leader の出題範囲を見ながら、
ここまでの8回を復習します

そのあと第10回で実践テストをやります

お楽しみに！！
```

---

# 付録A: ハンズオンのステップ対応表

| Step | ディレクトリ | 作るもの | 確認すること |
|---|---|---|---|
| 0 | `0. before/` | 第2〜6回の全リソース(38個) | 約10分 |
| 1 | `1. logging/` | ログベース指標 + シンク + バケット | シンクは権限が無いと静かに失敗する |
| 2 | `2. monitoring/` | Uptime check + ダッシュボード | **失敗しているのに誰も気づかない** |
| 3 | `3. alert/` | アラートポリシー(Slackチャンネル参照) | **Slack が鳴る** |

AWS版との対応:

| AWS版 | GCP版 | 備考 |
|---|---|---|
| (該当回なし) | 1〜3 | **AWS版に監視回は無かった**。新規制作 |
| 第11回 その他・まとめ | S36〜S39 | Cloud Run functions / Batch / BigQuery の概説 |

---

# 付録B: 制作メモ / 要確認事項

## 実環境での動作確認: **完了(2026-08-31)**

受講者相当の権限(なりすましSA)で通しで実測した。`user_name = perm8`。

| 項目 | 結果 |
|---|---|
| Step1 `0. before` + ログ(42リソース) | **9分39秒** |
| ログベース指標 / シンク / `writer_identity` | 作成OK |
| Step2 Uptime check + ダッシュボード | **11秒** |
| **外形監視の失敗** | **3拠点すべてで False**(狙いどおり) |
| Step3 アラートポリシー | 3秒 |
| **Slack への着弾** | **約7分**(`duration=300s` + 評価の遅れ) |
| 復旧(文字列を修正) | **約3分**で全拠点 True |
| 宿題1 SLO + バーンレート | OK。`select_slo_burn_rate` の構文も通った |
| 宿題2 メール通知 + ログベース指標アラート | OK |
| 宿題3 ログ除外 + ログバケット | OK |
| `roles/logging.configWriter` | 12個目として必要なことを確認 |

### 検証で見つけて直したもの

1. **「存在しないパスを叩けば失敗する」は成り立たない**
   アプリが Go の `http.HandleFunc("/", handler)` なので
   **どんなパスでも 200 を返す**(実測)。
   → `content_matchers` で本文を見る方式に変更した。
   結果として「200 = 生きている、ではない」という
   より本質的な論点を扱えるようになった
2. **Slack は Markdown を解釈しない**
   `mime_type = "text/markdown"` でも `##` や `**` が文字のまま出る。
   → `documentation` を素のテキストに書き直した
3. **シンクから GCS への書き込みは1時間ごとのバッチ**
   最初のログが出るまで2〜3時間。**講義中には確認できない**。
   原稿の「数分かかります」は誤りだったので訂正した
4. **宿題ディレクトリが Step3 の修正を上書きする**
   `syukudai1〜3` の `monitoring.tf` は `"ALL SYSTEMS NORMAL"` のままなので、
   宿題を apply すると外形監視が失敗に戻る。S34 に注意を追記した

## 受講者ロールの照合結果(2026-08-31 実施)

| 必要な権限 | どこにあるか |
|---|---|
| `monitoring.dashboards.create` / `alertPolicies.create` | `roles/editor` |
| `monitoring.notificationChannels.create` / `.list` | `roles/editor` |
| `monitoring.uptimeCheckConfigs.create` | `roles/editor` |
| `monitoring.services.create` / `slos.create` | `roles/editor` |
| `logging.logMetrics.create` | `roles/editor` |
| **`logging.sinks.create`** | **`roles/logging.configWriter`(12個目)** |
| **`logging.exclusions.create`** | 同上 |
| **`logging.buckets.create`** | 同上 |
| `storage.buckets.setIamPolicy` | `roles/storage.admin`(第1回) |

**監視まわりはほとんど Editor で足りる。**
足りないのはログルーター系だけ。

## 未確定の値

- Slack 通知チャンネルの表示名 — **講師が作る。未確定**
- S43 のアンケート Google Form

## 新規作図が必要なスライド

| スライド | 内容 | 優先度 |
|---|---|---|
| S11 | 何を鳴らすか / ダッシュボードに置くか | **最高** |
| S08 | AWS CloudWatch と GCP の対応 | **最高** |
| S04 | ログ・メトリクス・アラートの流れ | 高 |
| S25 | ダッシュボード4タイルの配置と役割 | 高 |
| S29 | ポリシーとチャンネルが分かれている図 | 中 |
| S07 | ログ / メトリクス / トレースの違い | 中 |
| S39 | 処理時間と起動方法での分類 | 中 |
| S27 | ダッシュボードのスクリーンショット(実物) | 中 |
| S33 | Slack 通知のスクリーンショット(実物) | 中 |

## 設計書からの変更点

- **`0. before` に第7回の CI/CD を含めていない。**
  監視の題材に不要で、`cloudbuild_repository` 変数が増えるだけのため。
  理由は S15 で受講者にも説明する
- **Cloud Trace は概説のみ**にした(アジェンダには入っていたが、
  アプリに計装を入れる必要があり尺が足りない)。S07 で「トレースとは何か」に触れる
- **Error Reporting も概説のみ**。S08 の対応表で「AWSに無いもの」として触れる
- 宿題を「SLO を1つ定義」の1つから3つに増やした
  (通知チャンネルとログコストは実務で必ず出るため)
