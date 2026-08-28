# 第3回 インフラ勉強会(GCP) — コンピューティング

- **開催日**: 2026-11-16(月) 2時間
- **AWS版対応**: 第4回(AWS コンピューティング編)
- **Terraformコード**: `gcp/lesson3/`
- **ゴール**: カスタムドメインに HTTPS でアクセスでき、`Hello, Infra Study` が返る

## 時間配分

| セクション | 時間 | スライド |
|---|---|---|
| 導入 | 8分 | S01〜S05 |
| 準備(before モジュール) | 7分 | S06〜S08 |
| Compute Engine(概念 + Step1) | 25分 | S09〜S20 |
| 休憩 | 5分 | S21 |
| ロードバランサ(概念 + Step2) | 30分 | S22〜S34 |
| Cloud DNS(Step3) | 12分 | S35〜S39 |
| マネージドSSL証明書(Step4) | 18分 | S40〜S46 |
| まとめ・宿題 | 10分 | S47〜S56 |

> 押した場合の削り所: S12(Persistent Disk)と S19(MIG概説)は口頭のみで飛ばせる。
>
> **証明書の発行待ちが読めないのが最大のリスク。** S43 で apply したあと
> `ACTIVE` になるまで最大60分かかる。待っている間に S19(MIG)や
> 宿題の説明を前倒しできるよう、順番を入れ替えられる構成にしてある。
>
> **削ってはいけないのは S25〜S27**(GCPのLBが6リソースに分かれている話)と
> **S31〜S32**(ヘルスチェックのFirewall)。この回のハマりどころ。

## 事前準備(講師)

この回は前提条件が多い。**開催の1週間前までに確認すること。**

1. **DNS の委譲が完了していること**(設計書12章。2026-08-28 に完了済み)
   - Cloud DNS に `[勉強会のドメイン]` のマネージドゾーンがある
   - 親ゾーンに NS レコードが登録済み
   - `dig NS [勉強会のドメイン]` で引ける
2. `terraform.tfvars` の `dns_zone_name` が実際のゾーン名と一致していること
3. **コードが GitHub に push 済みであること**
   - `0. before` を `github.com/shiiman/infra-study//gcp/lesson3/0. before` から
     読み込むため、push されていないと `terraform init` が失敗する
4. 受講者が第2回のリソースを destroy 済みであること
   - `0. before` が同名のVPCを作るため、残っていると名前が衝突する

## 原稿の読み方

- **[本文]** — スライドに載せるテキスト
- **[図版]** — 図の作り方。AWS版デッキからの流用指示を含む
- **[話す]** — ナレーション。スライドには載せない

---

# 導入

---

### S01 | タイトル

**[図版]** AWS版 第4回 表紙を複製。タイトルのみ差し替え。

**[本文]**

```
第3回 インフラ勉強会(GCP)

〜 コンピューティング編 〜

2026年11月16日
```

---

### S02 | ロードマップ

**[図版]** 第1回 S02 と同じスライドを複製。今日の行(11月16日)にマーカーを移す。

---

### S03 | 前回の振り返り

**[図版]** AWS版 第4回「前回」2枚を流用。中身を差し替え。

**[本文]**

```
◼前回やったこと

VPCはグローバル、サブネットはリージョン単位
public / private の区別は存在しない
  → 外部IPの有無とCloud NATの有無で決まる
Firewall Rules はVPCに並べ、タグかサービスアカウントで適用先を指定
IAP TCP forwarding で踏み台なしでVMに入った
Private Google Access と Cloud NAT で外に出る経路を2種類作った
```

**[話す]** 今日はこのネットワークの上に、実際に動くWebアプリを載せる。
前回のネットワークはモジュールとして読み込むので、作り直しはしない。

---

### S04 | 今回

**[図版]** AWS版 第4回「ゴール」の「一番簡単なwebアプリケーションを作るぞ〜」の
レイアウトを流用。

**[本文]**

```
一番簡単なWebアプリケーションを作るぞ〜

そして今日は AWSと部品の数が一番違う 回です
```

---

### S05 | ゴール

**[図版]** **新規作成**。AWS版 第4回「ゴール」の構成図をベースにするが、
**ロードバランサの内部構造を描き足す**のがポイント。

- VPCの枠を最外周に(第2回 S05 と同じ描き方)
- LBの箱を「グローバル外部IP → 転送ルール → ターゲットプロキシ → URLマップ →
  バックエンドサービス → インスタンスグループ」の6段に分解して描く
- LBはVPCの**外側**に描く(Googleのフロントエンドなので)
- private サブネットの中に web VM
- 左に Cloud DNS の箱、上にブラウザ

```
 [ブラウザ] ── https://shiiman.[勉強会のドメイン]
     │
 [Cloud DNS] Aレコード
     │
 ┌───────────── Google のフロントエンド ─────────────┐
 │ グローバル外部IP → 転送ルール(443) → HTTPSプロキシ  │
 │                                       │ 証明書      │
 │                                   URLマップ          │
 │                                       │              │
 │                              バックエンドサービス     │
 │                                 ├ ヘルスチェック     │
 └─────────────────────────────┼──────────────┘
 ┌─ VPC ────────────────────────┼──────────────┐
 │  ┌─ asia-northeast1 ──────────┼───────────┐  │
 │  │  private subnet                                  │  │
 │  │    インスタンスグループ ── [web VM] :80          │  │
 │  │  [Cloud Router + Cloud NAT]                      │  │
 │  └────────────────────────────────────┘  │
 └────────────────────────────────────────┘
```

**[本文]**

```
これを理解して作れる！
```

**[話す]** 部品が多く見えるが、上から下へ一直線につながっているだけ。
今日はこれを上から順に作っていく。

---

# 準備

---

### S06 | 準備

**[図版]** AWS版 第4回「準備」を流用。コマンドを差し替え。

