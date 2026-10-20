# 第2回 インフラ勉強会(GCP) — ネットワーク

- **開催日**: 2026-10-26(月) 14-16時
- **AWS版対応**: 第3回(AWS ネットワーク編)
- **Terraformコード**: `gcp/lesson2/`
- **ゴール**: private サブネットのVMに IAP でログインでき、Cloud NAT 経由で外部へ疎通する
- **スライド**: S01〜S63(S17「VPC作成完了」・S22「サブネット作成完了」・S29「休憩」・S33「AWSのSGとの書き換え」はデッキから削除し、欠番) + セクション区切り7枚(S05-2 / S13-2 / S17-2 / S22-2 / S29-2 / S43-2 / S48-2)= **デッキ66枚**。
  区切りは S番号を振り直さないための仮番号(第1回の S66-2 と同じ扱い)。S04 は「今回」から「今日のアジェンダ」に差し替えた

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入 | 8分 | S01〜S05 |
| GCPネットワークの前提(AWSとの差分) | 12分 | S06〜S12 |
| 準備 | 5分 | S13 |
| VPC(概念 + Step1) | 10分 | S14〜S17 |
| サブネット(概念 + Step2) | 12分 | S18〜S21 |
| インスタンス(Step3) | 12分 | S23〜S28 |
| 休憩 | 5分 | (スライドなし。S29 は削除) |
| Firewall Rules + IAP(Step4・Step5) | 25分 | S30〜S43 |
| Routes + Private Google Access(Step6) | 10分 | S44〜S48 |
| Cloud NAT(Step7) | 13分 | S49〜S54 |
| まとめ・宿題 | 8分 | S55〜S63 |

> 押した場合の削り所: S06〜S12 の差分説明は S06 のサマリ表1枚に集約できる。
> S44(Routes)は口頭のみでも成立する。
> **削ってはいけないのは S34〜S36**(Firewall Rules がタグ/SA単位である説明)。この回の核心。

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない

---

# 導入

---

### S01 | タイトル

**[図版]** AWS版 第3回 表紙を複製。タイトルのみ差し替え。

**[本文]**

```
第2回 インフラ勉強会(GCP)

〜 ネットワーク編 〜

2026年10月26日(月) 14-16時
```

---

### S02 | インフラ勉強会 スケジュール

**[図版]** 全回共通のスケジュールスライド(この回のデッキの S02 が原本)。今日の行のマーカーは付けない。第3回以降は同じスライドを複製して使う。

---

### S03 | 前回の振り返り

**[図版]** AWS版 第3回「前回」スライドを流用。

**[本文]**

```
◼前回やったこと

GCPは 組織 - フォルダ - プロジェクト の階層で管理する
Cloud IAM は「プリンシパル + ロール + リソース」
サービスアカウントは「プリンシパル」でも「リソース」でもある
Cloud Shell から terraform apply が通った
tfstate を GCS に置いた
```

**[話す]** (スライドには載せず、口頭で聞く)宿題2-2の「値を tfstate に残さずに入れる方法」を受講者に答えてもらう。
答え: `secret_data_wo`(write-only 引数)に、**ephemeral な変数**で受けた値を渡す。
従来の `secret_data` は tfstate に平文で入る。tfstate は GCS にあるので、
バケットを読める人全員に見えてしまう。write-only なら残らない。

さらに「それでも gcloud で入れる運用が選ばれるのはなぜか」を聞けると良い。
**職務分離**(apply する人に値を見せない)/ **更新の切り離し**
(値だけ変えても Terraform は検知しない)/ **値の受け渡し**(結局どこかに出どころがある)。

---

### S04 | 今日のアジェンダ

**[図版]** 第1回 S12 と同じスライドを複製して、内容を第2回のものに差し替える。

**[本文]**

```
GCPのネットワーク

VPC・サブネット

ネットワークタグ / サービスアカウント

Firewall Rules + IAP

Routes + Private Google Access

Cloud NAT, Cloud Router

ハンズオン
```

**[話す]** 早くも山場。そして GCPとAWSで一番違うところ。

---

### S05 | ゴール

**[図版]** **新規作成**。AWS版 第3回「ゴール」の構成図をベースに、以下を差し替える。

- 一番外の枠「リージョン ap-northeast-1」→ **削除**。代わりに **VPCの枠を一番外側に**置く
  (VPCがグローバルであることを図で表す)
- VPCの中に「リージョン asia-northeast1」の枠を置き、その中にサブネット2つ
- AZ(1a / 1c)の区切り線は **削除**(GCPのサブネットはリージョン単位)
- 「Internet Gateway」の箱は **削除**
- 「踏み台サーバ」の箱は **削除**、代わりに左側に「IAP」の箱を置き、
  Cloud Shell から IAP を通って両方のVMへ矢印を引く
- 「NAT Gateway」→「Cloud NAT + Cloud Router」に差し替え、リージョンの枠内に1つだけ置く

```
┌─ VPC (グローバル) ────────────────────────┐
│  ┌─ asia-northeast1 ───────────────────┐  │
│  │  public subnet 172.16.0.0/24         │  │
│  │    [web VM] ← 外部IPあり             │  │
│  │                                       │  │
│  │  private subnet 172.16.10.0/24       │  │
│  │    [db VM]  ← 外部IPなし             │  │
│  │                                       │  │
│  │  [Cloud Router + Cloud NAT]          │  │
│  └───────────────────────────────────┘  │
└──────────────────────────────────────┘
      ↑ IAP (35.235.240.0/20)
   [Cloud Shell]
```

**[本文]**

```
踏み台サーバもインターネットゲートウェイも作らない。これを理解して作れる！
```

---

# GCPネットワークの前提

---

### S05-2 | GCPのネットワーク(セクション区切り)

**[本文]**

```
GCPのネットワーク
```

---

### S06 | AWSとGCP、ネットワークの違い

**[図版]** **新規作成**。この回で一番重要な表。第3回以降も再掲する。

**[本文]**

```
                    AWS                      GCP
──────────────────────────────────────────────────────────────
VPCのスコープ        リージョン                グローバル
VPCのCIDR            VPCが持つ                 持たない(サブネットが持つ)
サブネットのスコープ  アベイラビリティゾーン    リージョン
public/private       サブネットの属性          区別なし(外部IPの有無だけ)
ファイアウォール      Security Group            VPC Firewall Rules
  適用先の指定        リソースにアタッチ        ネットワークタグ / サービスアカウント
  許可元の指定        SG同士を参照できる        タグ / SA / IPレンジ
インターネット接続    Internet Gateway          リソースなし(暗黙のデフォルトルート)
ルートテーブル        サブネットに紐付ける      VPC単位。紐付け不要
NAT                  NAT Gateway(サブネット)   Cloud NAT + Cloud Router(リージョン)
private接続          SSM Session Manager       IAP TCP forwarding
```

**[話す]** AWSを触ったことがある人は、ここを頭に入れてから聞いてほしい。
一番引っかかるのは「Security Group同士の参照ができない」ところ。ここは後で厚くやる。

private接続の行: AWS の推奨は SSM Session Manager(踏み台不要)。IAP TCP forwarding はその GCP 版にあたる。
違いは前提条件で、SSM は SSM Agent と VM 用のIAMロールが要り、NAT が無ければ VPCエンドポイントも要る。
IAP は 35.235.240.0/20 からの tcp:22 を許可するだけで済む。

---

### S07 | VPCがグローバル

**[図版]** **新規作成**。左右比較図。左 AWS「リージョンごとにVPC」、右 GCP「VPCは1つ」。

```
   AWS  リージョンごとにVPC          GCP  VPCは1つ
 ┌ 東京 ────┐ ┌ 大阪 ────┐   ┌ VPC(グローバル・CIDRを持たない) ─────┐
 │  VPC      │ │  VPC      │   │ ┌ 東京 subnet ──┐ ┌ 大阪 subnet ──┐ │
 │  subnet   │ │  subnet   │   │ │ 172.16.0.0/24  │ │ 172.17.0.0/24  │ │
 └───────┘ └───────┘   │ └────────┘ └────────┘ │
    └─ VPCピアリングを張る必要がある ─┘   └─ 同じVPC内のプライベートIPで直接通信できる ─┘
```

**[本文]**

```
◼GCPのVPCの特徴
VPCの設定変更は全リージョンに効く
サブネットのCIDRはVPC全体で重複できない
```

