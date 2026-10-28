# 第3回 インフラ勉強会(GCP) — コンピューティング

- **開催日**: 2026-11-16(月) 14-16時
- **AWS版対応**: 第4回(AWS コンピューティング編)
- **Terraformコード**: `gcp/lesson3/`
- **正本**: [レビュー済みGoogleスライド](https://docs.google.com/presentation/d/1cxkYA6EAxoyUp-iMQILfCvJ_CjR8SuccNb7cRbhMc0s/edit)
- **同期日**: 2026-10-28（全57ページ）
- **ゴール**: カスタムドメインにHTTPSでアクセスし、`Hello, Infra Study` を確認する

## ページ構成

| セクション | ページ |
|---|---|
| 導入 | S01〜S05 |
| 準備・Step0 | S06〜S08 |
| Compute Engine・Step1 | S09〜S19 |
| ロードバランサ・Step2 | S20〜S34 |
| Cloud DNS・Step3 | S35〜S39 |
| SSL証明書・Step4 | S40〜S46 |
| まとめ・宿題・注意事項 | S47〜S57 |

証明書の状態確認はS45のapply後に行う。発行待ちの間にS51〜S54の宿題を説明する。

## 事前準備(講師)

この回は前提条件が多い。**開催の1週間前までに確認すること。**

1. **DNS の委譲が完了していること**(設計書12章。2026-08-28 に完了済み)
   - Cloud DNS に `infra-study-gcp.sumsp.jp` のマネージドゾーンがある
   - 親ゾーンに NS レコードが登録済み
   - `dig NS infra-study-gcp.sumsp.jp` で引ける
2. `terraform.tfvars` の `dns_zone_name` が実際のゾーン名と一致していること
3. **コードが GitHub に push 済みであること**
   - Cloud Shellで `git pull` し、コピー元の教材を最新にする
4. 受講者が第2回のリソースを destroy 済みであること
   - `0. before` が同名のVPCを作るため、残っていると名前が衝突する
5. **vCPU クォータに余裕があること**
   - この回は**1人あたり e2-medium を2台**(zone a と b)作る。
     全10回で1人あたりのVM台数が最大になるのがこの回
   - 人数分が同時に存在するので、`asia-northeast1` の vCPU 枠(`CPUS`)を食い切ると
     **後から apply した人だけが失敗する**。原因が分かりにくい事故になる

   > **2026-10-01 時点の状況**: 増枠(64 → 200)は**却下された**ので、上限は **64 のまま**。
   > **ただし実測で、共有コアの VM は 1台 = 1 vCPU と数えられると分かった。**
   > 16人 × 2台 = **32 vCPU** なので、**余裕は32ある**。増枠は要らない。
   > 足りなくなるのは、**前回までの残骸が残っているとき**(第10回に第8回の残骸、など)だけ。
   - 確認(`CPUS` の usage が 64 に近くないこと。停止中のVMは数えられない):
     ```
     gcloud compute regions describe asia-northeast1 --project=[プロジェクトID] \
       --format="value(quotas)" | tr ';' '\n' | grep -A2 CPUS
     ```
   - 詳細は `gcp/docs/quota-precheck-2026-09.md`

## 原稿の読み方

- S番号は現在のスライドのページ番号と一致する。
- **[本文]** はスライドの表示テキスト。図は各ラベルを記載し、配置は正本リンクで確認する。
- コードは講義用の抜粋を含む。実行用ファイルは `gcp/lesson3/` を使用する。
- `terraform plan, terraform apply` は順番に実行する2コマンドの表記。
- 社内IP・社内GCPプロジェクトIDなど社内限定の情報は、公開原稿・配布コードには転記しない。限定公開のスライドを参照し、コピー先の作業ディレクトリで設定する。
- 各ページのリンク先も記録する。過去の検証記録は付録Bに残すが、現在の実行手順は本文を正とする。

### S01 | 第3回 インフラ勉強会(GCP)

<!-- slide-id: g000slide -->

**[本文]**

```text
第3回 インフラ勉強会(GCP)

〜 コンピューティング編 〜

2026年11月16日(月) 14-16時
```

---

### S02 | インフラ勉強会 スケジュール

<!-- slide-id: g001slide -->

**[本文]**

```text
◼ロードマップ(内容は随時変更される可能性あり)

2026年
10月05日(月) 14-16時  GCP基礎 / IAM / Terraform
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

---

### S03 | 前回の振り返り

<!-- slide-id: g002slide -->

**[本文]**

```text
◼前回やったこと

VPCはグローバル、サブネットはリージョン単位
public / private の区別は存在しない
  → 外部IPの有無とCloud NATの有無で決まる
Firewall Rules はVPCに並べ、タグかサービスアカウントで適用先を指定
IAP TCP forwarding で踏み台なしでVMに入った
Private Google Access と Cloud NAT で外に出る経路を2種類作った
```

---

### S04 | 今日のアジェンダ

<!-- slide-id: g003slide -->

**[本文]**

```text
Compute Engine / イメージ / Persistent Disk

VMでWebアプリケーションを動かす

Cloud Load Balancing / ヘルスチェック

Cloud DNS

Googleマネージド SSL証明書

ハンズオン：VM → HTTP → ドメイン → HTTPS
```

---

### S05 | ゴール

<!-- slide-id: g004slide -->

**[本文]**

```text
独自ドメインの HTTPS で、外部IPを持たない Web VM にアクセスする

Cloud DNS

① 名前解決
Aレコード → LBの外部IP

ブラウザ

https://[自分の名前].
infra-study-gcp.sumsp.jp

Google フロントエンド（VPCの外）

Cloud Load Balancing
グローバル外部 ALB

外部IP ＋ 転送ルール :443

HTTPS プロキシ ＋ SSL証明書

URLマップ

バックエンドサービス

ヘルスチェックで VM の状態を確認

② HTTPS
443

VPC ネットワーク

private subnet
asia-northeast1

インスタンスグループ

Compute Engine
web VM :80
外部IPなし

③ HTTP
80

Cloud NAT
Cloud Router で構成

外向き通信
インターネットへ

ゴール：ブラウザに Web ページが表示される
```

---

### S06 | ハンズオンの準備

<!-- slide-id: g005slide -->

**[本文]**

```text
◼Cloud Shell を立ち上げる
  プロジェクトが [プロジェクトID] になっていることを確認
  gcloud config get-value project
  (違うなら) gcloud config set project [プロジェクトID]

◼作業ディレクトリを作る
  mkdir -p ~/works/lesson3

◼サンプルコードを更新
  cd ~/infra-study && git pull

※ 第2回のリソースは destroy しておいてください
   同じ名前のVPCを作るので、残っていると衝突します
```

---

### S07 | コピー後に個人設定を反映する

<!-- slide-id: personal_settings_slide -->

**[本文]**

```text
第3回からは、コピー後の個人設定だけを補助します。
(common.tfとterraform.tfvarsの修正)

python3 ~/infra-study/gcp/tools/configure.py

初回：project ID・user name・作成済みtfstateバケット名を入力
次回：保存した3項目を反映（変更する場合は --edit）
保存先：~/.config/infra-study/profile.json（Git管理外）

common.tf のbackend bucketと、terraform.tfvars のproject_id・user_name だけを反映します。
```

---

### S08 | Step0 実行

<!-- slide-id: g006slide -->

**[本文]**

```text
cd ~/works/lesson3 && cp -rf ~/infra-study/gcp/lesson3/"0. before" ./
cd "0. before"
python3 ~/infra-study/gcp/tools/configure.py

0. before は、前回のネットワークの完成コードです。
VPC / public・private subnet / Cloud Router / Cloud NAT

terraform init
terraform plan, terraform apply


◼確認
gcloud compute networks list --filter="name:[自分の名前]-vpc"
gcloud compute networks subnets list --filter="network:[自分の名前]-vpc"
gcloud compute routers list --filter="name:[自分の名前]"
```

---

### S09 | Compute Engine

<!-- slide-id: audit_section_3_0 -->

**[本文]**

```text

```

---

### S10 | Compute Engine とは

<!-- slide-id: g008slide -->

**[本文]**

```text
◼Compute Engine (GCE)
  GCPが提供する仮想マシンサービス

秒単位の従量課金(最低1分)
数十秒で起動する
マシンタイプでCPU・メモリを選ぶ
イメージからOSを選ぶ。カスタムイメージも作れる
ストレージとして Persistent Disk を使う
OS Login でSSHする(鍵の配布が不要)
```

---

### S11 | マシンタイプ

<!-- slide-id: g009slide -->

**[本文]**

```text
◼マシンタイプ
「シリーズ + 用途 + vCPU数」の組み合わせで決まる

  e2-micro      汎用・共有CPU           2vCPU(共有) / 1GB
  e2-medium     汎用                   2vCPU / 4GB
  n2-standard-4 汎用・性能重視           4vCPU / 16GB
  c3-highcpu-8  コンピューティング最適化
  m3-ultramem   メモリ最適化

◼AWSとの違い
AWSは t3.micro のように決められた型から選ぶ
GCPは カスタムマシンタイプ でvCPUとメモリを自由に指定できる
  → 「4vCPU / 10GB」のような中途半端な構成が作れる

※ ネットワーク帯域は vCPU数に比例する
   これはAWSと同じ考え方
```

---

### S12 | イメージ

<!-- slide-id: g010slide -->

**[本文]**

```text
◼イメージ
  OSとその初期状態をまとめたもの。AWSのAMIに相当

  debian-cloud/debian-12
  ubuntu-os-cloud/ubuntu-2404-lts
  cos-cloud/cos-stable

◼イメージファミリー
「debian-12」のようにファミリー名を指定すると、その時点の最新版が使われる

  image = "debian-cloud/debian-12"
          └ プロジェクト ┘└ ファミリー ┘
```

---

### S13 | Persistent Disk

<!-- slide-id: g011slide -->

**[本文]**

```text
◼Persistent Disk (PD)
VMにネットワーク経由で接続するブロックストレージ。AWSのEBSに相当

  pd-standard   HDD。安いが遅い
  pd-balanced   SSD。バランス型(既定)
  pd-ssd        SSD。高性能
  hyperdisk-*   さらに高性能・IOPSを個別指定できる

稼働中のままサイズを拡張できる(縮小は不可)
スナップショットが取れる
```

---

### S14 | webインスタンスを作る（1/2）

<!-- slide-id: g012slide -->

**[本文]**

```text
cd ~/works/lesson3 && cp -rf ~/infra-study/gcp/lesson3/"1. web_instance" ./
cd "1. web_instance"
python3 ~/infra-study/gcp/tools/configure.py

resource "google_service_account" "web" {
  account_id   = "${var.user_name}-web"
  display_name = "${var.user_name} web instance"
}

resource "google_compute_instance" "web" {
  name         = "${var.user_name}-web"
  machine_type = "e2-medium"
  zone         = "asia-northeast1-a"

  tags = ["${var.user_name}-web"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

~~~~~

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
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
```

---

### S15 | Step1 実行

<!-- slide-id: g013slide -->

**[本文]**

```text
terraform init
  terraform plan, terraform apply

◼確認(主な項目のみ抜粋)
  gcloud compute instances list --filter="name:[自分の名前]-web"
  NAME: yamada-taro-web
  ZONE: asia-northeast1-a
  INTERNAL_IP: 172.16.10.2
  EXTERNAL_IP:
  STATUS: RUNNING
```

---

### S16 | OS Login でVMに入る

<!-- slide-id: g014slide -->

**[本文]**

```text
◼第2回でやった方法でVMに入る

  gcloud compute ssh [自分の名前]-web --zone=asia-northeast1-a --tunnel-through-iap


◼おさらい: 3つのゲート
  Firewall Rule                      35.235.240.0/20 からの tcp:22
  roles/iap.tunnelResourceAccessor   トンネルを張る権限
  roles/compute.osAdminLogin         OSにログインする権限
    + roles/iam.serviceAccountUser   VMのSAを使う権限

  → firewall.tf と iap.tf で設定済み
```

---

### S17 | アプリを起動する

<!-- slide-id: g015slide -->

**[本文]**

```text
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
```

---

### S18 | ローカルでは動いた

<!-- slide-id: g016slide -->

**[本文]**

```text
LocalでWebサーバが構築できました！

でも、外からは見えません

  外部IPを持っていない
  ロードバランサもまだない





インターネットからアクセスできるようにしよう！！
```

---

### S19 | （参考）自動化するなら

<!-- slide-id: g017slide -->

**[本文]**

```text
◼今は手で入れて docker run している
実務ではこうする
  起動スクリプト(metadata の startup-script)
    VMの初回起動時にrootで実行される → 宿題2で使います

  Container-Optimized OS
    コンテナを動かすことに特化したOS

  MIG (Managed Instance Group)
    インスタンステンプレートから、VMを自動で作って維持する仕組み



  そもそもVMを使わない → Cloud Run → 第5回でやります
```

---

### S20 | Cloud Load Balancing

<!-- slide-id: audit_section_3_1 -->

**[本文]**

```text

```

---

### S21 | Cloud Load Balancing とは

<!-- slide-id: g021slide -->

**[本文]**

```text
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
```

---

### S22 | ゴールの再確認

<!-- slide-id: h54e78a0d7390a0a0_16_3 -->

**[本文]**

```text
独自ドメインの HTTPS で、外部IPを持たない Web VM にアクセスする

Cloud DNS

① 名前解決
Aレコード → LBの外部IP

ブラウザ

https://[自分の名前].
infra-study-gcp.sumsp.jp

Google フロントエンド（VPCの外）

Cloud Load Balancing
グローバル外部 ALB

外部IP ＋ 転送ルール :443

HTTPS プロキシ ＋ SSL証明書

URLマップ

バックエンドサービス

ヘルスチェックで VM の状態を確認

② HTTPS
443

VPC ネットワーク

private subnet
asia-northeast1

インスタンスグループ

Compute Engine
web VM :80
外部IPなし

③ HTTP
80

Cloud NAT
Cloud Router で構成

外向き通信
インターネットへ

ゴール：ブラウザに Web ページが表示される
```

---

### S23 | ゴールのLBをTerraformリソースに分解する

<!-- slide-id: g024slide -->

**[本文]**

```text
AWS ALB

GCP：22ページのHTTPS構成

aws_lb

aws_lb_listener
HTTPS :443 ＋ 証明書

aws_lb_target_group
ヘルスチェックを設定

aws_lb_target_group_attachment

EC2（アプリ :80）

外部IP
google_compute_global_address

Google フロントエンド（VPCの外）

転送ルール :443
google_compute_global_forwarding_rule

HTTPS プロキシ
google_compute_target_https_proxy

URLマップ
google_compute_url_map

バックエンドサービス
google_compute_backend_service

インスタンスグループ
google_compute_instance_group

VPC / private subnet
HTTP :80 で VM へ

Compute Engine / web VM :80
外部IPなし

SSL証明書
google_compute_managed_ssl_certificate

ヘルスチェック
google_compute_health_check
```

---

### S24 | インスタンスグループ

<!-- slide-id: g025slide -->

**[本文]**

```text
◼インスタンスグループ
  VMをまとめる箱。バックエンドサービスはこれを見る

◼AWSとの違い
  AWSのターゲットグループは EC2 を直接アタッチできた
  GCPのバックエンドサービスは VMを直接持てない → 必ずインスタンスグループ(またはNEG)を挟む

◼2種類ある
  非マネージド(unmanaged)  自分でVMを入れる
  マネージド(MIG)          自動で作って維持

※ ゾーン単位のリソース
   別ゾーンのVMは同じインスタンスグループに入れられない → 宿題2でここに当たります
```

---

### S25 | named_port

<!-- slide-id: g026slide -->

**[本文]**

```text
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
バックエンドサービスに複数のインスタンスグループがぶら下がったとき、グループごとにポートが違っても「http」という名前で揃えられる
```

---

### S26 | ヘルスチェック

<!-- slide-id: g027slide -->

**[本文]**

```text
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
```

---

### S27 | Terraform コード（LB）（1/3）

<!-- slide-id: g028slide -->

**[本文]**

```text
cd ~/works/lesson3 && cp -rf ~/infra-study/gcp/lesson3/"2. loadbalancer" ./
cd "2. loadbalancer"
python3 ~/infra-study/gcp/tools/configure.py


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
```

---

### S28 | Terraform コード（LB）（2/3）

<!-- slide-id: g028bslide -->

**[本文]**

```text
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

### S29 | Terraform コード（LB）（3/3）

<!-- slide-id: g029slide -->

**[本文]**

```text
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
```

---

### S30 | Step2 実行 → 繋がらない

<!-- slide-id: g030slide -->

**[本文]**

```text
terraform init
  terraform plan, terraform apply

◼LBの外部IPを確認（環境ごとに異なる）
  terraform output -raw lb_ip   → [LBの外部IP]

◼ブラウザでアクセスしてみる
  http://[LBの外部IP]   → no healthy upstream

※ 画面の表示は no healthy upstream（正常な転送先がない）、HTTPステータスは503
   apply直後は接続タイムアウトになる場合があります。設定の反映まで1〜2分待ちます。

◼バックエンドの状態を見てみる
  gcloud compute backend-services get-health [自分の名前]-web-bs --global

  healthState: UNHEALTHY
```

---

### S31 | なぜ繋がらないのか

<!-- slide-id: g031slide -->

**[本文]**

```text
Google側（VPCの外）
LB・ヘルスチェック

VMから見た送信元IP
130.211.0.0/22
35.191.0.0/16

Firewall
許可なし
TCP :80
拒否

×

VPC / private subnet

web VM :80
外部IPなし

受信拒否 → ヘルスチェック失敗（UNHEALTHY）→ LB が 503 を返す

次ページで追加：Google側から web VM への TCP :80 を許可
送信元：上の2つのIPレンジ　／　対象タグ：[自分の名前]-web

LBには届いているが、LBからVMへの通信がFirewallで止まっている

ブラウザ

HTTP :80

未到達

← 503
```

---

### S32 | Firewall Rule を足す（1/2）

<!-- slide-id: g032slide -->

**[本文]**

```text
mv firewall_lb.tf.example firewall_lb.tf

resource "google_compute_firewall" "allow_lb_to_web" {
  name    = "${var.user_name}-allow-lb-to-web"
  network = google_compute_network.vpc.name

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
```

---

### S33 | Firewall Rule を足す（2/2）

<!-- slide-id: p2_3_g032bdy_1 -->

**[本文]**

```text
terraform plan, terraform apply

◼バックエンドの状態をもう一度
  gcloud compute backend-services get-health [自分の名前]-web-bs --global

  healthState: HEALTHY

※ ヘルスチェックが通るまで30〜40秒かかります
   (check_interval_sec 10 × healthy_threshold 2 + Firewallの反映)
```

---

### S34 | アクセス確認

<!-- slide-id: g033slide -->

**[本文]**

```text
◼ブラウザで、30ページで確認したLBの外部IPにアクセス

  http://[LBの外部IP]

  Hello, Infra Study
  hostname: [CONTAINER ID]


◼AWSのALBとの違い
  AWSのALBはDNS名(xxx.ap-northeast-1.elb.amazonaws.com)でアクセスする
  GCPはIPアドレスが固定で払い出されるので、IPで直接アクセスできる



 LBのIPアドレスではなくカスタムドメインを使ってアクセスできるようにしよう！！
```

---

### S35 | Cloud DNS

<!-- slide-id: audit_section_3_2 -->

**[本文]**

```text

```

---

### S36 | Cloud DNS とは

<!-- slide-id: g035slide -->

**[本文]**

```text
◼Cloud DNS：ドメイン名とIPアドレスの対応を管理するサービス
  DNSサーバーの運用はGoogleが担当。AWSのRoute 53に相当

◼ゾーン：あるドメインのDNSレコードをまとめて管理する単位
パブリック：インターネットから名前を調べられる
プライベート：指定したVPC内向けに名前を公開する

◼その他の特徴
SLA：DNS応答の月間稼働率100%が目標。未達時は条件付きで料金補填
エニーキャスト：世界各地のDNSサーバーへ経路に応じて振り分ける
                 問い合わせの遅延を抑え、障害にも備える
DNSSEC：電子署名でDNS応答の改ざん・偽装を検出する

◼今回使うパブリックゾーン
  ドメイン：infra-study-gcp.sumsp.jp
  ゾーン名：infra-study-gcp（Terraformの dns_zone_name に指定）
  各自の名前：[自分の名前].infra-study-gcp.sumsp.jp
```

---

### S37 | ゾーンは Terraform で作らない

<!-- slide-id: g036slide -->

**[本文]**

```text
※ ゾーンは既にこちらで作成してるので、 data で参照する

data "google_dns_managed_zone" "public" {
  name = var.dns_zone_name
}

◼なぜか
全員で1つのプロジェクト・1つのゾーンを共有しています

  resource で書くと → 誰か1人の terraform destroy で全員のドメインが消えます
```

---

### S38 | Terraform コード（DNS）

<!-- slide-id: g037slide -->

**[本文]**

```text
cd ~/works/lesson3 && cp -rf ~/infra-study/gcp/lesson3/"3. dns" ./
cd "3. dns"
python3 ~/infra-study/gcp/tools/configure.py


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

※ AWSではALBへの alias レコードを使います
   GCPはLBが固定IPを持つので、普通のAレコードでよい
```

---

### S39 | Step3 実行 → ドメインでアクセス

<!-- slide-id: g038slide -->

**[本文]**

```text
terraform init
  terraform plan, terraform apply

◼DNSが引けるか確認
  dig +short [自分の名前].infra-study-gcp.sumsp.jp

  [LBの外部IPと一致することを確認]

◼ブラウザでアクセス
  http://[自分の名前].infra-study-gcp.sumsp.jp

  Hello, Infra Study
  hostname: [CONTAINER ID]

※ 反映に少し時間がかかることがあります(TTL 300秒)

通信を暗号化したい = HTTPS化
```

---

### S40 | SSL証明書

<!-- slide-id: audit_section_3_3 -->

**[本文]**

```text

```

---

### S41 | Googleマネージド SSL証明書

<!-- slide-id: g040slide -->

**[本文]**

```text
◼Googleマネージド SSL証明書
  無料。期限が来ると自動更新される。AWSのACMに相当

◼AWSのACMとの違い

AWS   DNS検証用のCNAMEレコードを自分で作る必要があった
      (Terraformでは for_each で検証レコードを生成する)

GCP   対象ドメインがこのロードバランサを向いていることを
      Google側が確認して自動で発行する → 検証レコードを作る作業がない
```

---

### S42 | 発行には時間がかかる

<!-- slide-id: g041slide -->

**[本文]**

```text
PROVISIONING ──(DNSが正しく引ける)──> ACTIVE
       │
       └──(引けない / 向き先が違う)──> FAILED_NOT_VISIBLE

※ 証明書の発行は 10分程度 かかります

  PROVISIONING          発行処理中
  ACTIVE                発行完了
  FAILED_NOT_VISIBLE    ドメインが引けない・向き先が違う

※ ACTIVE になってもすぐには繋がりません.さらに1分ほど待つとHTTPSが通るようになります

◼前提条件
  Aレコードがこのロードバランサを向いていること → だからStep3(DNS)を先にやりました
```

---

### S43 | Terraform コード（SSL）（1/2）

<!-- slide-id: g042slide -->

**[本文]**

```text
cd ~/works/lesson3 && cp -rf ~/infra-study/gcp/lesson3/"4. ssl" ./
cd "4. ssl"
python3 ~/infra-study/gcp/tools/configure.py

resource "google_compute_managed_ssl_certificate" "web" {
  name = "${var.user_name}-web-cert"

  managed {
    domains = ["${var.user_name}.${data.google_dns_managed_zone.public.dns_name}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

---

### S44 | Terraform コード（SSL）（2/2）

<!-- slide-id: p2_3_g042bdy_1 -->

**[本文]**

```text
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
```

---

### S45 | Step4 実行

<!-- slide-id: g043slide -->

**[本文]**

```text
terraform init
  terraform plan, terraform apply


◼証明書の状態を確認(反映までに時間がかかるので、何度か実行する)
  gcloud compute ssl-certificates describe [自分の名前]-web-cert --global \
    --format="value(managed.status)"

  PROVISIONING
  ...
  ACTIVE

※ ここで10分ほど待ちが入ります
   その間に宿題の説明をします(「宿題1 アンケート」以降へ)
```

---

### S46 | アクセス確認

<!-- slide-id: g044slide -->

**[本文]**

```text
◼ブラウザでHTTPSアクセス

  https://[自分の名前].infra-study-gcp.sumsp.jp

  Hello, Infra Study
  hostname: [CONTAINER ID]

◼証明書の中身を見てみる
  ブラウザの鍵マークをクリック → 証明書
  発行元: Google Trust Services
  対象:   [自分の名前].infra-study-gcp.sumsp.jp
  有効期間: 約3ヶ月(自動更新される)
```

---

### S47 | 今日のゴール達成

<!-- slide-id: g045slide -->

**[本文]**

```text
◼できたこと

前回のネットワークを再作成し、stateを引き継いだ
private サブネットにVMを作り、コンテナでアプリを動かした
ロードバランサを6つの部品で組み立てた
ヘルスチェック用のFirewall Ruleを開けた
Cloud DNS でドメインを割り当てた
マネージドSSL証明書でHTTPS化した

※ 外部IPを1つも持たないVMが、HTTPSでインターネットに公開されている状態
```

---

### S48 | 本日のまとめ ①

<!-- slide-id: g046slide -->

**[本文]**

```text
◼Compute Engine
マシンタイプでCPU・メモリを選ぶ。カスタムも作れる
イメージはファミリー名で指定できる(AMI IDのような不透明なIDではない)
ストレージは Persistent Disk
MIGを使えば自動で台数を維持できる

◼ロードバランサ
グローバル外部LBはVPCの外側、Googleのフロントエンドにいる
6つのリソースを上から下へ繋いで作る
   グローバルIP → 転送ルール → プロキシ → URLマップ
                    → バックエンドサービス → インスタンスグループ
バックエンドサービスはVMを直接持てない。インスタンスグループを挟む
ヘルスチェックは独立リソース
```

---

### S49 | 本日のまとめ ②

<!-- slide-id: g047slide -->

**[本文]**

```text
◼今日一番のハマりどころ

  130.211.0.0/22
  35.191.0.0/16

  この2つのレンジからの通信を Firewall Rules で許可しないと
  ヘルスチェックが通らず、503が返り続ける

◼Cloud DNS
  共有しているゾーンは data で参照する。resource で書かない

◼マネージドSSL証明書
無料・自動更新
DNS検証レコードを自分で作る必要がない
発行に数分〜60分かかる
Aレコードが先にできている必要がある
```

---

### S50 | 本日はここまで

<!-- slide-id: g048slide -->

**[本文]**

```text

```

---

### S51 | 宿題1 アンケート

<!-- slide-id: g049slide -->

**[本文]**

```text
◼アンケートのお願い

1分で終わりますのでぜひフィードバックお願い致します！！
次回開催のモチベになります！！！

https://docs.google.com/forms/d/e/1FAIpQLSeQjLfR6f6H_jDR1ZHRQUmJPkaw3BmBEnGPV-t8fUjjIoF37A/viewform
```

**[リンク]**

- [https://docs.google.com/forms/d/e/1FAIpQLSeQjLfR6f6H_jDR1ZHRQUmJPkaw3BmBEnGPV-t8fUjjIoF37A/viewform](https://docs.google.com/forms/d/e/1FAIpQLSeQjLfR6f6H_jDR1ZHRQUmJPkaw3BmBEnGPV-t8fUjjIoF37A/viewform)

---

### S52 | 宿題2 実装課題 ①②

<!-- slide-id: g050slide -->

**[本文]**

```text
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

---

### S53 | 宿題2 実装課題 ③

<!-- slide-id: g051slide -->

**[本文]**

```text
◼3. Cloud Armor で社内IP制限をかけよう

  Cloud Armor は AWS の WAF に相当します
  ロードバランサの手前で、社内IP以外を弾く

  ・セキュリティポリシーを作る
  ・社内IPを許可するルール(priority 1000)
  ・それ以外を拒否するデフォルトルール(priority 2147483647)
  ・バックエンドサービスに紐づける

  社外(スマホのテザリングなど)から403が返ることを確認してください

  回答例: gcp/lesson3/syukudai3/

// 社内IPは限定公開のスライドを参照して、コピー先のterraform.tfvarsに設定する
company_ip = []
```

---

### S54 | 宿題3 ドキュメント

<!-- slide-id: g052slide -->

**[本文]**

```text
◼Compute Engine のドキュメントを眺めてみよう
  https://cloud.google.com/compute/docs

◼Cloud Load Balancing のドキュメントを眺めてみよう
  https://cloud.google.com/load-balancing/docs/https
  https://cloud.google.com/load-balancing/docs/health-check-concepts

◼Terraform google provider の各ドキュメントを眺めてみよう
  google_compute_instance
  google_compute_instance_group
  google_compute_health_check
  google_compute_backend_service
  google_compute_url_map
  google_compute_target_http_proxy
  google_compute_target_https_proxy
  google_compute_global_address
  google_compute_global_forwarding_rule
  google_compute_managed_ssl_certificate
  google_dns_record_set
  google_compute_security_policy
```

**[リンク]**

- [https://cloud.google.com/compute/docs](https://cloud.google.com/compute/docs)
- [https://cloud.google.com/load-balancing/docs/https](https://cloud.google.com/load-balancing/docs/https)
- [https://cloud.google.com/load-balancing/docs/health-check-concepts](https://cloud.google.com/load-balancing/docs/health-check-concepts)
- [google_compute_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance)
- [google_compute_instance_group](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance_group)
- [google_compute_health_check](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_health_check)
- [google_compute_backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service)
- [google_compute_url_map](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map)
- [google_compute_target_http_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_http_proxy)
- [google_compute_target_https_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy)
- [google_compute_global_address](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address)
- [google_compute_global_forwarding_rule](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule)
- [google_compute_managed_ssl_certificate](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate)
- [google_dns_record_set](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set)
- [google_compute_security_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy)

---

### S55 | 参考

<!-- slide-id: g053slide -->

**[本文]**

```text
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

**[リンク]**

- [https://cloud.google.com/compute/docs](https://cloud.google.com/compute/docs)
- [https://cloud.google.com/load-balancing/docs/https](https://cloud.google.com/load-balancing/docs/https)
- [https://cloud.google.com/load-balancing/docs/health-check-concepts](https://cloud.google.com/load-balancing/docs/health-check-concepts)
- [https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)
- [https://cloud.google.com/dns/docs](https://cloud.google.com/dns/docs)
- [https://cloud.google.com/armor/docs/cloud-armor-overview](https://cloud.google.com/armor/docs/cloud-armor-overview)

---

### S56 | 注意事項

<!-- slide-id: g054slide -->

**[本文]**

```text
宿題などで作成したリソースは必ず削除してください！

◼リソースの削除(最後に apply したディレクトリで実行)
  cd ~/works/lesson3/syukudai3       ← 実装課題③まで
  cd ~/works/lesson3/syukudai2       ← 実装課題②まで
  cd ~/works/lesson3/syukudai1       ← 実装課題①まで
  cd ~/works/lesson3/"4. ssl"        ← 講義 Step4 まで

  terraform destroy   → 確認で yes と入力

※ この回は課金されるものが多いです
   Compute Engine / ロードバランサ / 外部IP / Cloud NAT
   使い終わったらリソースを削除してください

※ 全員で1つのプロジェクトを共有しています
   消し忘れはQuotaを圧迫して、他の人のapplyを止めます

※ tfstate用のバケットは残しておいてください
※ 自分のDNSレコードも消えます(共有ゾーン自体は残ります)
```

---

### S57 | おしまい

<!-- slide-id: g055slide -->

**[本文]**

```text
次回 データベース編 もお楽しみに！
```

---

# 付録A: ハンズオンのステップ対応表

| Step | ディレクトリ | 作るもの | 確認すること |
|---|---|---|---|
| 0 | `0. before/` | 第2回のネットワーク一式(直接定義) | 前回と同じものができる |
| 1 | `1. web_instance/` | web VM + IAP用Firewall/IAM | IAPで入って `curl localhost` が通る。外からは見えない |
| 2 | `2. loadbalancer/` | LB 6リソース + ヘルスチェック用Firewall | **503 → Firewall追加 → LBのIPでアクセスできる** |
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

# 付録B: 過去の制作・検証記録（旧ページ番号）

この付録は2026年8〜9月時点の履歴。S番号・構成・所要時間は当時のものであり、現在の57ページとの対応や現構成での動作を保証しない。現在の作図・手順は本文と正本を参照する。

## 実環境での動作確認: **完了(2026-08-28)**

Step0〜4 と宿題2・3を通しで apply → destroy 済み。
`terraform validate` は全8ディレクトリで成功(google provider 8.0.0)。

| 項目 | 結果 |
|---|---|
| 旧構成のモジュール参照(変更前の検証記録) | **OK**。`github.com/shiiman/infra-study//gcp/lesson3/0. before` を素のURLで解決できた(ディレクトリ名のスペースも問題なし) |
| Step0+1 apply | OK。11リソース |
| アプリ起動(S16) | OK。**約7分**(apt-get + docker build) |
| Step2 Firewallなし | **503**(原稿の502は誤りだったので修正済み)。バックエンドUNHEALTHY |
| LBの伝播 | apply直後は無応答(curl 000)。**約1.5分**で503が返るようになる |
| Step2 Firewallあり | **37秒**でHEALTHY + HTTP 200 |
| Step3 DNS | OK。反映は即座。ドメインでアクセスできた |
| Step4 証明書 | **7分20秒でACTIVE、8分20秒でHTTPS 200**。ACTIVE後もさらに約1分のラグ |
| 証明書の中身 | issuer=Google Trust Services (CN=WR3)、有効期間 約90日 |
| 宿題2 冗長化 | OK。起動スクリプトの完走まで**約5分**。2台に7:3で振り分けを確認 |
| 宿題3 Cloud Armor | OK。反映に**約1分**。許可外IPから403、許可IPから200、バックエンドはHEALTHYのまま |
| destroy | **OK**。28リソースが4分19秒でエラーなく削除。LBの依存順序も問題なし |

### 修正した箇所

1. **S31: 502 → 503**
   バックエンドが全滅している状態は 503 Service Unavailable。
   502 Bad Gateway は「バックエンドはいるが応答が不正」のとき。
   両者の違いを説明に足した(障害切り分けに使えるため)。

2. **S31: LBの伝播待ちを追記**
   apply直後は503ですらなく無応答(接続タイムアウト)。
   1〜2分待ってから503になる。ここを知らないと「壊れた」と誤解する。

3. **S33: 20〜30秒 → 30〜40秒**(実測37秒)

4. **S42/S44: 数分〜60分 → 約10分**(実測8分20秒)
   ACTIVE になってもHTTPSはすぐ通らず、さらに1分ほどラグがある点も追記。

5. **S16: 所要時間 約7分を明記**
   原稿に記載がなかった。待ち時間としては最長なので、
   S18/S19を挟む案内を[話す]に追加。

### 待ち時間の合計

| 箇所 | 実測 |
|---|---|
| S16 アプリのビルド | 約2分 |
| S31 LBの伝播 | 約1.5分 |
| S33 ヘルスチェック | 約40秒 |
| S44 証明書の発行 | 約8分 |
| **合計** | **約12分** |

2時間のうち12分が待ちになる。解説を挟める順序に組んであるが、
**受講者全員が同時に実行すると伸びる可能性**がある(特にS16のdocker build)。
当日は「先にコマンドを流してから解説」の進め方を推奨する。

## 受講者相当の権限での検証(2026-08-28 実施)

第4回の `0. before` に第3回の全リソースが含まれているため、
**第4回を受講者権限で流した際に、第3回のリソースもすべて検証された。**

VM / インスタンスグループ / ヘルスチェック / バックエンドサービス /
URLマップ / HTTPプロキシ / HTTPSプロキシ / グローバルIP / 転送ルール×2 /
マネージドSSL証明書 / DNSレコード / IAP関連IAM×3 — **すべてOK**。

ロール構成は第1回 付録A の9ロール。

## 未検証のまま残っている項目

- **宿題1(Docker自動起動)**: VMの再起動を伴うため未実施。
  コード変更がなくREADMEのみなので、リスクは低い
- **Cloud Shell での実行**: 今回もローカルからの実行。
  第1回〜第4回ともCloud Shellでの通し実行は未実施
- **backendブロック**: 検証ではローカルstateを使った(第1回・第2回で検証済みのため)

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

## 開催前に撮るスクリーンショット — **ブラウザ画面の3枚だけ(2026-09-18 整理)**

**撮る**

| | 何を | なぜ残すか |
|---|---|---|
| S31 | **`no healthy upstream` のブラウザ画面** | 「こうなるはず」を先に見せる価値がある。`get-health` の UNHEALTHY 出力は端末なので不要 |
| S34 | **LBのIPでのブラウザ表示** | 同上 |
| S45 | **HTTPS表示(鍵マークが見えるように)** | 同上。鍵マークは口頭では伝わらない |

**撮らない**

| | 種別 | 判断 |
|---|---|---|
| S20 インスタンス一覧 | コンソールUI | **不要。講師が自分の画面を共有して実演する** |
| S31 の `get-health` 出力 | 端末出力 | **不要。文言は本文に載せてある** |

> **★ 端末出力とコンソールUIは撮らない、ブラウザの表示結果は撮る**
> という切り分けにした(2026-09-18)。
> 端末とコンソールは画面共有で実演でき、文言も本文にある。
> ブラウザの表示結果だけは「成功したらこう見える」を
> 先に見せておく意味があるため残す。

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
