# インフラ勉強会(GCP) カリキュラム全体設計

作成日: 2026-08-28
ステータス: 設計合意済み / 制作未着手

---

## 1. 背景と位置づけ

2022年4月〜2023年3月に実施した AWS版「Sumzap インフラ勉強会」(全12回・講義時間 合計21時間) の GCP版を作る。

- **形式**: B = GCP未経験者向けのゼロからのフル講座。AWS版とは独立して成立する
- **例外**: インフラ基礎と Terraform は省略版とする(AWS版では第1回・第2回に丸々2回分を使っていた)
- **成果物スコープ**: C = スライド + Terraformサンプルコード一式 + 理解度テスト/アンケート/採点シート

### 参照元(AWS版)

Drive フォルダ: (社内で共有)

| 資料 | Drive ファイルID |
|---|---|
| まとめ | (Drive参照。IDは社内で共有) |
| 第1回 インフラ基礎 | (Drive参照。IDは社内で共有) |
| 第2回 Terraform | (Drive参照。IDは社内で共有) |
| 第3回 ネットワーク | (Drive参照。IDは社内で共有) |
| 第4回 コンピューティング | (Drive参照。IDは社内で共有) |
| 第5回 データベース | (Drive参照。IDは社内で共有) |
| 第6回 コンテナ | (Drive参照。IDは社内で共有) |
| 第7回 ストレージ | (Drive参照。IDは社内で共有) |
| 第8回 CI/CD | (Drive参照。IDは社内で共有) |
| 第9回 実践テスト | (Drive参照。IDは社内で共有) |
| 第9回 試験結果発表 | (Drive参照。IDは社内で共有) |
| 第10回 試験対策 | (Drive参照。IDは社内で共有) |
| 第11回 その他・まとめ | (Drive参照。IDは社内で共有) |
| 第12回 ツール共有 | (Drive参照。IDは社内で共有) |
| 2022_試験採点(スプレッドシート) | (Drive参照。IDは社内で共有) |
| 第9回試験1(Google Form) | (Drive参照。IDは社内で共有) |

AWS版の Terraform コードはこのリポジトリの `lesson3/` 〜 `lesson9/` にある。

---

## 2. ゴール

**受講後の到達点**

Terraform で、HTTPS でアクセスできるコンテナ Web アプリ一式
(Cloud Load Balancing + Cloud Run + Cloud SQL + Memorystore + Cloud Storage/CDN)
を自力で構築し、CI/CD と監視まで設定できる。

**資格(2本立て)** — AWS版が Cloud Practitioner / Developer-Associate の2本立てだった構造を踏襲

- 本命: **Associate Cloud Engineer (ACE)** — AWS の SAA/DVA 相当
- 入門枠: **Cloud Digital Leader (CDL)** — AWS の CLF 相当。合格者数を作りやすい

資格取得は会社への成果報告に使うため、**試験対策回を第9回に置いて受験期間を確保する**設計にしている(AWS版は第10回=1/26に試験対策を行い、3/17時点の合格/受験予定をまとめスライドで集計していた)。

---

## 3. 開催スケジュール(全10回)

原則3週に1回・月曜・2時間。第5回と第9回のみ木曜。

| 回 | 日程 | 間隔 | テーマ |
|---|---|---|---|
| 1 | 2026-10-05(月) | — | GCP基礎 / IAM / Terraform |
| 2 | 2026-10-26(月) | 3週 | ネットワーク |
| 3 | 2026-11-16(月) | 3週 | コンピューティング |
| 4 | 2026-12-07(月) | 3週 | データベース |
| 5 | 2026-12-24(木) | 17日 | コンテナ |
| 6 | 2027-01-18(月) | 25日 | ストレージ + CDN |
| 7 | 2027-02-08(月) | 3週 | CI/CD |
| 8 | 2027-03-01(月) | 3週 | 監視・運用 + その他リソース |
| 9 | 2027-03-25(木) | 24日 | 試験対策(ACE / CDL) |
| 10 | 2027-04-12(月) | 18日 | 実践テスト + 総まとめ |

**避けた月曜**: 10/12(スポーツの日)、11/23(勤労感謝の日)、12/28(年末)、1/11(成人の日)、3/22(春分の日の振替休日)

**受験期間**: 第9回(3/25) で受験申込まで済ませ、第10回(4/12) までの18日間を受験期間に充てる。
第9回を木曜にずらした分、第10回を 4/5 → 4/12 に後ろ倒しして期間を確保した。

---

## 4. AWS → GCP サービス対応表

| AWS(参照元スライド) | GCP | 備考 |
|---|---|---|
| VPC(リージョン単位) | VPC Network | **グローバル**。サブネットがリージョン単位 |
| Subnet | Subnet | リージョン単位。IP範囲の拡張が可能 |
| Security Group | **VPC Firewall Rules** | ネットワークタグ / サービスアカウント単位。SG同士の参照は不可 |
| Internet Gateway | (暗黙) デフォルトルート + 外部IP | IGW に相当するリソースは存在しない |
| Route Table | Routes | VPC単位。サブネットに紐付けない |
| NAT Gateway | **Cloud NAT + Cloud Router** | Cloud Router が必須 |
| 踏み台サーバ + Key Pair | **IAP TCP forwarding** / OS Login | 踏み台レス構成が推奨 |
| Cloud9 | **Cloud Shell / Cloud Shell Editor** | 無料。**Terraform は同梱されていないので第1回でインストールさせる**($HOME配下に入れること) |
| IAM(ユーザ/グループ/ロール/ポリシー) | Cloud IAM(プリンシパル + ロール + **サービスアカウント**) | 組織 / フォルダ / プロジェクト階層。別物として教える |
| EC2 | Compute Engine (GCE) | |
| AMI | イメージ / マシンイメージ | |
| EBS | Persistent Disk | |
| ALB | Cloud Load Balancing (Global External Application LB) | |
| Route53 | Cloud DNS | |
| ACM | Google マネージド SSL証明書 / Certificate Manager | us-east-1 制約のような面倒がない |
| RDS / Aurora | **Spanner**(本編) / Cloud SQL(軽く) / AlloyDB は概説 | Spanner は AWS に相当なし。社内の主力なので本編に据える |
| ElastiCache | **Memorystore** (Redis / Valkey) | |
| DynamoDB | Firestore / Bigtable | 概説のみ |
| Redshift / Athena | **BigQuery** | 概説のみ |
| ECR | **Artifact Registry** | |
| ECS + Fargate | **Cloud Run** | ほぼ相当。本編はこちら |
| EKS | GKE (Standard / Autopilot) | **概説10分のみ**。本編から外す |
| S3 | **Cloud Storage** | |
| CloudFront | **Cloud CDN** (/ Media CDN) | |
| CodeCommit | **GitHub** | Cloud Source Repositories は新規利用不可のため |
| CodeBuild | **Cloud Build** | |
| CodeDeploy | **Cloud Deploy** | |
| CodePipeline | Cloud Build トリガー + Cloud Deploy パイプライン | |
| Secrets Manager | Secret Manager | |
| Lambda | Cloud Run functions | 概説のみ |
| AWS Batch | Cloud Run Jobs / Batch | 概説のみ |
| CloudWatch | **Cloud Monitoring / Cloud Logging** | |
| X-Ray | Cloud Trace / Cloud Profiler | |
| WAF | Cloud Armor | 宿題で扱う |

> **要確認**: Cloud Source Repositories / CodeCommit の新規利用不可は2026年5月時点の認識。
> 第7回(CI/CD)の制作時に最新の状況を必ず確認すること。

---

## 5. 置換では済まない設計判断

AWS版のスライドをそのままなぞると破綻する箇所。各回の制作時にここを見ること。

1. **VPCがグローバル** — AWS版第3回は「リージョンにVPCを作り、その中にAZ別サブネット」という説明構造。GCPは「グローバルなVPCに、リージョン別サブネット」。図とナレーションを作り直す。

2. **Firewall Rules がタグ/SA単位** — AWS版は「webのSGからdbのSGへの通信を許可」という説明を第3〜6回で繰り返し使っている。GCPではSG同士の参照ができないため、**ネットワークタグ**または**サービスアカウント**で許可元を指定する方式に全面的に書き換える。ここが最大の書き換えポイント。

3. **踏み台サーバをどう扱うか** — AWS版第3回は「踏み台を作る → SSH鍵を配る → private サーバに入る」が学習の軸だった。GCPは IAP TCP forwarding で踏み台レスにできる。
   **方針**: 踏み台VMは作らず、IAP で private VM に直接入る構成にする。ただし「なぜ踏み台が不要になるのか」を説明するために、AWS版の踏み台構成図を比較として1枚残す。

4. **IAM を第1回に持ってくる** — AWS版は第2回(Terraform回)で IAM を軽く扱っただけだった。GCPは組織/フォルダ/プロジェクト階層とサービスアカウントの理解がないと以降の回が回らないので、第1回に組み込んで時間を厚く取る。

5. **CI/CD が GitHub 前提になる** — AWS版は CodeCommit にリポジトリを作って push する流れ。GCPでは GitHub + Cloud Build トリガーになるため、第7回のハンズオン導線と、第10回の実践テストの提出方法(GitHubブランチ push)を作り直す。

6. **Cloud Run には「インスタンスに入る」概念がない** — AWS版第6回は ECS Exec でコンテナに入る体験がハイライトだった。Cloud Run では代替が限定的なので、ログとメトリクスで中を見る流れに置き換える(第8回の監視回に繋げる伏線にできる)。

7. **証明書が楽になる** — AWS版第7回は「CloudFront用のACMは us-east-1 で作る必要がある」という引っかかりポイントを扱っていた。GCPには相当する罠がないので、その分の尺を別の内容に回す。

---

## 6. 全10回シラバス

各回の構成テンプレート(AWS版の型をそのまま踏襲):

```
タイトル → ロードマップ再掲 → 前回の振り返り → アジェンダ → ゴール(完成構成図)
→ 概念解説 → ハンズオン → 本日のまとめ
→ 宿題1(アンケート) / 宿題2(実装課題) / 宿題3(公式資料を眺める)
→ 参考リンク → リソース削除の注意 → おしまい(次回予告)
```

ハンズオンは AWS版の型を必ず守る:
**作る → 繋がらない → なぜ繋がらないかを説明 → 設定を足す → 繋がる**

### 第1回 GCP基礎 / IAM / Terraform (2026-10-05)

- **AWS版対応**: 第1回 + 第2回を圧縮
- **アジェンダ**: なぜGCPか / 料金体系 / 組織-フォルダ-プロジェクト階層 / リージョン・ゾーン / 割り当て(Quota) / Cloud IAM(プリンシパル・ロール・サービスアカウント) / Cloud Shell / Terraform(HCL・plan/apply/destroy・tfstate on GCS)
- **省略**: インフラ基礎(WAN/LAN/IP/ポート/DNS/SSL)は事前配布の自習資料にし、冒頭15分で要点のみ
- **ハンズオン到達点**: Cloud Shell から `terraform apply` が通り、GCSバックエンドに tfstate が保存される
- **宿題**: Terraform チュートリアル(GCP編) / Cloud IAM ドキュメント

### 第2回 ネットワーク (2026-10-26)

- **AWS版対応**: 第3回
- **アジェンダ**: VPC(グローバル) / サブネット(リージョン) / CIDR設計 / Firewall Rules(タグ・SA) / Routes / Cloud Router + Cloud NAT / Private Google Access / IAP TCP forwarding
- **ハンズオン到達点**: private サブネットのVMに IAP でログインでき、Cloud NAT 経由で外部へ疎通する
- **宿題**: サブネット追加(web/db/cache) / Cloud NAT のリージョン冗長 / VPC ドキュメント

### 第3回 コンピューティング (2026-11-16)

- **AWS版対応**: 第4回
- **アジェンダ**: Compute Engine / マシンタイプ / イメージ / Persistent Disk / OS Login / MIG(概説) / Cloud Load Balancing / Cloud DNS / Google マネージド SSL証明書
- **ハンズオン到達点**: カスタムドメインに HTTPS でアクセスでき、`Hello, Infra Study` が返る
- **宿題**: 起動時の自動起動設定 / VMの冗長化 / Cloud Armor で社内IP制限

### 第4回 データベース (2026-12-07)

