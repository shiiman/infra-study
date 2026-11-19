# 第6回 インフラ勉強会(GCP) — ストレージ + CDN

- **開催日**: 2027-01-18(月) 11-13時
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
> - S19b〜S24 証明書発行 + LBの伝播: 7〜10分(実測7分23秒)
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
   - 年末年始を挟むので、この回はいちばん残骸が出やすい
   - 確認は `gcp/tools/check-leftover.sh --names-file=<受講者名簿>`(下記★)
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
   docker build --pull --no-cache -t $IMG .
   docker push $IMG
   ```

   > ★ `gcloud builds submit --tag` は使えない。
   > 教材の Dockerfile はファイル名が小文字の `dockerfile` で、
   > `--tag` は大文字の `Dockerfile` を要求するため
   > (`Dockerfile required when specifying --tag`)。
   > `docker build` は小文字でも見つけてくれる。

   > イメージの取得は Cloud Run のサービスエージェントが行うため、
   > 同一プロジェクトなら受講者側の追加権限は不要


> **★ 前回(第5回)の残骸が消えているか、開催前に確認すること ★**
>
> 第5回以降の destroy は **Direct VPC egress の予約IPが解放されるまで
> サブネットが消せない**ため、1回では終わらない(1〜2時間かかる)。
> **受講者は講義中の1回だけ**にして、2回目は講師がまとめて流す運用にしている。
>
> 第5回の直後に流し忘れていないか、ここで確認する。
> 残骸があると**この回の `0. before` が同名リソースの衝突で落ちて、
> 冒頭で全員が止まる。**
>
> ```
> # 残骸の確認
> gcp/tools/check-leftover.sh --names-file=<受講者名簿> --project=[プロジェクトID]
>
> # 残っていたら、前回分をまとめて片付ける(まず dry-run)
> gcp/tools/cleanup-lesson.sh 5 --names-file=<受講者名簿> \
>   --project=[プロジェクトID] --var-file=cleanup.tfvars
> ```
>
> **この回の片付け**については、末尾の注意事項スライドの講師メモを参照。

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない
- `terraform plan, terraform apply` は、順番に実行する2コマンドの表記
- ページタイトルの `(1/2)` などは、デッキでは全角のかっこ

---

# 導入

---

### S01 | タイトル

<!-- slide-id: g000slide -->

**[図版]** AWS版 第7回 表紙を複製。タイトルのみ差し替え。

**[本文]**

```
第6回 インフラ勉強会(GCP)

〜 ストレージ + CDN 編 〜

2027年1月18日(月) 11-13時
```

**[話す]** 明けましておめでとうございます。年末年始を挟んだので、
第5回のリソースが残っていないか最初に確認する。

---

### S02 | インフラ勉強会 スケジュール

<!-- slide-id: g001slide -->

**[図版]** 第2回 S02 と同じスライドを複製。今日の行のマーカーは付けない。

---

### S03 | 前回の振り返り

<!-- slide-id: g002slide -->

**[図版]** AWS版 第7回「前回」2枚を流用。中身を差し替え。

**[本文]**

```
◼前回やったこと

Artifact Registry にイメージを push した
Cloud Run で動かした
Cloud Run は VPC の外にいる
  → Spanner には繋がるが Memorystore には繋がらない
  → Direct VPC egress で解決
サーバレスNEGでロードバランサのバックエンドに繋いだ
  → ドメインも証明書もそのまま、中身だけ VM から Cloud Run へ

★ 今日もそのロードバランサに、配信先をもう1つ足します
```

---

### S04 | 今日のゴール

<!-- slide-id: g003slide -->

**[図版]** **新規作成**。1つのドメインで2つの配信先に振り分ける図。

```
   https://<自分の名前>.infra-study-gcp.sumsp.jp
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

<!-- slide-id: g004slide -->

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

<!-- slide-id: g005slide -->

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

★ S3は中身があるとバケットを削除できず、手動で空にする必要がありますが
   GCP では force_destroy で解決する
```

**[話す]** S3は中身が残っているとバケットを削除できず、手動で空にする必要がある。
GCPは force_destroy = true でそれが要らなくなる。

---

### S07 | location の選び方

<!-- slide-id: g006slide -->

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

<!-- slide-id: g007slide -->

**[図版]** 4行×4列の表(見出し行付き)。AWS版 第7回「S3 - ストレージクラス」の表を流用。中身を差し替え。
補足(保存料金・AWSとの対応)は、次の S08b に分ける。

**[本文]**

```
クラス       アクセス頻度       最低保存期間   用途
──────────────────────────────────────────────────
STANDARD     頻繁              なし          通常のファイル
NEARLINE     月1回程度          30日          バックアップ
COLDLINE     四半期に1回程度    90日          長期保管
ARCHIVE      年1回程度          365日         法定保存
```

**[話す]** ここはGCPの方が分かりやすい。
S3 Glacier は取り出しに時間がかかるクラスがあって、
「復元をリクエストして待つ」という操作が必要だった。
GCPはどのクラスも即座に読める。料金だけが違う。

---

### S08b | ストレージクラス(補足)

<!-- slide-id: p2_6_g007bdy_notes -->

**[本文]**

```
★ 保存料金は下がるが、取り出し料金が上がる
★ 最低保存期間より早く消すと、残り期間分の料金がかかる

