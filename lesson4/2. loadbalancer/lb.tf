/**
 * Aplication Loadbalancer作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
 */
resource "aws_lb" "application_lb" {
  name                       = "${var.user_name}-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [resource.aws_security_group.sg_lb.id]
  subnets                    = resource.aws_subnet.subnet_public.*.id
}

/**
 * target group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
 */
resource "aws_lb_target_group" "lb_target_group" {
  name                 = "${var.user_name}-lb-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = resource.aws_vpc.vpc.id
}

/**
 * target group attachment作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment
 */
resource "aws_lb_target_group_attachment" "lb_target_group_attachment" {
  target_group_arn = resource.aws_lb_target_group.lb_target_group.arn
  target_id        = resource.aws_instance.web_instance.id
  port             = 80
}
