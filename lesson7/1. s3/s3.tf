/**
 * バケット作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
 */
resource "aws_s3_bucket" "bucket" {
  bucket = "${var.user_name}-bucket"
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = resource.aws_s3_bucket.bucket.id
  acl    = "private"
}
