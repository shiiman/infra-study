# 第1回 インフラ勉強会(GCP) — GCP基礎 / IAM / Terraform

- **開催日**: 2026-10-05(月) 2時間
- **AWS版対応**: 第1回(インフラ基礎) + 第2回(Terraform) を1回に圧縮
- **Terraformコード**: `gcp/lesson1/`
- **ゴール**: Cloud Shell から `terraform apply` が通り、GCSバックエンドに tfstate が保存される

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入 | 8分 | S01〜S07 |
| インフラ基礎の要点 | 15分 | S08〜S15 |
| GCPについて | 17分 | S16〜S23 |
| Cloud IAM | 22分 | S24〜S34 |
| 休憩 | 5分 | S35 |
| Cloud Shell + Terraformインストール | 12分 | S36〜S39 |
| Terraform | 13分 | S40〜S49 |
| ハンズオン | 22分 | S50〜S60 |
| まとめ・宿題 | 5分 | S61〜S68 |

> 押した場合の削り所: S17(リソースカテゴリ一覧)と S46(data/module ブロック)は口頭のみで飛ばせる。
> S09〜S14 のインフラ基礎は事前配布資料に逃がしてあるので、遅れていれば S15 のおさらいだけでよい。
>
> **S38b(Terraformのインストール)は飛ばせない。** Cloud Shell に Terraform が
> 入っていないため、ここを飛ばすとハンズオンが始まらない。全10回で唯一この回だけ必要な作業。
> 事前に「Cloud Shellを開いてTerraformを入れておいてください」と案内しておくと当日が楽になる。

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない

---

# 導入

---

### S01 | タイトル

**[図版]** AWS版 第1回 表紙を複製。タイトルのみ差し替え。

**[本文]**

```
第1回 インフラ勉強会(GCP)

〜 GCP基礎 / IAM / Terraform 〜

2026年10月5日
```

---

### S02 | ロードマップ

**[図版]** AWS版 第2回「インフラ勉強会 スケジュール」の2カラムレイアウトを流用。
中身を全10回に差し替え(AWS版は12回だったので行を2つ削る)。

**[本文]**

```
◼ロードマップ(内容は随時変更される可能性あり)

2026年
10月05日  GCP基礎 / IAM / Terraform      ← 今日
10月26日  ネットワーク
11月16日  コンピューティング
12月07日  データベース
12月24日  コンテナ(木曜開催)

2027年
01月18日  ストレージ + CDN
02月08日  CI/CD
03月01日  監視・運用 + その他リソース
03月25日  試験対策(ACE / CDL・木曜開催)
04月12日  実践テスト + 総まとめ

原則3週に1回・月曜・2時間
```

**[話す]** 第5回と第9回は木曜。第5回は年末(12/24)なので、第4回の宿題は控えめにすると先に断っておく。

---

### S03 | なぜGCP勉強会をやるのか

**[図版]** AWS版 第1回「インフラ勉強会の経緯」のテキストスライドを流用。

**[本文]**

```
◼背景
- AWS版に続き、GCPを扱える人を増やしたい
- マルチクラウドが前提の時代になった
- Cloud Run / BigQuery など、GCP側が強い領域がある

◼目的(サーバサイドのスキルアップ)
- GCP基礎
- Terraform(GCP編)

サーバエンジニアが自分でインフラを触れる状態にする
```

---

### S04 | ゴール

**[図版]** AWS版 第1回「インフラ勉強会のゴール」を流用。資格名を差し替え。

**[本文]**

```
◼ゴール(1年後)
Terraformで、HTTPSでアクセスできるコンテナWebアプリ一式を
自力で構築し、CI/CDと監視まで設定できる

  Cloud Load Balancing + Cloud Run + Cloud SQL
  + Memorystore + Cloud Storage/CDN

◼Google Cloud 認定資格
Associate Cloud Engineer (ACE)    ← 本命
Cloud Digital Leader (CDL)        ← 入門枠
```

**[話す]** AWS版は Cloud Practitioner と Developer-Associate の2本立てだった。
GCPも同じく2本立てにする。第9回(3/25)で試験対策をやって、その場で申込みまで済ませる。

---

### S05 | 対象者

**[図版]** AWS版 第1回「インフラ勉強会 対象者」を流用。

**[本文]**

```
◼対象者
社員サーバエンジニア(全員)

GCP未経験を前提にゼロから進めます
AWS版に出ていた人は「AWSとの違い」に注目して聞いてください
```

> **未決**: 対象者の確定(設計書 10章)。開催前に確定させてこのスライドを直す。

---

### S06 | 自己紹介

**[図版]** AWS版 第1回「インフラ(SRE)になるまでの道のり」3枚をそのまま流用。
経歴の年数を2026年時点に更新するだけでよい。

---

### S07 | 今日のアジェンダ

**[本文]**

```
インフラ基礎(要点のみ)
  WANとLAN / IPアドレス / ポート / ドメイン / SSL証明書

GCPについて
  なぜGCPか / 料金体系 / 組織-フォルダ-プロジェクト
  リージョンとゾーン / 割り当て(Quota)

Cloud IAM
  プリンシパル / ロール / ポリシー / サービスアカウント

Cloud Shell

Terraform
  構成言語(HCL) / CLI / tfstate

ハンズオン
```

**[話す]** AWS版では「インフラ基礎」と「Terraform」で2回分使った。
今回はGCP側に時間を使いたいので1回に圧縮している。その分ペースが速い。

---

# インフラ基礎の要点

---

### S08 | インフラ基礎は事前配布資料で

**[本文]**

```
◼インフラ基礎は自習資料にしました

WAN/LAN、IPアドレス、ポート、DNS、SSL証明書は
GCPでもAWSでも同じ話なので、事前配布資料にまとめてあります

ここでは要点だけ15分で流します
「これ説明できないな」と思ったものがあれば、
資料を読み直してください
```

> **制作TODO**: 事前配布資料は AWS版 第1回スライドをそのままPDF化して配る。
> ページはS09〜S14に対応する範囲(「ネットワーク」〜「SSL証明書」)。

---

### S09 | WANとLAN

**[図版]** AWS版 第1回「ネットワーク」のWAN/LAN図をそのまま流用。差し替え不要。

**[本文]**

```
◼WAN  Wide Area Network   → インターネット
◼LAN  Local Area Network  → 社内ネットワーク

インフラとして構築するのはLAN
そしてWANへの入口(出口)を考えてあげる

→ 次回、GCPでこのLANを作ります
```

---

### S10 | IPアドレス

**[図版]** AWS版 第1回「IPアドレス」3枚を流用。差し替え不要。

**[本文]**

```
◼パブリックIP(外部IP、グローバルIP)
WANで使用されるIP(世界に同じものは1つしかない)

◼プライベートIP(内部IP、ローカルIP)
LANで使用されるIP(外の世界からは特定不可)

なぜ全部パブリックIPにしないのか
- IPv4のアドレスが枯渇している(約43億個しかない)
- IPが特定されると攻撃される
```

---

### S11 | CIDRとサブネットマスク

**[図版]** AWS版 第1回「IPアドレス」のIPクラス表 + `192.168.0.1/24` の分解図を流用。

**[本文]**

```
172.16.0.0/16
         ↑
      ネットワーク部が16bit、残り16bitがホスト部

/16 → 約65,000個
/24 → 254個

この勉強会では 172.16.0.0/16 を使います
```

**[話す]** GCPのサブネットは4つのIPが予約される(ネットワークアドレス、
デフォルトゲートウェイ、末尾2つ)。AWSは5つ予約だった。細かいが/28みたいな
小さいレンジを切るときに効いてくる。

---

### S12 | ポート番号

**[図版]** AWS版 第1回「ポート番号」を流用。差し替え不要。

**[本文]**

