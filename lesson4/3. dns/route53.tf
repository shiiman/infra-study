route53_host_name = {}

data "aws_route53_zone" "public" {
  name         = var.route53_host_name
  private_zone = false
}

/**
 * route53 record 作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record
 */
resource "aws_route53_record" "route53_record" {
  name    = "user_name.${data.aws_route53_zone.public.name}"
  zone_id = data.aws_route53_zone.public.zone_id
  type    = "A"

  alias {
    name                   = resource.aws_lb.application_lb.dns_name
    zone_id                = resource.aws_lb.application_lb.zone_id
    evaluate_target_health = true
  }
}
