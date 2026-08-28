# 第6回 インフラ勉強会(GCP) — ストレージ + CDN

- **開催日**: 2027-01-18(月) 2時間
- **AWS版対応**: 第7回(AWS ストレージ編)
- **Terraformコード**: `gcp/lesson6/`
- **ゴール**: 静的ファイルを Cloud Storage に置き、Cloud CDN 経由で HTTPS 配信し、キャッシュの挙動を確認する

> **この回の軸は「Cloud CDN は独立したサービスではない」こと。**
> CloudFront はディストリビューションという独立したリソースだったが、
> Cloud CDN はロードバランサのバックエンドに付ける機能。
> 第3回で作ったロードバランサに配信先を1つ足すだけで済む。

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入 | 6分 | S01〜S04 |
| Cloud Storage | 20分 | S05〜S13 |
| 休憩 | 5分 | S14 |
| 準備 + Step1(バケット) | 17分 | S15〜S19 |
| Cloud CDN(Step2) | 30分 | S19b〜S25 |
| 公開設定(Step3) | 12分 | S26〜S29 |
| キャッシュの挙動 | 18分 | S30〜S35 |
| まとめ・宿題 | 12分 | S36〜S44 |

> **待ち時間**
> - S16 `0. before` の apply: 約9分(実測8分34秒)
> - S24 証明書発行 + LBの伝播: 7〜10分(実測7分23秒)
>
> **`0. before` を最初に流してから Cloud Storage の話に入る構成にしてある。**
>
> 押した場合の削り所: S08〜S11(ストレージクラス / IAM / 署名付きURL)は
> 口頭のみで圧縮できる。
>
> **削ってはいけないのは S13**(CDNがLBの機能である話)、
> **S22**(URLマップのパスルール)、**S24〜S26**(403 → 公開 → 配信)。
> この回の核心。

## 事前準備(講師)

1. 受講者が第5回のリソースを destroy 済みであること
   **★ 第5回の destroy は SERVERLESS アドレスの解放に1〜2時間かかる。**
   前日までに終わらせるよう案内すること
2. API の追加は不要(Cloud Storage / Cloud CDN は既存のAPIで動く)
3. 受講者のロールの追加も不要(確認済み。付録B参照)
   > バックエンドバケットと Cloud Armor は `roles/editor` で作れる。
   > `allUsers` 公開に要る `storage.buckets.setIamPolicy` は
   > `roles/storage.admin`(第1回で付与済み)にある
4. **★ 共通のコンテナイメージを用意しておくこと**
   `0. before` の Cloud Run は、受講者ごとのリポジトリではなく
   講師が用意した共通リポジトリを参照する(S16b)。
   1度作れば以降の回でも使い回せる。

   ```
   gcloud artifacts repositories create infra-study-common \
     --repository-format=docker --location=asia-northeast1 \
     --description="インフラ勉強会(GCP) 共通イメージ" \
     --project=[プロジェクトID]

   # Cloud Shell で(第5回 S18 と同じ手順)
   cd "gcp/lesson5/1. artifact_registry/web_app"
   gcloud auth configure-docker asia-northeast1-docker.pkg.dev
   IMG=asia-northeast1-docker.pkg.dev/[プロジェクトID]/infra-study-common/app
   docker build -t $IMG .
   docker push $IMG
   ```

   > ★ `gcloud builds submit --tag` は使えない。
   > 教材の Dockerfile はファイル名が小文字の `dockerfile` で、
   > `--tag` は大文字の `Dockerfile` を要求するため
   > (`Dockerfile required when specifying --tag`)。
   > `docker build` は小文字でも見つけてくれる。

   > イメージの取得は Cloud Run のサービスエージェントが行うため、
   > 同一プロジェクトなら受講者側の追加権限は不要

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない

---

# 導入

---

### S01 | タイトル

**[図版]** AWS版 第7回 表紙を複製。タイトルのみ差し替え。

**[本文]**

```
第6回 インフラ勉強会(GCP)

〜 ストレージ + CDN 編 〜

2027年1月18日
```

**[話す]** 明けましておめでとうございます。年末年始を挟んだので、
第5回のリソースが残っていないか最初に確認する。

---

### S02 | ロードマップ

**[図版]** 第1回 S02 と同じスライドを複製。今日の行(1月18日)にマーカーを移す。

---

### S03 | 前回の振り返り

**[図版]** AWS版 第7回「前回」2枚を流用。中身を差し替え。

**[本文]**

```
◼前回やったこと

Artifact Registry にイメージを push した
Cloud Run で動かした(ECSの10リソースが3リソースに)
Cloud Run は VPC の外にいる
  → Spanner には繋がるが Memorystore には繋がらない
  → Direct VPC egress で解決
サーバレスNEGでロードバランサのバックエンドに繋いだ
  → ドメインも証明書もそのまま、中身だけ VM から Cloud Run へ

★ 今日もそのロードバランサに、配信先をもう1つ足します
```

---

### S04 | 今日やること

**[図版]** **新規作成**。1つのドメインで2つの配信先に振り分ける図。

```
   https://<自分の名前>.<勉強会のドメイン>
                │
        [ロードバランサ]   ← 第3回で作ったもの
                │
        [URLマップ]        ← ここで振り分ける
           ┌────┴────┐
     /static/*          それ以外
           │                │
   [バックエンドバケット]  [バックエンドサービス]
     + Cloud CDN            │
           │            [Cloud Run]
   [Cloud Storage]
```

**[本文]**

```
◼1つのドメインで、静的ファイルとアプリを出し分けます

  /static/*  → Cloud Storage の静的ファイル(CDNでキャッシュ)
  それ以外    → Cloud Run のアプリ

★ 第3回で「振り分けをしないので default だけ」と言った
   URLマップが、今日ようやく本領を発揮します
```