**[本文]**

```
◼Cloud Shell を立ち上げる
  プロジェクトが [プロジェクトID] になっているか確認
  gcloud config get-value project

◼作業ディレクトリを作る
  mkdir -p ~/works/lesson3
  cd ~/works/lesson3

◼サンプルコードを更新
  cd ~/infra-study && git pull
  cd ~/works/lesson3

★ 第2回のリソースは destroy しておいてください
   同じ名前のVPCを作るので、残っていると衝突します
```

---

### S07 | 前回の完成状態をモジュールで読み込む

**[図版]** AWS版 第4回「準備」のモジュール呼び出しコードスライドを流用。
コードをGCP版に差し替え。

**[本文]**

```
参照: gcp/lesson3/1. web_instance/before.tf

variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}

module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson3/0. before"

  subnet_public_cidr  = var.subnet_public_cidr
  subnet_private_cidr = var.subnet_private_cidr
  user_name           = var.user_name
}

◼module ブロック(第1回 S46 でやったもの)
複数のリソースをまとめて再利用する仕組み
GitHubのディレクトリを直接 source に指定できる

◼中身は前回作ったもの
VPC / サブネット(public・private) / Cloud Router / Cloud NAT

◼参照の仕方
  module.before.vpc_id
  module.before.vpc_name
  module.before.private_subnet_id
```

**[話す]** モジュール側で `output` を書いておかないと外から参照できない。
`0. before/before.tf` の末尾を見せる。

第4回以降も同じやり方で「前回の完成状態」を引き継いでいく。

---

### S08 | Step0 実行

**[本文]**

```
  terraform init
  terraform plan
  terraform apply

◼確認
  gcloud compute networks list --filter="name:[自分の名前]-vpc"
  gcloud compute networks subnets list --filter="network:[自分の名前]-vpc"
  gcloud compute routers list --filter="name:[自分の名前]"

★ 前回と同じものができていればOK
```

**[話す]** `terraform init` でGitHubからモジュールを取ってくるログが流れる。
モジュールを書き換えたときは `terraform init -upgrade` が必要、という話も添える。

---

# Compute Engine

---

### S09 | Compute Engine とは

**[図版]** AWS版 第4回「EC2」のテキストスライドを流用。用語を差し替え。

**[本文]**

```
◼Compute Engine (GCE)
GCPが提供する仮想マシンサービス

秒単位の従量課金(最低1分)
数十秒で起動する
マシンタイプでCPU・メモリを選ぶ
イメージからOSを選ぶ。カスタムイメージも作れる
ストレージとして Persistent Disk を使う
OS Login でSSHする(鍵の配布が不要)

★ AWSのEC2とほぼ同じ。呼び名が違うだけ
   AMI     → イメージ
   EBS     → Persistent Disk
   Key Pair → OS Login(鍵そのものが不要になる)
```

---

### S10 | マシンタイプ

**[図版]** 新規。マシンファミリーの表。

**[本文]**

```
◼マシンタイプ
「シリーズ + 用途 + vCPU数」の組み合わせで決まる

  e2-micro      汎用・共有CPU     2vCPU(共有) / 1GB   ← 今日使うもの
  e2-medium     汎用              2vCPU / 4GB
  n2-standard-4 汎用・性能重視     4vCPU / 16GB
  c3-highcpu-8  コンピューティング最適化
  m3-ultramem   メモリ最適化

◼AWSとの違い
AWSは t3.micro のように決められた型から選ぶ
GCPは カスタムマシンタイプ でvCPUとメモリを自由に指定できる
  → 「4vCPU / 10GB」のような中途半端な構成が作れる

★ ネットワーク帯域は vCPU数に比例する
   これはAWSと同じ考え方
```

---

### S11 | イメージ

**[本文]**

```
◼イメージ
OSとその初期状態をまとめたもの。AWSのAMIに相当

  debian-cloud/debian-12       Debian 12
  ubuntu-os-cloud/ubuntu-2404-lts
  cos-cloud/cos-stable         Container-Optimized OS

◼イメージファミリー
「debian-12」のようにファミリー名を指定すると、
その時点の最新版が使われる

  image = "debian-cloud/debian-12"
          └ プロジェクト ┘└ ファミリー ┘

★ AWSのAMI IDは ami-02c3627b04781eada のような不透明なID
   しかもリージョンごとに違った
   GCPはファミリー名で書けるし、グローバルに同じ名前が使える
```

**[話す]** AWS版の第3回・第4回では `ami-02c3627b04781eada` を直書きしていた。
あれがリージョンを跨げず、時間が経つと古くなるのが地味に不便だった。
GCPはここが楽。

---

### S12 | Persistent Disk

**[本文]**

```
◼Persistent Disk (PD)
VMにネットワーク経由で接続するブロックストレージ。AWSのEBSに相当

  pd-standard   HDD。安いが遅い
  pd-balanced   SSD。バランス型(既定)
  pd-ssd        SSD。高性能
  hyperdisk-*   さらに高性能・IOPSを個別指定できる

稼働中のままサイズを拡張できる(縮小は不可)
スナップショットが取れる

◼AWSとの違い
EBSは同じAZのEC2にしか付けられなかった
PDはゾーン単位なのは同じだが、
リージョンPD にすると2ゾーンに同期複製できる
```

**[話す]** 押していたら飛ばしてよい。第4回(データベース)で
「ディスクの性能がDBの性能」という話をするときに戻ってくる。

---

### S13 | webインスタンスを作る

**[図版]** AWS版 第4回「EC2」のコードスライドを流用。コードを差し替え。
**`ami` と `key_name` が消えることを強調する**。

**[本文]**

