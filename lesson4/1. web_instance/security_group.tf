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
