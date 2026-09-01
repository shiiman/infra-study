# 第7回 インフラ勉強会(GCP) — CI/CD

- **開催日**: 2027-02-08(月) 2時間
- **AWS版対応**: 第8回(AWS CI/CD編)
- **Terraformコード**: `gcp/lesson7/`
- **ゴール**: GitHub に push すると自動でビルドされ、Cloud Run にデプロイされる状態を作る

> **この回の軸は「Terraform と CI/CD の責務を分ける」こと。**
> 第5回・第6回では、デプロイも `terraform apply` だった。
> 今日からは **インフラの形は Terraform、動かすバージョンは CI/CD** に分かれる。
> その境界を `lifecycle { ignore_changes }` の1ブロックで表現する。

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入 | 6分 | S01〜S04 |
| CI/CDとは / AWSとの構成比較 | 16分 | S05〜S12 |
| 休憩 | 5分 | S13 |
| 準備 + Step1(Artifact Registry) | 14分 | S14〜S19(S17b含む) |
| Step2(トリガー)→ 失敗 | 25分 | S20〜S28 |
| Step3(権限)→ 成功 | 17分 | S29〜S34 |
| **Step4(GitHub Actions + WIF)** | 18分 | S34b〜S34j |
| 責務の分界 | 10分 | S35〜S38 |
| まとめ・宿題 | 9分 | S39〜S47 |

> **★ Step4 のビルド待ち(約5分)に S34g(Terragrunt)と S34h(SOPS)を挟む。**
> ビルド待ちはこれで3回目になるが、待ち時間を説明枠に変えることで
> Step4 の実コストを 18分に抑えている。

> **待ち時間**
> - S15 `0. before` + Step1 の apply: 約10分(実測。40リソース)
> - S24 1回目のビルド: **約5分20秒**(実測。Goの依存解決が重い)
> - S30 2回目のビルド: **同じく約5分**(キャッシュしていないので毎回このくらい)
>
> **ビルド待ちが2回で計10分ある。** ここが尺を圧迫するので、
> 1回目は S26〜S28(なぜ権限が2つ要るのか)を話しながら待つ。
> 2回目は S32〜S33(バージョンの埋め込み / リビジョン)を話しながら待つ。
>
> **`0. before` を最初に流してから CI/CD の話に入る構成にしてある。**
>
> 押した場合の削り所: S08〜S10(CI/CDの一般論)は口頭のみで圧縮できる。
>
> **削ってはいけないのは S11**(AWS 4サービス vs GCP 2サービス)、
> **S26〜S31**(ビルドが失敗する → 権限2つを足す)、
> **S35〜S37**(Terraform と CI/CD の責務分界)。この回の核心。

## 事前準備(講師)

**★ この回は事前準備が今までで一番重い。前週までに終わらせること。**

> **★ 順番が大事。** アプリ用リポジトリは **接続を作る前に**用意すること。
> GitHub App を「選択したリポジトリ」でインストールすると、
> **後から作ったリポジトリは Cloud Build から見えない**。
> あとで org の設定画面に戻ってリポジトリを追加する羽目になる。

### 1. アプリ用の GitHub リポジトリを用意する

受講者全員がここに push する。**ブランチで担当を分ける。**

```
gh repo create [org]/[アプリ用リポジトリ] --private
```

`gcp/lesson7/app/` の中身をそのまま置く。

```
main.go  go.mod  dockerfile  cloudbuild.yaml  cloudbuild-ci.yaml  deploy/
```

受講者に write 権限を付ける。

### 2. GitHub 接続を作る(★ コンソールでやること)

**ここだけはブラウザでの作業になる。gcloud だけでは完結しない。**

Google Cloud コンソール → **Cloud Build → リポジトリ → 第2世代**
→ 「ホスト接続を作成」→ リージョン `asia-northeast1` → GitHub → 「接続」

GitHub の認可画面が出るので承認する。
**この1回で、GitHub App のインストールとトークンの Secret Manager 保存が
両方とも自動で行われる。**

> **gcloud でやろうとすると手順が増える。**
> コンソールを使わない場合は、
> ① GitHub App を手でインストールしてインストールIDを控える
> ② PAT(`repo` / `read:user` / `read:org`)を発行する
> ③ Secret Manager に入れて Cloud Build サービスエージェントに読み取り権限を付ける
> ④ `gcloud builds connections create github` に①③を渡す
> の4段階になる。**コンソールを勧める。**

### 3. リポジトリをリンクする

接続ができたら、同じ画面の「リンク済みリポジトリ」から追加するか、
gcloud で作る。

> リンク候補に出てこない場合は、GitHub App がそのリポジトリを見られていない。
> GitHub の org 設定 → GitHub Apps → Google Cloud Build → Configure
> → Repository access にリポジトリを追加する。

```
gcloud builds repositories create [リポジトリリンク名] \
  --remote-uri=https://github.com/[org]/[アプリ用リポジトリ].git \
  --connection=[接続名] --region=asia-northeast1
```

**接続とリポジトリリンクは講師が1回だけ作る。受講者は作らない。**

### 4. 受講者に渡す値

```
gcloud builds repositories describe [リポジトリリンク名] \
  --connection=[接続名] --region=asia-northeast1 --format="value(name)"
```

これを `terraform.tfvars` の `cloudbuild_repository` に貼らせる。

### 5. ★ 受講者ごとのビルド用サービスアカウントを作る

**プロジェクト全体のIAMは受講者に触らせないため、講師が作る。**

`roles/logging.logWriter` はプロジェクト単位でしか付けられず、
それを付けるための `resourcemanager.projects.setIamPolicy` は
共有プロジェクトでは配れない(付けると誰にでも好きなロールを渡せてしまう)。

```
for u in shiiman tanaka suzuki; do
  gcloud iam service-accounts create "${u}-build" \
    --display-name="${u} cloud build" --project=[プロジェクトID]

  for ROLE in roles/logging.logWriter roles/clouddeploy.jobRunner; do
    gcloud projects add-iam-policy-binding [プロジェクトID] \
      --member="serviceAccount:${u}-build@[プロジェクトID].iam.gserviceaccount.com" \
      --role="$ROLE" --condition=None
  done
done
```

| ロール | いつ要るか |
|---|---|
| `roles/logging.logWriter` | **講義**。無いとビルドがそもそも始まらない |
| `roles/clouddeploy.jobRunner` | **宿題1・2**。Cloud Deploy の実行主体として必要 |

どちらもプロジェクト単位でしか付けられないので、受講者には配れない。

受講者は `data "google_service_account"` で参照するだけ。
リソース単位の権限(リポジトリ / Cloud Run / SA)は受講者が自分で付ける。

### 6. 受講者ロールに1つ追加する

`roles/artifactregistry.admin` を足す(**11個目**)。

`google_artifact_registry_repository_iam_member` に要る
`artifactregistry.repositories.setIamPolicy` が、
既存の10ロールのどれにも入っていないため。
第4回以降と同じ「`setIamPolicy` だけ別ロール」のパターン。

### 7. ★ Workload Identity プールとプロバイダを作る(Step4 用)

**GitHub Actions から GCP を触れるようにする。プロジェクトに1つでよい。**

サービスアカウントの鍵ファイルは作らない。
GitHub が発行する OIDC トークンを GCP が直接検証する形にする。

```
PROJECT_ID=[プロジェクトID]
PROJECT_NO=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# 1. プール(GCPの外のIDを受け入れる箱)
gcloud iam workload-identity-pools create github \
  --location=global --display-name="GitHub Actions" --project=$PROJECT_ID

# 2. プロバイダ(GitHub の OIDC を信頼する設定)
gcloud iam workload-identity-pools providers create-oidc github \
  --location=global --workload-identity-pool=github \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repo_ref=assertion.repository+'@'+assertion.ref" \
  --attribute-condition="assertion.repository_owner=='[org]'" \
  --project=$PROJECT_ID
```

> **★ `attribute.repo_ref` を必ず入れること。**
> `attribute.repository` だけだと「リポジトリ単位」でしか絞れない。
> 全員が同じリポジトリを使うので、それでは
> **他人のブランチから自分のSAが使えてしまう。**
> `repository + "@" + ref` を1つの属性にしておくことで、
> 受講者側が「自分のブランチだけ」に絞れるようになる。

