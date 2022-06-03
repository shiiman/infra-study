/**
 * VPC作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
 */
resource "aws_vpc" "vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "${var.user_name}-vpc"
  }
}
