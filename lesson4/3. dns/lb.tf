/**
 * Aplication Loadbalancer作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
 */
resource "aws_lb" "application_lb" {
  name                       = "${var.user_name}-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [resource.aws_security_group.sg_lb.id]
  subnets                    = split(",", module.before.public_subnet_ids)
}

/**
 * target group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
 */
resource "aws_lb_target_group" "lb_target_group" {
  name                 = "${var.user_name}-lb-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = module.before.vpc_id
}

/**
 * target group attachment作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment
 */
resource "aws_lb_target_group_attachment" "lb_target_group_attachment" {
  count            = length(resource.aws_instance.web_instance.*.id)
  target_group_arn = resource.aws_lb_target_group.lb_target_group.arn
  target_id        = resource.aws_instance.web_instance.*.id[count.index]
  port             = 80
}

/**
 * lb listener作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
 */
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = resource.aws_lb.application_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = resource.aws_lb_target_group.lb_target_group.arn
  }
}