- **AWS版対応**: 第5回
- **アジェンダ**: データベースの歴史(RDB/NoSQL) / 用途別の選択 / **GCPの3種類の接続方式** / Memorystore / **Spanner(本編)** / Cloud SQL(軽く) / AlloyDB・Firestore・Bigtable・BigQuery は概説
- **ハンズオン到達点**: アプリから Spanner と Memorystore に接続できる
- **★ 設計変更(2026-08-28)**: 社内で Spanner をメインで使っているため、
  **Spanner を本編に変更**した。当初案では Cloud SQL が主役だったが、
  Cloud SQL(MySQL/PostgreSQL)は既知の人が多いので軽く扱う。
  フェイルオーバーの計測は宿題に回した
- **宿題**: 年末進行と重なるため控えめに。
  Memorystore のリードレプリカ追加 / Spanner のインターリーブ体験 /
  Spanner の主キー設計を調べる / Cloud SQL のフェイルオーバー計測

### 第5回 コンテナ (2026-12-24 木)

- **AWS版対応**: 第6回
- **アジェンダ**: コンテナの歴史 / GCPにおけるコンテナの変遷 / Artifact Registry / Cloud Run / **GKE は概説10分** / Direct VPC egress / サーバレスNEG
- **ハンズオン到達点**: イメージを Artifact Registry に push し、Cloud Run で公開、
  **ロードバランサのバックエンドを VM から Cloud Run に切り替える**
- **★ 構成(2026-08-28)**: 「LBのバックエンドに繋ぐ」を単なる追加ではなく
  **VMからの移行**として構成した。ドメインも証明書もそのままで
  URLマップの向き先だけ差し替えるので、実務の移行手順と一致する。
  VMのバックエンドサービスは残すのでロールバックも説明できる
- **宿題**: Cloud Run のオートスケール設定 / 最小インスタンス数の挙動確認

### 第6回 ストレージ + CDN (2027-01-18)

- **AWS版対応**: 第7回
- **アジェンダ**: Cloud Storage(ストレージクラス / IAM とACL / バージョニング / ライフサイクル / 署名付きURL) / Cloud CDN / キャッシュ制御
- **ハンズオン到達点**: 静的ファイルを Cloud Storage に置き、Cloud CDN 経由で HTTPS 配信、キャッシュ無効化を確認
- **宿題**: バージョニング / ライフサイクルで自動削除 / Cloud Armor でIP制限

### 第7回 CI/CD (2027-02-08)

- **AWS版対応**: 第8回
- **アジェンダ**: CI/CDとは / GitHub連携 / Cloud Build(トリガー・ビルド構成) / Artifact Registry / Cloud Deploy(デリバリーパイプライン・ターゲット) / カナリアデプロイ / ロールバック
- **ハンズオン到達点**: GitHub に push すると自動ビルドされ、Cloud Run へ段階的にデプロイされる
- **宿題**: Cloud Deploy でカナリア / 承認ステップとロールバック / ブランチ指定デプロイ
- **決定(2026-08-28 制作時)**:
  - **Cloud Source Repositories は使わない。** 2024年6月17日に新規提供を終了しており、
    組織として未使用ならAPIも有効化できない。後継は Secure Source Manager だが、
    実務でGitHubを使っているので GitHub 連携で組む
  - **GitHubは共有リポジトリ + 受講者ごとのブランチ。** GitHub App のインストールと
    接続の作成は講師が1回だけ行い、受講者はトリガーをぶら下げるだけにする
  - **Cloud Deploy はハンズオンから宿題へ。** GitHub連携 + Cloud Build で2時間が埋まるため。
    カナリア/ロールバックはスライド解説 + 宿題1・2 で扱う

### 第8回 監視・運用 + その他リソース (2027-03-01)

- **AWS版対応**: 第11回 + AWS版に無かった監視回
- **アジェンダ**: Cloud Monitoring(メトリクス・ダッシュボード・アラートポリシー) / Cloud Logging(ログルーター・シンク・ログベース指標) / Cloud Trace / Error Reporting / Uptime check / SLO / アラート設計の考え方 / Cloud Run functions・Batch・BigQuery は概説
- **ハンズオン到達点**: ダッシュボードを作り、しきい値超過で Slack に通知が飛ぶ
- **宿題**: SLO を1つ定義してアラート / 自分あてメール通知の追加 / ログのコスト削減
- **決定(2026-08-31 制作時)**:
  - **`0. before` に第7回の CI/CD を含めない。** 監視の題材に不要で、
    `cloudbuild_repository` 変数が増えるだけのため。第6回の完成状態(38リソース)にする。
    「積み上げは原則だが、その回に関係ないものまで積む必要はない」と S15 で説明する
  - **Slack 通知チャンネルは講師が1回だけ作る。** `auth_token` の取得に
    ブラウザ作業が要るため。受講者は `data` で表示名参照。第7回の GitHub 連携と同じ形
  - **アラートの発火は「存在しないパスへの Uptime check」。** 仕組みが単純で確実に鳴り、
    Uptime check 自体もアジェンダに入っている
  - **Cloud Trace と Error Reporting は概説のみ。** Trace はアプリへの計装が要り尺が足りない
- **補足**: AWS版アンケートの「インフラの設計についてはまだ理解が及ばなかった」という声に応える回として設計している

### 第9回 試験対策 (2027-03-25 木)

- **AWS版対応**: 第10回
- **アジェンダ**: Google Cloud 認定資格の種類 / ACE と CDL の試験概要・対象者 / サンプル問題 / 模擬試験 / 受験申込(この場で完了させる) / 学習リソース
- **重要**: この回で申込まで済ませることで、第10回までの18日間を受験期間に充てる
- **宿題**: 資格学習 / サンプル問題と模擬試験の再受験
- **決定(2026-08-31 制作時)**:
  - **Terraform コードは無し。** AWS版第10回も同様
  - **模擬試験はその場で解かず宿題に回した。** サンプル問題と申し込みの両方を
    時間内にやると尺が足りないため。S30 で使い方だけ説明する
  - **申し込みに20分を確保。** この回の存在意義がそこにあるので、
    サンプル問題を削ってでも申し込みを優先する、と原稿に明記した
  - **「足りない3つ」を明示するスライド(S19)を追加。**
    ACE出題範囲との対応表を作る過程で、未実施が
    **GKE / 課金管理 / 組織・Cloud Identity** の3か所に固まっていると分かったため
  - **資格情報は変わるので、開催前に更新が必要。** 付録Bに確認項目の一覧を用意した

### 第10回 実践テスト + 総まとめ (2027-04-12)

- **AWS版対応**: 第9回 + 第11回のまとめ
- **構成**: 実践テスト(下記) + 総まとめ + 資格取得状況の共有 + 全体アンケート
- **尺(2026-08-31 決定)**: **2時間のまま。総まとめを15分に圧縮する。**
  実践テスト85分 + 休憩5分 + 総まとめ15分 + 資格共有・アンケート10分 = 120分。
  振り返りを厚くしたい場合は2.5時間に延長する(要事前調整)
- **決定(2026-08-31 制作時)**:
  - **試験2のロードバランサは HTTPS ではなく HTTP。**
    Google マネージド証明書の発行に7〜10分かかり(第6回で実測)、
    60分の試験に収まらないため。部品も1つ減る
  - **提出は GitHub の `exam/<自分の名前>` ブランチに push。**
    AWS版は CodeCommit。第7回で同じことをやっているので手順に迷わない。
    **第7回のアプリ用リポジトリとは別に用意すること**
  - **問2の「指定イメージ」はカスタムイメージを作らず、
    startup-script を問題文に載せる方式にした。**
    講師の事前準備が減り、受講者はコピペで済む
  - **出題範囲から GKE / 課金管理 / 組織・Cloud Identity を外した。**
    この勉強会で扱っていないため(第9回 S19 / 5章 判断21)
  - 配点は 試験1 = 15点、試験2 = 100点、合計 **115点**

---

## 7. 実践テストの設計

AWS版第9回の形式をそのまま踏襲する。

### 試験1: 選択式

- 25分 / 15問 / Google Form 提出
- 部分点なし。複数選択問題は完答のみ得点
- 出題範囲は第1回〜第8回の全範囲
- 結果は別スライド「試験結果発表」で共有、採点はスプレッドシートで管理

### 試験2: Terraform 実技

- 60分 / 4問 / GitHub のブランチに push して提出(AWS版は CodeCommit)
- ルール: 何を見てもOK(ブラウザ検索・過去資料可)。ただし **module 読み込み禁止**、**他人のコードを見るのは禁止**
- 4問は連続していて、前の問題で作ったリソースを次で使う

**出題内容(GCP版)**

| 問 | 内容 | AWS版の対応 |
|---|---|---|
| 1 | VPC + サブネット(public/private) + Firewall Rules + Cloud Router/NAT | VPC + サブネット + IGW + ルートテーブル |
| 2 | GCE を2台、private サブネットに作成(指定イメージ・マシンタイプ) | EC2を2台 |
| 3 | Cloud Load Balancing(バックエンドサービス + ヘルスチェック + 転送ルール) | ALB + ターゲットグループ |
| 4 | Firewall ルールを設定して、LBのIPでブラウザアクセス可能にする | SGルール設定 |

- **合格判定**: ブラウザに `Congratulation!!` が表示されること(AWS版と同じ実物確認方式)
- 問題2で使う指定イメージは、起動すると80番ポートでリクエストを受け付けるものを事前に用意する

### 採点物

- 試験1: 設問15問 + 解答 + 解説
- 試験2: 問題文 + 模範解答(Terraform) + 採点基準
- 採点用スプレッドシート(AWS版 `2022_試験採点` 相当)

---

## 8. 成果物と配置先

### Terraform コード

配置: `/Users/a12665/Documents/personal/infra-study/gcp/`

AWS版(`lesson3/` 〜 `lesson9/`)はリポジトリ直下にあり、既存スライドが
`github.com/shiiman/infra-study//lesson4/0. before` という形で参照しているため、
**AWS版のディレクトリは絶対に移動しない**。GCP版は `gcp/` 配下に新規で作る。

ディレクトリ規約は AWS版を踏襲する:

```
gcp/
├── docs/
│   ├── 2026-08-28-curriculum-design.md   ← このファイル
│   └── slides/
│       ├── lesson1.md
│       └── lesson2.md
├── lesson1/                              # GCP基礎 / IAM / Terraform
│   ├── 1. gcs/                           # tfstate用バケット作成(ローカルstate)
│   ├── 2. backend/                       # backendをGCSへ移行
│   ├── 3. service_account/               # SA作成 → なりすまし失敗
│   ├── 4. iam/                           # リソース単位のIAM付与 → 成功
│   ├── syukudai1/                        # カスタムロール
│   └── syukudai2/                        # Secret Manager + リソース単位IAM
├── lesson2/                              # ネットワーク
│   ├── 1. vpc/
│   ├── 2. subnet/
│   ├── 3. instance/                      # → SSHが通らない
│   ├── 4. firewall/                      # IAP(タグ指定) → SSH成功
│   ├── 5. firewall_internal/             # web→db(SA指定) → ping成功
│   ├── 6. private_google_access/         # → Google APIに到達
│   ├── 7. cloud_nat/                     # → インターネットに到達
│   ├── syukudai1/                        # web/db/cache サブネット追加
│   └── syukudai2/                        # 大阪リージョン + Cloud NAT
├── lesson3/
│   ├── 0. before/                        # 前回までの完成状態(モジュール化)
│   ├── 1. <ステップ名>/
│   │   ├── before.tf                     # 0. before をモジュール参照
│   │   ├── common.tf
│   │   └── ...
│   └── ...
└── ...
```

- ステップディレクトリ名は `<番号>. <名前>` (番号 + ピリオド + 半角スペース + 名前)
- 各ステップディレクトリは**その時点の作業ディレクトリの丸ごとスナップショット**
  (AWS版と同じ。受講者は1つの作業ディレクトリで作業し、リポジトリは答え合わせに使う)
- 宿題の回答例は `syukudai<N>/` に `README.md` 付きで置く。最終ステップからの積み上げで、
  `syukudai2` は `syukudai1` の内容を含む
- `0. before/` は前回の完成状態を引き継ぐ回にのみ置く。
  第1回・第2回は自己完結なので不要(AWS版も第3回には無かった)