```
◼ポート番号
コンピュータが通信に使用するプログラムを識別するための番号

22   SSH
80   HTTP
443  HTTPS
3306 MySQL
6379 Redis
```

---

### S13 | ドメインとDNS

**[図版]** AWS版 第1回「ドメイン」を流用。`Cloud DNS` の記載はそのまま使える
(AWS版のスライドに既に Cloud DNS と書かれている)。

**[本文]**

```
◼ドメイン
IPアドレスでは人間が識別しにくいので、
意味のある文字列を対応させたもの

DNS (Domain Name System)
GCPでは Cloud DNS   (AWSでは Route 53)
```

---

### S14 | SSL/TLS証明書

**[図版]** AWS版 第1回「SSL証明書」の通信シーケンス図を流用。差し替え不要。

**[本文]**

```
◼SSL/TLS証明書
通信の暗号化 + 通信相手が本物であることの証明

GCPでは Googleマネージド SSL証明書 / Certificate Manager

ワンポイント
AWSではCloudFront用のACM証明書を
「us-east-1で作らないといけない」という罠があった
GCPにはこの制約がない
```

**[話す]** ここは第3回でHTTPS化するときに実際に使う。今は「証明書は自動で取れる」
とだけ覚えておけばよい。

---

### S15 | ここまでのおさらい

**[本文]**

```
ネットワークにはWANとLANがある
ネットワーク内の住所がIPアドレス。パブリックとプライベートがある
CIDRを意識してネットワーク設計をする
ポートが分かればプログラムが分かる
IPアドレスを人間に分かるように変換するのがDNS
ブラウザ通信のセキュリティを担保するのがSSL/TLS証明書
```

---

# GCPについて

---

### S16 | なぜGCPか

**[図版]** 新規。3カラムで「Googleと同じインフラ」「データ分析」「コンテナ」のアイコン。

**[本文]**

```
◼GCPの特徴

Googleと同じインフラを使える
  Google検索・YouTubeを支えるネットワークがそのまま使える
  ネットワークが速い(Googleのバックボーンを通る)

データ分析が強い
  BigQuery

コンテナが強い
  Kubernetesの生まれた会社
  Cloud Run はサーバレスコンテナの完成形に近い

料金が分かりやすい
  自動で適用される割引がある(継続利用割引)
```

**[話す]** AWS版では「AWSが選ばれる10の理由」を10枚使って説明した。
GCPは「Googleのインフラをそのまま借りる」の一言でだいたい説明がつくので圧縮する。
どちらが優れているという話ではなく、得意領域が違うという理解でよい。

---

### S17 | GCPのリソースカテゴリ

**[図版]** AWS版 第2回「AWSリソース」4枚のレイアウトを流用し、GCPのサービス名に差し替え。
カテゴリ数はAWS版の11から8に減らす。

**[本文]**

```
コンピューティング       Compute Engine / Cloud Run / GKE / Cloud Run functions
ネットワーク・CDN        VPC / Cloud Load Balancing / Cloud DNS / Cloud CDN / Cloud Armor
ストレージ               Cloud Storage / Persistent Disk / Filestore
データベース             Cloud SQL / AlloyDB / Spanner / Memorystore / Firestore / Bigtable
データ分析               BigQuery / Dataflow / Pub/Sub
CI/CD                    Cloud Build / Artifact Registry / Cloud Deploy
セキュリティ・ID         Cloud IAM / Secret Manager / Cloud KMS / Cloud Armor
運用管理                 Cloud Monitoring / Cloud Logging / Cloud Trace / Error Reporting

カテゴリごとの詳細は次回以降で学びます
今回はTerraformの実行に必要な Cloud IAM だけ
```

**[話す]** ACE試験の出題範囲とほぼ重なる。試験対策のときにこの表に戻ってくる。

---

### S18 | 料金体系

**[本文]**

```
◼従量課金
使った分だけ。Compute Engineは秒単位課金(最低1分)

◼継続利用割引(SUD: Sustained Use Discount)
1ヶ月のうち長く動かすほど自動で安くなる
申請不要。何もしなくても適用される  ← AWSにはない仕組み

◼確約利用割引(CUD: Committed Use Discount)
1年/3年の利用を約束して安くする
AWSのリザーブドインスタンス/Savings Plansに相当

◼無料枠(Always Free)
一部リージョン限定。asia-northeast1(東京)は対象外なので注意
```

**[話す]** SUDが「勝手に安くなる」のはGCPの分かりやすい利点。
一方で無料枠は米国リージョン限定なので、東京で作ると普通に課金される。
今日作るものは数円レベルだが、宿題で作ったリソースは必ず消すこと。

---

### S19 | 組織 - フォルダ - プロジェクト ★重要

**[図版]** **新規作成**。AWS版に相当する図がないので描き起こす。
上から順に 組織 → フォルダ → プロジェクト → リソース の4段ツリー。
右側に「IAMロールは上から下へ継承される」の下向き矢印を添える。

**[本文]**

```
◼GCPのリソース階層

組織 (Organization)
  会社そのもの。Cloud Identity / Google Workspace のドメインに対応
  └ フォルダ (Folder)
      部署・プロダクト・環境などで区切る。入れ子にできる
      └ プロジェクト (Project)
          リソースを入れる箱。課金・APIの有効化・Quotaの単位
          └ リソース (VM / バケット / DB ...)

◼一番のポイント
IAMロールは上の階層から下へ継承される
組織でOwnerを付けたら、全プロジェクトのOwnerになる
```

**[話す]** AWSの Organizations + アカウント に近いが、AWSより階層が扱いやすい。
AWSは「アカウントを分ける」のが基本だったが、GCPは「プロジェクトを分ける」のが基本。
プロジェクトはAWSアカウントよりずっと気軽に作れる。

> **要確認**: この勉強会は会社の Cloud Identity 配下で実施する。
> コンソールの実物(組織 → 勉強会用フォルダ → [プロジェクトID])のスクリーンショットを
> 開催前に撮って差し込むこと。

---

### S20 | プロジェクトと、今回使うプロジェクト

**[本文]**

```
◼プロジェクトが持つ3つの識別子
プロジェクト名     人が読む名前。あとから変更できる
プロジェクトID     GCP全体で一意。作成後に変更できない  ← Terraformで使うのはこれ
プロジェクト番号   自動採番される数値

◼この勉強会で使うプロジェクト

  [プロジェクトID]

★ 全員でこの1つのプロジェクトを共有します

そのため、作るリソースには必ず自分の名前を付けてください
  shiiman-vpc / shiiman-app / [プロジェクトID]-tfstate-shiiman
```

**[話す]** 本来は受講者ごとにプロジェクトを分けたいが、今回は既存の共有プロジェクトを使う。
共有だからこそ気をつけることがあるので、IAMのところで改めて説明する。

---

### S21 | リージョンとゾーン

**[図版]** 新規。左に「リージョン asia-northeast1(東京)」の枠、
中に「ゾーン -a / -b / -c」の3つの箱。
**次回への布石として**、VPCの枠をリージョンの外側に描いておくと第2回が楽になる。

**[本文]**

```
◼リージョン
データセンターのある地域。asia-northeast1 = 東京

◼ゾーン
リージョン内の独立した区画。asia-northeast1-a / -b / -c
AWSのアベイラビリティゾーン(AZ)に相当

◼リソースのスコープは3種類ある
グローバル  VPC / イメージ / グローバルLB
リージョン  サブネット / Cloud NAT / Cloud Run
ゾーン      VM / Persistent Disk

この勉強会では asia-northeast1 を使います
```

**[話す]** 「VPCがグローバル」というのがAWSとの一番大きな違い。
次回みっちりやるので、今は「スコープが3段階ある」だけ覚えて帰ってほしい。

---

