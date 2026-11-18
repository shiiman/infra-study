# 第4回 インフラ勉強会(GCP) — データベース

- **開催日**: 2026-12-10(**木**)15-17時 ★ 曜日が違うので注意
- **AWS版対応**: 第5回(AWS データベース編)
- **Terraformコード**: `gcp/lesson4/`
- **ゴール**: アプリから Spanner と Memorystore に接続できる
- **スライド同期**: 2026-11-17 時点で、Googleスライドの1〜16枚目(S01〜S15-2)・18枚目(S17)・S19〜S25(PSC + Valkey に差し替え。2026-11-18 に S19 と S20 の順序を入れ替え、S20b・S20c・S21・S22b は同じ説明の繰り返しなので削除)・S44〜S47・S50〜S52 を原稿と合わせた。
  S18 と S26〜S43(Spanner・Cloud SQL の説明)・S46・S48・S49・S53 は、今回の変更の対象外で、未確認のまま。
  S16「休憩」は、デッキの16枚目(S15-2)の次が S17 のため、デッキ側に対応するスライドが見当たらない。
  - 今回の PSC + Valkey への切り替え(2026-11-17)は、スライドに次の変更を入れた。内容は付録「PSC + Memorystore for Valkey への切り替え」を参照。
    - 変更: S19(PSC を先に説明する)・S20(ピアリングは旧方式に。一部はまだ必要と明記)・S22・S23・S24・S25・S34(「Memorystore(5分)」の1か所のみ)・S44・S45・S47・S50・S51(2/2)・S52
    - 削除: S22b「Memorystore for Valkey の構成」(S22 から分けたが、不要と判断して2026-11-18 に削除)
    - 削除: S52b「注意事項(2/2)」(PSC では destroy が1回で終わるため)
  - S05「どれを使えばいいのか」・S07「万能なデータベースは無い」はデッキから削除し、欠番。
    S07 の文言は図の中に移っている(S06 の図に「万能なデータベースなど存在しない！」、S08 の図に「様々なワークロードに最適なデータベースを選択すべき！」)
  - S10「今日のゴール」は S04-2「ゴール」へ移動し、欠番
  - S04-2(ゴール)・S04-3(章扉)・S12-2(章扉「本日の実習」)・S15-2(スクリプトの説明)は S番号を振り直さないための仮番号(第2回と同じ扱い)。S11 以降の番号は変えていない

> **この回はAWS版と構成を大きく変えている。**
> 社内で Spanner をメインで使っているため、**Spanner を本編**に据え、
> Cloud SQL は「みんな知っている」前提で軽く扱う。
> AWS版は Aurora(= Cloud SQL相当)が主役だったので、そのままでは対応しない。

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入 | 6分 | S01〜S04-2(S04-2 はゴール) |
| データベースの選び方 | 12分 | S04-3・S06・S08・S09(S05・S07 は欠番) |
| 準備 + Step1(ローカルDB) | 15分 | S11〜S15-2(S10 は S04-2 へ移動、S12-2 は章扉) |
| 休憩 | 5分 | S16 |
| 4種類の接続方式 + Memorystore(Step2) | 27分 | S17〜S25 |
| **Spanner(Step3)** | **41分** | S26〜S40 |
| Cloud SQL(概説のみ) | 6分 | S41〜S44 |
| まとめ・宿題 | 8分 | S45〜S53 |

> **ハンズオンは Spanner で終わり。Cloud SQL は概説のみで、構築は宿題に回した。**
> Cloud SQL は作成に10分かかるうえ、社内では既知の人が多いため。
> これにより待ち時間が 22分 → **12分** に減っている。

> **待ち時間が長い回。**
> - S15 スクリプトの実行: 約6分(e2-medium。実機で6分強。e2-microでは終わらない)
> - S24 Memorystore の作成: 約5〜6分(実測。PSC + Valkey で 8.0 が5分13秒、9.1 が6分5秒)
> - S34 Spanner の作成: 約1分(実測)
>
> 合計 **約12分**。第3回(17分)より改善している。
>
> 押した場合の削り所: S06(DBの歴史)は口頭のみで圧縮できる。
> S39(マルチリージョン構成)も飛ばせる。
>
> **削ってはいけないのは S17〜S20**(4種類の接続方式)と
> **S28〜S34**(Spannerの構成と主キー設計)。この回の核心。

## 事前準備(講師)

1. 受講者が第3回のリソースを destroy 済みであること
2. API の有効化
   ```
   gcloud services enable networkconnectivity.googleapis.com \
     memorystore.googleapis.com sqladmin.googleapis.com spanner.googleapis.com
   ```
3. 受講者のロールに以下を**追加**すること(第1回 付録Aの構成では足りない)
   ```
   roles/spanner.admin                   spanner.databases.setIamPolicy
   ```
   Spanner / Cloud SQL / Memorystore の**作成権限は `roles/editor` に含まれている**ので、
   `roles/cloudsql.admin` や `roles/memorystore.admin` は不要。
   PSC で使うサービス接続ポリシー(`networkconnectivity.serviceConnectionPolicies.*`)の
   作成・削除・更新の権限も、Editor に含まれていることを確認済み(2026-11-17)。
   Editor に無いのは上記1つの権限だけ。
   (以前の手順の限定公開サービスアクセスで必要だった
   `roles/servicenetworking.networksAdmin` は、PSC では要らない)
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

2026年12月10日(木) 15-17時
```

---

### S02 | インフラ勉強会 スケジュール

**[図版]** 第2回 S02 と同じスライドを複製。今日の行のマーカーは付けない。

**[話す]** 次回(第5回)は12/24の木曜日。年末なので今日の宿題は控えめにしてある。

---

### S03 | 前回の振り返り

**[図版]** AWS版 第5回「前回」2枚を流用。中身を差し替え。

**[本文]**

```
◼前回やったこと

Compute Engine でVMを作り、コンテナでアプリを動かした
ロードバランサを6つの部品で組み立てた
130.211.0.0/22 と 35.191.0.0/16 をファイヤーウォールへ設定し、ヘルスチェックを通した
Cloud DNS でドメインを割り当て、マネージドSSL証明書でHTTPS化した
```

---

### S04 | 今日のアジェンダ

**[図版]** 第3回 S04 と同じスライドを複製して、内容を第4回のものに差し替える。

**[本文]**

```
データベースの選び方