---

# Cloud Storage

---

### S05 | Cloud Storage

**[図版]** AWS版 第7回「S3」のスライドを流用。用語を差し替え。

**[本文]**

```
◼Cloud Storage
オブジェクトストレージ。AWSのS3に相当

◼特徴
容量無制限(1オブジェクト最大5TB)
高い耐久性(99.999999999%)
安価
スケーラブル(サーバを気にしなくてよい)

★ S3とほぼ同じ。呼び名と細かい仕様が違うだけ
```

---

### S06 | S3 との違い

**[図版]** **新規作成**。用語と概念の対応表。

**[本文]**

```
                    S3                    Cloud Storage
────────────────────────────────────────────────────────
入れ物              バケット               バケット
中身                オブジェクト           オブジェクト
名前の一意性        グローバル一意          グローバル一意
配置                リージョン             location で選ぶ
                                          リージョン / デュアル / マルチ
アクセス制御        ACL + バケットポリシー  IAM(UBLAで一本化)
バージョン管理      バージョンID(文字列)   世代番号(数値)
ライフサイクル      別リソース             バケットの属性
中身がある削除      手動で空にする必要      force_destroy = true で可

★ AWS版の注意事項に
   「S3の中身があると削除できないので手動で削除してください」
   とあったが、GCPは force_destroy で解決する
```

**[話す]** AWS版の第7回の最後に「S3の中身は手動で削除してください」という
注意書きがあった。あれが要らなくなる。

---

### S07 | location の選び方

**[本文]**

```
◼3種類ある

  リージョン        asia-northeast1(東京)
                    1リージョン内で冗長化。安い。速い

  デュアルリージョン asia1(東京 + 大阪)
                    2リージョンに複製。リージョン障害に耐える

  マルチリージョン   ASIA / US / EU
                    広域に複製。世界中から読むデータ向け

★ 選び方
  アプリと同じリージョン        → リージョン
  災害対策が要る                → デュアルリージョン
  世界中に配信する              → マルチリージョン、またはCDN

★ 後から変更できない
   S3も同じ(バケットのリージョンは変えられない)
```

---

### S08 | ストレージクラス

**[図版]** AWS版 第7回「S3 - ストレージクラス」の表を流用。中身を差し替え。

**[本文]**

```
クラス       想定アクセス頻度   最低保存期間   用途
──────────────────────────────────────────────────
STANDARD     頻繁              なし          通常のファイル
NEARLINE     月1回程度          30日          バックアップ
COLDLINE     四半期に1回程度    90日          長期保管
ARCHIVE      年1回程度          365日         法定保存

★ 保存料金は下がるが、取り出し料金が上がる
★ 最低保存期間より早く消すと、残り期間分の料金がかかる

◼AWSとの対応
  STANDARD    → S3 Standard
  NEARLINE    → S3 Standard-IA
  COLDLINE    → S3 Glacier Instant Retrieval
  ARCHIVE     → S3 Glacier Deep Archive

★ GCPは全クラスでミリ秒アクセスできる
   S3 Glacier のように「取り出しに数時間」がない
```

**[話す]** ここはGCPの方が分かりやすい。
S3 Glacier は取り出しに時間がかかるクラスがあって、
「復元をリクエストして待つ」という操作が必要だった。
GCPはどのクラスも即座に読める。料金だけが違う。

---

### S09 | アクセス制御

**[図版]** AWS版 第7回「S3 - アクセス制御」を流用。中身を差し替え。

**[本文]**

```
◼S3は2系統あって分かりにくかった
  ACL(オブジェクト単位)
  バケットポリシー(バケット単位)
  → どちらが効くのか、組み合わせでどうなるのか

◼GCPは IAM に一本化できる

  uniform_bucket_level_access = true

  これを付けると旧来のACLが無効になり、IAMだけになる
  ★ 第1回のtfstateバケットでも同じ設定をしました

◼付与の単位
  バケット単位   google_storage_bucket_iam_member
  プロジェクト単位 roles/storage.admin など

◼主なロール
  roles/storage.objectViewer   読む
  roles/storage.objectCreator  書く
  roles/storage.objectAdmin    読み書き削除
  roles/storage.admin          バケットの操作も
```

---

### S10 | 署名付きURL

**[本文]**

```
◼バケットを公開せずに、特定の人にだけ読ませたい

  署名付きURL(Signed URL)

  有効期限付きのURLを発行する
  URLを知っていれば期限内は誰でもアクセスできる
  期限が切れると使えなくなる

  gcloud storage sign-url gs://[バケット]/[オブジェクト] \
    --duration=10m \
    --impersonate-service-account=[署名に使うSA]

★ 署名には秘密鍵が要ります
   ユーザ資格情報のままでは署名できないので、
   サービスアカウントになりすますか、鍵ファイルを渡す
   (鍵ファイルを作るのは避けたいので、なりすましが基本)

◼使いどころ
  ユーザがアップロードしたファイルの配信
  期限付きのダウンロードリンク
  ブラウザから直接アップロードさせる(PUT用の署名付きURL)

★ AWSのS3署名付きURLと同じ考え方
★ 今日は使いませんが、宿題3で関連する話が出てきます
```

---

### S11 | バージョニングとライフサイクル

**[図版]** AWS版 第7回「S3 - バージョン管理」「S3 - ライフサイクル」を流用。

**[本文]**

