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
