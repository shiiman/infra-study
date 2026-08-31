# 第5回 インフラ勉強会(GCP) — コンテナ

- **開催日**: 2026-12-24(木) 2時間
- **AWS版対応**: 第6回(AWS コンテナ編)
- **Terraformコード**: `gcp/lesson5/`
- **ゴール**: イメージを Artifact Registry に push し、Cloud Run で公開、ロードバランサのバックエンドを VM から Cloud Run に切り替える

> **この回は「VMからCloud Runへの移行」を軸にしている。**
> 第3回・第4回で VM の上で `docker run` していたものを Cloud Run に移す。
> 同じドメイン・同じ証明書のまま中身だけ入れ替えるので、
> 実際の移行手順としてもそのまま使える。

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入 | 6分 | S01〜S04 |
| コンテナの歴史 / GCPのコンテナ | 15分 | S05〜S10 |
| GKE(概説) | 10分 | S11〜S13 |
| 準備 + Artifact Registry(Step1) | 20分 | S14〜S20 |
| 休憩 | 5分 | S21 |
| Cloud Run(Step2) | 25分 | S22〜S31 |
| Direct VPC egress(Step3) | 15分 | S32〜S36 |
| ロードバランサの切り替え(Step4) | 14分 | S37〜S42 |
| まとめ・宿題 | 10分 | S43〜S51 |

> **待ち時間**
> - S14 `0. before` の apply: 約20分(Spanner/Memorystore/証明書を含む)
> - S19 イメージのビルドとpush: 2〜5分(Cloud Shellでビルドする)
> - S41 ロードバランサの伝播: **約7分30秒**(実測)
>
> **S41の伝播待ちが最後に来るのが痛い。**
> Step4のapplyを流したらすぐ S43(まとめ)に進み、
> 講義の最後に各自で確認してもらう構成にすること。
>
> **`0. before` が今までで一番重い。** 第4回までの全リソースが入っている。
> S14 の最初に apply を流してから、GKEの話とコンテナの歴史に入る構成にしてある。
>
> 押した場合の削り所: S05〜S07(コンテナの歴史)は口頭のみで圧縮できる。
> S11〜S13(GKE)も概説なので短縮可。
>
> **削ってはいけないのは S24〜S25**(ECSとCloud Runのリソース比較)と
> **S32〜S34**(Direct VPC egress)。この回の核心。

## 事前準備(講師)

1. 受講者が第4回のリソースを destroy 済みであること
2. API の有効化
   ```
   gcloud services enable artifactregistry.googleapis.com run.googleapis.com
   ```
3. 受講者のロールに以下を**追加**すること
   ```
   roles/run.admin        run.services.setIamPolicy
   ```
   Artifact Registry / Cloud Run / サーバレスNEG の**作成権限は
   `roles/editor` に含まれている**ので、`roles/artifactregistry.admin` は不要。
   Editor に無いのは `run.services.setIamPolicy` だけ。

   第1回 付録A に追記済み(計10ロール)。

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない

---

# 導入

---

### S01 | タイトル

**[図版]** AWS版 第6回 表紙を複製。タイトルのみ差し替え。

**[本文]**

```
第5回 インフラ勉強会(GCP)

〜 コンテナ編 〜

2026年12月24日
```

**[話す]** 年末の木曜開催。次回は年明け1/18。

---

### S02 | ロードマップ

**[図版]** 第1回 S02 と同じスライドを複製。今日の行(12月24日)にマーカーを移す。

---

### S03 | 前回の振り返り

**[図版]** AWS版 第6回「前回」2枚を流用。中身を差し替え。

**[本文]**

```
◼前回やったこと

GCPのマネージドDBは接続方式が3種類ある
  Google API経由     Spanner / BigQuery
  VPCピアリング       Cloud SQL / Memorystore
  Auth Proxy         Cloud SQL(別解)

Spanner: 主キーの設計が全て。IAMで認証。パスワードが無い
Memorystore: ElastiCacheの4リソースが1リソースに
限定公開サービスアクセスでピアリングを張った

★ 今日この「3種類の接続方式」がもう一度出てきます
```

**[話す]** 前回の話が今日の山場に直結する。覚えておいてほしい。

---

### S04 | 今日やること

**[図版]** **新規作成**。移行の前後を左右で比較。

```
   これまで(第3回・第4回)          今日

   [ロードバランサ]                 [ロードバランサ]  ← 同じものを使う
        │                                │
   インスタンスグループ              サーバレスNEG
        │                                │
   [VM] docker run                  [Cloud Run]
    ├ OSのパッチ                     自動
    ├ Dockerのインストール           不要
    ├ 自動起動の設定                 不要
    └ 冗長化は手動                   自動
```

**[本文]**

```
◼VMの上で docker run していたものを Cloud Run に移します

  ドメインも証明書もそのまま
  ロードバランサの向き先だけ差し替える

★ 実際の移行でもこの手順を取ります
   VMは残しておき、問題があれば戻せるようにする
```

---

# コンテナ

---

### S05 | コンテナの歴史

**[図版]** AWS版 第6回「コンテナ」の年表スライドを流用。
GCPの視点を足すので**一部差し替え**。

**[本文]**

```
◼コンテナの歴史

2013年  Docker が登場
2014年  Googleでは毎週20億のコンテナを起動していた
        (社内では2000年代から Borg で運用)
同年    Google が Kubernetes をOSSとして公開
2016年  Swarm vs Kubernetes
2017年  Kubernetes が事実上の標準に
同年    AWS Fargate 発表
2019年  Cloud Run 発表

★ Kubernetes は Google の社内基盤(Borg)を作り直したもの
★ GCPのコンテナサービスは、この流れの延長にある
```

**[話す]** AWS版では「Dockerが2013年に登場して〜」という一般的な流れだった。
GCPの回では「Kubernetesを作ったのはGoogle」という背景に触れると、
GKEとCloud Runの位置づけが分かりやすくなる。

---

### S06 | GCPにおけるコンテナの変遷

**[図版]** AWS版 第6回「AWSにおけるコンテナの歴史」を流用。中身を差し替え。

