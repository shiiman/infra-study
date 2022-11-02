# lbへのhttp
resource "aws_security_group_rule" "security_group_rule_lb_from_all_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = "0.0.0.0/0"
  security_group_id = resource.aws_security_group.sg_lb.id
}

# lbからwebインスタンスへのhttp
resource "aws_security_group_rule" "security_group_rule_lb_to_web_instance_http" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_lb.id
  source_security_group_id = resource.aws_security_group.private_instance.id
}

# lbからwebインスタンスへのhttp
resource "aws_security_group_rule" "security_group_rule_web_instance_from_lb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.private_instance.id
  source_security_group_id = resource.aws_security_group.sg_lb.id
}