> **★ `--attribute-condition` も必ず入れること。**
> これが無いと、**世界中のどのGitHubリポジトリからでも**
> トークンの入口までは通ってしまう(実際にSAを使えるかは
> 受講者側の `principalSet` 次第だが、入口は絞っておくべき)。

**受講者に渡す値**

```
gcloud iam workload-identity-pools describe github \
  --location=global --project=$PROJECT_ID --format="value(name)"
```

これを `terraform.tfvars` の `workload_identity_pool_id` に貼らせる。

### 8. アプリ用リポジトリに Variables を2つ設定する

**★ 講師が1回だけ設定する。受講者は触らない。**

```
gh variable set WIF_PROVIDER --repo [org]/[アプリ用リポジトリ] \
  --body "projects/$PROJECT_NO/locations/global/workloadIdentityPools/github/providers/github"

gh variable set PROJECT_ID --repo [org]/[アプリ用リポジトリ] --body "$PROJECT_ID"
```

> **★ 受講者ごとに違う値は Variables に入れないこと。**
> 全員で1つのリポジトリを共有しているので、リポジトリ変数も全員で共有される。
> ここに `SERVICE=shiiman-app` などと書くと、**他の人のビルドが壊れる**。
>
> リポジトリ名 / サービス名 / SA は、ワークフロー側で
> `${{ github.ref_name }}`(= ブランチ名 = 自分の名前)から組み立てる。
> Cloud Build のトリガーで `substitutions` に渡したのと同じ発想。
> **この制約自体が S34d の教材になる。**

### 9. API を有効化する

```
gcloud services enable clouddeploy.googleapis.com --project=[プロジェクトID]
```

Cloud Build は既に有効。Cloud Deploy は宿題で使う。

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない

---

# 導入

---

### S01 | タイトル

**[図版]** AWS版 第8回 表紙を複製。タイトルのみ差し替え。

**[本文]**

```
第7回 インフラ勉強会(GCP)

〜 CI/CD 編 〜

2027年2月8日
```

---

### S02 | ロードマップ

**[図版]** 第1回 S02 と同じスライドを複製。今日の行(2月8日)にマーカーを移す。

---

### S03 | 前回の振り返り

**[図版]** AWS版 第8回「前回」を流用。中身を差し替え。

**[本文]**

```
◼前回やったこと

Cloud Storage に静的ファイルを置いた
Cloud CDN はロードバランサの機能だった(enable_cdn = true)
URLマップのパスルールで /static/* を振り分けた
allUsers に公開しないとCDNも読めなかった
キャッシュは Cache-Control で寿命が決まる

★ ここまでの6回で、インフラは一通り揃いました
★ 今日は「そこに何を、どうやって載せるか」の話です
```

---

### S04 | 今日やること

**[図版]** **新規作成**。push から Cloud Run までの流れ。

```
  [自分のPC]
      │ git push origin <自分の名前>
      ▼
  [GitHub]  ← 全員で1つのリポジトリ。ブランチで分ける
      │ (webhook)
      ▼
  [Cloud Build トリガー]  ← 自分の名前のブランチだけ見る
      │
      ├─ 1. docker build
      ├─ 2. Artifact Registry に push
      └─ 3. gcloud run deploy
                 │
                 ▼
           [Cloud Run]  ← 第5回で作ったもの。イメージだけ入れ替わる
```

**[本文]**

```
◼push したら勝手にデプロイされる状態を作ります

  今まで: コードを直す → 手で docker build → 手で push →
          terraform apply

  今日から: コードを直す → git push
            あとは全部自動

★ 第5回で手でやっていたことが、そのまま自動になります
```

---

# CI/CDとは

---

### S05 | CI/CD

**[図版]** AWS版 第8回「CI/CDとは」を流用。

**[本文]**

```
◼CI(継続的インテグレーション)
コードを変えたら、すぐビルドしてテストする
「動かないコードが混ざったまま気づかない」を防ぐ

◼CD(継続的デリバリー / デプロイ)
ビルドが通ったものを、すぐ動く場所に届ける
「リリース作業」という特別なイベントを無くす

◼何のためか
  人の手作業を減らす        → 手順の抜けが減る
  誰がやっても同じ結果      → 属人性が減る
  小さく頻繁に出せる        → 問題の切り分けが楽になる

★ 「自動化して楽をする」より
   「毎回同じことが起きる」ほうが本質です
```

---

### S06 | 手でやると何が起きるか

**[本文]**

```
◼第5回・第6回でやっていたこと

  1. コードを直す
  2. docker build
  3. docker push
  4. terraform apply

◼これで困ること

  手順を忘れる            「push し忘れて古いイメージのままだった」
  人によって違う          「自分の環境ではビルドが通る」
  誰がやったか残らない    「いつ何を出したか分からない」
  権限が広くなる          全員が本番にデプロイできる状態

★ 4番目が一番こわい
   CI/CD にすると「人はデプロイ権限を持たなくてよくなる」
```

**[話す]** ここは強調したい。CI/CD は自動化の話に見えて、
実は「権限を人から機械に移す」話でもある。
今日つくるサービスアカウントの権限設計がその中身になる。

---

### S07 | AWS版でやったこと

**[図版]** AWS版 第8回の構成図をそのまま流用。

**[本文]**

```
◼AWS版 第8回で作ったもの

  CodeCommit    ソースコードを置く
  CodeBuild     ビルドする
  CodeDeploy    ECSにBlue/Greenでデプロイする
  CodePipeline  上の3つをつなぐ

  4つのサービス + それぞれのIAMロール

◼設定ファイルも2つ
  buildspec.yml   ビルドの手順
  appspec.yml     デプロイの手順
```

---

### S08 | GCPではどうなるか ★

**[図版]** **新規作成**。この回の最重要図その1。AWS 4サービス vs GCP 2サービス。

```
   AWS                             GCP

   [CodeCommit]  ソース             [GitHub]      ← GCPの外
        │                               │
   [CodePipeline] つなぐ            [Cloud Build] ← ビルドもデプロイもやる
    ├─ [CodeBuild]  ビルド              │
    └─ [CodeDeploy] デプロイ            ▼
        │                          [Cloud Run]
        ▼
     [ECS]

   4サービス + 3つのIAMロール       1サービス + 1つのサービスアカウント
   buildspec.yml + appspec.yml     cloudbuild.yaml
```

**[本文]**

```
◼Cloud Build がビルドもデプロイも両方やる

  ステップを上から順に実行するだけ

    1. docker build
    2. docker push
    3. gcloud run deploy

  「デプロイ専用のサービス」を挟まなくてよい

◼設定ファイルは1つ

  cloudbuild.yaml に全部書く

★ 段階的なデプロイ(カナリア)をやりたくなったら
   Cloud Deploy を足す → 今日の宿題
```

**[話す]** AWS版のコードを開くと、IAMロールとポリシーの定義だけで
かなりの行数がある。今日はサービスアカウント1つで済む。
その代わり「どの権限を付けるか」を自分で考える必要があって、
そこが後半の山場になる。

---

### S09 | ソースコードはどこに置くか

**[本文]**

```
◼AWSには CodeCommit があった
  AWSの中にGitリポジトリを持てた

◼GCPにも Cloud Source Repositories がありました

  ★ 2024年6月に新規提供を終了しています ★

  既存ユーザは使えますが、これから始めるものではありません
  後継として Secure Source Manager が案内されています

◼実質、GitHub(または GitLab)が前提になります

  GCPの外にソースがある
  → 「GCPから GitHub を読む」ための接続が必要になる
  → ここだけコードにできない手作業が残ります
```

---

### S10 | GitHub 連携に必要なもの

**[図版]** 新規。GitHub と GCP の間に接続が挟まる図。

**[本文]**