```
参照: gcp/lesson3/1. web_instance/

resource "google_service_account" "web" {
  account_id   = "${var.user_name}-web"
  display_name = "${var.user_name} web instance"
}

resource "google_compute_instance" "web" {
  name         = "${var.user_name}-web"
  machine_type = "e2-micro"
  zone         = "asia-northeast1-a"

  tags = ["${var.user_name}-web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = module.before.private_subnet_id
    // 外部IPなし
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.web.email
    scopes = ["cloud-platform"]
  }
}

★ private サブネットに置き、外部IPを持たせない
   外部からのアクセスはロードバランサ経由にする
```

---

### S14 | Step1 実行

**[本文]**

```
  terraform plan
  terraform apply

◼確認
  gcloud compute instances list --filter="name:[自分の名前]-web"

  NAME         ZONE               INTERNAL_IP  EXTERNAL_IP  STATUS
  shiiman-web  asia-northeast1-a  172.16.10.2               RUNNING

★ EXTERNAL_IP が空
```

---

### S15 | OS Login でVMに入る

**[図版]** AWS版 第4回「SSM セッションマネージャによるアクセス確認」を流用。
中身を IAP + OS Login に差し替え。**比較として1枚残す価値がある**
(AWSはSSM、GCPはIAP+OS Loginという対応関係)。

**[本文]**

```
◼第2回でやった方法でVMに入る

  gcloud compute ssh [自分の名前]-web \
    --zone=asia-northeast1-a --tunnel-through-iap

◼おさらい: 3つのゲート
  Firewall Rule                    35.235.240.0/20 からの tcp:22
  roles/iap.tunnelResourceAccessor トンネルを張る権限
  roles/compute.osAdminLogin       OSにログインする権限
  + roles/iam.serviceAccountUser   VMのSAを使う権限

  → firewall.tf と iap.tf で設定済み

◼AWSでいうと
SSM セッションマネージャーに相当する
  SSHキー不要 / 22番をインターネットに開けない / IAMで制御 / ログが残る
```

**[話す]** AWS版の第4回では、第3回で使った踏み台+SSH鍵をやめて
SSMセッションマネージャーに切り替える、という流れだった。
GCPは第2回の時点で既にIAPを使っているので、同じ方法のまま続けられる。

---

### S16 | アプリを起動する

**[図版]** AWS版 第4回「EC2」のWebアプリ起動コマンドスライドを流用。
コマンドを Debian 用に差し替え(`yum` → `apt-get`)。

**[本文]**

```
◼VMの中で

  sudo su -
  apt-get update
  apt-get install -y docker.io git
  systemctl start docker

  git clone https://github.com/shiiman/infra-study.git
  cd "infra-study/gcp/lesson3/1. web_instance/web_app"

  docker build -t app:0.1 .
  docker images
  docker run -d -p 80:8080 app:0.1
  docker ps

◼動作確認
  curl -X GET "http://localhost"

  Hello, Infra Study
  hostname: [CONTAINER ID]

★ ホストの80番を、コンテナの8080番にマッピングしている
   ロードバランサは80番に繋ぎに来ます
```

**[話す]** `git clone` が通るのは、第2回で作った Cloud NAT があるから。
NATを消してしまった人はここで詰まる。前回の内容がそのまま効いてくる。

このアプリはAWS版で使ったものと同じGoのアプリ。
hostnameを返すので、あとで冗長化したときに振り分けが見える。

---

### S17 | ローカルでは動いた

**[図版]** AWS版 第4回「ELB」の「LocalでWebサーバが構築できました！」を流用。

**[本文]**

```
LocalでWebサーバが構築できました！

でも、外からは見えません

  外部IPを持っていない
  ロードバランサもまだない

インターネットからアクセスできるようにしよう！！
```

---

### S18 | (参考)自動化するなら

**[本文]**

```
◼今は手で入れて docker run している

実務ではこうする

  起動スクリプト(metadata の startup-script)
    VMの初回起動時にrootで実行される
    → 宿題2で使います

  Container-Optimized OS
    コンテナを動かすことに特化したOS

  そもそもVMを使わない → Cloud Run
    → 第5回でやります

★ 第5回まで来ると「この悩み自体が消える」ことが分かります
```

**[話す]** ここで伏線を張っておくと第5回が効く。

---

### S19 | (概説)MIG — マネージドインスタンスグループ

**[本文]**

```
◼MIG (Managed Instance Group)
インスタンステンプレートから、VMを自動で作って維持する仕組み

  台数を指定すれば維持してくれる(壊れたら作り直す)
  オートスケール
  ローリングアップデート
  リージョンMIGなら複数ゾーンへの分散も自動

◼AWSでいうと
Auto Scaling Group + 起動テンプレート

★ 今日は使いません
   1台をロードバランサに繋ぐところに集中します
   宿題2で「手動で2台にする」のをやると、
   MIGが何を自動化してくれるのかが分かります
```

**[話す]** 押していたらここは飛ばして、証明書の待ち時間に回す。

---

### S20 | Step1 完了

**[図版]** AWS版 第4回「EC2」の「Webサーバ インスタンス作成完了！」の構図を流用。
**新規スクリーンショット**。

---

### S21 | 休憩

**[本文]**

```
5分休憩

後半はロードバランサです
今日の山場です
```

---

# ロードバランサ

---

### S22 | Cloud Load Balancing とは

**[図版]** AWS版 第4回「ELB」のテキストスライドを流用。

**[本文]**

```
◼Cloud Load Balancing
GCPのロードバランシングサービス

スケーラブルな負荷分散
高い可用性
グローバルに1つのIPで受けられる

◼AWSのELBとの決定的な違い

AWS  ALBはVPCの中の、指定したサブネットに置かれる
     リージョンをまたぐには別のALBが必要

GCP  グローバル外部LBはVPCの外側、Googleのフロントエンドにいる
     世界中のGoogleのエッジで受けて、最も近いバックエンドへ流す
     IPは1つ(エニーキャスト)

★ だから「LBをどのサブネットに置くか」という設定がない
```