- モジュール参照は `github.com/shiiman/infra-study//gcp/lesson3/0. before`
- `common.tf` の中身(第1回で確定)

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  required_version = ">= 1.9.0"

  backend "gcs" {
    bucket = "[プロジェクトID]-tfstate-shiiman"   # ★受講者が自分の名前に書き換える
    prefix = "lessonN"
  }
}

provider "google" {
  project = "[プロジェクトID]"
  region  = "asia-northeast1"
}

variable "user_name" {}
```

- `backend` ブロックには変数が使えないため、バケット名は直書きし
  「★自分の名前に書き換える」コメントを付ける
- リソース名はすべて `${var.user_name}-` prefix を付ける(共有プロジェクトのため)

### スライド

配置先の親フォルダ: (社内で共有)
この配下に **`インフラ勉強会(GCP)`** ディレクトリを作成して置く。

**制作方式**: Markdown で原稿を作り、Google スライドへの流し込みは手作業。

理由: AWS版スライドを読むと、テキストが空で図だけでスライドが成立している箇所が多数ある
(VPC構成図、ALBの経路図、Blue/Greenデプロイの遷移図など)。
Slides API でテキストだけ生成しても図が抜けた抜け殻になるため、
**AWS版デッキを複製してGCP版に差し替える**運用が最短。
GCPも「VPC → サブネット → LB → インスタンス」と構造がほぼ同じなので、既存の図はラベル差し替えで流用できる。

原稿には「このスライドはAWS版◯回目の△△の図を流用、ラベルをこう変更」というレベルまで指示を書く。

原稿の配置: `gcp/docs/slides/lesson<N>.md`

### テスト・アンケート類

- 試験問題/解答/採点基準: `gcp/docs/exam/`
- アンケート設問: `gcp/docs/survey.md`
  **フォームは作成済み**(共有ドライブ「インフラ勉強会(GCP)」フォルダ)。
  各回アンケート / 全体アンケート / 第10回 試験1 の3つ。
  各回アンケートは**1つのフォームに集約**し、冒頭で「第何回か」を選ばせる方式。
  10回分の回答が1つのシートに溜まり、回ごとの推移が見える

---

## 9. 制作の進め方

1. **パイロット2回分**(第1回・第2回)の3点セットを作って型を確定する
2. 型が固まったら残り8回を順次量産
3. 各回の制作単位: 原稿(Markdown) → Terraformコード → 宿題回答例 → 動作確認

### 進捗

| 回 | スライド原稿 | Terraformコード | 宿題回答例 | 実環境での動作確認 |
|---|---|---|---|---|
| 1 | 済 `docs/slides/lesson1.md` (69枚) | 済 `lesson1/` 4ステップ | 済 syukudai1-2 | **済 (2026-08-28)** |
| 2 | 済 `docs/slides/lesson2.md` (63枚) | 済 `lesson2/` 7ステップ | 済 syukudai1-2 | **済 (2026-08-28)** |
| 3 | 済 `docs/slides/lesson3.md` (56枚) | 済 `lesson3/` 0.before + 4ステップ | 済 syukudai1-3 | **済 (2026-08-28)** |
| 4 | 済 `docs/slides/lesson4.md` (53枚) | 済 `lesson4/` 0.before + 3ステップ | 済 syukudai1-3 | **済 (2026-08-28)** |
| 5 | 済 `docs/slides/lesson5.md` (51枚) | 済 `lesson5/` 0.before + 4ステップ | 済 syukudai1-2 | **済 (2026-08-28)** |
| 6 | 済 `docs/slides/lesson6.md` (46枚) | 済 `lesson6/` 0.before + 3ステップ | 済 syukudai1-3 | **済 (2026-08-28)** |
| 7 | 済 `docs/slides/lesson7.md` (48枚) | 済 `lesson7/` 0.before + 3ステップ + `app/` | 済 syukudai1-3 | **済 (2026-08-31)** |
| 8 | 済 `docs/slides/lesson8.md` (48枚) | 済 `lesson8/` 0.before + 3ステップ | 済 syukudai1-3 | **済 (2026-08-31)** |
| 9 | 済 `docs/slides/lesson9.md` (46枚) | **なし**(ハンズオン無し) | — | — |
| 10 | 済 `docs/slides/lesson10.md` (24枚) | 済 `lesson10/` 模範解答4問 + 試験一式 | — | **済 (2026-08-31)** |

**★ 全10回の制作が完了(2026-08-31)★**

- スライド原稿 **10本 / 計 504枚**
- Terraform コードは全 48 ディレクトリで `terraform fmt` 差分なし /
  `terraform validate` 成功(google provider 8.0.0)
- **ハンズオンのある全8回 + 第10回の実践テストを、
  すべて受講者相当の権限で実環境検証済み**(11章に各回の結果)
- コードは `main` に push 済み。`0. before` のモジュール参照が
  素のURLで解決できることを確認した
- 公開リポジトリのため、プロジェクトIDとドメインは変数化して伏せている

### 残っている作業(開催までに)

| 作業 | 対象 | 備考 |
|---|---|---|
| ~~スライドの Google スライドへの流し込み~~ | — | **完了(2026-08-31)**。`docs/slides/README.md` にURL一覧 |
| ~~新規作図~~ | — | **完了(2026-08-31)**。57枚をネイティブ図形で作図。`docs/slides/README.md` |
| ~~アンケート Google Form の作成~~ | — | **完了(2026-08-31)**。`docs/survey.md` にURLと設問 |
| ~~試験1の Google Form 化~~ | — | **完了(2026-08-31)**。自動採点まで設定済み |
| 提出用 GitHub リポジトリ | 第10回 | 第7回のアプリ用とは別に作る |
| 受講者への権限付与(12ロール) | 第1回まで | **付与直後は反映待ちで失敗するので前日までに** |
| 共通イメージの用意 | 第6回まで | `infra-study-common`(作成済み) |
| GitHub App + Cloud Build 接続 | 第7回まで | **作成済み** |
| ビルド用SAの作成(受講者ごと) | 第7回まで | `logging.logWriter` + `clouddeploy.jobRunner` |
| Slack 通知チャンネル | 第8回まで | **作成済み**(`infra-study`) |
| 社内IP(`company_ip`)の実値 | 第3回 / 第6回 | Cloud Armor で使う |
| 会社の受験費用補助の確認 | 第9回 | **空欄のまま当日を迎えないこと** |
| 資格情報の最新化 | 第9回 | 料金・時間・出題範囲。付録Bに確認項目あり |
| 対象者の確定 | 第1回 | S05 に反映する |

### 動作確認の型(第5回以降もこれに従う)

**受講者相当の権限で1回だけ通す。** 講師アカウントで確認してから
別途권限を確認する、という2周はしない(第1回・第2回でやったが無駄だった)。

**方法**

1. 受講者に付与するロールだけを持つサービスアカウントを作る
2. 自分にそのSAの `roles/iam.serviceAccountTokenCreator` を付ける
3. 教材のコードをコピーし、次のパッチを当てる
   - `provider "google"` に `impersonate_service_account` を追加
   - `member = "user:${data.google_client_openid_userinfo.me.email}"` を
     **テスト用SAのメールアドレスの実値**に置換する
   - `user_name` をテスト用の名前に変更
   - `backend` ブロックを削除(ローカルstateで十分)
   - モジュールの `source` をローカルパスに変更(未pushの場合)

> **★ `google_client_openid_userinfo` はなりすまし時に使えない**
>
> provider の `impersonate_service_account` が要求するスコープに
> `openid` が含まれないため、このデータソースは空を返し、
> `Invalid template interpolation value` で apply が失敗する。
>
> gcloud の `--impersonate-service-account` で取ったトークンには
> `openid` が含まれているので、CLIでは同じ問題が起きない。紛らわしい。
>
> 検証時はデータソース参照を実値に置き換えること。
> **教材側は人間のユーザが実行する前提なので、このままでよい**
> (第1回でローカル・Cloud Shell の両方で動作確認済み)。
4. `terraform apply` → 動作確認 → `terraform destroy`
5. 検証後、プロジェクトIAMのバインディングとSAを削除する

**なぜこの方法が良いか**

- グループ経由の権限が一切混ざらないので、**実際の受講者より厳しい条件**になる
- 講師アカウントでは気づけない権限不足を確実に検出できる
- 1周で機能検証と権限検証の両方が終わる

**この方法でカバーできない部分**

`gcloud compute ssh` とアプリの動作確認は人間の操作なので、
自分のアカウントで実施する。Terraform のリソース作成権限
(一番詰まりやすいところ)は1周でカバーできる。

**積み上げの利点**

各回の `0. before` に前回までの全リソースが入っているため、
**最新の回を1本流せば過去の回のリソース作成権限も同時に検証できる**。
例: 第4回を流すと、第2回・第3回のリソースもすべて作られる。

---

### 確定した制作の型(第3回以降もこれに従う)

**スライド原稿の書式**

各スライドを `### SNN | タイトル` で区切り、以下の3要素で構成する。

- `**[本文]**` — スライドに載せるテキスト(コードブロックで囲む)
- `**[図版]**` — 図の作り方。AWS版デッキからの流用指示を「どのスライドのどの図を、
  どのラベルに差し替えるか」のレベルまで書く。新規作図が必要なものは明示する
- `**[話す]**` — ナレーション。スライドには載せない

原稿の冒頭に時間配分表と「押した場合の削り所 / 削ってはいけないスライド」を書く。
末尾に付録として「講師の事前準備チェックリスト」「制作メモ / 要確認事項」
「新規作図が必要なスライド一覧」を置く。

**ハンズオンの型**

AWS版の型を守る: **作る → 繋がらない → なぜ繋がらないかを説明 → 設定を足す → 繋がる**

1ステップ = 1サイクルにする。1つのステップに2つのサイクルを詰めない
(第2回では Firewall Rules を `4. firewall/`(タグ指定)と
`5. firewall_internal/`(サービスアカウント指定)に分割した)。

**ディレクトリの積み上げ**

AWS版と同じく、各ステップディレクトリは **その時点の作業ディレクトリの丸ごとスナップショット**。
受講者は1つの作業ディレクトリ(`~/works/lessonN`)で作業し、
リポジトリのステップディレクトリは答え合わせに使う。
`syukudai<N>/` は最終ステップからの積み上げで、`syukudai2` は `syukudai1` の内容を含む。

**`0. before` に入れられないもの(第6回で判明)**

`0. before` は「前回までの完成状態を1回の apply で再現するモジュール」。
そのため **apply の途中に手作業が挟まる工程は入れられない**。

第6回の `0. before` には第5回の Cloud Run が入るが、
Cloud Run はイメージが存在しないと作成できず、
イメージの push は apply の外側の作業になる。
つまり「リポジトリ作成 → push → Cloud Run 作成」を1回の apply に畳めない。

**対処**: 受講者ごとの Artifact Registry リポジトリは `0. before` から外し、
講師が事前に用意した共通リポジトリ
(`asia-northeast1-docker.pkg.dev/[プロジェクトID]/infra-study-common/app`)
のイメージを Cloud Run に参照させる。
イメージの取得は Cloud Run のサービスエージェントが行うため、
同一プロジェクトなら受講者側に追加権限は要らない。

自分でビルドする体験は第5回で済んでいるので、
第6回で再現する必要はない(第7回のCI/CDでまたやる)。
第6回 S16b でこの理由を1枚使って説明している。

**第7回以降も同じ判断でよい。** 共通リポジトリは作りっぱなしにしておく。

---

## 10. 未決事項

### 決定済み(2026-08-28 パイロット制作時)

- [x] **GCP プロジェクト** — 既存の共有プロジェクト **`[プロジェクトID]`** を全員で使う。
  受講者ごとにプロジェクトは分けない。必要な Quota は事前に申請しておく。
  - 影響: 全リソースに `${var.user_name}-` prefix を付ける。tfstate バケットは
    `[プロジェクトID]-tfstate-<user_name>` で受講者ごとに分ける。
  - **共有プロジェクト固有の制約**: `google_project_iam_binding` /
    `google_project_iam_policy` は権威的リソースで他人のバインディングを消すため、
    教材で一切使わない。IAM はすべてリソース単位
    (`google_service_account_iam_member` / `google_storage_bucket_iam_member` /
    `google_compute_instance_iam_member` / `google_iap_tunnel_instance_iam_member`)で付与する。
    第1回スライド S33 で注意喚起として明示的に扱う。

