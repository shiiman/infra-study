# 第8回 インフラ勉強会(GCP) — 監視・運用 + その他リソース

- **開催日**: 2027-03-01(月) 14-16時
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


> **★ 前回(第7回)の残骸が消えているか、開催前に確認すること ★**
>
> 第5回以降の destroy は **Direct VPC egress の予約IPが解放されるまで
> サブネットが消せない**ため、1回では終わらない(1〜2時間かかる)。
> **受講者は講義中の1回だけ**にして、2回目は講師がまとめて流す運用にしている。
>
> 第7回の直後に流し忘れていないか、ここで確認する。
> 残骸があると**この回の `0. before` が同名リソースの衝突で落ちて、
> 冒頭で全員が止まる。**
>
> ```
> # 残骸の確認
> gcp/tools/check-leftover.sh --names-file=<受講者名簿> --project=[プロジェクトID]
>
> # 残っていたら、前回分をまとめて片付ける(まず dry-run)
> gcp/tools/cleanup-lesson.sh 7 --names-file=<受講者名簿> \
>   --project=[プロジェクトID] --var-file=cleanup.tfvars
> ```
>
> **この回の片付け**については、末尾の注意事項スライドの講師メモを参照。

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

2027年3月1日(月) 14-16時
```

---

### S02 | インフラ勉強会 スケジュール

**[図版]** 第2回 S02 と同じスライドを複製。今日の行のマーカーは付けない。

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

<!-- slide-id: x0812bslide -->

**[図版]** 上に「Cloud Run / LB / Spanner」の箱。そこから2本の矢印で、左の青い箱「Cloud Monitoring / Logging」と
右の黄色い箱「Datadog」へ。それぞれの下に灰色の説明枠。いちばん下に緑の ★ 枠。
(2026-11-19 にデッキ側で図を作り直した。図形は dg1212… 始まりの ID)

**[本文]**

```
Cloud Run / LB / Spanner

Cloud Monitoring / Logging
  GCPのリソースは、何も入れなくても見える

  GCPの外は見えない
  → 複数クラウドが混ざると足りない

Datadog
  GCP / AWS / オンプレ / SaaS(外部サービス)を1画面で

  APM(アプリ性能監視)が強い
  → 入れる手間と、料金がかかる

★ Datadog は監視専用の外部サービス。ghost / nishiki のどちらでも使っています
★ nishiki は Datadog の設定も Terraform で管理  ―  今日ダッシュボードとアラートを書いたのと同じ
```

**[話す]** 「GCPを勉強したのにDatadogの話?」と思われないように、
先に「考え方は同じ」と言ってから入る。
道具の名前ではなく、何をどう見るかが本題であることを強調する。
略語は初出で説明する: APM は Application Performance Monitoring(アプリ内部の処理時間を追跡する仕組み)、
SaaS は Software as a Service(自分で動かさず、インターネット越しに使うサービス)。

> **★ 監視設定もコードで管理する。** nishiki は Datadog の設定を
> Terraform(DataDog プロバイダ)で書いている。
> 「画面でポチポチ作った監視」は誰がいつ作ったか分からなくなる。
> **今日ダッシュボードとアラートを Terraform で書いたのと同じ考え方。**
>
> 講師メモ(旧スライドにあった内容。文字が多いのでデッキからは外した。口頭で補う):
> nishiki では外形監視(Synthetics)の接続元IPをファイアウォールで許可している。
> Datadog の API キーは SOPS で暗号化して Git に置いている。
---

### S12c | 道具が変わっても同じところ

<!-- slide-id: x0812cslide -->

**[図版]** 8行×3列の表(機能 / Cloud Monitoring / Datadog)。見出し行は灰色。

**[本文]**

```
機能              Cloud Monitoring        Datadog
メトリクス取得    自動(GCPリソース)       Integration を有効化
ログ              Cloud Logging           Log Management
ダッシュボード    ダッシュボード          Dashboard
アラート条件      アラートポリシー        Monitor
通知先            通知チャンネル          Notification(Slackなど)
外形監視          Uptime check            Synthetic Monitoring
分散トレース      Cloud Trace             APM(アプリ性能監視)
SLO               SLO モニタリング        SLO
```

**[話す]** 表は左から読む。「名前が違うだけで構造は同じ」が次のページ。

---

### S12d | 道具が変わっても同じところ（補足）

<!-- slide-id: p2_8_x0812cbdy_notes -->

**[図版]** 表のページから文字を分けた補足ページ(文字が小さくなるため分割)。

**[本文]**

```
◼名前が違うだけで、構造は同じです
  「いつ鳴らすか」と「どこに鳴らすか」が分かれているのも同じ

★ 片方を覚えれば、もう片方はドキュメントを見れば書けます
★ 大事なのは、どのメトリクスを、どのしきい値で見るかの判断です
```
---

### S13 | 休憩（5分）

**[本文]**

```
後半はハンズオンです
```

---

# 準備と Step1

---

### S14 | ハンズオンの準備

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

### S15 | 前回までの構成を作成する

<!-- slide-id: g014slide -->

**[図版]** 第2回の Step ページと同じ形式。上の灰色の枠に cp の3行、下の灰色の枠に `terraform init` / `terraform plan, terraform apply`。
その間に説明を2段で並べる。

**[本文]**

```
cd ~/works/lesson8 && cp -rf ~/infra-study/gcp/lesson8/"0. before" ./
cd "0. before"
python3 ~/infra-study/gcp/tools/configure.py

第6回までの構成を再作成します。
Cloud Run / Cloud Storage / ロードバランサなど

configure.py：project ID・user name・bucket だけを反映します
DNSなど各回固有の値は、コピー後に確認・設定してください。

terraform init
terraform plan, terraform apply