**[話す]** ここがAWS経験者に一番刺さるところ。
ALBは「VPCの中の箱」だったが、GCPのLBは「Googleのネットワークそのもの」。

---

### S23 | ロードバランサの種類

**[本文]**

```
◼GCPのロードバランサは用途で分かれている

グローバル外部アプリケーションLB   HTTP(S)。世界中で1つのIP  ← 今日使う
リージョン外部アプリケーションLB   HTTP(S)。リージョン内
外部パススルーNLB                  TCP/UDP。L4
内部アプリケーションLB             VPC内部向けHTTP(S)
内部パススルーNLB                  VPC内部向けL4

◼AWSでいうと
  ALB → アプリケーションLB
  NLB → パススルーNLB
  CLB → (廃止方向。GCPに相当なし)

★ 今日作るのは「グローバル外部アプリケーションLB」
```

---

### S24 | ゴールの再確認

**[図版]** S05のゴール図を再掲。LBの部分だけハイライト。

**[話す]** これから作る6つの部品が、この図のどこに当たるかを指しながら説明する。

---

### S25 | LBは6つのリソースでできている ★

**[図版]** **新規作成**。この回の最重要図。AWS版との左右比較。

```
   AWS ALB                        GCP グローバル外部アプリケーションLB

   aws_lb                         google_compute_global_address    (IP)
     │                                     │
   aws_lb_listener                google_compute_global_forwarding_rule (入口)
     │                                     │
   aws_lb_target_group            google_compute_target_http_proxy  (プロキシ)
     │                                     │
   aws_lb_target_group_attachment google_compute_url_map            (振り分け)
     │                                     │
   [EC2]                          google_compute_backend_service    (バックエンド定義)
                                    ├ google_compute_health_check
                                    └ google_compute_instance_group
                                            │
                                          [VM]

   3〜4リソース                    6〜7リソース
```

**[本文]**

```
◼なぜこんなに分かれているのか

役割ごとにリソースが独立しているので、使い回せる

  URLマップ         → HTTPとHTTPSで同じものを共有できる(Step4で効いてくる)
  ヘルスチェック     → 複数のバックエンドサービスで共有できる
  グローバルIP       → 80番と443番で同じIPを使う

◼作る順番
上から下へ一直線。参照の向きは 下から上 になる
  転送ルール → プロキシ → URLマップ → バックエンドサービス → インスタンスグループ
```

**[話す]** 最初は多く見えるが、1つ1つの役割は単純。
「AWSでは3つにまとまっていたものが、GCPでは6つに分かれている」だけ。
そして分かれているおかげで、Step4でHTTPS化するときに
URLマップとバックエンドサービスをそのまま使い回せる。

---

### S26 | インスタンスグループ

**[図版]** 新規。バックエンドサービスとVMの間にインスタンスグループが挟まる図。

**[本文]**

```
◼インスタンスグループ
VMをまとめる箱。バックエンドサービスはこれを見る

◼AWSとの違い
AWSのターゲットグループは EC2 を直接アタッチできた
  aws_lb_target_group_attachment で target_id = インスタンスID

GCPのバックエンドサービスは VMを直接持てない
  必ずインスタンスグループ(またはNEG)を挟む

◼2種類ある
  非マネージド(unmanaged)  自分でVMを入れる  ← 今日はこちら
  マネージド(MIG)          自動で作って維持   ← S19で概説したもの

★ ゾーン単位のリソース
   別ゾーンのVMは同じインスタンスグループに入れられない
   → 宿題2でここに当たります
```

---

### S27 | named_port

**[本文]**

```
◼named_port
「このグループの http という名前のポートは 80番」と名前を付ける

  resource "google_compute_instance_group" "web" {
    named_port {
      name = "http"
      port = 80
    }
  }

  resource "google_compute_backend_service" "web" {
    port_name = "http"   ← ポート番号ではなく「名前」で指定する
  }

◼なぜ名前で指定するのか
バックエンドサービスに複数のインスタンスグループがぶら下がったとき、
グループごとにポートが違っても「http」という名前で揃えられる

★ ここを書き忘れるとヘルスチェックが通らない
   port_name と named_port の name が一致しているか必ず確認
```

---

### S28 | ヘルスチェック

**[本文]**

```
◼ヘルスチェック
バックエンドが生きているかを定期的に確認する

  resource "google_compute_health_check" "web" {
    name = "${var.user_name}-web-hc"

    check_interval_sec  = 10   # 10秒ごとにチェック
    timeout_sec         = 5    # 5秒で応答がなければ失敗
    healthy_threshold   = 2    # 2回連続成功でHEALTHY
    unhealthy_threshold = 3    # 3回連続失敗でUNHEALTHY

    http_health_check {
      port         = 80
      request_path = "/"
    }
  }

◼AWSとの違い
AWSではターゲットグループの設定項目だった
GCPは独立したリソース → 複数のバックエンドサービスで使い回せる

★ しきい値はトレードオフ
   短くすると障害検知が速いが、一時的なもたつきで落とされる
   宿題2でVMを止めてみると体感できます
```

---

### S29 | Terraform コード(LB)

**[図版]** AWS版 第4回「ALB」のコードスライドを流用。
**AWS版は1枚に3リソース収まっていたが、GCP版は2枚に分ける。**

**[本文]** (1枚目)

```
参照: gcp/lesson3/2. loadbalancer/lb.tf

resource "google_compute_instance_group" "web" {
  name      = "${var.user_name}-web-ig"
  zone      = "asia-northeast1-a"
  instances = [google_compute_instance.web.id]

  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_health_check" "web" {
  name = "${var.user_name}-web-hc"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

resource "google_compute_backend_service" "web" {
  name          = "${var.user_name}-web-bs"
  protocol      = "HTTP"
  port_name     = "http"
  timeout_sec   = 30
  health_checks = [google_compute_health_check.web.id]

  backend {
    group = google_compute_instance_group.web.id
  }
}
```

