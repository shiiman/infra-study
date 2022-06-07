/**
 * Route Table作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
 */
resource "aws_route_table" "route_table_public" {
  vpc_id = resource.aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = resource.aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${var.user_name}-rt-public"
  }
}

/**
 * Route Table Association作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
 */
resource "aws_route_table_association" "route_table_association_public" {
  count          = length(resource.aws_subnet.subnet_public.*.id)
  subnet_id      = resource.aws_subnet.subnet_public.*.id[count.index]
  route_table_id = resource.aws_route_table.route_table_public.id
}

resource "aws_route_table" "route_table_private" {
  vpc_id = resource.aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = resource.aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "${var.user_name}-rt-private"
  }
}

resource "aws_route_table_association" "route_table_association_private" {
  count          = length(resource.aws_subnet.subnet_private.*.id)
  subnet_id      = resource.aws_subnet.subnet_private.*.id[count.index]
  route_table_id = resource.aws_route_table.route_table_private.id
}
