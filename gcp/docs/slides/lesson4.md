# 第4回 インフラ勉強会(GCP) — データベース

- **開催日**: 2026-12-07(月) 2時間
- **AWS版対応**: 第5回(AWS データベース編)
- **Terraformコード**: `gcp/lesson4/`
- **ゴール**: アプリから Spanner と Memorystore に接続できる

> **この回はAWS版と構成を大きく変えている。**
> 社内で Spanner をメインで使っているため、**Spanner を本編**に据え、
> Cloud SQL は「みんな知っている」前提で軽く扱う。
> AWS版は Aurora(= Cloud SQL相当)が主役だったので、そのままでは対応しない。

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入 | 6分 | S01〜S04 |
| データベースの選び方 | 12分 | S05〜S09 |
| 準備 + Step1(ローカルDB) | 15分 | S10〜S15 |
| 休憩 | 5分 | S16 |
| 4種類の接続方式 + Memorystore(Step2) | 27分 | S17〜S25(S20b・S20c 含む) |
| **Spanner(Step3)** | **41分** | S26〜S40 |
| Cloud SQL(概説のみ) | 6分 | S41〜S44 |
| まとめ・宿題 | 8分 | S45〜S53 |

> **ハンズオンは Spanner で終わり。Cloud SQL は概説のみで、構築は宿題に回した。**
> Cloud SQL は作成に10分かかるうえ、社内では既知の人が多いため。
> これにより待ち時間が 22分 → **12分** に減っている。

> **待ち時間が長い回。**
> - S15 アプリのビルド: 約5分(e2-medium。e2-microでは終わらない)
> - S24 Memorystore の作成: 約6分(実測)
> - S34 Spanner の作成: 約1分(実測)
>
> 合計 **約12分**。第3回(17分)より改善している。
>
> 押した場合の削り所: S06〜S07(DBの歴史)は口頭のみで圧縮できる。
> S39(マルチリージョン構成)も飛ばせる。
>
> **削ってはいけないのは S17〜S19**(3種類の接続方式)と
> **S28〜S34**(Spannerの構成と主キー設計)。この回の核心。

## 事前準備(講師)

1. 受講者が第3回のリソースを destroy 済みであること
2. API の有効化
   ```
   gcloud services enable servicenetworking.googleapis.com \
     sqladmin.googleapis.com redis.googleapis.com spanner.googleapis.com
   ```
3. 受講者のロールに以下を**追加**すること(第1回 付録Aの構成では足りない)
   ```
   roles/spanner.admin                   spanner.databases.setIamPolicy
   roles/servicenetworking.networksAdmin servicenetworking.services.addPeering
   ```
   Spanner / Cloud SQL / Memorystore の**作成権限は `roles/editor` に含まれている**ので、
   `roles/cloudsql.admin` や `roles/redis.admin` は不要。
   Editor に無いのは上記2つの権限だけ。
4. **Spanner の課金を事前に確認**すること
   100 PU(最小構成)× 受講者数 × 2時間。
   消し忘れると日割りで効いてくるので、destroy の徹底を強めに案内する

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない

---

# 導入

---

### S01 | タイトル

**[図版]** AWS版 第5回 表紙を複製。タイトルのみ差し替え。

**[本文]**

```
第4回 インフラ勉強会(GCP)

〜 データベース編 〜

2026年12月7日
```

---

### S02 | ロードマップ

**[図版]** 第1回 S02 と同じスライドを複製。今日の行(12月7日)にマーカーを移す。

**[話す]** 次回(第5回)は12/24の木曜日。年末なので今日の宿題は控えめにしてある。

---

### S03 | 前回の振り返り

**[図版]** AWS版 第5回「前回」2枚を流用。中身を差し替え。

**[本文]**

```
◼前回やったこと

Compute Engine でVMを作り、コンテナでアプリを動かした
ロードバランサを6つの部品で組み立てた
130.211.0.0/22 と 35.191.0.0/16 を開けないとヘルスチェックが通らない
Cloud DNS でドメインを割り当て、マネージドSSL証明書でHTTPS化した
```

---

### S04 | 今日の主役は Spanner

**[図版]** 新規。Spannerのロゴを大きく。

**[本文]**

```
◼今日の主役は Spanner です

うちで実際にメインで使っているデータベース

  Cloud SQL(MySQL / PostgreSQL)は
  みんなだいたい知っているので軽くやります

◼アジェンダ
  データベースの選び方
  3種類の接続方式(GCP独自の話)
  Memorystore
  Spanner        ← ここが本編
  Cloud SQL      ← 軽く
```

**[話す]** AWS版ではAurora(Cloud SQL相当)が主役だった。
GCP版はSpannerを主役にする。実務で使っているものを深くやりたいので。

---

# データベースの選び方

---

### S05 | どれを使えばいいのか

**[図版]** AWS版 第5回「データベース」の問いかけスライドを流用。

**[本文]**

```
データベースって種類がいっぱいあるけど
どれを使えばいいの？
```

---

### S06 | データベースの歴史

**[図版]** AWS版 第5回「データベースの歴史」の年表図を流用。**差し替え不要**。

**[本文]**

```
◼リレーショナルデータベース
1970年代後半〜  Oracle / DB2 / SQL Server
2000年前後      MySQL / PostgreSQL

◼NoSQL
2000年以降      MongoDB / Redis / Cassandra
                「スケールするために一貫性を諦める」

◼そして
2012年  Google が Spanner の論文を公開
        「スケールするのに一貫性も諦めない」

★ 今日やるSpannerは、この流れの答えとして生まれたもの
```

**[話す]** NoSQLは「水平にスケールしたいから、トランザクションや
JOINを諦める」という割り切りだった。Spannerはそこを諦めなかった。
だからGoogleの看板技術と言われる。

---

### S07 | 万能なデータベースは無い

**[図版]** AWS版 第5回「万能なデータベースなど存在しない！」を流用。

**[本文]**

```
万能なデータベースなど存在しない！

様々なワークロードに
最適なデータベースを選択すべき！

★ ただし「まずSpanner」で成立する場面は増えている
```

---

### S08 | 用途で選ぶ

**[図版]** **新規作成**。GCPのDBサービス一覧表。Spannerを強調する。

**[本文]**

```
用途                        GCP                    AWS
──────────────────────────────────────────────────────────
★ リレーショナル(スケール)  Spanner                (相当なし)
   リレーショナル(一般)      Cloud SQL              RDS
   リレーショナル(高性能PG)  AlloyDB                Aurora
   キャッシュ                Memorystore            ElastiCache
   ドキュメント              Firestore              DynamoDB
   ワイドカラム(大規模)      Bigtable               DynamoDB
   データ分析                BigQuery               Redshift / Athena

★ Spanner と BigQuery は AWS に相当するものが無い
   GCPを選ぶ理由になりやすい2つ
```

---

### S09 | Cloud SQL / AlloyDB / その他(概説)

**[本文]**

