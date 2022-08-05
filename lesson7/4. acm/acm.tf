provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

/**
 * acm 作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate
 */
resource "aws_acm_certificate" "acm_certificate" {
  provider = aws.us_east

  domain_name       ="${var.user_name}.${data.aws_route53_zone.public.name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = "300"
  type            = each.value.type
  zone_id         = data.aws_route53_zone.public.zone_id
}

/**
 * acm validation 作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation
 */
resource "aws_acm_certificate_validation" "cert_validation" {
  provider = aws.us_east

  certificate_arn         = aws_acm_certificate.acm_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_record : record.fqdn]
}
