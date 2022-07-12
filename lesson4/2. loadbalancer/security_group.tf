/**
 * security group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
 */
resource "aws_security_group" "sg_web_instance" {
  name   = "${var.user_name}-web-instance-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-web-instance-sg"
  }
}

resource "aws_security_group" "sg_lb" {
  name   = "${var.user_name}-lb-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-lb-sg"
  }
}

/**
 * Security Group Rule作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule
 */
# internetアクセス
resource "aws_security_group_rule" "security_group_rule_egress_web_instance" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = resource.aws_security_group.sg_web_instance.id
}

# lbからwebインスタンスへのhttp
resource "aws_security_group_rule" "security_group_rule_web_instance_from_lb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_web_instance.id
  source_security_group_id = resource.aws_security_group.sg_lb.id
}

variable "company_ip" { type = list(string) }

# 会社からlbへのhttp
resource "aws_security_group_rule" "security_group_rule_lb_from_company_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.company_ip
  security_group_id = resource.aws_security_group.sg_lb.id
}