**[話す]** VPCはグローバルリソース。リージョンを指定せず、CIDRも持たない(CIDRを持つのはサブネット)。
1つのVPCに世界中のリージョンのサブネットを入れられるので、
東京と大阪のサーバが、同じVPC内のプライベートIPで直接通信できる。
AWSならVPCを2つ作ってピアリングを張る必要がある。
気をつけるのは「東京だけ壊す」ができないこと。VPCの設定変更は全リージョンに効く。

今日の宿題2-2で、大阪リージョンにサブネットを足してもらう。
VPCを作り直さずに足せることを体感してほしい。

---

### S08 | サブネットがリージョン単位

**[図版]** **新規作成**。左右比較図。左 AWS は ap-northeast-1 の枠の中に AZ 1a / AZ 1c を並べ、
それぞれに web / db / cache subnet(計6つ)。右 GCP は asia-northeast1 の枠に
web / db / cache subnet を1つずつ(計3つ)。

**[本文]**

```
AWS  サブネットは AZ 単位
  冗長化のため AZ ごとに作る → 6つ

GCP  サブネットはリージョン単位
  asia-northeast1  (-a / -b / -c にまたがる)
  サブネットは増やさない → 3つ
```

**[話す]** AWSなら、AZごとに web1/web2, db1/db2, cache1/cache2 と6つ作る。
GCPでは3つで済む。今日の宿題で実際にやってもらう。

(スライドには載せていない補足)1つのサブネットが asia-northeast1-a / -b / -c 全部にまたがるので、
冗長化のためにサブネットを増やす必要はなく、VMを別ゾーンに置けばよい。
GCPのサブネットはCIDRを後から拡張できる(172.16.0.0/24 → 172.16.0.0/22。縮小は不可)。

---

### S09 | public / private という区別はない

**[図版]** 新規。同じサブネットに置かれた2台のVM。片方に外部IPのバッジが付いている。

**[本文]**

```
◼AWSの public subnet / private subnet
「Internet Gatewayへのルートを持つルートテーブルが紐づいているか」で決まっていた

◼GCPには そもそもその区別がない
全てのサブネットが、VPCの暗黙のデフォルトルートを共有している

インターネットに出られるかどうかを決めるのは以下の2点
  1. VMが外部IPを持っているか
  2. Cloud NAT があるか


   ハンズオンで public-subnet / private-subnet という名前を付けるが、
   これは 運用上の目印 でしかない
   同じサブネットに外部IPありとなしのVMを混在させることもできてしまう
```

**[話す]** ここはAWS経験者ほど引っかかる。
「private subnetに置いたのにインターネットに出られてしまった」という事故は、
VMに外部IPを付けたのが原因。組織ポリシーで外部IPの付与自体を禁止する運用もある。
2点目の Cloud NAT が効くのは、外部IPを持たないVMだけ(外部IPがあればそのまま出られる)。

---

### S10 | Firewall Rules は Security Group とは別物

**[図版]** **新規作成**。この回の最重要図その1。左右比較。

```
   AWS  Security Group               GCP  VPC Firewall Rules

  ┌─ SG: web ──────┐               ┌─ allow-http ─────────────────┐
  │ ingress tcp:80  │               │ target_tags   = ["web"]       │
  └─────────┘               │ source_ranges = ["0.0.0.0/0"] │
        ↑                            └──────────────────────┘
     [EC2 web]                              ↓
                                       [VM  tags = ["web"]]
  ┌─ SG: db ───────┐
  │ ingress tcp:3306│  ← SG が SG を参照できる
  │ from SG: web    │               ┌─ allow-mysql ─────────────────────────┐
  └─────────┘               │ source_service_accounts = [web-sa]    │
        ↑                           │ target_service_accounts = [db-sa]     │
     [EC2 db]                       └───────────────────────────┘
                                     参照するのはタグ or サービスアカウント
```

**[本文]**

```
SG が SG を参照できる

参照するのはタグ or サービスアカウント

AWSで「SGからSGへ」と書いていた部分は「タグからタグへ」または「SAからSAへ」に書き換える
```

**[話す]** Security Group はリソースに「貼り付ける」壁、Firewall Rules は VPC に「並べる」ルール。
どのVMに効かせるかを タグ / サービスアカウント で指定する。
SG同士の参照に相当するものは無いので、「SGからSGへ」はタグかSAに書き換える。
これがGCPのネットワークで一番の書き換えポイント。
第4回(DB)、第5回(コンテナ)でも同じ書き方が出てくるので、ここで身につけてほしい。

---

### S11 | Internet Gateway が無い

**[図版]** 図なし。テキストのみで AWS と GCP を対比する。

**[本文]**

```
◼AWS
VPCにInternet Gatewayをアタッチし、
ルートテーブルに 0.0.0.0/0 → IGW を書いて、
サブネットにルートテーブルを紐づける

◼GCP
VPCを作った時点で
  0.0.0.0/0 → デフォルトインターネットゲートウェイというルートが自動で作られている

  → 作るものが無い
  → 外部IPを持つVMは、何もしなくてもインターネットに出られる
```

**[話す]** AWSでは3ステップ(アタッチ・ルート追加・紐づけ)かかる作業が、GCPでは0ステップ。

---

### S12 | 踏み台サーバが要らない

**[図版]** **新規作成**。この回の最重要図その2。左にAWS(SSM Session Manager)、
右にGCP(IAP TCP forwarding)を並べて描く。どちらも踏み台は要らない、という図。
右側の図の下に「VMには IAP から 35.235.240.0/20 の送信元で届く」の注記を置く。

```
   AWS  SSM Session Manager           GCP  IAP TCP forwarding
 [自分] --IAM--> [SSM]              [自分] --IAP--> [private VM]
                   |
                   +--> [private VM]
```

**[本文]**

```
◼AWS
・鍵の配布が要らない / 22番も開けない
・IAMで制御。CloudTrailなどに残る
・SSM Agent と IAMロールが要る
・privateでは NAT か VPCエンドポイントが要る

◼GCP
VMには IAP から 35.235.240.0/20 の送信元で届く
→ このレンジからの tcp:22 だけを許可すればよい

・鍵の配布が要らない(OS Login)
・外部に22番を開けない
・IAMで制御。Cloud Loggingに残る

どちらも「誰がどのVMに入ってよいか」をIAMで書く
```

**[話す]** AWS では以前は踏み台 + SSH鍵が定番だったが、今の推奨は SSM Session Manager で、
踏み台も鍵も要らない。IAP はその GCP 版と考えればよい。
違いは前提条件。SSM は SSM Agent と VM 用のIAMロールが要り、privateなら NAT か VPCエンドポイントも要る。
IAP は 35.235.240.0/20 からの tcp:22 を Firewall で許可するだけ。
どちらも「入れる/入れない」がIAMで決まるので、権限設計の話になる。
これは前回やったIAMがそのまま効いてくるところ。

IAP TCP forwarding は、Googleのフロントエンドを経由して、外部IPを持たないVMへトンネルを張る仕組み。
自分から IAP までは普通のHTTPS で、35.235.240.0/20 になるのは IAP から VM への接続の送信元。
踏み台サーバは作らない方針(AWSでもGCPでも踏み台レスが推奨構成)。
その代わり「誰がどのVMに入ってよいか」をIAMで書く権限設計が重要になる。

---

# 準備

---

### S13 | ハンズオンの準備

**[図版]** AWS版 第3回「準備」2枚を流用。コマンドを差し替え。

**[本文]**

```
◼Cloud Shell を立ち上げる
  プロジェクトが [プロジェクトID] になっていることを確認
  gcloud config get-value project
  (違うなら) gcloud config set project [プロジェクトID]

◼作業ディレクトリを作る
  mkdir -p ~/works/lesson2
  cd ~/works/lesson2

◼サンプルコードを更新
  cd ~/infra-study && git pull
  cd ~/works/lesson2

  サンプル: ~/infra-study/gcp/lesson2/
```

**[話す]** 前回作ったtfstateバケットをそのまま使う。
common.tf の backend の prefix が `lesson2` になっていることを確認すること。

**★ この確認を飛ばすと Step1 の確認コマンドで止まる。**
Terraform は `var.project_id` でプロジェクトを渡すので、gcloud の既定プロジェクトが未設定でも apply は通る。
しかし `gcloud compute networks list` など以降の gcloud コマンドは既定プロジェクトを見に行くため、
`The required property [project] is not currently set.` で失敗する(2026-10-16 に検証中に発生)。
Cloud Shell は、起動時にコンソールでプロジェクトを選んでいた場合だけ既定プロジェクトを自動で設定する。
`shell.cloud.google.com` を直接開いた場合などは未設定のまま起動する。

