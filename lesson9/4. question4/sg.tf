# lbへのhttp
resource "aws_security_group_rule" "security_group_rule_lb_from_all_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = resource.aws_security_group.sg_lb.id
}

# lbからwebへのhttp
resource "aws_security_group_rule" "security_group_rule_lb_to_web_http" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_lb.id
  source_security_group_id = resource.aws_security_group.sg_web.id
}

# lbからwebへのhttp
resource "aws_security_group_rule" "security_group_rule_web_from_lb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_web.id
  source_security_group_id = resource.aws_security_group.sg_lb.id
}
