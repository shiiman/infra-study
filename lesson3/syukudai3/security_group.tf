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

resource "aws_security_group" "sg_private_instance" {
  name   = "${var.user_name}-private-instance-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-private-instance-sg"
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

# bastionからprivateインスタンスへのssh
resource "aws_security_group_rule" "security_group_rule_private_instance" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_private_instance.id
  source_security_group_id = resource.aws_security_group.sg_bastion.id
}

# internetアクセス
resource "aws_security_group_rule" "security_group_rule_egress_private_instance" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = resource.aws_security_group.sg_private_instance.id
}
