/**
 * VPC作成
 *
 * AWSと違い、GCPのVPCは「グローバル」リソース。
 * リージョンを指定しないし、CIDRも持たない。
 * CIDRを持つのはこの下に作るサブネットの方。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
 */
resource "google_compute_network" "vpc" {
  name = "${var.user_name}-vpc"

  // 各リージョンにサブネットを自動生成しない(自分で設計するのでfalse)
  auto_create_subnetworks = false

  // Cloud Router が学習した動的経路の適用範囲
  // REGIONAL: 同一リージョンのみ(デフォルト)
  // GLOBAL  : 全リージョン
  // VPC内のサブネット間通信は、この設定では制限されない
  routing_mode = "REGIONAL"
}
