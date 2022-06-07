variable "availability_zones" { type = list(string) }
variable "subnet_public_cidr_blocks" { type = list(string) }
variable "subnet_private_cidr_blocks" { type = list(string) }
variable "subnet_web_cidr_blocks" { type = list(string) }
variable "subnet_db_cidr_blocks" { type = list(string) }
variable "subnet_cache_cidr_blocks" { type = list(string) }

/**
 * subnet作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
 */
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

resource "aws_subnet" "subnet_web" {
  count             = length(var.subnet_web_cidr_blocks)
  vpc_id            = resource.aws_vpc.vpc.id
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  cidr_block        = var.subnet_web_cidr_blocks[count.index]

  tags = {
    Name = format("${var.user_name}-web-%01d-subnet", count.index + 1)
  }
}

resource "aws_subnet" "subnet_db" {
  count             = length(var.subnet_db_cidr_blocks)
  vpc_id            = resource.aws_vpc.vpc.id
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  cidr_block        = var.subnet_db_cidr_blocks[count.index]

  tags = {
    Name = format("${var.user_name}-db-%01d-subnet", count.index + 1)
  }
}

resource "aws_subnet" "subnet_cache" {
  count             = length(var.subnet_cache_cidr_blocks)
  vpc_id            = resource.aws_vpc.vpc.id
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  cidr_block        = var.subnet_cache_cidr_blocks[count.index]

  tags = {
    Name = format("${var.user_name}-cache-%01d-subnet", count.index + 1)
  }
}
