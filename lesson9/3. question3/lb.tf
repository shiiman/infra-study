resource "aws_security_group" "sg_lb" {
  name   = "${var.user_name}-lb-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-lb-sg"
  }
}

resource "aws_lb" "application_lb" {
  name                       = "${var.user_name}-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [resource.aws_security_group.sg_lb.id]
  subnets                    = resource.aws_subnet.subnet_public.*.id[count.index % length(resource.aws_subnet.subnet_public.*.id)]
}

resource "aws_lb_target_group" "lb_target_group" {
  name                 = "${var.user_name}-lb-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = resource.aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "lb_target_group_attachment" {
  count            = length(resource.aws_instance.private_instance.*.id)
  target_group_arn = resource.aws_lb_target_group.lb_target_group.arn
  target_id        = resource.aws_instance.private_instance.*.id[count.index]
  port             = 80
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = resource.aws_lb.application_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = resource.aws_lb_target_group.lb_target_group.arn
  }
}