**[本文]**

```
◼GCPのコンテナサービス

2015/08  Google Container Engine (GKE)
2016     Container Registry (GCR)
2019/04  Cloud Run
2020/05  Artifact Registry(GCRの後継)
2021/02  GKE Autopilot
2024     Container Registry は廃止方向

★ 今日使うのは Artifact Registry と Cloud Run
★ GKE は概説のみ(10分)
```

---

### S07 | GCPのコンテナサービスの選び方

**[図版]** **新規作成**。3つのサービスの位置づけ。

```
  手間                                          制御の細かさ
   多 ┃                                              多
      ┃   [GKE Standard]  ノードも自分で管理
      ┃        │
      ┃   [GKE Autopilot] ノード管理はGoogle
      ┃        │
      ┃   [Cloud Run]     コンテナを置くだけ  ← 今日
   少 ┃                                              少
```

**[本文]**

```
◼GKE (Google Kubernetes Engine)
Kubernetesのマネージドサービス。AWSのEKSに相当
  Standard   ノード(VM)も自分で管理
  Autopilot  ノード管理はGoogleに任せる

◼Cloud Run
コンテナを置くだけで動く。AWSのECS+Fargateに近いが、
App Runner の手軽さも併せ持つ

◼Cloud Run functions
関数単位。AWSのLambdaに相当(旧 Cloud Functions)
中身はCloud Runと同じ基盤

★ 「まずCloud Run。無理なところだけGKE」が今の定石
```

---

### S08 | AWSとの対応

**[本文]**

```
AWS                      GCP
────────────────────────────────────────────
ECR                      Artifact Registry
ECS + Fargate            Cloud Run
EKS                      GKE
App Runner               Cloud Run(同じものが担う)
Lambda                   Cloud Run functions
AWS Batch                Cloud Run Jobs

★ AWSは用途ごとにサービスが分かれている
★ GCPは Cloud Run が広くカバーする

   AWS版では App Runner の「デメリット」として
   「WAFが設定できない」「実績が少ない」が挙げられていた
   Cloud Run はそのあたりの制約がなく、本番でも普通に使われる
```

**[話す]** AWS版のスライドで App Runner の評価が辛口だったのを覚えている人。
Cloud Run は App Runner の立ち位置でありながら、
Cloud Armor も付けられるし LB の後ろにも置ける。そこが違う。

---

### S09 | Artifact Registry

**[図版]** AWS版 第6回「ECR」のスライドを流用。用語を差し替え。

**[本文]**

```
◼Artifact Registry
成果物の保管場所。AWSのECRに相当

◼ECRとの違い

  ECR                コンテナイメージ専用
  Artifact Registry  format を指定して使い分ける
                       DOCKER / MAVEN / NPM / PYTHON / GO / APT / YUM

◼リポジトリの単位も違う
  ECR                リポジトリ = イメージ1種類
  Artifact Registry  リポジトリ = 複数のイメージを入れる箱

◼共通するもの
脆弱性スキャン / レプリケーション / IAMでのアクセス制御

★ 旧 Container Registry(GCR)は廃止方向
   ネットの古い記事は gcr.io を使っているので注意
```

---

### S10 | Cloud Run とは

**[本文]**

```
◼Cloud Run
コンテナをデプロイするだけで動くサービス

  HTTPリクエストが来たらインスタンスを起動
  来ない間は0台にできる(課金されない)
  リクエスト数に応じて自動でスケール
  HTTPSのエンドポイントが自動で付く

◼2つの形態
  Cloud Run サービス  HTTPリクエストに応答する(今日やる)
  Cloud Run ジョブ    実行して終わるバッチ処理

◼制約
  実行時間の上限(既定5分、最大60分)
  常駐プロセスは置けない
  コンテナに入れない  ← あとで詳しくやります
```

---

# GKE(概説)

---

### S11 | GKE

**[図版]** AWS版 第6回「EKS」のスライドを流用。用語を差し替え。

**[本文]**

```
◼GKE (Google Kubernetes Engine)
Kubernetesのマネージドサービス

◼2つのモード

  Standard   ノード(VM)を自分で管理する
             ノードプールのサイズ、マシンタイプを決める
             課金はノード(VM)単位

  Autopilot  ノードはGoogleが管理する
             Podを置くだけ。ノードは意識しない
             課金はPodのリソース要求量に対して

◼AWSのEKSとの違い
EKSは「EC2かFargateか」を選ぶ
GKEは「Standardか Autopilotか」を選ぶ
考え方は近いが、Autopilotの方が抽象度が高い
```

---

### S12 | Cloud Run と GKE をどう使い分けるか

**[図版]** 新規。判断フロー図。

**[本文]**

```
◼まず Cloud Run を検討する

  HTTPリクエストに応答するだけ           → Cloud Run
  アクセスに波がある                     → Cloud Run
  運用の手間を減らしたい                 → Cloud Run

◼GKE を選ぶ理由

  複数サービスを細かく制御したい
  Kubernetesのエコシステムを使いたい
    (Istio / Argo CD / Prometheus Operator など)
  既にKubernetesの運用ノウハウがある
  常駐プロセスやサイドカーが必要

★ 「Kubernetesを使いたいから」は理由になりにくい
   運用コストに見合う複雑さがあるかで判断する
```

**[話す]** ここは意見が分かれるところ。
「うちはGKEを使っている」という現場もあれば「Cloud Runで十分」もある。
判断軸を持っておいてほしい、という話にとどめる。

---

### S13 | 今日はGKEを作りません

**[本文]**

```
◼GKEは概説のみ

  クラスターを1つ作るだけで数十分かかる
  Kubernetesの概念(Pod / Deployment / Service / Ingress)を
  説明するだけで2時間使う

  今日は Cloud Run に集中します

★ 興味がある人は
   GKE Autopilot のクイックスタートが1時間程度でできます
   https://cloud.google.com/kubernetes-engine/docs/quickstarts
```

---

# 準備と Artifact Registry

---

### S14 | 準備

**[図版]** AWS版 第6回「準備」を流用。コマンドを差し替え。