### S22 | 割り当て(Quota)

**[本文]**

```
◼割り当て(Quota)
プロジェクトごと・リージョンごとに使える量の上限

例
  VPCネットワーク数        プロジェクトあたり
  CPU数                    リージョンあたり
  使用中の外部IPアドレス数  リージョンあたり
  サービスアカウント数      プロジェクトあたり

上限に当たったらコンソールから引き上げ申請ができる
(承認まで時間がかかるので早めに)

★ 今回は共有プロジェクトなので、Quotaも全員で分け合っています
   作ったら消す。これを徹底してください
```

**[話す]** AWS版でいうサービスクォータ。共有プロジェクトだと誰かの消し忘れが
他の人の apply を止めることになる。

---

### S23 | AWSとの用語対応

**[図版]** 新規。2カラムの対応表。
第2回以降も毎回この表の関連行だけを再掲するので、テンプレートとして作っておく。

**[本文]**

```
AWS                       GCP
─────────────────────────────────────────────────
アカウント                プロジェクト
Organizations             組織 / フォルダ
IAMユーザ                 Googleアカウント(プリンシパル)
IAMロール                 ロール + サービスアカウント
IAMポリシー               ロール
VPC(リージョン)           VPC(グローバル)
サブネット(AZ)            サブネット(リージョン)
セキュリティグループ      Firewall Rules
NATゲートウェイ           Cloud NAT + Cloud Router
EC2                       Compute Engine
S3                        Cloud Storage
RDS                       Cloud SQL
ECS/Fargate               Cloud Run
CloudWatch                Cloud Monitoring / Cloud Logging
Cloud9                    Cloud Shell
```

**[話す]** AWS経験者向けの地図。ただし「IAMロール = ロール」ではないところが要注意で、
ここから先はその話をする。

---

# Cloud IAM

---

### S24 | Cloud IAM とは

**[図版]** AWS版 第2回「IAM」の関係図(グループ/ユーザ/ポリシー/ロール/IDプロバイダの箱)は
**構造が違うので流用しない**。新規作成する。

新しい図:
```
  誰が          何を            どのリソースに
  ────         ────           ──────────
 プリンシパル → ロール      →   リソース
 (Member)      (Role)          (Resource)

    └────── 許可ポリシー(バインディング) ──────┘
```

**[本文]**

```
◼Cloud IAM
「誰が」「何を」「どのリソースに」できるかを決める仕組み

  プリンシパル + ロール + リソース = バインディング
  バインディングの集合 = 許可ポリシー

◼AWSとの決定的な違い
AWSは「ユーザにポリシーを貼る」
GCPは「リソースに『このプリンシパルにこのロール』を貼る」

  → 権限を確認したいときは
    「ユーザ」ではなく「リソース」を見に行く
```

**[話す]** ここが一番の頭の切り替えポイント。AWSの感覚で「このユーザの権限一覧」を
探しに行くと見つからない。GCPは各リソースに許可ポリシーがぶら下がっている。

---

### S25 | プリンシパル(誰が)

**[本文]**

```
◼プリンシパル = 操作する主体

user:shiiman@example.com               Googleアカウント(人)
serviceAccount:xxx@....gserviceaccount.com   サービスアカウント(プログラム)
group:sre@example.com                  Googleグループ
domain:example.com                     Cloud Identity / Workspace ドメイン

allUsers            インターネット上の全員(認証不要)
allAuthenticatedUsers  Googleアカウントを持つ全員

★ allUsers / allAuthenticatedUsers は事故の元
   「バケットを公開したら全世界に公開されていた」の原因はほぼこれ
```

**[話す]** Terraformで `member` に書くのがこの文字列。プレフィックス(user: / serviceAccount:)を
間違えるとよくエラーになる。

---

### S26 | ロール(何ができる)

**[本文]**

```
◼ロール = 権限(permission)のまとまり

3種類ある

1. 基本ロール    roles/owner, roles/editor, roles/viewer
   AWSでいうAdministratorAccess級。強すぎるので本番では使わない

2. 事前定義ロール  roles/storage.objectViewer, roles/compute.networkAdmin ...
   Googleが用意したサービス別のロール。基本はこれを使う

3. カスタムロール  自分で権限を選んで作る
   事前定義ロールでは粒度が合わないときだけ

◼権限(permission)の命名規則
  <サービス>.<リソース>.<動詞>
  storage.objects.get / compute.instances.create
```

**[話す]** 「とりあえず Editor」をやると、共有プロジェクトでは他人のリソースも
消せてしまう。宿題でカスタムロールを作ってもらうので、そこで粒度の感覚を掴んでほしい。

---

### S27 | 許可ポリシーとバインディング

**[図版]** 新規。バケットの絵に許可ポリシーの吹き出しを付け、
中に2つのバインディング(role + members)を書く。

**[本文]**

```
◼許可ポリシー(Allow Policy)
リソースにぶら下がる「バインディングのリスト」

  バケット "[プロジェクトID]-tfstate-shiiman"
    └ 許可ポリシー
        ├ roles/storage.objectViewer : [serviceAccount:shiiman-app@...]
        └ roles/storage.admin        : [user:shiiman@example.com]

◼付与できる階層
組織 / フォルダ / プロジェクト / 個別リソース

  → 個別リソースに付けられるのがGCPの強み
    「このバケットだけ」「このVMだけ」が書ける
```

---

### S28 | IAMの継承

**[図版]** S19の階層ツリーを再掲し、上から下への矢印を強調。

**[本文]**

```
◼上の階層で付けたロールは、下の階層すべてに効く

組織で roles/viewer
  → 全フォルダ・全プロジェクト・全リソースが見える

◼実効権限 = 各階層で付与されたロールの「足し算」
下の階層で権限を減らすことはできない

◼減らしたいときは拒否ポリシー(Deny Policy)
ただし複雑になるので、まずは
「必要な階層で必要な分だけ付ける」を徹底する
```

---

### S29 | サービスアカウント ★GCP最重要

**[図版]** **新規作成**。GCP版で最も重要な図。

```
   サービスアカウントは2つの顔を持つ

   ┌─ プリンシパルとしての顔 ─┐   ┌─ リソースとしての顔 ─┐
   │  ロールを「付与される」   │   │  ロールを「付与する」  │
   │  = このSAは何ができるか   │   │  = 誰がこのSAを使えるか │
   └──────────────┘   └─────────────┘
```

**[本文]**

```
◼サービスアカウント(SA)
人ではなく「プログラム」に紐づくGCP専用のアカウント

  shiiman-app@[プロジェクトID].iam.gserviceaccount.com

◼SAが特殊なのは「プリンシパル」でも「リソース」でもあること

プリンシパルとして  SAにロールを付ける
                    → このSAはCloud Storageを読める

リソースとして      SAにもIAMポリシーが付く
                    → このSAを使ってよいのは誰か

◼AWSのIAMロールとの違い
AWSのIAMロールは「一時的に引き受けるもの」でIDを持たない
GCPのSAはメールアドレスを持った独立したIDである
```

**[話す]** ここが分かると以降の回が全部楽になる。逆にここが曖昧だと、
第5回(Cloud Run)や第7回(CI/CD)で必ず詰まる。

---

### S30 | サービスアカウントキーを作らない

**[本文]**

```
◼サービスアカウントキー(JSONファイル)
SAの秘密鍵。これがあれば誰でもそのSAになれる

★ 原則として作らない

理由
  有効期限がない
  漏れても気づけない
  Gitに間違えてコミットする事故が定番

◼代わりに使うもの
1. アタッチされたSA        GCE / Cloud Run にSAを紐づける(第3回・第5回)
2. 権限借用(impersonation) 人が一時的にSAになりすます(今日やる)
3. Workload Identity 連携  GitHub Actions などGCP外から使う(第7回)
```

