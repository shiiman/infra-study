/**
 * waf ip set 作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set
 */
resource "aws_wafv2_ip_set" "wafv2_ip_set" {
  name               = "${var.user_name}_company_ip_set"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.company_ip
}

/**
 * waf web acl 作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl
 */
resource "aws_wafv2_web_acl" "wafv2_web_acl_lb" {
  name  = "${var.user_name}-lb-webacl"
  scope       = "REGIONAL"

  default_action {
    block {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "All"
    sampled_requests_enabled   = false
  }

  rule {
    name     = "company-ip-set-roule"
    priority = 0

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = resource.aws_wafv2_ip_set.wafv2_ip_set.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "${var.user_name}-company-ip-set-roule-metric"
      sampled_requests_enabled   = false
    }
  }
}

/**
 * waf web acl association 作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association
 */
resource "aws_wafv2_web_acl_association" "wafv2_web_acl_association_lb" {
  resource_arn = resource.aws_lb.application_lb.arn
  web_acl_arn  = resource.aws_wafv2_web_acl.wafv2_web_acl_lb.arn
}