**[本文]**

```
◼Cloud Shell を立ち上げる

◼作業ディレクトリを作る
  mkdir -p ~/works/lesson5
  cd ~/works/lesson5

◼サンプルコードを更新
  cd ~/infra-study && git pull
  cd ~/works/lesson5

◼まず apply を流してください(20分かかります)
  terraform init
  terraform apply

★ 第4回のリソースは destroy しておいてください

★ 0. before が今までで一番重いです
   ネットワーク / VM / ロードバランサ / DNS / SSL証明書 /
   限定公開サービスアクセス / Memorystore / Spanner

   待っている間にコンテナとGKEの話をします(S05へ)
```

**[話す]** この回は最初に apply を流してから解説に入る。
証明書の発行(10分)と Cloud SQL 相当の待ちが重なるので、
先に走らせておかないと後半が詰まる。

---

### S15 | 今日のゴール

**[図版]** **新規作成**。S04の移行図をベースに、詳細版を描く。

```
 [ブラウザ] ── https://<自分の名前>.<勉強会のドメイン>
     │
 [Cloud DNS] ── 第3回で作ったAレコード(そのまま)
     │
 [グローバルIP] ── 第3回で作ったもの(そのまま)
     │
 [HTTPSプロキシ + SSL証明書] ── 証明書も第3回のまま
     │
 [URLマップ] ← ここの向き先を差し替える
     │
 [バックエンドサービス] ── [サーバレスNEG] ── [Cloud Run]
                                                  │  │
                                    Google API経由 │  │ Direct VPC egress
                                                  ▼  ▼
                                          [Spanner] [Memorystore]
```

**[本文]**

```
これを理解して作れる！
```

---

### S16 | Artifact Registry を作る

**[本文]**

```
参照: gcp/lesson5/1. artifact_registry/

resource "google_artifact_registry_repository" "app" {
  location      = "asia-northeast1"
  repository_id = "${var.user_name}-repo"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}

★ format で何を入れるリポジトリかを決める
   DOCKER 以外に MAVEN / NPM / PYTHON / GO / APT / YUM

★ cleanup_policies で古いイメージを自動削除
   ECRのライフサイクルポリシーに相当
```

---

### S17 | Step1 実行

**[本文]**

```
  terraform plan
  terraform apply

◼確認
  terraform output repository_url
  → asia-northeast1-docker.pkg.dev/[プロジェクトID]/[自分の名前]-repo

  gcloud artifacts repositories list --location=asia-northeast1
```

---

### S18 | イメージをビルドして push する

**[図版]** AWS版 第6回「ECR」のビルド&プッシュのコマンドスライドを流用。
コマンドを差し替え。**AWSの認証コマンドが1行になることを強調する**。

**[本文]**

```
◼Cloud Shell でビルドします

  VMに入る必要はありません
  Cloud Shell に docker が入っています

  cd "~/infra-study/gcp/lesson5/1. artifact_registry/web_app"

◼Artifact Registry にログイン
  gcloud auth configure-docker asia-northeast1-docker.pkg.dev

★ AWSではこうだった
   AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
   aws ecr get-login-password --region $REGION | \
     docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr...

   GCPは1行。ログイン中の権限がそのまま使われる

◼ビルドして push
  REPO=$(terraform -chdir=~/works/lesson5 output -raw repository_url)

  docker build -t $REPO/app .
  docker push $REPO/app

◼確認
  gcloud artifacts docker images list $REPO
```

**[話す]** 第3回・第4回では VM に入ってビルドしていた。
今回は Cloud Shell でビルドして push するだけ。VM に入る必要がない。
これも「VMを使わなくなる」流れの一部。

---

### S19 | ビルドには時間がかかります

**[本文]**

```
★ ビルドとpushで数分かかります

  Spanner のクライアントライブラリが大きいためです
  (第4回で e2-micro ではビルドできなかったのと同じ理由)

◼待っている間に
  Cloud Run の説明に進みます(S22へ)

★ 実務ではビルドをCI/CDに任せます
   第7回(CI/CD)で Cloud Build を使って自動化します
```

> **要検証**: Cloud Shell でのビルド時間。
> 検証時はローカルのdockerで代用し、**60秒**だった(キャッシュなし)。
> 第4回の VM(e2-medium)では5分16秒。
> Cloud Shell は 2vCPU なので、その中間(2〜5分)になると思われる。
> 開催前に Cloud Shell で実測して差し替えること。

---

### S20 | Artifact Registry 完了

**[図版]** AWS版 第6回「ECR」の完了スクリーンショットの構図を流用。
**新規スクリーンショット**。

---

### S21 | 休憩

**[本文]**

```
5分休憩

後半は Cloud Run です
```

---

# Cloud Run

---

### S22 | ECS + Fargate の構成(復習)

**[図版]** AWS版 第6回「ECS」の構成図をそのまま流用。**比較のために残す**。

**[本文]**

```
◼AWS版で作ったもの

  ECSクラスター
  ECSタスク定義       CPU / メモリ / コンテナ定義 / 環境変数 / シークレット
  ECSサービス         何台動かすか / LBへの登録 / ネットワーク設定
  ECSタスクロール      コンテナが他サービスを使う権限
  ECSタスク実行ロール  ECRからイメージを取る / ログを出す権限
  IAMポリシー × 2
  ロールへのアタッチ × 3
  Secrets Manager シークレット + バージョン

  → 10リソース以上
```

---

### S23 | Cloud Run の構成 ★

**[図版]** **新規作成**。この回の最重要図その1。AWS版との左右比較。

```
   AWS (ECS + Fargate)              GCP (Cloud Run)

   ECSクラスター                     ─────  不要
   ECSタスク定義          ┐
   ECSサービス            ┘─────  google_cloud_run_v2_service
   ECSタスクロール         ─────  google_service_account
   ECSタスク実行ロール     ─────  不要
   IAMポリシー × 2         ─────  google_spanner_database_iam_member
   ロールアタッチ × 3      ─────  不要
   Secrets Manager        ─────  (必要なら Secret Manager)

   10リソース以上                    3リソース
```