```
◼Cloud SQL
マネージドのMySQL / PostgreSQL / SQL Server。AWSのRDSに相当
  → 今日の後半で軽く触ります

◼AlloyDB
PostgreSQL互換の高性能DB。AWSのAuroraに近い
  → MySQLは使えない(PostgreSQL互換のみ)

◼Firestore
ドキュメント指向NoSQL。リアルタイム同期が得意
モバイル/Webのバックエンド向け

◼Bigtable
ワイドカラム型NoSQL。IoT・時系列・広告ログなどペタバイト級

◼BigQuery
サーバレスのデータウェアハウス
インスタンスを立てる概念がない。SQLを投げるだけ
  → 第8回でログ分析に使います
```

**[話す]** ここは名前と用途だけ。深掘りしない。
「困ったらこの表に戻ってくればいい」と伝える。

---

# 準備とローカルDB

---

### S10 | 今日のゴール

**[図版]** **新規作成**。第3回のゴール図をベースに、右側に3つの接続先を描く。
**接続経路が3種類あることが見えるように描くのがポイント。**

```
 ┌─ 自分のVPC ──────────┐
 │  private subnet            │
 │    [web VM]                │
 │      │  │                  │
 │      │  └──────────┼──▶ [Memorystore]  VPCピアリング
 │      │                     │            (限定公開サービスアクセス)
 │      └─────────────┼──▶ [Cloud SQL]    同上
 │                            │
 │  Private Google Access ────┼──▶ [Spanner]      Google API経由
 └────────────────────┘            (IPもポートも無い)
```

**[本文]**

```
これを理解して作れる！

  Hello, Infra Study
  hostname: xxxx
  DB接続(Spanner): 成功
  Cache接続: 成功
```

---

### S11 | 準備

**[図版]** AWS版 第5回「準備」を流用。コマンドを差し替え。

**[本文]**

```
◼Cloud Shell を立ち上げる

◼作業ディレクトリを作る
  mkdir -p ~/works/lesson4
  cd ~/works/lesson4

◼サンプルコードを更新
  cd ~/infra-study && git pull
  cd ~/works/lesson4

★ 第3回のリソースは destroy しておいてください
```

---

### S12 | 前回までの完成状態を読み込む

**[本文]**

```
参照: gcp/lesson4/1. web/before.tf

module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson4/0. before"

  project_id          = var.project_id
  subnet_public_cidr  = var.subnet_public_cidr
  subnet_private_cidr = var.subnet_private_cidr
  dns_zone_name       = var.dns_zone_name
  user_name           = var.user_name
}

◼中身は第2回 + 第3回で作ったもの(23リソース)
  ネットワーク / webインスタンス / ロードバランサ / DNS / SSL証明書

  terraform init
  terraform apply

★ 証明書の発行にまた10分かかります
   先に apply を流してから、次の解説に入ります
```

---

### S13 | まずはローカルのDBに繋ぐ

**[図版]** AWS版 第5回「EC2」の「まずはWebインスタンス内のアプリを更新しよう！」を流用。

**[本文]**

```
◼いきなりマネージドサービスに繋がない

まずVMの中でMySQLとRedisをコンテナで動かし、
アプリから繋がることを確認する

  [web VM]
    ├ appコンテナ    :80
    ├ dbコンテナ     :3306   MySQL
    └ cacheコンテナ  :6379   Redis

そのあと、1つずつ置き換えていく

★ 「動いている状態」を基準に、1つずつ変えるのが安全
```

---

### S14 | 今日のアプリ

**[本文]**

```
◼DBとキャッシュに繋がるかを表示するだけのアプリ

  Hello, Infra Study
  hostname: [CONTAINER ID]
  DB接続(MySQL): 成功
  Cache接続: 成功

◼設定は環境変数から読みます

  DB_KIND    mysql / spanner を切り替える
  DB_HOST / DB_USER / DB_PASS / DB_NAME
  SPANNER_DATABASE
  CACHE_HOST

★ AWS版ではmain.goを書き換えてビルドし直していました
   環境変数にしておくと、接続先を変えるたびにビルドしなくて済みます
   第5回のCloud Runでも同じやり方が使えます

★ Spanner も database/sql で書けます
   ドライバが違うだけで、使い方は MySQL と同じです
```

---

### S15 | Step1 ローカルDBに接続

**[図版]** AWS版 第5回「EC2」のコマンド一覧スライドを流用。コマンドを差し替え。

**[本文]**

```
◼webインスタンスに入る
  gcloud compute ssh [自分の名前]-web --zone=asia-northeast1-a --tunnel-through-iap

◼VMの中で
  sudo su -
  apt-get update
  apt-get install -y docker.io git default-mysql-client redis-tools
  systemctl start docker

  cd /root
  [ -d infra-study ] || git clone https://github.com/shiiman/infra-study.git
  cd "infra-study/gcp/lesson4/1. web/web_app"

  docker network create app-nw

  docker build -t db:0.1 -f ./dockerfile_mysql .
  docker run -d --network app-nw --name db db:0.1

  docker build -t cache:0.1 -f ./dockerfile_redis .
  docker run -d --network app-nw --name cache cache:0.1

  docker build -t app:0.1 .
  docker run -d -p 80:8080 --network app-nw --name app \
    -e DB_HOST=db -e DB_PASS=infra-study -e CACHE_HOST=cache \
    app:0.1

◼確認
  curl -X GET "http://localhost"
  → DB接続(MySQL): 成功 / Cache接続: 成功
```

**[話す]** ここは約5分かかる。MySQLの初回起動に時間がかかるので、
`失敗` が出たら30秒ほど待って再実行してもらう。

**★ 第4回からVMを e2-medium に上げています。**
Spannerのクライアントライブラリ(Google Cloud Go SDK + gRPC)は依存が大きく、
第3回まで使っていた e2-micro ではビルドが終わりません。

> **検証済み(2026-08-28)**:
> e2-micro  → 16分経っても完了せず(load average 4.11 で飽和)
> e2-medium → **5分16秒**で完了
>
> `0. before` の machine_type を e2-medium に変更済み。
> マシンタイプは用途で変える、という実例としても使える。

---

### S16 | 休憩

**[本文]**

```
5分休憩

後半はマネージドサービスに置き換えます
```

---

# 3種類の接続方式

---

### S17 | GCPのマネージドDBはどこにいるのか ★

**[図版]** **新規作成**。この回の最重要図その1。AWS版との比較。

```
   AWS                             GCP

 ┌─ 自分のVPC ────┐        ┌─ 自分のVPC ──┐
 │  private subnet   │        │ private subnet │
 │   [EC2]           │        │  [VM]          │
 │   [RDS]  ← 中にいる│        └───┬────┬─┘
 │   [ElastiCache]   │             │    │
 └─────────────┘        ピアリング  API経由
                            ┌────┘    └────┐
                    ┌─ Google のVPC ─┐ ┌─ Google API ─┐
                    │ [Cloud SQL]     │ │ [Spanner]     │
                    │ [Memorystore]   │ │ [BigQuery]    │
                    └───────────┘ └─────────┘
```

**[本文]**

