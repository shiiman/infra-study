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
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "whitelist"
      query_strings {
        items = ["versionId"]
      }
    }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

/**
 * オリジンリクエストポリシー作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_request_policy
 */
resource "aws_cloudfront_origin_request_policy" "origin_request_policy" {
  name = "${var.user_name}-origin-request-policy"
  cookies_config {
    cookie_behavior = "none"
  }
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["origin", "access-control-request-headers", "access-control-request-method"]
    }
  }
  query_strings_config {
    query_string_behavior = "whitelist"
    query_strings {
      items = ["versionId"]
    }
  }
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
  enabled    = true
  aliases    = ["${var.user_name}.${data.aws_route53_zone.public.name}"]
  web_acl_id = resource.aws_wafv2_web_acl.wafv2_web_acl_cf.arn

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
    origin_request_policy_id   = resource.aws_cloudfront_origin_request_policy.origin_request_policy.id
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