---

### S30 | Terraform コード(LB)続き

**[本文]** (2枚目)

```
resource "google_compute_url_map" "web" {
  name            = "${var.user_name}-web-urlmap"
  default_service = google_compute_backend_service.web.id
}

resource "google_compute_target_http_proxy" "web" {
  name    = "${var.user_name}-web-http-proxy"
  url_map = google_compute_url_map.web.id
}

resource "google_compute_global_address" "web" {
  name = "${var.user_name}-web-ip"
}

resource "google_compute_global_forwarding_rule" "web_http" {
  name       = "${var.user_name}-web-http-fr"
  target     = google_compute_target_http_proxy.web.id
  ip_address = google_compute_global_address.web.id
  port_range = "80"
}

★ provider 8.0 から load_balancing_scheme の既定値が
   EXTERNAL_MANAGED になりました
   ネット上の古いサンプルには EXTERNAL と明示してあるものが多いですが、
   今は書かなくてよいです
```

**[話す]** バージョンによって既定値が変わる、というのはよくある話。
ドキュメントを見るときは、自分が使っているバージョンのものを見ること。
レジストリのドキュメントは既定で最新版が表示される。

---

### S31 | Step2 実行 → 繋がらない

**[図版]** ターミナルの出力。**開催前に実物のスクリーンショットを撮ること**。

**[本文]**

```
  terraform plan
  terraform apply

◼LBのIPアドレスを確認
  terraform output lb_ip
  → 34.xx.xx.xx

◼ブラウザでアクセスしてみる
  http://34.xx.xx.xx

  → 502 Server Error

◼バックエンドの状態を見てみる
  gcloud compute backend-services get-health [自分の名前]-web-bs --global

  healthState: UNHEALTHY

★ VMではアプリが動いている(curl localhost で確認済み)
   なのにUNHEALTHY
```

**[話す]** ここで「なぜだと思う?」と受講者に聞く。
第2回をやっていれば答えが出るはず。

---

### S32 | なぜ繋がらないのか ★

**[図版]** **新規作成**。この回の最重要図その2。
LBがVPCの外にいて、Firewall Rulesの壁に阻まれている図。

```
  [Googleのフロントエンド]
    130.211.0.0/22
    35.191.0.0/16
         │
         ✕  ← Firewall Rules (暗黙のingress拒否)
         │
  ┌─ VPC ─────────┐
  │   [web VM] :80  │
  └──────────────┘
```

**[本文]**

```
◼Firewall Rules で許可していない

Googleのロードバランサは、次の2つの固定レンジから来る

  130.211.0.0/22
  35.191.0.0/16

ヘルスチェックも、実際のトラフィックの転送も、両方このレンジから届く

◼第2回でやったこと
カスタムVPCの初期状態は「暗黙のingress拒否」
書いていない通信は全部拒否される

★ AWSでは「LBのSGからwebのSGへ」と書けば済んだ
   GCPのLBはVPCの外側にいるのでSG的な発想が使えない
   → 決められたIPレンジを開ける、という書き方になる

★ GCPのロードバランサで一番よくあるハマりどころ
```

**[話す]** 「LBを作ったのに502が返る」は、9割これ。
覚えて帰ってほしい2つのレンジ。

---

### S33 | Firewall Rule を足す

**[本文]**

```
参照: gcp/lesson3/2. loadbalancer/firewall_lb.tf

resource "google_compute_firewall" "allow_lb_to_web" {
  name    = "${var.user_name}-allow-lb-to-web"
  network = module.before.vpc_name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]
  target_tags = ["${var.user_name}-web"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

  terraform apply

◼バックエンドの状態をもう一度
  gcloud compute backend-services get-health [自分の名前]-web-bs --global

  healthState: HEALTHY

★ ヘルスチェックが通るまで20〜30秒かかります
   (check_interval_sec 10 × healthy_threshold 2)
```

---

### S34 | アクセス確認

**[図版]** AWS版 第4回「アクセス確認」のブラウザ画面を流用。
**新規スクリーンショット**。

**[本文]**

```
◼ブラウザでLBのIPアドレスにアクセス

  http://34.xx.xx.xx

  Hello, Infra Study
  hostname: [CONTAINER ID]

★ インターネットから、外部IPを持たないVMに繋がった

◼AWS版との違い
AWS版ではALBのDNS名(xxx.ap-northeast-1.elb.amazonaws.com)でアクセスした
GCPはIPアドレスが固定で払い出されるので、IPで直接アクセスできる
```

---

# Cloud DNS

---

### S35 | IPではなくドメインでアクセスしたい

**[図版]** AWS版 第4回「Route53」の導入スライドを流用。

**[本文]**

```
LBのIPアドレスではなく
カスタムドメインを使ってアクセスできるようにしよう！！
```

---

### S36 | Cloud DNS とは

**[図版]** AWS版 第4回「Route53」のテキストスライドを流用。用語を差し替え。

**[本文]**

```
◼Cloud DNS
フルマネージドのDNSサービス。AWSのRoute 53に相当

パブリックゾーン / プライベートゾーン
100%のSLA
Googleのエニーキャストネットワークで応答が速い
DNSSEC対応

◼この勉強会で使うゾーン

  [勉強会のドメイン]

  受講者ごとに
  <自分の名前>.[勉強会のドメイン]
```

**[話す]** AWS版では `[AWS版のドメイン]` を使っていた。
GCP版は別ゾーンを切って、Cloud DNS に委譲してある。
AWS版の設定には影響しない。

---

### S37 | ゾーンは Terraform で作らない ★

**[図版]** 新規。警告色。1つのゾーンを全員で共有している図。

**[本文]**