◼AWSとの、おおよその対応
  STANDARD    → S3 Standard
  NEARLINE    → S3 Standard-IA
  COLDLINE    → S3 Glacier Instant Retrieval
  ARCHIVE     → S3 Glacier Deep Archive

★ GCPは全クラスでミリ秒アクセスできる
   S3 Glacier のように「取り出しに数時間」がない
```

---

### S09 | アクセス制御

<!-- slide-id: g008slide -->

**[図版]** AWS版 第7回「S3 - アクセス制御」を流用。中身を差し替え。

**[本文]**

```
◼S3は2系統あって分かりにくかった
  ACL(オブジェクト単位。今は新規バケットで既定では無効)
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

<!-- slide-id: g009slide -->

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
★ 今日は使いませんが、宿題2の③で関連する話が出てきます
```

---

### S11 | バージョニングとライフサイクル(1/2)

<!-- slide-id: g010slide -->

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
```

---

### S11b | バージョニングとライフサイクル(2/2)

<!-- slide-id: g010bslide -->

**[本文]**

```
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

<!-- slide-id: g011slide -->

**[図版]** AWS版 第7回「S3 だけでもホスティングできるのに
なんで前段にCloudFrontを配置することが多いの？」を流用。

**[本文]**

```
◼CDN(Content Delivery Network)とは
  世界中にある「エッジ」(ユーザに近い配信拠点)に
  コンテンツのコピー(キャッシュ)を置いて配信する仕組み

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
```

---

### S13 | Cloud CDN とは ★

<!-- slide-id: g012slide -->

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

★ AWSでは「CloudFront用のACMは us-east-1 で作る必要がある」
   という罠があります。GCPにはその制約がない
   第3回で作った証明書をそのまま使えます
```

**[話す]** AWSでCloudFrontを使うときは、ACMのために
`provider = aws.us_east` という別プロバイダーを定義する必要がある。
「なぜここだけリージョンが違うのか」を毎回説明する必要がある。
GCPにはこれが無い。

---

### S14 | 休憩(5分)

<!-- slide-id: g013slide -->

**[本文]**

```
後半はハンズオンです
```

---

# 準備と Cloud Storage

---

### S15 | ハンズオンの準備

<!-- slide-id: g014slide -->

**[図版]** AWS版 第7回「準備」を流用。コマンドを差し替え。

**[本文]**

```
◼Cloud Shell を立ち上げる
  プロジェクトが [プロジェクトID] になっていることを確認
  gcloud config get-value project
  (違うなら) gcloud config set project [プロジェクトID]

◼作業ディレクトリを作る
  mkdir -p ~/works/lesson6
  cd ~/works/lesson6

◼サンプルコードを更新
  cd ~/infra-study && git pull
  cd ~/works/lesson6
```

---

### S15b | 前回のリソースの確認

<!-- slide-id: g014bslide -->

**[本文]**

```
◼第5回のリソースは destroy 済みですか

  第5回は SERVERLESS アドレスの解放に2時間以上かかりました
  まだ残っている人は、先に確認してください

  gcloud compute networks list
  gcloud compute addresses list --filter="purpose=SERVERLESS"
```

**[話す]** 年末年始を挟んでいるので、第5回の片付けが終わっていない人がいるはず。
最初に確認する時間を取る。

※ 「2時間以上」の根拠: 公式ドキュメントは「1〜2時間」、第6回の destroy では
Cloud Run の削除から約2時間20分を実測した(付録B)。第5回の destroy そのものを
計測した値ではない。

---

### S16 | 前回までの構成を作成する

<!-- slide-id: g015slide -->

**[本文]**

```
cd ~/works/lesson6 && cp -rf ~/infra-study/gcp/lesson6/"0. before" ./
cd "0. before"
python3 ~/infra-study/gcp/tools/configure.py

第2〜5回の構成を再作成します
  ネットワーク / Memorystore / Spanner / Cloud Run /
  サーバレスNEG / グローバルIP / SSL証明書 / DNS

  terraform init
  terraform plan, terraform apply

※ ロードバランサのフロント側は、今回パスルール付きで作ります
※ Cloud Run は講師の共通リポジトリのイメージを使います
※ 各ステップの中で設定を反映します。同じGCSのstateを引き継ぎます
```