```
◼バージョニング
上書き・削除しても前の版が残る

  versioning { enabled = true }

  古い版は「世代番号」で取り出せる
    gs://bucket/index.html#1768730400000000

★ 古い版も課金対象。放っておくと増え続ける
   → ライフサイクルとセットで使う

◼ライフサイクル
条件に合うオブジェクトを自動で処理する

  Delete             削除する
  SetStorageClass    安いクラスへ移す

  「30日でNEARLINE、90日でCOLDLINE、365日で削除」
  のように段階的にコストを下げるのが定番

★ どちらも宿題でやってもらいます

◼おまけ: ソフト削除(Soft Delete)

  バージョニングとは別に、GCPには「消したものを7日間保持する」
  機能が既定でONになっています

    gcloud storage buckets describe gs://[バケット名]
    → soft_delete_policy:
        retentionDurationSeconds: '604800'   ← 7日

  バケットごと消しても7日間は復元できる
  S3には無い仕組み(バージョニングとは別物)

★ 保持されている間は課金対象
   バージョニングと合わせて「思ったより減らない」原因になります
```

---

### S12 | Cloud CDN の前に: なぜCDNを挟むのか

**[図版]** AWS版 第7回「S3 だけでもホスティングできるのに
なんで前段にCloudFrontを配置することが多いの？」を流用。

**[本文]**

```
◼Cloud Storage だけでも公開できる

  https://storage.googleapis.com/[バケット]/index.html

◼それでもCDNを挟む理由

  キャッシュによる高速化
    ユーザに近いエッジから返せる

  独自ドメイン + 証明書
    storage.googleapis.com ではなく自分のドメインで出せる

  アクセス制御
    Cloud Armor をエッジで効かせられる

  オリジンの保護
    バケットへのリクエストが減る

★ AWS版では「S3のスロットリング」も理由に挙げられていた
   (1プレフィックスあたり 5,500 GET/秒 で 503 が返る)
   GCPにも同様の上限があるので、考え方は同じ
```

---

### S13 | Cloud CDN とは ★

**[図版]** **新規作成**。この回の最重要図その1。AWS版との構成比較。

```
   AWS                              GCP

   [Route53]                        [Cloud DNS]
       │                                 │
   [CloudFront]  ← 独立したサービス   [ロードバランサ]  ← 第3回で作ったもの
    ├ オリジン設定                       │
    ├ ビヘイビア                     [URLマップ]
    ├ 証明書(us-east-1!)                │
    └ 独自ドメイン               [バックエンドバケット]
       │                            enable_cdn = true
     [S3]                                │
                                   [Cloud Storage]
```

**[本文]**

```
◼Cloud CDN は独立したサービスではない

  ロードバランサのバックエンドに付ける「機能」

  enable_cdn = true

  これだけで有効になる

◼CloudFront との違い

  CloudFront  ディストリビューションを作り、
              オリジン・証明書・ドメイン・ビヘイビアを全部その中に設定

  Cloud CDN   ロードバランサが既にあるので、配信先を足すだけ
              証明書もドメインも既存のものを使う

★ AWS版では「CloudFront用のACMは us-east-1 で作る必要がある」
   という罠があった。GCPにはその制約がない
   第3回で作った証明書をそのまま使えます
```

**[話す]** AWS版第7回のコードを見ると、ACMのために
`provider = aws.us_east` という別プロバイダーを定義していた。
「なぜここだけリージョンが違うのか」を毎回説明する必要があった。
GCPにはこれが無い。

---

### S14 | 休憩

**[本文]**

```
5分休憩

後半はハンズオンです
```

---

# 準備と Cloud Storage

---

### S15 | 準備

**[図版]** AWS版 第7回「準備」を流用。コマンドを差し替え。

**[本文]**

```
◼Cloud Shell を立ち上げる

◼作業ディレクトリを作る
  mkdir -p ~/works/lesson6
  cd ~/works/lesson6

◼サンプルコードを更新
  cd ~/infra-study && git pull
  cd ~/works/lesson6

★★ 第5回のリソースは destroy 済みですか ★★

   第5回は SERVERLESS アドレスの解放に1〜2時間かかりました
   まだ残っている人は、先に確認してください

     gcloud compute networks list
     gcloud compute addresses list --filter="purpose=SERVERLESS"
```

**[話す]** 年末年始を挟んでいるので、第5回の片付けが終わっていない人がいるはず。
最初に確認する時間を取る。

---

### S16 | 前回までの完成状態を読み込む

**[本文]**

```
参照: gcp/lesson6/1. storage/before.tf

module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson6/0. before"
  ...
}

◼中身は第2回〜第5回で作ったもの(30リソース)
  ネットワーク / Memorystore / Spanner /
  Cloud Run / サーバレスNEG /
  グローバルIP / SSL証明書 / DNSレコード

  terraform init
  terraform apply

★ 10分ほどかかります。先に流してから解説に入ります

★ ロードバランサのフロント(URLマップ・プロキシ・転送ルール)は
   含まれていません。今日パスルール付きで作り直すためです

★ Artifact Registry のリポジトリも含まれていません
   Cloud Run が使うイメージは、講師が用意した共通リポジトリのものです
   (理由は次のスライド)
```

---

### S16b | 自分のリポジトリを作り直さない理由

**[本文]**

```
◼第5回では自分でビルドして push した

  リポジトリを作る → イメージを push する → Cloud Run を作る

  この順番でしか作れません
  イメージが無いうちに Cloud Run を作ろうとすると失敗します

◼今日それをやると apply を3回に分ける必要がある

  前回までの状態に一度で戻せなくなり、ビルドの待ち時間も増える
  今日の主題はコンテナではないので、そこは再現しません

◼代わりに、講師が用意した共通リポジトリのイメージを使います

  image = "asia-northeast1-docker.pkg.dev/
             ${var.project_id}/infra-study-common/app"

  中身は第5回で自分が push したものと同じです

★ 自分でビルドするところは、第7回のCI/CDでまたやります
   (今度は push すると自動でビルドされるようになります)
```