```
◼AWS
RDSもElastiCacheも、自分のVPCのサブネットにENIを作って入ってくる
  → サブネットグループで置き場所を指定
  → セキュリティグループで通信を制御

◼GCP は 4種類の接続方式がある

  ① VPCピアリング         Cloud SQL / Memorystore
     Googleが管理する別VPCとピアリングを張る
     = 限定公開サービスアクセス        ← 今日のハンズオンはこれ

  ② Google API 経由       Spanner / BigQuery / Cloud Storage
     IPもポートも無い。APIを叩く
     第2回でやった Private Google Access で届く

  ③ Private Service Connect   Cloud SQL / Memorystore(①の後継)
     自分のVPCの中にエンドポイントIPを1つ立てて、そこ宛に繋ぐ
     ★ 社内では今こちらが主流です(S20b で詳しく)

  ④ Auth Proxy            Cloud SQL(別解)
     プロキシを立てて繋ぐ。今日は使わない

★ どれを使うかで、必要な準備が全く変わります
★ ①と③は「同じものへの2つの繋ぎ方」です。①を先にやるのは、
   なぜ③が生まれたのかが分かるからです
```

**[話す]** ここが今日一番大事なところ。
「Spannerを作ったのにVMから繋がらない」と「Cloud SQLを作ったのに繋がらない」は
原因が全く違う。

③のPSCは名前だけ出しておき、①を実際に作ったあと S20b で詳しく扱う。
先に①をやるのは、PSCが「①の何を解決したのか」を体験してからのほうが早いため。

---

### S18 | ② Google API 経由(Spanner)

**[図版]** 新規。第2回 S46 の Private Google Access の図を再掲して繋げる。

**[本文]**

```
◼Spanner には IPアドレスもポートも無い

  接続文字列がこうなる

  projects/<プロジェクト>/instances/<インスタンス>/databases/<DB>

  ホスト名もポート番号も出てこない

◼どうやって繋がっているのか
spanner.googleapis.com というGoogleのAPIを叩いている
Cloud Storage や Secret Manager と同じ仕組み

◼だから必要なのは
  ネットワーク: 第2回で有効化した Private Google Access
                (外部IPの無いVMからGoogle APIへ届く設定)
  認証:         IAM

★ 限定公開サービスアクセスは要りません
★ Firewall Rules も要りません
★ パスワードも要りません
```

> **検証済み(2026-08-28)**: 外部IPを持たないVMから
> `gcloud spanner databases execute-sql` が成功することを確認。
> VMのサービスアカウントには、データベース単位で
> `roles/spanner.databaseUser` を付けただけ(プロジェクトレベルの権限なし)。

**[話す]** 第2回のS46〜S47でやった Private Google Access が、
ここで効いてくる。あのとき `curl https://storage.googleapis.com` が
400を返したのと同じ経路でSpannerに繋がる。

---

### S19 | ① VPCピアリング(Cloud SQL / Memorystore)

**[図版]** **新規作成**。この回の最重要図その2。レンジの貸し出しを描く。

**[本文]**

```
◼Cloud SQL と Memorystore は「Googleが管理するVPC」にいる

自分のVPCとは別ネットワークなので、そのままでは繋がらない
→ 自分のVPCからIPレンジを1つ貸し出して、ピアリングを張る

  自分のVPC 172.16.0.0/16
    ├ public   172.16.0.0/24     ← 第2回
    ├ private  172.16.10.0/24    ← 第2回
    └ 172.16.192.0/20            ← 今日Googleに貸し出す

  Cloud SQL / Memorystore のIPはこのレンジから払い出される

★ 貸し出すレンジは他のサブネットと重複できない
   第2回でCIDR設計をした理由がここで効いてきます

★ 1回作れば Cloud SQL と Memorystore の両方で使い回せます

★★ レンジは大きめに取ること ★★
   サービスごとにこのレンジからブロックを切り出して使います
   /24 だと Memorystore を作った時点で埋まり、
   Cloud SQL の作成が失敗します

     Couldn't find free blocks in allocated IP ranges.
     Please allocate new ranges for this service provider.

   Googleは /16 を推奨。ここでは /20 にしています
```

> **検証済み(2026-08-28)**: 最初 `/24` で作ったところ、
> Memorystore は作れたが Cloud SQL が上記エラーで失敗した。
> `/20` に変更して解決。

> **★ さらに注意**: Cloud SQL の作成に失敗すると、
> インスタンスは `state: FAILED` の状態で残る。
> Terraformのstateには入らないので、次のapplyは
> `The Cloud SQL instance already exists` で失敗する。
> `gcloud sql instances delete` で消してから再実行すること。

---

### S20 | Terraform コード(限定公開サービスアクセス)

**[本文]**

```
参照: gcp/lesson4/2. cache/private_service_access.tf

resource "google_compute_global_address" "private_service" {
  name          = "${var.user_name}-private-service-range"
  purpose       = "VPC_PEERING"        ← ここが用途の指定
  address_type  = "INTERNAL"
  address       = split("/", var.private_service_cidr)[0]
  prefix_length = var.private_service_prefix_length
  network       = module.before.vpc_id
}

resource "google_service_networking_connection" "private_service" {
  network                 = module.before.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service.name]
}

★ google_compute_global_address は第3回でも使いました
   (ロードバランサのIP)
   purpose が違うと全く別の用途になります
```

---

### S20b | ③ Private Service Connect ★

**[図版]** **新規作成**。①との左右比較。
左に「ピアリング(いま作ったもの)」、右に「PSC」。
左はGoogleのVPCとの間に太いピアリングの線を引き、貸出レンジを図示する。
右は自分のVPCの中にエンドポイントIPが1つだけ立っている図にする。

```
   ① 限定公開サービスアクセス          ③ Private Service Connect

  ┌─ 自分のVPC ──────┐          ┌─ 自分のVPC ──────┐
  │ private 172.16.10.0/24 │          │ private 172.16.10.0/24 │
  │ 貸出   172.16.192.0/20 │          │   [EP] 172.16.10.50    │← IP 1つだけ
  └──────┬────────┘          └──────┬────────┘
      ピアリング(VPC全体がつながる)              PSC(この1点だけ)
  ┌──────┴────────┐          ┌──────┴────────┐
  │ Google のVPC           │          │ Google のVPC           │
  │  [Cloud SQL]           │          │  [Cloud SQL]           │
  └─────────────────┘          └─────────────────┘
```

**[本文]**

```
◼さっき作ったピアリングの弱点

  VPC全体がGoogleのVPCとつながる
  レンジを丸ごと貸し出す(/16 推奨。さっき /24 で失敗した)
  1つのVPCが張れるピアリングの数に上限がある
  ピアリングは推移しない
    → Shared VPC や 別VPCから使いたいときに詰む

◼Private Service Connect

  自分のVPCの中に「エンドポイント」を1つ立てる
  その1つのIPに向かって接続する

  貸し出すのはIP 1つ分だけ。レンジの設計が要らない
  Firewall Rules でそのIP宛だけを許可できる
  別VPCや別プロジェクトからも、それぞれエンドポイントを立てれば届く

★ 社内では今こちらが主流です
★ Cloud SQL / Memorystore / AlloyDB のほか、
   サードパーティのSaaSにも同じ仕組みで繋げます
```

**[話す]** 「さっきレンジで失敗したやつ、要らなくなるんです」と言うと伝わりやすい。
①をハンズオンでやったのは、PSCが何を解決したのかを体で分かってもらうため。

> **なぜハンズオンは①のままなのか**: ①のほうが「Googleが管理する別VPCにいる」という
> GCPの構造がそのまま見えるため。PSCはその構造を隠してくれるぶん、
> 初見だと「なぜエンドポイントが要るのか」が分からなくなる。