---

### S16b | 自分のリポジトリを作り直さない理由

<!-- slide-id: g016slide -->

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

**[話す]** 「1回の apply にまとめるには、途中に手作業を挟まない構成にする」
という話でもある。ビルドと apply が交互に必要な工程は
1回の apply には畳めない。第7回の CI/CD はまさにそこを自動化する回。

---

### S17 | バケットを作る

<!-- slide-id: g017slide -->

**[図版]** cp 行(灰色の枠 bx0)と、コード(灰色の枠 bx1)は、本文とは別の図形。

**[コード]**

```
cd ~/works/lesson6 && cp -rf ~/infra-study/gcp/lesson6/"1. storage" ./
cd "1. storage"
python3 ~/infra-study/gcp/tools/configure.py

resource "google_storage_bucket" "static" {
  name     = "${var.project_id}-static-${var.user_name}"
  location = "ASIA-NORTHEAST1"

  storage_class = "STANDARD"

  // 旧来のACLを無効化し、IAMに一本化する
  uniform_bucket_level_access = true

  // 中身が残っていても destroy できる
  force_destroy = true
}
```

**[本文]**

```
※ バケット名は GCP 全体で一意
第1回のtfstateバケットと同じく、プロジェクトIDと名前を含めている
```

---

### S18 | ファイルを置く(1/3)