**[話す]** AWS版でいう「アクセスキーをばら撒かない」と同じ話。
GCPはキーレスの手段が揃っているので、原則キーは作らない。

---

### S31 | 権限借用(impersonation)

**[図版]** 新規。人アイコン → 矢印(roles/iam.serviceAccountTokenCreator)→ SAアイコン → 矢印 → リソース。

**[本文]**

```
◼権限借用
自分の認証情報のまま、一時的にSAとして操作する

  自分 --[roles/iam.serviceAccountTokenCreator]--> SA --> リソース

◼ポイント
このロールは「SAというリソース」に対して付ける
プロジェクトに対してではない

◼CLIでの使い方
  gcloud storage ls gs://xxx \
    --impersonate-service-account=shiiman-app@[プロジェクトID].iam.gserviceaccount.com

今日のハンズオンで実際にやります
```

---

### S32 | AWS IAM との対比

**[図版]** 新規。左右2カラムで並べる。

**[本文]**

```
AWS                              GCP
────────────────────────────────────────────────────
IAMユーザ                        Googleアカウント(プリンシパル)
IAMグループ                      Googleグループ
IAMポリシー(JSON)                ロール
IAMロール(AssumeRole)            サービスアカウント + 権限借用
インラインポリシー               リソースに直接付けるバインディング
アクセスキー/シークレットキー    サービスアカウントキー(なるべく作らない)
IDプロバイダ(SAML/OIDC)          Workload Identity 連携

◼考え方の違い
AWS : プリンシパルに権限を「持たせる」
GCP : リソースに「誰が何をできるか」を書く
```

---

### S33 | 【注意】共有プロジェクトでやってはいけないこと ★

**[図版]** 新規。警告色(赤)のスライド。この回で一番目立たせる。

**[本文]**

```
★★ Terraformで絶対に使ってはいけないリソース ★★

  google_project_iam_binding
  google_project_iam_policy

これらは「権威的(authoritative)」なリソースで、
apply すると 他の人のIAM設定を消します

  google_project_iam_policy  → プロジェクトのIAM設定を全部置き換える
  google_project_iam_binding → そのロールの付与先を全部置き換える

◼使ってよいのはこれ
  google_project_iam_member   ← 加算的(additive)。自分の分だけ足す

◼今日のハンズオンではさらに安全側に倒します
プロジェクトではなく、リソース単位でロールを付けます
  google_service_account_iam_member
  google_storage_bucket_iam_member
```

**[話す]** これは共有プロジェクトに限らず、業務でもよくある事故。
`_policy` / `_binding` / `_member` の3種類があって、`_member` 以外は
「そのリソースの権限を自分の書いた内容で上書きする」という意味になる。
GCPのIAMリソースは全部この3点セットになっているので、名前を見て判断できるようにしておくこと。

---

### S34 | 認証情報の優先順位(ADC)

**[図版]** AWS版 第2回「IAM」の認証情報優先順位スライドのレイアウトを流用。
中身をADCに差し替え(AWS版は6段階、GCPは3段階なので行を減らす)。

**[本文]**

```
◼ADC (Application Default Credentials)
gcloud / Terraform / 各言語のSDKが共通で使う認証情報の探し方

優先順位
1. 環境変数 GOOGLE_APPLICATION_CREDENTIALS が指すJSONファイル
2. gcloud auth application-default login で作った認証情報
   (~/.config/gcloud/application_default_credentials.json)
3. 実行環境にアタッチされたサービスアカウント
   (Compute Engine / Cloud Run / Cloud Shell などのメタデータサーバ経由)

★ Cloud Shell では 3 が使われます
  = 今ログインしている自分のアカウントで Terraform が動く
  ローカルでの設定は不要
```

---

### S35 | 休憩

**[本文]**

```
5分休憩

後半は Cloud Shell と Terraform です
```

---

# Cloud Shell

---

### S36 | Cloud Shell とは

**[図版]** AWS版 第2回「Cloud9」スライドのレイアウトを流用。中身を差し替え。
Cloud9の作成手順スクリーンショット6枚(AWS版)は**不要になるので削除**
(Cloud Shellは作成操作がないため)。

**[本文]**

```
◼Cloud Shell
ブラウザから使えるGCPの作業環境

◼特徴
無料
gcloud / git / go / python / docker / kubectl がプリインストール済み
ログイン中の自分の権限がそのまま使える(認証設定が不要)
5GBの永続ホームディレクトリ
Cloud Shell Editor(VS Codeベース)でファイル編集もできる

★ AWS版のCloud9と違い、事前に作る操作が要りません
   ボタンを押せば数秒で立ち上がります

★ ただし Terraform は入っていません
   自分でインストールします(次のスライド)
```

**[話す]** AWS版ではCloud9を作るのに6枚スライドを使っていた。
Cloud Shellは押すだけなので、その分をTerraformに回せる。

Terraformは以前はCloud Shellに同梱されていたが、現在は外されている。
`/google/bin/terraform` というファイルは残っているが、
中身は「自分で入れてください」という案内を表示するだけのスクリプト。

> **検証済み(2026-08-28)**: 実際のCloud Shellで `terraform: command not found` を確認。

---

### S37 | Cloud Shell の注意点

**[本文]**

```
◼知っておくべきこと

一定時間操作しないとセッションが切れる
  → 切れても $HOME の中身は残る

$HOME(5GB)以外は再接続時にリセットされる
  → apt install したものは消える。/home/[ユーザ] の中で作業すること

120日間使わないとホームディレクトリが削除される

週あたりの利用時間に上限がある

★ この「$HOME以外は消える」がTerraformのインストール先を決めます
   sudo apt install terraform だと、次に繋いだとき消えている
   → $HOME の下に入れる

★ tfstateをCloud Shellのローカルに置いたままにしない
   → 今日、GCSに置く方法をやります
```

> **要確認**: 「120日」「週あたりの上限時間」は開催前に公式ドキュメントで最新値を確認する。

---

### S38 | Cloud Shell を起動してみよう

**[図版]** **新規スクリーンショット**。GCPコンソール右上のCloud Shellアイコンを赤枠で囲む。
起動後のターミナル画面も1枚。

**[本文]**

```
1. GCPコンソールを開く
   https://console.cloud.google.com

2. プロジェクトを [プロジェクトID] に切り替える

3. 右上のターミナルアイコンをクリック

4. 下からターミナルが立ち上がる

◼確認
  gcloud config get-value project
  gcloud auth list
```

**[話す]** Cloud Shellの既定プロジェクトは各自の個人プロジェクトになっていることが多い。
`gcloud config set project [プロジェクトID]` で必ず切り替えさせること。
ここを忘れると、以降の apply が別プロジェクトに向いてしまう。

---

### S38b | Terraform をインストールする ★新規

**[本文]**

```
◼Cloud Shell に Terraform は入っていません

  terraform version
  → bash: terraform: command not found

◼$HOME の下にインストールします
  ($HOME以外は再接続で消えるため)

  mkdir -p ~/bin
  cd /tmp
  curl -sLO https://releases.hashicorp.com/terraform/1.16.0/terraform_1.16.0_linux_amd64.zip
  unzip -o terraform_1.16.0_linux_amd64.zip -d ~/bin

◼PATH を通します(~/.bashrc に書けば次回以降も有効)

  echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
  source ~/.bashrc

◼確認
  terraform version
  → Terraform v1.16.0

★ この作業は初回だけ。第2回以降は不要です
```

**[話す]** AWS版の第2回でも Cloud9 に tfenv で Terraform を入れる作業があった。
やっていることは同じ。違うのは、Cloud Shellは $HOME しか残らないので
`/usr/local/bin` ではなく `~/bin` に入れる必要があること。

