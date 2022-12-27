resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

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
    Name = format("${var.user_name}-public%1d", count.index + 1)
  }
}

resource "aws_subnet" "subnet_private" {
  count             = length(var.subnet_private_cidr_blocks)
  vpc_id            = resource.aws_vpc.vpc.id
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  cidr_block        = var.subnet_private_cidr_blocks[count.index]

  tags = {
    Name = format("${var.user_name}-private%1d", count.index + 1)
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-ig"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = resource.aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = resource.aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${var.user_name}-rt"
  }
}

resource "aws_route_table_association" "route_table_association_public" {
  count          = length(resource.aws_subnet.subnet_public.*.id)
  subnet_id      = resource.aws_subnet.subnet_public.*.id[count.index]
  route_table_id = resource.aws_route_table.route_table.id
}