- [x] **組織階層** — 会社の Cloud Identity 配下で実施する。
  第1回で組織 → フォルダ → プロジェクトの階層を実際のコンソールで見せられる。

- [x] **CIDR** — AWS版を踏襲して `172.16.0.0/16` 系を使う。
  受講者ごとに VPC が別なので、同一プロジェクト内でもサブネット CIDR は全員同じ値でよい
  (GCP はサブネット CIDR の重複を「同一 VPC 内」でのみ禁止する)。
  - `172.16.0.x` public / `172.16.10.x` private / `172.16.20.x` web /
    `172.16.40.x` db / `172.16.50.x` cache / `172.16.100.x` 大阪
  - 社内の標準化ルールに合わせる必要があるかは別途確認(下記「保留中」参照)

- [x] **terraform / google provider のバージョン** —
  `required_version = ">= 1.9.0"` / `google = "~> 8.0"`。
  8.0.0 は 2026-08-26 リリース。開催が 2026-10 〜 2027-04 と長期なので、
  受講者がレジストリで見るドキュメント(既定で最新 = 8.x)と揃う方を選んだ。
  - パイロットの全 15 ディレクトリで `terraform validate` 成功済み(provider 8.0.0)

### 保留中

- [x] 第10回の尺 — **2時間のまま、総まとめを15分に圧縮**(2026-08-31 決定)
- [x] 使用するカスタムドメイン — **`[勉強会のドメイン]`** を Cloud DNS に委譲する方式に決定(12章)
- [x] 親ゾーンへの NS レコード登録 — **完了(2026-08-28)**。
  Cloud DNS にゾーンを作成し、親ゾーン(Route53)に NS を登録済み。
  `dig NS <勉強会のドメイン>` で委譲を確認済み
- [ ] 社内IP(`company_ip` 相当)の実値確認 — 第3回 宿題3 / 第6回 宿題3 の Cloud Armor で使う
- [ ] CIDR を社内の標準化スプレッドシートに合わせる必要があるか
- [x] Cloud Source Repositories の現況確認 — **2024年6月17日に新規提供終了**。
  組織として未使用ならAPIも有効化できない。後継は Secure Source Manager。
  第7回は **GitHub 連携**で組むことに決定(6章 第7回)
- [x] アプリ用の共有 GitHub リポジトリ — **`sumzap/infra-study-app` を作成済み**(2026-08-31)
- [x] Cloud Build の GitHub App + 接続 — **作成済み**(接続名 `infra-study`、2026-08-31)
- [ ] **受講者ごとのビルド用サービスアカウントの作成**(第7回・講師)
  `<名前>-build` を作り、`roles/logging.logWriter` と `roles/clouddeploy.jobRunner` を付与する。
  どちらもプロジェクト単位でしか付けられないため、受講者には配れない
- [ ] **提出用 GitHub リポジトリの作成**(第10回)。第7回のアプリ用とは別に作る
- [ ] **Slack 通知チャンネル** — 作成済み(`infra-study` / `#infra-study-alert`、2026-08-31)
- [ ] 対象者の確定(AWS版は「社員サーバエンジニア全員」) — 第1回 S05 に反映する
- [x] tfstate バケットを `terraform destroy` から守る運用 —
  第1回の最後だけ `-target` でバケット以外を指定する方式に決定(実測で検証済み)。
  第1回スライド S67 に手順を記載。第2回以降は素の `terraform destroy` でよい
- [x] アンケート用 Google Form — **作成済み**(2026-08-31)。`docs/survey.md` にURL。
  各回アンケート / 全体アンケート / 第10回 試験1 の3つ。スライドのURLも差し替え済み
- [x] 受講者ロールの確定 — 第5回時点で **10ロール**。
  **第7回で `roles/artifactregistry.admin` を追加して計11ロール**
  (`artifactregistry.repositories.setIamPolicy` がどのロールにも無いため)。
  第1回 付録A に付与コマンドあり。
  第4回で追加が必要なのは `roles/spanner.admin` と
  `roles/servicenetworking.networksAdmin` の2つだけ
  (`cloudsql.admin` / `redis.admin` は不要。作成権限は Editor に含まれる)
- [ ] 受講者への権限付与を実行する。付与するロール(**12個**)は検証済み。
  **`roles/editor` だけでは足りない**ので、第1回 付録A の付与コマンドをそのまま使うこと。
  **付与直後の1回目の apply は IAM 反映待ちで失敗する**ため、開催前日までに済ませること

### 動作確認の結果(2026-08-28 実施)

`[プロジェクトID]` に対して第1回・第2回の全ステップと宿題を
通しで `apply` → `destroy` した結果。実行環境はローカルの Mac + ADC
(講師のアカウント)。**Cloud Shell では未実施**。

| 確認項目 | 結果 |
|---|---|
| `data "google_client_openid_userinfo"` が動くか | **OK**。ADCに `userinfo.email` スコープあり。IAMメンバーが `user:<講師のアカウント>` に解決された |
| インスタンス単位/SA単位のIAM付与だけでIAP SSHが通るか | **OK**。外部IPなしのVMに踏み台なしでログイン成功 |
| `*_iam_member` 系(setIamPolicy)を作れるか | **OK**。`iap_tunnel_instance` / `compute_instance` / `service_account` / `storage_bucket` / `secret_manager_secret` の5種すべて成功 |
| 必要なAPIが有効か | **OK**。compute / iam / iamcredentials / iap / secretmanager / storage / cloudresourcemanager / serviceusage はすべて有効化済みだった |
| 通しの apply → destroy | 第2回は **OK**(24リソースがクリーンに削除)。第1回は**要注意**(下記) |

**第1回のdestroyに問題があった**

`terraform destroy` をそのまま実行すると、tfstateを置いているバケット自身を
削除するため、最後のロック解放に失敗して `errored.tfstate` が残る。
リソース自体は全て消えるが、後味の悪い終わり方になる。

回避策(検証済み): バケット以外を `-target` で指定して destroy する。
第1回スライド S67 に手順を記載した。第2回以降は素の `terraform destroy` で問題ない。

**その他の実測メモ**

- IAMの反映に **約1分** かかる。apply 直後は権限借用が失敗し続ける。
  「すぐ失敗しても正常」と受講者に先に伝えないと混乱する(S59)
- 第2回 S28 の失敗パターンは受講者の権限で変わる。
  IAP権限を組織/グループから継承している人はタイムアウト、
  していない人は権限エラーになる(S28に両方を記載済み)
- カスタムロールは削除後7日間ソフトデリート状態で残る。
  同じ `role_id` ですぐ作り直せない(`syukudai1/README.md` に記載済み)

### 第10回の動作確認結果(2026-08-31 実施)

**模範解答を受講者相当の権限で通しで apply した。** `user_name = perm10`。

| 段階 | 所要 | 結果 |
|---|---|---|
| 問1 ネットワーク(6リソース) | **49秒** | OK |
| 問2 VM 2台(3リソース) | **37秒** | OK |
| 問3 ロードバランサ(7リソース) | **4分12秒** | OK |
| **問3のあと(問4の前)** | LB伝播に約2分 | **503**(試験の前提どおり) |
| 問4 Firewall(1リソース) | **23秒** | OK |
| **合格判定** | apply から **9秒** | **`Congratulation!!` 表示** |

**apply の合計は約6分。** 60分の試験なので、
**残り54分が「調べて書く時間」**になる。AWS版と同程度の難易度に収まる。

**分かったこと**

- **問3のあと LB が応答するまで約2分かかる。**
  その前は `000`(接続できない)で、503 ではない。
  「503が出ない」と焦る受講者が出るので、
  **S11 に「LBは作ってから2分ほど待つ。503が出れば問3までは正しい」**と追記した
- 問4のあとは**9秒**で通った。HTTP なので証明書待ちが無い分速い
- startup-script は Cloud NAT 経由で nginx を入れられた。
  **問1の NAT が無いと問2以降が全部落ちる**構造は狙いどおり機能する
- 受講者ロールの追加は不要(全12ロールで足りた)

---

### 第8回の動作確認結果(2026-08-31 実施)

**受講者相当の権限で通しで実測した。** `user_name = perm8`。

| 項目 | 結果 |
|---|---|
| Step1 `0. before` + ログ(42リソース) | **9分39秒** |
| Step2 Uptime check + ダッシュボード | 11秒。**3拠点すべてで失敗**(狙いどおり) |
| Step3 アラート → **Slack 着弾** | **約7分** |
| 復旧(文字列を修正) | **約3分**で全拠点成功 |
| 宿題1 SLO + バーンレート | OK |
| 宿題2 メール通知 | OK |
| 宿題3 ログ除外 + ログバケット | OK |
| 受講者ロールの追加 | **`roles/logging.configWriter`(12個目)が必要** |

**制作中に見つけて直したもの(4件)**

1. **「存在しないパスを叩けば失敗する」が成り立たなかった**
   教材アプリは Go の `http.HandleFunc("/", handler)` なので
   **どんなパスでも 200 を返す**。
   → `content_matchers`(本文の中身を見る)方式に変更。
   結果として「**200が返る = 生きている、ではない**」という
   より本質的な論点を扱えるようになり、教材としては改善した

2. **Slack は Markdown を解釈しない**
   `mime_type = "text/markdown"` を指定しても、
   Slack には `##` や `**` が文字のまま出る(コンソールでは整形される)。
   → `documentation` は素のテキストで書く。全ファイルを書き直した

3. **シンクから Cloud Storage への書き込みは1時間ごとのバッチ**
   最初のログが出るまで2〜3時間かかり、**講義中には確認できない**。
   「バケットが空」は権限不足のときも待ち時間のときも同じ見え方になるので、
   切り分けは `writer_identity` の権限確認から入る、と教材に書いた

4. **積み上げディレクトリが、前ステップの手作業を上書きする**
   Step3 で直した `content` が、宿題ディレクトリの apply で元に戻り
   アラートが再発した。第8回 S34 に注意を追記。
   **この勉強会の積み上げ方式そのものに内在する注意点**なので、
   以降の回でも「手で直した変更は次のディレクトリに引き継がれない」を意識すること

---

### 第7回の動作確認結果(2026-08-29 / 08-31 実施)

**講義・宿題とも受講者相当の権限で通しで実測した。** `user_name = perm7`。

| 項目 | 結果 |
|---|---|
| `0. before` + Step1(40リソース) | **約10分** |
| `roles/artifactregistry.admin` の要否 | **必要だと実測で確認** |
| **`ignore_changes` あり** | `gcloud run deploy` で image を変えても **No changes** |
| **`ignore_changes` なし** | `~ image = ... -> ...` で巻き戻そうとする |
| destroy 1回目 | **6分32秒**。失敗は private サブネット1件のみ(第6回と同じ) |
| トリガー作成(受講者権限) | **OK**。共有接続にぶら下げられた(追加ロール不要) |
| push → トリガー起動 | **OK**。`^<自分の名前>$` のブランチフィルタも効いた |
| **Step2 のビルド** | **build/push は成功、deploy で PERMISSION_DENIED**(完全再現) |
| ビルド所要時間 | **約5分20秒**。Goの依存解決が重い。講義中に2回走るので計10分 |

**権限の事前照合が2件当たった**

`gcloud iam roles describe` + `gcloud iam list-testable-permissions` で
事前に洗い出した2件が、そのまま実環境の結果と一致した。

1. `artifactregistry.repositories.setIamPolicy` — 既存10ロールに無い
   → `roles/artifactregistry.admin` を追加(**11個目**)。
   実際に付与前は 403 で落ちた

2. `resourcemanager.projects.setIamPolicy` — 既存10ロールに無く、**配ってもいけない**
   → 持つと共有プロジェクトで誰にでも好きなロールを付けられる。
   ビルドSAに要る `roles/logging.logWriter` はプロジェクト単位でしか付かないので、
   **ビルドSAは講師が事前に作る**設計に変更した(15章 判断16)

**ロール付与直後は反映待ちで失敗する(再現)**

`roles/artifactregistry.admin` を付けた直後の apply が 403 で落ち、
数分おいて再実行したら通った。第1回で確認したのと同じ現象。
**ロール追加は開催前日までに済ませること。**