**[本文]**

```
◼なぜこんなに減るのか

  クラスター       Cloud Runには「どこで動かすか」の概念がない
  タスク定義/サービス  1つのリソースにまとまっている
  タスク実行ロール  イメージの取得とログ出力は Cloud Run 自身が行う
                   ユーザが権限を設定する必要がない

★ 残るのは「アプリが何をしてよいか」を決めるサービスアカウントだけ
```

**[話す]** AWS版のスライドを見ると、IAMロールの設定だけで1枚使っていた。
「タスクロールとタスク実行ロールの違い」は毎回説明が必要な概念だった。
Cloud Run にはその区別がない。

---

### S24 | Terraform コード(Cloud Run)★

**[本文]**

```
参照: gcp/lesson5/2. cloud_run/cloud_run.tf

resource "google_service_account" "run" {
  account_id   = "${var.user_name}-run"
  display_name = "${var.user_name} cloud run"
}

resource "google_spanner_database_iam_member" "run" {
  instance = module.before.spanner_instance_name
  database = module.before.spanner_database_name
  role     = "roles/spanner.databaseUser"
  member   = "serviceAccount:${google_service_account.run.email}"
}

★ 第4回でVMのサービスアカウントに付けたのと同じ
   アプリの動く場所が変わっただけで、権限の付け方は変わらない
```

---

### S25 | Terraform コード(Cloud Run 続き)

**[本文]**

```
resource "google_cloud_run_v2_service" "app" {
  name     = "${var.user_name}-app"
  location = "asia-northeast1"
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.run.email

    scaling {
      min_instance_count = 0   # 0台まで減らせる = 課金されない
      max_instance_count = 3
    }

    containers {
      image = "...-docker.pkg.dev/[プロジェクト]/[自分の名前]-repo/app"

      ports { container_port = 8080 }

      resources {
        limits = { cpu = "1000m", memory = "512Mi" }
      }

      env { name = "DB_KIND"          value = "spanner" }
      env { name = "SPANNER_DATABASE" value = module.before.spanner_database }
      env { name = "CACHE_HOST"       value = module.before.cache_host }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

★ 第4回でアプリを環境変数化しておいたので、そのまま使えます
★ min_instance_count = 0 が Fargate との一番の違い
   ECSは desired_count で固定。0にするとサービスが止まる
```

---

### S26 | 公開設定

**[本文]**

```
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.app.name
  location = google_cloud_run_v2_service.app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

◼Cloud Run は既定で「呼び出しにIAM認証が必要」

  Webサイトとして公開するには allUsers に invoker を与える

★ 第1回 S25 で「allUsers は事故の元」と言ったやつ
   ここでは意図的に公開するので正しい使い方

★ 社内向けなら allUsers ではなく
   特定のグループやサービスアカウントに絞る
```

**[話す]** 「Cloud Runを作ったのに403が返る」の原因はほぼこれ。
既定が「非公開」なのは安全側に倒した設計。

---

### S27 | Step2 実行

**[本文]**

```
  terraform plan
  terraform apply

★ Cloud Run の作成は1分程度です

◼確認
  terraform output cloud_run_url
  → https://[自分の名前]-app-xxxxx.asia-northeast1.run.app

  gcloud run services list --region=asia-northeast1
```

---

### S28 | アクセスしてみる → 半分だけ動く

**[図版]** ブラウザの表示。**開催前に実物のスクリーンショットを撮ること**。

**[本文]**

```
◼Cloud Run のURLにアクセス

  curl https://[自分の名前]-app-xxxxx.asia-northeast1.run.app

  Hello, Infra Study
  hostname: localhost
  DB接続(Spanner): 成功     ← 繋がる
  Cache接続: 失敗            ← 繋がらない

★ Spanner には繋がるのに、Memorystore には繋がらない

なぜだと思いますか？
```

> **検証済み(2026-08-28)**: 実環境で上記の出力を確認。
> Cloud Run のデプロイは 35秒。デプロイ直後からアクセスできる。

**[話す]** ここで受講者に聞く。第4回をやっていれば答えが出るはず。

---

### S29 | なぜ Memorystore に繋がらないのか ★

**[図版]** **新規作成**。この回の最重要図その2。
第4回 S17 の「3種類の接続方式」の図を再掲し、Cloud Run を左側に置く。

```
                          ┌─ Google API ─┐
   [Cloud Run] ──────────▶│  [Spanner]    │  ○ 繋がる
        │                  └────────────┘
        │
        │  ✕            ┌─ 自分のVPC ──┐  ┌─ Google のVPC ─┐
        └───────────▶│  (VPCの外にいる) │◀▶│ [Memorystore]   │
                          └────────────┘  └──────────────┘
                                       ピアリング
```

**[本文]**

```
◼Cloud Run は VPC の外で動いている

第4回でやった「3種類の接続方式」を思い出す

  Spanner      Google API 経由    → VPCの外からでも届く
  Memorystore  VPCピアリング経由  → VPCの中にいないと届かない

◼Cloud Run はVPCの中にいない
だからピアリングの先にある Memorystore に届かない

★ 第4回で「接続方式が3種類ある」と言った理由がこれ
   どこからアクセスするかで、必要な準備が変わる
```

---

### S30 | VMのときはなぜ繋がっていたのか

**[本文]**

```
◼第4回のVMは private サブネットの中にいた

  [VM] ─ private subnet ─ VPC ─ ピアリング ─ [Memorystore]
                                                ○ 繋がる

◼Cloud Run はVPCの外

  [Cloud Run] ────────✕──── ピアリング ─ [Memorystore]

★ 「VMからは繋がったのにCloud Runからは繋がらない」
   移行のときによく踏む
```

---

### S31 | Cloud Run 到達点(途中)

**[図版]** S15のゴール図を再掲し、Spannerへの線だけチェックを付ける。

**[本文]**

```
◼ここまでできたこと

イメージを Artifact Registry に push した
Cloud Run でコンテナが動いた
HTTPSのURLが自動で付いた
Spanner に繋がった

◼まだできていないこと

Memorystore に繋がらない       ← 次のStep
カスタムドメインで見られない    ← その次のStep
```