```
★ ゾーンは data で参照するだけ。resource で書かない ★

data "google_dns_managed_zone" "public" {
  name = var.dns_zone_name
}

◼なぜか
全員で1つのプロジェクト・1つのゾーンを共有しています

  resource で書くと → 誰か1人の terraform destroy で
                      全員のドメインが消えます

◼AWS版でも同じでした
  data "aws_route53_zone" "public" { ... }

★ 「共有しているものは data で参照する」
   これは実務でも同じ。本番のVPCやゾーンをうっかり
   自分のstateに取り込まないこと
```

**[話す]** 第1回で話した「共有プロジェクトで権威的リソースを使わない」と同じ発想。
自分が作ったものだけを自分のstateで管理する。

---

### S38 | Terraform コード(DNS)

**[図版]** AWS版 第4回「Route53」のコードスライドを流用。コードを差し替え。

**[本文]**

```
参照: gcp/lesson3/3. dns/dns.tf

variable "dns_zone_name" {}

data "google_dns_managed_zone" "public" {
  name = var.dns_zone_name
}

resource "google_dns_record_set" "web" {
  name         = "${var.user_name}.${data.google_dns_managed_zone.public.dns_name}"
  managed_zone = data.google_dns_managed_zone.public.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.web.address]
}

★ dns_name は末尾にドットが付いた形で返ります
   "[勉強会のドメイン]."
   なので "${var.user_name}." と繋ぐと
   "shiiman.[勉強会のドメイン]." になります

★ AWS版はALBへの alias レコードでした
   GCPはLBが固定IPを持つので、普通のAレコードでよい
```

---

### S39 | Step3 実行 → ドメインでアクセス

**[本文]**

```
  terraform plan
  terraform apply

◼DNSが引けるか確認
  dig +short [自分の名前].[勉強会のドメイン]

  34.xx.xx.xx

◼ブラウザでアクセス
  http://[自分の名前].[勉強会のドメイン]

  Hello, Infra Study
  hostname: [CONTAINER ID]

★ 反映に少し時間がかかることがあります(TTL 300秒)
```

---

# マネージドSSL証明書

---

### S40 | HTTPS にしたい

**[図版]** AWS版 第4回「ACM」の導入スライドを流用。

**[本文]**

```
クライアント - サーバ間の通信を暗号化しよう！！

  第1回 S14 でやったSSL/TLS証明書の話が、
  ここで実物になります
```

---

### S41 | Googleマネージド SSL証明書

**[図版]** AWS版 第4回「ACM」のテキストスライドを流用。

**[本文]**

```
◼Googleマネージド SSL証明書
無料。期限が来ると自動更新される。AWSのACMに相当

◼AWSのACMとの違い

ACM   DNS検証用のCNAMEレコードを自分で作る必要があった
      (AWS版のコードでは for_each で検証レコードを生成していた)

GCP   対象ドメインがこのロードバランサを向いていることを
      Google側が確認して自動で発行する
      → 検証レコードを作る作業がない

◼AWSにあった罠がない
CloudFront用のACMは us-east-1 で作らないといけない、という
リージョン制約がありました。GCPには相当するものがありません

★ そのぶんコードが短くなります
```

**[話す]** AWS版のACMのコードは `domain_validation_options` を
`for_each` で回して検証レコードを作る、という少し複雑なものだった。
GCPはそれが丸ごと要らない。

---

### S42 | 発行には時間がかかる ★

**[図版]** 新規。状態遷移図。

```
  PROVISIONING ──(DNSが正しく引ける)──> ACTIVE
       │
       └──(引けない / 向き先が違う)──> FAILED_NOT_VISIBLE
```

**[本文]**

```
★ 証明書の発行は 数分〜60分 かかります ★

  PROVISIONING          発行処理中
  ACTIVE                発行完了。使える
  FAILED_NOT_VISIBLE    ドメインが引けない・向き先が違う

◼前提条件
Aレコードがこのロードバランサを向いていること
  → だからStep3(DNS)を先にやりました

◼確認コマンド
  gcloud compute ssl-certificates describe [自分の名前]-web-cert --global \
    --format="value(managed.status)"

★ 待っている間に、宿題の説明とMIGの話をします
```

**[話す]** ここが今日の時間管理のポイント。
apply してから ACTIVE になるまで待つので、その間に別の話をする。
最悪、講義中に ACTIVE にならない人がいても、
「あとで見てください」で成立するように宿題の説明を先にしておく。

---

### S43 | Terraform コード(SSL)

**[図版]** AWS版 第4回「ACM」のコードスライドを流用。
**AWS版の検証レコード生成コードが消えることを強調する**。

**[本文]**

```
参照: gcp/lesson3/4. ssl/ssl.tf

resource "google_compute_managed_ssl_certificate" "web" {
  name = "${var.user_name}-web-cert"

  managed {
    domains = ["${var.user_name}.${data.google_dns_managed_zone.public.dns_name}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "web" {
  name             = "${var.user_name}-web-https-proxy"
  url_map          = google_compute_url_map.web.id   ← Step2のものを使い回す
  ssl_certificates = [google_compute_managed_ssl_certificate.web.id]
}

resource "google_compute_global_forwarding_rule" "web_https" {
  name       = "${var.user_name}-web-https-fr"
  target     = google_compute_target_https_proxy.web.id
  ip_address = google_compute_global_address.web.id  ← 同じIPを使う
  port_range = "443"
}

★ URLマップとバックエンドサービスはそのまま使い回せる
   S25で「役割ごとに分かれているから使い回せる」と言ったのがこれ

★ 80番の転送ルールも残したままにします
   同じIPに、ポートごとに転送ルールがぶら下がる形
```

---

### S44 | Step4 実行

**[本文]**

```
  terraform plan
  terraform apply

◼証明書の状態を確認(何度か実行する)
  gcloud compute ssl-certificates describe [自分の名前]-web-cert --global \
    --format="value(managed.status)"

  PROVISIONING
  ...
  ACTIVE

★ ここで待ちが入ります
   その間に宿題の説明をします(S50〜S53へ)
```