バージョンを切り替えたい人は tfenv を `~/.tfenv` に入れてもよい
(その場合も PATH は `~/.bashrc` に書く)。

> **検証済み(2026-08-28)**: 実際のCloud Shellで上記手順を実行し、
> `Terraform v1.16.0` の起動と、`~/.bashrc` 経由でのPATH永続化を確認。
> `~/bin` の容量は約115MB(ホームは5GBまで)。

> **制作TODO**: 開催直前にTerraformの最新版バージョン番号を確認して差し替える。

---

### S39 | 作業スペースの準備

**[本文]**

```
◼作業ディレクトリを作る
  mkdir -p ~/works/lesson1
  cd ~/works/lesson1

◼サンプルコードを取得
  git clone https://github.com/shiiman/infra-study.git ~/infra-study

◼サンプルの場所
  ~/infra-study/gcp/lesson1/

★ サンプルは「答え」です
   まずは自分で書いてみて、詰まったら見てください
```

**[話す]** AWS版と同じリポジトリ。AWS版のコードは `lesson3/` 〜 `lesson9/`、
GCP版は `gcp/lesson1/` 〜 に入っている。

---

# Terraform

---

### S40 | Terraform とは

**[図版]** AWS版 第2回「Terraform」の特徴スライドを流用。差し替えほぼ不要。

**[本文]**

```
◼Terraform
インフラの構成をソースコードとして管理するツール

◼特徴
マルチプラットフォーム対応
  AWS, GCP, Azure, Datadog, GitHub など
学習コストが低い
Infrastructure as Code
  インフラの見える化 / 再利用 / 複数人開発 / レビュー / CI/CD

★ AWS版で学んだことがそのまま使えます
   変わるのは provider と resource の名前だけ
```

---

### S41 | Write / Plan / Apply

**[図版]** AWS版 第2回「Terraform」のStep1-2-3スライドを流用。差し替え不要。

**[本文]**

```
Step1. Write (HCL)
  .tfファイルを書く

Step2. Plan (CLI)
  何が作られる/変わる/消えるかを確認(dry run)

Step3. Apply (CLI)
  実際に構築する

★ plan を読まずに apply しない
   特に destroy(赤いマイナス表示)が出ていないか必ず見る
```

---

### S42 | 構成言語(HCL)- ブロックの種類

**[図版]** AWS版 第2回「Terraform - 構成言語」の一覧スライドを流用。差し替え不要。

**[本文]**

```
◼ブロック
terraform    Terraform自体の設定
provider     プロバイダー(GCPなど)の設定
variable     変数
resource     作るリソース
data         既にあるものを参照する
module       複数リソースをまとめて再利用する

◼式
型: string, number, bool, list, map, null
ループ: count, for_each

◼関数
format(), replace(), length() ...
```

---

### S43 | terraform / provider ブロック

**[図版]** AWS版 第2回「Terraform - 構成言語」のmain.tf例スライドを流用。
コード部分をGCP版に差し替え。

**[本文]**

```
common.tf

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  required_version = ">= 1.9.0"
}

provider "google" {
  project = "[プロジェクトID]"
  region  = "asia-northeast1"
}

★ providerに project を書いておけば、
   各リソースで毎回プロジェクトを指定しなくてよい
```

**[話す]** `~> 8.0` は「8.x系の最新を使う。9系には上げない」という意味。
バージョンを固定しないと、ある日突然 plan の結果が変わることがある。

---

### S44 | resource / variable ブロック

**[図版]** AWS版 第2回の resource/variable 2カラムスライドを流用。コードを差し替え。

**[本文]**

```
◼resourceブロック
resource "google_storage_bucket" "tfstate" {
  name     = "[プロジェクトID]-tfstate-shiiman"
  location = "ASIA-NORTHEAST1"
}
          ↑リソースタイプ    ↑この設定ファイル内での名前

  参照するときは google_storage_bucket.tfstate.name

◼variableブロック
variable "user_name" {}

resource "google_storage_bucket" "tfstate" {
  name = "[プロジェクトID]-tfstate-${var.user_name}"
}
```

---

### S45 | tfvars

**[図版]** AWS版 第2回の tfvars スライドを流用。コードを差し替え。

**[本文]**

```
◼terraform.tfvars
変数の値をまとめて書くファイル。自動で読み込まれる

terraform.tfvars

  // ★ 自分の名前に書き換えること
  user_name = "shiiman"

◼値の渡し方(優先順位順)
  -var オプション
  -var-file オプション
  terraform.tfvars(自動読み込み)
  環境変数 TF_VAR_user_name
  variable の default
```

**[話す]** この勉強会では全員が同じコードを使って、`user_name` だけ変える。
共有プロジェクトなので、ここを書き換え忘れると他人のリソースを触ることになる。必ず変えること。

---

### S46 | data / module ブロック

**[本文]**

```
◼dataブロック
Terraform管理外の情報を読み取る

  data "google_client_openid_userinfo" "me" {}

  → 今Terraformを実行している自分のメールアドレスが取れる
    data.google_client_openid_userinfo.me.email

◼moduleブロック
複数リソースをまとめて再利用する

  module "before" {
    source = "github.com/shiiman/infra-study//gcp/lesson3/0. before"
  }

  → 第3回以降、前回の完成状態を読み込むのに使います
```

**[話す]** 押していたらここは口頭だけで飛ばしてよい。data は今日のハンズオンで実際に使う。

---

### S47 | CLIコマンド

**[図版]** AWS版 第2回「Terraform - CLI」2枚を流用。差し替え不要。

**[本文]**

```
◼Main commands
  terraform init      初期化(プロバイダーの取得、backendの設定)
  terraform validate  構文チェック
  terraform plan      dry run
  terraform apply     実行
  terraform destroy   削除

  terraform fmt       整形

◼特徴
カレントディレクトリの .tf / .tfvars を読み込む
-chdir で実行ディレクトリを変更できる
init すると .terraform/ にプロバイダーがキャッシュされる
```

---

### S48 | tfstate とは

**[図版]** 新規。3つの箱(コード / tfstate / 実際のGCP)を三角形に配置し、
tfstateが「コードと現実の対応表」であることを示す。

**[本文]**

```
◼tfstate
Terraformが「今どのリソースを管理しているか」を記録するファイル

  .tfファイル ←→ tfstate ←→ 実際のGCPリソース

plan はこの3つを突き合わせて差分を出している

◼tfstateが消えると
Terraformは「何も作っていない」と思い込む
→ apply すると同じものをもう一度作ろうとして名前が衝突する

◼tfstateには機密情報が平文で入る
DBのパスワードなどがそのまま書かれる
→ Gitにコミットしない。アクセス制御されたところに置く
```

---

### S49 | tfstate をどこに置くか(backend)

**[本文]**

```
◼デフォルトはローカル
  ./terraform.tfstate

  → PCが壊れたら終わり
  → 複数人で作業できない
  → Cloud Shellのホームが消えたら終わり

◼リモートバックエンド
GCSバケットに置く

terraform {
  backend "gcs" {
    bucket = "[プロジェクトID]-tfstate-shiiman"
    prefix = "lesson1"
  }
}

★ backendブロックには変数が使えない
   バケット名は直接書く必要がある
```

**[話す]** AWS版ではローカルのままだったが、GCP版では最初からGCSに置く。
実務ではまずこれをやる。今日のハンズオンの山場。

---

# ハンズオン

---

### S50 | 今日作るもの

**[図版]** **新規作成**。左から右へ4ステップのフロー図。
各ステップの下に作られるリソースのアイコンを配置。

```
 Step1        Step2           Step3            Step4
GCSバケット → backend移行 → サービスアカウント → 権限付与
                                    ↓
                              なりすまし失敗 → 成功
```

**[本文]**

