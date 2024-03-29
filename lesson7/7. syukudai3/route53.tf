variable "route53_host_name" {}

data "aws_route53_zone" "public" {
  name         = var.route53_host_name
  private_zone = false
}

/**
 * route53 record 作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
 */
resource "aws_route53_record" "route53_record" {
  name    = "${var.user_name}.${data.aws_route53_zone.public.name}"
  zone_id = data.aws_route53_zone.public.zone_id
  type    = "A"

  alias {
    name                   = resource.aws_cloudfront_distribution.cloudfront_distribution.domain_name
    zone_id                = resource.aws_cloudfront_distribution.cloudfront_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}