4種類の接続方式

Memorystore

Spanner

Cloud SQL

ハンズオン：ローカルDB → Memorystore → Spanner
```

**[話す]** 今日の主役は Spanner。うちで実際にメインで使っているデータベース。
Cloud SQL(MySQL / PostgreSQL)はみんなだいたい知っているので軽くやる。
リレーショナルDBといえばAurora / Cloud SQLが定番だが、
今回はSpannerを主役にする。実務で使っているものを深くやりたいので。

---

### S04-2 | ゴール

<!-- slide-id: g004slide -->

**[図版]** 第3回 S05 のゴール図をベースに、右側に2つの接続先を描く。
接続経路(Private Service Connect / Google API 経由)が別々であることが見えるように描くのがポイント。
Cloud SQL は今日作らない(宿題)ので図に入れない。

**[本文]**

```text
アプリから、接続経路の違う Spanner と Memorystore に接続する

VPC ネットワーク

private subnet
asia-northeast1

Compute Engine
web VM(アプリ)

③ Private Service Connect

Memorystore
(Valkey)

Private Google Access
(第2回で有効化した)

② Google API 経由

Spanner
(IPもポートも無い)

ゴール：Spanner と Memorystore に接続できる

Hello, Infra Study
DB接続(Spanner): 成功
Cache接続: 成功
```

---

# データベースの選び方

---

### S04-3 | データベースの選び方(章扉)

<!-- slide-id: audit_section_4_0 -->

**[本文]**

```text

```

> **欠番**: S05「どれを使えばいいのか」はデッキから削除した。

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
  2012年         Google が Spanner の論文を公開
                「スケールするのに一貫性も諦めない」

万能なデータベースなど存在しない！
```

**[話す]** NoSQLは「水平にスケールしたいから、トランザクションや
JOINを諦める」という割り切りだった。Spannerはそこを諦めなかった。
だからGoogleの看板技術と言われる。

---

> **欠番**: S07「万能なデータベースは無い」はデッキから削除した。
> 文言は図の中に移っている。「万能なデータベースなど存在しない！」は S06 の図、
> 「様々なワークロードに最適なデータベースを選択すべき！」は S08 の図。
> 「★ ただし「まずSpanner」で成立する場面は増えている」は載せていない。

---

### S08 | 用途で選ぶ

**[図版]** **新規作成**。GCPのDBサービス一覧表。Spannerを強調する。

**[本文]**

```
用途                              GCP           AWS
リレーショナル(スケール)          Spanner       相当なし
リレーショナル(一般)              Cloud SQL     RDS
リレーショナル(PostgreSQL互換)    AlloyDB       Aurora
キャッシュ                        Memorystore   ElastiCache
ドキュメント                      Firestore     DynamoDB
ワイドカラム(大規模)              Bigtable      DynamoDB
データ分析                        BigQuery      Redshift / Athena

様々なワークロードに最適なデータベースを選択すべき！
```

---

### S09 | Cloud SQL / AlloyDB / その他（概説）

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

> **欠番**: S10「今日のゴール」は、第3回と同じ位置(アジェンダの直後)の S04-2「ゴール」へ移動した。
> Cloud SQL は今日作らない(宿題)ので、図から外している。

---

### S11 | 準備

**[図版]** AWS版 第5回「準備」を流用。コマンドを差し替え。

**[本文]**

```
◼Cloud Shell を立ち上げる
  プロジェクトが [プロジェクトID] になっていることを確認
  gcloud config get-value project
  (違うなら) gcloud config set project [プロジェクトID]

◼作業ディレクトリを作る
  mkdir -p ~/works/lesson4

◼サンプルコードを更新
  cd ~/infra-study && git pull

※ 第3回のリソースは destroy しておいてください
   同じ名前のVPCを作るので、残っていると衝突します
```

---

### S12 | 前回までの構成を作成する

**[本文]**

```
cd ~/works/lesson4 && cp -rf ~/infra-study/gcp/lesson4/"0. before" ./
cd "0. before"
python3 ~/infra-study/gcp/tools/configure.py

第2・3回の構成を再作成します。
ネットワーク / Web VM / ロードバランサ / DNS / SSL証明書

terraform init
terraform plan, terraform apply

証明書の発行を待つ間に、次の解説へ進みます。
```

---

# 本日の実習

---

### S12-2 | 本日の実習(章扉)

<!-- slide-id: h5412d2891662c16b_0_21 -->

**[本文]**

```text

```

---

### S13 | まずはローカルのDBに繋ぐ

<!-- slide-id: g012slide -->

**[図版]** AWS版 第5回「EC2」の「まずはWebインスタンス内のアプリを更新しよう！」を参考に新規作図。
web VM の枠の中に db / app / cache の3コンテナを横に並べ、app から db と cache へ矢印を引く。
下に黄色のバナーで「1つずつ置き換えていく」を入れる。

**[本文]**

```text
◼いきなりマネージドサービスに繋がない

まずVMの中でMySQLとRedisをコンテナで動かし、
アプリから繋がることを確認する

Compute Engine  web VM

dbコンテナ
MySQL  :3306

appコンテナ
アプリ  :80

cacheコンテナ
Redis  :6379

そのあと、1つずつ置き換えていく
★ 「動いている状態」を基準に、1つずつ変えるのが安全
```

---

### S14 | 今日のアプリ

<!-- slide-id: g013slide -->

**[図版]** 新規作図。左にアプリの出力例(curl の結果)、右に環境変数とその意味を表で並べる。
「アプリが何を表示するか」と「接続先をどう切り替えるか」を左右に分けて見せる。
下の黄色いバナーで、環境変数で渡す理由を伝える。

**[本文]**

```text
◼アプリが表示するもの

curl http://localhost

  Hello, Infra Study
  hostname: [CONTAINER ID]
  DB接続(MySQL): 成功
  Cache接続: 成功

◼設定は環境変数から読みます

DB_KIND                             使うDBを切り替える(mysql / spanner)
DB_HOST / DB_USER / DB_PASS / DB_NAME   MySQL の接続先
SPANNER_DATABASE                    Spanner の接続先
CACHE_HOST                          キャッシュ(Redis)の接続先

※ 環境変数で渡すのは、接続先を変えるたびにビルドし直さなくて済むため
```