```
◼ハンズオンのゴール

1. Terraformで GCSバケットを作る
2. tfstate をそのバケットに移す
3. サービスアカウントを作る
4. サービスアカウントになりすませるようにする

コード: ~/infra-study/gcp/lesson1/
```

---

### S51 | Step1 GCSバケットを作る

**[本文]**

```
◼common.tf と gcs.tf を作る
  cd ~/works/lesson1

参照: gcp/lesson1/1. gcs/

resource "google_storage_bucket" "tfstate" {
  name     = "[プロジェクトID]-tfstate-${var.user_name}"
  location = "ASIA-NORTHEAST1"

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
  force_destroy               = true
}

★ バケット名はGCP全体で一意
   だからプロジェクトIDと自分の名前を含めている
```

---

### S52 | Step1 実行

**[本文]**

```
  terraform init
  terraform plan
  terraform apply

◼確認
  gcloud storage buckets list --filter="name:tfstate-[自分の名前]"

◼tfstateがどこにあるか見てみる
  ls -la
  → terraform.tfstate がローカルにできている

  cat terraform.tfstate

★ これがローカルにあると困る、という話を次でやります
```

---

### S53 | Step2 backend を GCS に切り替える

**[本文]**

```
◼common.tf に backend ブロックを足す

参照: gcp/lesson1/2. backend/

terraform {
  required_providers { ... }
  required_version = ">= 1.9.0"

  backend "gcs" {
    bucket = "[プロジェクトID]-tfstate-shiiman"   ← ★自分の名前に
    prefix = "lesson1"
  }
}

★ ここだけは変数が使えないので直接書く
```

---

### S54 | Step2 state を移行する

**[本文]**

```
  terraform init -migrate-state

  Do you want to copy existing state to the new backend?
    → yes

◼確認
  gcloud storage ls -r gs://[プロジェクトID]-tfstate-[自分の名前]/

  gs://.../lesson1/default.tfstate

  ls -la
  → ローカルの terraform.tfstate が空になっている

★ これで、Cloud Shellが吹き飛んでも tfstate は無事
★ バージョニングを有効にしてあるので、壊しても前の世代に戻せる
```

**[話す]** 実務ではこれを最初にやる。今日はローカルからの移行を体験してもらいたかったので
2ステップに分けた。

---

### S55 | Step3 サービスアカウントを作る

**[本文]**

```
参照: gcp/lesson1/3. service_account/

resource "google_service_account" "app" {
  account_id   = "${var.user_name}-app"
  display_name = "${var.user_name} app service account"
}

  terraform plan
  terraform apply

◼確認
  gcloud iam service-accounts list --filter="email:[自分の名前]-app"

  shiiman-app@[プロジェクトID].iam.gserviceaccount.com
```

---

### S56 | Step3 なりすましてみる → 失敗する

**[図版]** ターミナルのエラー出力を貼る(**開催前に実行して実物のスクショを撮ること**)。

**[本文]**

```
◼このサービスアカウントになりすまして、さっき作ったバケットを見てみる

  gcloud storage ls gs://[プロジェクトID]-tfstate-[自分の名前]/ \
    --impersonate-service-account=[自分の名前]-app@[プロジェクトID].iam.gserviceaccount.com

◼結果

  ERROR: (gcloud.storage.ls) PERMISSION_DENIED:
    Failed to impersonate [shiiman-app@[プロジェクトID].iam.gserviceaccount.com].
    Make sure the account that's trying to impersonate it has access to
    the service account itself and the "roles/iam.serviceAccountTokenCreator" role.
    Permission 'iam.serviceAccounts.getAccessToken' denied on resource

★ 作っただけでは使えない
★ エラーメッセージが必要なロール名まで教えてくれている
   GCPのエラーは親切なので、まず全文を読む癖をつけること
```

> **検証済み(2026-08-28)**: `[プロジェクトID]` で上記のエラーを実測。

---

### S57 | なぜ失敗したのか

**[図版]** 新規。2つのゲートが閉じている図。

```
  自分 ──✕── サービスアカウント ──✕── バケット
        ①                    ②

  ① 自分がこのSAになりすます権限がない
  ② SAがバケットを読む権限がない
```

**[本文]**

```
◼2つの権限が足りていない

① 自分 → SA
   roles/iam.serviceAccountTokenCreator
   「このSAになりすましてよい」
   → SAというリソースに対して付ける

② SA → バケット
   roles/storage.objectViewer
   「このバケットの中身を読んでよい」
   → バケットというリソースに対して付ける

★ どちらもプロジェクトではなく個別リソースに付ける
   S33の「共有プロジェクトでやってはいけないこと」の実践
```

**[話す]** AWS版では「セキュリティグループを足したら繋がった」をやった。
GCPのIAMも同じで、「足りないものを1つずつ足す」で解決する。
違うのは、足す場所がユーザ側ではなくリソース側だということ。

---

### S58 | Step4 権限を足す

**[本文]**

```
参照: gcp/lesson1/4. iam/

data "google_client_openid_userinfo" "me" {}

// ① 自分 → SA
resource "google_service_account_iam_member" "token_creator" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${data.google_client_openid_userinfo.me.email}"
}

// ② SA → バケット
resource "google_storage_bucket_iam_member" "app_object_viewer" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.app.email}"
}

★ data ブロックで自分のメールアドレスを取っている
   (S46でやったもの)
```

---

### S59 | Step4 実行 → 成功

**[本文]**

```
  terraform plan
  terraform apply

◼もう一度なりすましてみる

  gcloud storage ls gs://[プロジェクトID]-tfstate-[自分の名前]/ \
    --impersonate-service-account=[自分の名前]-app@[プロジェクトID].iam.gserviceaccount.com

  gs://[プロジェクトID]-tfstate-[自分の名前]/lesson1/

★ 通った

◼書き込みは失敗することも確認する
  echo test > /tmp/test.txt
  gcloud storage cp /tmp/test.txt gs://[プロジェクトID]-tfstate-[自分の名前]/ \
    --impersonate-service-account=...

  ERROR: ... does not have storage.objects.create access ...

★ objectViewer は読めるだけ。最小権限が効いている
```

**[話す]** IAMの反映には時間がかかる。実測では apply 直後は失敗し続け、
**約1分後**に通るようになった。「すぐ失敗しても正常」と先に言っておくこと。
ここで受講者が「コードが間違っている」と思って触り始めると崩れる。

> **検証済み(2026-08-28)**: 読み取り成功 / 書き込みは
> `does not have storage.objects.create access` で拒否されることを実測。

---

### S60 | ハンズオン完了

**[図版]** S50のフロー図を再掲し、全ステップにチェックマークを付ける。

**[本文]**

```
◼できたこと

Cloud Shell から terraform apply が通った
tfstate が GCS に保存された
サービスアカウントを作った
リソース単位でIAMロールを付けて、権限借用ができた

★ ここまでが、以降9回の土台になります
```

---

# まとめ

---

### S61 | 本日のまとめ

**[図版]** AWS版 第2回「本日のまとめ」のレイアウトを流用。

**[本文]**

```
◼GCPの基礎
GCPは 組織 - フォルダ - プロジェクト の階層で管理する
リソースには グローバル / リージョン / ゾーン の3つのスコープがある
料金は従量課金。継続利用割引が自動で効く
Quotaはプロジェクト単位。共有プロジェクトなので作ったら消す

◼Cloud IAM
プリンシパル + ロール + リソース = バインディング
ロールには 基本 / 事前定義 / カスタム の3種類がある
IAMは上の階層から下へ継承される
サービスアカウントは「プリンシパル」でも「リソース」でもある
サービスアカウントキーは作らない。権限借用を使う
google_project_iam_binding / _policy は共有プロジェクトで使わない

◼Terraform
HCLはブロックで書く
plan で確認してから apply する
tfstate はコードと現実の対応表。GCSに置く
```

