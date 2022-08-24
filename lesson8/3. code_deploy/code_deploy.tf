# ロール作成 =====================================================

variable "codedeploy_role_settings" { type = map(string) }

resource "aws_iam_role" "codedeploy_iam_role" {
  name               = "Cloud9-${var.user_name}-codedeploy-iam-role"
  assume_role_policy = var.codedeploy_role_settings["assume_role_policy"]
}

resource "aws_iam_role_policy_attachment" "codedeploy_iam_role_policy_attachment1" {
  role       = resource.aws_iam_role.codedeploy_iam_role.id
  policy_arn = var.codedeploy_role_settings["policy_arn_1"]
}

resource "aws_iam_role_policy_attachment" "codedeploy_iam_role_policy_attachment2" {
  role       = resource.aws_iam_role.codedeploy_iam_role.id
  policy_arn = var.codedeploy_role_settings["policy_arn_2"]
}

# =============================================================

resource "aws_lb_target_group" "lb_target_group_green" {
  name                 = "${var.user_name}-lb-tg-green"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = module.before.vpc_id
}

resource "aws_lb_listener" "lb_listener_test" {
  load_balancer_arn = module.before.lb_arn
  port              = 4443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = module.before.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = resource.aws_lb_target_group.lb_target_group_green.arn
  }

  lifecycle {
    ignore_changes = [default_action.0.target_group_arn]
  }
}

# 会社からlbへの4443
resource "aws_security_group_rule" "security_group_rule_lb_from_company_test" {
  type              = "ingress"
  from_port         = 4443
  to_port           = 4443
  protocol          = "tcp"
  cidr_blocks       = var.company_ip
  security_group_id = module.before.sg_lb_id
}

/**
 * Code Deploy Application作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_app
 */
resource "aws_codedeploy_app" "codedeploy_app" {
    name              =  "${var.user_name}-codedeploy"
    compute_platform  = "ECS"
}

/**
 * Code Deploy group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group
 */
resource "aws_codedeploy_deployment_group" "codedeploy_deployment_group" {
  app_name               = resource.aws_codedeploy_app.codedeploy_app.name
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  deployment_group_name  = "${var.user_name}-deployment-group"
  service_role_arn       = resource.aws_iam_role.codedeploy_iam_role.arn

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = "STOP_DEPLOYMENT"
      wait_time_in_minutes = 60
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = module.before.ecs_cluster_name
    service_name = module.before.ecs_service_name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [module.before.lb_listener_arn]
      }

      test_traffic_route {
        listener_arns = [resource.aws_lb_listener.lb_listener_test.arn]
      }

      target_group {
        name = module.before.lb_target_group_blue_name
      }

      target_group {
        name = resource.aws_lb_target_group.lb_target_group_green.name
      }
    }
  }
}
