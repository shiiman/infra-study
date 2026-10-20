variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}
variable "dns_zone_name" {}
variable "private_service_cidr" {}

/**
 * 第6回までの完成状態をモジュールとして読み込む
 * ネットワーク + Memorystore + Spanner + Cloud Run + ロードバランサ + Cloud Storage + CDN
 *
 * ★ 今回の 0. before には第6回の完成形がまるごと入っています ★
 *
 * 第5回・第6回では「今日いじるものは 0. before から外す」方針でしたが、
 * 今日いじるのは Terraform のコードではなく **デプロイの仕組み** なので、
 * インフラの形はそのまま使います。
 *
 * ただし Cloud Run には lifecycle { ignore_changes } を1つ足してあります。
 * 理由は Step3 で説明します。
 */
module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson7/0. before"

  project_id           = var.project_id
  subnet_public_cidr   = var.subnet_public_cidr
  subnet_private_cidr  = var.subnet_private_cidr
  dns_zone_name        = var.dns_zone_name
  private_service_cidr = var.private_service_cidr
  user_name            = var.user_name
}