第7回のCI/CDは含めていません。
監視を学ぶために必要なアプリと配信基盤から始めます。
各ステップの中で設定を反映します。
同じ Cloud Storage の state を引き継ぎます。
```

**[話す]** `0. before` の apply は約10分(第6回の完成状態、38リソース)。
「DNSなど各回固有の値」は口頭で補う(cp 後に tfvars を書き換える手順は、スライドには載せない)。
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

### S17 | ログベース指標（1/2）

<!-- slide-id: g016slide -->

**[図版]** 上の灰色の枠に cp の3行、その下にコード枠、いちばん下に黄色の ※ 枠。
`1. logging/` の中身は、この Step で使うコード一式(`logging.tf`)と、前の Step までの `before.tf`。
cp するとログベース指標・バケット・シンク・IAM がまとめて入るが、apply は「Step1 実行」で1回だけ。
この回の Step ディレクトリは積み上げ式(2. monitoring は logging.tf も含む)。

**[本文]**

```
cd ~/works/lesson8 && cp -rf ~/infra-study/gcp/lesson8/"1. logging" ./
cd "1. logging"
python3 ~/infra-study/gcp/tools/configure.py

resource "google_logging_metric" "app_error" {
  name = "${var.user_name}-app-error"

  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${google_cloud_run_v2_service.app.name}"
    textPayload:"失敗"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

※ cp すると、この Step のコード一式が入ります
   (ログベース指標 / バケット / シンク / IAM)。apply は「Step1 実行」で1回だけ
```

---

### S17b | ログベース指標（2/2）

<!-- slide-id: p2_8_g016bdy_1 -->

**[本文]**

```
◼ログから「数」を作る

  条件に合うログを数えて、メトリクスにする
  作った指標はダッシュボードにもアラートにも使える

◼なぜ要るのか

  Cloud Run はリクエスト数やエラー率を出してくれる
  でも アプリが何をしたか は出してくれない

    「DB接続に失敗した回数」
    「決済が失敗した回数」

  これはログにしかない。その穴を埋めるのがログベース指標

★ AWSの CloudWatch Logs メトリクスフィルタと同じ考え方
```
---

### S18 | ログルーター（シンク）（1/2）

<!-- slide-id: g017slide -->

**[図版]** コード枠(シンク)と、下に黄色の ※ 枠。
シンクも、次ページの IAM も、流し先のバケット(`google_storage_bucket.logs`)も、cp 済みの `logging.tf` に入っている。
バケット自体のコードはスライドに出さない(30日で消えるライフサイクル付き。`1. logging/logging.tf` を参照)。

**[本文]**

```
resource "google_logging_project_sink" "app_logs" {
  name        = "${var.user_name}-app-logs"
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"
  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${google_cloud_run_v2_service.app.name}"
  EOT
  unique_writer_identity = true
}

※ このシンクも、次ページの IAM も、流し先のバケット(google_storage_bucket.logs)も
   cp 済みの logging.tf に入っています。apply は「Step1 実行」で1回だけ
```

---

### S18b | ログルーター（シンク）（2/2）

<!-- slide-id: p3_8_g017bdy_1 -->

**[本文]**

```
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

### S19 | シンクは作っただけでは動かない（1/2） ★

<!-- slide-id: g018slide -->

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

  ★ しかも エラーが出ません ★

  「シンクは作ったのにバケットが空のまま」
  という状態になり、気づくのに時間がかかります

★ 第7回の「権限が2つ要る」と同じ構図
★ ただしこちらは失敗しても静かなので、余計にたち悪い
```

**[話す]** これは実際にハマる。シンクを作って満足して、
半年後に「監査ログが1件も無い」と気づくパターン。

---

### S19b | シンクは作っただけでは動かない（2/2） ★

<!-- slide-id: p2_8_g018bdy_1 -->

**[本文]**

```
★ さらに厄介なこと

   Cloud Storage への書き込みは1時間ごとのバッチで、
   最初のログが出るまで2〜3時間かかります

   つまり「バケットが空」のとき、原因が
     権限不足なのか
     まだ書き込まれていないだけなのか
   見た目では区別できません

   → 先に writer_identity の権限を確認する癖をつける
```
---

### S20 | Step1 実行（1/2）

<!-- slide-id: g019slide -->

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼確認
  terraform output log_metric_name
  terraform output log_bucket_name
  terraform output sink_writer_identity
  → serviceAccount:service-....@gcp-sa-logging.iam.gserviceaccount.com

◼ログバケットの中を見てみる
  gcloud storage ls --recursive gs://[ログバケット]/
  → 今日は 空のままです
```

---

### S20b | Step1 実行（2/2）

<!-- slide-id: p3_8_g019bdy_1 -->

**[本文]**

```
★ Cloud Storage へのエクスポートは1時間ごとのバッチ
   最初のログが現れるまで 2〜3時間 かかります
   講義中には確認できません
   ファイルはこう並びます
     [バケット]/[ログID]/YYYY/MM/DD/08:00:00_08:59:59_S0.json
★ 「シンクを作ったのにバケットが空」は
   権限不足のときも、単に待ち時間のときも同じ見え方です
   切り分けは writer_identity の権限を先に確認する
```

**[話す]** 2〜3時間は実機で測った値(付録B)。このページ(2/2)は、1ページに入りきらなかったので分けた。
---

### S21 | ログベース指標に数字が入るまで

<!-- slide-id: g020slide -->

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

### S22 | Uptime check（外形監視）（1/2）

<!-- slide-id: g021slide -->

**[図版]** 上の灰色の枠に cp の3行、その下にコード枠。`content_matchers` の行の右に「← ★ わざと」。

**[本文]**

```
cd ~/works/lesson8 && cp -rf ~/infra-study/gcp/lesson8/"2. monitoring" ./
cd "2. monitoring"
python3 ~/infra-study/gcp/tools/configure.py

resource "google_monitoring_uptime_check_config" "web" {
  display_name = "${var.user_name}-uptime"
  period       = "60s"
  timeout      = "10s"

  http_check {
    path         = "/"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  content_matchers {
    content = "ALL SYSTEMS NORMAL"   ← ★ わざと
    matcher = "CONTAINS_STRING"
  }

  ~~~~~
}
```

**[話す]** `monitored_resource` と `selected_regions`(3拠点)は `~~~~~` で省略している。コードは `2. monitoring/monitoring.tf`。

---

### S22b | Uptime check（外形監視）（2/2）

<!-- slide-id: g021bslide -->

**[本文]**

```
◼「外から見て生きているか」を確かめる

  Cloud Run のメトリクスは
  「リクエストが来たときに何が起きたか」しか分からない

  リクエストが0件のとき、それが
    「誰も使っていない」のか「繋がらない」のか
  区別できない

  Uptime check は Google が世界の複数拠点から定期的に叩くので、
  誰も使っていない時間帯でも壊れていることに気づけます

★ AWSの Route53 ヘルスチェック / CloudWatch Synthetics に相当
```

---

### S23 | わざと壊しています

<!-- slide-id: g022slide -->

**[本文]**

```
  content = "ALL SYSTEMS NORMAL"

◼ページに無い文字列を、期待する本文に指定しています

  すぐ失敗する状態を作って、
  「監視しているのに誰も気づかない」を体験するためです

  Step3 でアラートを繋いだあと、"DB接続" に直します

★ このアプリはどんなパスでも 200 を返します
   パスを間違えても失敗しないので、本文を見ます
★ 200 が返る = 正しく動いている、ではありません
★ 本番でこれをやると、当然ずっと鳴り続けます
```

**[話す]** 「存在しないパスを叩けば失敗する」は成り立たなかった(付録B 検証1)。
アプリが `http.HandleFunc("/", handler)` なので、どんなパスでも 200 を返す(実測)。
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

<!-- slide-id: g025slide -->

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼ダッシュボードを見る
  コンソール → Monitoring → ダッシュボード
  → 「[自分の名前] インフラ勉強会」

★ Uptime check の結果が出るまで数分かかります
   作った直後はグラフが空です

◼Uptime check の結果
  コンソール → Monitoring → 稼働時間チェック

  → しばらくすると 失敗 になります
```
---

### S27 | 失敗しているのが見える

<!-- slide-id: g026slide -->

**[図版]** ダッシュボードのスクリーンショット。
**開催前に実物を撮ること**(外形監視のタイルが0のまま)。

**[本文]**

```
◼外形監視のグラフが 0 のままです

  1 = 成功、0 = 失敗

  本文に ALL SYSTEMS NORMAL が無いので、当然失敗しています

◼リクエスト数のグラフは、普通に増えています

  アプリは 200 を返し続けているので、
  リクエスト数やエラー数だけ見ていても気づけません

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

<!-- slide-id: g029slide -->

**[図版]** 上の灰色の枠に cp の3行、その下にコード枠(`data` ブロック)、その下に本文。

**[本文]**

```
cd ~/works/lesson8 && cp -rf ~/infra-study/gcp/lesson8/"3. alert" ./
cd "3. alert"
python3 ~/infra-study/gcp/tools/configure.py

data "google_monitoring_notification_channel" "slack" {
  display_name = var.notification_channel_name
}

◼Slack に投げるには auth_token が要ります

  Slack 側で「Google Cloud Monitoring」アプリを認可して受け取る
  → ブラウザでの作業。Terraform には書けません

◼第7回の GitHub 連携と同じ形です

  講師が1回だけ認可して通知チャンネルを作ってあります
  受講者は表示名で参照するだけ

★ メール通知は auth_token が要らないので自分で作れます
   → 宿題2でやります
```

**[話す]** 通知チャンネルの表示名(`notification_channel_name`)は、口頭で伝える。
cp 後に `terraform.tfvars` へ貼る手順はスライドには載せない(2026-11-19 に削除)。
---

### S31 | アラートポリシー（1/2）

<!-- slide-id: g030slide -->

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
```

---

### S31b | アラートポリシー（2/2）

<!-- slide-id: p2_8_g030bdy_1 -->

**[本文]**

```
◼duration = 300s の意味

  「その状態が5分続いたら」鳴らす

  1拠点が一瞬失敗しただけで鳴らすと、うるさくて誰も見なくなる
  鳴らさない工夫のほうが、しきい値より大事なことが多い

★ ALIGN_FRACTION_TRUE で「成功した割合」になります
   1未満 = どこかの拠点で失敗した
```
---

### S32 | documentation を書く（1/2） ★

<!-- slide-id: g031slide -->

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
```

**[話す]** 「まず何を見るか」が書けないアラートは、
作った本人しか対応できない。それは運用として弱い。
---

### S32b | documentation を書く（2/2） ★

<!-- slide-id: g031bslide -->

**[本文]**

```
★ Slack は Markdown を解釈しません

   mime_type = "text/markdown" と書いても、
   Slack には ## や ** が 文字のまま 出ます
   (コンソールの画面では整形されます)

   通知が届く先は Slack なので、
   記号を使わず素のテキストで書くのが正解

     × ## サイトが見えません / **確認すること**
     ◯ サイトが見えません   / 確認すること

★ アラートを作るとき、ここを空にしない
★ 書けないなら、そのアラートは要らないかもしれません
```

**[話す]** 通知の届く先は Slack なので、Markdown で書いても記号がそのまま見える。
素のテキストで書く、と覚えておく。(コンソールの画面では整形される)
---

### S33 | Step3 実行 → Slack が鳴る

<!-- slide-id: g032slide -->

**[図版]** Slack の通知画面。**開催前に実物のスクリーンショットを撮ること**。

**[本文]**

```
  terraform init
  terraform plan, terraform apply

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

### S34 | 直す（1/2）

<!-- slide-id: g033slide -->

**[本文]**

```
◼監視対象の文字列を正しく直します

  3. alert/monitoring.tf

    content = "ALL SYSTEMS NORMAL"
    ↓
    content = "DB接続"

  terraform apply

★ 5分ほどで Slack に「解決」の通知が届きます
```

**[話す]** これは講義の中で `3. alert/monitoring.tf` を1行直す操作。
cp 後の tfvars / common.tf の書き換えとは別物。

---

### S34b | 直す（2/2）

<!-- slide-id: p2_8_g033bdy_1 -->

**[本文]**

```
★ 宿題をやるときの注意

   宿題のディレクトリ(syukudai1〜3)にも monitoring.tf が入っていて、
   そちらは "ALL SYSTEMS NORMAL" のままです

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

<!-- slide-id: g037slide -->

**[本文]**

```
◼Batch

  バッチ処理を動かす基盤
  VMを立てて、処理して、落とすまでを面倒見てくれる

  Cloud Run のリクエストは最大60分。それ以上は Batch か
  Cloud Run ジョブ(終わったら止まる Cloud Run。最大7日)

  ★ AWSの AWS Batch に相当

◼BigQuery

  データ分析基盤。SQLで巨大なデータを集計できる

  今日のシンクの流し先にも選べました
    → ログをSQLで分析したいならこちら

  ★ AWSの Athena / Redshift に相当

★ どちらも「使う側」になることが多いサービスです
   インフラとして構築するより、繋ぎ方を知っておくとよい
```

**[話す]** 時間の上限は公式ドキュメントで確認した(2026-11-19)。
Cloud Run サービスのリクエストタイムアウトは最大60分、ジョブのタスクタイムアウトは最大168時間(7日)。
---

### S38b | ログを BigQuery に貯める ★ ①

<!-- slide-id: x0838bslide -->

**[図版]** 2つの経路を上下に並べた図(2026-11-19 にデッキ側で作り直した。図形は p56_ 始まりの ID)。
上段「① GCPのログを貯める」: Cloud Logging → シンク → 右に2つの箱。
Cloud Storage(注釈「今日 Step1 でやったもの / nishiki は Cloud Armor のログをここへ」)と
BigQuery(注釈「SQL で集計・分析したいとき」)。
下段「② アプリのイベントを貯める ← nishiki の行動ログはこちら」: アプリ → Pub/Sub →
BigQuery サブスクリプション → BigQuery、と、Pub/Sub → Dataflow → BigQuery の2本。
いちばん下に略語の説明と ★ のまとめ。

**[本文]**

```
① GCPのログを貯める
  Cloud Logging → シンク → Cloud Storage    今日 Step1 でやったもの
                                             nishiki は Cloud Armor のログをここへ
                         → BigQuery          SQL で集計・分析したいとき

② アプリのイベントを貯める  ← nishiki の行動ログはこちら
  アプリ → Pub/Sub → BigQuery サブスクリプション → BigQuery
                   → Dataflow → BigQuery

Pub/Sub: イベントを受け取って、必要な先へ配るメッセージの仕組み
BigQuery サブスクリプション: Pub/Sub の設定だけで、加工せずに BigQuery へ書き込む
Dataflow: 間で整形・フィルタなどの加工をしてから届ける(動かし続けるコストがかかる)
★ まず BigQuery サブスクリプション。加工が要るなら Dataflow
```

**[話す]** 第8回のシンクの話と地続きなので、
「さっきのシンク先を BigQuery にすると何ができるか」から入るとつながる。
①は、今日の Step1 のシンクの流し先を BigQuery にしたもの。今日は Cloud Storage に流した。
②はアプリが出すイベント(ゲームのプレイログ、行動ログなど)を貯めたいとき。
Cloud Logging を経由させると量とコストが厳しいので、Pub/Sub に流してから BigQuery に入れる。

> 2026-11-19 の修正: 旧図は「① Cloud Logging のシンク → BigQuery(今日 Step1 でやったやつ)」と描いており、
> 今日の Step1 のシンク先は Cloud Storage なので事実と合わなかった。流し先を2つ並べる形に直した。
> 旧本文の「Kinesis Data Firehose に近い立ち位置」は、デッキに無いので外した(AWSとの対応を言うなら要確認)。
> 旧本文の「全期間を1回スキャンして数万円」は、金額の根拠が確認できないので「高額になる」に弱めた。

---

### S38c | ログを BigQuery に貯める ★ ②

<!-- slide-id: x0838cslide -->

**[図版]** 上に小見出し「nishiki の BigQuery テーブルの作り方」、灰色のコード枠、
その下に各設定の説明(・の箇条書き)、いちばん下に黄色の ※ 枠。

**[本文]**

```
nishiki の BigQuery テーブルの作り方

time_partitioning { type = "DAY", field = "timestamp" }
require_partition_filter = true
storage_billing_model    = "PHYSICAL"

・time_partitioning: 日付ごとにテーブルを区切る(パーティション)
・require_partition_filter: 日付を指定しないクエリを拒否する
・storage_billing_model = PHYSICAL: 圧縮後のサイズで保存料金を計算する

※ require_partition_filter = true が効いています
   WHERE で日付を指定しないとクエリが実行できません
   → 「全期間をスキャンして高額になる」ミスを仕組みで防ぎます
```

**[話す]** 「PHYSICAL」は圧縮後(物理)のサイズで保存料金を計算する設定。
既定の LOGICAL は圧縮前(論理)のサイズ。どちらが安いかはデータ次第なので、ここでは「選べる」とだけ言う。
---

### S39 | 選ぶときの考え方

<!-- slide-id: g038slide -->

**[図版]** 4列(いつ動く / 1回の最大時間 / 何を使うか)の対応図。デッキ側で5行の表の形に作り直してある。

**[本文]**

```
いつ動く                 1回の最大時間     何を使うか
常に待つ(リクエスト)     〜60分            Cloud Run
イベント(ファイル/メッセージ)  〜9分       Cloud Run functions
定時(スケジュール)       〜30分            Cloud Scheduler + Cloud Run
長時間(任意)             〜7日             Cloud Run ジョブ / Batch
常時稼働                 無制限            GCE / GKE

★ 「まず Cloud Run で書けないか」を考えるのが今風です
★ 時間の上限を超える、常時起動が要る、といった理由が出てから他を検討する
```

**[話す]** 時間の上限は公式ドキュメントで確認した(2026-11-19)。
Cloud Run functions(第2世代)のイベント駆動は最大540秒(=9分。HTTP 関数は最大60分)、
Cloud Scheduler の attemptDeadline は最大30分、Cloud Run ジョブは最大168時間(7日)。
旧原稿の「イベント 〜60分」「定時 〜60分」「長時間 時間単位」は、上のとおり直した。
---

# 料金と規模の見積もり

### S39b | いくらかかるのかを、作る前に知る ★

<!-- slide-id: x0839bslide -->

**[図版]** 3ステップの横フロー(青 ① 見積もる・作る前 → 黄 ② 負荷をかける・作ったあと → 緑 ③ 決める・試験の結果から)。
各ステップの下に使う道具の箱。いちばん下に赤い ★ 枠。

**[本文]**

```
① 見積もる       作る前       Pricing Calculator / 課金レポート / 予算アラート
② 負荷をかける   作ったあと   負荷試験ツール(k6 / Locust / JMeter)
③ 決める         試験の結果から  台数・スペック・上限 / オートスケールの設定

★「作ってから請求書で気づく」が一番まずい
★ 予算アラートは、リソースを作るのと同じタイミングで入れること
```

**[話す]** 今日まで料金の話をしてこなかった。勉強会の共有プロジェクトなので講師が見ていた。
実務では、これを自分でやる必要がある。
・Pricing Calculator(cloud.google.com/products/calculator): リソースを並べると月額が出る。
・無料枠(Always Free)の対象と上限を確認する。第1回の「asia-northeast1 は対象外」の話。
・課金レポート(何にいくらかかっているか。ラベルで分解できる)・予算アラート(しきい値超過で通知)・コスト分析(推移)。
第1回で「Always Free の対象リージョンに東京は入っていない」と言った。あれを覚えていれば、見積もりの入り口は分かっている。
---

### S39c | GCPで料金が跳ねるところ

<!-- slide-id: x0839cslide -->

**[図版]** 表(サービス / 課金の単位 / 注意点)、9行。補足は次のページに分けた(文字が小さくなるため)。

**[本文]**

```
サービス          課金の単位                          注意点
Compute Engine    起動時間 × マシンタイプ              止め忘れ。停止後もディスクは課金
Cloud Run         リクエスト数 + 実行時間              min-instances を入れると常時課金
ロードバランサ    転送ルール + 転送量                  作るだけで固定費
Cloud NAT         ゲートウェイ + 処理量                作るだけで固定費
Cloud Storage     容量 + 取り出し + 操作回数           Nearline / Coldline は取り出しが高い
Cloud CDN         キャッシュ配信量 + オリジンからの取得量  ヒット率が低いと逆に高くなる
Spanner           ノード数 / 処理ユニット              最小構成でも常時課金。この勉強会で一番高い
Memorystore       容量 × 時間                         止められない
ネットワーク      外向きの通信量                      リージョン間・ゾーン間にも課金
```

---

### S39c2 | GCPで料金が跳ねるところ（補足）

<!-- slide-id: p2_8_x0839cbdy_notes -->

**[本文]**

```
◼一番効くのは「作るだけで固定費がかかるもの」
  ロードバランサ / Cloud NAT / Spanner / Memorystore
  → 検証で作ったら、消す
★ この勉強会で毎回 destroy させているのは、これが理由です
★ ゾーンをまたぐ通信にも課金されます。冗長化の設計はコストと直結します
```
---

### S39d | 負荷試験とキャパシティプランニング

<!-- slide-id: x0839dslide -->

**[図版]** 左に折れ線グラフ(横軸=同時アクセス数、縦軸=レイテンシ95%ile。緑の破線が運用点、赤の破線が限界)、
右に緑の枠「結果から決めること」(1〜4)、下に黄色の ★ 枠。
(2026-11-19 にデッキ側で図形の位置と文字を直した。図形は dg1212… 始まりの ID)

**[本文]**

```
レイテンシ 95%ile
同時アクセス数 →
運用点(限界の6〜7割)    限界    ここから急に崩れる

結果から決めること
1. 限界を知る
2. 運用点を決める
3. 台数と上限を決める
4. 予算と突き合わせる

★ nishiki は k6 を使っています
   PRごとに smoke テスト(軽い負荷)を GitHub Actions で回している
   → 重い負荷試験の前に「壊れていないか」を毎回見る
★ 本番に向けて流さない。nishiki には lod(負荷試験)という専用環境がある
★ 台数を増やしても、DBが詰まっていれば速くならない(第4回のホットスポット)
※ 95%ile: 遅い方の5%を除いた値。平均より実態に近い
```

**[話す]** ここは触りだけ。1回分のテーマになる内容なので、
「こういう順番でやる」という地図だけ渡して終わる。
興味がある人は全体アンケートに書いてもらう。
・負荷試験は「壊れる点」を探すためにやる。見るもの: レイテンシ(95%ile) / エラー率 / CPU / メモリ / DBの待ち。
・道具は k6 / Locust / JMeter など。同じ構成の検証環境を作って流す(本番に向けて流さない)。
・3. 台数と上限: Cloud Run の max-instances、インスタンスグループの最小・最大。
・「見積もる → 流す → 決める → また見積もる」のループ。今日の監視は、このループを回すための計器。

> **未確認**: 「運用点は限界の6〜7割」は一般的な経験則の目安で、公式ドキュメントの値ではない
> (2026-11-19 時点で出典を確認できていない)。「目安」と言って渡すこと。
> 95%ile の説明は「遅い方の5%を除いた値」(全リクエストを速い順に並べて95%目の値)。
---

# まとめ

---

### S40 | 本日のまとめ ①

<!-- slide-id: g039slide -->

**[図版]** 丸数字(青い円に白抜きの 1〜4)+ 太字の結論1行 + 補足1行 を4段に並べる(第4回 S45 と同じ形)。
図形は p62_ 始まりの ID。宿題・片付けは載せない(宿題のページで説明する)。

**[本文]**

```
1  監視の目的は2つだけ
   気づくこと、原因を絞り込むこと。症状を鳴らす

2  ログは自動で集まる。数にすると使える
   ログベース指標で数にする。シンクは権限が無いと静かに失敗する

3  ダッシュボードは調べる道具、気づくのはアラート
   Uptime check は本文まで見る。200 が返る = 正常、ではない

4  鳴らす工夫と、通知に書く文章が大事
   duration で続いたときだけ鳴らす。「まず何を見るか」を書く
```

**[話す]** 今日の話を4つに絞ると、この4点。
---

### S41 | 本日のまとめ ②

<!-- slide-id: g040slide -->

**[図版]** 5行×4列の表(見出し行は青、左の列は灰色)。下に黄色の ※ 枠(第4回 S46 と同じ形)。図形は p63_ 始まりの ID。

**[本文]**

```
                   ログ                  メトリクス          トレース
何が分かるか       1つ1つの出来事の詳細  数の推移            1リクエストの内訳
量                 多い                  少ない              中くらい
いつ見るか         原因を調べるとき      いつも / 異常検知   遅い原因を探すとき
GCPのサービス      Cloud Logging         Cloud Monitoring    Cloud Trace

※ 使い分け
「なんか遅い」→ メトリクスで範囲を絞る
「このリクエストが遅い」→ トレースでどこが遅いか見る
「なぜ失敗した」→ ログで詳細を見る
```

**[話す]** 3種類のデータを並べると、量と見るタイミングが違うことが分かる。
最後の ※ が、障害のときの使い分けの目安。
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

### S44 | 宿題2 実装課題 ①②

<!-- slide-id: g043slide -->

**[図版]** 第3回 S52 と同じ形式(◼見出し + 説明 + ・の補足 + 回答例)。1ページに入りきらないので、①② と ③ の2ページに分ける。

**[本文]**

```
◼1. SLO を1つ定義して、バーンレートでアラートしよう
  「30日で成功率99%」を目標にする
  エラーバジェットを速く使っているときだけ鳴らす

  ・エラーバジェット = 失敗してよい量(99%なら1%)
  ・バーンレート = それを使うペースの速さ
  ・「エラー率が高い」ではなく「使い切るまであと何日か」で見るのが SLO

  回答例: gcp/lesson8/syukudai1/

◼2. 自分あてのメール通知を足そう
  Slack に加えて、自分のメールにも飛ばす
  Step1 で作ったログベース指標でアラートする

  ・メールは auth_token が要らないので自分で作れます
  ・通知チャンネルを作って、アラートポリシーに足します

  回答例: gcp/lesson8/syukudai2/
```

---

### S44b | 宿題2 実装課題 ③

<!-- slide-id: x0843bslide -->

**[本文]**

```
◼3. ログのコストを下げよう
  ヘルスチェックの成功ログを取り込まないようにする
  保持期間の短いログバケットを作る

  ・取り込まないようにする設定を「除外(exclusion)」といいます
  ・除外したログは取り込まれないので、あとから見られません
  ・何を消してよいかは「障害のときに見るか」で決めます

  回答例: gcp/lesson8/syukudai3/
```

> 2026-11-19: 第3回の形(◼見出し + 説明 + ・の補足 + 回答例)に揃え、①② と ③ に分けた。
> 略語・用語を初出で説明した(エラーバジェット / バーンレート / 除外)。
> 回答例の `syukudai1〜3` は、`monitoring.tf` が `"ALL SYSTEMS NORMAL"` のままである点に注意(S34b)。
---

### S45 | 宿題3 ドキュメント ①

<!-- slide-id: g044slide -->

**[図版]** 第3回 S54 と同じ形式(◼見出し + リンク)。調べ物の課題ではなく、眺めるだけ。
URL は1行ごとにリンクを貼る。

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

**[リンク]**

- [https://cloud.google.com/monitoring/docs](https://cloud.google.com/monitoring/docs)
- [https://cloud.google.com/logging/docs](https://cloud.google.com/logging/docs)
- [https://sre.google/sre-book/monitoring-distributed-systems/](https://sre.google/sre-book/monitoring-distributed-systems/)

> 3つの URL は 2026-11-19 に取得できること(HTTP 200)を確認した。
> 「SRE本の章」は旧宿題から引き継いだ項目(調べ物ではなく読み物)。残してよいかはユーザー判断(報告済み)。

---

### S45b | 宿題3 ドキュメント ②

<!-- slide-id: x0844bslide -->

**[図版]** 第3回 S54 と同じ形式。リソース名(google_xxx)の1つ1つにリンクを貼る。

**[本文]**

```
◼Terraform google provider の各ドキュメントを眺めてみよう
  google_logging_metric
  google_logging_project_sink
  google_logging_project_exclusion
  google_logging_project_bucket_config
  google_storage_bucket
  google_storage_bucket_iam_member
  google_monitoring_uptime_check_config
  google_monitoring_dashboard
  google_monitoring_alert_policy
  google_monitoring_notification_channel
  google_monitoring_custom_service
  google_monitoring_slo
```

**[リンク]**

- [google_logging_metric](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_metric)
- [google_logging_project_sink](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_sink)
- [google_logging_project_exclusion](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_exclusion)
- [google_logging_project_bucket_config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_bucket_config)
- [google_storage_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket)
- [google_storage_bucket_iam_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam)
- [google_monitoring_uptime_check_config](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_uptime_check_config)
- [google_monitoring_dashboard](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_dashboard)
- [google_monitoring_alert_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_alert_policy)
- [google_monitoring_notification_channel](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_notification_channel)
- [google_monitoring_custom_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_custom_service)
- [google_monitoring_slo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_slo)

> 12個のリソースが、`gcp/lesson8/` の `*.tf` で実際に使われていること、
> 上の URL が取得できること(HTTP 200)を 2026-11-19 に確認した。
> `google_storage_bucket_iam_member` のドキュメントは `storage_bucket_iam` のページにまとまっている。
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

### S47 | 注意事項 ①

<!-- slide-id: g046slide -->

**[図版]** 第3回 S56 と同じ形式。タイトル行、◼リソースの削除、cd 行を灰色の枠で囲み右に「←」の注釈、
`terraform destroy` は別の小さな枠(右に「→ 確認で yes と入力」)、その下に ※ で2項目。
文字が多いので、共有プロジェクトの注意などは ② に分けた。

**[本文]**

```
宿題などで作成したリソースは必ず削除してください！

◼リソースの削除(最後に apply したディレクトリで実行)
  cd ~/works/lesson8/syukudai3       ← 実装課題③まで
  cd ~/works/lesson8/syukudai2       ← 実装課題②まで
  cd ~/works/lesson8/syukudai1       ← 実装課題①まで
  cd ~/works/lesson8/"3. alert"      ← 講義 Step3 まで

  terraform destroy   → 確認で yes と入力

※ destroy は1回打つだけで OK です
   private サブネットだけ失敗します
   Direct VPC egress が確保した IP の解放待ち(1〜2時間)のためで、
   手動では消せません。残りは講師がまとめて片付けます

※ アラートポリシーが残ると Slack が鳴り続けます
   1回目は必ず打ってください
```

---

### S47b | 注意事項 ②

<!-- slide-id: x0846bslide -->

**[本文]**

```
※ 全員で1つのプロジェクトを共有しています
   消し忘れはQuotaを圧迫して、他の人のapplyを止めます
   この回の消し忘れは、第10回の試験にも影響します

※ tfstate用のバケットは残しておいてください

※ 残るのは VPC とサブネットだけで、課金はありません

※ 確認したい人は  gcp/tools/check-leftover.sh [自分の名前]

※ 次回(第9回)は3月18日(木)、試験対策です
   曜日が違うので注意してください
```

> **実機で確認した内容(付録B。2026-08-31)**: 1回目の destroy で private サブネットだけが失敗する。
> Direct VPC egress の予約IPの解放待ちは、公式ドキュメントにも「1〜2時間」とある(第5回の原稿)。
> 今回(2026-11-19)は destroy を再実行していない。待ち時間の実測値は付録B を参照。
> 「3月18日(木)」の日付は、2026-11-19 時点で開催日程の一次情報を確認していない(要確認)。

> **★ 講師メモ: 2回目は講師がやる。この回はいちばん重要 ★**
>
> **受講者は講義中の1回だけ。2回目は翌朝、講師がまとめて流す。**
>
> ```
> # まず dry-run(既定)
> gcp/tools/cleanup-lesson.sh 8 --names-file=<受講者名簿> \
>   --project=[プロジェクトID] --var-file=cleanup.tfvars
>
> # 中身を見てから実行
> gcp/tools/cleanup-lesson.sh 8 --names-file=<受講者名簿> \
>   --project=[プロジェクトID] --var-file=cleanup.tfvars --apply
> ```
>
> **この回の片付けだけは絶対に落とさないこと。**
> 第8回(3/1)から第10回(4/5)まで35日空き、間の第9回はハンズオンが無い。
> 残骸があると第10回の試験で作るリソースと二重になり、
> **`BACKEND-SERVICES-per-project`(75で固定・引き上げ不可)に当たって
> 試験そのものが止まる。**
>
> 流したあとに `check-leftover.sh` で消えたことを確認し、
> 第10回の事前準備(前日の残骸確認)でもう一度見る。二重に構えておく。

> **★ 講師メモ: destroy の完了を後追いすること ★**
>
> この手順は **1回目の destroy が必ず失敗する**(private サブネットが
> `purpose=SERVERLESS` の予約IPに掴まれている)。
> 「2〜3時間待って再実行」を当日の夜にやらせる形なので、
> **やり切れない人が必ず出る。**
>
> 第9回(3/18)はハンズオンが無く、次に手を動かすのは第10回(4/5)。
> **35日間、誰も気づかないまま残り続ける。**
> 残っていると第10回の試験でクォータに当たって試験が止まるうえ、
> その間ずっと課金される。
>
> **翌日と1週間後に、講師が全体を見て個別に声をかけること。**
>
> ```
> gcloud compute instances list --project=[プロジェクトID]
> gcloud compute networks list --project=[プロジェクトID]
> gcloud compute addresses list --project=[プロジェクトID] \
>   --filter="purpose=SERVERLESS"
> ```
>
> 第10回の「事前準備 7」でも同じ確認をする。
---

### S48 | おしまい

<!-- slide-id: g047slide -->

**[本文]**

```
次回 試験対策編 もお楽しみに！
```

**[話す]** 次回は試験対策(3月18日 木曜)。Associate Cloud Engineer と Cloud Digital Leader の出題範囲を見ながら、
ここまでの8回を復習する。そのあと第10回で実践テストをやる。
(旧原稿は上の内容をスライドに載せていたが、デッキは1行にまとまっている。デッキに合わせた)
---

# 付録A: ハンズオンのステップ対応表

| Step | ディレクトリ | 作るもの | 確認すること |
|---|---|---|---|
| 0 | `0. before/` | 第2〜6回の全リソース(38個)を再作成する(`before.tf` に全部入っている) | 約10分 |
| 1 | `1. logging/` | ログベース指標 + シンク + バケット | シンクは権限が無いと静かに失敗する |
| 2 | `2. monitoring/` | Uptime check + ダッシュボード | **失敗しているのに誰も気づかない** |
| 3 | `3. alert/` | アラートポリシー(Slackチャンネル参照) | **Slack が鳴る** |

> **Step のディレクトリは積み上げ式。** `1. logging/` には `before.tf`(前の Step まで)と、この Step の `logging.tf` が入る。
> `2. monitoring/` には `logging.tf` と `monitoring.tf`、`3. alert/` には `alert.tf` も入る(同じ state を引き継ぐ)。
> 「`1. logging/` に後の Step のファイルが入っている」わけではない。
> cp すると、その Step のコード一式(ログベース指標・バケット・シンク・IAM)が一度に入るが、
> スライドでは見せる順に分けて説明する。**apply は「Step1 実行」で1回だけ**
> (S17 / S18 / S19 の各ページと S20 に注記した。2026-11-19)。

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

## 2026-11-19 の見直し(第1〜4回のレビュー指摘を先回りで反映)

デッキ側の編集を正として、原稿を合わせた。コードは変えていない(`gcp/lesson8/` は無変更)。

**直したもの**

- **まとめ**: 第4回の形に。S40 は丸数字1〜4 + 太字の結論 + 補足、S41 は3種類のデータの表 + ※(使い分け)。宿題・片付けは載せない
- **宿題2**: 第3回の形(◼見出し + 説明 + ・の補足 + 回答例)。S44(①②)と S44b(③)に分割。エラーバジェット / バーンレート / 除外(exclusion)を初出で説明
- **宿題3 ドキュメント**: 第3回 S54 の形。S45(Cloud Monitoring / Cloud Logging / SRE本)と S45b(Terraform の12リソース)。原稿に [リンク] 一覧を追加
- **注意事項**: 第3回 S56 の形。S47(cd 行 + destroy)と S47b(共有プロジェクト・Quota・次回の案内)。1回目の destroy で private サブネットだけ失敗することを具体的に書いた
- **Step ページ**: S15 / S17 / S22 / S30 の cp 行を第2回の形に揃えた。`terraform plan, terraform apply` は1行(S20 / S26 / S33)。cp 後の tfvars 書き換えの手順は載せない
- **Step1 の整理(8回 p17 の指摘)**: `1. logging/` の中身を確認した。`logging.tf`(ログベース指標・バケット・シンク・IAM)は Step1 のコードで、
  後の Step のファイルではない。ただし cp で全部入るのに、スライドは見せる順に分けていたため
  「後の Step のコードまで入っている」ように見えた。S17 / S18 に「cp すると一式が入る。apply は Step1 実行で1回だけ」の注記を足し、
  ディレクトリは動かさなかった(`2. monitoring` 以降は `logging.tf` を含む積み上げ式で、全 Step が同じ state を引き継ぐ構成のため)
- **Uptime check**: 旧原稿の「存在しないパス」「404」は、検証1(付録B)で成り立たないと分かったあとも残っていた。
  デッキに合わせて `path = "/"` + `content_matchers`(本文に ALL SYSTEMS NORMAL)に統一(S22 / S23 / S27)
- **S38b(BigQuery)**: 旧図は今日のシンク先を BigQuery としていたが、実際は Cloud Storage。流し先を2つ並べる形に直した。
  S38b / S38c の2ページに分割。Pub/Sub / BigQuery サブスクリプション / Dataflow を初出で説明。「数万円」は根拠が確認できないので「高額になる」に弱めた
- **S12b〜S12d(Datadog)**: 略語 APM / SaaS を初出で説明。表のページから文字を分けて補足ページ(S12d)にした
- **S39 / S39b〜S39d(その他・料金)**: S39 の時間の上限を公式ドキュメントで確認して直した(functions のイベント駆動は9分、Scheduler は30分、ジョブは7日)。
  S39c の表の列名を「課金の単位 / 注意点」に。S39d は95%ile の説明を足し、文字を減らした
- **S38**: Cloud Run のリクエスト最大60分、ジョブ最大7日を明記(公式ドキュメントで確認)
- **ページ分割**: 文字が小さいページを(1/2)(2/2)に分けた。デッキのタイトルに合わせ、原稿も S17 / S18 / S19 / S20 / S22 / S31 / S32 / S34 に b を足した
- **S48(おしまい)**: デッキは1行なので原稿を合わせた(旧本文は [話す] に移した)

**実機で確認していないもの**

- 今回(2026-11-19)は apply / destroy / gcloud を実行していない(認証切れ)。待ち時間・Slack の着弾時間などの数字は、上の2026-08-31の実測のまま
- 「運用点は限界の6〜7割」(S39d): 経験則で、出典を確認できていない
- 次回(第9回)の日付「3月18日(木)」(S47b): 一次情報を確認していない
- `before.tf` の `DB_KIND=spanner`: 第4回でアプリが3行表示になり `DB_KIND` は廃止されたため、第6回・第8回の `before.tf`(全14か所)から環境変数を削除した(第5回・第7回は削除済み)。実機の apply では未確認

**sync の残り**

- `check-slide-sync.py 8` で、タイトルが合わないのは S01(表紙)と S04(今日やること。デッキは「今日のアジェンダ」「今日のゴール」)。今回は触っていない
- S18 の差分(※ の注記)は、デッキ側で別の図形に分けているための誤検出

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