(スライドには載せていない補足)前回の設定が残っているかも確認する
(`echo $GOOGLE_CLOUD_QUOTA_PROJECT` で何も出なければOK)。
何か出た人は ~/.bashrc に追記してもらう(第1回 S66)。
`echo 'unset GOOGLE_CLOUD_QUOTA_PROJECT' >> ~/.bashrc && source ~/.bashrc`

今日のステップ: 1. vpc / 2. subnet / 3. instance / 4. firewall / 5. firewall_internal /
6. private_google_access / 7. cloud_nat

---

# VPC

---

### S13-2 | VPC(セクション区切り)

**[本文]**

```
VPC
```

---

### S14 | VPC とは

**[図版]** AWS版 第3回「VPC」のテキストスライドを流用しつつ、
「リージョンに作る」「CIDRを設定する」の記述を差し替える。

**[本文]**

```
◼VPC (Virtual Private Cloud)
GCP上に作るプライベートなネットワーク空間

グローバルリソース。リージョンを指定しない
VPC自体はCIDRを持たない。CIDRを持つのはサブネット
VPC内はプライベートIPで相互アクセス可能

◼デフォルトVPCについて
新しいプロジェクトには default という名前のVPCが最初からある
全リージョンにサブネットが自動生成され、SSH/RDP/ICMPが最初から開いている

※ 本番では使わない。自分で1から作る(AWSのdefault VPCも、本番では使わない)
```

---

### S15 | VPC の Terraform コード

**[図版]** AWS版 第3回「VPC」のコードスライドを流用。コードを差し替え。

**[本文]**

```
cd ~/works/lesson2/ && cp -rf ~/infra-study/gcp/lesson2/1.\ vpc/ ./

resource "google_compute_network" "vpc" {
  name = "${var.user_name}-vpc"

  // 各リージョンにサブネットを自動生成しない
  auto_create_subnetworks = false

  // REGIONAL: 同一リージョンのサブネット同士のみルートを共有(デフォルト)
  // GLOBAL  : 全リージョン間でルートを共有
  routing_mode = "REGIONAL"
}

※ auto_create_subnetworks = false を忘れると
   全リージョンにサブネットが勝手に作られる
```

**[話す]** (スライドには載せていない補足)cidr_block が無い。
AWSの resource "aws_vpc" には cidr_block = "172.16.0.0/16" を書く項目があるが、
GCPのVPCには相当する項目が存在しない(CIDRはサブネットが持つ)。

---

### S16 | Step1 実行

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼確認(主な項目のみ抜粋)
  gcloud compute networks list --filter="name:[自分の名前]-vpc"
  NAME: [自分の名前]-vpc
  SUBNET_MODE: CUSTOM
  BGP_ROUTING_MODE: REGIONAL

◼自動で作られたルートを見てみる(主な項目のみ抜粋)
  gcloud compute routes list --filter="network:[自分の名前]-vpc"
  NAME: default-route-xxxx
  DEST_RANGE: 0.0.0.0/0
  NEXT_HOP: default-internet-gateway
```

**[話す]** サブネットを1つも作っていないのに、もうインターネットへのルートがある。
これがAWSでいうInternet Gateway + ルートテーブルに相当する。
GCPは最初から入っているので、作る作業が無い。

出力は「項目名: 値」の縦並びで出る(2026-10-16 に実機で確認)。スライドは主な項目だけを抜粋している。
networks list は、この下に値が空の `IPV4_RANGE` / `GATEWAY_IPV4` / `INTERNAL_IPV6_RANGE` が続く。
routes list は、`NAME` の下に `NETWORK`(自分のVPC名)と `PRIORITY: 1000` も出る。
NAME の `default-route-` に続く文字列は人によって違う。

---

# サブネット

---

### S17-2 | サブネット(セクション区切り)

**[本文]**

```
サブネット
```

---

### S18 | サブネットとは

**[図版]** AWS版 第3回「サブネットワーク」のテキストスライドを流用し、
「ゾーン(AZ)を指定して配置」→「リージョンを指定して配置」に差し替え。

**[本文]**

```
◼サブネット
VPCの中を分割した小さなネットワーク

リージョンを指定して配置する
同一VPC内でCIDRは重複できない

◼IPアドレスの予約
GCPは各サブネットで4つのIPを予約する
  ネットワークアドレス / デフォルトゲートウェイ / 末尾2つ

  172.16.0.0/24 → 使えるのは 250個(AWSは5つ予約なので 251個 だった)
```

**[話す]** (スライドには載せていない補足)リージョンを指定して配置する、の部分は「ゾーンではない」と添える。
CIDRを持つのはVPCではなくこちら(サブネット)。

---

### S19 | CIDR設計

**[図版]** AWS版 第1回「IPアドレス」のIPクラス表を流用。

**[本文]**

```
◼この勉強会のCIDR

VPC          (CIDRなし)
  public      172.16.0.0/24    asia-northeast1
  private     172.16.10.0/24   asia-northeast1

◼設計の考え方
用途ごとにレンジを分ける
将来増えるものを見越して間を空けておく
拡張はできるが縮小はできないので、最初は小さめに切る

  172.16.0.x    public
  172.16.10.x   private
  172.16.20.x   web    ← 今日の宿題
  172.16.40.x   db     ← 今日の宿題
  172.16.50.x   cache  ← 今日の宿題
  172.16.100.x  大阪    ← 今日の宿題
```

> **未決**: CIDRの標準化ルール(設計書 10章)。
> AWS版は社内の標準化スプレッドシートを参照していた。GCP版の扱いを決める。

---

### S20 | サブネットの Terraform コード

**[図版]** AWS版 第3回「サブネットワーク」のコードスライドを流用。コードを差し替え。
**AWSの `count` + `availability_zone` の書き方が消えることを強調する**。

**[本文]**

```
cd ~/works/lesson2/ && cp -rf ~/infra-study/gcp/lesson2/2.\ subnet/ ./

variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}

resource "google_compute_subnetwork" "public" {
  name          = "${var.user_name}-public-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast1"
  ip_cidr_range = var.subnet_public_cidr
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.user_name}-private-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast1"
  ip_cidr_range = var.subnet_private_cidr
}
```

**[話す]** (スライドには載せていない補足)availability_zone も count も無い。
AWSはAZごとに作るので count でAZ分ループするが、GCPは1リージョン1つでよい。

---

### S21 | Step2 実行

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼確認
  gcloud compute networks subnets list --filter="network:[自分の名前]-vpc"
  NAME: [自分の名前]-public-subnet
  REGION: asia-northeast1
  RANGE: 172.16.0.0/24

  NAME: [自分の名前]-private-subnet
  REGION: asia-northeast1
  RANGE: 172.16.10.0/24

◼ルートが増えているのを確認
  gcloud compute routes list --filter="network:[自分の名前]-vpc"

  → サブネットを作ると、そのCIDR宛のルートが自動で追加される
    AWSのようにルートテーブルを作って紐づける作業は無い
```

**[話す]** 出力は「項目名: 値」の縦並びで、サブネットごとに空行で区切られる。スライドは主な項目だけを抜粋している。
subnets list は、この下に `NETWORK`(自分のVPC名)や `STACK_TYPE: IPV4_ONLY` なども出る。
routes list は、サブネットのCIDR宛(`DEST_RANGE: 172.16.0.0/24` など)のルートが2本増えている。

---

# インスタンス

---

### S22-2 | インスタンス(セクション区切り)

**[本文]**

```
インスタンス
```

---

### S23 | 今日使うインスタンス

**[図版]** S05のゴール図から、VM2台の部分だけを抜き出したもの。

**[本文]**

```
◼2台作ります

  web    public subnet   外部IP あり   e2-micro
  db     private subnet  外部IP なし   e2-micro

◼この2台で確かめること
1. 外部IPがあってもSSHは通らない(Firewall Ruleが無いから)
2. 外部IPが無くてもIAPなら入れる
3. 外部IPがある方はインターネットに出られる
4. 外部IPが無い方は出られない → Cloud NATが要る
```

**[話す]** (スライドには載せていない補足)コンピューティングの詳細は次回やる。今日はネットワークの確認に使うだけ。

---

### S24 | ネットワークタグとサービスアカウント

**[図版]** 新規。VM1台の絵に、タグのラベルとサービスアカウントのバッジを付ける。

**[本文]**

