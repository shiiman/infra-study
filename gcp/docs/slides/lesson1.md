# 第1回 インフラ勉強会(GCP) — GCP基礎 / IAM / Terraform

- **開催日**: 2026-10-05(月) 14-16時
- **AWS版対応**: 第1回(インフラ基礎) + 第2回(Terraform) を1回に圧縮
- **Terraformコード**: `gcp/lesson1/`
- **ゴール**: Cloud Shell から `terraform apply` が通り、GCSバックエンドに tfstate が保存される
- **スライド**: 94枚(S01〜S94)。うち S22〜S39 は当日飛ばす事前配布用スライド

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入(背景・対象・自己紹介) | 12分 | S01〜S11 |
| 今日のアジェンダ | 2分 | S12 |
| インフラ基礎の要点 | 18分 | S13〜S21(S22〜S39は飛ばす) |
| GCPについて | 13分 | S40〜S48 |
| Cloud IAM | 16分 | S49〜S60 |
| Cloud Shell | 9分 | S61〜S64 |
| Terraform | 15分 | S65〜S77 |
| ハンズオン | 22分 | S78〜S86 |
| まとめ・宿題・注意事項 | 10分 | S87〜S94 |

> 押した場合の削り所: S42(リソースカテゴリ一覧)と S74(data/module ブロック)は口頭のみで飛ばせる。
> **S22〜S39 は当日は飛ばすスライド**(事前配布資料 = GCP版スキップスライド)。
> 当日話すのは S15〜S20 の要点6枚で、遅れていれば S21(おさらい)だけでもよい。
>
> **S66(Terraformのインストール)は飛ばせない。** Cloud Shell に Terraform が
> 入っていないため、ここを飛ばすとハンズオンが始まらない。全10回で唯一この回だけ必要な作業。
> **講義内で全員一緒にやる。** Cloud Shell は事前準備のしようがないので、
> 受講者への事前案内は不要。

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない

> **実値の扱い**: このファイルは public リポジトリに入るので、
> プロジェクトID・IPなどの実値は `[プロジェクトID]` のように伏せる。
> Google スライド側の該当スライド(例: 「プロジェクトと、今回使うプロジェクト」)には
> 実値を入れる(共有ドライブ限定だからOK)。

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

### S02 | なぜインフラ勉強会(GCP)?(セクション区切り)

**[本文]**

```
なぜインフラ勉強会(GCP)？
```

**[話す]** 冒頭は「なぜやるのか」から始める。AWS版とは何が違うのか、を最初に言っておく。

---

### S03 | なぜGCP勉強会をやるのか

**[図版]** AWS版 第1回「インフラ勉強会の経緯」のテキストスライドを流用。

**[本文]**

```
◼背景
- バックエンドエンジニアのインフラ人材を増やしたい
- AWS版に続き、GCPを扱える人を増やしたい
- スタンダードサーバの前提がGCP
- マルチクラウドが前提の時代になった
- Cloud Run / BigQuery など、GCP側が強い領域がある

◼目的(サーバサイドのスキルアップ)
- GCP基礎
- Terraform(GCP編)

バックエンドエンジニアが自分でインフラを触れる状態にする
```

---

### S04 | ゴール

**[図版]** AWS版 第1回「インフラ勉強会のゴール」を流用。資格名を差し替え。

**[本文]**

```
◼ゴール(1年後)
Terraformで、HTTPSでアクセスできるコンテナWebアプリ一式を
自力で構築し、CI/CDと監視まで設定できる

  Cloud Load Balancing + Cloud Run + Spanner + Memorystore
  + Cloud Storage/CDN

◼Google Cloud 認定資格
Associate Cloud Engineer (ACE)     ← 本命
Cloud Digital Leader (CDL)        ← 入門枠
Professional Cloud Architect (PCA) ← 上級枠
```

**[話す]** AWS版は Cloud Practitioner と Developer-Associate の2本立てだった。
GCP版は ACA を上級枠として3本立てにする。第9回(3/18)で試験対策をやって、その場で申込みまで済ませる。

---

### S05 | 対象者

**[図版]** AWS版 第1回「インフラ勉強会 対象者」を流用。右側に参加者名の一覧を置く。

**[本文]**

```
◼対象者
社員バックエンドエンジニア(全員) + 参加希望者(社員以外もやる気があれば可)

GCP未経験を前提にゼロから進めます
AWS版に出ていた人は「AWSとの違い」に注目して聞いてください

◼任意参加(これから増えるかもね)
島田 蒼也 / 石坂 拓海 / 小島 哲 / 藤代 俊祐
守田 一喜 / 朝倉 信晴 / 齋藤 亮
```

**[話す]** 任意参加者は「参加してもいいよ」の意思表示の段階。
途中から加わっても大丈夫なので、興味があればいつでも声をかけてほしい。

---

### S06 | ロードマップ

**[図版]** AWS版 第2回「インフラ勉強会 スケジュール」の2カラムレイアウトを流用。
中身を全10回に差し替え(AWS版は12回だったので行を2つ削る)。

**[本文]**

```
◼ロードマップ(内容は随時変更される可能性あり)

2026年
10月05日(月) 14-16時  GCP基礎 / IAM / Terraform      ← 今日
10月26日(月) 14-16時  ネットワーク
11月16日(月) 14-16時  コンピューティング
12月10日(木) 15-17時  データベース
12月24日(木) 17-19時  コンテナ

2027年
01月18日(月) 11-13時  ストレージ + CDN
02月08日(月) 11-13時  CI/CD
03月01日(月) 14-16時  監視・運用 + その他リソース
03月18日(木) 15-17時  試験対策(ACE / CDL)
04月05日(月) 11-13時  実践テスト + 総まとめ

原則3週に1回・月曜or木曜・2時間
```