```
◼2つ必要です

  1. GitHub 側に「Cloud Build」の GitHub App をインストール
     → ブラウザでの承認作業

  2. GitHub のアクセストークンを Secret Manager に入れる
     → 接続がこれを使って GitHub を読む

  この2つで「接続(connection)」ができます

◼勉強会では講師が1回だけやってあります

  受講者はその接続にぶら下がるだけ
  terraform.tfvars に1行貼るだけで使えます

★ 自分のプロジェクトで一から組むときは、
   ここが最初の関門になります。覚えておいてください
```

---

### S11 | 全員で1つのリポジトリを使います ★

**[図版]** **新規作成**。1リポジトリ・N ブランチ・N トリガーの図。

```
     [アプリ用リポジトリ]  ← 1つのリポジトリ

   ブランチ         トリガー              デプロイ先
   ─────────────────────────────────────────────
   shiiman     →  shiiman-deploy   →   shiiman-app
   tanaka      →  tanaka-deploy    →   tanaka-app
   suzuki      →  suzuki-deploy    →   suzuki-app

   cloudbuild.yaml は1つを全員で共有
   違いは substitutions で渡す
```

**[本文]**

```
◼自分の名前のブランチに push してください

  git push origin <自分の名前>

  自分のトリガーだけが動きます
  他の人のブランチに push しても、自分のビルドは走りません

◼cloudbuild.yaml は全員共通

  「どのリポジトリに push するか」
  「どのサービスにデプロイするか」
  はトリガーの substitutions から渡します

★ main ブランチには push しないでください
```

---

### S12 | cloudbuild.yaml の読み方

**[本文]**

```
参照: アプリのリポジトリの cloudbuild.yaml

steps:
  - id: build
    name: gcr.io/cloud-builders/docker
    args: [build, -t, ${_REGION}-docker.pkg.dev/$PROJECT_ID/${_REPO}/app:$SHORT_SHA, .]

  - id: push
    name: gcr.io/cloud-builders/docker
    args: [push, ...]

  - id: deploy
    name: gcr.io/google.com/cloudsdktool/cloud-sdk
    entrypoint: gcloud
    args: [run, deploy, ${_SERVICE}, --image, ..., --region, ${_REGION}]

options:
  logging: CLOUD_LOGGING_ONLY

◼ステップは「コンテナを1つ動かす」単位

  name  使うコンテナイメージ
  args  そのコンテナに渡す引数

  gcloud も docker も、コンテナとして動いています

◼変数の種類
  $PROJECT_ID $SHORT_SHA $BRANCH_NAME   Cloud Buildが自動で入れる
  ${_REGION} ${_REPO} ${_SERVICE}        トリガーから渡す(_ で始める)
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
  mkdir -p ~/works/lesson7
  cd ~/works/lesson7

◼サンプルコードを更新
  cd ~/infra-study && git pull
  cd ~/works/lesson7

★★ 第6回のリソースは destroy 済みですか ★★

   第6回の destroy も SERVERLESS アドレスの解放待ちがありました

     gcloud compute networks list
     gcloud compute addresses list --filter="purpose=SERVERLESS"

◼アプリのリポジトリも clone してください
  cd ~
  git clone https://github.com/[org]/[アプリ用リポジトリ].git
  cd [アプリ用リポジトリ]
  git checkout -b [自分の名前]
```

---

### S15 | 前回までの完成状態を読み込む

**[本文]**

```
参照: gcp/lesson7/1. artifact_registry/before.tf

module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson7/0. before"
  ...
}

◼中身は第2回〜第6回で作ったもの(38リソース)
  ネットワーク / Memorystore / Spanner /
  Cloud Run / サーバレスNEG /
  Cloud Storage / バックエンドバケット / ロードバランサ一式

  terraform init
  terraform apply

★ 10分ほどかかります。先に流してから解説に入ります

★ 今回は第6回の完成形が「まるごと」入っています
   第5回・第6回では「今日いじるものは外す」方針でしたが、
   今日いじるのは Terraform のコードではなく
   **デプロイの仕組み** なので、インフラの形はそのまま使います

★ ただし Cloud Run に1ブロックだけ足してあります
   何を足したかは Step3 で説明します
```

---

### S16 | Artifact Registry を作る

**[本文]**

```
参照: gcp/lesson7/1. artifact_registry/artifact_registry.tf

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

★ 第5回で一度作ったものと同じです

★ 第6回では作りませんでした
   「イメージが無いと Cloud Run は作れない」ので、
   リポジトリ作成 → push → Cloud Run 作成 を
   1回の apply に畳めなかったためです

   今日からは自分のリポジトリに、
   自分が push したコードから作られたイメージが入ります
```

---

### S17 | ビルド用のサービスアカウント ★

**[本文]**

```
data "google_service_account" "build" {
  account_id = "${var.user_name}-build"
}

★ resource ではなく data です。講師が作ってあります

◼AWSでは3つのロールが必要でした
  CodeBuild用 / CodeDeploy用 / CodePipeline用

◼GCPは1つで済みます
  ビルドもデプロイも Cloud Build がやるので

◼なぜ既定のSAを使わないのか

  Cloud Build には昔から使われている既定のSAがありますが、
  2024年以降のプロジェクトでは自動では作られず、
  明示的に指定するのが推奨になっています

  それ以上に大事なのは
  **ビルドが持つ権限を自分で決められる**こと

  既定SAは強い権限を持ちがちで、
  「CIが乗っ取られたら何ができるか」が読めなくなります
```

---

### S17b | なぜ講師が作ってあるのか ★

**[図版]** **新規作成**。IAM を付けられる階層と、誰が持つかの図。

```
   プロジェクト全体のIAM        ← 基盤チーム / 講師だけが触れる
     roles/logging.logWriter
   ──────────────────────────────────────
   リソース単位のIAM            ← 使う人が自分で付ける
     Artifact Registry のリポジトリ
     Cloud Run のサービス
     サービスアカウントそのもの
```

**[本文]**

```
◼このSAには roles/logging.logWriter が要ります

  ログを書けないと、ビルドがそもそも始まりません

◼ところが Cloud Logging の権限は
  プロジェクト単位でしか付けられません

  そして「プロジェクト全体のIAMを書き換える権限」は、
  みんなで使っている共有プロジェクトでは配れません
  → 誰にでも好きなロールを付けられてしまうため

◼これは勉強会の都合ではありません

  プロジェクト全体のIAM  → 基盤チームが持つ
  リソース単位のIAM      → 使う人が自分で付ける

  実務でもこうなります

★ 今日 Step1・Step3 で自分が付ける権限は、
   全部 **リソース単位** です
   「自分のリポジトリ」「自分のサービス」「自分のSA」にしか付けません
```

**[話す]** ここは権限設計の話として大事。
「なんで自分で全部できないの」ではなく、
「リソース単位で付けられるように作られている」ことに気づいてほしい。

---

### S18 | 最初に付ける権限は1つだけ

**[本文]**

```
resource "google_artifact_registry_repository_iam_member" "build_writer" {
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_service_account.build.email}"
}

◼artifactregistry.writer — イメージを push する権限

  ★ リポジトリ単位で付けています ★
  プロジェクト全体ではなく
  「このビルドは自分のリポジトリにだけ push できる」状態

  付ける先がリソース(リポジトリ)なので、自分で付けられます

★ デプロイの権限はまだ付けていません。わざとです
```

---

### S19 | Step1 実行

**[本文]**

```
  terraform plan
  terraform apply

◼確認
  terraform output repository_url
  → asia-northeast1-docker.pkg.dev/[プロジェクトID]/[自分の名前]-repo

  terraform output build_sa_email
  → [自分の名前]-build@[プロジェクトID].iam.gserviceaccount.com

★ まだ何も自動化されていません
★ 次でトリガーを作ります
```

---

# Step2: トリガー

---

### S20 | ビルドトリガー

**[本文]**

```
参照: gcp/lesson7/2. cloud_build/cloud_build.tf

resource "google_cloudbuild_trigger" "app" {
  name     = "${var.user_name}-deploy"
  location = "asia-northeast1"

  service_account = data.google_service_account.build.name

  repository_event_config {
    repository = var.cloudbuild_repository

    push {
      branch = "^${var.user_name}$"
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _REGION  = "asia-northeast1"
    _REPO    = google_artifact_registry_repository.app.repository_id
    _SERVICE = module.before.cloud_run_name
  }
}

★ ^ と $ で囲むこと
   囲まないと部分一致になり、他の人のブランチにも反応します
```