```
◼ネットワークタグ
VMに付ける ただの文字列ラベル
Firewall Ruleの適用先を指定するのに使う

  tags = ["[自分の名前]-web"]

◼サービスアカウント
VMに紐づけるID
Firewall Ruleの適用先にも使えるし、
VMからGCPのAPIを叩くときの認証にも使う

  service_account {
    email = google_service_account.web.email
  }

◼どちらを使うか
タグ  : 手軽。ただしVMを編集できる人なら誰でも付けられる
SA    : 付け替えにIAM権限が要るので堅い。本番はこちら
```

**[話す]** タグは便利だが「タグを付ければ通れてしまう」という穴がある。
本番の重要な経路はサービスアカウントで縛るのが定石。

(スライドには載せていない補足)今日は両方使う。

---

### S25 | インスタンスの Terraform コード

**[図版]** AWS版 第3回「踏み台サーバ作成」のコードスライドを流用。コードを差し替え。
**`key_name` が消えることを強調する**。

**[本文]**

```
cd ~/works/lesson2/ && cp -rf ~/infra-study/gcp/lesson2/3.\ instance/ ./

resource "google_compute_instance" "web" {
  name         = "${var.user_name}-web"
  machine_type = "e2-micro"
  zone         = "asia-northeast1-a"

  tags = ["${var.user_name}-web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id
    access_config {}          // ← これがあると外部IPが付く
  }

  metadata = {
    enable-oslogin = "TRUE"   // ← SSH鍵の配布が要らなくなる
  }

  service_account {
    email  = google_service_account.web.email
    scopes = ["cloud-platform"]
  }
}
```

**[話す]** (スライドには載せていない補足)★ `key_name` が無い。
SSH鍵のペアを指定しなくてよい(AWSでも SSM Session Manager なら不要)。
GCPは OS Login が鍵の配布を代替する。AWSなら `iam_instance_profile` が要る。

---

### S26 | db インスタンスとの違い

**[本文]**

```
resource "google_compute_instance" "db" {
  ...
  network_interface {
    subnetwork = google_compute_subnetwork.private.id

    // access_configブロックを書かない = 外部IPなし
  }
  ...
}

違いはこれだけ
  「privateサブネットに置いたから外部IPが無い」のではなく
  「access_configを書かなかったから外部IPが無い」
```

**[話す]** (スライドには載せていない補足)これは S09 で話した「public/privateの区別は無い」の実例。

---

### S27 | Step3 実行

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼確認(主な項目のみ抜粋)
  gcloud compute instances list --filter="name:[自分の名前]"
  NAME: yamada-taro-web
  ZONE: asia-northeast1-a
  INTERNAL_IP: 172.16.0.2
  EXTERNAL_IP: 34.xx.xx.xx
  STATUS: RUNNING

  NAME: yamada-taro-db
  ZONE: asia-northeast1-a
  INTERNAL_IP: 172.16.10.2
  EXTERNAL_IP:
  STATUS: RUNNING

  dbには EXTERNAL_IP が無いことを確認
```

**[話す]** 出力は「項目名: 値」の縦並びで、VMごとに空行で区切られる。スライドは主な項目だけを抜粋している。
実際には `MACHINE_TYPE`(e2-micro)や `PREEMPTIBLE`(空)も出る。
外部IPが無いVMは、`EXTERNAL_IP:` の右が空になる。

---

### S28 | SSHしてみる → 繋がらない

**[図版]** ターミナルの失敗出力2種を貼る。
**スクリーンショットは不要**(2026-09-18 判断)。文言は本文に載せてあり、当日は受講者の画面に実物が出る。
右側の空きに黄色の吹き出しを2つ置く(第1回の吹き出しと同じ体裁。objectId は `note_ssh_key` / `note_ssh_timeout`)。
文言は次のとおり。

```
★ 初回だけ SSH 鍵の生成を聞かれます
Y のあと、パスフレーズは空のまま
Enter を 2 回押してください

★ --ssh-flag は待ち時間を
10秒に縮める指定です
(①②とも、無いと 2 分ほど待ちます)
```

**[本文]**

```
◼① 外部IPを持つ web に、普通にSSHしてみる

  gcloud compute ssh [自分の名前]-web --zone=asia-northeast1-a \
    --ssh-flag="-oConnectTimeout=10"

  Connection timed out
  ERROR: (gcloud.compute.ssh) [/usr/bin/ssh] exited with return code [255].

  外部IPはある。でもFirewall Ruleが無い
  GCPのカスタムVPCは、ingressが全部拒否 が初期状態


◼② 外部IPを持たない db に、IAP経由でSSHしてみる

  gcloud compute ssh [自分の名前]-db --zone=asia-northeast1-a \
    --tunnel-through-iap --ssh-flag="-oConnectTimeout=10"

  Connection timed out during banner exchange
  ERROR: (gcloud.compute.ssh) [/usr/bin/ssh] exited with return code [255].

  IAPのトンネルは張れても、その先の 22番 が閉じている

-> ということで、経路と権限を作っていきます
```

**[話す]** 「作った → 繋がらない → なぜ繋がらないかを理解する → 足す → 繋がる」
このリズムで進める。

`--ssh-flag="-oConnectTimeout=10"` は待ち時間を縮めるための指定。
付けないと、①は接続の再送を繰り返すので、タイムアウトまで 2 分ほど待たされる。
受講者が待ちきれず Ctrl+C を押してしまうので、先に付けておく。
初めて `gcloud compute ssh` を打つ Cloud Shell では SSH 鍵の生成が始まる(吹き出しの内容)。

②のエラーは人によって変わる。IAPを使う権限(`roles/iap.tunnelResourceAccessor`)を
組織やプロジェクトのグループから既に継承している人は、上のようにタイムアウトになる。
継承していない人は、トンネルを張る手前で権限エラーになる。

  ERROR: ... 4033: 'not authorized'

どちらのエラーが出たかで「どのゲートで止まっているか」が分かる、と伝える。
このあとのS35「3つのゲート」への導入にできる。

> **検証済み(2026-08-28)**: `[プロジェクトID]` の実環境で①②とも上記のタイムアウトを確認。
> 講師アカウントはIAP権限を継承していたため②もタイムアウトになった。
> 受講者の権限次第で②の表示が変わるので、当日は両方のパターンを想定しておくこと。

> **検証済み(2026-10-16)**: `--ssh-flag="-oConnectTimeout=10"` を付けて Cloud Shell で実行し、①②とも約10秒でタイムアウトすることを確認。
> 実際の出力はスライドより長い。①は `ssh: connect to host <外部IP> port 22: Connection timed out`、
> ②は `Connection timed out during banner exchange` の次に `Connection to UNKNOWN port 65535 timed out` が出る。
> どちらも、その後に `--troubleshoot` を勧める `Recommendation:` の数行が続き、最後に `ERROR: ... exited with return code [255].` で終わる。
> スライドは `Connection timed out` と `ERROR:` の行だけを抜粋している。

---

# Firewall Rules と IAP

---

### S29-2 | Firewall Rules と IAP(セクション区切り)

**[本文]**

```
Firewall Rules と IAP
```

---

### S30 | Firewall Rules とは

**[図版]** AWS版 第3回「セキュリティグループ」のテキストスライドを流用しつつ、
「VPC内であればセキュリティグループ同士のアクセス制御が可能」の行を
**削除して差し替える**(GCPではできないため)。

**[本文]**

```
◼VPC Firewall Rules
VPCに設定する通信制御のルール

VPC単位で定義する(リソースにアタッチするのではない)
どのVMに効かせるかは「ネットワークタグ」か「サービスアカウント」で指定
ステートフル(戻りの通信は自動で許可される)
INGRESS(受信)と EGRESS(送信)がある

◼優先度(priority)
0 〜 65535。小さいほど優先。デフォルトは1000
同じ通信に複数のルールが該当したら、priorityが小さい方が勝つ
```

---

### S31 | 暗黙のルール

**[図版]** 新規。VPCの箱の外周に、点線で「暗黙のルール」を描く。

**[本文]**

```
◼VPCを作ると、書かなくても存在するルールが2つある

  暗黙の ingress 拒否   priority 65535
    外から中への通信は、全部拒否

  暗黙の egress 許可    priority 65535
    中から外への通信は、全部許可

  ルールを1つも書いていない今の状態 = 全部拒否
   -> だからさきほどSSHがタイムアウトした


※ ただしdefault VPCには最初から穴が開いているので注意
  (default-allow-ssh / default-allow-icmp などが定義済み)
  → 今回はカスタムVPCなので、その穴は無い