---

### S15 | Step1 ローカルDBに接続する

<!-- slide-id: g014slide -->

**[図版]** VM内で実行するコマンドと、実行時間・確認方法を示すスライド。
上から、web インスタンスへ入るコマンド、VMの中でスクリプトを実行するコマンド、確認の curl を並べる。
右の吹き出しで「約6分かかる」「終わったら curl で確認」「失敗なら30秒待って再実行」を伝え、下の黄色いバナーで次のページへつなぐ。
スクリプトの中身は次のページで説明する。

**[本文]**

```text
◼webインスタンスに入る
  gcloud compute ssh [自分の名前]-web --zone=asia-northeast1-a --tunnel-through-iap

◼VMの中で、スクリプトを実行する
  sudo su -
  apt-get update && apt-get install -y git
  git clone https://github.com/shiiman/infra-study.git
  bash "infra-study/gcp/lesson4/1. web/setup_local.sh"

◼確認する
  curl http://localhost

実行には約6分かかります
終わったら下の curl で確認します
「失敗」なら30秒待って再実行

次のページで、このスクリプトが何をしているかを見ていきます
```

**[話す]** 手順はスクリプト(`setup_local.sh`)にまとめてあります。
SSHで入ったVMでは、複数行をまとめて貼ると行が欠けることがあるため、貼る行を減らしました。
スクリプトは約6分かかります。終わったら、確認は手で `curl` を実行します。確認はスクリプトに含めていません。
MySQLは初回起動が遅いので、「失敗」と出たら30秒ほど待って、もう一度 `curl` を実行してもらいます。
「DB接続」と「Cache接続」がどちらも「成功」と出れば完了です。待っても失敗が続くときは `docker logs db` / `docker logs app` を見ます。

**★ 第4回からVMを e2-medium に上げています。**
Spannerのクライアントライブラリ(Google Cloud Go SDK + gRPC)は依存が大きく、
第3回まで使っていた e2-micro ではビルドが終わりません。

> **検証済み(2026-08-28)**:
> e2-micro  → 16分経っても完了せず(load average 4.11 で飽和)
> e2-medium → **5分16秒**で完了
>
> `0. before` の machine_type を e2-medium に変更済み。
> マシンタイプは用途で変える、という実例としても使える。
>
> ※ 上の検証は、旧手順(コマンドを1行ずつ実行)での計測。
>
> **`setup_local.sh` の実機検証済み(2026-11-17)**:
> git・docker が入っていないVMで、スクリプトの実行は**6分強**で完了。
> 手で実行した `curl http://localhost` でも、問題なく「成功」が返った。
> git は、スクリプトを取得するために15枚目の `apt-get install -y git` で先に入れる必要がある。

---

### S15-2 | Step1 スクリプトがやっていること

<!-- slide-id: p2_4_g014bdy_1 -->

**[図版]** スクリプトがやっていることを表にした図。左にステップ名、右にそのステップでやっていること。
準備・ネットワーク・確認は青、db と cache は黄、app は白(青枠)で色分けする。⑥ 確認だけはスクリプトに含めず、手で実行する。
下の黄色いバナーで、MySQL は初回起動が遅いので「失敗」なら30秒待って再実行することを伝える。

**[本文]**

```text
① 準備        docker・git と mysql / redis のクライアントを入れる
② ネットワーク  コンテナ同士をつなぐ app-nw を作る
③ db          MySQL のコンテナをビルドして起動する(:3306)
④ cache       Redis のコンテナをビルドして起動する(:6379)
⑤ app         アプリのコンテナをビルドして起動する(:80)  約5分
⑥ 確認(手動)  curl で「成功」と返るか、自分で確認する

MySQL は初回起動が遅いので、「失敗」なら30秒待って再実行
```

**[話す]** 前のページのスクリプトは、①〜⑤を上から順にやっているだけです。
③〜⑤は、各コンテナを `docker build` して `docker run` しているだけで、第3回までにやった操作と同じです。
⑥の確認はスクリプトに含めず、手で `curl` を実行します。MySQLは初回起動が遅いので、「失敗」と出たら30秒ほど待ってもう一度実行します。
スクリプトの中身は、`gcp/lesson4/1. web/setup_local.sh` で読めます。

> **参考(スクリプトの②〜⑤を手で打つ場合)**:
>
> ```bash
> docker network create app-nw
> docker build --pull --no-cache -t db:0.1 -f ./dockerfile_mysql . && docker run -d --network app-nw --name db db:0.1
> docker build --pull --no-cache -t cache:0.1 -f ./dockerfile_redis . && docker run -d --network app-nw --name cache cache:0.1
> docker build --pull --no-cache -t app:0.1 . && docker run -d -p 80:8080 --network app-nw --name app -e DB_HOST=db -e DB_PASS=infra-study -e CACHE_HOST=cache app:0.1
> ```

---

### S16 | 休憩

**[本文]**

```
5分休憩

後半はマネージドサービスに置き換えます
```

---

# 4種類の接続方式

---

### S17 | GCPのマネージドDBはどこにいるのか ★

<!-- slide-id: g016slide -->

**[図版]** **新規作成**。この回の最重要図その1。AWS版との比較。
左にAWS(DBは自分のVPCの中にいる)、右にGCP(DBはGoogle側にいる)を並べる。
GCPは、自分のVPCの VM から Google の VPC(Cloud SQL / Memorystore)と Google API(Spanner / BigQuery)へ矢印を引き、
矢印には ①ピアリング・③PSC・②API経由 の番号を付ける。④Auth Proxy は図に描かず、図の下の凡例で示す。
凡例は4行で、③の行だけ薄い黄色で「今日はこれ」と示す。
左下の黄色い枠で、「Spannerが繋がらない」と「Cloud SQLが繋がらない」は原因が全く違うことを伝える。

**[本文]**