**[話す]** 「モジュールにまとめられるのは、順番に依存しないものだけ」
という話でもある。ビルドと apply が交互に必要な工程は
1回の apply には畳めない。第7回の CI/CD はまさにそこを自動化する回。

---

### S17 | バケットを作る

**[本文]**

```
参照: gcp/lesson6/1. storage/storage.tf

resource "google_storage_bucket" "static" {
  name     = "${var.project_id}-static-${var.user_name}"
  location = "ASIA-NORTHEAST1"

  storage_class = "STANDARD"

  // 旧来のACLを無効化し、IAMに一本化する
  uniform_bucket_level_access = true

  // 中身が残っていても destroy できる
  force_destroy = true
}

★ バケット名はGCP全体で一意
   第1回のtfstateバケットと同じく、プロジェクトIDと名前を含めている
```

---

### S18 | ファイルを置く

**[本文]**

```
resource "google_storage_bucket_object" "index" {
  name   = "static/index.html"
  bucket = google_storage_bucket.static.name
  source = "${path.module}/static/index.html"

  content_type = "text/html"

  // ★ キャッシュ制御。Cloud CDN はこれを見る
  cache_control = "public, max-age=60, s-maxage=300"
}

★★ name に "static/" を付けているのは偶然ではありません ★★

   バックエンドバケットは、URLのパスをそのままオブジェクト名にして
   バケットに取りに行きます

     GET /static/index.html  →  オブジェクト "static/index.html"

   あとで作るURLマップのパスルール(/static/*)と、
   オブジェクト名の階層を合わせておく必要があります

   ★ 合っていないと 404 になります。ハマりどころ

◼Cache-Control の読み方

  public      CDNにキャッシュしてよい
  max-age     ブラウザのキャッシュ時間(秒)
  s-maxage    CDN(共有キャッシュ)の時間(秒)

★ AWS版では aws s3 sync を手で叩いていた
★ Terraformで置くとコード管理できる
   ただし1ファイル1リソースになるので、大量のファイルには向かない
   実務ではCI/CDから gcloud storage rsync することが多い
```

---

### S19 | Step1 実行

**[本文]**

```
  terraform plan
  terraform apply

◼確認
  terraform output bucket_name

  gcloud storage ls "gs://[バケット名]/**"
  → gs://[バケット名]/static/index.html
    gs://[バケット名]/static/style.css

◼ブラウザで直接アクセスしてみる
  https://storage.googleapis.com/[バケット名]/static/index.html

  → 403 になります

★ バケットを公開していないので読めません
★ この状態でCDNを付けるとどうなるか、次でやります
```

---

# Cloud CDN

---

### S19b | 先に Step2 を流します ★

**[本文]**

```
◼コードは書けているので、先に apply を流してください

  cd ~/works/lesson6
  (2. cdn のファイルをコピー)

  terraform init
  terraform apply

★ 証明書の発行とLBの伝播に7〜10分かかります
   待っている間に、何を作っているかを解説します

◼待っている間に確認するコマンド
  gcloud compute ssl-certificates describe [自分の名前]-web-cert \
    --global --format="value(managed.status)"

  PROVISIONING → ACTIVE になったら S24 へ
```

**[話す]** 第3回で作った証明書は、転送ルールが無いと発行が始まらない。
`0. before` にはLBのフロントを入れていないので、
Step2 で転送ルールを作った瞬間から発行が走る。
ここが今日いちばん長い待ち時間なので、先に流してから解説する。

---

### S20 | バックエンドバケット ★

**[図版]** **新規作成**。この回の最重要図その2。
第3回・第5回のバックエンドとの比較。

```
   第3回  バックエンドサービス → インスタンスグループ → VM
   第5回  バックエンドサービス → サーバレスNEG      → Cloud Run
   今日    バックエンドバケット ────────────→ Cloud Storage
                 enable_cdn = true
```

**[本文]**

```
◼バックエンドバケット
ロードバランサのバックエンドに Cloud Storage を繋ぐ部品

  resource "google_compute_backend_bucket" "static" {
    name        = "${var.user_name}-static-bb"
    bucket_name = google_storage_bucket.static.name
    enable_cdn  = true
  }

★ バックエンドサービスではなく「バックエンドバケット」
   別のリソースタイプです

★ ヘルスチェックは要らない
   第3回でハマった 130.211.0.0/22 の Firewall Rule も要らない
   (Cloud Storage はVPCの外にあるため)
```

---

### S21 | CDNポリシー

**[本文]**

```
  cdn_policy {
    cache_mode         = "USE_ORIGIN_HEADERS"
    serve_while_stale  = 86400
    request_coalescing = true
  }

◼cache_mode
  CACHE_ALL_STATIC    静的コンテンツを自動でキャッシュ(既定)
  USE_ORIGIN_HEADERS  オリジンのCache-Controlに従う ← 今回これ
  FORCE_CACHE_ALL     全部キャッシュ(Cache-Controlを無視)

★ 既定は CACHE_ALL_STATIC
   Cache-Control が無くても、画像やCSSは勝手にキャッシュされる
   便利だが「なぜキャッシュされているか」がコードから読めない

★ 今回は USE_ORIGIN_HEADERS を明示している
   S18で付けた Cache-Control が効く形にして、
   キャッシュの寿命をアプリ側で決められるようにするため

◼serve_while_stale
  オリジンが落ちている間、期限切れのキャッシュを返し続ける秒数
  → オリジン障害時もページが出る

◼request_coalescing
  同じURLへの同時リクエストをまとめて、オリジンには1回だけ問い合わせる
  → キャッシュミス時にオリジンへ殺到するのを防ぐ

★ CloudFrontのキャッシュポリシーに相当
★ 「オリジンのヘッダに従う」のが基本。アプリ側で制御できる
```