```

(スライドには載せていない補足)この2つのルールは削除できない。AWSのSGも「ingressデフォルト拒否 / egressデフォルト許可」で同じ考え方。

---

### S32 | 適用先の指定方法

**[本文]**

```
◼INGRESSルールで指定するもの

  誰から          source_ranges            IPレンジ
                 source_tags              ネットワークタグ
                 source_service_accounts  サービスアカウント

  誰に            target_tags              ネットワークタグ
                 target_service_accounts  サービスアカウント

  何を            allow { protocol / ports }
                  deny  { protocol / ports }

◼制約
  1つのルールの中で タグ と サービスアカウント は混在できない
  source_tags と source_service_accounts も同時に書けない

  → 「タグで統一する」か「SAで統一する」かを決めてから書く
```

(スライドには載せていない補足)target を省略すると、VPC内の全VMに効く。

(スライドには載せていない補足)AWSのSGとの書き換え(元 S33。スライドは削除した)。
ここが今日の一番のポイント。
AWSでは「SGを作って、そのSGにルールを足す」という2段構えだったが、
GCPは「ルールそのもの」が1つのリソースになる。
そして許可元をSGではなくタグかSAで書く。

---

### S34 | IAP TCP forwarding とは

**[図版]** S12の右側の図を再掲。

**[本文]**

```
◼IAP (Identity-Aware Proxy) TCP forwarding
Googleのフロントエンドを経由してVMへトンネルを張る仕組み

  [Cloud Shell] → Google のフロントエンド → [VM の 22番]
                        ↑
                  ここでIAMをチェックする

◼VMから見ると
35.235.240.0/20 という固定レンジからの通信に見える
→ このレンジからの tcp:22 だけ開ければよい

◼メリット
外部IPが不要
インターネットに22番を晒さない
誰が入ったかがCloud Loggingに残る
踏み台VMのコストと管理が消える
```

---

### S35 | IAPで入るための3つのゲート ★

**[図版]** **新規作成**。3つの門が縦に並んでいる図。
左に「3つとも通る必要がある / どれか1つでも欠けると入れない」、右に「①はネットワーク / ②③は IAM / 層が違う」の注記。

```
 [自分]
   ↓  ① ネットワークの許可     Firewall Rule
   ↓                          35.235.240.0/20 からの tcp:22
   ↓  ② トンネルを張る権限     roles/iap.tunnelResourceAccessor
   ↓                          IAPでこのVMに繋いでよいか
   ↓  ③ OSにログインする権限   roles/compute.osAdminLogin
   ↓                          + roles/iam.serviceAccountUser
   ↓                          OSユーザとしてログインしてよいか / VMのSAを使ってよいか
 [VM の shell]
```

**[話す]** 前回やったIAMがここで効いてくる。
「ネットワークで許可したのに入れない」ときは、だいたい②か③が足りていない。
逆に「IAMは付いているのにタイムアウトする」なら①が足りていない。
エラーの種類で切り分けられる。

(スライドには載せていない補足)AWSの SSM は「IAMの許可 + SSM Agent」で入れた。GCPのIAPは3つのゲートを全部通る必要がある。
osAdminLogin は sudo 付きでログインできる権限。serviceAccountUser は、VMに付いているサービスアカウントを使ってよいか、という権限。

---

### S36 | Firewall Rule の Terraform コード

**[本文]**

```
cd ~/works/lesson2/ && cp -rf ~/infra-study/gcp/lesson2/4.\ firewall/ ./

// ① ファイアーウォール設定
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.user_name}-allow-iap-ssh"
  network = google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]
  target_tags = [
    "${var.user_name}-web",
    "${var.user_name}-db",
  ]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
```

(スライドには載せていない補足)★ ここでは適用先を ネットワークタグ で指定している(VMの `tags = [...]` と対応)。

---

### S37 | IAM の Terraform コード

**[本文]**

```
data "google_client_openid_userinfo" "me" {}

// ② IAPトンネルを張る権限(インスタンス単位)
resource "google_iap_tunnel_instance_iam_member" "db" {
  zone     = google_compute_instance.db.zone
  instance = google_compute_instance.db.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = "user:${data.google_client_openid_userinfo.me.email}"
}

// ③ OSにログインする権限(インスタンス単位)
resource "google_compute_instance_iam_member" "db_os_login" {
  zone          = google_compute_instance.db.zone
  instance_name = google_compute_instance.db.name
  role          = "roles/compute.osAdminLogin"
  member        = "user:${data.google_client_openid_userinfo.me.email}"
}

// ③ VMのサービスアカウントを使う権限(SA単位)
resource "google_service_account_iam_member" "db_sa_user" {
  service_account_id = google_service_account.db.name
  role               = "roles/iam.serviceAccountUser"
  member             = "user:${data.google_client_openid_userinfo.me.email}"
}
```

> **★ 講師メモ ★** `data "google_client_openid_userinfo"` は
> Cloud Shell が立てる `GOOGLE_CLOUD_QUOTA_PROJECT` があると
> 403 で失敗し、**プロバイダがそれを握りつぶして null を返す**。
> 第1回 S66 で `~/.bashrc` に `unset` を書かせてあるので通常は起きないが、
> **Cloud Shell のホームが作り直された人は再発する**
> (120日アクセスが無いと消える)。
> 原因と詳細は第1回 S66 の講師メモ。

(スライドには載せていない補足)★ 全部 インスタンス単位 / SA単位 で付けている。前回話した「共有プロジェクトでプロジェクトIAMを触らない」の実践。
★ `email is null` のエラーが出たら、第1回でやった `unset GOOGLE_CLOUD_QUOTA_PROJECT` を実行する(第1回の `~/.bashrc` の設定を忘れた人が踏む)。

---

### S38 | Step4 実行 → SSH成功

**[図版]** なし。**スクリーンショットは不要**(2026-09-18 判断)。文言は本文に載せてあり、当日は受講者の画面に実物が出る。

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼外部IPを持たない db に入ってみる

  gcloud compute ssh [自分の名前]-db --zone=asia-northeast1-a --tunnel-through-iap

  [自分の名前]_sumzap_co_jp@[自分の名前]-db:~$

-> 踏み台を作らずに、外部IPを持たないVMに入れた
-> SSH鍵も配っていない(OS Loginが自動で鍵を配置している)

◼webにも同じ方法で入れる
  gcloud compute ssh [自分の名前]-web --zone=asia-northeast1-a --tunnel-through-iap

  → 外部IPがあっても、IAP経由で入る方が安全 (外部に22番を開けなくて済む)
```

**[話す]** IAMの反映に時間がかかることがある。すぐ通らなければ1分ほど待って再実行。

---

### S39 | web から db へ通信してみる → 繋がらない

**[本文]**

```
◼webに入って、dbにpingを打ってみる

  gcloud compute ssh [自分の名前]-web --zone=asia-northeast1-a --tunnel-through-iap

  (web の中で)
  ping -c 3 [自分の名前]-db   → 応答なし(100% packet loss)

  ※ VM名は VPC内のDNSが内部IPに引いてくれる

◼なぜか
VPC内はプライベートIPで到達できる経路にある
しかし ICMPを許可するFirewall Ruleが無い
暗黙の ingress 拒否 に引っかかっている
```

**[話す]** IPアドレスではなく VM名 で打つ。同じプロジェクトのVM同士なら、VPC内のDNSが名前を内部IPに引いてくれる
(実機で確認済み(2026-10-16): `PING <VM名>.c.<プロジェクトID>.internal (172.16.10.2)` と表示される)。
IPで打つと、db の内部IPが `172.16.10.2` と違う人(VMを作り直した人など)が詰まる。
db の内部IPが気になる人は `gcloud compute instances list` で確認できる。

(スライドには載せていない補足)AWSのSecurity Groupでも同じことが起きる。「経路はあるのに、許可していないのでタイムアウト」で、原因も同じ(ファイアウォールで許可していない)。違うのは許可の書き方。

---

### S40 | サービスアカウントで許可元を指定する

**[本文]**

```
cd ~/works/lesson2/ && cp -rf ~/infra-study/gcp/lesson2/5.\ firewall_internal/ ./

resource "google_compute_firewall" "allow_web_to_db" {
  name    = "${var.user_name}-allow-web-to-db"
  network = google_compute_network.vpc.name

  direction = "INGRESS"
  priority  = 1000

  source_service_accounts = [google_service_account.web.email]
  target_service_accounts = [google_service_account.db.email]

  allow {
    protocol = "icmp"
  }
}
```

**[話す]** (スライドには載せていない補足)★ AWSの `source_security_group_id` に相当するのがこれ。
★ タグでも同じことが書けるが、タグはVMを編集できる人なら誰でも付けられてしまう。
SAの付け替えにはIAM権限が要るので、こちらの方が堅い。