**[話す]** 第4回(12/10)、第5回(12/24)、第9回(3/18)は木曜。第5回は年末(12/24)なので、第4回の宿題は控えめにすると先に断っておく。
**第2回以降の各回で、このスライドを複製して「今日」のマーカーを移す**(第2回 md S02 など参照)。

---

### S07 | 自己紹介(セクション区切り)

**[本文]**

```
自己紹介
```

---

### S08 | 経歴

**[図版]** AWS版 第1回「インフラ(SRE)になるまでの道のり」の経歴スライドを流用。
経歴の年数を2026年時点に更新する。

**[本文]**

```
◼経歴
2012年 サイバーエージェントの新卒として入社
  サーバーエンジニア(リーダーなども経験)
  7タイトルくらいリリース
  PHP, nodeJS, mysql, redis, memcached

2017年 インフラエンジニアに職務チェンジ
  5タイトル rush, sakura, wonder, seek, ghost
  GCP 9年, AWS 8年くらい
  terraform, ansible, docker, golang, mackarel, datadog
```

---

### S09 | どうやってインフラを覚えたのか

**[本文]**

```
◼どうやってインフラを覚えたのか

インフラのコード化
＋標準化
```

**[話す]** 覚えた知識をそのままコードにし、それが標準化されて次のタイトルに再利用される。
このサイクルがGCP勉強会の目的そのものである、と繋げる。

---

### S10 | 勉強会でやること

**[本文]**

```
◼勉強会でやること
nishikiと同じ開発環境の構築

terraform を覚えて、GCPの知識をつけ、
とはいえいきなり「terraformで作ってみましょう！」というのは
ハードルが高いので、本日は最低限必要なインフラの知識や考え方を学ぶ
```

**[話す]** 「nishikiと同じ開発環境」が最終到達点であることを最初に言っておく。
本日はそのための土台づくり、という位置づけ。

---

### S11 | ここからが本題(セクション区切り)

**[本文]**

```
ここからが本題
```

---

### S12 | 今日のアジェンダ

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

# インフラ基礎

---

### S13 | インフラ基礎(セクション区切り)

**[本文]**

```
インフラ基礎
```

---

### S14 | インフラ基礎は事前配布資料で

**[本文]**

```
◼インフラ基礎は自習資料にしました

WAN/LAN、IPアドレス、ポート、DNS、SSL証明書は
GCPでもAWSでも同じ話なので、22~39ページにまとめてあります。

ここでは要点だけ15分で流します
「これ説明できないな」と思ったものがあれば、
資料を読み直してください
```

> **制作メモ**: 22〜39ページは **GCP用に用意した事前配布資料(スキップスライド)** のページ番号。
> このファイルの S22〜S39 がそれにあたる(デッキのページ番号と一致している)。
> AWS版第1回スライドをそのままPDF化する、という以前の予定は変更された。
>
> **この節の構成**: S15〜S20 が当日話す要点、S21 がおさらい、
> S22〜S39 が読み物用の詳細スライド(当日は飛ばす)。

---

### S15 | WANとLAN

**[図版]** AWS版 第1回「ネットワーク」のWAN/LAN図をそのまま流用。

**[本文]**

```
◼WAN  Wide Area Network   → インターネット
◼LAN  Local Area Network  → 社内ネットワーク

インフラとして構築するのはLAN
そしてWANへの入口(出口)を考えてあげる

→ 次回、GCPでこのLANを作ります
```

---

### S16 | IPアドレス

**[図版]** AWS版 第1回「IPアドレス」を流用。

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

### S17 | CIDRとサブネットマスク

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

### S18 | ポート番号

**[図版]** AWS版 第1回「ポート番号」を流用。

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

### S19 | ドメインとDNS

**[図版]** AWS版 第1回「ドメイン」を流用。`Cloud DNS` の記載はそのまま使える。

**[本文]**

```
◼ドメイン
IPアドレスでは人間が識別しにくいので、
意味のある文字列を対応させたもの

DNS (Domain Name System)
GCPでは Cloud DNS   (AWSでは Route 53)
```

---

### S20 | SSL/TLS証明書

**[図版]** AWS版 第1回「SSL証明書」の通信シーケンス図を流用。

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

### S21 | ここまでのおさらい

**[本文]**

```
ネットワークにはWANとLANがある
ネットワーク内の住所がIPアドレス。パブリックとプライベートがある
CIDRを意識してネットワーク設計をする
ポートが分かればプログラムが分かる
IPアドレスを人間に分かるように変換するのがDNS
ブラウザ通信のセキュリティを担保するのがSSL/TLS証明書
```

**[話す]** 次回のネットワーク編で実際にVPCを作るので、今日の用語が
そのまま使われることを先に言っておく。

---

### S22 | 2種類のネットワーク

**[図版]** AWS版 第1回「ネットワーク」1枚目(タイトル:「ネットワーク」)を流用。
LAN / WAN の2つの箱の図。

**[本文]**

```
ネットワーク
2種類のネットワーク
LAN / WAN
```

---

### S23 | これらの違いちゃんと説明できますか?

**[図版]** AWS版 第1回「ネットワーク」2枚目を流用。

**[本文]**

```
ネットワーク
これらの違いちゃんと説明できますか？
```

**[話す]** ここで一旦手を挙げてもらう。説明できる人は後で発表してもらうと、
そのまま次回以降の復習にもなる。

---

### S24 | WANとLAN(定義)

**[図版]** AWS版 第1回「ネットワーク」の定義スライドを流用。

**[本文]**

```
ネットワーク
◼WAN
Wide Area Network（ワイドエリアネットワーク）

◼LAN
Local Area Network（ローカルエリアネットワーク）
```

---

### S25 | WANとLAN(なぜ2つあるのか)

**[図版]** AWS版 第1回「ネットワーク」の解説スライドを流用。

**[本文]**