---

# Direct VPC egress

---

### S32 | Cloud Run を VPC に繋ぐ ★

**[図版]** **新規作成**。この回の最重要図その3。
Cloud Run のインスタンスが VPC 内にIPを持つ様子。

**[本文]**

```
◼Cloud Run のインスタンスにVPC内のIPを持たせる

  [Cloud Run インスタンス]
       │ VPC内のIP(private サブネットから払い出される)
       ▼
  ┌─ 自分のVPC ──┐
  │  private subnet │──ピアリング──▶ [Memorystore]
  └──────────┘

◼2つのやり方がある

  サーバレスVPCアクセスコネクタ(旧来)
    専用のVMインスタンスが立ち、そこを経由する
    コネクタ自体に課金される
    スループットに上限がある

  Direct VPC egress(新しい方)      ← 今日はこちら
    Cloud Run のインスタンスが直接VPCにIPを持つ
    追加のVMが要らない。速い。安い

★ ネットの記事はコネクタのものが多いので注意
```

---

### S33 | Terraform コード(Direct VPC egress)

**[本文]**

```
参照: gcp/lesson5/3. vpc_egress/cloud_run.tf

resource "google_cloud_run_v2_service" "app" {
  template {
    ...
    vpc_access {
      network_interfaces {
        subnetwork = module.before.private_subnet_id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }
  }
}

◼egress の選択肢

  PRIVATE_RANGES_ONLY  プライベートIP宛だけVPCへ流す
                       インターネット宛はCloud Runから直接出る

  ALL_TRAFFIC          全ての外向き通信をVPCへ流す
                       Cloud NAT を経由するので、
                       送信元IPを固定できる(外部APIのIP制限に使う)

★ 今日は PRIVATE_RANGES_ONLY
★ 外部サービスにIP制限をかけたい場合は ALL_TRAFFIC + Cloud NAT
   第2回で作った Cloud NAT がここで効いてきます
```

**[話す]** `ALL_TRAFFIC` にすると、第2回で作った Cloud NAT を Cloud Run が使う。
「外部のAPIにIP制限をかけたいので送信元を固定したい」という要件でよく使う。

---

### S34 | Step3 実行 → 繋がる

**[本文]**

```
  terraform plan
  terraform apply

★ 追加したのは vpc_access ブロックだけです

◼もう一度アクセス

  curl https://[自分の名前]-app-xxxxx.asia-northeast1.run.app

  Hello, Infra Study
  hostname: localhost
  DB接続(Spanner): 成功
  Cache接続: 成功            ← 繋がった

★ サブネットのIPが1つ消費されます
   Cloud Runのインスタンスが増えるとその分使われるので、
   private サブネットのCIDRに余裕が必要
```

> **検証済み(2026-08-28)**: `vpc_access` ブロックを足した apply が **16秒**で完了し、
> 直後のアクセスで `Cache接続: 成功` になることを確認。
> 反映を待つ必要はなかった。

---

### S35 | hostname が localhost になっている

**[本文]**

```
◼気づいた人はいますか

  第3回・第4回     hostname: 52bb27897698   ← コンテナID
  今回             hostname: localhost

◼Cloud Run のコンテナは hostname が localhost になる

  「どのインスタンスが応答したか」がアプリからは分からない

★ 第3回の宿題2では hostname で振り分けを確認しました
   Cloud Run では同じことができません

★ 代わりに Cloud Logging に instanceId が記録されます
   → 次のスライド
```

> **検証済み(2026-08-28)**: 実環境で `hostname: localhost` を確認。

**[話す]** 細かいが、移行したときに気づく違い。
「ログにインスタンスIDを出していたのに出なくなった」というのはよくある。

---

### S36 | コンテナに入れない ★

**[図版]** AWS版 第6回「ECS Execによるアクセス確認」のスライドを流用し、
**「GCPには相当する機能が無い」と大きく書く**。比較として残す価値がある。

**[本文]**

```
◼AWSでは ECS Exec でコンテナに入れた

  aws ecs execute-command --cluster xxx --task xxx \
    --container app --interactive --command "/bin/sh"

  ps aux / env が打てた

◼Cloud Run には相当する機能がありません

  インスタンスは使い捨て。いつ消えてもよいものとして扱う

◼代わりに「外から観測する」

  ログ      gcloud run services logs read [サービス名] --region=...
  メトリクス コンソール → Cloud Run → 指標
             リクエスト数 / レイテンシ / インスタンス数 /
             CPU / メモリ / コールドスタート

★ 「入れないなら、必要な情報はログに出す」
   これはコンテナ運用の基本でもあります

★ デバッグはローカルで同じイメージを動かす
   docker run -p 8080:8080 -e ... [イメージ]
```

**[話す]** AWS版第6回のハイライトが ECS Exec だった。
GCPにはこれが無い、というのは移行時に必ず話題になる。
ただ「入れない」のは制約というより設計思想の違い。
第8回(監視・運用)でログの読み方を詳しくやる。

---

# ロードバランサの切り替え

---

### S37 | カスタムドメインで見えるようにする

**[本文]**

```
◼今は Cloud Run のURLでしかアクセスできない

  https://[自分の名前]-app-xxxxx.asia-northeast1.run.app

◼第3回で作ったドメインで見えるようにする

  https://[自分の名前].[勉強会のドメイン]

★ ドメインも証明書もそのまま
   ロードバランサの向き先だけ Cloud Run にします
```

---

### S38 | サーバレスNEG ★

**[図版]** **新規作成**。第3回のインスタンスグループとの比較。

```
   第3回                              今日

   バックエンドサービス                バックエンドサービス
        │                                  │
   インスタンスグループ                サーバレスNEG
        │                                  │
      [VM] :80                       [Cloud Run]

   + ヘルスチェック                   ヘルスチェック不要
   + Firewall Rule                   Firewall Rule不要
     (130.211.0.0/22)
```

**[本文]**