---

### S22 | URLマップにパスルールを足す ★

**[図版]** **新規作成**。この回の最重要図その3。
第3回のURLマップ(defaultだけ)と今日のURLマップ(パスルール付き)を比較。

**[本文]**

```
参照: gcp/lesson6/2. cdn/lb.tf

resource "google_compute_url_map" "main" {
  name            = "${var.user_name}-urlmap"
  default_service = module.before.run_backend_service_id

  host_rule {
    hosts        = ["*"]
    path_matcher = "main"
  }

  path_matcher {
    name            = "main"
    default_service = module.before.run_backend_service_id

    path_rule {
      paths   = ["/static", "/static/*"]
      service = google_compute_backend_bucket.static.id
    }
  }
}

★ 第3回では default_service だけ書いていました
   ここでようやくURLマップの本来の役割が出てきます

★ 1つのドメイン・1つの証明書で
   静的ファイルとアプリを出し分けられる
```

**[話す]** 第3回で「LBの部品が6つもあって多い」と言ったが、
URLマップが独立しているおかげで、こういう振り分けが自然に書ける。
AWSでCloudFrontとALBを併用すると、
どちらにどのパスを向けるかの設計が複雑になりがち。

---

### S23 | 3つのバックエンドを比べる

**[本文]**

```
                    第3回          第5回           今日
────────────────────────────────────────────────────────
リソース            バックエンド    バックエンド     バックエンド
                    サービス        サービス         バケット
中継                インスタンス    サーバレスNEG    なし
                    グループ
ヘルスチェック      必要            不要             不要
Firewall Rule       必要            不要             不要
                    (130.211/22)
CDN                 なし            なし             enable_cdn

★ 第3回が一番手間がかかっていた
   VMを使わなくなると、周辺の設定も要らなくなる
```

---

### S24 | Step2 実行 → 繋がらない

**[図版]** ブラウザの表示。**開催前に実物のスクリーンショットを撮ること**。

**[本文]**

```
  terraform plan
  terraform apply

★ SSL証明書の発行とロードバランサの伝播に7〜10分かかります
   (実測: 転送ルール作成から証明書ACTIVEまで7分23秒)
   第5回のときと同じです

   gcloud compute ssl-certificates describe [自分の名前]-web-cert \
     --global --format="value(managed.status)"
   → PROVISIONING が ACTIVE になるまで待つ

◼アクセスしてみる
  https://[自分の名前].[勉強会のドメイン]/static/index.html

  → 403 Forbidden

  <?xml version='1.0' encoding='UTF-8'?>
  <Error><Code>AccessDenied</Code><Message>Access denied.</Message></Error>

  ★ Cloud Storage が返したXMLがそのまま出てきます
     AWS版で見た「Access Denied」と同じ文字列

◼アプリの方は動いている
  https://[自分の名前].[勉強会のドメイン]/

  Hello, Infra Study
  hostname: localhost
  DB接続(Spanner): 成功
  Cache接続: 成功

★ パスルールは効いている(振り分けはできている)
★ でも静的ファイルが読めない

なぜだと思いますか？
```

**[話す]** AWS版でも同じ場面があった。
CloudFrontを作ってアクセスしたら Access Denied になり、
S3バケットポリシーを追加して解決した。

---

### S25 | なぜ 403 になるのか

**[図版]** 新規。バケットが非公開でCDNが読めない図。

**[本文]**

```
◼バケットを公開していないから

  Step1 で uniform_bucket_level_access = true にしたが、
  誰にも読み取り権限を与えていない

  Cloud CDN も読めない

◼AWSではどうしていたか

  CloudFront の OAI(オリジンアクセスアイデンティティ)を作り、
  その principal に GetObject を許可するバケットポリシーを書いた

  → 「CloudFrontだけが読める」状態にできた

◼GCPのバックエンドバケットには OAI に相当する仕組みがない

  Cloud CDN は「公開されたオブジェクト」を読みに行く
  → allUsers に読み取り権限を与える必要がある

★ ここはAWSの方が細かく制御できます
```

---

# 公開設定

---

### S26 | バケットを公開する

**[本文]**

```
参照: gcp/lesson6/3. public/public.tf

resource "google_storage_bucket_iam_member" "public" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

★ 第1回 S25 で「allUsers は事故の元」と言ったやつ
   ここでは意図的に公開するので正しい使い方

★ ただし理解しておくこと
   バケット全体が「誰でも直接読める」状態になります
   CDNを経由しなくても読めてしまう

     https://storage.googleapis.com/[バケット名]/static/index.html
```

---

### S27 | Step3 実行 → 繋がる

**[本文]**

```
  terraform apply

◼もう一度アクセス
  https://[自分の名前].[勉強会のドメイン]/static/index.html

  Hello, Infra Study
  このページは Cloud Storage から Cloud CDN 経由で配信されています。
  version: 1

★ 繋がりました
★ CSSも効いています(/static/style.css も配信されている)
```

---

### S28 | 非公開のまま配信したい場合

**[本文]**

```
◼「バケット全体が公開される」のが困る場合

  署名付きURL
    有効期限付きのURLを発行する
    バケットは非公開のまま

  署名付きCookie(Cloud CDN の機能)
    CDN配信用。1回の認証で配下のファイル全部にアクセスできる

  Cloud Storage を直接使わない
    Cloud Run から配信する(アプリ側で認可)

★ 「静的ファイルだから公開でよい」かどうかは、中身次第
★ 宿題3で、この落とし穴を扱います
```