```
ネットワーク
◼WAN
Wide Area Network（ワイドエリアネットワーク）
インターネット

◼LAN
Local Area Network（ローカルエリアネットワーク）
社内ネットワーク

インフラとして構築しないといけないのはLAN
そしてWANへの入口(出口)などを考えてあげるイメージになります
なぜ2つのネットワークがあるのか、
違いはなんなのかについてはIPについて説明したあとで解説します
```

---

### S26 | IPアドレスとは

**[本文]**

```
IPアドレス
◼IPアドレスとは
スマホやPCなど、ネットワーク上の機器に割り当てられる
インターネット上の住所のようなもの
```

**[図版]** AWS版 第1回「IPアドレス」1枚目を流用。

---

### S27 | パブリックIPとプライベートIP

**[本文]**

```
IPアドレス
◼パブリックIP(外部IP、グローバルIP)
WANで使用されるIP(世界に同じものは1つしかない)

◼プライベートIP(内部IP、ローカルIP)
LANで使用されるIP(外の世界(WAN)からは特定不可)
```

**[図版]** AWS版 第1回「IPアドレス」2枚目を流用。

---

### S28 | なんで全部パブリックIPを使わないの?

**[本文]**

```
IPアドレス
なんで全部パブリックIPを使わないの？
```

**[話す]** 答えは次の2枚。ここで先送りにして、参加者の「なんでだろう?」
を引き出してから解説する。

---

### S29 | IPアドレスの不足とセキュリティ

**[本文]**

```
IPアドレス
◼IPアドレスの不足
IPv4では 2の32乗、つまり約43億個のアドレスが存在できる
しかし急速なIT発達で誰もがPCやスマホを持つ状態に...
するとネットワーク機器全てにIPアドレスを付与することができない

◼セキュリティーの問題
IPアドレスが特定されると攻撃される危険性
```

**[図版]** AWS版 第1回「IPアドレス」の解説スライドを流用。

**[話す]** S28で投げかけた問いの答えをここで説明する。
AWSの感覚で言わすと「NATゲートウェイの向こうに置く」という話で、
第2回で Cloud NAT を実際に作る。

---

### S30 | LANを構成する

**[本文]**

```
IPアドレス
ということでLANのネットワークを
構成する方法を学ぼう!!
```

---

### S31 | IPアドレスクラス

**[図版]** AWS版 第1回「IPアドレス」の `192.168.0.1/24` 分解図を流用。

**[本文]**

```
IPアドレス
◼IPアドレスクラス
192.168.0.1/24
   ネットワーク部 / ホスト部  ← サブネットマスク

上記を踏まえ各プラットフォーム規則に則って、ネットワーク設計を行う
```

**[話す]** GCPのサブネットは4つのIPが予約される(ネットワークアドレス、
デフォルトゲートウェイ、末尾2つ)。AWSは5つ予約だった。細かいが/28みたいな
小さいレンジを切るときに効いてくる。
**この勉強会では 172.16.0.0/16 を使う**。

---

### S32 | サムザップでは標準化している

**[本文]**

```
IPアドレス
◼サムザップでは標準化している

(IP標準化スプレッドシートの共有リンクを掲載)
```

**[話す]** 実務では「172.16.0.0/16 を使いなさい」は決まり文句ではなく、
会社ごとにIP標準がある。勉強会では172.16.0.0/16 が標準の代わりになる。

> **制作TODO**: 共有スプレッドシートのリンクは公開リポジトリに書かない。
> スライドには貼る(共有ドライブ/社内限定)。

---

### S33 | 「:8080」って何?

**[本文]**

```
IPアドレス
IPアドレスでネットワークとホストを
特定できることがわかった
じゃあたまに見る「:8080」ってなんだろう？
```

**[話す]** ポート番号への導入。ここで手を挙げて「ポートだな」と言える人がいるか確認する。

---

### S34 | ポート番号

**[本文]**

```
ポート番号
◼ポート番号とは
TCP/IP通信において、コンピュータが通信に使用する
プログラムを識別するための番号です
```

**[図版]** AWS版 第1回「ポート番号」を流用。22 / 80 / 443 / 3306 / 6379 の表。

---

### S35 | ドメイン

**[本文]**

```
ドメイン
IPアドレスを入力してアクセスすることって少ないですよね？
```

**[話す]** ドメインへの導入。

---

### S36 | ドメインとDNS

**[本文]**

```
ドメイン
◼ドメイン
IPアドレスでは人間が識別しにくいので、意味のある文字列を対応させたもの

Domain Name System
GCPでは Cloud DNS   (AWSでは Route 53)
```

**[図版]** AWS版 第1回「ドメイン」を流用。

---

### S37 | SSL証明書(セクション)

**[本文]**

```
SSL証明書
```

---

### S38 | SSL証明書はなぜ必要か

**[本文]**

```
SSL証明書
攻撃 / 覗き見 / 偽装

そこで出てくるのがSSL証明書です！！
```

**[図版]** AWS版 第1回「SSL証明書」の導入スライドを流用。

---

### S39 | SSL/TLSの手順

**[本文]**

```
SSL証明書
ブラウザからサイトにアクセス
  → 通信先サーバーからSSL証明書と公開鍵が送られてくる
  → ブラウザはあらかじめ登録されている認証局の証明書を使って証明書を検証
  → 有効な証明書なら共通鍵(セッションキー)を生成
  → 共通鍵を公開鍵で暗号化して通信先サーバーに返送
  → サーバーは秘密鍵で復号
  → 以降は共通鍵で通信データを暗号化

SSL証明書を使えば安全に通信ができる！
```

**[図版]** AWS版 第1回「SSL証明書」の通信シーケンス図を流用。差し替え不要。