```text
AWS  DBは自分のVPCの中にいる
  自分の VPC > private subnet > EC2 / RDS / ElastiCache
  ENIを作ってサブネットに入ってくる
  サブネットグループ + SGで制御

GCP  DBはGoogle側にいる。繋ぎ方は4種類
  自分の VPC > VM
    ① ピアリング / ③ PSC  → Google の VPC(Cloud SQL / Memorystore)
    ② API経由             → Google API(Spanner / BigQuery)

  ① VPCピアリング … Cloud SQL / Memorystore(旧方式)
  ② Google API 経由 … Spanner / BigQuery(IPもポートも無い)
  ③ Private Service Connect … Cloud SQL / Memorystore  ← 今日はこれ
  ④ Auth Proxy … Cloud SQL の別解。今日は使わない

★「Spannerが繋がらない」と「Cloud SQLが繋がらない」は原因が全く違う
```

**[話す]** ここが今日一番大事なところ。
「Spannerを作ったのにVMから繋がらない」と「Cloud SQLを作ったのに繋がらない」は
原因が全く違う。

AWSは、RDSもElastiCacheも、自分のVPCのサブネットにENIを作って入ってくる。
置き場所はサブネットグループで指定し、通信はセキュリティグループで制御する。
GCPは、DBが自分のVPCの外(Google側)にいて、繋ぎ方が4種類ある。どれを使うかで、必要な準備が全く変わる。

- ① VPCピアリング: Cloud SQL / Memorystore。Googleが管理する別VPCとピアリングを張る(= 限定公開サービスアクセス)。旧方式。今日は使わないが、一部のサービスは今もこちらしか使えない。
- ② Google API 経由: Spanner / BigQuery / Cloud Storage。IPもポートも無く、APIを叩く。第2回でやった Private Google Access で届く。
- ③ Private Service Connect: Cloud SQL / Memorystore(①の後継)。自分のVPCの中にエンドポイントIPを1つ立てて、そこ宛に繋ぐ。★ 社内では今こちらが主流。今日のハンズオンはこれ(S19〜S20で詳しく)。
- ④ Auth Proxy: Cloud SQL の別解。プロキシを立てて繋ぐ。今日は使わない。

①と③は「同じものへの2つの繋ぎ方」。今日は主流の③から仕組みを見て実際に作り、①は旧方式として、一部まだ必要な場面だけ押さえる。

---

### S18 | ② Google API 経由(Spanner)

<!-- slide-id: g017slide -->

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

### S19 | ③ PSC

<!-- slide-id: x0420bslide -->

**[図版]** **新規作成**。③を主役にした左右比較。
左に「③ PSC」、右に「① VPCピアリング(旧方式)」。
左は自分のVPCの中に、private サブネット・エンドポイント(IP 1つだけ)・サービス接続ポリシー(エンドポイントを自動で作る許可)を縦に並べる。
右は同じ並びで、貸出レンジと「/16 推奨」の注記を置き、GoogleのVPCとの間に太いピアリングの線を引く。
下の帯に「IPレンジの設計が要らない。社内でも今こちらが主流。① は一部まだ必要(次のページ)」を置く。

```
   ③ Private Service Connect          ① VPCピアリング

  ┌─ 自分のVPC ──────┐          ┌─ 自分のVPC ──────┐
  │ private 172.16.10.0/24 │          │ private 172.16.10.0/24 │
  │ エンドポイント 172.16.10.4 │          │ 貸出   172.16.192.0/20 │
  │ サービス接続ポリシー      │          │ /16 推奨。小さいと詰む   │
  └──────┬────────┘          └──────┬────────┘
      PSC(この1点だけ)                   ピアリング(VPC全体がつながる)
  ┌──────┴────────┐          ┌──────┴────────┐
  │ Google のVPC           │          │ Google のVPC           │
  │  [Memorystore]         │          │  [Cloud SQL]           │
  └─────────────────┘          └─────────────────┘
```

**[本文]**

```
◼③ Private Service Connect(今日はこれ)

  自分のVPCの中に「エンドポイント」(内部IPを1つ)を立てる
  そのIPに向かって接続する

  貸し出すのはIP 1つ分だけ。IPレンジの設計が要らない
  エンドポイントは、サービス接続ポリシーがあると自動で作られる
  別VPCや別プロジェクトからも、それぞれエンドポイントを立てれば届く

◼① VPCピアリング(旧方式)との違い

  VPC全体がGoogleのVPCとつながる
  IPレンジを丸ごと貸し出す(/16 推奨。小さいと次のサービスが作れない)
  ピアリングは推移しない
    → Shared VPC や 別VPCから使いたいときに詰む
  ※ ① は次のページで説明する。一部のサービスは、今もこちらでしか繋げない

★ Cloud SQL は、公式が ③ を推奨しています(新規は ③ が既定)
★ Cloud SQL / AlloyDB / Memorystore のほか、
   サードパーティのSaaSにも同じ仕組みで繋げます
★ AWSでいうと ③ が PrivateLink、① が VPCピアリングに近い関係です
```

**[話す]** 先にこちらを説明する。いま主流の繋ぎ方で、今日のハンズオンもこれ。
自分のVPCの中にIPを1つ立てるだけで、IPレンジの設計が要らない。
AWS経験者には「PrivateLinkと同じ発想」と言うのが一番早い。
VPCピアリングとPrivateLinkの使い分けを知っている人なら、そのまま理解できる。
右の旧方式(①)は次のページで説明する。
「こういう方式もあって、一部のサービスはまだこちらでしか繋げない」と予告しておく。

> **なぜハンズオンを PSC にしたのか**: Cloud SQL では、公式が PSC を推奨していて、
> 新規は PSC が既定になっている。Memorystore も、Valkey は PSC でしか繋げない。
> 実務で使う形を手で作るほうが、今日の学びが実務に直結する。
> (以前は ① でやっていたが、2026-11-17 に PSC + Valkey に切り替えた)

---

### S20 | ① VPCピアリング(旧方式。一部はまだ必要)

<!-- slide-id: g018slide -->

**[図版]** **新規作成**。この回の最重要図その2。レンジの貸し出しを描く。
前のページの PSC と比べるための、旧方式の図であることが分かるようにする。
下に黄色い枠を置き、今も ① でしか繋げないサービスを書く。

**[本文]**