---

### S41 | Step5 実行 → 疎通成功

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼もう一度 web から ping

  gcloud compute ssh [自分の名前]-web --zone=asia-northeast1-a --tunnel-through-iap  ping -c 3 [自分の名前]-db

  64 bytes from ... (172.16.10.2): icmp_seq=1 ttl=64 time=0.5 ms
  3 packets transmitted, 3 received, 0% packet loss
```

**[話す]** (スライドには載せていない補足)★ 通った。
`64 bytes from` の後ろは、実際には VM の FQDN
(`<VM名>.c.<プロジェクトID>.internal`)が入る。スライドは `...` で省略している。
実機で確認済み(2026-10-16): 3 packets transmitted, 3 received, 0% packet loss。往復は 0.3〜1.6 ms ほど。

---

### S42 | ワンポイント: 許可されていない経路も確認する

**[本文]**

```
◼db から web に ping を打ってみる

  (db の中で)
  ping -c 3 [自分の名前]-web

  → 応答なし

◼なぜか
書いたルールは「web(SA) から db(SA) への ICMP」だけ
逆方向は許可していない

★ Firewall Rules はステートフルなので
   「webからのpingの戻り」は自動で通る
   しかし「dbから始まる通信」は別物として拒否される

  → AWSのSGと同じ考え方
```

**[話す]** 時間が押していたらここは飛ばしてよい。
ただ「ステートフル」の意味を体で分かってもらうにはよい実験。

---

### S43 | Firewall Rules まとめ

**[図版]** S10の比較図を再掲。

**[本文]**

```
◼今日書いた2つのルール

allow-iap-ssh
  from  35.235.240.0/20 (IAPの固定レンジ)
  to    ネットワークタグ web / db
  what  tcp:22

allow-web-to-db
  from  サービスアカウント web
  to    サービスアカウント db
  what  icmp

◼覚えて帰ること
適用先はタグかSAで指定する。1つのルールで混在はできない
```

**[話す]** (スライドには載せていない補足)Firewall RuleはVPCに並ぶ。リソースには貼らない。
SG同士の参照に相当するのは `source_service_accounts` / `source_tags`。

---

# Routes と Private Google Access

---

### S43-2 | Routes と Private Google Access(セクション区切り)

**[本文]**

```
Routes と Private Google Access
```

---

### S44 | Routes

**[図版]** AWS版 第3回「ルートテーブル」の図を流用し、
「サブネットに紐づける」矢印を消して「VPC全体に効く」に描き換える。

**[本文]**

```
◼GCPのルート
  VPC単位。サブネットには紐づけない

◼自動で作られるルート
  サブネットルート      各サブネットのCIDR宛
  デフォルトルート      0.0.0.0/0 → デフォルトインターネットゲートウェイ

◼自分で作る必要があるルート
  オンプレとのVPN接続、特定の宛先を別のVMに向ける、など
```

**[話す]** 押していたらここは口頭だけでよい。
「ルートテーブルの作業が要らない」ということだけ伝われば十分。

(スライドには載せていない補足)
- サブネットルートはサブネット作成時に自動で作られる。
- 自分で作るルートは今日は作らない。
- AWSでは「ルートテーブルを作る → サブネットに紐づける」を public / private の2セット書く必要があった。GCPではこの作業が丸ごと無くなる。

---

### S45 | db から Google API を叩いてみる → 繋がらない

**[本文]**

```
◼db に入って、Cloud Storage を叩いてみる

  gcloud compute ssh [自分の名前]-db --zone=asia-northeast1-a --tunnel-through-iap

  (db の中で)
  curl -m 10 -I https://storage.googleapis.com   → タイムアウト

◼なぜか
dbには外部IPが無い
デフォルトルート(0.0.0.0/0 → インターネットゲートウェイ)は存在するが、外部IPを持たないVMはそこを通れない
```

**[話す]** (スライドには載せていない補足)
- おもしろいところ: db の中で `gcloud auth print-access-token` は通る。メタデータサーバ(169.254.169.254)はリンクローカルなので、ネットワークの外に出なくてもアクセスできる。
- 「認証は通るのに、APIが叩けない」。この状態の切り分けができると障害対応が早くなる。

---

### S46 | Private Google Access

**[図版]** **新規作成**。AWSには対応する図がないので描き起こす。
左に「外部IPなしのVM」、右に PGA なし(インターネットへ ✕)と PGA あり(Google API のみ ○)の2経路。
左下に「サブネット単位で有効/無効を切り替える / Cloud NAT を立てずに Google API に到達できる」、
図の下に AWS との比較の1行を置く。

```
  外部IPなしのVM
      │
      ├─ (PGA なし) ──✕── インターネット
      │
      └─ (PGA あり) ──○── Google API のみ
                            storage.googleapis.com
                            secretmanager.googleapis.com
                            logging.googleapis.com ...

  サブネット単位で
  有効/無効を切り替える

  Cloud NAT を立てずに
  Google API に到達できる

  AWSのVPCエンドポイントに近いが、GCPはサブネットのフラグ1つで全Google APIが対象になる
```

**[話す]** 限定公開のGoogleアクセス (Private Google Access) は、
外部IPを持たないVMから、インターネットに出ることなく Google のAPI に到達できるようにする設定。
Cloud Storage や Secret Manager を使うためだけに Cloud NAT を立てる必要がなくなる(コスト削減)。
通信がGoogleのネットワーク内で完結する(セキュリティ)。

(スライドには載せていない補足)AWSのVPCエンドポイントは Gateway型 / Interface型があり、サービスごとにエンドポイントを作る必要があった。
GCPはサブネットのフラグ1つで全Google APIが対象になる。

---

### S47 | Step6 実行 → 成功

**[本文]**

```
cd ~/works/lesson2/ && cp -rf ~/infra-study/gcp/lesson2/6.\ private_google_access/ ./

resource "google_compute_subnetwork" "private" {
  name          = "${var.user_name}-private-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast1"
  ip_cidr_range = var.subnet_private_cidr

  private_ip_google_access = true      // ← 追加したのはこの1行
}

  terraform init
  terraform plan, terraform apply

◼db に入って、もう一度

  curl -m 10 -I https://storage.googleapis.com    -> HTTP/2 400
```

**[話す]** 1行足しただけ。GCPはこういう「フラグ1つ」で挙動が変わるものが多い。
逆に言うと、フラグを見落とすと原因が分からなくなる。

(スライドには載せていない補足)
- 通った。400が返るのは正常(認証情報を付けていないため)。
- 「繋がる」と「権限がある」は別の話。ネットワークが通っても、IAMが無ければAPIは使えない。

---

### S48 | でも、Google以外には出られない

**[本文]**

```
◼db から普通のインターネットに出てみる

  (db の中で)
  curl -m 10 -I https://github.com

  → タイムアウト

◼なぜか
Private Google Access はその名の通り Googleへの経路 しか作らない

  → 一般のインターネットに出るには Cloud NAT が必要

◼これは web と比べると分かりやすい
  (web の中で)
  curl -m 10 -I https://github.com

  HTTP/2 200

  webは外部IPを持っているので、そのまま出られる
```

---

# Cloud NAT

---

### S48-2 | Cloud NAT(セクション区切り)

**[本文]**

```
Cloud NAT
```

---

### S49 | Cloud NAT とは

**[図版]** 「AWSのNAT Gatewayとの違い」は S06 と同じ体裁の **表(図形で作る。テキストの桁揃えではない)**。
見出し行は空欄 / AWS NAT Gateway / GCP Cloud NAT の3列、データ行は5行。

```
              AWS NAT Gateway         GCP Cloud NAT
──────────────────────────────────────────────────────
単位          サブネット(ゾーン)      リージョン
冗長化        自分でAZ分作る          Google側で担保
外部IP        EIPを確保してアタッチ   自動(固定にもできる)
ルート設定    ルートテーブルに書く     不要
課金          時間 + データ処理量      時間 + データ処理量
```

**[本文]**

```
◼Cloud NAT
外部IPを持たないVMが、インターネットへ出るための仕組み

リージョン単位で1つ作る
Cloud Router とセットで使う(必須)
外部IPを自分で確保する必要がない(自動払い出し)
片方向。外からVMへは入れない

◼AWSのNAT Gatewayとの違い
```

**[話す]** AWSの NAT Gateway はゾーンごとに作って冗長化する必要がある。
GCPではリージョン単位なので、その作業自体が消える。
代わりに今日の宿題では「別リージョンにもう1つ作る」をやってもらう。

---

### S50 | Cloud Router とは

**[本文]**

```
◼Cloud Router とは
外のネットワーク(オンプレなど)と VPC の間で
「どの宛先へどう行けるか」(ルート)を自動で教え合うサービス
  ※ 教え合うときの決まりごとを BGP(Border Gateway Protocol) という