---

### S20c | ①と③の使い分け

**[図版]** 表。左列に判断軸、右2列に①と③。

**[本文]**

```
                        ① 限定公開サービスアクセス   ③ Private Service Connect
────────────────────────────────────────────────────────────────
何を貸し出すか            IPレンジ(/16〜/20)          IP 1つ
繋がる範囲                VPC全体                     エンドポイント1点だけ
Firewall での絞り込み      レンジ単位                  そのIP宛だけ
別VPCから使う             ピアリングは推移しないので不可  エンドポイントを足せば可
Shared VPC                 設計が複雑になる             素直に使える
作るリソース               global_address +            forwarding_rule +
                          service_networking_connection service_attachment 参照
料金                      ピアリング自体は無料          エンドポイントに時間課金

◼どちらを選ぶか

  ★ サービス側が決めていることがあります

  nishiki の実際の構成:

    Memorystore Cluster (Redis Cluster / Valkey)
      → ③ PSC のみ。①は選べない
        google_network_connectivity_service_connection_policy

    Cloud SQL
      → ①③どちらも選べる(psc_enabled で切り替え)

    ①の限定公開サービスアクセスも併存している
      → 貸出レンジは /22

  ★ 新しいサービスほど③しか用意されていません
     「①を知らないと、なぜ③があるのか分からない」ので今日は①からやりました

★ ネットの記事や少し古いドキュメントは①の説明が多いので注意
★ AWSでいうと ① が VPCピアリング、③ が PrivateLink に近い関係です
```

**[話す]** AWS経験者には「PrivateLinkと同じ発想」と言うのが一番早い。
VPCピアリングとPrivateLinkの使い分けを知っている人なら、そのまま理解できる。

nishiki は①と③が両方入っている。「どちらかに統一する」ものではなく、
**サービスごとに使える方式が違う**ことを押さえてもらう。

---

### S21 | AWSでいうと何が消えるのか

**[本文]**

```
◼AWS版で作っていたもの → GCP版でどうなるか

  DBサブネットグループ          → 不要
  ElastiCacheサブネットグループ → 不要
  DB用セキュリティグループ      → 不要
  Cache用セキュリティグループ   → 不要
  SGルール(web→db 3306)        → 不要
  SGルール(web→cache 6379)     → 不要

  代わりに
  グローバルアドレス予約 + サービスネットワーキング接続 → 新規(1回だけ)

★ Firewall Rules を書かなくてよい理由
   ピアリング経由の通信はVPC Firewall Rulesの対象外

★ Spanner はこれすら要りません
```

---

### S22 | Memorystore とは

**[図版]** AWS版 第5回「Amazon ElastiCache」のスライドを流用。用語を差し替え。

**[本文]**

```
◼Memorystore for Redis
マネージドのRedis。AWSのElastiCacheに相当

  BASIC        1ノード。フェイルオーバーなし。開発用
  STANDARD_HA  プライマリ + レプリカ。自動フェイルオーバー

◼ElastiCache との違い

  AWS版は4リソース
    セキュリティグループ / サブネットグループ /
    パラメータグループ / レプリケーショングループ

  GCP版は1リソース
    google_redis_instance

    サブネットグループ   → 限定公開サービスアクセスで代替
    パラメータグループ   → redis_configs で直接指定
    セキュリティグループ → 不要

◼シャード構成は別サービス
  Memorystore for Redis Cluster
  (AWSはクラスターモードのON/OFFで切り替えられた)
```

---

### S23 | Terraform コード(Memorystore)

**[本文]**

```
参照: gcp/lesson4/2. cache/cache.tf

resource "google_redis_instance" "cache" {
  name           = "${var.user_name}-cache"
  region         = "asia-northeast1"
  memory_size_gb = 1

  tier          = "STANDARD_HA"
  redis_version = "REDIS_7_2"

  authorized_network = module.before.vpc_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  depends_on = [google_service_networking_connection.private_service]
}

★ depends_on を書く理由
   ピアリングが張られる前に作ろうとすると失敗します
   Terraformは参照関係から順序を推測しますが、
   このケースは参照がないので明示する必要があります
```

---

### S24 | Step2 実行

**[本文]**

```
  terraform plan
  terraform apply

★ Memorystoreの作成には6分前後かかります
   (限定公開サービスアクセスのピアリングも含めて)
   待っている間に Spanner の話に進みます(S26へ)

> **検証済み(2026-08-28)**: ピアリング + Memorystore で 6分5秒。
> cache_host は貸し出しレンジから 172.16.200.84 が払い出された。

◼確認
  terraform output cache_host
  → 172.16.200.x
```

---

### S25 | アプリの接続先を切り替える

**[本文]**

```
◼VMの中で、cacheコンテナを止めてMemorystoreに向ける

  docker stop cache && docker rm cache
  curl -X GET "http://localhost"     → Cache接続: 失敗

  redis-cli -h [cache_host] ping     → PONG

  docker stop app && docker rm app
  docker run -d -p 80:8080 --network app-nw --name app \
    -e DB_HOST=db -e DB_PASS=infra-study \
    -e CACHE_HOST=[cache_host] \
    app:0.1

  curl -X GET "http://localhost"     → Cache接続: 成功

★ Firewall Rules を1つも書いていないのに繋がります
   ピアリング経由なのでVPC Firewall Rulesの対象外だからです
```

---

# Spanner

---

### S26 | Spanner とは ★

**[図版]** 新規。Spannerの立ち位置を示す2軸図。
横軸「スケーラビリティ」、縦軸「一貫性・SQLの表現力」。
右上にSpannerだけがいる。

**[本文]**

```
◼Cloud Spanner

Googleが自社サービスのために作ったデータベース
広告システム(F1)、Gmail、Photos などを支えている

  リレーショナル      SQLが書ける。JOINもトランザクションも効く
  水平スケール        ノードを足せば書き込みも増える
  強整合性            どのレプリカから読んでも同じ結果
  高可用性            99.999% SLA(マルチリージョン構成)

★ この4つを同時に満たすのがSpannerの特徴
```

---

### S27 | なぜAWSに相当がないのか

**[図版]** **新規作成**。この回の最重要図その3。3つのDBの比較表。

**[本文]**

```
                    トランザクション  JOIN   水平スケール  グローバル
──────────────────────────────────────────────────────────────
Aurora (AWS)            ○           ○        △          ×
                                          (読みのみ)
DynamoDB (AWS)          △           ×        ○          △
                     (制限あり)                      (Global Tables)
Spanner (GCP)           ○           ○        ○          ○

◼NoSQLが諦めたもの
「水平にスケールするために、トランザクションとJOINを諦める」
これが2000年代のNoSQLの割り切りだった

◼Spannerが諦めなかった理由
TrueTime という仕組み
  Googleのデータセンターに原子時計とGPSを置き、
  世界中のサーバで「今」の誤差を数ミリ秒に抑えている
  → 分散していても「どちらが先か」を判定できる
  → 分散トランザクションが成立する

★ ハードウェアから作れるGoogleだからできた
   だからAWSに同じものが無い
```