**`cloudbuild.triggers.*` / `cloudbuild.connections.use` は存在しない**

`gcloud iam list-testable-permissions` で確認した。
トリガーの操作は `cloudbuild.builds.*` に含まれ、`roles/editor` にある。
**実測でも、受講者権限だけで共有接続にトリガーをぶら下げられた。**

**GitHub 連携の実際の手順(2026-08-31 実施)**

1. コンソールで接続を作成 — GitHub App のインストールとトークンの
   Secret Manager 保存が1回で済む。**ここだけブラウザ作業**
2. GitHub App が「選択したリポジトリ」でインストールされていると、
   **後から作ったリポジトリは Cloud Build から見えない**。
   org の設定画面でリポジトリを追加する必要がある(これもブラウザ作業)
3. `gcloud builds repositories create` でリンク(CLIで可)
4. 受講者に渡すのはリンクのフルリソース名1つだけ

2 は見落としやすい。**アプリ用リポジトリは接続を作る前に用意しておくと1往復減る。**

**Cloud Deploy の実行SAには `roles/clouddeploy.jobRunner` も要る(宿題1・2)**

`roles/logging.logWriter` と同じくプロジェクト単位でしか付けられないので、
**講師がビルドSAを作るときに一緒に付ける**。
第7回の事前準備スクリプトに入れてある。

### 宿題の実測結果(2026-08-31)

| 項目 | 結果 |
|---|---|
| 宿題1 apply | OK(7リソース) |
| 1回目のリリース | **カナリアは必ず SKIPPED**。`stable` の手前で人待ち |
| 2回目のリリース | **10% → 50% → 100%** が動いた |
| 宿題2 承認 | `The rollout is pending approval.` で停止 |
| 宿題2 ロールバック | **承認不要**。`stable` のみで100%切り戻し |
| 宿題3 dev ブランチ | **CIだけ起動、Cloud Run のリビジョンは増えず** |

**宿題で見つけて直した設計の穴(2件)**

1. **Cloud Deploy に新規サービスを作らせると、プロジェクト単位の
   `roles/run.developer` が必要になる。**
   サービス単位のIAMは既存サービスにしか付けられないため。
   共有プロジェクトでこれを配ると、受講者のCIが他人の本番 Cloud Run も
   触れてしまうので通せない。
   → **カナリア用サービスの入れ物を Terraform で先に作る**形に変更した。
   講義の「インフラの形は Terraform、動かすものは CI/CD」が、
   宿題では「権限を絞れる形はどれか」という別の理由からも要求される展開になり、
   結果として教材の筋が通った

2. Cloud Deploy 実行SAの `roles/clouddeploy.jobRunner`(上記)

**Cloud Deploy の運用上の注意(教材に反映済み)**

- リリース作成直後の `approve` は `PENDING_RELEASE: failed precondition` で失敗する。
  `PENDING_APPROVAL` になるまで十数秒待つ
- **1ターゲットで同時に進められるロールアウトは1つだけ。**
  進行中のものがあるとロールバックが `PENDING` のまま動かない。
  先に `rollouts cancel` が要る。障害対応で一番ハマるところ
- ロールバックに承認は要らない(`DOES_NOT_NEED_APPROVAL`)。
  カナリアも通らず `stable` のみで100%切り戻し

---

### 第6回の動作確認結果(2026-08-28 実施)

**受講者相当の権限(なりすましSA)で1回通した。** `user_name = perm6`。

| 項目 | 結果 |
|---|---|
| Step1 `0. before` + バケット(33リソース) | OK。**8分34秒**(第5回より軽い) |
| Cloud Run の共通イメージ参照 | OK。自分のリポジトリを作らずに起動できた |
| Step1後の直接アクセス | **403 AccessDenied**(S19の主張どおり) |
| Step2 CDN + URLマップ(4リソース) | OK。1分20秒 |
| 証明書の発行 | 転送ルール作成から ACTIVE まで **7分23秒** |
| **Step2後 `/` → Cloud Run** | **200**。Spanner・Memorystore とも成功 |
| **Step2後 `/static/*` → 403** | **完全再現**。GCSのXMLがそのまま返る |
| Step3 `allUsers` 公開 | OK。12秒で 200 になった |
| `age` ヘッダ | OK。8 → 11 → 14 と増える |
| ファイル更新 → 古いまま | OK。世代が変わっても古いキャッシュが返る |
| キャッシュ無効化 | **3秒**で反映(想定より大幅に速い) |
| 宿題1 バージョニング | OK。世代番号で旧版を取得できた |
| 宿題2 ライフサイクル | OK |
| 宿題3 Cloud Armor | **バグを発見(下記)**。修正後は 許可IP=200 / 非許可IP=403 |
| 宿題3 バケット直アクセス | **200**。LB経由が403でも読める(狙いどおりの落とし穴) |
| 受講者ロールの追加 | **不要**。第5回までの10ロールで足りた |
| destroy 1回目 | **6分35秒**。失敗は private サブネット1件のみ |

**destroy は第5回より軽い**

第5回では「ピアリングの手動削除」と「SERVERLESSアドレスの解放待ち」の
2つの障害があったが、第6回の検証では**ピアリングは1回目の destroy の中で
53秒で消えた**。手動削除は不要だった。

残ったのは Cloud Run の Direct VPC egress が確保した
`purpose = SERVERLESS` のアドレスによるサブネット削除の失敗だけ。
これは第5回と同じで待つしかない。
**実測では Cloud Run の削除から解放まで約2時間20分**かかった
(公式ドキュメントの「1〜2時間」より長い)。
受講者には「当日中には終わらない。翌日に2回目の destroy を流す」と案内すること。

**課金されるリソースは1回目の destroy で全部消える。**
残るのは VPC とサブネット(どちらも無料)のみ。
第6回スライド S43 に手順を記載した。

**バグ1: `0. before` に Cloud Run を入れると apply が通らない**

Cloud Run はイメージが存在しないと作成できない。
`0. before` の中でリポジトリを作っても、そこにイメージは無い。
→ 受講者ごとのリポジトリを `0. before` から外し、
講師が用意した共通リポジトリを参照させることで解決した(9章「制作の型」参照)。

**バグ2: `edge_security_policy` には専用のポリシーが要る**

`google_compute_security_policy` の `type` は既定で `CLOUD_ARMOR` になる。
これをバックエンドバケットの `edge_security_policy` に指定すると失敗する。

```
Error 400: Security policy ... is not an edge security policy., invalid
```

`type = "CLOUD_ARMOR_EDGE"` が必要。
**第3回 宿題3 のポリシーは使い回せない。**
第6回 宿題3 の回答例とスライド S40 のヒントに反映済み。

**バグ3: オブジェクト名とURLのパスは一致させる必要がある**

バックエンドバケットはURLのパスをそのままオブジェクト名にして取りに行く。
`/static/index.html` → オブジェクト `static/index.html`。
バケット直下に `index.html` を置くと404になる。
オブジェクト名に `static/` を付けて解決した(S18で明示)。

**訂正した記述**

- `cache_mode` の既定は `USE_ORIGIN_HEADERS` ではなく **`CACHE_ALL_STATIC`**
- LBのアクセスログは **バックエンドバケットでは有効化できない**
  (`google_compute_backend_bucket` に `log_config` が無く、gcloud にも相当するフラグが無い)
  → S31 は「見られない話」に書き換えた
- `gcloud storage buckets describe --format="yaml(lifecycle)"` は null を返す。
  正しくは `lifecycle_config`
- `gcloud storage sign-url` は署名鍵が要る。
  `--impersonate-service-account` か鍵ファイルが必要

**気づき: ソフト削除が既定でON**

バケットには `soft_delete_policy`(7日保持)が既定で設定されている。
バージョニングとは別の仕組みで、S3 には無い。
「消したのに課金が減らない」の原因になるので S11 で触れることにした。

---

### 第5回の動作確認結果(2026-08-28 実施)

受講者相当の権限(10ロール)で Step0〜4 を通しで実行。**36リソース**が作成できた。

| 項目 | 結果 |
|---|---|
| `0. before`(24リソース) | OK |
| Artifact Registry + push | OK。`gcloud auth configure-docker` の1行で認証 |
| Cloud Run のデプロイ | OK。35秒 |
| **Step2: Spanner 成功 / Cache 失敗** | **完全再現** |
| **Step3: Direct VPC egress で Cache 成功** | **OK**。apply 16秒。反映待ちなし |
| Step4: サーバレスNEG + LB | OK。カスタムドメインで到達 |
| 証明書の使い回し | OK。第3回の証明書がそのまま使われ再発行なし |
| LBの伝播 | **約7分30秒**。講義の最後に来るので進行に注意 |

**destroy に第4回とは別の障害がある**

Direct VPC egress を使うと `purpose = SERVERLESS` のIPアドレスが
サブネットに確保され、Cloud Run を削除してもすぐには解放されない。
サブネットの削除がブロックされる。

```
The subnetwork '<user_name>-private-subnet' is already being used by
'addresses/serverless-ipv4-XXXXXXXXXX', resourceInUseByAnotherResource
```

**これは仕様で、公式ドキュメントに明記されている。**

> After you delete or move your Cloud Run resources, wait 1-2 hours
> for Cloud Run to release the IP addresses before you delete the subnet.
> You cannot manually delete a reserved address.
> https://cloud.google.com/run/docs/configuring/vpc-direct-vpc

検証時は32分待っても解放されなかった。**当日中の完全削除は諦め、
翌日に destroy を実行する運用**にするのが現実的。
課金されるリソースは1回目の destroy で消えるので実害はない。
第5回スライドの 付録A-2 に手順を記載した。

**この回の核心(S28 → S34)は狙いどおり動いた。**
Cloud Run は VPC の外にいるため Spanner には繋がるが Memorystore には繋がらず、
`vpc_access` ブロックを1つ足すだけで解決する。
第4回の「3種類の接続方式」がそのまま回収できている。

**ロール構成は10個で確定**

追加が必要だったのは `roles/run.admin`(`run.services.setIamPolicy`)のみ。
`roles/artifactregistry.admin` は不要だった。

**第4回・第5回で傾向がはっきりした。**
GCP は作成・更新・削除の権限を `roles/editor` に広く含めており、
**`setIamPolicy` だけが別ロール**になっている。
第6回以降もこのパターンで照合すれば、必要ロールを事前に特定できる。

---

### 受講者権限での検証(第2回〜第4回まとめて・2026-08-28)

**第4回を1本流せば第2回・第3回のリソースも同時に検証できる**(`0. before` に
積み上がっているため)。この方法で第2〜4回の権限をまとめて確認した。

**結果: 第2〜4回の全リソース(Cloud SQL 含む)が受講者権限だけで作成できた。**

- `3. spanner` 時点で **31リソース**
- 宿題2(Cloud SQL / REGIONAL)を足して **34リソース**。作成 10分12秒

内訳(第4回の `3. spanner` 時点):

- 第2回: VPC / サブネット×2 / Firewall×2 / Cloud Router / Cloud NAT
- 第3回: web VM / SA / インスタンスグループ / ヘルスチェック /
  バックエンドサービス / URLマップ / HTTPプロキシ / HTTPSプロキシ /
  グローバルIP / 転送ルール×2 / SSL証明書 / DNSレコード / IAP関連IAM×3
- 第4回: グローバルアドレス(VPC_PEERING) / サービスネットワーキング接続 /
  Memorystore / Spanner インスタンス / Spanner データベース / Spanner IAM

**ロール構成を簡素化できた**

当初 `roles/cloudsql.admin` / `roles/redis.admin` も必要だと想定していたが、
**Spanner / Cloud SQL / Memorystore の作成権限は `roles/editor` に含まれていた**。

`roles/editor` に無く、追加が必要だったのは次の2つだけ。

| 不足権限 | 補完先 |
|---|---|
| `spanner.databases.setIamPolicy` | `roles/spanner.admin` |
| `servicenetworking.services.addPeering` | `roles/servicenetworking.networksAdmin` |

**確定した受講者ロール(計9)**

```
roles/editor
roles/iam.serviceAccountAdmin
roles/iam.roleAdmin
roles/storage.admin
roles/secretmanager.admin
roles/compute.instanceAdmin.v1
roles/iap.admin
roles/spanner.admin                      ← 第4回で追加
roles/servicenetworking.networksAdmin    ← 第4回で追加
```