**[話す]** GCPでは「Googleマネージド SSL証明書 / Certificate Manager」を使う。
AWSには「CloudFront用のACM証明書はus-east-1で作らないといけない」という罠があったが、
GCPにはこの制約がない。ここは第3回でHTTPS化するときに実際に使う。
今は「証明書は自動で取れる」とだけ覚えておけばよい。

---

# GCPについて

---

### S40 | GCPについて(セクション区切り)

**[本文]**

```
GCPについて
```

---

### S41 | なぜGCPか

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

### S42 | GCPのリソースカテゴリ

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

### S43 | 料金体系

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

### S44 | 組織 - フォルダ - プロジェクト ★重要

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

### S45 | プロジェクトと、今回使うプロジェクト

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

  名前は「社用メールの @ の前」の _ を - に変えたもの
  yamada_taro@... → yamada-taro

  yamada-taro-vpc / yamada-taro-app / [プロジェクトID]-tfstate-yamada-taro

★ 詳しくは Terraform の tfvars のところで
```

**[話す]** 本来は受講者ごとにプロジェクトを分けたいが、今回は既存の共有プロジェクトを使う。
共有だからこそ気をつけることがあるので、IAMのところで改めて説明する。

**名前の形はここで一度だけ見せて、理由と文字数制約は S73 に回す。**
この回のハンズオンでも第7回のビルド用SAでも同じ `user_name` を使うので、
形が揃っていないと後の回で詰まる。

> **注意**: 原稿には実値を書かない(public)。Google スライド側には実値を入れる。

---

### S46 | リージョンとゾーン

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

### S47 | 割り当て(Quota)

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

### S48 | AWSとの用語対応

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

### S49 | Cloud IAM(セクション区切り)

**[本文]**

```
Cloud IAM
```

---

### S50 | Cloud IAM とは

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

### S51 | プリンシパル(誰が)

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

> **他回からの参照先**: 「allUsers は事故の元」は第5回・第6回でも言及される
> (第5回 md / 第6回 md の「★ 第1回 S51 で…」という箇所)。
> **このスライドの番号(S51)を動かすときは、第5回・第6回の md も直すこと。**

---

### S52 | ロール(何ができる)

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

### S53 | 許可ポリシーとバインディング

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

### S54 | IAMの継承

**[図版]** S44の階層ツリーを再掲し、上から下への矢印を強調。

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

### S55 | サービスアカウント ★GCP最重要

**[図版]** **新規作成**。GCP版で最も重要な図。サービスアカウントは2つの顔を持つ、
を左右2カラムで描く。

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
                    (例: SAに roles/storage.objectViewer
                       → このSAはバケットを読める)

リソースとして      SAにもIAMポリシーが付く
                    → このSAを使ってよいのは誰か
                    (例: SAに roles/iam.serviceAccountTokenCreator
                       → 自分がこのSAになりすませる)

◼AWSのIAMロールとの違い
AWSのIAMロールは「一時的に引き受けるもの」でIDを持たない
GCPのSAはメールアドレスを持った独立したIDである
```

**[話す]** ここが分かると以降の回が全部楽になる。逆にここが曖昧だと、
第5回(Cloud Run)や第7回(CI/CD)で必ず詰まる。

---

### S56 | サービスアカウントキーを作らない

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

### S57 | 権限借用(impersonation)

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

### S58 | AWS IAM との対比

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

### S59 | 【注意】共有プロジェクトでやってはいけないこと ★

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

### S60 | 認証情報の優先順位(ADC)

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

# Cloud Shell

---

### S61 | Cloud Shell(セクション区切り)

**[本文]**

```
Cloud Shell
```

---

### S62 | Cloud Shell とは

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

### S63 | Cloud Shell の注意点

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

### S64 | Cloud Shell を起動してみよう

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

# Terraform

---

### S65 | Terraform(セクション区切り)

**[本文]**

```
Terraform
```

---

### S66 | Terraform をインストールする ★新規

**[本文]**

```
◼Cloud Shell に Terraform は入っていません

  terraform version
  → bash: terraform: command not found

◼$HOME の下にインストールします
  ($HOME以外は再接続で消えるため)

  mkdir -p ~/bin
  cd /tmp
  curl -sLO https://releases.hashicorp.com/terraform/1.16.3/terraform_1.16.3_linux_amd64.zip
  unzip -o terraform_1.16.3_linux_amd64.zip -d ~/bin

◼PATH を通します(~/.bashrc に書けば次回以降も有効)

  echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
  source ~/.bashrc

◼確認
  terraform version
  → Terraform v1.16.3

★ この作業は初回だけ。第2回以降は不要です
```

**[話す]** AWS版の第2回でも Cloud9 に tfenv で Terraform を入れる作業があった。
やっていることは同じ。違うのは、Cloud Shellは $HOME しか残らないので
`/usr/local/bin` ではなく `~/bin` に入れる必要があること。

バージョンを切り替えたい人は tfenv を `~/.tfenv` に入れてもよい
(その場合も PATH は `~/.bashrc` に書く)。

> **検証済み(2026-08-28)**: 実際のCloud Shellで上記手順を実行し、
> 起動と `~/.bashrc` 経由でのPATH永続化を確認。
> `~/bin` の容量は約115MB(ホームは5GBまで)。
> このとき入れたのは当時の最新 `1.16.0`。