---

### S21 | 講師から渡された値を貼る

**[本文]**

```
terraform.tfvars

// TODO: 講師が作成した Cloud Build のリポジトリリンクを指定
cloudbuild_repository = ""

◼こういう値が入ります

  projects/[プロジェクトID]/locations/asia-northeast1/
    connections/[接続名]/repositories/[リポジトリリンク名]

◼自分でも確認できます

  gcloud builds repositories list \
    --connection=[接続名] --region=asia-northeast1

★ 接続とリポジトリリンクは講師が作ってあります
★ 皆さんは「そこにトリガーをぶら下げる」だけです
```

---

### S22 | Step2 実行

**[本文]**

```
  terraform plan
  terraform apply

◼確認
  gcloud builds triggers list --region=asia-northeast1 \
    --format="table(name,filename)"

  → [自分の名前]-deploy   cloudbuild.yaml

★ できました。push してみましょう
```

---

### S23 | push してみる

**[本文]**

```
◼アプリのリポジトリで、何か1行変えてみてください

  cd ~/[アプリ用リポジトリ]

  例: main.go の "Hello, Infra Study" を
      "Hello, Infra Study!!" にする

◼自分の名前のブランチに push

  git add .
  git commit -m "test"
  git push origin [自分の名前]

◼ビルドが始まったか見る

  gcloud builds list --region=asia-northeast1 --limit=3 \
    --format="table(id,status,substitutions.BRANCH_NAME)"
```

---

### S24 | ビルドを見守る

**[本文]**

```
◼ログを追いかける

  gcloud builds log [ビルドID] --region=asia-northeast1 --stream

◼コンソールでも見られます

  Cloud Build → 履歴 → 該当のビルド

★ Goのビルドが入るので3〜5分かかります

★ 待っている間に、ステップの読み方を確認します
   build → push → deploy の3つが順に流れます
```

---

### S25 | Step2 の結果 → 失敗する

**[図版]** ビルド失敗の画面。**開催前に実物のスクリーンショットを撮ること**。

**[本文]**

```
◼build は成功
◼push も成功
◼deploy で失敗します

  Step #2 - "deploy": ERROR: (gcloud.run.deploy)
  PERMISSION_DENIED: Permission 'run.services.get' denied on resource
  'namespaces/[プロジェクトID]/services/[自分の名前]-app'
  (or resource may not exist). This command is authenticated as
  [自分の名前]-build@[プロジェクトID].iam.gserviceaccount.com ...

★ 「(or resource may not exist)」に惑わされないこと
   サービスは存在します。読む権限が無いだけです
   GCPは「見えない」と「無い」を区別しないので、
   権限不足がこの文言で出てくることがよくあります

◼イメージはできています

  gcloud artifacts docker images list \
    asia-northeast1-docker.pkg.dev/[プロジェクトID]/[自分の名前]-repo

  → ちゃんと入っている

★ ビルドまでは動いた。デプロイだけができない

なぜだと思いますか？
```

**[話す]** ここは全員止まる。AWS版でも CodePipeline のロール不足で
同じような場面があった。エラーメッセージを一緒に読む時間を取る。

---

### S26 | 権限が足りない ★

**[図版]** **新規作成**。この回の最重要図その2。2つの権限が揃って初めて通る図。

```
   [Cloud Build SA]
        │
        │ ① デプロイ先を更新してよいか？
        ▼
   [Cloud Run サービス]  roles/run.developer
        │
        │ ② その中で動くSAを使ってよいか？
        ▼
   [Cloud Run 実行SA]    roles/iam.serviceAccountUser

   両方揃わないとデプロイできない
```

**[本文]**

```
◼Step1 で付けたのは2つだけでした

  roles/logging.logWriter          ログを書く
  roles/artifactregistry.writer    イメージを push する

  デプロイの権限は付けていません

◼デプロイには権限が2つ要ります

  1. デプロイ先を更新する権限        roles/run.developer
  2. 実行SAになりすます権限          roles/iam.serviceAccountUser

★ 1つ目だけでは通りません。ここが一番ハマるところ
```

---

### S27 | なぜ2つ要るのか ★

**[本文]**

```
◼Cloud Run には「動くときに名乗るサービスアカウント」がある

  第5回で作った <自分の名前>-run
  Spanner や Memorystore にアクセスする権限を持っている

◼デプロイするということは

  「そのサービスアカウントの権限で動くものを作る」ということ

◼もし1つ目の権限だけでデプロイできてしまうと

  ビルドを乗っ取った人が、
  もっと強い権限のサービスアカウントを指定して
  好きなコードを動かせてしまう

  → 権限昇格

◼だから「そのSAを使ってよい」という許可が別に要る

  roles/iam.serviceAccountUser

★ AWSでいうと iam:PassRole と同じ考え方
   AWS版 第8回でも CodePipeline のロールに PassRole を入れていました
```

**[話す]** ここは今日一番大事なところ。
「デプロイ権限」が実は2階建てになっているという話は、
GCPでもAWSでも、CI/CDを組むたびに出てくる。

---

### S28 | 第2回でも同じロールが出ました

**[本文]**

```
◼roles/iam.serviceAccountUser は初めてではありません

  第2回 IAP で VM に入るとき
  → VMが名乗るSAを「使ってよい」許可が要った

  第7回 Cloud Build がデプロイするとき
  → Cloud Runが名乗るSAを「使ってよい」許可が要る

◼考え方は同じ

  「サービスアカウントの権限を借りる行為」には、
  常に別途 許可が必要

★ GCPを触っていて permission denied が出たら、
   まずこのロールを疑うと当たることが多いです
```

---

# Step3: 権限を足す

---

### S29 | 権限を2つ足す

**[本文]**

```
参照: gcp/lesson7/3. deploy/deploy.tf

// 1. デプロイ先を更新する権限
resource "google_cloud_run_v2_service_iam_member" "build_developer" {
  name     = module.before.cloud_run_name
  location = module.before.cloud_run_location
  role     = "roles/run.developer"
  member   = "serviceAccount:${data.google_service_account.build.email}"
}

// 2. 実行SAになりすます権限
resource "google_service_account_iam_member" "build_act_as_run" {
  service_account_id = module.before.cloud_run_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_service_account.build.email}"
}

★ 1つ目は サービス単位 で付けています
   roles/run.admin をプロジェクトに付ければ動きますが、
   それだと「このビルドは他人の Cloud Run も壊せる」状態になります

★ 2つ目の付け先は プロジェクトではなくサービスアカウント
   リソースとしてのSAに、ポリシーを付けています
```

---

### S30 | Step3 実行

**[本文]**

```
  terraform plan
  terraform apply

★ 数秒で終わります

◼もう一度 push してみる

  cd ~/[アプリ用リポジトリ]
  # もう1行変える
  git commit -am "test2"
  git push origin [自分の名前]
```

---

### S31 | 今度は成功する

**[本文]**

```
  gcloud builds list --region=asia-northeast1 --limit=1 \
    --format="table(id,status)"

  → SUCCESS

◼デプロイされたか確認

  curl https://[自分の名前].[勉強会のドメイン]/

  Hello, Infra Study!!          ← 変更が反映されている
  version: a1b2c3d              ← コミットのSHA
  revision: [自分の名前]-app-00002-xyz
  hostname: localhost
  DB接続(spanner): 成功
  Cache接続: 成功

★ push しただけで、ここまで来ました
```

---

### S32 | version はどこから来たのか

**[本文]**

```
◼ビルド時にイメージへ焼き込んでいます

  cloudbuild.yaml
    docker build --build-arg APP_VERSION=$SHORT_SHA ...

  dockerfile
    ARG APP_VERSION=dev
    RUN go build -ldflags "-X main.version=${APP_VERSION}" ...

  main.go
    var version = "dev"

◼なぜ環境変数にしないのか

  Cloud Run の環境変数は Terraform が管理しています
  (SPANNER_* / CACHE_HOST)

  CI/CD 側が --set-env-vars を使うと、
  既存の環境変数を全部消してしまい、DBに繋がらなくなります

★ 「イメージの中身」だけを CI/CD が決めるようにしておくと、
   Terraform と取り合いになりません
```

