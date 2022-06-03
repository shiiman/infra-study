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

variable "subnet_availability_zones" { type = list(string) }
variable "subnet_public_cidr_blocks" { type = list(string) }

/**
 * subnet作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
 */
resource "aws_subnet" "subnet_public" {
  count                   = 2
  vpc_id                  = resource.aws_vpc.vpc.id
  cidr_block              = ["172.16.0.0/24", "172.16.1.0/24"]
  availability_zone       = ["ap-northeast-1a", "ap-northeast-1c"]

  tags = {
    Name = format("${var.user_name}-public-%01d-subnet", count.index + 1)
  }
}