---

### S62 | 本日はここまで

**[図版]** AWS版の同スライドを流用。

---

### S63 | 宿題1 アンケート

**[図版]** AWS版 第1回「宿題1」を流用。URLを差し替え。

**[本文]**

```
◼アンケートのお願い

1分で終わりますのでぜひフィードバックお願い致します！！
次回開催のモチベになります！！！

https://forms.gle/xxxxxxxx
```

> **制作TODO**: Google Form を新規作成してURLを差し込む。
> 設問は `gcp/docs/survey.md`(未作成)に定義する。

---

### S64 | 宿題2 実装課題

**[本文]**

```
◼1. カスタムロールを作ってサービスアカウントに付与しよう

事前定義ロール roles/storage.objectViewer の代わりに、
必要な権限だけを持つカスタムロールを作る

  必要な権限: storage.objects.get / storage.objects.list

回答例: gcp/lesson1/syukudai1/


◼2. Secret Manager のシークレットを作り、
   リソース単位で読み取り権限を付けよう

シークレットの「入れ物」だけをTerraformで作る
中身(値)は gcloud で入れる。なぜか考えてみてください

回答例: gcp/lesson1/syukudai2/
```

**[話す]** 2つ目の「なぜ値をTerraformに書かないか」は答えを言わないでおく。
分かった人は次回の冒頭で発表してもらう。

---

### S65 | 宿題3 チュートリアルとドキュメント

**[図版]** AWS版 第2回「宿題2 Terraform チュートリアル」の
○△×形式のリストを流用。項目をGCP編に差し替え。

**[本文]**

```
◼Terraform Tutorial - GCP編
  https://developer.hashicorp.com/terraform/tutorials/gcp-get-started

  △ What is Infrastructure as Code with Terraform?
  △ Install Terraform
  ○ Build Infrastructure
  ○ Change Infrastructure
  ○ Destroy Infrastructure
  ○ Define Input Variables
  ○ Query Data with Outputs
  ○ Store Remote State

  (○はやる / △は読むだけ / ×はやらなくてよい)

◼ドキュメントを眺めてみよう
  Cloud IAM   https://cloud.google.com/iam/docs/overview
  サービスアカウント  https://cloud.google.com/iam/docs/service-account-overview
  Terraform google provider
    https://registry.terraform.io/providers/hashicorp/google/latest/docs
```

**[話す]** AWS版では Store Remote State を「×(やらなくてよい)」にしていたが、
GCP版では今日ハンズオンでやったので「○」にしている。復習として通しでやってみてほしい。

---

### S66 | 参考

**[本文]**

```
Google Cloud ドキュメント
  https://cloud.google.com/docs

AWSプロフェッショナルのためのGoogle Cloud
  https://cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison

Google Cloud のリソース階層
  https://cloud.google.com/resource-manager/docs/cloud-platform-resource-hierarchy

Cloud Shell ドキュメント
  https://cloud.google.com/shell/docs

Terraform Google Provider
  https://registry.terraform.io/providers/hashicorp/google/latest/docs
```

---

### S67 | 注意事項

**[図版]** AWS版「注意事項」スライドを流用。

**[本文]**

```
宿題などで作成したリソースは
必ず削除してください！

★ 今回は全員で1つのプロジェクトを共有しています
   消し忘れがQuotaを圧迫して、他の人のapplyが止まります


◼第1回だけは、そのまま terraform destroy をしないでください

tfstateを置いているバケット自身を消してしまうため、
Terraformが最後にロックを解放できず、エラーで終わります

  Error: Error releasing the state lock
  ★ リソース自体は消えるが、errored.tfstate が残る後味の悪い終わり方になる

◼正しい消し方: バケット以外を -target で指定する

  terraform destroy \
    -target=google_service_account_iam_member.token_creator \
    -target=google_storage_bucket_iam_member.app_object_viewer \
    -target=google_service_account.app

  宿題までやった人は、これも足す
    -target=google_storage_bucket_iam_member.app_custom_role \
    -target=google_project_iam_custom_role.object_reader \
    -target=google_secret_manager_secret_iam_member.app_accessor \
    -target=google_secret_manager_secret.app

★ バケットは次回以降も使うので残します
★ 第2回からは普通に terraform destroy で大丈夫です
   (バケットが第2回のstateに入っていないため)
```

**[話す]** `-target` は本来「例外的な状況でのみ使うもの」で、
実行するとTerraformが警告を出す。ここはまさにその例外的な状況。
宿題3のCLIチュートリアルに「Target resources」という章があるので、
そこで詳しくやってほしい、と繋げる。

なぜこうなるのか(自分の家の鍵を家の中に置いたまま家ごと壊す構図)を
図で説明すると納得感が出る。

> **検証済み(2026-08-28)**: 実環境で確認。
> - そのまま `terraform destroy` → 全リソースは削除されるが
>   `Error releasing the state lock` で終了し `errored.tfstate` が残る
> - 上記の `-target` 指定 → バケットとtfstateは健全なまま、他は削除される
> - 第2回は素の `terraform destroy` で24リソースがクリーンに削除される

> **制作TODO**: 「なぜロック解放に失敗するのか」の図を1枚作る。
> S48のtfstate三角図(コード / tfstate / 実際のGCP)を流用し、
> tfstateの箱がバケットの中にあることを示すとよい。

---

### S68 | おしまい

**[図版]** AWS版「おしまい」スライドを流用。

**[本文]**

```
次回は ネットワーク編 です

GCPで一番AWSと違うところです
お楽しみに！！
```

---

# 付録A: 講師の事前準備チェックリスト

## 1. プロジェクトで有効化するAPI

`[プロジェクトID]` で以下を有効化する。

```
gcloud services enable \
  compute.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  storage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  secretmanager.googleapis.com \
  iap.googleapis.com \
  --project=[プロジェクトID]
```

| API | 使う回 | 用途 |
|---|---|---|
| iamcredentials | 第1回 | 権限借用(impersonation) |
| storage | 第1回 | tfstateバケット |
| secretmanager | 第1回 宿題2-2 | シークレット |
| compute | 第2回 | VPC / VM / Firewall / Cloud NAT |
| iap | 第2回 | IAP TCP forwarding |

## 2. 受講者に付与するIAMロール(プロジェクトレベル)

### 結論: `roles/editor` だけでは足りない

`roles/editor` の権限一覧(11,979個)を実際に調べた結果、
教材で使う次の権限が **含まれていない**。

| 不足している権限 | 使う箇所 | 無いとどうなるか |
|---|---|---|
| `iam.serviceAccounts.setIamPolicy` | 第1回 Step4 / 第2回 Step4 | `google_service_account_iam_member` が作れない |
| `storage.buckets.setIamPolicy` | 第1回 Step4 | `google_storage_bucket_iam_member` が作れない |
| `storage.buckets.getIamPolicy` | 第1回 Step4 | 同上(Terraformは書く前に読む) |
| `compute.instances.setIamPolicy` | 第2回 Step4 | `google_compute_instance_iam_member` が作れない |
| `iap.tunnelInstances.setIamPolicy` | 第2回 Step4 | `google_iap_tunnel_instance_iam_member` が作れない |
| `iap.tunnelInstances.getIamPolicy` | 第2回 Step4 | 同上 |
| `iam.roles.create` / `.delete` | 第1回 宿題1 | カスタムロールが作れない |
| `secretmanager.secrets.setIamPolicy` | 第1回 宿題2 | シークレット単位のIAMが付けられない |

つまり Editor だけだと **第1回 Step4(IAMハンズオンの山場)と
第2回 Step4(IAP)が両方とも動かない**。この2つはそれぞれの回の核心なので致命的。

### 付与するロール

Editor に以下を足す。いずれも不足権限を含むことを確認済み。