---

### S33 | リビジョンを見てみる

**[本文]**

```
  gcloud run revisions list --service=[自分の名前]-app \
    --region=asia-northeast1 \
    --format="table(name,status.conditions[0].status,creationTimestamp)"

  → 00001  第5回のイメージ(講師の共通イメージ)
    00002  自分がビルドしたイメージ

◼リビジョンは残ります

  デプロイのたびに新しいリビジョンができ、古いものも残る
  → 問題があればトラフィックを戻せる

  gcloud run services update-traffic [自分の名前]-app \
    --region=asia-northeast1 \
    --to-revisions=[前のリビジョン名]=100

★ これが一番手軽なロールバックです
★ 段階的な切り替え(カナリア)は宿題で扱います
```

---

### S34 | ここまでの到達点

**[図版]** S04の構成図を再掲し、全要素にチェックを付ける。

**[本文]**

```
◼できたこと

GitHub に push すると自動でビルドされる
イメージが Artifact Registry に入る
Cloud Run に自動でデプロイされる
デプロイに必要な権限を、必要な範囲だけ付けた
どのコミットが動いているか、画面で分かる
```

---

# Step4: GitHub Actions から同じことをやる

### S34b | もう1つのやり方

**[図版]** **新規作成**。同じ「push → デプロイ」を2本の経路で描く。
左が今やった Cloud Build、右がこれからやる GitHub Actions。
GitHub の箱は共通で、そこから2本に分かれる。

```
              [GitHub]  push
                 │
        ┌────────┴────────┐
    (webhook)          (GitHub Actions)
        │                     │
  [Cloud Build]      [Actions runner]  ← GCPの外で動く
        │                     │
        └────────┬────────┘
            [Cloud Run]
```

**[本文]**

```
◼さっきまでのやり方(Cloud Build)

  GitHub に push すると webhook が飛び、GCPの中でビルドが走る
  ビルドするマシンもGCPの中にある

◼もう1つのやり方(GitHub Actions)

  GitHub の中でビルドが走り、そこからGCPを操作する
  ビルドするマシンはGCPの外にいる

◼実務ではこちらのほうが多いです

  アプリのテストもリンタも、もう GitHub Actions で回っている
  デプロイだけ Cloud Build に分けると、2か所を見ることになる

★ ここで問題になるのが「GCPの外から、どうやってGCPを触るか」です
★ 今日はそこだけをやります
```

**[話す]** Cloud Build を先にやったのは、GCPの中で完結する形のほうが
権限の関係が見やすいから。外から触る形は、そこに認証の話が1つ増える。

---

### S34c | 鍵ファイルを配らない ★

**[図版]** **新規作成**。この回の最重要図その4。
上下2段。上が「昔のやり方(鍵ファイル)」、下が「Workload Identity 連携」。
上は鍵ファイルがGitHubのSecretsに置かれている図に ✕、
下はGitHubが発行したトークンをGCPが検証している図に ○。

```
  ✕ 昔のやり方
    [SAの鍵ファイル(JSON)] ──コピー──▶ [GitHub Secrets]
      ・有効期限がない        ・漏れたら誰でもGCPを触れる
      ・誰が持っているか分からない

  ○ Workload Identity 連携
    [GitHub Actions] ──「私は sumzap/infra-study-app の
                          refs/heads/shiiman です」(OIDCトークン)
           │
           ▼
    [GCP] トークンをGitHubの公開鍵で検証
           → 条件に合えば、SAの短命なトークンを渡す(1時間)
```

**[本文]**

```
◼サービスアカウントの鍵ファイルは作らないでください

  JSONの鍵を作って GitHub Secrets に貼る、が昔のやり方でした

  鍵には有効期限がない
  漏れたら、取り消すまで誰でも使える
  誰がコピーを持っているか分からない

◼Workload Identity 連携(WIF)

  GitHub Actions は、実行のたびに OIDC トークンを発行できる
  そのトークンには「どのリポジトリの、どのブランチか」が入っている

    repository : sumzap/infra-study-app
    ref        : refs/heads/shiiman

  GCP側で「この条件に合うトークンなら、このSAを使ってよい」と
  書いておけば、鍵ファイルなしでGCPを操作できる

  渡されるのは1時間で切れる短命なトークン

★ 第1回でやった「サービスアカウントの2つの顔」の話です
   ここでも「このSAを使ってよいのは誰か」を書いています
   その"誰か"に、人でもSAでもなく
   「GitHubのこのリポジトリのこのブランチ」を書けるようになった、というだけ
★ AWSでいうと、GitHub OIDC + IAMロールの AssumeRole と同じ仕組みです
```

**[話す]** 第1回のサービスアカウントの図(2つの顔)を思い出してもらう。
「使ってよいのは誰か」の"誰か"に、人でもSAでもなく
「GitHubのこのリポジトリのこのブランチ」を書けるようになった、というだけ。

---

### S34d | 誰が何を用意するか

**[図版]** **新規作成**。S17b の階層図と同じ描き方で、
「プロジェクトに1つあればよいもの(講師)」と
「自分のものに付けるもの(受講者)」に分ける。

**[本文]**

```
◼講師が用意してあるもの(プロジェクトに1つでよい)

  Workload Identity プール         GCPの外のIDを受け入れる箱
  Workload Identity プロバイダ      GitHub の OIDC を信頼する設定
                                  「トークンの何を見るか」の対応付けも書いてある

  ★ 作成はプロジェクト単位の操作なので、Cloud Build の GitHub 接続と同じ扱い

◼みなさんが今から書くもの

  自分のビルド用SAに、こう書きます

    「sumzap/infra-study-app の refs/heads/<自分の名前> から来たトークンなら、
      このSAを使ってよい」

  ★ 付ける先は サービスアカウント。リソース単位のIAMです
  ★ 他人のブランチから自分のSAは使えません

◼ワークフローファイル

  .github/workflows/deploy-<自分の名前>.yml
  cloudbuild.yaml と同じことを、GitHub Actions の書き方で書きます
```

---

### S34e | Step4: 自分のSAに許可を足す

**[本文]**

```
参照: gcp/lesson7/4. github_actions/wif.tf

resource "google_service_account_iam_member" "gha_wif" {
  service_account_id = data.google_service_account.build.name
  role               = "roles/iam.workloadIdentityUser"

  member = join("", [
    "principalSet://iam.googleapis.com/",
    var.workload_identity_pool_id,
    "/attribute.repo_ref/",
    "${var.github_repository}@refs/heads/${var.user_name}",
  ])
}

  cd ~/works/lesson7 && cp -r "~/infra-study/gcp/lesson7/4. github_actions/"* .
  terraform apply

★ ここで apply したら、すぐには push しないでください
   IAMの反映に数分かかります。次の2枚を聞いている間に反映されます

★ principalSet:// で始まるのが、外部IDを指す書き方です
★ @refs/heads/<自分の名前> で、自分のブランチだけに絞っています
   ここを消すと、誰のブランチからでも自分のSAが使えてしまいます
```

**[話す]** ここは1リソースだけ。Step3 でやった
`google_service_account_iam_member` と同じリソースタイプで、
member の書き方だけが違う、という点を押さえてもらう。

---

### S34e2 | ドキュメントどおりに書くと通らない ★

**[図版]** **新規作成**。実際に発行されたトークンの sub を大きく見せ、
数値IDの部分を赤で囲む。下に「repository / ref は素直」と対比を置く。

**[本文]**

