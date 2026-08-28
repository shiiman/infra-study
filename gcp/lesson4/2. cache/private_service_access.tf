/**
 * 限定公開サービスアクセス (Private Service Access)
 *
 * ★ AWSには無い、GCP独自の前提 ★
 *
 * Cloud SQL や Memorystore は「Googleが管理するVPC」の中で動いている。
 * 自分のVPCとは別のネットワークなので、そのままでは繋がらない。
 *
 * そこで自分のVPCの中からIPレンジを1つ切り出してGoogle側に貸し出し、
 * VPCピアリングで両者を繋ぐ。これが限定公開サービスアクセス。
 *
 *   自分のVPC 172.16.0.0/16
 *     ├ public  172.16.0.0/24
 *     ├ private 172.16.10.0/24
 *     └ 172.16.192.0/20  ← Googleに貸し出す(ここにCloud SQLなどのIPが入る)
 *
 * ★ レンジは大きめに取ること ★
 * サービスごとにこのレンジからブロックを切り出して使う。
 * /24 だと Memorystore を作った時点で埋まり、
 * Cloud SQL の作成が次のエラーで失敗する。
 *
 *   Couldn't find free blocks in allocated IP ranges.
 *   Please allocate new ranges for this service provider.
 *
 * Googleは /16 を推奨している。ここでは /20 にしている。
 *          ↕ VPCピアリング
 *   Googleが管理するVPC
 *
 * AWSではRDSやElastiCacheが自分のVPCのサブネットに直接ENIを作っていたので、
 * この手順は存在しなかった。代わりにサブネットグループを作っていた。
 *
 * ★ 1つ作れば Cloud SQL と Memorystore の両方で使い回せる
 *
 * https://cloud.google.com/vpc/docs/configure-private-services-access
 */

variable "private_service_cidr" {}

/**
 * Googleに貸し出すIPレンジを予約する
 *
 * purpose = "VPC_PEERING" が限定公開サービスアクセス用の予約という意味。
 * 第3回で使った google_compute_global_address(ロードバランサのIP)と
 * 同じリソースだが、purposeが違うと全く別の用途になる。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address
 */
resource "google_compute_global_address" "private_service" {
  name          = "${var.user_name}-private-service-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", var.private_service_cidr)[0]
  prefix_length = tonumber(split("/", var.private_service_cidr)[1])
  network       = module.before.vpc_id
}

/**
 * VPCピアリングを張る
 *
 * servicenetworking.googleapis.com が Google側のサービス。
 * 上で予約したレンジを渡して接続する。
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection
 */
resource "google_service_networking_connection" "private_service" {
  network                 = module.before.vpc_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service.name]
}
