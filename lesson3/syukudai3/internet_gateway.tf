/**
 * Internet Gateway作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
 */
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-ig"
  }
}