```
◼公式ドキュメントには、こう書いてあります

  principal://iam.googleapis.com/<プール>/subject/
    repo:OWNER/REPO:ref:refs/heads/BRANCH

  sub の完全一致で、リポジトリとブランチを1つの文字列で縛れる

◼ところが、実際に発行されたトークンの sub はこうでした

  repo:sumzap@45473687/infra-study-app@1351899519:ref:refs/heads/shiiman
            ~~~~~~~~~                ~~~~~~~~~~~
            組織の数値ID              リポジトリの数値ID

  ★ この組織は「OIDCのsubjectに不変IDを含める」設定が有効です
     名前を変えても同じ主体を指せるようにするための設定で、
     セキュリティ的にはこちらのほうが堅牢です

◼どうするか

  repository と ref のクレームは、名前のまま素直に入っています

    repository : sumzap/infra-study-app
    ref        : refs/heads/shiiman

  プロバイダ側でこの2つを連結した属性を作ってあります

    attribute.repo_ref = assertion.repository + "@" + assertion.ref

  → principalSet://<プール>/attribute.repo_ref/
       sumzap/infra-study-app@refs/heads/shiiman

★ 「ドキュメントどおりに書いたのに PERMISSION_DENIED」は、
   だいたいこれか、audience の指定ミスです
★ 困ったら、トークンの中身を実際に出して確かめるのが一番早いです
```

**[話す]** ここは実際にハマったところ。
最初は公式の書き方で組んだが動かず、トークンをデコードして初めて分かった。
「ドキュメントと実物が違うことがある」「調べ方を知っていれば10分で分かる」
という話として扱う。

> **トークンの中身の出し方**(講師のメモ):
> ワークフロー内で `$ACTIONS_ID_TOKEN_REQUEST_URL` に `audience` を付けて
> curl し、返ってきた JWT のペイロード部を base64 デコードする。
> S34i のトラブルシュートで詰まったら、これを見せる。

---

### S34f | ワークフローを書いて push する

**[本文]**

```
参照: gcp/lesson7/app/.github/workflows/deploy.yml

name: deploy
on:
  push:
    branches: ["<自分の名前>"]     ← ここだけ書き換える

permissions:
  contents: read
  id-token: write          ← ★ これが無いとトークンを発行できません

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # ブランチ名から自分のリソース名を組み立てる
      - id: vars
        run: |
          NAME="${{ github.ref_name }}"
          echo "repo=${NAME}-repo"   >> "$GITHUB_OUTPUT"
          echo "service=${NAME}-app" >> "$GITHUB_OUTPUT"
          echo "sa=${NAME}-build@${{ vars.PROJECT_ID }}.iam.gserviceaccount.com" \
            >> "$GITHUB_OUTPUT"

      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.WIF_PROVIDER }}
          service_account: ${{ steps.vars.outputs.sa }}

      - uses: google-github-actions/setup-gcloud@v2
      - run: gcloud auth configure-docker asia-northeast1-docker.pkg.dev --quiet
      - run: docker build / push / gcloud run deploy   (中身は cloudbuild.yaml と同じ)

  cp .github/workflows/deploy.yml .github/workflows/deploy-<自分の名前>.yml
  # branches を自分の名前に書き換えてから
  git add . && git commit -m "add workflow" && git push origin <自分の名前>

★ リポジトリは全員共通なので、Variables も全員共有です
   自分の名前を Variables に書くと、他の人のビルドが壊れます
   → ブランチ名から組み立てます(Cloud Build の substitutions と同じ発想)

★ ビルドに5分ほどかかります。待っている間に別の話をします
```

**[話す]** `permissions: id-token: write` を忘れるのが一番多いミス。
書かないと OIDC トークンが発行されず、
`Unable to get ACTIONS_ID_TOKEN_REQUEST_URL` で落ちる。
ここは先に「忘れると落ちます」と言っておく。

---

### S34g | Terragrunt — 同じことを何度も書かないために ★

**[図版]** **新規作成**。左が「素のTerraform(環境ごとにコピー)」、
右が「Terragrunt(共通モジュール + 環境ごとの差分だけ)」。
左は同じファイルが3つ並んでいて、赤字で「3か所直す」。

```
   素のTerraform                    Terragrunt

   envs/dev/main.tf   ┐            modules/app/       ← 中身は1つ
   envs/stg/main.tf   ├ 中身がほぼ同じ  envs/dev/terragrunt.hcl  ← 差分だけ
   envs/prd/main.tf   ┘            envs/stg/terragrunt.hcl
                                   envs/prd/terragrunt.hcl
   → 1つ直すと3か所直す            → モジュールを1か所直す
```

**[本文]**

```
◼この勉強会では、環境が1つしかありませんでした

  実務では dev / stg / prd と増えます
  中身はほとんど同じで、値だけが違う

◼素のTerraformだと

  ディレクトリごとコピーすることになりがちです
  backend の設定も、provider の設定も、毎回書く
  → 直すときに全部直す。直し忘れる

◼Terragrunt

  Terraform のラッパー。社内でも使っています(nishiki)

  共通の中身は module に置く
  環境ごとには terragrunt.hcl に「違うところだけ」書く
  backend の設定も自動生成できる

  依存関係も書ける(VPCができてからアプリを作る、など)

★ Terraform を素で理解したうえで使う道具です
   だから今日まで出しませんでした
★ 今日やった ignore_changes などは、Terragrunt でもそのまま使えます
```

**[話す]** ビルドを待っている間の話。
「今日書いたコードが3環境分に増えたらどうなるか」から入る。

> **制作TODO**: nishiki の Terragrunt のディレクトリ構成を確認し、
> 実物の構成図を1枚差し込むこと。「うちだとこうなっている」があると早い。

---

### S34h | SOPS — 秘密情報をリポジトリに置く ★

**[図版]** **新規作成**。左が「そのまま置く(✕)」、右が「SOPSで暗号化(○)」。
右は KMS の鍵で暗号化されたYAMLがGitに入っていて、
復号にはIAMの権限が要る、という流れを描く。

```
  ✕ そのまま         db_password: "honmono"        ← Gitに平文が残る

  ○ SOPS            db_password: ENC[AES256_GCM,data:...]
                             │
                        [Cloud KMS の鍵]
                             │
                     復号できるのは、その鍵に IAM 権限がある人だけ
```

**[本文]**

```
◼秘密情報をどこに置くか

  第1回の宿題で Secret Manager を使いました
  → 値はGCPの中。Terraform からは参照するだけ

  では「Secret Manager に入れる値そのもの」はどこで管理するのか

◼SOPS (Secrets OPerationS)

  設定ファイルの **値だけ** を暗号化するツール。社内でも使っています

  キーは平文のまま、値だけ ENC[...] になる
  → 差分が読める。どのキーが増えたか分かる

  鍵は Cloud KMS(GCP) / KMS(AWS) / age など
  → 復号できるかは IAM で決まる。人の入れ替わりに強い

◼何がうれしいか

  暗号化したままGitに入れられる
  → 秘密情報もコードと同じ場所で、同じレビューを通せる

★ 「.env をSlackで送る」をやめるための道具です
★ 復号の権限をIAMで管理するので、今日までの話とつながります
```

**[話す]** ここもビルド待ちの話。
「Secret Manager に入れる値は、誰がどこで持っているのか」という問いから入ると、
SOPSの位置づけが分かりやすい。

> **制作TODO**: nishiki での SOPS の鍵の持ち方(KMS か age か、
> 誰が復号できるか)を確認して差し込むこと。

---

### S34i | 動いたか確認する

**[本文]**

```
◼GitHub の Actions タブを見てください

  緑になっていれば成功です

  gcloud run revisions list --service=[自分の名前]-app \
    --region=asia-northeast1 --limit=3 \
    --format="table(name,creationTimestamp)"

  → さっきの Cloud Build のリビジョンの上に、もう1つ増えています

◼うまくいかないとき

  Unable to get ACTIONS_ID_TOKEN_REQUEST_URL
    → permissions: id-token: write を書いていない

  Permission 'iam.serviceAccounts.getAccessToken' denied
    → ★ まず「紐付けの反映待ち」を疑ってください
       apply の直後に push すると、これで落ちます
       実測では 1〜2分では足りず、10分後の再実行で通りました
       失敗したジョブは GitHub の画面から Re-run できます

    → 何度やっても駄目なら、ブランチ名が合っているか
       (terraform output の repo_ref と、自分のブランチ名)

    → それでも分からなければ、S34e2 のやり方で
       トークンの中身を実際に出して確かめる

  denied: Permission "artifactregistry.repositories.uploadArtifacts" denied
    → Step1 で付けた権限が、このSAに付いているか確認

★ 3つ目は Cloud Build のときと同じエラーです
   ビルドする場所が変わっても、必要な権限は同じです
```