```
◼① VPCピアリングは旧方式(今日は使いません。ただし一部はまだ必要)
  ※ 正式名は「限定公開サービスアクセス」(PSA)。資料や画面では、この名前で出てくることもある

Cloud SQL と Memorystore は「Googleが管理するVPC」にいる
自分のVPCとは別ネットワークなので、そのままでは繋がらない
→ 自分のVPCからIPレンジを1つ貸し出して、ピアリングを張る

  自分のVPC 172.16.0.0/16
    ├ public   172.16.0.0/24     ← 第2回
    ├ private  172.16.10.0/24    ← 第2回
    └ 172.16.192.0/20            ← Googleに貸し出す

  Cloud SQL / Memorystore のIPはこのレンジから払い出される

★ 貸し出すレンジは他のサブネットと重複できない
   第2回でCIDR設計をした理由がここで効いてきます

★★ レンジは大きめに取る必要があります ★★
   サービスごとにこのレンジからブロックを切り出して使うため、
   /24 だと途中で埋まり、Cloud SQL の作成が失敗します

     Couldn't find free blocks in allocated IP ranges.
     Please allocate new ranges for this service provider.

   Googleは /16 を推奨

★ 今も ① でしか繋げないサービスがある
   Memorystore for Redis(標準) / Memcached
   新規の Cloud SQL は ③ PSC が推奨(今日の実習も ③)
※ ① の正式名は「限定公開サービスアクセス」(PSA)。中身は VPC ピアリング
```

> **検証済み(2026-08-28)**: 最初 `/24` で作ったところ、
> Memorystore は作れたが Cloud SQL が上記エラーで失敗した。
> `/20` に変更して解決。
> (この検証は、以前の手順の限定公開サービスアクセス + Memorystore for Redis で行った)

> **★ さらに注意**: Cloud SQL の作成に失敗すると、
> インスタンスは `state: FAILED` の状態で残る。
> Terraformのstateには入らないので、次のapplyは
> `The Cloud SQL instance already exists` で失敗する。
> `gcloud sql instances delete` で消してから再実行すること。

**[話す]** PSC を先に見たので、ここでは「もう1つ、こういう方式もある」と見せる。ハンズオンでは作らない。
実務では、古いドキュメントやすでに動いているシステムで必ず出てくる。
Memorystore for Redis(標準)や Memcached のように、今も ① でしか繋げないサービスもあるので、
**レンジを丸ごと貸し出す仕組みだった**ことを押さえてもらう。

---

### S22 | Memorystore とは

<!-- slide-id: g021slide -->

**[図版]** AWS版 第5回「Amazon ElastiCache」のスライドを流用。用語を差し替え。
Memorystore の種類(4つ)と接続方式の対応をテキストで並べ、続けて Valkey が Redis から派生した経緯と優位点を載せる。

**[本文]**

```
◼Memorystore は4種類ある
  Redis (standard)  … VPCピアリング か ダイレクトピアリング
  Redis Cluster     … PSC
  Valkey            … PSC のみ
  Memcached         … VPCピアリング

◼Memorystore for Valkey
  Valkey は Redis から派生。Redis と同じ方法で繋がる。今日は最新の 9.1

◼なぜ Redis から派生したのか
  2024年3月、Redis のライセンスが BSD から変わった(OSS ではなくなった)
  → Linux Foundation の下で、BSD のまま Valkey として引き継いだ

◼Valkey の優位点(Google の発表)
  ・Redis Cluster の最大2倍の QPS。メモリ効率も改善(Valkey 8.0 の発表値)
  ・価格は Redis Cluster と同水準。性能が高い分、ノードを減らせる可能性
  ・Linux Foundation 運営の OSS(BSD)なので、特定企業の都合でライセンスが変わりにくい
```

**[話す]** 標準の Redis(クラスタ無し)は PSC に対応していないので、今日は使わない。
「PSC で繋ぐなら Valkey か Redis Cluster」と覚えてもらう。
今日は `mode = CLUSTER_DISABLED`(シャード1つ)なので、アプリは今までどおり `redis.Dial` で繋がる。

**バージョン**: Memorystore for Valkey は 7.2 / 8.0 / 9.0 / 9.1 から選べて、指定しなければ最新の 9.1 になる(2026-11-18 に公式で確認)。
今日は最新の 9.1 を指定している。**一度上げると、前の版には戻せない**。
以前は 8.0 を指定していたが、8.0 にする強い理由はなかったので、9.1 に揃えた。

**派生した経緯**: 2024年3月に、Redis を作っている Redis Ltd. が、ライセンスを BSD から
RSALv2 / SSPLv1(ソースは見られるが、OSS ではない)に変えた。
直後に Linux Foundation が、BSD のまま続ける新しいプロジェクトとして Valkey を発表した。
Alibaba・Amazon・Ericsson・Google・Huawei・Tencent の開発者が立ち上げている。
Redis という名前は Redis Ltd. が商標を持っているので、別の名前になった。
Memorystore を提供する Google も、立ち上げに加わった側。

**優位点**: 数字はどれも Google の発表値で、第三者の測定ではない。
Memorystore for Valkey 8.0 の発表では、Memorystore for Redis Cluster の最大2倍の QPS、1キーあたりのメモリを16バイト減らした、と説明されている(今日の 9.1 の数字ではない)。
価格は Redis Cluster と同水準なので、同じ負荷ならノードを減らせて、結果として安くなる可能性がある、という言い方。
今日の `SHARED_CORE_NANO`(最小サイズ)では、この差は体感できない。
「Redis と同じ方法で繋がる(Redis OSS 7.2 の API と互換)」ので、アプリは変えずに移れる点も大きい。

> **出典(2026-11-18 に確認)**:
> - Valkey の経緯: https://valkey.io/topics/history/(ライセンス変更の月は Google の GA 記事に「March 2024」とある)
> - 優位点: https://cloud.google.com/blog/products/databases/announcing-general-availability-of-memorystore-for-valkey/ (GA は 2025-04-19)
>   https://cloud.google.com/blog/products/databases/memorystore-launches-valkey-8-0-on-google-cloud (2x QPS・16バイト減)
> - Valkey のページには、Redis の何版から派生したかの記載が無いので、スライドには版を書いていない。
> - 対応バージョン: https://docs.cloud.google.com/memorystore/docs/valkey/supported-versions (7.2 / 8.0 / 9.0 / 9.1、既定は 9.1。9.1 の更新日は 2026-07-27。ノードタイプ別の対応は記載なし)

---

### S23 | Terraform コード(Memorystore)

<!-- slide-id: g022slide -->

**[本文]**