◼Cloud NAT との関係
Cloud NAT の設定は、Cloud Router の上に載せる
→ Cloud NAT を作るには Cloud Router が必須

今回は BGP の設定はしない。Cloud Router を置くだけ
```

**[話す]** BGP は、ネットワーク同士が「うちはこの宛先に行けるよ」と経路情報を教え合うための決まりごと。
Cloud Router はそれを自動でやってくれるマネージドなルータで、オンプレと VPN / Interconnect で繋ぐときに使う。
今日はオンプレと繋がないので、この本来の機能は使わない。

(スライドには載せていない補足)
- 本来の用途は、オンプレとの VPN / Interconnect。
- ★ 「Cloud NATを作ろうとしたらCloud Routerが要ると言われた」というのはGCP初学者の定番のつまずき。セットで覚える。

Cloud NAT は、設定の置き場所として Cloud Router を必要とする。
だから NAT を作る前に、空の Cloud Router を1つ作っておく、という順番になる。
BGP の設定は要らないので「Cloud NAT とセットで必須の部品」とだけ覚えてもらえばよい。

---

### S51 | Cloud NAT の Terraform コード

**[本文]**

```
cd ~/works/lesson2/ && cp -rf ~/infra-study/gcp/lesson2/7.\ cloud_nat/ ./

resource "google_compute_router" "router" {
  name    = "${var.user_name}-router"
  network = google_compute_network.vpc.id
  region  = "asia-northeast1"
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.user_name}-nat"
  router = google_compute_router.router.name
  region = "asia-northeast1"

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
```

**[話す]** (スライドには載せていない補足)
- ★ aws_eip が無い。AWSでは NAT Gateway に「まずEIPを取得してアタッチする」必要がある。GCPは AUTO_ONLY にしておけばGoogleが払い出す。
- ★ ルートテーブルへの追記も無い。

---

### S52 | Step7 実行 → 成功

**[本文]**

```
  terraform init
  terraform plan, terraform apply

◼db に入って、インターネットに出てみる

  gcloud compute ssh [自分の名前]-db --zone=asia-northeast1-a --tunnel-through-iap

  (db の中で)
  curl -m 10 -I https://github.com   → HTTP/2 200


◼パッケージのインストールも試す
  sudo apt-get update  → 通る
```

**[話す]** Cloud NATは作成後、反映に少し時間がかかることがある。
すぐ通らなければ1分ほど待つ。

---

### S53 | ワンポイント: 外部でIP制限をかけるとき

**[本文]**

```
◼Cloud NAT経由の通信は、NATの外部IPから出ていく

  外部のAPIやサービスでIP制限をかけたい場合は
  Cloud NAT のIPアドレスを許可リストに入れる

◼ただし AUTO_ONLY だとIPが変わる可能性がある
  固定したい場合は

    nat_ip_allocate_option = "MANUAL_ONLY"
    nat_ips = [google_compute_address.nat.self_link]

  として、外部IPを自分で確保して、そのIPを許可する
```

**[話す]** (スライドには載せていない補足)
- 確認方法: db の中で `curl -s https://ifconfig.me` を実行すると、Cloud NATの外部IPが返ってくる。
- AWSでも同じ話がある。NAT Gatewayのアドレスで制限をかける、というやつ。

---

### S54 | ハンズオン完了

**[図版]** S05のゴール図を再掲し、全要素にチェックマークを付ける。

**[本文]**

```
◼やったこと

VPCとサブネットを作った
外部IPあり/なしのVMを2台作った
IAP経由で、踏み台なしでprivateなVMに入った
Firewall Ruleをタグとサービスアカウントで書いた
Private Google AccessでGoogle APIに到達した
Cloud NATでインターネットに出た
```

**[話す]** (スライドには載せていない補足)
- AWSなら Internet Gateway と ルートテーブルの設定が要るところが、GCPでは要らない分、別のこと(IAP / PGA)に使えた。

---

# まとめ

---

### S55 | 本日のまとめ ①

**[図版]** AWS版 第3回「本日のまとめ」のレイアウトを流用。

**[本文]**

```
◼GCPのネットワーク

VPCはグローバルリソース。CIDRを持たない
サブネットはリージョン単位。CIDRを持つ
public / private という区別は存在しない
  → 外部IPの有無と、Cloud NATの有無で決まる
ルートはVPC単位。デフォルトルートは自動で作られる
  → Internet Gatewayもルートテーブルの紐づけも不要
```

---

### S56 | 本日のまとめ ②

**[本文]**

```
◼Firewall Rules
VPCに並べるルール。リソースにアタッチしない
適用先は ネットワークタグ か サービスアカウント で指定する
1つのルールでタグとSAを混在させることはできない
暗黙のルール: ingress全拒否 / egress全許可
ステートフル。戻りの通信は自動で許可される

◼IAP TCP forwarding
3つのゲート
  Firewall Rule(35.235.240.0/20 の tcp:22)
  roles/iap.tunnelResourceAccessor
  roles/compute.osAdminLogin + roles/iam.serviceAccountUser

◼外に出る手段は2つ
Private Google Access  Google APIだけ。サブネットのフラグ1つ
Cloud NAT              一般のインターネット。Cloud Routerとセット
```

---

### S57 | 本日はここまで

**[図版]** AWS版の同スライドを流用。

---

### S58 | 宿題1 アンケート

**[図版]** AWS版 第3回「宿題1」を流用。URLを差し替え。

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

### S59 | 宿題2 実装課題

**[図版]** AWS版 第3回「宿題2」のCIDR表付きレイアウトを流用。表の中身を差し替える。

**[本文]**

```
◼1. web / db / cache 用のサブネットを追加しよう

  web     172.16.20.0/22   asia-northeast1
  db      172.16.40.0/24   asia-northeast1
  cache   172.16.50.0/24   asia-northeast1

  AWSならAZごとに作るので6つ要りますが、GCPでは3つで済みます
  追加したサブネットが自動でCloud NATの対象に入ることも確認してください

  回答例: gcp/lesson2/syukudai1/


◼2. 大阪リージョンにサブネットと Cloud NAT を追加しよう

  osaka-public    172.16.100.0/24   asia-northeast2
  osaka-private   172.16.110.0/24   asia-northeast2

  + asia-northeast2 用の Cloud Router と Cloud NAT

  VPCを作り直さずに追加できることを確認してください
  Cloud NAT はリージョン単位なので、こちらは追加が必要です

  回答例: gcp/lesson2/syukudai2/
```

**[話す]** 2つ目は「VPCがグローバル」を体感してもらう課題。
AWSでこれをやるとVPCをもう1つ作ってピアリングを張ることになる。

---

### S60 | 宿題3 ドキュメント

**[図版]** 「Terraform google provider の各ドキュメント」の6つのリソース名は、Terraform Registry の各リソースページへのハイパーリンクにする(`https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/<リソース名から google_ を除いたもの>`)。

**[本文]**

```
◼VPCのドキュメントを眺めてみよう
  VPC ネットワークの概要
    https://cloud.google.com/vpc/docs/vpc
  ファイアウォール ルールの概要
    https://cloud.google.com/firewall/docs/firewalls
  ルートの概要
    https://cloud.google.com/vpc/docs/routes

◼Terraform google provider の各ドキュメントを眺めてみよう
  google_compute_network
  google_compute_subnetwork
  google_compute_firewall
  google_compute_router
  google_compute_router_nat
  google_compute_instance
```

---

### S61 | 参考

**[本文]**

```
VPC ネットワークの概要
  https://cloud.google.com/vpc/docs/vpc

ファイアウォール ルールの概要
  https://cloud.google.com/firewall/docs/firewalls

IAP TCP 転送を使用する
  https://cloud.google.com/iap/docs/using-tcp-forwarding

限定公開の Google アクセスを構成する
  https://cloud.google.com/vpc/docs/configure-private-google-access

Cloud NAT の概要
  https://cloud.google.com/nat/docs/overview

AWSプロフェッショナルのためのGoogle Cloud: ネットワーキング
  https://cloud.google.com/docs/get-started/aws-azure-gcp-service-comparison
```

---

### S62 | 注意事項

**[本文]**

