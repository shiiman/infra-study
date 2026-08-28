variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}
variable "dns_zone_name" {}

/**
 * 第3回までの完成状態をモジュールとして読み込む
 * ネットワーク + webインスタンス + ロードバランサ + DNS + SSL証明書
 */
module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson4/0. before"

  project_id          = var.project_id
  subnet_public_cidr  = var.subnet_public_cidr
  subnet_private_cidr = var.subnet_private_cidr
  dns_zone_name       = var.dns_zone_name
  user_name           = var.user_name
}
