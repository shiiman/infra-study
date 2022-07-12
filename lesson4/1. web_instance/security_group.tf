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
