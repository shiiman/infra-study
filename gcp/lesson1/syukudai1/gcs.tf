/**
 * tfstate保存用のGCSバケット作成
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
 */
resource "google_storage_bucket" "tfstate" {
  // バケット名はGCP全体で一意である必要があるため、プロジェクトIDを含めている
  name = "${var.project_id}-tfstate-${var.user_name}"

  // GCSのlocationはリージョン(asia-northeast1)/デュアルリージョン/マルチリージョン(ASIA)が選べる
  location = "ASIA-NORTHEAST1"

  // バージョニング: tfstateを壊してしまった時に前の世代へ戻せるようにする
  versioning {
    enabled = true
  }

  // 均一なバケットレベルのアクセス: 旧来のACLを無効化し、権限管理をIAMに一本化する
  uniform_bucket_level_access = true

  // 勉強会用: 中身が残っていても terraform destroy で削除できるようにする
  force_destroy = true
}