```
cd ~/works/lesson4 && cp -rf ~/infra-study/gcp/lesson4/"2. cache" ./
cd "2. cache"
python3 ~/infra-study/gcp/tools/configure.py

参照: 2. cache/cache.tf

resource "google_memorystore_instance" "cache" {
  instance_id = "${var.user_name}-cache"
  location    = "asia-northeast1"

  mode          = "CLUSTER_DISABLED"   ← シャード1つ。Redis と同じ使い方
  shard_count   = 1
  replica_count = 0                    ← 0: 1ノード / 1以上: レプリカ付き

  node_type      = "SHARED_CORE_NANO"  ← 勉強会用の最小サイズ
  engine_version = "VALKEY_9_1"

  engine_configs = { maxmemory-policy = "allkeys-lru" }

  desired_auto_created_endpoints {     ← PSCのエンドポイントを自動で作る
    network    = google_compute_network.vpc.id
    project_id = var.project_id
  }

  depends_on = [google_network_connectivity_service_connection_policy.memorystore]
}

★ depends_on を書く理由
   ポリシーが先にないと、エンドポイントを作れずに失敗します
   Terraformは参照関係から順序を推測しますが、ここは参照がないので明示します
```

---

### S24 | Step2 実行

<!-- slide-id: g023slide -->

**[本文]**

```
  terraform init
  terraform plan
  terraform apply

★ Memorystoreの作成には5分前後かかります
   待っている間に Spanner の話に進みます(S26へ)

◼確認
  terraform output cache_host
  → 172.16.10.x
```

> **検証済み(2026-11-17)**: サービス接続ポリシー + Memorystore for Valkey で、
> Memorystore の作成に 5分13秒(ポリシーは12秒)。これは `VALKEY_8_0` での計測。
> `VALKEY_9_1` + `SHARED_CORE_NANO` でも作成できることを 2026-11-18 に確認した(作成 6分5秒、ポリシー12秒)。
> 6分5秒は1回の計測で、8.0 との差が版の違いによるものかは分からない。
> cache_host は private サブネット(172.16.10.0/24)から払い出される(172.16.10.3 や .4)。
> プライマリとリーダーのどちらが先の番号になるかは決まっていないので、
> `connection_type` で選んでいる(検証では順番が逆になることもあった)。
> `replica_count = 0` で新規に作ったときも、リーダーエンドポイントは作られた(Cloud Shell で確認)。

---

### S25 | アプリの接続先を切り替える

<!-- slide-id: g024slide -->

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
   自分のVPCから外へ出る通信(送信)は、既定で許可されているからです
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
cd ~/works/lesson4 && cp -rf ~/infra-study/gcp/lesson4/"3. spanner" ./
cd "3. spanner"
python3 ~/infra-study/gcp/tools/configure.py

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
  member   = "serviceAccount:${google_service_account.web.email}"
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

**[話す]** 第1回の宿題2で「Secret Manager の値を tfstate に残さずに入れるには」を
考えてもらった。Spannerでは、そもそも秘密が発生しない。
これがマネージドサービスをIAMで統一することの利点。

---

### S34 | Step3 実行

**[本文]**

```
  terraform init
  terraform plan
  terraform apply

★ Spannerの作成は1〜2分で終わります
   Cloud SQL(15分)や Memorystore(5分)よりずっと速い

◼確認
  terraform output spanner_database
  → projects/xxx/instances/yyy-spanner/databases/test-db

  gcloud spanner instances list
  gcloud spanner databases ddl describe test-db --instance=[自分の名前]-spanner
```

> **検証済み(2026-08-28)**: インスタンス + データベース + IAM で 1分6秒。
> インターリーブを含むDDLもそのまま通った。

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

  AWSで作るもの(6リソース)
    セキュリティグループ / DBサブネットグループ /
    パラメータグループ / クラスターパラメータグループ /
    RDSクラスター / RDSクラスターインスタンス × 2

  GCP(3リソース)
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

◼直書きするとこうなる
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

◼値は環境変数から渡す(ephemeral な変数)
  read -rs TF_VAR_db_password
  export TF_VAR_db_password
  terraform apply

◼変数には default = "" を書いておく(destroy で値を聞かれない)
  空のまま apply しないよう precondition で止める

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

**[話す]** destroy のときに値を聞かれるのは、変数に default が無いから。
消すだけなのにパスワードを打たせるのは筋が悪いので `default = ""` にしてある。
ただしそのままだと、渡し忘れたときに**パスワード無しのユーザー**ができてしまう
(Cloud SQL は空のパスワードを受け付ける。Secret Manager は空の値を弾くので事情が違う)。
だから `precondition` で apply の前に止めている。destroy のときは評価されないので値なしで消せる。

---

### S44 | Cloud SQL は宿題で作ります

<!-- slide-id: g043slide -->

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

★ サービス接続ポリシー(今日作ったもの)をそのまま使い回します
   Cloud SQL 用のポリシーだけ、宿題で1つ足します
★ password_wo が本当に tfstate に残らないかも確認してみてください
```

---

# まとめ

---

### S45 | 本日のまとめ ①

<!-- slide-id: g044slide -->

**[図版]** AWS版 第5回「本日のまとめ」のレイアウトを流用。

**[本文]**

```
◼GCPのマネージドDBは接続方式が4種類ある

  Google API 経由    Spanner / BigQuery
                     Private Google Access があれば届く
                     IPもポートもパスワードも無い

  PSC(今日使った)  Cloud SQL / Memorystore
                     エンドポイントIPを1つ立てて繋ぐ
                     サービス接続ポリシーで作成を許可する
                     Firewall Rules は不要
                     社内では今こちらが主流

  VPCピアリング       Cloud SQL / Memorystore(旧方式)
                     限定公開サービスアクセスの設定が必要
                     Valkey は選べない

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

<!-- slide-id: g046slide -->

**[本文]**

```
◼Memorystore
ElastiCacheの4リソースが1リソースになる
Memorystore for Valkey を PSC で繋ぐ
replica_count = 0 は1ノード、1以上でフェイルオーバーあり
標準の Redis は PSC に対応していないので使わない

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

<!-- slide-id: g049slide -->

**[本文]**

```
◼1. Memorystore にレプリカを追加しよう

  replica_count を 0 → 1 にして apply する
  読み取り専用のエンドポイントが使えるようになる
  そこに書き込むとどうなるか試してみる

