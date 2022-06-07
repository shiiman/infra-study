/**
 * EIP作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
 */
resource "aws_eip" "eip" {
  count = length(resource.aws_subnet.subnet_public.*.id)
  vpc = true

  tags = {
    Name = "${format("${var.user_name}-ng%04d", count.index + 1)}-eip"
  }
}

/**
 * NAT Gateway作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
 */
resource "aws_nat_gateway" "nat_gateway" {
  count         = length(resource.aws_subnet.subnet_public.*.id)
  allocation_id = resource.aws_eip.eip.*.id[count.index]
  subnet_id     = resource.aws_subnet.subnet_public.*.id[count.index]

  tags = {
    Name = format("${var.user_name}-ng%04d", count.index + 1)
  }
}
