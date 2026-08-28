/**
 * Cloud Router作成
 *
 * Cloud NATを動かすために必須のリソース。
 * AWSのNAT Gatewayは単体で動いたが、GCPはCloud Routerとセットになる。
 * (本来はBGPでルート交換をするためのマネージドルータ)
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router
 */
resource "google_compute_router" "router" {
  name    = "${var.user_name}-router"
  network = google_compute_network.vpc.id
  region  = "asia-northeast1"
}

/**
 * Cloud NAT作成
 *
 * AWSのNAT Gatewayに相当するが、単位が違う。
 *   AWS : サブネット(ゾーン)ごとに作り、冗長化は自分で行う
 *   GCP : リージョンごとに1つ。リージョン内の冗長性はGoogle側で担保される
 *
 * また外部IPを自分で確保(EIP)する必要もない。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
 */
resource "google_compute_router_nat" "nat" {
  name   = "${var.user_name}-nat"
  router = google_compute_router.router.name
  region = "asia-northeast1"

  // NAT用の外部IPをGoogleに自動で払い出してもらう
  // 外部からIP制限をかけたい場合は MANUAL_ONLY にして固定IPを使う
  nat_ip_allocate_option = "AUTO_ONLY"

  // このVPC内の全サブネットをNATの対象にする
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