第1回 付録A の付与コマンドを9ロールに更新済み。

> **注意**: ロール付与直後の1回目の apply は失敗する。
> IAMの反映に1分程度かかるため。再実行すれば通る。

---

### 第4回の動作確認結果(2026-08-28 実施・一部)

Spanner をメインに据えた構成で検証。**教材のバグを2件見つけて修正した。**

| 確認項目 | 結果 |
|---|---|
| `0. before`(23リソース)の apply | OK。4分48秒 |
| 限定公開サービスアクセス + Memorystore | OK。6分5秒 |
| Spanner の作成(DDL・インターリーブ含む) | OK。**1分6秒**。Cloud SQLよりずっと速い |
| **外部IPなしVMから Spanner へ到達** | **OK**。`gcloud spanner ... execute-sql` が成功 |
| **Spanner の IAM** | **OK**。データベース単位の `roles/spanner.databaseUser` だけで足りた |
| **go-sql-spanner でのビルドと接続** | **OK**。`DB接続(Spanner): 成功` |
| Spanner + Memorystore の同時接続 | OK |
| Cloud SQL(REGIONAL)の作成 | OK。9分28秒。プライマリ 1-a / セカンダリ 1-c |
| **`password_wo` が tfstate に残らないか** | **OK**。`password: None` / `password_wo: None` のみ。実値の grep は0件 |
| アプリから Cloud SQL / Memorystore への接続 | OK |
| destroy | **1回では終わらない**(下記バグ3) |

**見つけたバグ1: 貸し出しレンジが小さすぎた**

`private_service_cidr = "172.16.200.0/24"` にしていたが、
Memorystore を作った時点でブロックが埋まり、Cloud SQL の作成が失敗した。

```
Couldn't find free blocks in allocated IP ranges.
Please allocate new ranges for this service provider.
```

`/20` に変更して解決。Googleは `/16` を推奨している。

さらに、**Cloud SQL は作成に失敗すると `state: FAILED` で残る**。
Terraformのstateには入らないので、次のapplyは
`The Cloud SQL instance already exists` で失敗する。
`gcloud sql instances delete` してから再実行が必要。
受講者全員がこれを踏むところだった。

**見つけたバグ2: e2-micro ではアプリがビルドできない**

Spanner のクライアントライブラリ(Google Cloud Go SDK + gRPC)は依存が大きく、
第3回まで使っていた e2-micro ではビルドが終わらない。

| マシンタイプ | 結果 |
|---|---|
| e2-micro (2共有vCPU / 1GB) | **16分経っても完了せず**(load average 4.11) |
| e2-medium (2vCPU / 4GB) | **5分16秒で完了** |

**第3回のVMも e2-medium に変更した。**
`lesson4/0. before` は「第3回までの完成状態」なので、
第3回が e2-micro のままだと `0. before` の中身と食い違ってしまうため。

副次的に第3回のビルドも速くなった。

| 回 | マシンタイプ | ビルド時間 |
|---|---|---|
| 第2回 | e2-micro(VM2台。疎通確認のみ、ビルドなし) | — |
| 第3回 | **e2-micro → e2-medium** | 6分46秒 → **2分14秒** |
| 第4回 | e2-medium | 5分16秒(Spannerクライアント込み) |

第3回の待ち時間の合計も 17分 → **12分** に改善した。

**見つけたバグ3: destroy が1回で終わらない**

Cloud SQL / Memorystore を消したあと、限定公開サービスアクセスの
接続の削除で失敗する。

```
Error: Unable to remove Service Networking Connection
Failed to delete connection; Producer services
(e.g. CloudSQL, Cloud Memstore, etc.) are still using this connection.
```

Terraform の削除順序自体は正しい(`depends_on` によりDBが先に消え、
実際に Cloud SQL / Memorystore / Spanner は消えている)。
Google 側でピアリングが解放されるまでにラグがあるのが原因。

**待っても解決しない。** DBを全て削除した状態で12分間・6回リトライしたが
毎回同じエラーになった。

解決手順:

```
terraform destroy      # DBは消える。ピアリングの削除で失敗
gcloud compute networks peerings delete servicenetworking-googleapis-com \
  --network=<user_name>-vpc
terraform destroy      # 33秒で完了
```

ピアリングが残るとVPCも消せない。共有プロジェクトなので消し残しは
他の受講者のQuotaを圧迫する。第4回スライドに 付録A-2 として手順を追加した。

**Cloud SQL は講義から外して宿題に回した。**
作成に10分かかるうえ、社内では既知の人が多いため。
講義では概説のみ(S41〜S44)とし、構築とフェイルオーバー計測は `syukudai2/` へ。

これにより待ち時間は **約12分**(ビルド5分 + Memorystore 6分 + Spanner 1分)。
Spanner の講義時間も 35分 → 42分 に増やした。

---

### 第3回の動作確認結果(2026-08-28 実施)

Step0〜4 と宿題2・3を通しで apply → destroy 済み。詳細は
`docs/slides/lesson3.md` の付録B。

**原稿の記述を4箇所修正した。**

| 箇所 | 誤 | 正(実測) |
|---|---|---|
| S31 | 502 Server Error | **503 Service Unavailable**(バックエンド全滅時は503) |
| S31 | (記載なし) | apply直後は無応答。**約1.5分**で503が返るようになる |
| S33 | ヘルスチェック 20〜30秒 | **37秒** |
| S42/S44 | 証明書 数分〜60分 | **8分20秒**(ACTIVE後さらに約1分のラグ) |
| S16 | (記載なし) | アプリのビルドに**約7分**(その後 e2-medium 化で2分14秒に改善) |

**待ち時間が合計17分ある。** 2時間の講義でこれは大きいので、
解説を挟める順序に原稿を組んである。当日は「先にコマンドを流してから解説」を推奨。

その他:

- モジュール参照(`github.com/shiiman/infra-study//gcp/lesson3/0. before`)は
  ディレクトリ名にスペースがあっても素のURLで解決できた
- destroy は28リソースが4分19秒でエラーなく完了。LBの依存順序も問題なし
- Cloud Armor は反映に約1分。許可外IPから403、バックエンドはHEALTHYのまま
  (ヘルスチェックはCloud Armorの影響を受けないという記述を実証)

---

### Cloud Shell での確認結果(2026-08-28 実施)

`gcloud cloud-shell ssh` で実際の Cloud Shell に接続して確認した。

| 確認項目 | 結果 |
|---|---|
| ADC のスコープ | **OK**。`userinfo.email` を含む。`data "google_client_openid_userinfo"` が `terraform apply` で正しくメールアドレスを返した |
| Terraform がプリインストールされているか | **NO。入っていない** |
| 既定プロジェクト | 各自の個人プロジェクトになっている。`gcloud config set project` が必須 |
| gcloud のバージョン | 581.0.0(ローカルと同じ) |
| 入っているもの | git / go / python3 / docker / kubectl |

**Terraform が Cloud Shell から外されていた(教材への影響大)**

`/google/bin/terraform` というファイルは残っているが、中身は
「自分でインストールしてください」と案内を表示するだけのスタブスクリプト。
`/google/bin` は PATH にも入っていない。

さらに Cloud Shell は **$HOME 以外が再接続でリセットされる**ため、
`sudo apt install terraform` では次のセッションで消えてしまう。

対応(検証済み): $HOME 配下にバイナリを置き、PATH を `~/.bashrc` に書く。