```
◼サーバレスNEG(ネットワークエンドポイントグループ)
ロードバランサのバックエンドに Cloud Run をぶら下げる部品

◼第3回との違い

  ヘルスチェックが要らない
    Cloud Run 側が面倒を見てくれる

  Firewall Rule が要らない
    第3回でハマった 130.211.0.0/22 の設定が不要
    Cloud Run はVPCの外にいるので、VPCのFirewallの対象外

★ 第3回で一番ハマったところが、まるごと消えます
```

---

### S39 | Terraform コード(切り替え)

**[本文]**

```
参照: gcp/lesson5/4. loadbalancer/serverless_neg.tf

resource "google_compute_region_network_endpoint_group" "run" {
  name                  = "${var.user_name}-run-neg"
  region                = "asia-northeast1"
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_v2_service.app.name
  }
}

resource "google_compute_backend_service" "run" {
  name     = "${var.user_name}-run-bs"
  protocol = "HTTP"

  backend {
    group = google_compute_region_network_endpoint_group.run.id
  }
}

resource "google_compute_url_map" "main" {
  name            = "${var.user_name}-urlmap"
  default_service = google_compute_backend_service.run.id   ← ここ
}

resource "google_compute_target_https_proxy" "main" {
  name             = "${var.user_name}-https-proxy"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = [module.before.ssl_certificate_id]      ← 第3回の証明書
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = "${var.user_name}-https-fr"
  target     = google_compute_target_https_proxy.main.id
  ip_address = module.before.global_address_id               ← 第3回のIP
  port_range = "443"
}
```

---

### S40 | 部品が分かれている利点 ★

**[図版]** 第3回 S25 の「LBは6つのリソースでできている」図を再掲。

**[本文]**

```
◼第3回で「なぜ6つに分かれているのか」と言いました

  役割ごとに独立しているので、使い回せる

◼今日それが効いています

  そのまま使うもの
    グローバルIP      第3回で作ったもの
    SSL証明書         第3回で作ったもの(再発行不要)
    DNSレコード       第3回で作ったもの

  差し替えるもの
    URLマップの向き先   VM → Cloud Run

★ ドメインも証明書も変えずに、中身だけ入れ替えられる
★ VMのバックエンドサービスは残してあります
   問題があれば default_service を戻すだけでロールバックできる

   実際の移行でもこの手順を取ります
```

**[話す]** ここが今日一番きれいなところ。
第3回で「部品が多い」と文句を言った構造が、移行のときに効いてくる。

---

### S41 | Step4 実行 → 完成

**[図版]** ブラウザの表示。**新規スクリーンショット**。

**[本文]**

```
  terraform plan
  terraform apply

◼カスタムドメインでアクセス

  https://[自分の名前].[勉強会のドメイン]

  Hello, Infra Study
  hostname: localhost
  DB接続(Spanner): 成功
  Cache接続: 成功

★ 証明書はそのまま。ブラウザの鍵マークも変わりません
★ 中身だけ VM から Cloud Run に入れ替わりました

★ apply 直後はまだ繋がりません
   ロードバランサの設定が行き渡るまで 5〜10分 かかります
   第3回のときと同じです
```

> **検証済み(2026-08-28)**: apply完了から **約7分30秒**で HTTP 200。
> 証明書は第3回で発行したものがそのまま使われ、再発行は走らなかった
> (issuer=Google Trust Services / subject=<自分の名前>.<ドメイン>)。

---

### S42 | VMはもう要らない

**[本文]**

```
◼第3回・第4回で使っていたVMは、もう使っていません

  ロードバランサは Cloud Run を向いている
  VMのバックエンドサービスは残っているが、誰も呼ばない

◼実際の移行では
  しばらく残しておいて、問題がないことを確認してから消す

◼次回(第6回)以降
  VMは使いません。Cloud Run が本体になります

★ 第3回の宿題でやったこと(自動起動、冗長化)が
   全部要らなくなったことを確認してみてください
```

---

# まとめ

---

### S43 | 本日のまとめ ①

**[図版]** AWS版 第6回「本日のまとめ」のレイアウトを流用。

**[本文]**

```
◼コンテナ
Kubernetes は Google の社内基盤を作り直したもの
GCPのコンテナサービス
  Artifact Registry / Cloud Run / GKE / Cloud Run functions / Jobs
「まずCloud Run。無理なところだけGKE」

◼Artifact Registry
ECRに相当。format で Docker 以外も扱える
ログインは gcloud auth configure-docker の1行

◼Cloud Run
ECS + Fargate の10リソースが3リソースになる
クラスターもタスク実行ロールも要らない
min_instance_count = 0 にできる(Fargateとの一番の違い)
既定は非公開。allUsers に invoker を与えて公開する
```

---

### S44 | 本日のまとめ ②

**[本文]**

```
◼Cloud Run は VPC の外にいる

  Spanner      Google API経由      → そのまま繋がる
  Memorystore  VPCピアリング経由   → Direct VPC egress が必要

  第4回の「3種類の接続方式」がそのまま効いてくる

◼コンテナに入れない
ECS Exec に相当する機能が無い
ログとメトリクスで外から観測する
hostname が localhost になる

◼ロードバランサの切り替え
サーバレスNEGでバックエンドに繋ぐ
ヘルスチェックもFirewall Ruleも不要
グローバルIP / 証明書 / DNSはそのまま使える
URLマップの向き先を戻せばロールバックできる
```

---

### S45 | 本日はここまで

**[図版]** AWS版の同スライドを流用。

---

### S46 | 宿題1 アンケート

**[図版]** AWS版 第6回「宿題1」を流用。URLを差し替え。

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

### S47 | 宿題2 実装課題

**[図版]** AWS版 第6回「宿題2」のレイアウトを流用。

**[本文]**