---

### S45 | アクセス確認

**[図版]** AWS版 第4回「アクセス確認」のブラウザ画面を流用。
**新規スクリーンショット**。鍵マークが見えるように撮る。

**[本文]**

```
◼ブラウザでHTTPSアクセス

  https://[自分の名前].[勉強会のドメイン]

  Hello, Infra Study
  hostname: [CONTAINER ID]

★ アドレスバーに鍵マークが出ていればOK

◼証明書の中身を見てみる
  ブラウザの鍵マークをクリック → 証明書
  発行元: Google Trust Services
  対象:   [自分の名前].[勉強会のドメイン]
```

---

### S46 | 今日のゴール達成

**[図版]** S05のゴール図を再掲し、全要素にチェックマークを付ける。

**[本文]**

```
◼できたこと

前回のネットワークをモジュールとして読み込んだ
private サブネットにVMを作り、コンテナでアプリを動かした
ロードバランサを6つの部品で組み立てた
ヘルスチェック用のFirewall Ruleを開けた
Cloud DNS でドメインを割り当てた
マネージドSSL証明書でHTTPS化した

★ 外部IPを1つも持たないVMが、
   HTTPSでインターネットに公開されている状態
```

---

# まとめ

---

### S47 | 本日のまとめ ①

**[図版]** AWS版 第4回「本日のまとめ」のレイアウトを流用。

**[本文]**

```
◼Compute Engine
マシンタイプでCPU・メモリを選ぶ。カスタムも作れる
イメージはファミリー名で指定できる(AMI IDのような不透明なIDではない)
ストレージは Persistent Disk
MIGを使えば自動で台数を維持できる(今回は非マネージドを使用)

◼ロードバランサ
グローバル外部LBはVPCの外側、Googleのフロントエンドにいる
6つのリソースを上から下へ繋いで作る
  グローバルIP → 転送ルール → プロキシ → URLマップ
  → バックエンドサービス → インスタンスグループ
バックエンドサービスはVMを直接持てない。インスタンスグループを挟む
ヘルスチェックは独立リソース
```

---

### S48 | 本日のまとめ ②

**[本文]**

```
◼今日一番のハマりどころ

  130.211.0.0/22
  35.191.0.0/16

  この2つのレンジからの通信を Firewall Rules で許可しないと
  ヘルスチェックが通らず、502が返り続ける

◼Cloud DNS
共有しているゾーンは data で参照する。resource で書かない

◼マネージドSSL証明書
無料・自動更新
DNS検証レコードを自分で作る必要がない(ACMとの違い)
発行に数分〜60分かかる
Aレコードが先にできている必要がある
```

---

### S49 | 本日はここまで

**[図版]** AWS版の同スライドを流用。

---

### S50 | 宿題1 アンケート

**[図版]** AWS版 第4回「宿題1」を流用。URLを差し替え。

**[本文]**

```
◼アンケートのお願い

1分で終わりますのでぜひフィードバックお願い致します！！
次回開催のモチベになります！！！

https://forms.gle/xxxxxxxx
```

> **制作TODO**: Google Form を新規作成してURLを差し込む。

---

### S51 | 宿題2 実装課題 ①②

**[図版]** AWS版 第4回「宿題2」のレイアウトを流用。中身を差し替え。

**[本文]**

```
◼1. VMを再起動してもアプリが自動で立ち上がるようにしよう

  今のままだとVMを再起動するとアプリが止まります
  Dockerデーモンの自動起動 + コンテナの再起動ポリシー

  回答例: gcp/lesson3/syukudai1/


◼2. webインスタンスを別ゾーンにも置いて冗長化しよう

  asia-northeast1-b に2台目を作る
  インスタンスグループはゾーン単位なので、
  バックエンドサービスに backend を2つぶら下げる形になります

  ・サブネットは増やさなくてよい(リージョン単位だから)
  ・起動スクリプトでセットアップを自動化してみましょう
  ・1台止めてもアクセスが続くことを確認してください

  回答例: gcp/lesson3/syukudai2/
```

**[話す]** 2つ目は「AWSではAZごとにサブネットが必要だった」という
第2回の話が効いてくる課題。GCPではサブネットを増やさなくていい。

---

### S52 | 宿題2 実装課題 ③

**[本文]**

```
◼3. Cloud Armor で社内IP制限をかけよう

  Cloud Armor は AWS の WAF に相当します
  ロードバランサの手前で、社内IP以外を弾く

  ・セキュリティポリシーを作る
  ・社内IPを許可するルール(priority 1000)
  ・それ以外を拒否するデフォルトルール(priority 2147483647)
  ・バックエンドサービスに紐づける

  社外(スマホのテザリングなど)から403が返ることを確認してください

  回答例: gcp/lesson3/syukudai3/

★ ヘルスチェックはCloud Armorの影響を受けません
   社内IP以外を全部拒否してもバックエンドはHEALTHYのままです
```

**[話す]** 第2回でやった Firewall Rules との違いを意識してほしい。
Firewall RulesはVPCの中、Cloud ArmorはVPCの外。守る層が違う。

---

### S53 | 宿題3 ドキュメント

**[図版]** AWS版 第4回「宿題3」を流用。リンクを差し替え。

**[本文]**

```
◼Compute Engine のドキュメントを眺めてみよう
  https://cloud.google.com/compute/docs
  マシンタイプ / イメージ / Persistent Disk

◼Cloud Load Balancing のドキュメントを眺めてみよう
  https://cloud.google.com/load-balancing/docs
  外部アプリケーション ロードバランサの概要
  ヘルスチェックの概要

◼Terraform google provider の各ドキュメントを眺めてみよう
  google_compute_instance
  google_compute_instance_group
  google_compute_health_check
  google_compute_backend_service
  google_compute_url_map
  google_compute_target_http_proxy / target_https_proxy
  google_compute_global_address / global_forwarding_rule
  google_compute_managed_ssl_certificate
  google_dns_record_set
  google_compute_security_policy
```