```
mkdir -p ~/bin
cd /tmp
curl -sLO https://releases.hashicorp.com/terraform/1.16.0/terraform_1.16.0_linux_amd64.zip
unzip -o terraform_1.16.0_linux_amd64.zip -d ~/bin
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

- `Terraform v1.16.0` の起動、`~/.bashrc` 経由での PATH 永続化を実機で確認
- `~/bin` の容量は約115MB(ホームは5GB)
- 第1回に **S38b「Terraform をインストールする」を新規追加**した(所要4分程度)
- 第2回以降は不要。第1回でだけ発生する作業

### 受講者相当の権限での検証結果(2026-08-28 実施)

**`roles/editor` だけでは足りない。** `roles/editor` の権限一覧(11,979個)を
照合したところ、`iam.serviceAccounts.setIamPolicy` /
`storage.buckets.get・setIamPolicy` / `compute.instances.setIamPolicy` /
`iap.tunnelInstances.get・setIamPolicy` / `iam.roles.create・delete` /
`secretmanager.secrets.setIamPolicy` が含まれていない。
このため Editor だけだと **第1回 Step4(IAMハンズオン)と第2回 Step4(IAP)が
両方とも動かない**。どちらもその回の核心。

必要なロール構成(第1回 付録A に付与コマンドを記載):

```
roles/editor
roles/iam.serviceAccountAdmin
roles/iam.roleAdmin
roles/storage.admin
roles/secretmanager.admin
roles/compute.instanceAdmin.v1
roles/iap.admin
```

この7ロールだけを持つサービスアカウントを作り、なりすまして
第1回・第2回の全ステップと全宿題を通しで実行した結果、**すべて成功**した。
グループ経由の権限が混ざらない条件での検証なので、実際の受講者より厳しい条件。

| 実行内容 | 結果 |
|---|---|
| 第1回 全ステップ + 宿題1・2 | OK(9リソース、backend移行含む) |
| 第2回 Step1〜7 + 宿題1・2 | OK(25リソース) |
| destroy(第2回は素、第1回は `-target`) | OK |

検証後、付与したプロジェクトIAMバインディングとテスト用SAは削除済み
(バインディング数は元の62件に復帰)。

**残りは第3回の制作時に確認する**

Cloud Shell での全ステップ通し apply は未実施だが、**追加で確認する必要は薄い**と判断した。
Cloud Shell 固有のリスクは個別に潰してあり、残るのは
「同じコードが同じ ADC で動くか」だけのため。

| Cloud Shell 固有の懸念 | 状態 |
|---|---|
| Terraform が入っていない | 判明済み。第1回 S38b でインストール手順を追加 |
| ADC に `userinfo.email` スコープがあるか | 確認済み。`terraform apply` でデータソースが動作 |
| 既定プロジェクトが個人プロジェクト | 判明済み。S38 で切り替えを明示 |
| 全ステップの apply | 未実施 → **第3回のハンズオンを Cloud Shell で組む段階で自然に判明する** |

第3回の制作時に Cloud Shell で作業すれば、第1回・第2回のコードも同時に踏むことになる。
そこで問題が出たら第1回・第2回に遡って修正する。

付録A の代替案「Editor + カスタムロール1つ」も同様に未検証。
採用する場合のみ確認すればよい(現行の7ロール構成は検証済みなので、そのままでも支障はない)。

---

## 11. パイロット制作で判明した、第3回以降への申し送り

### google provider 8.0 の破壊的変更で効いてくるもの

第1回・第2回で使うリソースには影響なし。以降の回で注意が要るのは次の2点。

- **第3回(Cloud Load Balancing)**: `google_compute_backend_service` と
  `google_compute_global_forwarding_rule` の `load_balancing_scheme` の既定値が
  `EXTERNAL` → `EXTERNAL_MANAGED` に変更された。
  Global External Application LB を作るなら既定のままでよいが、
  ネット上のサンプルは 7.x 以前を前提に `EXTERNAL` を明示していることが多いので、
  スライドで「明示しなくてよくなった」ことに触れる。
- **`google_iap_brand` / `google_iap_client` が削除された**。
  IAP の OAuth Admin API が停止したため。
  第2回で使う **IAP TCP forwarding には影響しない**が、
  LB に IAP(Web 認証)をかける構成を扱う場合は Terraform で管理できない。

### 設計書 5章「置換では済まない設計判断」への追加

第2回の制作中に判明した、AWS版をなぞると破綻する箇所。

8. **public subnet / private subnet という区別が GCP に存在しない** —
   AWS では「IGW へのルートを持つルートテーブルが紐づいているか」で決まっていたが、
   GCP のサブネットにその属性はない。インターネットに出られるかを決めるのは
   「VM が外部 IP を持つか」「Cloud NAT があるか」の2つだけ。
   AWS 経験者ほど引っかかるので、第2回で1枚使って明示的に扱う(S09)。
   第3回以降でも `public-subnet` という名前はあくまで運用上の目印として扱うこと。

9. **Private Google Access という AWS に無い概念が入る** —
   外部 IP のない VM から Google API へ、インターネットに出ずに到達させる設定。
   AWS の VPC エンドポイントに近いが、サブネットのフラグ1つで全 Google API が対象になる。
   第2回のハンズオンでは **Cloud NAT より先に** これを教える順序にした
   (逆順だと NAT 経由で到達できてしまい、PGA の効果が見えなくなるため)。

11. **マネージドDBへの接続方式が3種類ある** —
    AWS では RDS も ElastiCache も自分の VPC のサブネットに ENI を作って入ってきたので、
    「サブネットグループ + セキュリティグループ」の1パターンで済んだ。
    GCP は接続方式が分かれる。

    | 方式 | サービス | 必要な準備 |
    |---|---|---|
    | Google API 経由 | Spanner / BigQuery / Cloud Storage | Private Google Access(第2回で有効化済み) |
    | VPCピアリング | Cloud SQL / Memorystore | 限定公開サービスアクセス(グローバルアドレス予約 + サービスネットワーキング接続) |
    | Auth Proxy | Cloud SQL(別解) | プロキシの起動 |

    「Spanner を作ったのに繋がらない」と「Cloud SQL を作ったのに繋がらない」は
    原因が全く違う。第4回 S17 で明示的に扱う。

    **第5回(Cloud Run)でこれがそのまま効いてくる。**
    Cloud Run は VPC の外で動くため、Spanner には繋がるが
    Memorystore には繋がらない。Direct VPC egress の設定が必要になる。
    第5回 S29 の「繋がらない→繋がる」サイクルの根拠がここ。

10. **IAP は「ネットワークの許可」と「IAM の許可」の2層が揃わないと通らない** —
    AWS の踏み台は「SG + SSH 鍵」の2つだったが、GCP の IAP は
    Firewall Rule + `roles/iap.tunnelResourceAccessor` +
    `roles/compute.osAdminLogin` + `roles/iam.serviceAccountUser` の
    実質4つを揃える必要がある。
    第2回 S35 で「3つのゲート」として図解している。
    エラーの種類(タイムアウト = ネットワーク / 権限エラー = IAM)で
    切り分けられることを教えると、以降の回の障害切り分けが楽になる。

14. **CI/CD のサービス数が 4 → 1 になる** —
    AWS版第8回は CodeCommit / CodeBuild / CodeDeploy / CodePipeline の
    4サービスと、それぞれのIAMロールを作る回だった。
    GCPは **Cloud Build 1つがビルドもデプロイもやる**ので、
    「パイプラインで3つのサービスをつなぐ」という説明構造が丸ごと消える。
    設定ファイルも `buildspec.yml` + `appspec.yml` → `cloudbuild.yaml` の1つ。
    空いた尺は **権限設計**(下記15)に回す。

15. **デプロイ権限は2階建てになっている** —
    Cloud Build が Cloud Run にデプロイするには
    `roles/run.developer`(デプロイ先を更新する)と
    `roles/iam.serviceAccountUser`(Cloud Run の実行SAになりすます)の
    **両方**が要る。1つ目だけでは通らない。
    AWS の `iam:PassRole` と同じ考え方で、AWS版でも CodePipeline のロールに
    入れていたが、GCPではエラーが出て初めて気づく形になる。
    第7回 S25〜S27 の「繋がらない→繋がる」サイクルの核。

16. **プロジェクト単位のIAMは受講者に配れない** —
    Cloud Build のビルド用SAには `roles/logging.logWriter` が要るが、
    Cloud Logging の権限は**プロジェクト単位でしか付けられない**。
    それを付けるための `resourcemanager.projects.setIamPolicy` を配ると
    共有プロジェクトで誰にでも好きなロールを渡せてしまうため、渡せない。

    **対処**: ビルド用SAは講師が事前に作り、受講者は
    `data "google_service_account"` で参照する。
    受講者が自分で付けるのはリソース単位の権限だけにする。

    これは勉強会の都合ではなく実務でもそうなるので、
    「プロジェクト全体のIAM = 基盤チーム / リソース単位 = 使う人」という
    分界の説明として教材に組み込んだ(第7回 S17b)。

17. **Terraform と CI/CD の責務分界を教える必要がある** —
    第6回まではデプロイも `terraform apply` だったが、
    第7回からイメージを決めるのは CI/CD になる。
    `lifecycle { ignore_changes = [template[0].containers[0].image] }` が
    無いと、次の apply で古いイメージに巻き戻る。
    AWS版にはこの論点が無かった(ECSのタスク定義はCodeDeployが持つ前提だった)。
    第7回 S35〜S37 で1セクション使う。

18. **監視回は AWS版に無い。丸ごと新規制作になる** —
    AWS版は12回のうち監視だけを扱う回が無く、
    第11回「その他・まとめ」でCloudWatchに軽く触れる程度だった。
    GCP版 第8回は**流用元が無い**ので、構成から作る必要がある。
    設計書の補足にあるとおり、AWS版アンケートの
    「インフラの設計についてはまだ理解が及ばなかった」への回答にあたる回なので、
    個々のサービス紹介ではなく **組み合わせて運用する話** に寄せた。

    軸は「**症状を鳴らす。原因はダッシュボードとログで調べる**」
    (Google SRE本の考え方)。
    ハンズオンは「ダッシュボードを作る → 失敗しているのに誰も気づかない →
    アラートを繋ぐ」というサイクルにして、
    **ダッシュボードだけでは監視したことにならない**を体験させる。

19. **監視まわりの権限はほとんど `roles/editor` に入っている** —
    ダッシュボード / アラートポリシー / 通知チャンネル / Uptime check /
    SLO / ログベース指標は Editor で作れる。
    足りないのは **ログルーター系(シンク・除外・ログバケット)** だけで、
    `roles/logging.configWriter` が必要になる(**12個目**)。
    第4回以降の「`setIamPolicy` だけ別ロール」とはパターンが違い、
    ログ設定の書き込みが丸ごと別ロールに切り出されている。

20. **シンクは権限不足でも静かに失敗する** —
    `google_logging_project_sink` は `unique_writer_identity = true` にすると
    専用SAが払い出されるが、そのSAに書き込み権限を付けないと
    **エラーも出ないまま何も流れない**。
    「シンクは作ったのにバケットが空」という状態になり、
    半年後に監査ログが1件も無いことに気づく、という事故につながる。
    第7回のデプロイ権限(2つ要る)と構図は同じだが、
    **失敗が静か**な分こちらのほうが厄介。第8回 S19 で1枚使う。

21. **ACE の出題範囲に対して、この勉強会の未実施は3か所に固まる** —
    第9回の制作で ACE 試験ガイド(5セクション)と全8回を突き合わせた結果、
    触れていないのは次の3つだけだった。

    | 抜け | ACEのどこ | なぜ扱わなかったか |
    |---|---|---|
    | **GKE** | 3.2 / 4.2 | 第5回で Cloud Run を選んだ理由として比較したのみ |
    | **課金管理** | 1.2 | 共有プロジェクトのため課金アカウントを触れない |
    | **組織・フォルダ・Cloud Identity** | 1.1 | 同上。組織ポリシーを設定できない |

    いずれも**共有プロジェクトで勉強会をやる構成上の制約**か、
    **意図的にスコープから外したもの**で、設計ミスではない。
    第9回 S19 で受講者にも「ここが足りない」と明示する。

    **第10回の実践テストを作るときも、この3つは出題できない**ので注意。

22. **gcloud コマンドを問う問題が出る** —
    この勉強会は Terraform 中心で組んだが、ACE は
    **gcloud コマンドの選択肢**を問う問題が多い。
    Terraform しか触っていないと、細かいフラグで迷う。
    各回の「確認」で打っていた gcloud コマンドが、そのまま試験範囲になっている。
    第9回 S21 で「各回で打ったコマンドを見返すこと」と案内する。

12. **Cloud CDN は独立したサービスではない** —
    CloudFront は「ディストリビューション」という独立したリソースで、
    オリジン・証明書・独自ドメイン・ビヘイビアを全部その中に設定していた。
    Cloud CDN はロードバランサのバックエンドに付ける**機能**でしかなく、
    `enable_cdn = true` の一行で有効になる。
    第3回で作った証明書とドメインをそのまま使えるので、
    7 の「ACM は us-east-1」の罠が無いこととあわせて、
    AWS版第7回の尺がかなり空く。
    その分を **URLマップのパスルール**(`/static/*` を
    バックエンドバケットへ、それ以外を Cloud Run へ)に回した。
    第3回で「今回は振り分けをしないので default だけ」と言ったURLマップが、
    第6回でようやく本領を発揮する構成にしてある。

13. **バックエンドバケットには OAI / OAC に相当する仕組みが無い** —
    AWS版第7回は「CloudFront の OAI を作り、
    その principal にだけ GetObject を許可するバケットポリシーを書く」で
    **バケットを非公開のまま CDN 配信できた**。
    GCP のバックエンドバケットにはこれが無く、
    `allUsers` に `roles/storage.objectViewer` を与える必要がある。
    つまり `storage.googleapis.com` から直接読めてしまう。
    - 第1回 S25 で「`allUsers` は事故の元」と教えた直後の回で、
      意図的に `allUsers` を使うことになるので、必ず理由を説明すること
    - 非公開のまま配信したい場合は署名付きURL / 署名付きCookie になる(第6回 S28)
    - **Cloud Armor をバックエンドバケットに付けても、
      バケット直アクセスは素通しになる**。ここは第6回 宿題3 で
      受講者に体験させる落とし穴にしてある

---

## 12. カスタムドメインの扱い(第3回の前提)

### AWS版はどうなっていたか

AWS版 第4回のスライドで確認した実際の構成。

```
ホストゾーン    [AWS版のドメイン]     (Route53。事前に用意済み)
受講者のURL     https://[user_name].[AWS版のドメイン]
```

- Terraform はゾーンを**作らず**、`data "aws_route53_zone"` で参照するだけだった
- レコードは受講者ごとに `${var.user_name}.${zone.name}` の A レコード(ALBへのalias)
- ACM証明書もワイルドカードではなく受講者ごとに個別発行
- リポジトリ上は `route53_host_name = ""` と伏せられている
  (`// TODO: route53で設定しているhostを指定`)。公開リポジトリのため

### GCP版の決定

ゾーンが Route53 にあるため、そのままでは Cloud DNS から操作できない。
**`[勉強会のドメイン]` を Cloud DNS に委譲する**方式に決定した。

```
ホストゾーン    [勉強会のドメイン]   (Cloud DNS)
受講者のURL     https://[user_name].[勉強会のドメイン]
```

AWS版の `[AWS版のドメイン]` の**サブドメインではなく、親ドメイン直下の兄弟ゾーン**。
AWS版のゾーンから完全に独立するので、AWS版の設定に一切触らずに済む。

検討した他案:

| 案 | 内容 | 不採用の理由 |
|---|---|---|
| A | Route53 のゾーンに GCP LB の A レコードを直接追加 | google provider だけでは書けず、aws provider 併用か手動になる。第3回のハンズオンが濁る |
| C | 新規ドメインを取得 | 費用と手間が増える。既存ドメインがあるので不要 |

### 段取り(2026-08-28 完了済み)

1. Cloud DNS に `[勉強会のドメイン]` のマネージドゾーンを作成する
2. 払い出された NS レコード4本を **親ゾーン**に登録する
3. `dig NS [勉強会のドメイン]` で委譲を確認する

```
gcloud dns managed-zones create <ゾーン名> \
  --project=<プロジェクトID> \
  --dns-name="<勉強会のドメイン>." \
  --description="インフラ勉強会(GCP)用。受講者が data で参照する。削除しないこと" \
  --visibility=public

# 払い出されたNSを確認して、親ゾーンに登録する
gcloud dns managed-zones describe <ゾーン名> --format='value(nameServers)'
```

> ゾーンは **Terraform 管理にしていない**。受講者が data で参照する共有リソースのため、
> 誰かの destroy で消えないように gcloud で手動作成している。

> **注意**: NS の登録先は `[AWS版のドメイン]` ではなく **その親ドメイン**。
> AWS版のときと違い、apex ゾーンへの書き込み権限が必要だった。
> 親ゾーンは Route53 にあり、そちらに NS を登録して委譲が完了している。

**Google マネージド SSL 証明書は DNS が正しく引けることが発行条件**なので、
委譲は第3回(2026-11-16)より前に完了させておくこと。
証明書のプロビジョニングにも数十分かかるため、当日その場で作ると尺が持たない。
第3回のハンズオンでは、証明書リソースを作ってから `ACTIVE` になるまで待つ流れになる。
待ち時間に MIG やマシンタイプの話を入れる構成にすると尺が収まる。

### 第3回のコードでの扱い

AWS版と同じく、ゾーンは Terraform で作らず data ソースで参照する形にする。

```hcl
variable "dns_zone_name" {}   // Cloud DNS のマネージドゾーン名

data "google_dns_managed_zone" "public" {
  name = var.dns_zone_name
}

resource "google_dns_record_set" "web" {
  name         = "${var.user_name}.${data.google_dns_managed_zone.public.dns_name}"
  managed_zone = data.google_dns_managed_zone.public.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.lb.address]
}
```

> ゾーンを Terraform 管理にすると、受講者の誰かが `destroy` したときに
> 全員のドメインが消える。共有プロジェクトなので data 参照が必須。

### あわせて決めておくこと

AWS版では `company_ip`(会社のIP)も同様に伏せられていた
(`// TODO: 会社のIP`)。GCP版では以下で必要になる。

- 第3回 宿題3: Cloud Armor で社内IP制限
- 第6回 宿題3: Cloud Armor でIP制限

こちらも第3回の制作までに実値を確認しておくこと(10章の保留中に記載)。

---

## 13. 現場からのフィードバックへの対応(2026-09-01)

朝倉さんから、nishiki / ghost との差分として6項目の提案をいただいた。
**全10回とも既に120分ぴったりで組んであった**ため、
追加分は「既存を圧縮する」「待ち時間を説明枠に変える」で捻出した。

| # | 指摘 | 対応 | どこに |
|---|---|---|---|
| ① | Terragrunt / SOPS | **第7回に置いた**(第1回ではなく) | S34g / S34h |
| ② | Private Service Connect | **接続方式を3種類→4種類に** | 第4回 S17 / S20b / S20c |
| ③ | GitHub Actions + Workload Identity | **ハンズオン(Step4)を新設** | 第7回 S34b〜S34j |
| ④ | Datadog | 監視の考え方に併記 | 第8回 S12b / S12c |
| ⑤ | Pub/Sub → BigQuery | その他リソースに追加 | 第8回 S38b |
| ⑥ | 料金 / 負荷試験 / キャパプラ | **触りだけ**(新セクション) | 第8回 S39b〜S39d |

### 判断23: Terragrunt / SOPS は第1回ではなく第7回に置く

指摘は「GCP基礎 / IAM / Terraform の回で」だったが、**第7回に置いた**。

- 第1回は Terraform 初見の人もいる想定で、既に69枚と最長
- Terragrunt は「Terraform を素で理解したうえで使う道具」なので、
  一通り書いたあとのほうが理解が早い
- 第7回の「責務の分界」(Terraform と CI/CD の境界)と文脈が合う
- **Step4 のビルド待ち(約5分)に挟めるので、尺のコストが実質ゼロになる**

### 判断24: 接続方式は「3種類」ではなく「4種類」と教える

PSC は単なる4つ目の選択肢ではなく、**①限定公開サービスアクセスの後継**。
第4回で最大のハマりどころとして扱っている
「貸出レンジを /24 にすると Cloud SQL が作れない」は、**PSC なら起きない**
(レンジの貸し出し自体が不要)。

**ハンズオンは①のままにした。**

- ①のほうが「Googleが管理する別VPCにいる」という構造がそのまま見える
- PSCはその構造を隠すぶん、初見だと「なぜエンドポイントが要るのか」が分からない
- 実環境で検証済みのコードを作り直すコストが大きい

S20b で「①の何を解決したのか」として扱い、S20c で使い分けを示す。

### 判断25: Step4 の WIF は「プールは講師、紐付けは受講者」で切る

第7回の主題(リソース単位のIAM)と噛み合う切り方にした。

| | 誰が | 理由 |
|---|---|---|
| WIF プール / プロバイダ | 講師 | プロジェクトに1つでよい。作成はプロジェクト単位の操作 |
| SAへの紐付け | **受講者** | サービスアカウント単位のIAM。第7回で繰り返してきた話そのもの |
| ワークフロー | **受講者** | cloudbuild.yaml と同じことを別の書き方で |

**リポジトリ変数(Variables)は全員共有になる**ので、
受講者ごとに違う値(リポジトリ名 / サービス名 / SA)はそこに入れず、
ワークフロー側で `${{ github.ref_name }}`(= ブランチ名 = 自分の名前)
から組み立てる。Cloud Build の `substitutions` と同じ発想。
**この制約自体が S34d の教材になる。**

### ★ 実環境で判明: この org は OIDC の sub に数値IDが入る

**2026-09-01 に `sumzap/infra-study-app` で実際に検証して判明した。**

公式ドキュメントの書き方は、sub の完全一致で縛るもの。

```
principal://iam.googleapis.com/<プール>/subject/repo:OWNER/REPO:ref:refs/heads/BRANCH
```

ところが実際に発行されたトークンの sub はこうだった。

```
repo:sumzap@45473687/infra-study-app@1351899519:ref:refs/heads/wif-check
          ~~~~~~~~~                ~~~~~~~~~~~
```

**この組織は「OIDC の subject に不変ID を含める」設定が有効**になっている。
組織やリポジトリの名前を変えても同じ主体を指せるようにするための設定で、
セキュリティ的にはこちらのほうが堅牢。

`repository` / `ref` クレームは名前のまま素直に入っていたので、
**プロバイダ側でこの2つを連結したカスタム属性を定義した。**

```
attribute.repo_ref = assertion.repository + "@" + assertion.ref
```

→ `principalSet://<プール>/attribute.repo_ref/sumzap/infra-study-app@refs/heads/<名前>`

**`attribute.repository` だけで絞ってはいけない。**
全員で1つのリポジトリを共有しているため、
それだと他の人のブランチから自分のSAが使えてしまう。

この経緯は **S34e2 として1枚に起こしてある**。
「ドキュメントどおりに書いたのに通らない」「トークンの中身を見れば分かる」
という調べ方の教材として使う。

### ★ 実測: WIF の紐付けは反映に時間がかかる

**同じ設定で、1回目は失敗し、10分後の再実行で成功した。**

```
1回目(紐付け作成の約1分半後)   PERMISSION_DENIED
                              Permission 'iam.serviceAccounts.getAccessToken' denied
2回目(約10分後に Re-run)      成功
```

第7回では既に「IAMの反映に約1分かかる」を扱っているが、
**WIF の紐付けはそれより長い。**

そこで原稿の流れをこう組んである。

```
S34e   apply する(紐付けを作る)
S34e2  sub の話をする          ← ここで時間を稼ぐ
S34f   ワークフローを push する
```

S34e に「すぐには push しないでください」と明記した。
S34i のトラブルシュートでも、**最初に疑うのは反映待ち**としてある。

### 作った勉強会専用のWIFプール

プロジェクトには既に `github-actions` / `github-pool` の2つがあったが、
どちらも `attribute.repo_ref` を持っていなかったため、
**勉強会専用に `infra-study` を作った**(既存プールには手を触れていない)。

```
gcloud iam workload-identity-pools create infra-study --location=global
gcloud iam workload-identity-pools providers create-oidc github \
  --location=global --workload-identity-pool=infra-study \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repo_ref=assertion.repository+'@'+assertion.ref" \
  --attribute-condition="assertion.repository_owner=='sumzap'"
```

### 各回の時間の作り直し

| 回 | 変更前 | 変更後 | どう捻出したか |
|---|---|---|---|
| 第4回 | 120分 | 120分 | Cloud SQL 概説 8→6分、まとめ 10→8分、Spanner 42→41分 |
| 第7回 | 120分 | 120分 | 各セクションを計17分圧縮 + **ビルド待ちに①を挟む** |
| 第8回 | 120分 | 120分 | 各セクションを計14分圧縮 |

**第7回の要点**: GitHub Actions を足すと3回目のビルド待ち(約5分)が増える。
そこに Terragrunt / SOPS を置くことで、待ち時間が説明枠に変わり、
Step4 の実コストが 18分に収まった。第3回で使ったのと同じ手。

### 実物(nishiki)に合わせて書き直した(2026-09-01)

`~/Documents/project/nishiki/nishiki-server` を読んで、
スライドの「一般的な説明」を**実際の構成に差し替えた**。
`制作TODO` は全て解消済み。

| 項目 | nishiki の実際 | 反映先 |
|---|---|---|
| **Terragrunt** | `platform/gcp/{init,common,app}/{env}/{resource}/` + `modules/`。値は `common.yaml → env.yaml → task.yaml` の**3階層**。環境は dev/stg/prd/cer/lod/pmt の**6つ**。**apply/destroy は手元でやらず CI/CD で実行**。tfenv/tgenv でバージョン固定 | 第7回 S34g |
| **SOPS** | **Cloud KMS 鍵**。`.sops.yaml` の `path_regex` で環境ごとに振り分け、**本番と開発で鍵が別**。`secret.enc.yaml` を Git に置く | 第7回 S34h |
| **WIF** | プール `<name>-cicd-pool` / プロバイダ `<name>-cicd-provider`。**`attribute.repository` でリポジトリ単位**(1リポジトリ=1プロダクトなのでブランチまで絞らない)。公式モジュール `terraform-google-modules/github-actions-runners//modules/gh-oidc` を使用 | 第7回 S34d |
| **PSC** | **Memorystore Cluster は PSC のみ**(`google_network_connectivity_service_connection_policy`)。**Cloud SQL は `psc_config` で選択可**。従来の限定公開サービスアクセス(`/22`)も**併存** | 第4回 S20c |
| **Datadog** | **ghost だけでなく nishiki でも使用**。Terraform に DataDog プロバイダを入れ、**監視設定もコードで管理**。外形監視IPをファイアウォールで許可、APIキーは SOPS | 第8回 S12b |
| **Pub/Sub → BigQuery** | アプリの行動ログは `ActionLogger` → **Pub/Sub 経由**。テーブルは日次パーティション + **`require_partition_filter = true`** + `storage_billing_model = "PHYSICAL"`。Cloud Armor のログは GCS へ | 第8回 S38b |
| **負荷試験** | **k6**。PRごとに smoke テストを GitHub Actions で実行。**`lod` という負荷試験専用環境**がある | 第8回 S39d |

### 教材として効いた発見

1. **「新しいサービスほど PSC しか選べない」**
   Memorystore Cluster は PSC 必須。①を知らないと、なぜ③があるのか分からない。
   → 第4回で①をハンズオンする順序が正しかったことの裏付けになった。

2. **WIF の絞り方は事情で変わる**
   nishiki はリポジトリ単位で足りる(1リポジトリ=1プロダクト)。
   勉強会は「全員で1リポジトリ」なのでブランチまで絞る必要がある。
   → **「どこまで絞るかは、共有の仕方で決まる」**という話にできる。

3. **`require_partition_filter = true`**
   「WHERE で日付を指定しないとクエリが通らない」設定。
   **「全期間スキャンで数万円」を仕組みで防いでいる。**
   → 第8回の料金の話(S39c)と直結する実例。

4. **手元で apply しない**
   nishiki の Terragrunt README に
   「apply と destroy は基本的に実行しないでください(CICD で実行)」とある。
   → 第7回でやった「push したら適用される」の延長として説明できる。

### スライドに書かなかったもの(公開リポジトリのため)

実物を読んで分かったが、**リポジトリには書いていない**。

- プロジェクトID(`gcp-nishiki-development` など)
- Cloud KMS の鍵のフルパス
- 組織名
- **社内IPの実値** — `terragrunt/platform/gcp/app/common.yaml` に
  `company_ip_list` / VPN / スマポン / STF などの区分で載っている
  → **10章の保留「社内IP(`company_ip`)の実値」はここから取れる**
  (第3回・第6回の Cloud Armor で使う。当日は伏せ字のまま配布し、
   値は別途共有する運用にすること)