◼2. Spanner のインターリーブを体験しよう

  users と orders にデータを入れてJOINしてみる
  親を消すと子も消えることを確認する

  回答例: gcp/lesson4/syukudai1/


◼3. Cloud SQL を作って繋いでみよう(講義でやらなかった分)

  Cloud SQL(REGIONAL)を作る
  アプリを Cloud SQL に向ける
  PSC のエンドポイントIPをアプリに渡す(private_ip_address は空になる)
  password_wo が tfstate に残らないことを確認する
  フェイルオーバーを起こして復旧時間を測る

  ★ 作成に7〜10分かかります。時間のあるときにやってください

  回答例: gcp/lesson4/syukudai2/

★ 次回(12/24)まで14日ありますが年末なので、宿題は軽めにしています
```

---

### S51 | 宿題3 調べ物

<!-- slide-id: g050slide, p3_4_g050bdy_1 -->

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
  Memorystore for Valkey
    https://cloud.google.com/memorystore/docs/valkey
  Private Service Connect
    https://cloud.google.com/vpc/docs/private-service-connect
```

---

### S52 | 注意事項

<!-- slide-id: g051slide -->

**[図版]** AWS版「注意事項」スライドを流用。

**[本文]**

```
宿題などで作成したリソースは必ず削除してください！

◼リソースの削除(最後に apply したディレクトリで実行)
  cd ~/works/lesson4/syukudai2       ← 実装課題3まで
  cd ~/works/lesson4/syukudai1       ← 実装課題1・2まで
  cd ~/works/lesson4/"3. spanner"    ← 講義 Step3 まで

  terraform destroy   → 確認で yes と入力

★★ この回は課金が大きいです ★★
   Spanner(100 PU)      無料枠なし。今日の中で一番高い
   Cloud SQL (REGIONAL)  2ゾーン分
   Memorystore (Valkey)  レプリカを付けると、その分も

★ destroy にも時間がかかります(1回で終わります)
   Memorystore の削除に約8〜10分、Cloud SQL に約2分
   時間に余裕を持って実行してください

★ deletion_protection / force_destroy の設定を確認
   本番では逆にする(消せないようにする)設定です

★ tfstate用のバケットは残しておいてください
```

**[話す]** PSC は、ピアリングのときのような「1回目の destroy が失敗する」問題が無い。
1回で終わる(実機で確認済み。付録A-2)。ただし Memorystore の削除は8分ほどかかる。
S52b(旧「注意事項(続き)」)は、この説明が不要になったので欠番にした。

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
| 2 | `2. cache/` | サービス接続ポリシー(PSC) + Memorystore for Valkey | **Firewall Ruleなしで繋がる** |
| 3 | `3. spanner/` | Spanner インスタンス/DB/IAM | **パスワードなしで繋がる** |

宿題:

| 宿題 | ディレクトリ | 内容 |
|---|---|---|
| 2-1,2-2 | `syukudai1/` | Memorystore レプリカ(`replica_count = 1`) + Spanner インターリーブ |
| 2-3 | `syukudai2/` | Cloud SQL(PSC)の構築とフェイルオーバー計測 |
| 3-2 | `syukudai3/` | Spanner のレプリケーション(調べ物のみ) |

AWS版 第5回との対応:

| AWS版 | GCP版 | 備考 |
|---|---|---|
| 0. before | 0. before | 23リソース |
| 1. web | 1. web | 設定を環境変数化。ビルドし直しが不要に |
| 2. cache | 2. cache | **サービス接続ポリシー(PSC)が新規に必要。Redis ではなく Valkey** |
| 3. db (Aurora) | **3. spanner** | **主役を差し替え。AWS版に対応するものが無い** |
| — | syukudai2 | AWS版の 3. db に相当。講義では概説のみ、構築は宿題 |

---

# 付録A-2: destroy の手順

**PSC + Valkey の構成では、`terraform destroy` は1回で終わる。**
当日の最後に案内するのは「宿題で作ったディレクトリで destroy する」ことだけ。

```
terraform destroy
  → Cloud SQL / Memorystore / Spanner が消える
  → サービス接続ポリシー、サブネット、VPC も、同じ1回で消える
```

> **検証済み(2026-11-17)**: VPC + サブネット + サービス接続ポリシー2つ +
> Memorystore for Valkey(レプリカ付き) + Cloud SQL(REGIONAL) + VM を
> `terraform destroy` した。**1回で成功**(エラー無し、手動削除も不要)。
>
> | 削除したもの | 所要時間 |
> |---|---|
> | Memorystore for Valkey | 8.0 で7分53秒(Cloud Shell では9分56秒)。9.1 は Cloud Shell で11分48秒(2026-11-18) |
> | Cloud SQL(REGIONAL) | 1分52秒 |
> | サービス接続ポリシー(各) | 約11秒 |
> | サブネット / VPC | 22秒 / 33秒 |

**なぜ1回で終わるのか**

PSC のエンドポイント(転送ルール)は、Memorystore / Cloud SQL を消すと
一緒に消える。ポリシーはその後に消せる。
限定公開サービスアクセスのように、Google側が接続を握り続けることがない。

**旧方式(限定公開サービスアクセス)の場合**(2026-08-28 に検証。今は使わない)

`google_service_networking_connection` の削除が
`Producer services (e.g. CloudSQL, Cloud Memstore, etc.) are still using this connection`
で失敗し、**待っても解決しなかった**(12分・6回リトライ)。
`gcloud compute networks peerings delete servicenetworking-googleapis-com` で
ピアリングを直接消してから、もう一度 destroy する必要があった。
これが無くなったのは、PSC に切り替えた利点の1つ。

---

# 付録B: 制作メモ / 要確認事項

## PSC + Memorystore for Valkey への切り替え(2026-11-17)

講義のハンズオンを「限定公開サービスアクセス + Memorystore for Redis」から
「**PSC(サービス接続ポリシー) + Memorystore for Valkey**」に変更した。

**変更した理由**

- 社内では Valkey を使っている。実務に近い構成で実習したい
- Google は Cloud SQL について PSC を推奨している(新規プロジェクトの既定も PSC)
- Memorystore for Valkey は PSC でしか繋げない。標準の Redis は PSC に対応していないので、
  PSC で揃えるなら Valkey にするしかない

