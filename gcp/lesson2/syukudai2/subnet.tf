variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}

/**
 * サブネット作成
 *
 * AWSではサブネットは「ゾーン(AZ)」単位だったが、GCPは「リージョン」単位。
 * 1つのサブネットがそのリージョンの全ゾーンにまたがる。
 * したがってAWSのように「1a用」「1c用」と2つ作る必要がない。
 *
 * なお public / private という区別はGCPには存在しない。
 * 外部IPを持つかどうかだけで決まる。ここでの名前は運用上の目印。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
 */
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

  // 限定公開のGoogleアクセス
  // 外部IPを持たないVMから、インターネットに出ることなく
  // Google のAPI(Cloud Storage, Secret Managerなど)へアクセスできるようになる
  private_ip_google_access = true
}

/**
 * 宿題2-1: 用途別サブネットの追加
 *
 * GCPのサブネットはリージョン単位なので、AWSのように
 * 「1a用」「1c用」と2つずつ作る必要はない。用途ごとに1つでよい。
 */
variable "subnet_web_cidr" {}
variable "subnet_db_cidr" {}
variable "subnet_cache_cidr" {}

resource "google_compute_subnetwork" "web" {
  name          = "${var.user_name}-web-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast1"
  ip_cidr_range = var.subnet_web_cidr

  private_ip_google_access = true
}

resource "google_compute_subnetwork" "db" {
  name          = "${var.user_name}-db-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast1"
  ip_cidr_range = var.subnet_db_cidr

  private_ip_google_access = true
}

resource "google_compute_subnetwork" "cache" {
  name          = "${var.user_name}-cache-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast1"
  ip_cidr_range = var.subnet_cache_cidr

  private_ip_google_access = true
}

/**
 * 宿題2-2: 別リージョン(大阪)のサブネット追加
 *
 * VPCはグローバルリソースなので、同じVPCのまま大阪リージョンに
 * サブネットを足せる。AWSでこれをやるにはVPCをもう1つ作って
 * VPCピアリングを張る必要があった。
 */
variable "subnet_osaka_public_cidr" {}
variable "subnet_osaka_private_cidr" {}

resource "google_compute_subnetwork" "osaka_public" {
  name          = "${var.user_name}-osaka-public-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast2"
  ip_cidr_range = var.subnet_osaka_public_cidr
}

resource "google_compute_subnetwork" "osaka_private" {
  name          = "${var.user_name}-osaka-private-subnet"
  network       = google_compute_network.vpc.id
  region        = "asia-northeast2"
  ip_cidr_range = var.subnet_osaka_private_cidr

  private_ip_google_access = true
}
