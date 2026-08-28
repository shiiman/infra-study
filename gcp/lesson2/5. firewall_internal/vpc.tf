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

  // REGIONAL: 同一リージョンのサブネット同士のみルートを共有(デフォルト)
  // GLOBAL  : 全リージョンのサブネット間でルートを共有(Cloud Router使用時)
  routing_mode = "REGIONAL"
}