<!-- slide-id: g018slide -->

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
```

---

### S18b | ファイルを置く(2/3)

<!-- slide-id: p2_6_g018bdy_1 -->

**[本文]**

```
★ name に "static/" を付けているのは偶然ではありません

   バックエンドバケットは、URLのパスをそのままオブジェクト名にして
   バケットに取りに行きます

     GET /static/index.html  →  オブジェクト "static/index.html"

   あとで作るURLマップのパスルール(/static/*)と、
   オブジェクト名の階層を合わせておく必要があります

   ★ 合っていないと 404 になります。ハマりどころ
```

---

### S18c | ファイルを置く(3/3)

<!-- slide-id: p2_6_g018bdy_2 -->

**[本文]**

```
◼Cache-Control の読み方

  public      CDNにキャッシュしてよい
  max-age     ブラウザのキャッシュ時間(秒)
  s-maxage    CDN(共有キャッシュ)の時間(秒)

★ 手で gcloud storage cp を叩いて置く方法もあります
★ Terraformで置くとコード管理できる
   ただし1ファイル1リソースになるので、大量のファイルには向かない
   実務ではCI/CDから gcloud storage rsync することが多い
```

---

### S19 | Step1 実行

<!-- slide-id: g019slide -->

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼確認
  terraform output bucket_name
  gcloud storage ls "gs://[バケット名]/**"
  → static/index.html と static/style.css が見える

◼ブラウザで直接アクセスしてみる
  https://storage.googleapis.com/[バケット名]/static/index.html
  → 403 になります

※ バケットを公開していないので読めません
※ この状態でCDNを付けるとどうなるか、次でやります
```

---

# Cloud CDN

---

### S19b | 先に Step2 を流します ★

<!-- slide-id: g020slide -->

**[本文]**

```
◼コードは書けているので、先に apply を流してください

cd ~/works/lesson6 && cp -rf ~/infra-study/gcp/lesson6/"2. cdn" ./
cd "2. cdn"
python3 ~/infra-study/gcp/tools/configure.py

  terraform init
  terraform plan, terraform apply

※ 証明書の発行とロードバランサの伝播に7〜10分かかります
※ 待っている間に、何を作っているかを解説します

◼待っている間に確認するコマンド
  gcloud compute ssl-certificates describe [自分の名前]-web-cert \
    --global --format="value(managed.status)"

  PROVISIONING → ACTIVE になったら「Step2 の確認 → 繋がらない」へ
```

**[話す]** 第3回で作った証明書は、転送ルールが無いと発行が始まらない。
`0. before` にはLBのフロントを入れていないので、
Step2 で転送ルールを作った瞬間から発行が走る。
ここが今日いちばん長い待ち時間なので、先に流してから解説する。

---

### S20 | バックエンドバケット ★

<!-- slide-id: g021slide -->

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

★ ヘルスチェックも 130.211.0.0/22 の Firewall Rule も要らない
   (Cloud Storage はVPCの外にあるため)
```

---

### S21 | CDNポリシー(1/2)

<!-- slide-id: g022slide -->

**[図版]** コード部分(cdn_policy)を灰色の枠で囲む。

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
   「ファイルを置く」で付けた Cache-Control が効く形にして、
   キャッシュの寿命をアプリ側で決められるようにするため
```

---

### S21b | CDNポリシー(2/2)

<!-- slide-id: p2_6_g022bdy_1 -->

**[本文]**

```
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

<!-- slide-id: g023slide -->

**[図版]** **新規作成**。この回の最重要図その3。
第3回のURLマップ(defaultだけ)と今日のURLマップ(パスルール付き)を比較。

**[本文]**

```
参照: 2. cdn/lb.tf

resource "google_compute_url_map" "main" {
  name            = "${var.user_name}-urlmap"
  default_service = google_compute_backend_service.run.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "main"
  }

  path_matcher {
    name            = "main"
    default_service = google_compute_backend_service.run.id

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

<!-- slide-id: g024slide -->

**[図版]** 5行×4列の表(見出し行は青、左の列は灰色)。下に黄色の ※(g024slide_n0)。

**[本文]**

```
比較項目         第3回                  第5回              今回
リソース         バックエンドサービス    バックエンドサービス  バックエンドバケット
中継             インスタンスグループ    サーバレスNEG       なし
ヘルスチェック   必要                   不要               不要
Firewall Rule    必要(130.211/22)      不要               不要
CDN              なし                   なし               enable_cdn

※ 第3回が一番手間がかかっていた
   VMを使わなくなると、周辺の設定も要らなくなる
```

---

### S24 | Step2 の確認 → 繋がらない(1/2)

<!-- slide-id: g025slide -->

**[図版]** ブラウザの表示。**開催前に実物のスクリーンショットを撮ること**。

**[本文]**

```
◼Step2 の apply が終わったら、アクセスしてみる
  https://[自分の名前].infra-study-gcp.sumsp.jp/static/index.html

  → 403 Forbidden

  <?xml version='1.0' encoding='UTF-8'?>
  <Error><Code>AccessDenied</Code><Message>Access denied.</Message></Error>

※ Cloud Storage が返した XML がそのまま出てきます
※ バケットを公開していないので、CDN も読めません
```

**[話す]** 証明書の待ち時間は S19b で済ませてある(実測: 転送ルール作成から
証明書ACTIVEまで7分23秒)。まだ PROVISIONING の人がいたら、ここで待つ。

---

### S24b | Step2 の確認 → 繋がらない(2/2)

<!-- slide-id: g025bslide -->

**[本文]**

```
◼アプリの方は動いている
  https://[自分の名前].infra-study-gcp.sumsp.jp/

  Hello, Infra Study
  hostname: localhost
  DB接続(Spanner): 成功
  Cache接続: 成功

※ パスルールは効いている(振り分けはできている)
※ でも静的ファイルが読めない

なぜだと思いますか？
```

**[話す]** AWSでも同じ場面がある。
CloudFrontを作ってアクセスしたら Access Denied になり、
S3バケットポリシーを追加して解決する。

---

### S25 | なぜ 403 になるのか

<!-- slide-id: g026slide -->

**[図版]** 新規。バケットが非公開でCDNが読めない図。

**[本文]**

```
◼バケットを公開していないから

  Step1 で uniform_bucket_level_access = true にしたが、
  誰にも読み取り権限を与えていない

  Cloud CDN も読めない

◼AWSの CloudFront には OAI / OAC がある

  S3 を非公開にして、CloudFront だけに読ませる仕組み
  (OAI が古い方式で、今は OAC が推奨)

  → バケットは非公開のまま配信できる

◼Cloud CDN は、既定では「公開されたオブジェクト」を読みに行く

  → allUsers に読み取り権限を与える必要がある
  非公開のまま配信するには、署名付きURL / 署名付きCookie を使う

★ 署名付きURL / Cookie は、この後の「非公開のまま配信したい場合」で説明します
```

---

# 公開設定

---

### S26 | バケットを公開する

<!-- slide-id: g027slide -->

**[図版]** cp 行(灰色の枠 bx0)と、コード(灰色の枠 bx1)は、本文とは別の図形。

**[コード]**

```
cd ~/works/lesson6 && cp -rf ~/infra-study/gcp/lesson6/"3. public" ./
cd "3. public"
python3 ~/infra-study/gcp/tools/configure.py

resource "google_storage_bucket_iam_member" "public" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
```

**[本文]**

```
※ 第1回の IAM で説明した allUsers の公開設定
   ここでは意図的に公開するので、正しい使い方です

※ ただし、理解しておくこと
   バケット全体が「誰でも直接読める」状態になります
   CDN を経由しなくても読めてしまいます

   https://storage.googleapis.com/[バケット名]/static/index.html
```

---

### S27 | Step3 実行 → 繋がる

<!-- slide-id: g028slide -->

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼もう一度アクセス
  https://[自分の名前].infra-study-gcp.sumsp.jp/static/index.html

  Hello, Infra Study
  このページは Cloud Storage から Cloud CDN 経由で配信されています。
  version: 1

※ 繋がりました
※ CSSも効いています(/static/style.css も配信されている)
```

---

### S28 | 非公開のまま配信したい場合

<!-- slide-id: g029slide -->

**[本文]**

```
◼「バケット全体が公開される」のが困る場合

  署名付きURL
    有効期限付きのURLを発行する
    バケットは非公開のまま(Cloud CDN のサービスアカウントに読ませる)

  署名付きCookie(Cloud CDN の機能)
    CDN配信用。1回の認証で配下のファイル全部にアクセスできる

  Cloud Storage を直接使わない
    Cloud Run から配信する(アプリ側で認可)

★ 「静的ファイルだから公開でよい」かどうかは、中身次第
★ 宿題2の③で、この落とし穴を扱います
```

**[話す]** 「CDNにIP制限をかけたから安全」と思っていると、
バケットに直接アクセスされて素通し、ということが起きる。
宿題で実際に確認してもらう。

署名付きURL・署名付きCookie でも非公開のバケットを配信できる点は、
公式ドキュメントで確認した(Cloud CDN のサービスアカウントに
`roles/storage.objectViewer` を付ける)。今日は実機では試していない。

---

### S29 | ここまでの到達点

<!-- slide-id: g030slide -->

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

<!-- slide-id: g031slide -->

**[本文]**

```
◼レスポンスヘッダを見る

  curl -I https://[自分の名前].infra-study-gcp.sumsp.jp/static/index.html

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

### S31 | ログでも確認できる

<!-- slide-id: g032slide -->

**[本文]**

```
◼ロードバランサのアクセスログにも cacheHit という項目がある

  gcloud logging read \
    'resource.type="http_load_balancer"' \
    --format="value(httpRequest.cacheHit,httpRequest.requestUrl)"

◼バックエンドバケットとバックエンドサービスの違い

  1. バックエンドバケットのログは、自動で有効
       設定項目は無く、無効にもできない

  2. バックエンドサービスのログは、既定で無効
       log_config { enable = true } で有効にする
       サンプリング率も、ここで決める
       → /static/* のリクエストも、ログに残る

★ 今日はレスポンスヘッダ(age)で確認しました。ログでも同じことが分かります

★ ログの設定を変えられるのはバックエンド「サービス」の方
   第8回(監視・運用)でそちらを扱います
```

**[話す]** 以前の原稿は「バックエンドバケットのログは有効化できない(だから今日は見られない)」
としていたが、公式ドキュメントでは、バックエンドバケットを使う外部アプリケーションLBの
ログは自動で記録され、無効化も設定もできない。事実に合わせて直した(2026-11-19)。
`gcloud logging read` の実行は、今回の見直しでは実機で確認していない。

---

### S32 | ファイルを更新してみる

<!-- slide-id: g033slide -->

**[図版]** AWS版 第7回「アプリ更新」のコマンドスライドを流用。

**[本文]**

```
◼static/index.html の version を 2 に書き換える

  terraform apply

◼アクセスしてみる
  curl https://[自分の名前].infra-study-gcp.sumsp.jp/static/index.html

  version: 1     ← 古いまま！

★ CDNにキャッシュが残っているから
★ s-maxage=300 なので、最大5分間は古いものが返り続けます
```

---

### S33 | キャッシュを無効化する

<!-- slide-id: g034slide -->

**[本文]**

```
◼キャッシュ無効化(invalidation)

  gcloud compute url-maps invalidate-cdn-cache [自分の名前]-urlmap \
    --path "/static/*"

  → version: 2 が返るようになる

◼AWSでいうと
  aws cloudfront create-invalidation --paths "/*"

  ほぼ同じ。対象がディストリビューションではなくURLマップなのが違い

★ 実測3秒で反映されました(公式ドキュメントでは約10秒)
   ただし常にこの速さとは限りません
★ 頻繁にやるものではありません(毎分500リクエストまでの上限がある)
```

---

### S34 | 実務でのキャッシュ戦略

<!-- slide-id: g035slide -->

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

<!-- slide-id: g036slide -->

**[図版]** 8行×3列の表。AWS比較のページなので残している(削除はユーザー判断)。

**[本文]**

```
比較項目       CloudFront                     Cloud CDN
位置づけ       独立したサービス               ロードバランサの機能
作るもの       ディストリビューション         enable_cdn = true
証明書         ACM(us-east-1限定)           LBの証明書をそのまま
ドメイン       ディストリビューションに設定   LBに設定済み
オリジン制御   OAI / OAC                      署名付きURL / Cookie(既定は公開が必要)
無効化         create-invalidation            invalidate-cdn-cache
エッジの処理   Lambda@Edge /                  Service Extensions /
               CloudFront Functions           Cloud Armor もエッジ
```

---

### S35b | Cloud CDN と CloudFront(補足)

<!-- slide-id: p2_6_g036bdy_notes -->

**[本文]**

```
★ GCPの方がシンプル。ただしオリジンのアクセス制御は、既定では公開が必要
★ エッジでコードを動かす仕組みは GCP にもある
   Service Extensions(WASMプラグイン / コールアウト)
   ただし Lambda@Edge ほど手軽ではない。今日は扱いません
```

---

# まとめ

---

### S36 | 本日のまとめ ①

<!-- slide-id: g037slide -->

**[図版]** 丸数字(青い円に白抜きの 1〜4)+ 太字の結論1行 + 補足1行 を4段に並べる。ラベルや灰色の枠は使わない。
図形は g037slide_ 始まりの ID(円 n0〜n3、文字 t0〜t3)。宿題・片付け・AWSとのリソース数比較は載せない。

**[本文]**

```
1  バージョニングとライフサイクルは、セットで使う
   古い版を残し、ライフサイクルで自動削除や NEARLINE への移動をする

2  Cloud CDN は、ロードバランサの機能の1つ
   enable_cdn = true で有効になる。第3回の証明書とドメインをそのまま使える

3  配信先は、URLマップのパスルールで出し分ける
   /static/* はバックエンドバケット、それ以外は Cloud Run

4  キャッシュの寿命は、Cache-Control で決める
   更新したいときは URL にハッシュを入れる。invalidation は最後の手段
```

**[話す]** 今日の話を4つに絞ると、この4点。

---

### S37 | 本日のまとめ ②

<!-- slide-id: g038slide -->

**[図版]** 5行×4列の表(g038slide_tbl)。見出し行は青、左の列は灰色。下に黄色の ※(g038slide_y)。

**[本文]**

```
              allUsers に公開          署名付きURL                署名付きCookie
読める人      誰でも                   期限付きURLを持つ人         期限付きCookieを持つ人
バケット      公開する(allUsers)      非公開のまま               非公開のまま
対象          バケット内の全ファイル   1つのURL(1ファイル)       パスの範囲(複数ファイル)
気をつける点  公開してよいものだけ置く 署名鍵と、Cloud CDN に     署名鍵と、Cloud CDN に
                                      objectViewer を付ける      objectViewer を付ける

※ 選び方
   誰に見せてもよいファイル(公開サイトの画像・CSS) → allUsers に公開
   特定の人だけ → 署名付きURL(1ファイル) / 署名付きCookie(複数ファイル)
```

**[話す]** 今日は allUsers に公開する形でやった。署名付きURL・Cookie は、公式ドキュメントで
確認した内容を表にしている(Cloud CDN のサービスアカウントに `roles/storage.objectViewer`
を付ければ、非公開のバケットを配信できる)。今回の見直しでは実機で試していない。

---

### S38 | 本日はここまで

<!-- slide-id: g039slide -->

**[図版]** AWS版の同スライドを流用。

---

### S39 | 宿題1 アンケート

<!-- slide-id: g040slide -->

**[図版]** AWS版 第7回「宿題1」を流用。URLを差し替え。

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

### S40 | 宿題2 実装課題 ①②

<!-- slide-id: g041slide -->

**[図版]** 第3回 S52 と同じ形式(◼見出し + 説明 + ・の補足 + 回答例)。1ページに入りきらないので、①② と ③ の2ページに分ける。

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

  ・with_state の指定を間違えると現行版が消えます

  回答例: gcp/lesson6/syukudai2/
```

---

### S40b | 宿題2 実装課題 ③

<!-- slide-id: p2_6_g041bdy_1 -->

**[本文]**

```
◼3. Cloud Armor で静的ファイルにもIP制限をかけよう

  バックエンドバケットには edge_security_policy を使います
  (security_policy という属性はありません)

  ・第3回 宿題2 ③ のポリシーはそのままでは使えません
    こんなエラーが出ます

      Error 400: Security policy ... is not an edge security policy

    google_compute_security_policy 側にも設定を1つ足す必要があります
    ドキュメントを見てください

  ・そのあと、バケットに直接アクセスしてみてください
    何が起きるか確認して、なぜそうなるか考えてみてください

  回答例: gcp/lesson6/syukudai3/
```

**[話す]** 3つ目の「バケットに直接アクセス」は落とし穴の体験。
答えは言わない。
(旧「宿題3」の Cloud Armor は、宿題の番号を整理して「宿題2 実装課題 ③」になった。
宿題1 = アンケート、宿題2 = 実装課題、宿題3 = ドキュメント)

---

### S41 | 宿題3 ドキュメント

<!-- slide-id: g042slide -->

**[図版]** 第3回 S54 と同じ形式(◼見出し + リンク)。調べ物の課題ではなく、眺めるだけ。
リソース名(google_xxx)にリンクを貼る。URL はそのまま表示する(下の [リンク] 参照)。

**[本文]**

```
◼Cloud Storage のドキュメントを眺めてみよう
  https://cloud.google.com/storage/docs
  ストレージクラス / バージョニング / ライフサイクル / 署名付きURL

◼Cloud CDN のドキュメントを眺めてみよう
  https://cloud.google.com/cdn/docs
  キャッシュモード / キャッシュキー / 無効化

◼Terraform google provider の各ドキュメントを眺めてみよう
  google_storage_bucket
  google_storage_bucket_object
  google_storage_bucket_iam_member
  google_compute_backend_bucket
  google_compute_url_map(path_matcher / path_rule)
  google_compute_security_policy
```

**[リンク]**

- [https://cloud.google.com/storage/docs](https://cloud.google.com/storage/docs)
- [https://cloud.google.com/cdn/docs](https://cloud.google.com/cdn/docs)
- [google_storage_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket)
- [google_storage_bucket_object](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_object)
- [google_storage_bucket_iam_member](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam)
- [google_compute_backend_bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_bucket)
- [google_compute_url_map](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map)
- [google_compute_security_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy)

> 旧「宿題3」(Cloud Armor)は「宿題2 実装課題 ③」に移した。
> google_compute_security_policy は、③で使うので追加した(2026-11-19)。

---

### S42 | 参考

<!-- slide-id: g043slide -->

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

<!-- slide-id: g044slide -->

**[図版]** 第3回 S56 と同じ形式(cd 行を灰色の枠で囲み、右に「←」の注釈。`terraform destroy` は別の小さな枠。注意は ※ で並べる)。
cd 行の枠は g044slide_f0、destroy の枠は g044slide_f1。1ページに収める(旧「注意事項(続き)」は削除)。

**[本文]**

```
宿題などで作成したリソースは必ず削除してください！

◼リソースの削除(最後に apply したディレクトリで実行)
  cd ~/works/lesson6/"3. public"   ← 講義 Step3 まで
  cd ~/works/lesson6/syukudai1     ← 実装課題①まで
  cd ~/works/lesson6/syukudai2     ← 実装課題②まで
  cd ~/works/lesson6/syukudai3     ← 実装課題③まで

  terraform destroy   → 確認で yes と入力

※ destroy は1回だけです
   1リソースだけ失敗しますが、そのままで大丈夫です
   Cloud Run が確保した IP アドレスがすぐ解放されず、サブネットを消せないため
   残りは講師がまとめて消します

※ 全員で1つのプロジェクトを共有しています
   消し忘れはQuotaを圧迫して、他の人のapplyを止めます

※ tfstate用のバケットは残しておいてください
※ バケットは force_destroy = true なので、古い版ごと消えます
```

**[話す]** 失敗するのは private サブネット1件だけ。
`Error 400: The subnetwork resource '...-private-subnet' is already being used by 'addresses/serverless-ipv4-...'`
と出るが、そのままでよい。手で消すこともできない。

※ 旧 S43 / S43b にあった次の記述は、実測できていない・不要なため載せなくした(2026-11-19)。
- 「約2時間20分」の待ち時間の説明(講師メモに残す)
- destroy の所要時間「実測 6分35秒」(付録B のとおり限定公開サービスアクセス版での値。PSC 版は Memorystore の削除に約8分かかるため、現行構成では実測できていない)
- 「課金されるリソースは1回目で全部消える」(実機で確認していない)
- `gcp/tools/check-leftover.sh` の案内、PSC・ピアリングの説明、次回の日付(おしまいのページにある)

> **★ 講師メモ: 2回目の destroy は講師がやる ★**
>
> **受講者は destroy を1回打つだけ。残りは翌朝まとめて流す。**
>
> ```
> # まず dry-run(既定)
> gcp/tools/cleanup-lesson.sh 6 --names-file=<受講者名簿> \
>   --project=[プロジェクトID] --var-file=cleanup.tfvars
>
> # 中身を見てから実行
> gcp/tools/cleanup-lesson.sh 6 --names-file=<受講者名簿> \
>   --project=[プロジェクトID] --var-file=cleanup.tfvars --apply
> ```
>
> **実測で約2時間20分かかっている**(Cloud Run の削除から、IP の解放まで)。
> 公式の「1〜2時間」より長いので、**当日の夜ではまだ解放されていない。
> 翌朝に流すこと。**
>
> この回は年末年始明けで、第5回の片付けが終わっていない人も混ざる。
> 冒頭の確認(S15b)と合わせて二重に構えておく。
>
> 課金されるリソース(VM・Spanner・Memorystore・Cloud Run・ロードバランサ)が
> 1回目の destroy で消えるかどうかは、今回の見直しでは実機で確認していない。
> 気になる場合は `gcp/tools/check-leftover.sh [自分の名前]` で確認できる。

---

### S44 | おしまい

<!-- slide-id: g045slide -->

**[図版]** AWS版「おしまい」スライドを流用。

**[本文]**

```
次回 CI/CD 編 もお楽しみに！
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
| 宿題2の① バージョニング | OK。世代番号で旧版を取得できた |
| 宿題2の② ライフサイクル | OK |
| 宿題2の③ Cloud Armor | **`type = "CLOUD_ARMOR_EDGE"` が必要**。修正済み |
| 宿題2の③ 許可IP / 非許可IP | **200 / 403**。反映まで約1分30秒 |
| 宿題2の③ バケット直アクセス | **200**。LB経由が403でも読めてしまう(狙いどおりの落とし穴) |
| destroy 1回目 | **6分35秒**。失敗は private サブネット1件のみ(限定公開サービスアクセス版での実測。PSC 版は Memorystore の削除が約8分かかる) |
| ピアリングの手動削除 | **PSC に切り替えたので不要**(限定公開サービスアクセス版でも1回目の destroy 内で消えていた) |

### 制作中に見つけて直したもの

1. **`0. before` に Cloud Run を入れると apply が通らない**
   イメージが無いと Cloud Run は作れないため、
   受講者ごとの Artifact Registry を `0. before` から外し、
   講師が用意した共通リポジトリを参照させる形にした(S16b)
2. **オブジェクト名とURLのパスを合わせる必要がある**
   `/static/index.html` はオブジェクト `static/index.html` を取りに行く。
   バケット直下に置くと404になる(S18で明示)
3. **`cache_mode` の既定は `CACHE_ALL_STATIC`**(`USE_ORIGIN_HEADERS` ではない)
4. **LBのアクセスログ**: バックエンドバケットは自動で有効(無効化も設定もできない)、バックエンドサービスは既定で無効(S31を書き換え。初稿の「有効化できない」は誤り)
5. **`edge_security_policy` には `type = "CLOUD_ARMOR_EDGE"` のポリシーが必要**
   第3回 宿題2 ③ のポリシーは使い回せない

## スライド見直しの反映(2026-11-19)

第1〜4回のレビュー指摘を、第6回に先回りで反映した。
デッキは再生成せず、既存ページの文言差し替え・複製・削除だけで直している。

| 項目 | 内容 |
|---|---|
| まとめ | 第4回の形に作り直した(S36 = 丸数字1〜4、S37 = 公開の仕方の比較表)。AWSとのリソース数比較・宿題・片付けは載せない |
| 宿題2 | S40(①②)と S40b(③)に分割。旧「宿題3」の Cloud Armor は「宿題2の③」に移した。S10・S28 の参照も直した |
| 宿題3 ドキュメント | S41 に [リンク] 一覧を追加。google_compute_security_policy を追加した |
| 注意事項 | S43 の1ページにまとめた(S43b は削除)。cd 行と destroy を枠で囲み、実測していない所要時間は載せない |
| Step ページ | S16 / S19 / S19b / S24 / S27 を `terraform init` / `terraform plan, terraform apply` の形に統一 |
| 前回のリソースの確認 | S15 から分けて S15b にした |
| ページ分割 | S08b(ストレージクラス補足)・S18〜S18c(ファイルを置く 1/3〜3/3)・S21 / S21b(CDNポリシー)・S35b(CloudFront補足) |
| S31 | 「ログでは見られない」を「ログでも確認できる」に訂正(バックエンドバケットのLBログは自動で有効) |
| S33 | invalidation の反映時間(公式は約10秒)と上限(毎分500リクエスト)を公式ドキュメントに合わせた |
| S12 | CDN の用語説明(エッジ・キャッシュ)を足し、S3 のスロットリングの話は削除 |
| AWSとの切り離し | 本文の「AWSでは〜した」を一般的な比較に直した。S35(AWS比較表)は残している |
| slide-id | 変更したページに付けた |

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
  ハンズオンに入れると尺が足りないため。宿題2の③で関連する落とし穴を扱う
- AWS版にあった「S3の中身は手動で削除」という注意は不要になった
  (`force_destroy = true`)