**[話す]** 「CDNにIP制限をかけたから安全」と思っていると、
バケットに直接アクセスされて素通し、ということが起きる。
宿題で実際に確認してもらう。

---

### S29 | ここまでの到達点

**[図版]** S04の構成図を再掲し、全要素にチェックを付ける。

**[本文]**

```
◼できたこと

Cloud Storage に静的ファイルを置いた
バックエンドバケットで Cloud CDN を有効にした
URLマップのパスルールで /static/* を振り分けた
第3回の証明書とドメインをそのまま使った
1つのドメインで、静的ファイルとアプリを出し分けた
```

---

# キャッシュの挙動

---

### S30 | キャッシュされているか確認する

**[本文]**

```
◼レスポンスヘッダを見る

  curl -I https://[自分の名前].[勉強会のドメイン]/static/index.html

  HTTP/2 200
  cache-control: public, max-age=60, s-maxage=300
  age: 12                        ← キャッシュされてからの秒数
  via: 1.1 google

◼age の意味

  age: 0     オリジンから取ってきたばかり(キャッシュミス)
  age: 12    12秒前にキャッシュされたものを返している(キャッシュヒット)

★ 何度かアクセスして age が増えることを確認してください
★ s-maxage=300 を超えると age が 0 に戻ります
```

---

### S31 | ログでは見られない(という話)

**[本文]**

```
◼ロードバランサのアクセスログにも cacheHit という項目がある

  gcloud logging read \
    'resource.type="http_load_balancer"' \
    --format="value(httpRequest.cacheHit,httpRequest.requestUrl)"

◼ただし今日は見られません

  1. LBのアクセスログは既定で無効
       バックエンドサービスの log_config { enable = true } で有効にする

  2. バックエンドバケットにはその設定項目が無い
       google_compute_backend_bucket に log_config ブロックが無い
       gcloud compute backend-buckets update にも相当するフラグが無い
       → /static/* のリクエストはログに出せない

★ なので今日は S30 のレスポンスヘッダ(age)で確認します

★ ログを有効にできるのはバックエンド「サービス」の方
   第8回(監視・運用)でそちらを扱います
```

**[話す]** これは「調べたが出来なかった」という話をそのまま出す。
ドキュメントに機能があっても、Terraform や gcloud から
触れるとは限らない。プロバイダーのスキーマを直接見る癖をつけると早い。

  terraform providers schema -json

---

### S32 | ファイルを更新してみる

**[図版]** AWS版 第7回「アプリ更新」のコマンドスライドを流用。

**[本文]**

```
◼static/index.html の version を 2 に書き換える

  terraform apply

◼アクセスしてみる
  curl https://[自分の名前].[勉強会のドメイン]/static/index.html

  version: 1     ← 古いまま！

★ CDNにキャッシュが残っているから
★ s-maxage=300 なので、最大5分間は古いものが返り続けます
```

---

### S33 | キャッシュを無効化する

**[本文]**

```
◼キャッシュ無効化(invalidation)

  gcloud compute url-maps invalidate-cdn-cache [自分の名前]-urlmap \
    --path "/static/*"

  → version: 2 が返るようになる

◼AWSでいうと
  aws cloudfront create-invalidation --paths "/*"

  ほぼ同じ。対象がディストリビューションではなくURLマップなのが違い

★ 実測3秒で反映されました(CloudFrontより速い)
   ただし常にこの速さとは限りません
★ 頻繁にやるものではありません(回数に上限と課金がある)
```

---

### S34 | 実務でのキャッシュ戦略

**[本文]**

```
◼毎回 invalidation するのは筋が悪い

  時間がかかる
  回数制限がある
  取りこぼしが起きる

◼ファイル名にハッシュを入れる(推奨)

  /static/app.a1b2c3.js
  /static/app.d4e5f6.js   ← 内容が変わればURLが変わる

  URLが変われば別のオブジェクトなので、キャッシュは効いたまま
  s-maxage を長く(1年など)できる

  HTMLだけ短いキャッシュにして、そこから新しいURLを参照させる

◼今日の設定
  index.html   s-maxage=300   短め(更新が反映されやすい)
  style.css    s-maxage=300   本来はハッシュ付きにして長くする

★ フロントエンドのビルドツールが自動でやってくれることが多い
   (webpack / Vite の contenthash)
```

**[話す]** ここは実務で効く話。
「更新したのに反映されない」の相談はだいたいキャッシュ設計の問題。
invalidation でしのぐのではなく、URLを変える設計にする。

---

### S35 | Cloud CDN と CloudFront の違いまとめ

**[本文]**

```
                    CloudFront            Cloud CDN
────────────────────────────────────────────────────────
位置づけ            独立したサービス       ロードバランサの機能
作るもの            ディストリビューション  enable_cdn = true
証明書              ACM(us-east-1限定)   LBの証明書をそのまま
ドメイン            ディストリビューションに設定  LBに設定済み
オリジン制御        OAI / OAC             なし(公開が必要)
無効化              create-invalidation    invalidate-cdn-cache
エッジで動く処理    Lambda@Edge /          Service Extensions
                    CloudFront Functions   (Cloud Armor もエッジ)

★ GCPの方がシンプル。ただしオリジンのアクセス制御は弱い
★ エッジでコードを動かす仕組みは GCP にもある
   Service Extensions(WASMプラグイン / コールアウト)
   ただし Lambda@Edge ほど手軽ではない。今日は扱いません
```

---

# まとめ

---

### S36 | 本日のまとめ ①

**[図版]** AWS版 第7回「本日のまとめ」のレイアウトを流用。

**[本文]**