```
宿題などで作成したリソースは
必ず削除してください！

◼リソースの削除(最後に apply したディレクトリで実行)
  cd ~/works/lesson2/syukudai2           ← 宿題2まで
  cd ~/works/lesson2/syukudai1           ← 宿題1まで
  cd ~/works/lesson2/"7. cloud_nat"      ← 講義 Step7 まで

  terraform destroy
  → 確認で yes と入力

※ 特に今回は課金されるものが多いです
   Compute Engine  起動している間ずっと
   Cloud NAT       起動している間ずっと
   外部IP           使っていなくても課金される

※ 全員で1つのプロジェクトを共有しています
   消し忘れはQuotaを圧迫して、他の人のapplyを止めます

※ tfstate用のバケットは残しておいてください
```

**[話す]** destroy は「最後に apply したディレクトリ」で打つ。宿題2までやった人は
`~/works/lesson2/syukudai2`、宿題1までなら `syukudai1`、講義のハンズオンだけなら `"7. cloud_nat"`
(ディレクトリ名に空白があるので `"7. cloud_nat"` のように引用符で囲む)。
tfstate は全部同じ場所(prefix `lesson2`)を見ているので、どのディレクトリからでも同じ state が消える。
確認プロンプトは `yes` と3文字入力する(`y` では `Apply cancelled.` になる)。
tfstate 用のバケットは第1回で gcloud で作ったもので、Terraform の管理外なので destroy では消えない。

---

### S63 | おしまい

**[図版]** AWS版「おしまい」スライドを流用。

**[本文]**

```
次回 コンピューティング編 もお楽しみに！
```

**[話す]** (スライドには載せていない補足)次回は Compute Engine / ロードバランサー / Cloud DNS。
カスタムドメインにHTTPSでアクセスできるところまで作る。

---

# 付録A: ハンズオンのステップ対応表

| Step | ディレクトリ | 作るもの | 確認すること |
|---|---|---|---|
| 1 | `1. vpc/` | VPC | デフォルトルートが自動で存在する |
| 2 | `2. subnet/` | public / private サブネット | サブネットルートが自動追加される |
| 3 | `3. instance/` | web(外部IPあり) / db(外部IPなし) | **SSHが通らない**(2種類の失敗) |
| 4 | `4. firewall/` | IAP用Firewall Rule + IAM 3種 | **IAPでSSHできる** |
| 5 | `5. firewall_internal/` | SA指定のFirewall Rule | **web→db の ping が通る** |
| 6 | `6. private_google_access/` | サブネットにPGA | **Google APIに到達できる** |
| 7 | `7. cloud_nat/` | Cloud Router + Cloud NAT | **インターネットに出られる** |

AWS版 第3回の6ステップとの対応:

| AWS版 | GCP版 |
|---|---|
| 1. vpc | 1. vpc |
| 2. subnet | 2. subnet |
| 3. bastion | (廃止) |
| 4. internet_gateway | (GCPには不要) |
| 5. private_instance | 3. instance |
| 6. nat_gateway | 7. cloud_nat |
| — | 4. firewall / 5. firewall_internal(新規) |
| — | 6. private_google_access(新規) |

---

# 付録B: 制作メモ / 要確認事項

## 動作確認の結果(2026-08-28 実施)

`[プロジェクトID]` で Step1〜Step7 と宿題1・2を通しで apply → destroy 済み。
実行環境はローカルの Mac + ADC。**Cloud Shell では未実施**。

| スライド | 確認内容 | 結果 |
|---|---|---|
| S27 | 内部IP web=172.16.0.2 / db=172.16.10.2、dbに外部IPなし | OK。原稿の記載どおり |
| S28-① | web への直接SSH | OK。`Connection timed out` / return code 255 |
| S28-② | db への IAP SSH(Step4前) | **タイムアウトだった**(権限エラーではない)。原稿を修正済み |
| S38 | IAP経由で db にログイン | OK。踏み台なしでログイン成功 |
| S39 | web → db の ping(Step5前) | OK。100% packet loss |
| S41 | web → db の ping(Step5後) | OK。0% packet loss |
| S42 | db → web の ping | OK。100% packet loss(逆方向は許可していない) |
| S45 | PGAなしで Google API | OK。`http_code=000`。メタデータからトークンは取得できる |
| S47 | PGA有効化後の Google API | OK。**`http_code=400`**(原稿の予告どおり) |
| S48 | PGA有効化後の github.com | OK。タイムアウト継続 |
| S52 | Cloud NAT後の github.com | OK。`http_code=200` |
| S53 | 送信元IP | OK。Cloud NATの自動払い出しIP(web VMの外部IPとは別) |
| 宿題1 | web/db/cache サブネット追加 | OK。3リソース追加 |
| 宿題2 | 大阪リージョン + Cloud Router/NAT | OK。同一VPCに東京・大阪のサブネットが同居 |
| destroy | 素の `terraform destroy` | OK。24リソースがクリーンに削除 |

### 判明した注意点

1. **S28-② のエラーは受講者の権限で変わる**
   IAP権限を組織/グループから継承していればタイムアウト、
   していなければ権限エラーになる。S28に両方を記載済み。

2. **IAMの反映に約1分かかる**
   Step4のapply直後はSSHが通らないことがある。
   「すぐ通らなくても正常」と先に伝えること。

3. **インスタンス単位/SA単位のIAM付与で十分だった**
   `google_iap_tunnel_instance_iam_member` /
   `google_compute_instance_iam_member` /
   `google_service_account_iam_member` はいずれも作成でき、
   プロジェクトレベルのIAMを触らずにIAP SSHが通った。

### 受講者相当の権限での検証(2026-08-28 実施)

第1回 付録A のロール構成(Editor + 6ロール)だけを持つサービスアカウントを作り、
なりすまして Step1〜7 と宿題1・2を通しで実行 → **すべて成功**(25リソース)。
`terraform destroy` も24リソースがクリーンに削除された。

グループ経由の権限が混ざらない条件での検証なので、実際の受講者より厳しい条件。
**このロール構成で過不足なし。**

### 残っていること

- Cloud Shell での全ステップ通し apply は未実施。
  Cloud Shell 固有のリスク(Terraform未インストール / ADCのスコープ / 既定プロジェクト)は
  個別に確認・対処済みなので、**第3回の制作時に確認すれば足りる**(設計書11章)。

## 開催前に撮るスクリーンショット — **全て不要(2026-09-18 判断)**

当初7枚を挙げていたが、**この回に撮影が必要なものは無い。**

| | 種別 | 判断 |
|---|---|---|
| VPC一覧 / サブネット一覧(S17 / S22 は削除済み) | コンソールUI | **不要。講師が自分の画面を共有して実演する** |
| S28 SSH失敗×2 / S38 SSH成功 | 端末出力 | **不要。当日は受講者の画面に実物が出る** |
| S41 ping成功 / S47 curl成功 / S52 curl成功 | 端末出力 | 同上 |

**ブラウザの表示結果を見せるスライドはこの回には無い**(第3回の S31/S34/S45 が該当)。

> **★ 端末出力は文言だけ本文に載せてある。**
> 実機で文言を確認できていれば画像は不要、という判断
> (第1回で同じ整理をした。第1回 付録A-4 を参照)。
> **ただしこの回の文言は 2026-08-28 のローカル検証時のもので、
> Cloud Shell 実機では未確認。** 開催前に1回通すときに見ておくこと。

## 新規作図が必要なスライド

AWS版から流用できず、描き起こしが必要なもの。

| スライド | 内容 | 優先度 |
|---|---|---|
| S05 | ゴール構成図(VPCを最外周に置く) | 高 |
| S06 | AWS/GCP ネットワーク比較表 | 高 |
| S10 | Security Group と Firewall Rules の比較図 | **最高** |
| S12 | 踏み台構成 と IAP構成 の比較図 | **最高** |
| S35 | IAPの3つのゲート | 高 |
| S07 | VPCのスコープ比較 | 中 |
| S46 | Private Google Access | 中 |
| S08 | サブネットのスコープ | 中 |
| S09 | public/privateの区別がない | 中 |
| S24 | ネットワークタグとサービスアカウント | 低 |
| S31 | 暗黙のルール | 低 |

## 設計書との差異

- 設計書 6章の第2回アジェンダにある「Routes」は、GCPでは作る作業が無いため
  概念スライド1枚(S44)に圧縮した。
- ハンズオンのステップ数を設計書の想定より1つ増やし7ステップにした。
  Firewall Rules で「タグ指定」と「サービスアカウント指定」の2つを
  それぞれ独立した「繋がらない→繋がる」サイクルにするため
  (`4. firewall/` と `5. firewall_internal/` に分割)。