```
roles/editor                          ベース
roles/iam.serviceAccountAdmin         iam.serviceAccounts.setIamPolicy
roles/iam.roleAdmin                   iam.roles.create / delete / undelete
roles/storage.admin                   storage.buckets.get/setIamPolicy
roles/secretmanager.admin             secretmanager.secrets.setIamPolicy
roles/compute.instanceAdmin.v1        compute.instances.setIamPolicy
roles/iap.admin                       iap.tunnelInstances.get/setIamPolicy
roles/spanner.admin                   spanner.databases.setIamPolicy  (第4回)
roles/servicenetworking.networksAdmin servicenetworking.services.addPeering (第4回)
roles/run.admin                       run.services.setIamPolicy       (第5回)
```

**第4回で追加になる2ロールについて**

Spanner / Cloud SQL / Memorystore の**作成権限は `roles/editor` に含まれている**ので、
`roles/cloudsql.admin` や `roles/redis.admin` は不要。

必要なのは Editor に無い次の2つだけ。

| 不足権限 | 補完先 | 使う箇所 |
|---|---|---|
| `spanner.databases.setIamPolicy` | `roles/spanner.admin` | 第4回 Step3(SAにDB権限を付与) |
| `servicenetworking.services.addPeering` | `roles/servicenetworking.networksAdmin` | 第4回 Step2(限定公開サービスアクセス) |
| `run.services.setIamPolicy` | `roles/run.admin` | 第5回 Step2(Cloud Runを公開する) |

**Artifact Registry / Cloud Run / サーバレスNEG の作成権限も `roles/editor` に含まれている。**
`roles/artifactregistry.admin` は不要。

付与コマンド(受講者ごとに実行)

```
PROJECT=<プロジェクトID>
MEMBER=user:xxx@example.com

for ROLE in \
  roles/editor \
  roles/iam.serviceAccountAdmin \
  roles/iam.roleAdmin \
  roles/storage.admin \
  roles/secretmanager.admin \
  roles/compute.instanceAdmin.v1 \
  roles/iap.admin \
  roles/spanner.admin \
  roles/servicenetworking.networksAdmin \
  roles/run.admin
do
  gcloud projects add-iam-policy-binding $PROJECT \
    --member=$MEMBER --role=$ROLE --condition=None
done
```

### 共有プロジェクトでのリスク

このロール構成だと、受講者は**他人のリソースも消せる**。

- `roles/editor` の時点で、既に他人のVM・バケットは削除できる
- 追加した admin ロールで増えるのは主に `setIamPolicy` の権限
- `roles/storage.admin` はプロジェクト内の全バケットを操作できる

Editor を配る時点でこのリスクは受け入れる前提になっているが、
気になる場合は次の代替案がある。

**代替案: Editor + カスタムロール1つ**

不足している権限だけを持つカスタムロールを作り、Editor と一緒に付与する。
admin ロールを配らずに済むので、影響範囲を最小にできる。

```
gcloud iam roles create infra_study_iam_helper \
  --project=[プロジェクトID] \
  --title="Infra Study IAM Helper" \
  --permissions=\
iam.serviceAccounts.setIamPolicy,\
storage.buckets.getIamPolicy,storage.buckets.setIamPolicy,\
compute.instances.setIamPolicy,\
iap.tunnelInstances.getIamPolicy,iap.tunnelInstances.setIamPolicy,\
secretmanager.secrets.setIamPolicy,\
iam.roles.create,iam.roles.delete,iam.roles.undelete,iam.roles.update
```

### 検証結果(2026-08-28)

上記7ロールだけを持つサービスアカウントを作り、それになりすまして
第1回・第2回の全ステップと全宿題を通しで実行した。
グループ経由の余計な権限が一切混ざらない条件での検証。

| 実行内容 | 結果 |
|---|---|
| 第1回 全ステップ + 宿題1・2 | **OK**(9リソース。GCSバックエンドへのstate移行も成功) |
| 第2回 Step1〜7 | **OK**(Step4のIAP関連7リソースを含む) |
| 第2回 宿題1・2 | **OK**(計25リソース) |
| 第2回 `terraform destroy` | **OK**(24リソース削除) |
| 第1回 `-target` での destroy(S67の手順) | **OK**(7リソース削除) |

**このロール構成で過不足なし。** 追加も削減も不要。

なお `roles/editor` の `includedPermissions`(11,979個)を
`gcloud iam roles describe roles/editor` で取得して照合した結果が上の不足表。
補完先の各ロールに当該権限が含まれることも同様に確認している。

> **カスタムロール案は未検証**。権限リストを机上で組んだだけなので、
> そちらを採用する場合は同じ方法で通しの確認をすること。
> 検証方法: 権限だけを持つSAを作り、
> provider に `impersonate_service_account` を書いて apply する。

## 3. 引き上げ申請が必要な可能性のあるQuota

受講者を N 人とする。

| Quota | スコープ | 必要数の目安 | 備考 |
|---|---|---|---|
| VPCネットワーク数 | プロジェクト | N | デフォルト5。**最優先で申請** |
| サービスアカウント数 | プロジェクト | 3N + α | デフォルト100。第1回で1個、第2回で2個 |
| Cloud Router数 | リージョン | N | デフォルト値を要確認 |
| 使用中の外部IPアドレス数 | リージョン | 2N | web VMの外部IP + Cloud NAT |
| CPU数 | リージョン | 2N | e2-micro × 2台 |
| ファイアウォールルール数 | プロジェクト | 2N | |
| サブネットワーク数 | プロジェクト | 2N(宿題込みで7N) | |
| カスタムロール数 | プロジェクト | N | 第1回 宿題2-1 |

## 4. 開催前に撮るスクリーンショット

- S19: 組織 → 勉強会用フォルダ → [プロジェクトID] のリソース階層画面
- S38: Cloud Shell 起動アイコン / 起動後のターミナル
- S56: 権限借用の失敗エラー(実物)
- S59: 権限借用の成功出力(実物)

## 5. 事前に配布するもの

- インフラ基礎の自習資料(AWS版 第1回スライドのPDF、「ネットワーク」〜「SSL証明書」の範囲)
- アンケートフォームのURL

---

# 付録B: 制作メモ / 要確認事項

## 開催前に最新情報を確認すること

| 項目 | スライド | 内容 |
|---|---|---|
| Cloud Shell の仕様 | S37 | ホームディレクトリ削除までの日数(120日)、週あたりの利用時間上限 |
| Always Free の対象リージョン | S18 | asia-northeast1 が対象外であることの再確認 |
| Terraform GCPチュートリアルの構成 | S65 | 章立てが変わっていないか。○△×の割り当て |
| google provider のバージョン | S43 | `~> 8.0` のまま行くか。8.0.0 は 2026-08-26 リリース |

## 動作確認が必要な箇所

1. **`data "google_client_openid_userinfo"` が Cloud Shell で動くか**
   Cloud Shell の ADC に `userinfo.email` スコープが含まれている前提で書いている。
   もし取得できない場合は `variable "user_email"` を追加して tfvars で渡す形に変更する。
   影響: S46 / S58 / `gcp/lesson1/4. iam/iam.tf` / `gcp/lesson2/4. firewall/iap.tf`

2. **権限借用の失敗メッセージの文言**(S56)
   実際に実行してエラー文を確認し、スライドの文言を実物に合わせる。

3. **通しでの apply → destroy**
   Step1 から Step4 まで通して apply し、destroy まで確認する。

## 設計書からの変更点

設計書 6章では第1回の宿題を「Terraformチュートリアル(GCP編) / Cloud IAMドキュメント」
としていたが、成果物として宿題の回答例が必要なため、**実装課題を2問追加**した(S64)。
読み物系の宿題は S65 に集約している。
