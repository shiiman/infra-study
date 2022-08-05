/**
 * Cloudfront Origin Access Identity作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_identity
 */
resource "aws_cloudfront_origin_access_identity" "cloudfront_origin_access_identity" {
  comment = "s3アクセス"
}

/**
 * Cloudfront Distribution作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution
 */
resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  enabled             = true

  origin {
    domain_name = resource.aws_s3_bucket.bucket.bucket_domain_name
    origin_id   = "${resource.aws_s3_bucket.bucket.id}"

    s3_origin_config {
      origin_access_identity = resource.aws_cloudfront_origin_access_identity.cloudfront_origin_access_identity.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${resource.aws_s3_bucket.bucket.id}"
    viewer_protocol_policy = "https-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
