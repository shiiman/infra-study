variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}
variable "dns_zone_name" {}
variable "private_service_cidr" {}

/**
 * 第6回までの完成状態をモジュールとして読み込む
 * ネットワーク + Memorystore + Spanner + Cloud Run + ロードバランサ + Cloud Storage + CDN
 *
 * ★ 第7回の CI/CD は入れていません ★
 *
 * 今日は「すでに動いているシステムを、どう見るか」の回です。
 * ビルドトリガーがあってもなくても監視の話は変わらないので、
 * 変数が1つ増える分だけ邪魔になります。
 *
 * 「積み上げ」は原則ですが、その回に関係ないものまで積む必要はありません。
 */
module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson8/0. before"

  project_id           = var.project_id
  subnet_public_cidr   = var.subnet_public_cidr
  subnet_private_cidr  = var.subnet_private_cidr
  dns_zone_name        = var.dns_zone_name
  private_service_cidr = var.private_service_cidr
  user_name            = var.user_name
}