> **★ バージョンを上げるときは、講師の Cloud Shell も入れ直すこと ★**
>
> **2026-09-18 に `1.16.0` → `1.16.3` に固定した。**
>
> インストールは**第1回の1回だけ**で、以降7ヶ月そのバージョンを使い続ける。
> Terraform は**パッチが週1ペースで出る**(1.16.0 は 2026-08-26、
> 1.16.3 は 2026-09-16)ので、スライドの番号は放っておくと必ず古くなり、
> 受講者に `Your version of Terraform is out of date!` が出て不安にさせる。
>
> **「最新版を動的に取得する」方式は採らなかった。**
> 講師の Cloud Shell には既に入っているため再インストールされず、
> **講師だけ古いバージョンのまま**になって受講者とズレる。
> 固定にしておけば、講師も同じ手順で入れ直せば揃う。
>
> ```
> # 講師が入れ直すとき(受講者と同じ版に揃える)
> rm -f ~/bin/terraform
> cd /tmp && curl -sLO https://releases.hashicorp.com/terraform/1.16.3/terraform_1.16.3_linux_amd64.zip
> unzip -o terraform_1.16.3_linux_amd64.zip -d ~/bin
> terraform version   # → v1.16.3
> ```
>
> 最新版の確認:
> `curl -s https://api.releases.hashicorp.com/v1/releases/terraform/latest | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])'`
>
> **上げるなら 10/5 の数日前までに、スライドと講師環境の両方を同時に。**
> 当日に近すぎると講師環境の入れ直しを忘れる。

---

### S67 | 作業スペースの準備

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

### S68 | Terraform とは

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

### S69 | Write / Plan / Apply

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

### S70 | 構成言語(HCL)- ブロックの種類

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

### S71 | terraform / provider ブロック

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

### S72 | resource / variable ブロック

**[図版]** AWS版 第2回の resource/variable 2カラムスライドを流用。コードを差し替え。

**[本文]**

```
◼resourceブロック
resource "google_service_account" "app" {
  account_id   = "${var.user_name}-app"
  display_name = "${var.user_name} app service account"
}
          ↑リソースタイプ    ↑この設定ファイル内での名前

  参照するときは google_service_account.app.email

◼variableブロック
variable "user_name" {}

resource "google_service_account" "app" {
  account_id = "${var.user_name}-app"
}
```

**[話す]** ここはハンズオンで実際に作るリソースを例にしている。
Terraformで「リソースを1つ足す」感覚を掴んでおくと、
次回の VPC 一気通貫が楽になる。

---

### S73 | tfvars

**[図版]** AWS版 第2回の tfvars スライドを流用。コードを差し替え。

**[本文]**

```
◼terraform.tfvars
変数の値をまとめて書くファイル。自動で読み込まれる

terraform.tfvars

  // ★ 自分の名前に書き換えること
  user_name = "yamada-taro"

★★ user_name は「社用メールの @ の前」の _ を - に変えたもの ★★

     yamada_taro@... → user_name = "yamada-taro"

  ★ アンダースコア(_)は使えません
     サービスアカウントの名前が <user_name>-app になり、
     account_id は「小文字英数字とハイフンのみ」だからです

◼値の渡し方(優先順位順)
  -var オプション
  -var-file オプション
  terraform.tfvars(自動読み込み)
  環境変数 TF_VAR_user_name
  variable の default
```

**[話す]** この勉強会では全員が同じコードを使って、`user_name` だけ変える。
共有プロジェクトなので、ここを書き換え忘れると他人のリソースを触ることになる。必ず変えること。

**名前の形をここで揃えてもらう。** メールのローカル部の `_` を `-` にするだけ。
アンダースコアのままだとサービスアカウントが作れず、この回の Step2 で落ちる。
第7回のビルド用サービスアカウント(`<user_name>-build`)は講師が事前に作ってあるので、
**ここで違う名前を入れると第7回で「SAが見つからない」で詰まる**。

> **★ 講師メモ ★** `user_name` の形は
> **社用メールのローカル部の `_` を `-` に置き換えたもの**で確定している(2026-09-16)。
> 名簿(`gcp/tools/members.txt`)と `tools/` のスクリプトは全部この形を前提にしている。
>
> 制約はサービスアカウントの `account_id` がいちばん厳しく、
> **6〜30文字・小文字英数字とハイフンのみ。**
> サフィックスが最長 `-build`(6文字)なので **user_name は 3〜24文字**。
> 確定した12名で最長は18文字なので余裕がある。
>
> **姓だけにしなかった理由**: 同姓が2名いて衝突するため。

---

### S74 | data / module ブロック

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
**第3回 md の「module ブロック(第1回 S74 でやったもの)」という参照先。**

---

### S75 | CLIコマンド

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

### S76 | tfstate とは

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

### S77 | tfstate をどこに置くか(backend)

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

### S78 | ハンズオン(セクション区切り)

**[本文]**

```
ハンズオン
```

---

### S79 | 今日作るもの

**[図版]** 3ステップのフロー図(デッキに作図済み)。
Step2 の下に「なりすまし 失敗」、Step3 の下に「成功」を置く。

```
 Step 1            Step 2                 Step 3
GCSバケット   →  サービスアカウント  →  なりすませる
を作る            を作る                 ようにする
gcloud / 管理外   google_service_account  …iam_member

                なりすまし 失敗  →  成功
```

**[本文]**

```
◼ハンズオンのゴール

1. gcloud で GCSバケットを作る(Terraform管理外)
2. サービスアカウントを作る
3. サービスアカウントになりすませるようにする

  (ついでに tfstate をそのバケットに移す)

コード: ~/infra-study/gcp/lesson1/

★ バケットはTerraformで管理しない
   → destroy で「自分のバケットごと消す」事故が起きない
   → 第2回以降も同じバケットを使い続ける
```

---

### S80 | Step1 GCSバケットを作る(gcloud)

**[本文]**