**[話す]** ここは「なぜSpannerが特別なのか」の説明。
TrueTimeの詳細まで踏み込まなくてよいが、
「時刻を正確にしたから分散トランザクションができた」という
発想の面白さは伝えたい。

---

### S28 | Spanner の構成単位

**[図版]** 新規。インスタンス → データベース → テーブル の3段。

**[本文]**

```
◼インスタンス
処理能力とデータの置き場所を決める単位

  インスタンス構成 (config)
    regional-asia-northeast1   東京の3ゾーンに複製
    nam-eur-asia1              北米・欧州・アジア(マルチリージョン)

  処理能力 (processing_units)
    1000 PU = 1ノード
    最小は 100 PU  ← 今日はこれ

◼データベース
インスタンスの中に複数作れる
スキーマ(DDL)を持つ

◼テーブル
主キーが必須。主キーの設計がとても重要(次のスライド)

★ AWSとの対応
  Aurora  クラスター + インスタンス(複数)
  Spanner インスタンス(処理能力の単位) + データベース
```

---

### S29 | 主キーの設計が全て ★

**[図版]** **新規作成**。この回の最重要図その4。
スプリットの図と、連番によるホットスポットの図を並べる。

```
  Spannerは主キー順にソートして、スプリットに分けて配る

  主キー順:  aaa | bbb | ccc | ddd
             └─┘ └─┘ └─┘ └─┘
            サーバA  B    C    D

  ◯ UUID など、ばらける主キー
     aaa | bbb | ccc | ddd     書き込みが分散する
      ↑    ↑    ↑    ↑

  ✕ 連番・タイムスタンプ
     997 | 998 | 999 | 1000    末尾に全部集中(ホットスポット)
                        ↑↑↑↑
```

**[本文]**

```
◼Spannerはデータを主キーの順に並べて保持する

一定サイズごとに スプリット という単位に分割し、
複数のサーバに配ることで水平スケールする

◼だから主キーが連番だと台無しになる

新しい行が常に末尾に来る
→ 末尾のスプリットを持つサーバ1台に書き込みが集中
→ ノードを増やしても速くならない

これを ホットスポット と言う

◼避け方
  UUID を使う
  ハッシュを先頭に付ける
  分散する列を主キーの先頭に置く

★ AUTO_INCREMENT の感覚で設計すると必ず失敗します
★ DynamoDBのパーティションキーと同じ悩み
```

**[話す]** ここがSpannerで一番失敗しやすいところ。
「MySQLからそのまま移してきたらスケールしなかった」の原因はほぼこれ。

---

### S30 | インターリーブ

**[図版]** 新規。親子テーブルの行が物理的に隣り合っている図。

**[本文]**

```
◼インターリーブ (INTERLEAVE IN PARENT)
親テーブルの行の「すぐ隣」に、子テーブルの行を物理配置する

  users(u001)
    orders(u001, o001)   ← 同じスプリットに入る
    orders(u001, o002)
  users(u002)
    orders(u002, o001)

◼何が嬉しいか
親子を一緒に読むJOINが、1台のサーバで完結する
分散DBではネットワークをまたぐJOINが重いので、効果が大きい

◼AWSのRDBには無い概念
テーブルの物理配置を明示的に指定する、という発想がない

◼使わない方がよいケース
  1つの親に子が極端に多い(100万行など)
  子を単独で検索することが多い

★ 迷ったら使わない。JOINは普通にできます
```

---

### S31 | Terraform コード(Spanner インスタンス)

**[本文]**

```
参照: gcp/lesson4/3. spanner/spanner.tf

resource "google_spanner_instance" "main" {
  name         = "${var.user_name}-spanner"
  display_name = "${var.user_name} spanner"

  config           = "regional-asia-northeast1"
  processing_units = 100        ← 最小構成(1000PU = 1ノード)

  force_destroy = true          ← 勉強会用。本番は false
}

★ config は後から変更できません
   regional から multi-region への変更は作り直しになります

★ processing_units は無停止で変更できます
   足りなくなったら増やせばよい

★ 課金に注意
   100 PU でも動かしている間ずっと課金されます
   今日の中で一番高いリソースです。必ず destroy してください
```

---

### S32 | Terraform コード(データベースとスキーマ)

**[本文]**

```
resource "google_spanner_database" "app" {
  instance = google_spanner_instance.main.name
  name     = "test-db"

  database_dialect = "GOOGLE_STANDARD_SQL"   // PostgreSQL方言も選べる

  ddl = [
    <<-SQL
      CREATE TABLE users (
        user_id STRING(36) NOT NULL,
        name    STRING(255) NOT NULL,
        created TIMESTAMP OPTIONS (allow_commit_timestamp = true)
      ) PRIMARY KEY (user_id)
    SQL
    ,
    <<-SQL
      CREATE TABLE orders (
        user_id  STRING(36) NOT NULL,
        order_id STRING(36) NOT NULL,
        item     STRING(255) NOT NULL
      ) PRIMARY KEY (user_id, order_id),
      INTERLEAVE IN PARENT users ON DELETE CASCADE
    SQL
  ]

  deletion_protection = false
}

★ スキーマをTerraformで管理できる
   Cloud SQL では手で CREATE TABLE を流していました

★ ddl は追記していく形
   既存の要素を書き換えるとエラーになります
   運用ではマイグレーションツールを使うことが多い
```

**[話す]** `ddl` をTerraformで持つかどうかは意見が分かれる。
テーブル定義はアプリのリリースと一緒に動くことが多いので、
実務ではマイグレーションツール(Liquibase, wrenchなど)に任せて、
Terraformはインスタンスとデータベースまで、という切り方も多い。

---

### S33 | 認証はIAM。パスワードが無い ★

**[図版]** 新規。第1回のIAM図を再掲し、SAからSpannerへの矢印を描く。

**[本文]**

```
resource "google_spanner_database_iam_member" "web" {
  instance = google_spanner_instance.main.name
  database = google_spanner_database.app.name
  role     = "roles/spanner.databaseUser"
  member   = "serviceAccount:${module.before.web_service_account_email}"
}

◼Spanner には DBユーザーもパスワードも無い

  接続してくるプリンシパル(サービスアカウント)を
  IAMで認可する

  → アプリは認証情報を何も持たない
  → tfstateに残る秘密も無い
  → 漏洩する鍵が存在しない

◼第1回でやったこと
「サービスアカウントにリソース単位でロールを付ける」
まさにそれをやっています

★ Cloud SQL ではパスワードの扱いに悩みます(後半で触れます)
★ Spanner にはその悩み自体がありません
```

**[話す]** 第1回の宿題2で「なぜ Secret Manager の値を Terraform に書かないのか」を
考えてもらった。Spannerでは、そもそも秘密が発生しない。
これがマネージドサービスをIAMで統一することの利点。

---

### S34 | Step3 実行

**[本文]**

```
  terraform plan
  terraform apply

★ Spannerの作成は1〜2分で終わります
   Cloud SQL(15分)や Memorystore(6分)よりずっと速い

> **検証済み(2026-08-28)**: インスタンス + データベース + IAM で 1分6秒。
> インターリーブを含むDDLもそのまま通った。

◼確認
  terraform output spanner_database
  → projects/xxx/instances/yyy-spanner/databases/test-db

  gcloud spanner instances list
  gcloud spanner databases ddl describe test-db --instance=[自分の名前]-spanner
```