---

### S34j | Cloud Build と GitHub Actions、どちらを使うか

**[図版]** **新規作成**。表。左に判断軸、右2列。

**[本文]**

```
                      Cloud Build              GitHub Actions
──────────────────────────────────────────────────────────────
実行場所               GCPの中                   GitHubの中(GCPの外)
GCPへの認証            SAを指定するだけ            Workload Identity 連携
VPC内リソースへの接続    プライベートプールで可能      基本は届かない(要 self-hosted)
GCPの他サービスとの連携   密(Cloud Deploy など)      gcloud 経由
テストやリンタ           別に用意することになる        すでにここで回っている
料金                  ビルド時間で課金             パブリックリポジトリは無料枠が大きい
設定ファイル            cloudbuild.yaml           .github/workflows/*.yml

◼選び方

  アプリのCIが既に GitHub Actions にある     → そのままデプロイまでやる
  VPC内のDBにマイグレーションを流したい        → Cloud Build(プライベートプール)
  Cloud Deploy でカナリアをやりたい          → Cloud Build のほうが素直

★ 両方使う構成もよくあります
   テストは GitHub Actions、デプロイは Cloud Build、など
★ どちらでも「必要な権限は同じ」ことは、今日見たとおりです
```

**[話す]** ここが Step4 の締め。
道具の優劣ではなく、どこで動かすかの違いであることを押さえてもらう。

---

# 責務の分界

---

### S35 | terraform apply したらどうなるか ★

**[図版]** **新規作成**。この回の最重要図その3。

```
   Terraform が知っている image     CI/CD が入れた image
   infra-study-common/app     ≠    shiiman-repo/app:a1b2c3d

   → 次の terraform apply で、Terraform は
     「ズレている」と判断して巻き戻そうとする
```

**[本文]**

```
◼やってみましょう

  cd ~/works/lesson7
  terraform plan

  → No changes.

◼なぜ戻らないのか

  0. before の Cloud Run に、これを入れてあります

    lifecycle {
      ignore_changes = [
        template[0].containers[0].image,
        client,
        client_version,
      ]
    }

★ これが無いと、terraform apply のたびに
   古いイメージに巻き戻されます

◼試しに ignore_changes を外して plan すると

  # module.before.google_cloud_run_v2_service.app will be updated in-place
    ~ image = "asia-northeast1-docker.pkg.dev/.../[自分の名前]-repo/app:a1b2c3d"
           -> "asia-northeast1-docker.pkg.dev/.../infra-study-common/app"

  Plan: 0 to add, 1 to change, 0 to destroy.

  ★ せっかくデプロイしたものを、講師の共通イメージに
    戻そうとしています
```

**[話す]** Step1 のときに「Cloud Run に1ブロック足してある」と言ったのがこれ。
実務で必ずぶつかるところなので、ここは時間を取って説明する。

---

### S36 | 誰が何を決めるのか ★

**[図版]** **新規作成**。責務の分界表。

**[本文]**

```
                        Terraform    CI/CD
────────────────────────────────────────────
ネットワーク               ◯
Cloud Run があるか         ◯
CPU / メモリ / スケール     ◯
環境変数                   ◯
サービスアカウント          ◯
VPCへの繋ぎ方              ◯
────────────────────────────────────────────
どのイメージが動くか                    ◯

★ 境界線は1本だけ
   インフラの形は Terraform、動かすバージョンは CI/CD

★ ignore_changes は「その1本を引く」ための宣言
```

---

### S37 | ignore_changes は乱用しない

**[本文]**

```
◼便利ですが、書きすぎると危険です

  ignore_changes に入れた属性は
  **Terraform が管理をやめる** ということ

  コードと実物がズレていても plan に出なくなります

◼今回入れたもの

  template[0].containers[0].image   CI/CDが変えるから(意図的)
  client / client_version           gcloud が勝手に付けるメタ情報

◼入れてはいけないもの

  環境変数、サービスアカウント、スケール設定
  → これらは Terraform が管理し続けるべき

★ 「CI/CDが触るものだけ」を、属性単位で指定する
★ ignore_changes = all は最後の手段
```

---

### S38 | ロールバックの手段を整理する

**[本文]**

```
◼今日の構成でのロールバック

  1. 前のリビジョンにトラフィックを戻す(一番速い)
     gcloud run services update-traffic ... --to-revisions=...=100

  2. 前のコミットに戻して push しなおす
     git revert → push → 自動で再デプロイ

★ 1は即座、2は履歴が残る
  障害時は1で止血して、あとから2で直すのが定石

◼段階的に出せば、そもそも全員には当たらない

  → Cloud Deploy のカナリアデプロイ
  → 今日の宿題1・2
```

---

# まとめ

---

### S39 | 本日のまとめ ①

**[本文]**

```
◼CI/CD の構成
GCPは Cloud Build 1つでビルドもデプロイもやる
  AWS: CodeCommit + CodeBuild + CodeDeploy + CodePipeline
設定ファイルも cloudbuild.yaml 1つ
  AWS: buildspec.yml + appspec.yml

◼ソースコード
Cloud Source Repositories は2024年6月に新規提供終了
GitHub 連携が前提。GitHub App と トークンの登録が要る
  → ここだけコードにできない

◼トリガー
リポジトリとブランチで、どのビルドを動かすか決める
branch は ^ と $ で囲む
cloudbuild.yaml は共有し、違いは substitutions で渡す
```

---

### S40 | 本日のまとめ ②

**[本文]**

```
◼デプロイに要る権限は2つ
  roles/run.developer          デプロイ先を更新する
  roles/iam.serviceAccountUser 実行SAになりすます

  1つ目だけでは通らない
  AWSの iam:PassRole と同じ考え方

◼権限は必要な範囲に
  サービス単位・リポジトリ単位で付けられるものは、そうする
  プロジェクト単位は最後の手段

◼Terraform と CI/CD の責務
  インフラの形は Terraform
  動かすバージョンは CI/CD
  境界は lifecycle { ignore_changes } で宣言する
  乱用しない。属性単位で、CI/CDが触るものだけ
```

---

### S41 | 本日はここまで

**[図版]** AWS版の同スライドを流用。

---

### S42 | 宿題1 アンケート

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

### S43 | 宿題2 実装課題

**[本文]**

```
◼1. Cloud Deploy でカナリアデプロイをやってみよう

  10% → 50% → 100% と段階的に切り替える

  ★ デプロイ先は <自分の名前>-canary という別サービスにします
     講義で作った <自分の名前>-app は Terraform が
     環境変数まで管理しているので、Cloud Deploy を当てると壊れます

  回答例: gcp/lesson7/syukudai1/


◼2. 承認ステップを足して、ロールバックしてみよう

  人が承認するまでデプロイが進まない状態を作る
  そのあと、前のリリースに戻す

  回答例: gcp/lesson7/syukudai2/


◼3. ブランチによってやることを変えよう

  <自分の名前>-dev  → ビルドと push だけ
  <自分の名前>      → ビルドしてデプロイ

  回答例: gcp/lesson7/syukudai3/
```

---

### S44 | 宿題3 ドキュメント

**[本文]**

```
◼Cloud Build のドキュメントを眺めてみよう
  https://cloud.google.com/build/docs
  ビルド構成ファイル / トリガー / サービスアカウント

◼Cloud Deploy のドキュメントを眺めてみよう
  https://cloud.google.com/deploy/docs
  デリバリーパイプライン / ターゲット / デプロイ戦略

◼Terraform google provider の各ドキュメントを眺めてみよう
  google_cloudbuild_trigger
  google_cloudbuildv2_connection / google_cloudbuildv2_repository
  google_clouddeploy_delivery_pipeline / google_clouddeploy_target
```

---

### S45 | 参考

**[本文]**

```
Cloud Build ドキュメント
  https://cloud.google.com/build/docs

ビルド構成ファイルのスキーマ
  https://cloud.google.com/build/docs/build-config-file-schema

GitHub リポジトリへの接続
  https://cloud.google.com/build/docs/automating-builds/github/connect-repo-github

Cloud Deploy ドキュメント
  https://cloud.google.com/deploy/docs

Cloud Run のロールアウトとロールバック
  https://cloud.google.com/run/docs/rollouts-rollbacks-traffic-migration
```