```
◼バケットを作ります

  gcloud storage buckets create \
    gs://[プロジェクトID]-tfstate-[自分の名前] \
    --location=ASIA-NORTHEAST1 \
    --uniform-bucket-level-access

  ★ バケット名はGCP全体で一意
     だからプロジェクトIDと自分の名前を含めている
  ★ 均一なバケットレベルのアクセス:
     旧来のACLを無効化し、権限管理をIAMに一本化する

◼バージョニングを有効にします

  gcloud storage buckets update \
    gs://[プロジェクトID]-tfstate-[自分の名前] \
    --versioning

  ★ tfstateを壊してしまった時に前の世代へ戻せる
  ★ create には --versioning が無いので update で後から付ける

◼確認
  gcloud storage buckets describe gs://[プロジェクトID]-tfstate-[自分の名前]

  → location: ASIA-NORTHEAST1
    uniform_bucket_level_access: true
    versioning_enabled: true

★ バケットはTerraformで管理しない。第2回以降も使い続けます
```

**[話す]** バケットは tfstate の「入れ物」なので、Terraformで管理する必要はない。
Terraformで作ると、`terraform destroy` が「自分のtfstateが乗っているバケット」を
消しにいく事故パターンになる。それを避けるために、ここだけ gcloud で作る。
このバケットは第2回以降も使い続ける。

> **制作TODO**: `describe` の出力キー(`versioning_enabled` など)は
> 開催前に実機で1回確認して、スライドの表記を実物に合わせること。

---

### S81 | Step2 サービスアカウントを作る

**[本文]**

```
参照: gcp/lesson1/2. service_account/

resource "google_service_account" "app" {
  account_id   = "${var.user_name}-app"
  display_name = "${var.user_name} app service account"
}

  terraform init
  terraform plan
  terraform apply

◼確認
  gcloud iam service-accounts list --filter="email:[自分の名前]-app"

  shiiman-app@[プロジェクトID].iam.gserviceaccount.com

★ init の段階で state は GCS backend に接続される
  → 以降の apply で state が GCS に保存される
```

---

### S82 | Step2 になりすましてみる → 失敗する

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
★ エラーメッセージに必要なロール名まで教えてくれている
   GCPのエラーは親切なので、まず全文を読む癖をつけること
```

> **検証済み(2026-08-28)**: `[プロジェクトID]` で上記のエラーを実測。

---

### S83 | なぜ失敗したのか

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
   S59 の「共有プロジェクトでやってはいけないこと」の実践
```

**[話す]** AWS版では「セキュリティグループを足したら繋がった」をやった。
GCPのIAMも同じで、「足りないものを1つずつ足す」で解決する。
違うのは、足す場所がユーザ側ではなくリソース側だということ。

---

### S84 | Step3 権限を足す

**[本文]**

```
参照: gcp/lesson1/3. iam/

data "google_client_openid_userinfo" "me" {}

// ① 自分 → SA
resource "google_service_account_iam_member" "token_creator" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${data.google_client_openid_userinfo.me.email}"
}

// ② SA → バケット
//    バケットはTerraform管理外なので data ブロックで参照する
data "google_storage_bucket" "tfstate" {
  name = "${var.project_id}-tfstate-${var.user_name}"
}

resource "google_storage_bucket_iam_member" "app_object_viewer" {
  bucket = data.google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.app.email}"
}

★ data ブロックが2つ出てくる (S74でやったもの)
   ・自分のメールアドレスを取る
   ・Terraform管理外のバケットを読む
```

---

### S85 | Step3 実行 → 成功

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

### S86 | ハンズオン完了

**[図版]** S79のフロー図を再掲し、全ステップにチェックマークを付ける。

**[本文]**

```
◼できたこと

gcloud で GCSバケットを作った
terraform apply が通り、tfstate が GCS に保存された
サービスアカウントを作った
リソース単位でIAMロールを付けて、権限借用ができた

★ ここまでが、以降9回の土台になります
```

---

# まとめ

---

### S87 | 本日のまとめ

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

### S88 | 本日はここまで

**[図版]** AWS版の同スライドを流用。

---

### S89 | 宿題1 アンケート

**[図版]** AWS版 第1回「宿題1」を流用。URLを差し替え。

**[本文]**

```
◼アンケートのお願い

1分で終わりますのでぜひフィードバックお願い致します！！
次回開催のモチベになります！！！

https://docs.google.com/forms/d/e/1FAIpQLSeQjLfR6f6H_jDR1ZHRQUmJPkaw3BmBEnGPV-t8fUjjIoF37A/viewform
```

> **★ 全10回で同じフォームです。** 冒頭で「第何回か」を選ぶ形式なので、
> 回答は1つのシートに溜まり、回ごとの推移が見えます。
> 設問は `gcp/docs/survey.md` を参照。

---

### S90 | 宿題2 実装課題

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

### S91 | 宿題3 チュートリアルとドキュメント

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

### S92 | 参考

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

### S93 | 注意事項

**[図版]** AWS版「注意事項」スライドを流用。

**[本文]**

```
宿題などで作成したリソースは必ず削除してください！
今回は全員で1つのプロジェクトを共有しています。消し忘れがQuotaを圧迫して、他の人のapplyが止まります


◼リソースの削除

  terraform destroy

  → サービスアカウント / IAMバインディング2つ が削除される
    宿題までやった人は、カスタムロールとシークレットも一緒に消えます

★ tfstate用のバケットは残しておいてください
   第2回以降も同じバケットを使います(prefix で回ごとに分かれます)

★ バケットは gcloud で作ったので terraform destroy の対象外
   「自分のtfstateが乗っているバケットを destroy が消しにいく」という事故が起きない
   第2回以降もそのまま terraform destroy で大丈夫です

  (勉強会が全部終わったあと、消すときは中身ごと1コマンド)
  gcloud storage rm --recursive gs://[プロジェクトID]-tfstate-[自分の名前]/
```

**[話す]** 第2回以降も `terraform destroy` はそのまま実行してよい。
バケットだけが Terraform の管理外にあるので、毎回きれいに消えて、
置き場所だけが残る。

> **変更点(2026-09-11)**: 従来の「Step1 GCSバケットをTerraformで作る」方式は
> バケットが state に入るため、destroy 後に state lock を解放できず
> `errored.tfstate` が残る問題があった。gcloud で作成する方式に変更し、
> その問題自体を構造的に解消した。

