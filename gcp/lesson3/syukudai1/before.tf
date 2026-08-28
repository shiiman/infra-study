variable "subnet_public_cidr" {}
variable "subnet_private_cidr" {}

/**
 * 第2回で作ったネットワークをモジュールとして読み込む
 *
 * 前回の作業ディレクトリをそのまま使うのではなく、
 * 完成状態をモジュール化して呼び出すことで、
 * 第3回の作業ディレクトリだけで完結できるようにしている。
 */
module "before" {
  source = "github.com/shiiman/infra-study//gcp/lesson3/0. before"

  project_id          = var.project_id
  subnet_public_cidr  = var.subnet_public_cidr
  subnet_private_cidr = var.subnet_private_cidr
  user_name           = var.user_name
}
