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
  count = length(resource.aws_subnet.subnet_private.*.id)
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
  count          = length(resource.aws_subnet.subnet_private.*.id)
  subnet_id      = concat(resource.aws_subnet.subnet_private.*.id)[count.index]
  route_table_id = resource.aws_route_table.route_table_private.*.id[count.index % length(resource.aws_subnet.subnet_private.*.id)]
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  value = join(",", aws_subnet.subnet_public.*.id)
}

output "private_subnet_ids" {
  value = join(",", aws_subnet.subnet_private.*.id)
}

resource "aws_security_group" "sg_web_instance" {
  name   = "${var.user_name}-web-instance-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-web-instance-sg"
  }
}

resource "aws_security_group_rule" "security_group_rule_egress_web_instance" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = resource.aws_security_group.sg_web_instance.id
}

variable "iam_instance_profile" {}

resource "aws_instance" "web_instance" {
  count                       = 1
  ami                         = "ami-02c3627b04781eada"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [resource.aws_security_group.sg_web_instance.id]
  subnet_id                   = resource.aws_subnet.subnet_private.*.id[count.index % length(resource.aws_subnet.subnet_private.*.id)]
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile

  tags = {
    Name = format("${var.user_name}-web-instance%04d", count.index + 1)
  }

  volume_tags = {
    Name = "${format("${var.user_name}-web-instance%04d", count.index + 1)}-ebs"
  }
}

resource "aws_security_group" "sg_lb" {
  name   = "${var.user_name}-lb-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-lb-sg"
  }
}

variable "company_ip" { type = list(string) }

# 会社からlbへのhttps
resource "aws_security_group_rule" "security_group_rule_lb_from_company_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.company_ip
  security_group_id = resource.aws_security_group.sg_lb.id
}

# lbからwebインスタンスへのhttp
resource "aws_security_group_rule" "security_group_rule_lb_to_web_instance_http" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_lb.id
  source_security_group_id = resource.aws_security_group.sg_web_instance.id
}

# lbからwebインスタンスへのhttp
resource "aws_security_group_rule" "security_group_rule_web_instance_from_lb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_web_instance.id
  source_security_group_id = resource.aws_security_group.sg_lb.id
}
resource "aws_lb" "application_lb" {
  name                       = "${var.user_name}-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [resource.aws_security_group.sg_lb.id]
  subnets                    = resource.aws_subnet.subnet_public.*.id
}

resource "aws_lb_target_group" "lb_target_group" {
  name                 = "${var.user_name}-lb-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = resource.aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "lb_target_group_attachment" {
  count            = length(resource.aws_instance.web_instance.*.id)
  target_group_arn = resource.aws_lb_target_group.lb_target_group.arn
  target_id        = resource.aws_instance.web_instance.*.id[count.index]
  port             = 80
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = resource.aws_lb.application_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = resource.aws_lb_target_group.lb_target_group.arn
  }
}

variable "route53_host_name" {}

data "aws_route53_zone" "public" {
  name         = var.route53_host_name
  private_zone = false
}

resource "aws_route53_record" "route53_record" {
  name    = "${var.user_name}.${data.aws_route53_zone.public.name}"
  zone_id = data.aws_route53_zone.public.zone_id
  type    = "A"

  alias {
    name                   = resource.aws_lb.application_lb.dns_name
    zone_id                = resource.aws_lb.application_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "acm_certificate" {
  domain_name       ="${var.user_name}.${data.aws_route53_zone.public.name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.acm_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = "300"
  type            = each.value.type
  zone_id         = data.aws_route53_zone.public.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.acm_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_record : record.fqdn]
}