```
◼1. 最小インスタンス数を1にして、コールドスタートの差を測ろう

  min_instance_count = 0 のとき
    しばらく放置してからアクセスすると最初の1回だけ遅い

  min_instance_count = 1 にすると
    常に1台起動しているので速い。ただし課金され続ける

  curl -s -o /dev/null -w "%{time_total}\n" https://...

  回答例: gcp/lesson5/syukudai1/


◼2. 同時リクエスト数を変えてオートスケールを見よう

  max_instance_request_concurrency の既定は80
  10にすると同じ負荷でもインスタンスが増える

  負荷をかけてインスタンス数の推移を見てください

  回答例: gcp/lesson5/syukudai1/

★ 年末年始をまたぐので、無理のない範囲で
★ 特に min_instance_count = 1 のまま放置しないでください(課金されます)
```

---

### S48 | 宿題3 調べ物

**[本文]**

```
◼1. Cloud Run のログとメトリクスを見てみよう

  コンテナに入れない代わりに何が見えるか
  gcloud run services logs read [自分の名前]-app --region=asia-northeast1

◼2. VM と Cloud Run のどちらを選ぶか考えよう

  第3回・第4回でやっていたことのうち、
  何が要らなくなったかを整理してみてください

  自分が担当しているサービスは、どれに載せるのが妥当か

  回答例: gcp/lesson5/syukudai2/

◼ドキュメントを眺めてみよう
  Cloud Run          https://cloud.google.com/run/docs
  Artifact Registry  https://cloud.google.com/artifact-registry/docs
  Direct VPC egress  https://cloud.google.com/run/docs/configuring/vpc-direct-vpc
  GKE Autopilot      https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview
```

---

### S49 | 参考

**[本文]**

```
Cloud Run ドキュメント
  https://cloud.google.com/run/docs

Artifact Registry ドキュメント
  https://cloud.google.com/artifact-registry/docs

サーバレスNEGでのロードバランシング
  https://cloud.google.com/load-balancing/docs/https/setting-up-https-serverless

Cloud Run のインスタンス自動スケーリング
  https://cloud.google.com/run/docs/about-instance-autoscaling

ホスティングオプションの選び方
  https://cloud.google.com/hosting-options
```

---

### S50 | 注意事項

**[図版]** AWS版「注意事項」スライドを流用。

**[本文]**

```
宿題などで作成したリソースは
必ず削除してください！

★★ destroy は2つの障害があります ★★

   ① 限定公開サービスアクセスのピアリング(第4回と同じ)
   ② Direct VPC egress が確保したIPアドレス(今回から)

   1. terraform destroy
        → ピアリングとサブネットの削除で失敗する

   2. ピアリングを直接消す
        gcloud compute networks peerings delete \
          servicenetworking-googleapis-com \
          --network=[自分の名前]-vpc

   3. SERVERLESS のアドレスが解放されるのを待つ
        gcloud compute addresses list --filter="purpose=SERVERLESS"

        ★ 公式ドキュメントに「1〜2時間待て」と書かれています
        ★ 手動では削除できません

   4. terraform destroy

★ 残るのは VPC とサブネットだけで、課金はありません
   慌てず、翌日にでも消してください

★ 年末年始を挟むので、消し忘れると長期間課金されます
   Spanner / Memorystore / VM / ロードバランサ / 外部IP

★ min_instance_count = 1 のまま放置しないこと(宿題2)

★ tfstate用のバケットは残しておいてください
```

**[話す]** 年末年始を挟む回なので、片付けを特に強く言う。
消し忘れると3週間分課金される。

---

### S51 | おしまい

**[図版]** AWS版「おしまい」スライドを流用。

**[本文]**

```
次回は ストレージ + CDN 編 です(1月18日)

Cloud Storage / Cloud CDN
静的ファイルの配信とキャッシュをやります

よいお年を！！
```

---

# 付録A: ハンズオンのステップ対応表

| Step | ディレクトリ | 作るもの | 確認すること |
|---|---|---|---|
| 0 | `0. before/` | 第2〜4回の全リソース(24個) | 20分かかる |
| 1 | `1. artifact_registry/` | Artifact Registry リポジトリ | イメージをpushできる |
| 2 | `2. cloud_run/` | Cloud Run + SA + Spanner IAM | **Spanner OK / Cache失敗** |
| 3 | `3. vpc_egress/` | Direct VPC egress(1ブロック追加) | **Cache成功** |
| 4 | `4. loadbalancer/` | サーバレスNEG + LBフロント | カスタムドメインでアクセス |

AWS版 第6回との対応:

| AWS版 | GCP版 | 備考 |
|---|---|---|
| 0. before | 0. before | **LBのフロント側は含まない**(第5回で作り直すため) |
| 1. ecr | 1. artifact_registry | ログインが1行になる |
| 2. iam | (2. cloud_run に統合) | タスク実行ロールが不要 |
| 3. secret | — | 今回は環境変数のみ。Secret Manager は第1回宿題で既習 |
| 4. ecs | 2. cloud_run | **10リソース → 3リソース** |
| — | 3. vpc_egress | **新規**。AWSには無い概念 |
| — | 4. loadbalancer | AWS版はECSサービスがターゲットグループに直接登録できた |

## `0. before` に LBのフロント側を含めていない理由

第5回では URLマップの向き先を Cloud Run に差し替える。
URLマップがモジュールの中にあると外から変更できないため、
URLマップ / HTTPSプロキシ / 転送ルール は `0. before` から外し、
第5回で作る構成にしている。

グローバルIP / SSL証明書 / DNSレコード / VMのバックエンドサービスは
`0. before` に残してあるので、ロールバックの説明(S40)が成立する。

---

# 付録A-2: destroy の手順(重要)

**この回の destroy は2つの障害がある。** 当日の最後に必ず案内すること。

## ① 限定公開サービスアクセスのピアリング(第4回と同じ)

```
Error: Unable to remove Service Networking Connection
Failed to delete connection; Producer services are still using this connection.
```

`gcloud compute networks peerings delete servicenetworking-googleapis-com
 --network=<自分の名前>-vpc` で直接消す。

## ② Direct VPC egress が確保したIPアドレス(今回から)

```
Error: The subnetwork resource '<自分の名前>-private-subnet' is already
being used by 'addresses/serverless-ipv4-XXXXXXXXXX', resourceInUseByAnotherResource
```

