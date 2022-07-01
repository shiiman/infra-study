resource "aws_vpc" "vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "${var.user_name}-vpc"
  }
}

variable "availability_zones" { type = list(string) }
variable "subnet_public_cidr_blocks" { type = list(string) }
variable "subnet_private_cidr_blocks" { type = list(string) }

resource "aws_subnet" "subnet_public" {
  count             = length(var.subnet_public_cidr_blocks)
  vpc_id            = resource.aws_vpc.vpc.id
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  cidr_block        = var.subnet_public_cidr_blocks[count.index]

  tags = {
    Name = format("${var.user_name}-public-%01d-subnet", count.index + 1)
  }
}

resource "aws_subnet" "subnet_private" {
  count             = length(var.subnet_private_cidr_blocks)
  vpc_id            = resource.aws_vpc.vpc.id
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  cidr_block        = var.subnet_private_cidr_blocks[count.index]

  tags = {
    Name = format("${var.user_name}-private-%01d-subnet", count.index + 1)
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-ig"
  }
}

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

resource "aws_route_table_association" "route_table_association_public" {
  count          = length(resource.aws_subnet.subnet_public.*.id)
  subnet_id      = resource.aws_subnet.subnet_public.*.id[count.index]
  route_table_id = resource.aws_route_table.route_table_public.id
}

resource "aws_eip" "eip" {
  count = length(resource.aws_subnet.subnet_public.*.id)
  vpc = true

  tags = {
    Name = "${format("${var.user_name}-ng%04d", count.index + 1)}-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = length(resource.aws_subnet.subnet_public.*.id)
  allocation_id = resource.aws_eip.eip.*.id[count.index]
  subnet_id     = resource.aws_subnet.subnet_public.*.id[count.index]

  tags = {
    Name = format("${var.user_name}-ng%04d", count.index + 1)
  }
}

resource "aws_route_table" "route_table_private" {
  count = length(resource.aws_subnet.subnet_public.*.id)
  vpc_id = resource.aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = resource.aws_nat_gateway.nat_gateway.*.id[count.index]
  }

  tags = {
    Name = format("${var.user_name}-rt-private%04d", count.index + 1)
  }
}

resource "aws_route_table_association" "route_table_association_private" {
  count          = length(resource.aws_subnet.subnet_private.*.id) + length(resource.aws_subnet.subnet_web.*.id) + length(resource.aws_subnet.subnet_db.*.id) + length(resource.aws_subnet.subnet_cache.*.id)
  subnet_id      = concat(resource.aws_subnet.subnet_private.*.id, resource.aws_subnet.subnet_web.*.id, resource.aws_subnet.subnet_db.*.id, resource.aws_subnet.subnet_cache.*.id)[count.index]
  route_table_id = resource.aws_route_table.route_table_private.*.id[count.index % length(resource.aws_subnet.subnet_public.*.id)]
}