---

### S35 | アプリの接続先をSpannerに切り替える

**[本文]**

```
◼VMの中で

  # ローカルのMySQLを止める
  docker stop db && docker rm db

  # アプリをSpannerに向けて再起動
  docker stop app && docker rm app
  docker run -d -p 80:8080 --network app-nw --name app \
    -e DB_KIND=spanner \
    -e SPANNER_DATABASE='projects/xxx/instances/yyy-spanner/databases/test-db' \
    -e CACHE_HOST=[cache_host] \
    app:0.1

  curl -X GET "http://localhost"

  Hello, Infra Study
  hostname: xxxx
  DB接続(Spanner): 成功
  Cache接続: 成功

★ パスワードを渡していません
   VMに付いているサービスアカウントの権限で繋がっています

★ ホスト名もポート番号も指定していません
```

> **検証済み(2026-08-28)**: 外部IPを持たないVMから
> `DB接続(Spanner): 成功` を確認。
> go-sql-spanner ドライバでのビルドと接続が通ることも確認済み。

---

### S36 | データを入れてみる

**[本文]**

```
◼gcloud で直接操作できる

  gcloud spanner rows insert --table=users \
    --database=test-db --instance=[自分の名前]-spanner \
    --data=user_id=u001,name=infra

  gcloud spanner databases execute-sql test-db \
    --instance=[自分の名前]-spanner \
    --sql="SELECT * FROM users"

◼インターリーブした子テーブルにも入れてみる

  gcloud spanner rows insert --table=orders \
    --database=test-db --instance=[自分の名前]-spanner \
    --data=user_id=u001,order_id=o001,item=book

  gcloud spanner databases execute-sql test-db \
    --instance=[自分の名前]-spanner \
    --sql="SELECT u.name, o.item FROM users u JOIN orders o USING (user_id)"

★ 普通にSQLが書けます。JOINも効きます
★ 宿題でもう少し触ってもらいます
```

---

### S37 | 料金の考え方

**[本文]**

```
◼課金される要素

  処理能力(PU)   動かしている間ずっと
  ストレージ      保存量
  ネットワーク    リージョン間の通信

◼最小構成でも安くはない
  100 PU を1ヶ月動かすと、Cloud SQL の小さいインスタンスより高い

◼だから
  小規模なら Cloud SQL
  スケールが要る・止められない なら Spanner

★ 「無料枠が無い」ことに注意
   今日作ったものは必ず destroy してください
```

**[話す]** 実務でSpannerを選ぶのは「止まらないこと」と
「将来のスケール」にお金を払う判断。小さく始めるなら Cloud SQL でよい。
そこの判断軸を持っておいてほしい。

---

### S38 | Spanner のまとめ

**[本文]**

```
◼構成
インスタンス(処理能力と配置) → データベース(スキーマ) → テーブル

◼設計
主キーの設計が全て。連番はホットスポットになる
インターリーブで親子を近くに置ける

◼接続
IPもポートも無い。Google API 経由
Private Google Access があれば届く
認証はIAM。パスワードが無い

◼AWSに相当が無い
トランザクション・JOIN・水平スケール・グローバルを同時に満たす
TrueTime という仕組みが支えている
```

---

### S39 | (参考)マルチリージョン構成

**[本文]**

```
◼今日は regional-asia-northeast1 で作りました
東京の3ゾーンに複製されている
1ゾーンが落ちても、残り2つで動き続ける

◼マルチリージョン構成にすると
  nam-eur-asia1 など
  複数の大陸にレプリカを置ける
  リージョンごと落ちても動き続ける
  SLA 99.999%

★ 書き込みのレイテンシは伸びます
   遠くのレプリカと合意を取る必要があるため

★ config は後から変更できません
   最初の選択が重要
```

**[話す]** 時間が押していたらここは飛ばしてよい。

---

### S40 | Spanner 接続完了

**[図版]** AWS版 第5回「Aurora 接続完了！」の構図を流用。
**新規スクリーンショット**(`DB接続(Spanner): 成功` が見えるように)。

---

# Cloud SQL(概説)

---

### S41 | Cloud SQL

**[本文]**

```
◼Cloud SQL
マネージドのMySQL / PostgreSQL / SQL Server。AWSのRDSに相当

みんな知っていると思うので、要点だけやります
実際に作るのは宿題です(作成に10分かかるため)

◼RDS との違い

  AWS版で作っていたもの(6リソース)
    セキュリティグループ / DBサブネットグループ /
    パラメータグループ / クラスターパラメータグループ /
    RDSクラスター / RDSクラスターインスタンス × 2

  GCP版(3リソース)
    google_sql_database_instance   本体
    google_sql_database            データベース
    google_sql_user                ユーザー

★ クラスターとインスタンスの2階層が無い
  AWS  「クラスターの中にインスタンスを増やす」
  GCP  「インスタンス1つ。HAもレプリカも属性で指定」
```

---

### S42 | 高可用性構成と Spanner との違い ★

**[図版]** 新規。Cloud SQL の「プライマリ + スタンバイ」と
Spanner の「3ゾーンのレプリカ」を左右で比較。

**[本文]**

```
◼availability_type

  ZONAL      1ゾーンだけ。障害時は復旧まで停止
  REGIONAL   別ゾーンにスタンバイ。自動フェイルオーバー

◼スタンバイは待機専用
接続できない。読み取りにも使えない
読み取りを分散したいならリードレプリカを別リソースで作る

◼Spanner との違い

              Cloud SQL (REGIONAL)    Spanner (regional)
  構成         プライマリ + スタンバイ   3ゾーンに投票権を持つレプリカ
  ゾーン障害時  フェイルオーバー(60秒)   そのまま継続
  書き込み先    プライマリ1台            合意が取れれば継続
  運用          切り替えを意識する       意識しない

★ Spannerが高い理由の一部がこれ
   「止まらないこと」にお金を払っている

★ フェイルオーバーの実測は宿題でやってもらいます
```

**[話す]** ここが今日のまとめでもある。
「HA構成なら無停止」ではない、というのがCloud SQLの話。
Spannerはそもそも切り替えという概念が無い。この差が価格差になっている。

---

### S43 | パスワードをどう扱うか

**[本文]**

```
◼Spanner にはパスワードが無かった
◼Cloud SQL にはある。どう扱うか

◼AWS版はこうしていた
  master_password = "[ROOT_PASSWORD]"
  → tfstateに平文で残る

◼GCP版では password_wo を使います

  resource "google_sql_user" "app" {
    name        = "app"
    instance    = google_sql_database_instance.db.name
    password_wo         = var.db_password
    password_wo_version = 1
  }

  "wo" は write-only の略
  この引数に渡した値は tfstate に保存されません

◼値は環境変数から渡す
  export TF_VAR_db_password='...'
  terraform apply

★ 第1回の宿題2でやった「tfstateに秘密を残さない」の実践
```

> **検証済み(2026-08-28)**: apply後の tfstate を確認したところ
> `google_sql_user` の属性は次のようになっていた。
>
> ```
> {'name': 'app', 'password': None, 'password_wo': None, 'password_wo_version': 1}
> ```
>
> パスワードの実値で grep しても0件。確かに保存されていない。

