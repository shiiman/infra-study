/**
 * tfstate保存用のGCSバケット(参照のみ)
 *
 * このバケットは gcloud コマンドで作成しており、Terraformの管理外にある。
 * Terraformで作ってしまうと terraform destroy の対象になり、
 * tfstateを置いているバケット自身を消しにいって最後のロック解放に失敗する。
 *
 * 管理外のリソースは data ブロックで読み取って参照する。
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_bucket
 */
data "google_storage_bucket" "tfstate" {
  // バケット名はGCP全体で一意である必要があるため、プロジェクトIDを含めている
  name = "${var.project_id}-tfstate-${var.user_name}"
}