> **制作TODO**: 「Terraform管理分は destroy で消える / バケットだけ残る」を
> 1枚の図にすると、第2回の冒頭で「前回のバケットを使います」に繋げやすい。

---

### S94 | おしまい

**[図版]** AWS版「おしまい」スライドを流用。

**[本文]**

```
おしまい

次回 ネットワーク編 もお楽しみに！
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
| `iam.serviceAccounts.setIamPolicy` | 第1回 Step3 / 第2回 Step4 | `google_service_account_iam_member` が作れない |
| `storage.buckets.setIamPolicy` | 第1回 Step3 | `google_storage_bucket_iam_member` が作れない |
| `storage.buckets.getIamPolicy` | 第1回 Step3 | 同上(Terraformは書く前に読む) |
| `compute.instances.setIamPolicy` | 第2回 Step4 | `google_compute_instance_iam_member` が作れない |
| `iap.tunnelInstances.setIamPolicy` | 第2回 Step4 | `google_iap_tunnel_instance_iam_member` が作れない |
| `iap.tunnelInstances.getIamPolicy` | 第2回 Step4 | 同上 |
| `iam.roles.create` / `.delete` | 第1回 宿題1 | カスタムロールが作れない |
| `secretmanager.secrets.setIamPolicy` | 第1回 宿題2 | シークレット単位のIAMが付けられない |

つまり Editor だけだと **第1回 Step3(IAMハンズオンの山場)と
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
roles/artifactregistry.admin          artifactregistry.repositories.setIamPolicy (第7回)
roles/logging.configWriter            logging.sinks / exclusions / buckets.create (第8回)
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
| `artifactregistry.repositories.setIamPolicy` | `roles/artifactregistry.admin` | 第7回 Step1(ビルドSAにpush権限を付与) |
| `logging.sinks.create` / `logging.exclusions.create` / `logging.buckets.create` | `roles/logging.configWriter` | 第8回 Step1(ログルーター)/ 宿題3(除外・保持期間) |

**Artifact Registry / Cloud Run / サーバレスNEG の作成権限は `roles/editor` に含まれている。**
第5回までは `roles/artifactregistry.admin` は不要だったが、
**第7回でリポジトリ単位のIAMを付けるようになるので必要になる。**

**第8回の監視まわりは、ほとんど `roles/editor` で足りる。**
ダッシュボード / アラートポリシー / 通知チャンネル / Uptime check / SLO /
ログベース指標は Editor に入っている。
足りないのは **ログルーター系(シンク・除外・ログバケット)** だけで、
これが `roles/logging.configWriter` に入っている。

**★ 配ってはいけないロール ★**

`resourcemanager.projects.setIamPolicy`(= `roles/resourcemanager.projectIamAdmin`
や `roles/owner`)は**配らない**。
持つと誰にでも好きなロールを付けられるため、共有プロジェクトでは事実上のオーナー権限になる。

そのため、プロジェクト単位でしか付けられない権限
(第7回の `roles/logging.logWriter` など)は講師が事前に付与する。
第7回 S17b で、この分界を受講者にも説明している。

### 付与は Google グループ経由で行う

**個人ごとに12ロールを付けるのではなく、グループを1つ作ってそこに付与する。**
このプロジェクトは既にグループ運用になっている
(`gcp-infra-owner@` / `gcp-infra_common-analyst-user@` / `wonder-server@`)ので、
その流儀に合わせる。

教材側はこれで問題ない。**受講者個人の identity を使うのは全部リソースレベル**で、
`data "google_client_openid_userinfo"` から Terraform が apply 時に解決している
(`lesson1/3. iam/iam.tf`)。講師が配るのはプロジェクトレベルのロールだけ。

**後始末が1箇所で済むのが最大の利点。** 勉強会が終わったらグループを消すか
バインディングを12個外すだけで全員分の権限が消える。
個人付与だと 20人 × 12ロール = 240個のバインディングを外すことになる。

#### 1. グループを作る

```
gcloud identity groups create gcp-infra_common-study-user@[ドメイン] \
  --organization="[ドメイン]" \
  --display-name="GCP勉強会 受講者" \
  --description="インフラ勉強会(GCP)の受講者。editor を含むので管理者のみ追加可"
```

#### 2. ★ グループの参加設定を締める ★

Workspace 管理コンソールで次のようにする。

- 参加できるユーザー: **招待されたユーザーのみ**
- メンバーの追加: **管理者のみ**
- 社外参加者を入れる場合のみ「組織外のメンバーを許可」をオン

**`roles/editor` を配るグループになる。**
自由参加にすると誰でもプロジェクトの編集権限を取れてしまう。

#### 3. メンバーを追加する

```
gcloud identity groups memberships add \
  --group-email=gcp-infra_common-study-user@[ドメイン] \
  --member-email=[受講者]@[ドメイン]
```

#### 4. グループに12ロールを付与する(1回で済む)

```
PROJECT=<プロジェクトID>
MEMBER=group:gcp-infra_common-study-user@[ドメイン]

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
  roles/run.admin \
  roles/artifactregistry.admin \
  roles/logging.configWriter
do
  gcloud projects add-iam-policy-binding $PROJECT \
    --member=$MEMBER --role=$ROLE --condition=None
done
```

#### グループ方式の注意点

**① 反映待ちが個人付与より長くなりえる。**
メンバーシップの伝播が挟まるため。**前日ではなく数日前に付与し、
講師が1回 apply を通して確認しておくこと。**

**② `gcloud projects get-iam-policy` では個人が見えなくなる。**
当日「この人だけ権限がない」を切り分けるときは Policy Troubleshooter を使う。

```
gcloud policy-intelligence troubleshoot-policy iam \
  //cloudresourcemanager.googleapis.com/projects/[プロジェクトID] \
  --principal-email=[受講者]@[ドメイン] \
  --permission=iam.serviceAccounts.setIamPolicy
