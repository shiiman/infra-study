variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}
variable "dns_zone_name" {}
variable "private_service_cidr" {}

/**
 * 第4回までの完成状態をモジュールとして読み込む
 * ネットワーク + VM + ロードバランサ + DNS + SSL + Memorystore + Spanner
 */
module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson5/0. before"

  project_id           = var.project_id
  subnet_public_cidr   = var.subnet_public_cidr
  subnet_private_cidr  = var.subnet_private_cidr
  dns_zone_name        = var.dns_zone_name
  private_service_cidr = var.private_service_cidr
  user_name            = var.user_name
}