---

### S46 | 注意事項

**[本文]**

```
宿題などで作成したリソースは
必ず削除してください！

★★ destroy の手順 ★★

   1. terraform destroy          (private サブネットだけ失敗します)

   2. 2〜3時間待つ
        gcloud compute addresses list --filter="purpose=SERVERLESS"
        → 消えていればOK

   3. terraform destroy

★ アプリのリポジトリのブランチは消さなくて大丈夫です

★ 次回(第8回)は3月1日、監視・運用編です
```

---

### S47 | おしまい

**[本文]**

```
次回は 監視・運用 編 です(3月1日)

Cloud Logging / Cloud Monitoring / アラート
「動かなくなったとき、どこを見るか」をやります

第5回で「Cloud Run にはインスタンスに入る概念が無い」
と言った話の続きです

お楽しみに！！
```

---

# 付録A: ハンズオンのステップ対応表

| Step | ディレクトリ | 作るもの | 確認すること |
|---|---|---|---|
| 0 | `0. before/` | 第2〜6回の全リソース(38個) | 約9分 |
| 1 | `1. artifact_registry/` | Artifact Registry + ビルド用SA + 権限2つ | まだ自動化されていない |
| 2 | `2. cloud_build/` | トリガー | **push → deploy で失敗** |
| 3 | `3. deploy/` | 権限2つ(run.developer + serviceAccountUser) | **push → 成功** |
| 4 | `4. github_actions/` | WIFの紐付け1つ + ワークフロー | **GitHub Actions からも成功** |

AWS版 第8回との対応:

| AWS版 | GCP版 | 備考 |
|---|---|---|
| 1. code_commit | — | **CSRは新規提供終了**。GitHub を使う |
| 2. code_build | 1. artifact_registry + 2. cloud_build | ECR相当 + ビルド定義 |
| 3. code_deploy | 3. deploy | **サービスは増えない**。権限を足すだけ |
| 4. code_pipeline | — | **不要**。Cloud Build が全部やる |
| (Blue/Green) | syukudai1-2 | Cloud Deploy のカナリアに置き換え |

---

# 付録B: 制作メモ / 要確認事項

## 実環境での動作確認: **完了(2026-08-29 / 08-31)**

`terraform fmt` 差分なし / `terraform validate` は全7ディレクトリで成功
(google provider 8.0.0)。

**講義・宿題とも受講者相当の権限で通しで実測済み。**

### 実測できたこと

| 項目 | 結果 |
|---|---|
| `0. before` + Step1(40リソース) | **約10分** |
| `roles/artifactregistry.admin` の要否 | **必要だと実測で確認**。無いと下記のエラーで落ちる |
| **`ignore_changes` あり** | `gcloud run deploy` で image を変えても **No changes** |
| **`ignore_changes` なし** | `~ image = ... -> ...` で **巻き戻そうとする**(S35の主張どおり) |
| destroy 1回目 | **6分32秒**。失敗は private サブネット1件のみ(第6回と同じ) |
| destroy(宿題まで含む) | **6分35秒**。失敗は private サブネット1件のみ。トリガー・パイプライン・SAは素直に消えた |
| トリガー作成(受講者権限) | **OK**。共有接続にぶら下げられた |
| push → トリガー起動 | **OK**。`^perm7$` のブランチフィルタも効いた |
| 小文字 `dockerfile` | **OK**。Cloud Build の `docker build .` で問題なくビルドされた |

```
Error: Error applying IAM policy for artifactregistry repository:
  Error setting IAM policy for artifactregistry repository:
  googleapi: Error 403: Permission 'artifactregistry.repositories.setIamPolicy'
  denied on resource '...repositories/[自分の名前]-repo'
```

> **★ ロール付与の直後は反映待ちで失敗する。**
> 上のエラーは `roles/artifactregistry.admin` を付けた直後の apply で出た。
> 数分おいて再実行したら通った。第1回と同じ現象なので、
> ロール追加は開催前日までに済ませること。

### 宿題の実測(2026-08-31)

| 項目 | 結果 |
|---|---|
| 宿題1 apply | OK(7リソース)。カナリア用サービスも Terraform で作る |
| 1回目のリリース | **カナリアは必ず SKIPPED**。`stable` の手前で人待ちになる |
| 2回目のリリース | **10% → 50% → 100%** が実際に動いた |
| 宿題2 承認 | `The rollout is pending approval.` で停止 |
| 宿題2 ロールバック | **承認不要**。`stable` のみで100%切り戻し |
| 宿題3 dev ブランチ | **CIだけ起動、Cloud Run のリビジョンは増えず** |

### 宿題で見つけて直したもの

1. **Cloud Deploy 実行SAに `roles/clouddeploy.jobRunner` が要る**
   → プロジェクト単位なので講師の事前準備に追加
2. **Cloud Deploy に新規サービスを作らせるとプロジェクト単位の
   `roles/run.developer` が要る**
   → 共有プロジェクトでは配れないので、
   **カナリア用サービスは Terraform で先に作る**形に変更
3. **リリース作成直後の `approve` は失敗する**
   (`PENDING_RELEASE: failed precondition`)。
   `PENDING_APPROVAL` になるまで十数秒待つ
4. **進行中のロールアウトがあるとロールバックが `PENDING` のまま動かない**
   → 先に `rollouts cancel` が要る。障害対応で効く落とし穴

## 受講者ロールの照合結果(2026-08-28 実施)

`gcloud iam roles describe` と `gcloud iam list-testable-permissions` で照合した。

| 必要な権限 | どこにあるか |
|---|---|
| `cloudbuild.builds.create` / `.update`(トリガー作成) | `roles/editor` |
| `cloudbuild.connections.get` / `repositories.get` | `roles/editor` |
| `iam.serviceAccounts.actAs` | `roles/editor` |
| `run.services.setIamPolicy` | `roles/run.admin`(第5回で追加済み) |
| `iam.serviceAccounts.setIamPolicy` | `roles/iam.serviceAccountAdmin`(第1回) |
| `storage.buckets.setIamPolicy`(宿題1) | `roles/storage.admin`(第1回) |
| `clouddeploy.*`(宿題1-3) | `roles/editor` |
| **`artifactregistry.repositories.setIamPolicy`** | **どのロールにも無い → `roles/artifactregistry.admin` を追加** |
| **`resourcemanager.projects.setIamPolicy`** | **どのロールにも無い → 配らない。講師がSAを作る(事前準備5)** |

`cloudbuild.triggers.*` および `cloudbuild.connections.use` という権限は
**存在しない**(`list-testable-permissions` で確認)。
トリガーの操作は `cloudbuild.builds.*` に含まれる。

## 未確定の値

- アプリ用リポジトリの org / 名前 — **講師が決める。未確定**
- Cloud Build の接続名 / リポジトリリンク名 — **講師が決める。未確定**
- S42 のアンケート Google Form

## 新規作図が必要なスライド

| スライド | 内容 | 優先度 |
|---|---|---|
| S08 | AWS 4サービス vs GCP 1サービス | **最高** |
| S26 | デプロイに要る2つの権限 | **最高** |
| S35 | Terraform が知っている image と実物のズレ | **最高** |
| S36 | 責務の分界表 | 高 |
| S04 | push から Cloud Run までの流れ | 高 |
| S11 | 1リポジトリ・Nブランチ・Nトリガー | 中 |
| S10 | GitHub と GCP の間の接続 | 中 |

## 設計書からの変更点

- **Cloud Deploy をハンズオンから宿題に移した**。
  GitHub連携 + Cloud Build だけで2時間が埋まるため。
  設計書のアジェンダにある「カナリアデプロイ / ロールバック」は
  スライド解説(S38)+ 宿題1・2 で扱う
- **Cloud Source Repositories は使わない**。2024年6月に新規提供終了
- 宿題を2つ→3つにした(設計書の「ブランチ指定デプロイ / 承認ステップ」に
  Cloud Deploy のカナリアが加わったため)
