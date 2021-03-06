/**
 * security group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
 */
resource "aws_security_group" "sg_bastion" {
  name   = "${var.user_name}-bastion-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-bastion-sg"
  }
}

/**
 * Security Group Rule作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule
 */

# internetアクセス
resource "aws_security_group_rule" "security_group_rule_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = resource.aws_security_group.sg_bastion.id
}

# icmpアクセス
resource "aws_security_group_rule" "security_group_rule_icmp" {
  type              = "ingress"
  from_port         = "-1"
  to_port           = "-1"
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = resource.aws_security_group.sg_bastion.id
}

variable "company_ip" { type = list(string) }

# 会社からbastionへのssh
resource "aws_security_group_rule" "security_group_rule_company" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.company_ip
  security_group_id = resource.aws_security_group.sg_bastion.id
}