```
◼Cloud Storage
S3とほぼ同じ。location でリージョン/デュアル/マルチを選ぶ
ストレージクラスは4種類。全クラスでミリ秒アクセスできる
uniform_bucket_level_access でIAMに一本化
force_destroy = true で中身ごと消せる
バージョニングとライフサイクルはセットで使う
ソフト削除が既定でON(7日)。バージョニングとは別物
オブジェクト名の階層 = URLのパス
```

---

### S37 | 本日のまとめ ②

**[本文]**

```
◼Cloud CDN
独立したサービスではない。ロードバランサの機能
enable_cdn = true だけで有効になる
第3回の証明書とドメインをそのまま使える
  (AWSの「ACMはus-east-1」という罠がない)

◼URLマップのパスルール
1つのドメインで配信先を出し分けられる
  /static/*  → バックエンドバケット
  それ以外    → バックエンドサービス(Cloud Run)

◼オリジンのアクセス制御
バックエンドバケットには OAI に相当する仕組みが無い
allUsers に公開する必要がある
非公開のまま配信したいなら署名付きURL / 署名付きCookie

◼キャッシュ
Cache-Control(s-maxage)で寿命を決める
age ヘッダでヒットしているか分かる
invalidation は最後の手段。URLにハッシュを入れる設計が基本
```

---

### S38 | 本日はここまで

**[図版]** AWS版の同スライドを流用。

---

### S39 | 宿題1 アンケート

**[図版]** AWS版 第7回「宿題1」を流用。URLを差し替え。

**[本文]**

```
◼アンケートのお願い

1分で終わりますのでぜひフィードバックお願い致します！！
次回開催のモチベになります！！！

https://forms.gle/xxxxxxxx
```

> **制作TODO**: Google Form を新規作成してURLを差し込む。

---

### S40 | 宿題2 実装課題

**[図版]** AWS版 第7回「宿題2」のレイアウトを流用。

**[本文]**

```
◼1. バージョニングを設定しよう

  index.html を上書きして、前の版が残ることを確認
  世代番号で古い版を取り出してみる

  回答例: gcp/lesson6/syukudai1/


◼2. ライフサイクルで古い版を自動削除しよう

  3世代より古い版を削除
  7日より古い版を削除
  30日経った現行版を NEARLINE に移す

  ★ with_state の指定を間違えると現行版が消えます

  回答例: gcp/lesson6/syukudai2/


◼3. Cloud Armor で静的ファイルにもIP制限をかけよう

  バックエンドバケットには edge_security_policy を使います
  (security_policy という属性はありません)

  ★ 第3回 宿題3 のポリシーはそのままでは使えません
     こんなエラーが出ます

       Error 400: Security policy ... is not an edge security policy

     google_compute_security_policy 側にも
     設定を1つ足す必要があります。ドキュメントを見てください

  ★ そのあと、バケットに直接アクセスしてみてください
     何が起きるか確認して、なぜそうなるか考えてみてください

  回答例: gcp/lesson6/syukudai3/
```

**[話す]** 3つ目の「バケットに直接アクセス」は落とし穴の体験。
答えは言わない。

---

### S41 | 宿題3 ドキュメント

**[本文]**

```
◼Cloud Storage のドキュメントを眺めてみよう
  https://cloud.google.com/storage/docs
  ストレージクラス / バージョニング / ライフサイクル / 署名付きURL

◼Cloud CDN のドキュメントを眺めてみよう
  https://cloud.google.com/cdn/docs
  キャッシュモード / キャッシュキー / 無効化

◼Terraform google provider の各ドキュメントを眺めてみよう
  google_storage_bucket / google_storage_bucket_object
  google_storage_bucket_iam_member
  google_compute_backend_bucket
  google_compute_url_map(path_matcher / path_rule)
```

---

### S42 | 参考

**[本文]**

```
Cloud Storage ドキュメント
  https://cloud.google.com/storage/docs

Cloud CDN ドキュメント
  https://cloud.google.com/cdn/docs

キャッシュキーとキャッシュモード
  https://cloud.google.com/cdn/docs/caching

署名付きURL
  https://cloud.google.com/storage/docs/access-control/signed-urls

外部アプリケーションLBのURLマップ
  https://cloud.google.com/load-balancing/docs/url-map-concepts
```

---

### S43 | 注意事項

**[図版]** AWS版「注意事項」スライドを流用。

**[本文]**

```
宿題などで作成したリソースは
必ず削除してください！

★★ destroy は2回に分ける必要があります ★★

   1. terraform destroy          (実測 6分35秒)

        → 1リソースだけ失敗します

          Error 400: The subnetwork resource '...-private-subnet'
          is already being used by 'addresses/serverless-ipv4-...'

        Cloud Run の Direct VPC egress が確保したIPアドレスが
        すぐには解放されないため。手で消すこともできません

   2. 1〜2時間待つ

        gcloud compute addresses list --filter="purpose=SERVERLESS"
        → 消えていればOK

   3. terraform destroy          (残りは VPC と サブネット だけ)

★ 課金されるリソースは1回目で全部消えています
   VMもSpannerもMemorystoreもCloud Runもロードバランサも消えます
   残るのはVPCとサブネットだけ(どちらも無料)

★ ピアリングの手動削除(第5回 付録A-2)は今回は不要でした
   1回目の destroy の中で53秒で消えています
   もし失敗したら、そのときは第5回の手順を使ってください

     gcloud compute networks peerings delete \
       servicenetworking-googleapis-com \
       --network=[自分の名前]-vpc

★ バケットは force_destroy = true にしてあるので、
   バージョニングで残った古い版ごと消えます
   AWS版のような「手動で空にする」作業は不要です

★ 次回(第7回)は2月8日です
   それまでに片付けを完了させてください
```

---

### S44 | おしまい