Direct VPC egress を使うと、Cloud Run のインスタンス用に
`purpose = SERVERLESS` のIPアドレスがサブネットに確保される。

**Cloud Run を削除してもこのアドレスはすぐには解放されない。**
Terraform から見ると Cloud Run は消えているので、
そのままサブネットを消しに行って弾かれる。

```
gcloud compute addresses list --filter="purpose=SERVERLESS"
```

**このアドレスは直接削除できない。**

```
gcloud compute addresses delete serverless-ipv4-XXXXXXXXXX --region=asia-northeast1
```

```
The address resource '...' is already being used by
'//serverless.googleapis.com/.../addressReservations/serverless-ipv4-XXXXXXXXXX'
```

**これは仕様。公式ドキュメントに明記されている。**

> After you delete or move your Cloud Run resources, wait **1-2 hours**
> for Cloud Run to release the IP addresses before you delete the subnet.
>
> **You cannot manually delete a reserved address.**
>
> https://cloud.google.com/run/docs/configuring/vpc-direct-vpc

つまり **1〜2時間待つしかない**。

## 手順

```
# 当日(講義の最後)
terraform destroy
  → Cloud Run / Spanner / Memorystore などは消える
  → ピアリングとサブネットの削除で失敗する

gcloud compute networks peerings delete servicenetworking-googleapis-com \
  --network=<自分の名前>-vpc

# 翌日
gcloud compute addresses list --filter="purpose=SERVERLESS"
  → 消えていることを確認

terraform destroy
  → 残りの VPC とサブネットが消える
```

> **検証時の実測(2026-08-28)**: 32分待っても解放されなかった。
> 公式ドキュメントの「1〜2時間」は現実的な値。

**課金は当日で止まる**

残るのは VPC とサブネットだけで、どちらも課金されない。
Cloud Run / Spanner / Memorystore / VM / ロードバランサ / 外部IP は
1回目の destroy で消えている。

**受講者への案内**

「destroyでエラーが2種類出ます。慌てないでください。
課金されるものは全部消えています。
ピアリングを消して、翌日にもう一度 destroy してください」

と先に言っておくこと。
**当日中に完全に消そうとすると1〜2時間待つことになる。**

---

# 付録B: 制作メモ / 要確認事項

## 実環境での動作確認: **完了(2026-08-28)**

受講者相当の権限(第1回 付録Aの10ロール)で Step0〜4 を通しで実行。
`terraform validate` は全6ディレクトリで成功(google provider 8.0.0)。

| 項目 | 結果 |
|---|---|
| `0. before`(24リソース) | **OK**。受講者権限で作成できた |
| Artifact Registry の作成と push | **OK**。`gcloud auth configure-docker` の1行で認証できた |
| イメージのビルド | 60秒(ローカルのdockerで代用。キャッシュなし) |
| Cloud Run のデプロイ | **OK**。35秒 |
| **Step2: Spanner 成功 / Cache 失敗** | **完全再現**。S28の主張どおり |
| `hostname: localhost` | **OK**。S35の主張どおり |
| **Step3: Direct VPC egress で Cache 成功** | **OK**。apply 16秒。反映待ちなし |
| Step4: サーバレスNEG + LB | **OK**。5リソース |
| カスタムドメインでのアクセス | **OK**。ただし伝播に**約7分30秒** |
| 証明書の使い回し | **OK**。第3回の証明書がそのまま使われ、再発行は走らなかった |

### この回の核心は狙いどおり動いた

**S28 → S34 の「繋がらない → 繋がる」サイクル**が実環境で再現した。

- Cloud Run は VPC の外にいるので、Google API 経由の Spanner には繋がる
- ピアリング経由の Memorystore には繋がらない
- `vpc_access` ブロックを1つ足すだけで解決する

第4回の「3種類の接続方式」がそのまま回収できている。

### 判明した時間の問題

**S41のロードバランサ伝播(7分30秒)が講義の最後に来る。**

Step4のapplyを流したらすぐ S43(まとめ)に進み、
最終確認は各自でやってもらう構成にすること。原稿に追記済み。

### まだ検証できていないこと

- **Cloud Shell でのビルド時間**。検証ではローカルのdockerで代用した
- 宿題1(min_instance_count / concurrency)の実測
- destroy の完了(SERVERLESSアドレスの解放に1〜2時間かかるため、翌日に持ち越し)

## 受講者ロールへの追加(確認済み)

`roles/editor` の権限一覧と照合した結果、追加が必要なのは1ロールだけ。

```
roles/run.admin        run.services.setIamPolicy
```

| 権限 | Editor に含まれるか |
|---|---|
| `artifactregistry.repositories.create` / `.uploadArtifacts` | 含む |
| `run.services.create` / `.update` / `.delete` | 含む |
| `compute.regionNetworkEndpointGroups.create` / `.use` | 含む |
| **`run.services.setIamPolicy`** | **含まない** → `roles/run.admin` |

`roles/artifactregistry.admin` は不要。
第1回 付録A の付与コマンドを10ロールに更新済み。

## 新規作図が必要なスライド

| スライド | 内容 | 優先度 |
|---|---|---|
| S23 | ECS 10リソース vs Cloud Run 3リソース | **最高** |
| S29 | Cloud Run がVPCの外にいる図 | **最高** |
| S32 | Direct VPC egress | 高 |
| S38 | インスタンスグループ vs サーバレスNEG | 高 |
| S04 | 移行の前後(VM → Cloud Run) | 高 |
| S15 | ゴール構成図 | 高 |
| S07 | GKE / Cloud Run の位置づけ | 中 |
| S12 | 使い分けの判断フロー | 中 |

## 設計書からの変更点

- 設計書のアジェンダにある「サービスアカウントと Secret Manager」のうち
  Secret Manager は扱っていない。第1回の宿題2で既習であり、
  今回は環境変数で足りるため。必要なら宿題に回せる
- 「LBのバックエンドに繋ぐ」を単なる追加ではなく
  **VMからの移行**として構成した。第3回・第4回の資産が
  そのまま活きる形になり、実務の手順とも一致する
