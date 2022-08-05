/**
 * Cloudfront Origin Access Identity作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_identity
 */
resource "aws_cloudfront_origin_access_identity" "cloudfront_origin_access_identity" {
  comment = "s3アクセス"
}

/**
 * キャッシュポリシー取得
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_cache_policy
 */
data "aws_cloudfront_cache_policy" "managed_caching_optimized" {
  name = "Managed-CachingOptimized"
}

/**
 * オリジンリクエストポリシー取得
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_origin_request_policy
 */
data "aws_cloudfront_origin_request_policy" "managed_elemental_mediatailor_personalizedmanifests" {
  name = "Managed-Elemental-MediaTailor-PersonalizedManifests"
}

/**
 * レスポンスヘッダーポリシー取得
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_response_headers_policy
 */
data "aws_cloudfront_response_headers_policy" "managed_simplecors" {
  name = "Managed-SimpleCORS"
}

/**
 * Cloudfront Distribution作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution
 */
resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  enabled = true
  aliases = ["${var.user_name}.${data.aws_route53_zone.public.name}"]

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

    cache_policy_id            = data.aws_cloudfront_cache_policy.managed_caching_optimized.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.managed_elemental_mediatailor_personalizedmanifests.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.managed_simplecors.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  viewer_certificate {
    acm_certificate_arn = resource.aws_acm_certificate.acm_certificate.arn
    ssl_support_method  = "sni-only"
  }
}