**[図版]** AWS版「おしまい」スライドを流用。

**[本文]**

```
次回は CI/CD 編 です(2月8日)

GitHub に push すると自動でビルドされ、
Cloud Run へデプロイされるところまで作ります

今日まで手で docker build していたものが自動になります

お楽しみに！！
```

---

# 付録A: ハンズオンのステップ対応表

| Step | ディレクトリ | 作るもの | 確認すること |
|---|---|---|---|
| 0 | `0. before/` | 第2〜5回の全リソース(30個) | 実測8分34秒 |
| 1 | `1. storage/` | バケット + 静的ファイル | 直接URLでは403 |
| 2 | `2. cdn/` | バックエンドバケット + URLマップのパスルール | **/static/* が403** |
| 3 | `3. public/` | allUsers に objectViewer | **配信できる** |

AWS版 第7回との対応:

| AWS版 | GCP版 | 備考 |
|---|---|---|
| 1. s3 | 1. storage | `aws s3 sync` → Terraformでオブジェクトを配置 |
| 2. cloudfront | 2. cdn | **独立サービス → LBの機能**。ここが最大の差分 |
| (バケットポリシー) | 3. public | OAI が無いので allUsers に公開する |
| 3. dns | — | 第3回のDNSレコードをそのまま使う |
| 4. acm | — | 第3回の証明書をそのまま使う(us-east-1の罠が無い) |

---

# 付録B: 制作メモ / 要確認事項

## 実環境での動作確認: **実施済み(2026-08-28)**

受講者相当の権限(なりすましSA)で1回通した。google provider 8.0.0。

| 項目 | 結果 |
|---|---|
| Step1 `0. before` + バケット(33リソース) | **8分34秒** |
| Step1 後の直接アクセス | **403 AccessDenied**(S19の主張どおり) |
| Step2 CDN + URLマップ(4リソース) | 1分20秒 |
| 証明書の発行 | 転送ルール作成から ACTIVE まで **7分23秒** |
| Step2 後の `/` | **200**。Spanner・Memorystore とも成功 |
| Step2 後の `/static/*` | **403**。GCSのXMLがそのまま返る(S24の主張どおり) |
| Step3 後 | **200**。apply 12秒 |
| `age` ヘッダ | **8 → 11 → 14**(S30の主張どおり) |
| ファイル更新 → 古いまま | **再現**(S32の主張どおり) |
| invalidation | **3秒**で反映(S33を訂正済み) |
| 宿題1 バージョニング | OK。世代番号で旧版を取得できた |
| 宿題2 ライフサイクル | OK |
| 宿題3 Cloud Armor | **`type = "CLOUD_ARMOR_EDGE"` が必要**。修正済み |
| 宿題3 許可IP / 非許可IP | **200 / 403**。反映まで約1分30秒 |
| 宿題3 バケット直アクセス | **200**。LB経由が403でも読めてしまう(狙いどおりの落とし穴) |
| destroy 1回目 | **6分35秒**。失敗は private サブネット1件のみ |
| ピアリングの手動削除 | **不要だった**(1回目の destroy 内で53秒で消えた) |

### 制作中に見つけて直したもの

1. **`0. before` に Cloud Run を入れると apply が通らない**
   イメージが無いと Cloud Run は作れないため、
   受講者ごとの Artifact Registry を `0. before` から外し、
   講師が用意した共通リポジトリを参照させる形にした(S16b)
2. **オブジェクト名とURLのパスを合わせる必要がある**
   `/static/index.html` はオブジェクト `static/index.html` を取りに行く。
   バケット直下に置くと404になる(S18で明示)
3. **`cache_mode` の既定は `CACHE_ALL_STATIC`**(`USE_ORIGIN_HEADERS` ではない)
4. **LBのアクセスログはバックエンドバケットでは有効化できない**(S31を書き換え)
5. **`edge_security_policy` には `type = "CLOUD_ARMOR_EDGE"` のポリシーが必要**
   第3回 宿題3 のポリシーは使い回せない

## 受講者ロールの追加: **不要**(確認済み)

第5回までの10ロールで足りる。追加は無い。

`gcloud iam roles describe roles/editor` で照合した結果:

| 必要な権限 | どのロールにあるか |
|---|---|
| `compute.backendBuckets.create` / `.update` / `.use` | `roles/editor` |
| `compute.backendBuckets.setSecurityPolicy` | `roles/editor` |
| `compute.securityPolicies.create` / `.use` | `roles/editor` |
| `storage.buckets.create` / `objects.create` | `roles/editor` |
| `storage.buckets.setIamPolicy`(allUsers公開) | **`roles/storage.admin`**(第1回で付与済み) |

第4回・第5回と同じパターン。
作成・更新・削除は `roles/editor` に入っているが、
`*.setIamPolicy` だけが別ロールに切り出されている。

## 新規作図が必要なスライド

| スライド | 内容 | 優先度 |
|---|---|---|
| S13 | CloudFront(独立サービス) vs Cloud CDN(LBの機能) | **最高** |
| S22 | URLマップのパスルール(第3回との比較) | **最高** |
| S20 | 3つのバックエンド(サービス/NEG/バケット)の比較 | 高 |
| S04 | 1ドメインで2つの配信先に振り分ける図 | 高 |
| S06 | S3 と Cloud Storage の対応表 | 中 |
| S25 | バケット非公開でCDNが読めない図 | 中 |

## 設計書からの変更点

- 設計書のアジェンダにある「署名付きURL」は概説(S10)のみにした。
  ハンズオンに入れると尺が足りないため。宿題3で関連する落とし穴を扱う
- AWS版にあった「S3の中身は手動で削除」という注意は不要になった
  (`force_destroy = true`)
