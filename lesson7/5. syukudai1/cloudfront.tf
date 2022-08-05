/**
 * Cloudfront Origin Access Identity作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_identity
 */
resource "aws_cloudfront_origin_access_identity" "cloudfront_origin_access_identity" {
  comment = "s3アクセス"
}

/**
 * キャッシュポリシー作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy
 */
resource "aws_cloudfront_cache_policy" "cache_policy" {
  name = "${var.user_name}-cache-policy"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {}
    headers_config {}
    query_strings_config {
      query_string_behavior = "whitelist"
      query_strings {
        items = ["versionId"]
      }
    }
  }
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

    cache_policy_id            = resource.aws_cloudfront_cache_policy.cache_policy.id
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