---

### S44 | Cloud SQL は宿題で作ります

**[本文]**

```
◼今日は作りません

  Cloud SQL の作成には約10分かかります
  講義中に待つには長いので、宿題に回します

◼宿題でやること
  Cloud SQL(REGIONAL)を作る
  アプリを Cloud SQL に向ける
  フェイルオーバーを起こして復旧時間を測る

  回答例: gcp/lesson4/syukudai2/

★ 限定公開サービスアクセス(今日作ったもの)をそのまま使い回します
★ password_wo が本当に tfstate に残らないかも確認してみてください
```

---

# まとめ

---

### S45 | 本日のまとめ ①

**[図版]** AWS版 第5回「本日のまとめ」のレイアウトを流用。

**[本文]**

```
◼GCPのマネージドDBは接続方式が3種類ある

  Google API 経由    Spanner / BigQuery
                     Private Google Access があれば届く
                     IPもポートもパスワードも無い

  VPCピアリング       Cloud SQL / Memorystore
                     限定公開サービスアクセスの設定が必要
                     Firewall Rules は不要

  Auth Proxy         Cloud SQL(別解)

★ AWSは「自分のVPCの中にDBが入ってくる」1種類だけだった
```

---

### S46 | 本日のまとめ ②(Spanner)

**[本文]**

```
◼Spanner
リレーショナル・水平スケール・強整合性・高可用性を同時に満たす
AWSに相当するサービスが無い
TrueTime が分散トランザクションを成立させている

◼構成
インスタンス(config と processing_units) → データベース → テーブル
config は後から変更できない。PUは無停止で変更できる

◼設計
主キーの設計が全て。連番はホットスポットになる
インターリーブで親子を物理的に近くに置ける

◼接続
IAMで認可する。パスワードが存在しない
database/sql で書ける(ドライバが違うだけ)
```

---

### S47 | 本日のまとめ ③(その他)

**[本文]**

```
◼Memorystore
ElastiCacheの4リソースが1リソースになる
BASIC / STANDARD_HA
シャード構成は別サービス

◼Cloud SQL
RDSの6リソースが3リソースになる
availability_type = REGIONAL でHA構成
スタンバイは待機専用。フェイルオーバーは60秒程度
password_wo を使うと tfstate に残らない

◼選び方
小さく始める・MySQLが使いたい      → Cloud SQL
スケールが要る・止められない        → Spanner
```

---

### S48 | 本日はここまで

**[図版]** AWS版の同スライドを流用。

---

### S49 | 宿題1 アンケート

**[図版]** AWS版 第5回「宿題1」を流用。URLを差し替え。

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

### S50 | 宿題2 実装課題

**[本文]**

```
◼1. Memorystore にリードレプリカを追加しよう

  ★ 1つハマりどころがあります。エラーメッセージをよく読んでください

◼2. Spanner のインターリーブを体験しよう

  users と orders にデータを入れてJOINしてみる
  親を消すと子も消えることを確認する

  回答例: gcp/lesson4/syukudai1/


◼3. Cloud SQL を作って繋いでみよう(講義でやらなかった分)

  Cloud SQL(REGIONAL)を作る
  アプリを Cloud SQL に向ける
  password_wo が tfstate に残らないことを確認する
  フェイルオーバーを起こして復旧時間を測る

  ★ 作成に10分かかります。時間のあるときにやってください

  回答例: gcp/lesson4/syukudai2/

★ 次回(12/24)まで17日ありますが年末なので、宿題は軽めにしています
```

---

### S51 | 宿題3 調べ物

**[本文]**

```
◼1. Spanner の主キー設計を調べよう

  自分のプロダクトのテーブルをSpannerに載せるとしたら
  主キーをどう設計するか考えてみてください

  スキーマ設計のベストプラクティス
  https://cloud.google.com/spanner/docs/schema-design

◼2. Spanner にはなぜフェイルオーバーが無いのか

  Cloud SQL には `gcloud sql instances failover` がある
  Spanner には無い

  レプリケーションの仕組みの違いから考えてみてください

  回答例: gcp/lesson4/syukudai3/

◼ドキュメントを眺めてみよう
  Spanner            https://cloud.google.com/spanner/docs
  Memorystore        https://cloud.google.com/memorystore/docs/redis
  限定公開サービスアクセス
    https://cloud.google.com/vpc/docs/configure-private-services-access
```

---

### S52 | 注意事項

**[図版]** AWS版「注意事項」スライドを流用。

**[本文]**

```
宿題などで作成したリソースは
必ず削除してください！

  terraform destroy

★★ この回は課金が大きいです ★★
   Spanner(100 PU)      無料枠なし。今日の中で一番高い
   Cloud SQL (REGIONAL)  2ゾーン分
   Memorystore (STANDARD_HA)  レプリカの分も

★ destroy にも時間がかかります
   時間に余裕を持って実行してください

★★ destroy は素直に終わりません ★★

   Cloud SQL / Memorystore を消したあと、
   限定公開サービスアクセスの接続を消そうとして失敗します

     Error: Unable to remove Service Networking Connection
     Failed to delete connection; Producer services
     (e.g. CloudSQL, Cloud Memstore, etc.) are still using this connection.

   Terraformの削除順序は正しく、DBは消えています
   Google側がピアリングを解放してくれないのが原因です

   ◼手順(この順でやってください)

   1. terraform destroy
        → DBは消える。ピアリングの削除で失敗する

   2. ピアリングを直接消す
        gcloud compute networks peerings delete \
          servicenetworking-googleapis-com \
          --network=[自分の名前]-vpc

   3. terraform destroy
        → 残りが消える

★ 待っても解決しません。手順2が必要です

★ deletion_protection / force_destroy の設定を確認
   本番では逆にする(消せないようにする)設定です

★ tfstate用のバケットは残しておいてください
```

---

### S53 | おしまい

**[図版]** AWS版「おしまい」スライドを流用。

**[本文]**

```
次回は コンテナ編 です(12月24日 木曜)

Artifact Registry / Cloud Run
今日まで「VMの中でdocker run」していたものが
どう変わるかをやります

お楽しみに！！
```

---

# 付録A: ハンズオンのステップ対応表

| Step | ディレクトリ | 作るもの | 確認すること |
|---|---|---|---|
| 0 | `0. before/` | 第2回+第3回の全リソース(23個) | HTTPSでアクセスできる |
| 1 | `1. web/` | (Terraform変更なし) | ローカルコンテナのMySQL/Redisに接続 |
| 2 | `2. cache/` | 限定公開サービスアクセス + Memorystore | **Firewall Ruleなしで繋がる** |
| 3 | `3. spanner/` | Spanner インスタンス/DB/IAM | **パスワードなしで繋がる** |

宿題:

| 宿題 | ディレクトリ | 内容 |
|---|---|---|
| 2-1,2-2 | `syukudai1/` | Memorystore リードレプリカ + Spanner インターリーブ |
| 2-3 | `syukudai2/` | Cloud SQL の構築とフェイルオーバー計測 |
| 3-2 | `syukudai3/` | Spanner のレプリケーション(調べ物のみ) |

AWS版 第5回との対応:

