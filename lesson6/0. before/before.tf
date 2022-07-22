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

resource "aws_security_group" "sg_app" {
  name   = "${var.user_name}-app-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-app-sg"
  }
}

output "sg_app_id" {
  value = aws_security_group.sg_app.id
}

resource "aws_security_group_rule" "security_group_rule_egress_app" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = resource.aws_security_group.sg_app.id
}

resource "aws_security_group" "sg_lb" {
  name   = "${var.user_name}-lb-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-lb-sg"
  }
}

output "sg_lb_id" {
  value = aws_security_group.sg_lb.id
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

# lbからappへのhttp
resource "aws_security_group_rule" "security_group_rule_lb_to_app_http" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_lb.id
  source_security_group_id = resource.aws_security_group.sg_app.id
}

# lbからappへのhttp
resource "aws_security_group_rule" "security_group_rule_app_from_lb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_app.id
  source_security_group_id = resource.aws_security_group.sg_lb.id
}

resource "aws_lb" "application_lb" {
  name                       = "${var.user_name}-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [resource.aws_security_group.sg_lb.id]
  subnets                    = resource.aws_subnet.subnet_public.*.id
}

output "application_lb_id" {
  value = aws_lb.application_lb.id
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

resource "aws_security_group" "sg_cache" {
  name   = "${var.user_name}-cache-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-cache-sg"
  }
}

# appからcacheへのredis
resource "aws_security_group_rule" "security_group_rule_app_to_cache_redis" {
  type                     = "egress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_app.id
  source_security_group_id = resource.aws_security_group.sg_cache.id
}

# appからcacheへのredis
resource "aws_security_group_rule" "security_group_rule_cache_from_app_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_cache.id
  source_security_group_id = resource.aws_security_group.sg_app.id
}

resource "aws_elasticache_subnet_group" "elasticache_subnet_group" {
  name       = "${var.user_name}-esg"
  subnet_ids = resource.aws_subnet.subnet_private.*.id
}

variable "redis_cluster_parameter" { type = map(string) }

resource "aws_elasticache_parameter_group" "parameter_group" {
  name   = "${var.user_name}-epg"
  family = "redis5.0"

  dynamic "parameter" {
    for_each = var.redis_cluster_parameter

    content {
      name  = parameter.key
      value = parameter.value
    }
  }
}

resource "aws_elasticache_replication_group" "elasticache_replication_group" {
  replication_group_id          = "${var.user_name}-cache0001"
  replication_group_description = "Managed by Terraform"
  node_type                     = "cache.t2.micro"
  engine                        = "redis"
  engine_version                = "5.0.6"
  port                          = "6379"
  subnet_group_name             = resource.aws_elasticache_subnet_group.elasticache_subnet_group.name
  parameter_group_name          = resource.aws_elasticache_parameter_group.parameter_group.id
  security_group_ids            = [resource.aws_security_group.sg_cache.id]
}

output "elasticache_replication_group_id" {
  value = aws_elasticache_replication_group.elasticache_replication_group.id
}

output "elasticache_replication_group_primary_endpoint_address" {
  value = aws_elasticache_replication_group.elasticache_replication_group.primary_endpoint_address
}

resource "aws_security_group" "sg_db" {
  name   = "${var.user_name}-db-sg"
  vpc_id = resource.aws_vpc.vpc.id

  tags = {
    Name = "${var.user_name}-db-sg"
  }
}

# appからdbへのmysql
resource "aws_security_group_rule" "security_group_rule_app_to_db_mysql" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_app.id
  source_security_group_id = resource.aws_security_group.sg_db.id
}

# appからdbへのmysql
resource "aws_security_group_rule" "security_group_rule_db_from_app_mysql" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_db.id
  source_security_group_id = resource.aws_security_group.sg_app.id
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.user_name}-rdssg"
  subnet_ids = resource.aws_subnet.subnet_private.*.id
}

variable "db_parameter" { type = map(string) }

resource "aws_db_parameter_group" "parameter_group" {
  name   = "${var.user_name}-rdspg"
  family = "aurora-mysql5.7"

  dynamic "parameter" {
    for_each = var.db_parameter

    content {
      name  = parameter.key
      value = parameter.value
    }
  }
}

variable "rds_cluster_parameter" { type = map(string) }

resource "aws_rds_cluster_parameter_group" "cluster_parameter_group" {
  name   = "${var.user_name}-rdscpg"
  family = "aurora-mysql5.7"

  dynamic "parameter" {
    for_each = var.rds_cluster_parameter

    content {
      name  = parameter.key
      value = parameter.value
    }
  }
}

variable "rds_master_password" {}

resource "aws_rds_cluster" "rds_cluster" {
  cluster_identifier              = "${var.user_name}-db0001"
  db_subnet_group_name            = resource.aws_db_subnet_group.db_subnet_group.name
  db_cluster_parameter_group_name = resource.aws_rds_cluster_parameter_group.cluster_parameter_group.name
  engine                          = "aurora-mysql"
  engine_version                  = "5.7.mysql_aurora.2.08.2"
  master_username                 = "root"
  master_password                 = var.rds_master_password
  availability_zones              = var.availability_zones
  vpc_security_group_ids          = [resource.aws_security_group.sg_db.id]
  skip_final_snapshot             = true

  lifecycle {
    ignore_changes = [availability_zones]
  }
}

output "rds_cluster_id" {
  value = aws_rds_cluster.rds_cluster.id
}

output "rds_cluster_endpoint" {
  value = aws_rds_cluster.rds_cluster.endpoint
}

output "rds_cluster_reader_endpoint" {
  value = aws_rds_cluster.rds_cluster.reader_endpoint
}

output "rds_cluster_cluster_identifier" {
  value = aws_rds_cluster.rds_cluster.cluster_identifier
}

resource "aws_rds_cluster_instance" "rds_cluster_instance" {
  count                        = 2
  identifier                   = format("${var.user_name}-db01%02d", count.index + 1)
  cluster_identifier           = resource.aws_rds_cluster.rds_cluster.id
  instance_class               = "db.t2.small"
  engine                       = "aurora-mysql"
  engine_version               = "5.7.mysql_aurora.2.08.2"
  db_parameter_group_name      = resource.aws_db_parameter_group.parameter_group.name
}