```

`allowAccessState: ALLOW_ACCESS_STATE_GRANTED` が出れば通っている。
リソースは**位置引数**で、`--resource` ではない点に注意。

> **★ `policytroubleshooter.googleapis.com` の有効化が必要 ★**
> 2026-09-16 に有効化済み。**無効に戻すと当日の切り分け手段が無くなる。**
> グループ経由だと `gcloud projects get-iam-policy` では個人が見えないため、
> これが唯一の確認手段になる。
> 受講者をグループに入れる `gcloud identity groups memberships add` には
> `cloudidentity.googleapis.com` が必要(同日に有効化済み)。

**③ 社外参加者も入れられる**(2026-09-16 確認)。
組織ポリシー `constraints/iam.allowedPolicyMemberDomains` は `allValues: ALLOW` で、
ドメイン制限はかかっていない。グループ側で「組織外のメンバーを許可」をオンにすればよい。

#### 個人ごとに付与する場合(グループを使わないとき)

```
PROJECT=<プロジェクトID>
MEMBER=user:xxx@example.com
```

として、上の 4. の for ループをそのまま受講者ごとに実行する。

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
| 第1回 `terraform destroy` | **OK**(3リソース: SA / IAM2つ。バケットは gcloud で作ったので対象外) |

**このロール構成で過不足なし。** 追加も削減も不要。

なお `roles/editor` の `includedPermissions`(11,979個)を
`gcloud iam roles describe roles/editor` で取得して照合した結果が上の不足表。
補完先の各ロールに当該権限が含まれることも同様に確認している。

> **変更点(2026-09-11)**: 第1回のハンズオンを gcloud ベースに作り替えた。
> 上記の検証は 2026-08-28 の Terraform ベース方式で実施したもので、
> 権限要件(不足権限の表・ロール一覧)は方式変更に伴わず有効。
> **新しい方式での再検証は実施していない**ので、開催前に
> 「gcloud でバケット → terraform apply 3リソース → destroy」
> を受講者相当の権限で1回だけ通すこと。

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

- S44: 組織 → 勉強会用フォルダ → [プロジェクトID] のリソース階層画面
- S64: Cloud Shell 起動アイコン / 起動後のターミナル
- S82: 権限借用の失敗エラー(実物)
- S85: 権限借用の成功出力(実物)

## 5. 事前に配布するもの

- インフラ基礎の自習資料(GCP版スキップスライド)
- アンケートフォームのURL

---

# 付録B: 制作メモ / 要確認事項

## 開催前に最新情報を確認すること

| 項目 | スライド | 内容 |
|---|---|---|
| Cloud Shell の仕様 | S63 | ホームディレクトリ削除までの日数(120日)、週あたりの利用時間上限 |
| Always Free の対象リージョン | S43 | asia-northeast1 が対象外であることの再確認 |
| Terraform GCPチュートリアルの構成 | S91 | 章立てが変わっていないか。○△×の割り当て |
| google provider のバージョン | S71 | `~> 8.0` のまま行くか。8.0.0 は 2026-08-26 リリース |
| 事前配布資料のページ番号 | S14 | スキップスライドのページ数と一致するか |

## 動作確認が必要な箇所

1. **`data "google_client_openid_userinfo"` が Cloud Shell で動くか**
   Cloud Shell の ADC に `userinfo.email` スコープが含まれている前提で書いている。
   もし取得できない場合は `variable "user_email"` を追加して tfvars で渡す形に変更する。
   影響: S74 / S84 / `gcp/lesson1/3. iam/iam.tf` / `gcp/lesson2/4. firewall/iap.tf`

2. **権限借用の失敗メッセージの文言**(S82)
   実際に実行してエラー文を確認し、スライドの文言を実物に合わせる。

3. **通しでの apply → destroy**
   Step1(gcloud バケット)から Step3 まで通して apply し、
   `terraform destroy` がバケットを残したまま通ることを確認する。
   バケットの後片付けは `gcloud storage rm --recursive gs://.../`。

## 設計書からの変更点

設計書 6章では第1回の宿題を「Terraformチュートリアル(GCP編) / Cloud IAMドキュメント」
としていたが、成果物として宿題の回答例が必要なため、**実装課題を2問追加**した(S90)。
読み物系の宿題は S91 に集約している。

## 第1回のハンズオンを gcloud ベースに作り替えた(2026-09-11)

従来の方式は「Step1 で Terraform にバケットを作ってもらう」だったが、
その場合 destroy 後に state lock を解放できず `errored.tfstate` が残る
という問題があった(従来の S93 には「-target を使う」回避策を書いていた)。

gcloud でバケットを作成する方式に作り替えたことで:

- destroy で state lock を解放できない問題は構造的に起きない
- 受講者に「-target を使って一部だけ destroy する」ことを教える必要がなくなった
- バケットは Terraform の管理外なので、destroy しても残る(第2回でそのまま使える)
- Step1 の Terraform コードが不要になり、ハンズオンが1ステップ短縮

副作用:

- `1. gcs/`(バケット作成)と `2. backend/`(backend移行)のディレクトリを削除し、
  残りをステップ番号に合わせて `2. service_account/` `3. iam/` に付け替えた
  (Step1 は gcloud なのでコードが無く、ディレクトリは 2 から始まる)
- backend は最初のステップから GCS を指す。
  「ローカル state で作ってから移行する」という段取りが無くなった
- バケットは `data "google_storage_bucket"` で参照する(S84 / `3. iam/gcs.tf`)
- 第1回の state には3リソースだけ入る(従来は4リソース)
- バケットは第2回以降も使い回すので、第1回の最後では消さない(S93)