**実環境で確認したこと**(共有プロジェクト。確認用のリソースは全て削除済み)

| 項目 | 結果 |
|---|---|
| サービス接続ポリシー(`gcp-memorystore`) | OK。12秒 |
| Memorystore for Valkey(`CLUSTER_DISABLED`、`SHARED_CORE_NANO`) | OK。8.0 で5分13秒、9.1 で6分5秒(2026-11-18 に9.1も確認) |
| VM から PSC エンドポイントへ接続 | OK。**Firewall Rule は IAP 用の ingress だけで届いた**(egress は既定で許可) |
| リーダーエンドポイントへの書き込み(`replica_count = 1`) | `-READONLY You can't write against a read only replica.` |
| リーダーエンドポイント(`replica_count = 0`) | `-ERR no replicas found`。**新規作成した直後から存在する**(Cloud Shell で確認。プライマリは PONG) |
| `replica_count` の 0 → 1 変更 | **in-place**。約3分25秒 |
| `replica_count` の 1 → 0 変更 | **in-place**。約30〜40秒 |
| `engine_configs` の追加 | in-place(上と同時に適用して確認) |
| Cloud SQL(REGIONAL、PSC) | OK。7分0秒。PSC エンドポイントのIPで MySQL 8.4.11 のバナーを確認 |
| Cloud SQL の接続先IP | `private_ip_address` は**空**。`settings[0].ip_configuration[0].psc_config[0].psc_auto_connections[0].ip_address` に入る |
| destroy | **1回で成功**(付録A-2)。Cloud Shell でも `-parallelism=2` で1回(25リソース、11分33秒。Valkey の削除は9分56秒) |
| `terraform validate`(PSC / Valkey を含む32ディレクトリ。terraform 1.17.2 で `required_version` を緩めずに実行) | 全て成功 |
| Cloud Shell(terraform 1.17.1、`-parallelism=2`)で `2. cache` を apply | OK。25リソース。Valkey の作成は5分15秒 |

**確認していないこと**

- 受講者相当のサービスアカウントでの実行。権限は、Editor のロール定義に
  `memorystore.instances.*` と `networkconnectivity.serviceConnectionPolicies.*`
  が含まれることを確認しただけ(実行は講師アカウント)。
  **`roles/servicenetworking.networksAdmin` が要らなくなったかどうかも、これで初めて分かる**
  (2026-11-17 に、検証用SAへのロール付与が自動の権限判定で止められたため未実施)
- Cloud Shell で実行したのは `2. cache` まで。`syukudai2`(Cloud SQL の PSC)は講師のPCでだけ実行した

## 以前の構成(限定公開サービスアクセス)での動作確認: 完了(2026-08-28)

> 以下は旧構成での結果。講義の構成は上のとおり PSC + Valkey に変わっている。

Step0〜3 と Cloud SQL(宿題2相当)を通しで apply → destroy 済み。
`terraform validate` は全6ディレクトリで成功(google provider 8.0.0)。

| 項目 | 結果 |
|---|---|
| `0. before`(23リソース) | OK。4分48秒 |
| 限定公開サービスアクセス + Memorystore for Redis | OK。6分5秒。IPは貸出レンジから払い出された |
| Spanner(インターリーブDDL含む) | OK。**1分6秒**。Cloud SQLよりずっと速い |
| **外部IPなしVMから Spanner へ到達** | **OK**。Private Google Access のみで届いた |
| **Spanner の IAM** | **OK**。DB単位の `roles/spanner.databaseUser` だけで足りた |
| **go-sql-spanner でのビルドと接続** | **OK**。`DB接続(Spanner): 成功` |
| Spanner + Memorystore 同時接続 | OK |
| Cloud SQL(REGIONAL) | OK。9分28秒。プライマリ 1-a / セカンダリ 1-c |
| **`password_wo` が tfstate に残らない** | **OK**。`password: None` のみ。実値の grep は0件 |
| destroy | ピアリング削除に回避策が必要(付録A-2。PSC では不要) |

### 見つけて修正したバグ

**1. 貸し出しレンジが `/24` では足りない**(限定公開サービスアクセスの話。PSC ではレンジの貸し出し自体が無い)

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

**3. destroy が待っても終わらない**(限定公開サービスアクセスの話。PSC では1回で終わる)

付録A-2 に記載。12分・6回リトライしても解決せず、
`gcloud compute networks peerings delete` が必要だった。

### 受講者相当の権限での検証(2026-08-28 実施)

第1回 付録A の9ロールだけを持つサービスアカウントになりすまして通した結果、
**第2〜4回の全リソース(34個。Cloud SQL 含む)が作成できた。**

`0. before` に第2回・第3回が積み上がっているため、
**第4回を1本流すだけで過去の回の権限も同時に検証できる。**

ロールは当初の想定より少なくて済んだ(`cloudsql.admin` / `redis.admin` は不要)。

### まだ検証できていないこと
- **Cloud Shell での実行**。第1回〜第4回とも未実施

## 受講者ロールへの追加が必要

第1回 付録Aのロール構成に、この回から次が必要になる。

```
roles/spanner.admin
```

`roles/servicenetworking.networksAdmin` は、PSC に切り替えたので**不要**になった
(第1回の付録Aには、まだ残っている)。
`roles/cloudsql.admin` / `roles/redis.admin` / `roles/memorystore.admin` も**不要**。
作成権限は `roles/editor` に含まれている。

第1回の付録Aは計9ロールで、`roles/servicenetworking.networksAdmin` を含んだまま。外す場合は第1回の側で直す。

## 新規作図が必要なスライド

| スライド | 内容 | 優先度 |
|---|---|---|
| S17 | 4種類の接続方式(AWS/GCP比較) | **最高** |
| S29 | 主キーとスプリット / ホットスポット | **最高** |
| S27 | Aurora / DynamoDB / Spanner の比較表 | 高 |
| S19・S20 | PSC の仕組みと限定公開サービスアクセスの仕組み | 高 |
| S04-2 | ゴール構成図(接続経路が2系統。旧 S10) | 高 |
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
- 「4種類の接続方式」は設計書5章の「置換では済まない設計判断」に
  追加すべき項目。第5回(Cloud Run)でも接続方式の話が出てくる