---

### S54 | 参考

**[本文]**

```
Compute Engine ドキュメント
  https://cloud.google.com/compute/docs

外部アプリケーション ロードバランサの概要
  https://cloud.google.com/load-balancing/docs/https

ヘルスチェックの概要(IPレンジの根拠)
  https://cloud.google.com/load-balancing/docs/health-check-concepts

Google マネージド SSL証明書
  https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs

Cloud DNS ドキュメント
  https://cloud.google.com/dns/docs

Google Cloud Armor
  https://cloud.google.com/armor/docs/cloud-armor-overview
```

---

### S55 | 注意事項

**[図版]** AWS版「注意事項」スライドを流用。

**[本文]**

```
宿題などで作成したリソースは
必ず削除してください！

  terraform destroy

★ この回は課金されるものが多いです
   Compute Engine   起動している間ずっと
   ロードバランサ    転送ルールがある間ずっと
   グローバル外部IP  使っていなくても課金される
   Cloud NAT        起動している間ずっと

★ 全員で1つのプロジェクトを共有しています
   消し忘れはQuotaを圧迫して、他の人のapplyが止まります

★ tfstate用のバケットは残しておいてください

★ DNSレコードも消えます(ゾーン自体は残ります)
```

---

### S56 | おしまい

**[図版]** AWS版「おしまい」スライドを流用。

**[本文]**

```
次回は データベース編 です

Cloud SQL / Memorystore
今日作ったアプリからDBに繋ぎます

お楽しみに！！
```

---

# 付録A: ハンズオンのステップ対応表

| Step | ディレクトリ | 作るもの | 確認すること |
|---|---|---|---|
| 0 | `0. before/` | 第2回のネットワーク一式(モジュール) | 前回と同じものができる |
| 1 | `1. web_instance/` | web VM + IAP用Firewall/IAM | IAPで入って `curl localhost` が通る。外からは見えない |
| 2 | `2. loadbalancer/` | LB 6リソース + ヘルスチェック用Firewall | **502 → Firewall追加 → LBのIPでアクセスできる** |
| 3 | `3. dns/` | Aレコード | ドメインでアクセスできる |
| 4 | `4. ssl/` | マネージド証明書 + HTTPSプロキシ + 443転送ルール | HTTPSでアクセスできる |

AWS版 第4回との対応:

| AWS版 | GCP版 | 備考 |
|---|---|---|
| 0. before | 0. before | 中身がVPC/サブネット/NATなのは同じ |
| 1. web_instance | 1. web_instance | AWSはSSM、GCPはIAP+OS Login |
| 2. loadbalancer | 2. loadbalancer | **3リソース → 6リソース**。ヘルスチェックFirewallが増える |
| 3. dns | 3. dns | alias → Aレコード |
| 4. acm | 4. ssl | 検証レコードの生成が不要になる |

---

# 付録B: 制作メモ / 要確認事項

## 実環境での動作確認: **未実施**

第1回・第2回と違い、**この回はまだ実環境で apply していない**。
`terraform validate` は全8ディレクトリで成功済み(google provider 8.0.0)。

apply の前提として次が必要:

1. DNS の委譲完了(設計書12章の保留中タスク)
2. コードを GitHub に push(`0. before` をモジュール参照するため)

### 確認すべきこと(apply できるようになったら)

| 項目 | 内容 |
|---|---|
| モジュール参照 | `github.com/shiiman/infra-study//gcp/lesson3/0. before` で init が通るか |
| ヘルスチェック | Firewall追加前にUNHEALTHY / 502 になることを実測(S31) |
| ヘルスチェック | Firewall追加後にHEALTHYになるまでの実測時間(S33で「20〜30秒」と書いている) |
| 証明書 | PROVISIONING → ACTIVE の実測時間(S42で「数分〜60分」と書いている) |
| 起動スクリプト | 宿題2の `startup-script` が完走するか。所要時間 |
| Cloud Armor | 宿題3のポリシー反映にかかる時間。社外からの403を実測 |
| destroy | LBの依存関係の削除順序でエラーが出ないか |

## 新規作図が必要なスライド

| スライド | 内容 | 優先度 |
|---|---|---|
| S25 | AWS ALB と GCP LB のリソース比較 | **最高** |
| S32 | LBがVPCの外にいてFirewallに阻まれる図 | **最高** |
| S05 | ゴール構成図(LBの内部構造を6段に分解) | 高 |
| S42 | 証明書の状態遷移 | 中 |
| S26 | インスタンスグループが挟まる図 | 中 |
| S37 | ゾーンを共有している図(警告) | 中 |
| S10 | マシンタイプの表 | 低 |

## 開催前に撮るスクリーンショット

- S20: インスタンス一覧画面
- S31: 502エラー画面 + `get-health` の UNHEALTHY 出力
- S34: LBのIPでのブラウザ表示
- S45: HTTPSでのブラウザ表示(鍵マークが見えるように)

## 時間管理のリスク

**証明書の発行待ちが読めない。** S42〜S45 で待ちが発生する。

対策として原稿の順序を組み替え可能にしてある:

1. S44 で apply したら、S50〜S53(宿題の説明)を先にやる
2. それでも足りなければ S19(MIG)の話を挟む
3. 講義中に ACTIVE にならない人がいても成立するよう、
   S45 の確認は「あとで各自で」に逃がせる構成にしている

## 設計書からの変更点

設計書 6章の第3回アジェンダにある「OS Login」は、第2回で既に扱っているため
S15 でおさらいとして触れるだけにした。そのぶんロードバランサに時間を回している。
