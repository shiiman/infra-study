/**
 * EIP作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
 */
resource "aws_eip" "eip" {
  vpc = true

  tags = {
    Name = "${var.user_name}-ng-eip"
  }
}

/**
 * NAT Gateway作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
 */
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = resource.aws_eip.eip.id
  subnet_id     = resource.aws_subnet.subnet_public.0.id

  tags = {
    Name = "${var.user_name}-ng"
  }
}
