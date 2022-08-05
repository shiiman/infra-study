/**
 * バケット作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
 */
resource "aws_s3_bucket" "bucket" {
  bucket = "${var.user_name}-bucket"
}

/**
 * バケットACL作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl
 */
resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = resource.aws_s3_bucket.bucket.id
  acl    = "private"
}

/**
 * ポリシードキュメント作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document
 */
data "aws_iam_policy_document" "iam_policy_document" {
  statement {
    sid       = "CloudFrontOriginAccessIdentity"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${resource.aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [resource.aws_cloudfront_origin_access_identity.cloudfront_origin_access_identity.iam_arn]
    }
  }
}

/**
 * バケットポリシー作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy
 */
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = resource.aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.iam_policy_document.json
}

/**
 * バージョニング設定
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
 */
resource "aws_s3_bucket_versioning" "s3_bucket_versioning" {
  bucket = resource.aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

/**
 * ライフサイクル設定
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration
 */
resource "aws_s3_bucket_lifecycle_configuration" "s3_bucket_lifecycle_configuration" {
  bucket = resource.aws_s3_bucket.bucket.id

  rule {
    id = "${var.user_name}-lifecycle-rule"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}