| AWS版 | GCP版 | 備考 |
|---|---|---|
| 0. before | 0. before | 23リソース |
| 1. web | 1. web | 設定を環境変数化。ビルドし直しが不要に |
| 2. cache | 2. cache | **限定公開サービスアクセスが新規に必要** |
| 3. db (Aurora) | **3. spanner** | **主役を差し替え。AWS版に対応するものが無い** |
| — | syukudai2 | AWS版の 3. db に相当。講義では概説のみ、構築は宿題 |

---

# 付録A-2: destroy の手順(重要)

**この回の destroy は1回では終わらない。かつ、待っても解決しない。**
当日の最後に必ず手順を案内すること。

```
# 1回目
terraform destroy
  → Cloud SQL / Memorystore / Spanner は消える
  → 限定公開サービスアクセスの接続の削除で失敗する

# ピアリングを直接消す
gcloud compute networks peerings delete servicenetworking-googleapis-com \
  --network=[自分の名前]-vpc

# 2回目
terraform destroy
  → 残りが消える
```

**なぜ失敗するのか**

Terraform の削除順序は正しい(`depends_on` により DB が先に消える)。
実際に Cloud SQL / Memorystore / Spanner は消えている。

問題は Google 側。プロデューサーサービスを削除しても
ピアリングが `ACTIVE` のまま残り続け、
`google_service_networking_connection` の削除が弾かれる。

**待っても解決しない。**

> **検証済み(2026-08-28)**: DBを全て削除した状態で
> `terraform destroy` を **12分間・6回** リトライしたが、
> 毎回同じエラーで失敗した。
> `gcloud compute networks peerings delete` でピアリングを
> 直接消したところ、次の destroy が33秒で完了した。

**ピアリングが残ると VPC も消せない。**
共有プロジェクトなので、消し残しは他の受講者のQuotaを圧迫する。
手順2を飛ばさないよう強めに案内すること。

**別解: deletion_policy = "ABANDON"**

`google_service_networking_connection` には
`deletion_policy = "ABANDON"` という設定がある。
destroy 時に「接続は消さず、stateから外すだけ」にできる。

ただしピアリングは残るので、VPCが消せない問題は解決しない。
結局 `gcloud compute networks peerings delete` は必要になる。
教材では素直に手順を案内する方を採った。

---

# 付録B: 制作メモ / 要確認事項

## 実環境での動作確認: **完了(2026-08-28)**

Step0〜3 と Cloud SQL(宿題2相当)を通しで apply → destroy 済み。
`terraform validate` は全6ディレクトリで成功(google provider 8.0.0)。

| 項目 | 結果 |
|---|---|
| `0. before`(23リソース) | OK。4分48秒 |
| 限定公開サービスアクセス + Memorystore | OK。6分5秒。IPは貸出レンジから払い出された |
| Spanner(インターリーブDDL含む) | OK。**1分6秒**。Cloud SQLよりずっと速い |
| **外部IPなしVMから Spanner へ到達** | **OK**。Private Google Access のみで届いた |
| **Spanner の IAM** | **OK**。DB単位の `roles/spanner.databaseUser` だけで足りた |
| **go-sql-spanner でのビルドと接続** | **OK**。`DB接続(Spanner): 成功` |
| Spanner + Memorystore 同時接続 | OK |
| Cloud SQL(REGIONAL) | OK。9分28秒。プライマリ 1-a / セカンダリ 1-c |
| **`password_wo` が tfstate に残らない** | **OK**。`password: None` のみ。実値の grep は0件 |
| destroy | ピアリング削除に回避策が必要(付録A-2) |

### 見つけて修正したバグ

**1. 貸し出しレンジが `/24` では足りない**

Memorystore を作った時点でブロックが埋まり、Cloud SQL の作成が失敗した。

```
Couldn't find free blocks in allocated IP ranges.
Please allocate new ranges for this service provider.
```

`/20` に変更して解決。Googleは `/16` を推奨。

さらに、Cloud SQL は作成に失敗すると `state: FAILED` で残る。
Terraformのstateには入らないので次のapplyは
`The Cloud SQL instance already exists` で失敗する。
`gcloud sql instances delete` してから再実行が必要。

**2. e2-micro ではアプリがビルドできない**

| マシンタイプ | 結果 |
|---|---|
| e2-micro (2共有vCPU / 1GB) | **16分経っても完了せず**(load average 4.11) |
| e2-medium (2vCPU / 4GB) | **5分16秒で完了** |

第3回のVMも e2-medium に変更し、`0. before` と整合させた。
第3回のビルドも 6分46秒 → 2分14秒 に改善している。

**3. destroy が待っても終わらない**

付録A-2 に手順を記載。12分・6回リトライしても解決せず、
`gcloud compute networks peerings delete` が必要だった。

### 受講者相当の権限での検証(2026-08-28 実施)

第1回 付録A の9ロールだけを持つサービスアカウントになりすまして通した結果、
**第2〜4回の全リソース(34個。Cloud SQL 含む)が作成できた。**

`0. before` に第2回・第3回が積み上がっているため、
**第4回を1本流すだけで過去の回の権限も同時に検証できる。**

ロールは当初の想定より少なくて済んだ(`cloudsql.admin` / `redis.admin` は不要)。

### まだ検証できていないこと
- **Cloud Shell での実行**。第1回〜第4回とも未実施
- 宿題1(Memorystore リードレプリカの5GB制約)のエラーメッセージ実測

## 受講者ロールへの追加が必要

第1回 付録Aのロール構成に、この回から次が必要になる。

```
roles/spanner.admin
roles/servicenetworking.networksAdmin
```

`roles/cloudsql.admin` / `roles/redis.admin` は**不要**。
作成権限は `roles/editor` に含まれている。

**第1回の付録Aに追記済み(計9ロール)。**

## 新規作図が必要なスライド

| スライド | 内容 | 優先度 |
|---|---|---|
| S17 | 3種類の接続方式(AWS/GCP比較) | **最高** |
| S29 | 主キーとスプリット / ホットスポット | **最高** |
| S27 | Aurora / DynamoDB / Spanner の比較表 | 高 |
| S19 | VPCピアリング(レンジの貸し出し) | 高 |
| S10 | ゴール構成図(接続経路が3種類) | 高 |
| S26 | Spannerの立ち位置(2軸図) | 中 |
| S28 | Spannerの構成単位 | 中 |
| S30 | インターリーブの物理配置 | 中 |
| S33 | SAからSpannerへのIAM | 中 |
| S08 | 用途別のDB選択表 | 低 |

## 設計書からの変更点

**この回は設計書の内容から大きく変えている。**

- 設計書では「Cloud SQL(HA構成・フェイルオーバー)」が本編で、
  Spannerは「概説」だった
- 社内で Spanner をメインで使っているため、**Spanner を本編**に変更
- Cloud SQL は「みんな知っている」前提で軽く扱い、フェイルオーバーの計測は宿題へ
- ハンズオン到達点も「アプリから Spanner と Memorystore に接続」に変更

その他:

- アプリの設定を環境変数化した。1つのイメージで MySQL / Spanner の
  両方に繋げるようにしてある(`DB_KIND` で切り替え)
- 「3種類の接続方式」は設計書5章の「置換では済まない設計判断」に
  追加すべき項目。第5回(Cloud Run)でも接続方式の話が出てくる
