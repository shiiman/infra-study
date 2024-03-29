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

/**
 * endpoint作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint
 */
resource "aws_vpc_endpoint" "endpoint" {
  vpc_id          = resource.aws_vpc.vpc.id
  service_name    = "com.amazonaws.ap-northeast-1.s3"
  route_table_ids = concat(resource.aws_route_table.route_table_public.*.id, resource.aws_route_table.route_table_private.*.id)
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
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = resource.aws_security_group.sg_lb.id
  source_security_group_id = resource.aws_security_group.sg_app.id
}

# lbからappへのhttp
resource "aws_security_group_rule" "security_group_rule_app_from_lb_http" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
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

output "lb_arn" {
  value = aws_lb.application_lb.arn
}

resource "aws_lb_target_group" "lb_target_group_blue" {
  name                 = "${var.user_name}-lb-tg-blue"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = resource.aws_vpc.vpc.id
}

output "lb_target_group_blue_arn" {
  value = aws_lb_target_group.lb_target_group_blue.arn
}

output "lb_target_group_blue_name" {
  value = aws_lb_target_group.lb_target_group_blue.name
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = resource.aws_lb.application_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = resource.aws_lb_target_group.lb_target_group_blue.arn
  }

  lifecycle {
    ignore_changes = [default_action.0.target_group_arn]
  }
}

output "lb_listener_arn" {
  value = aws_lb_listener.lb_listener.arn
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

output "acm_certificate_arn" {
  value = aws_acm_certificate.acm_certificate.arn
}

// ECSタスクロール ===============================================================

variable "ecs_task_iam_role_settings" { type = map(string) }

/**
 * iam role作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy
 */
resource "aws_iam_role" "ecs_task_iam_role" {
  name               = "Cloud9-${var.user_name}-ecs-task-iam-role"
  assume_role_policy = var.ecs_task_iam_role_settings["assume_role_policy"]
}

/**
 * iam policy作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
 */
resource "aws_iam_policy" "ecs_task_iam_policy" {
  name   = "${var.user_name}-ecs-task-iam-role-policy"
  policy = var.ecs_task_iam_role_settings["assume_policy"]
}

/**
 * iam role policy attachment作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
 */
resource "aws_iam_role_policy_attachment" "ecs_task_iam_role_policy_attachment" {
  role       = resource.aws_iam_role.ecs_task_iam_role.id
  policy_arn = resource.aws_iam_policy.ecs_task_iam_policy.arn
}

// ECSタスクロール ===============================================================

// ECSタスク実行ロール ===============================================================

variable "ecs_task_execution_iam_role_settings" { type = map(string) }

resource "aws_iam_role" "ecs_task_execution_iam_role" {
  name               = "Cloud9-${var.user_name}-ecs-task-execution-iam-role"
  assume_role_policy = var.ecs_task_execution_iam_role_settings["assume_role_policy"]
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_iam_role_policy_attachment" {
  role       = resource.aws_iam_role.ecs_task_execution_iam_role.id
  policy_arn = var.ecs_task_execution_iam_role_settings["policy_arn"]
}

// ECSタスク実行ロール ===============================================================

/**
 * ECS作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster
 */
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.user_name}-ecs-cluster"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs_cluster.name
}

data "aws_ecr_repository" "ecr_repository" {
  name = "infra-study-ecr"
}

data "aws_ecr_image" "ecr_image_app" {
  repository_name = "infra-study-ecr"
  image_tag       = "app"
}

/**
 * ECS作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
 */
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "${var.user_name}-app-ecs-td"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  task_role_arn            = resource.aws_iam_role.ecs_task_iam_role.arn
  execution_role_arn       = resource.aws_iam_role.ecs_task_execution_iam_role.arn

  container_definitions    = <<TASK_DEFINITION
[
  {
    "name": "app",
    "image": "${data.aws_ecr_repository.ecr_repository.repository_url}@${data.aws_ecr_image.ecr_image_app.image_digest}",
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 8080,
        "protocol": "tcp"
      }
    ]
  }
]
TASK_DEFINITION
}

/**
 * ECS Service作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service
 */
resource "aws_ecs_service" "ecs_service" {
  name                       = "${var.user_name}-app-ecs-service"
  cluster                    = resource.aws_ecs_cluster.ecs_cluster.arn
  task_definition            = resource.aws_ecs_task_definition.ecs_task_definition.arn
  desired_count              = 1
  launch_type                = "FARGATE"
  platform_version           = "1.4.0"
  enable_execute_command     = true

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    target_group_arn = resource.aws_lb_target_group.lb_target_group_blue.arn
    container_name   = "app"
    container_port   = 8080
  }

  network_configuration {
    subnets          = resource.aws_subnet.subnet_private.*.id
    security_groups  = [resource.aws_security_group.sg_app.id]
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition,
      load_balancer,
    ]
  }
}

output "ecs_service_name" {
  value = aws_ecs_service.ecs_service.name
}
