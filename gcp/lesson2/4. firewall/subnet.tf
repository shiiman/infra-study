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
}
