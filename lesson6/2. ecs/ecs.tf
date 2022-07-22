/**
 * ECS作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster
 */
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.user_name}-ecs-cluster"
}

data "aws_ecr_image" "ecr_image_app" {
  repository_name = resource.aws_ecr_repository.ecr_repository.name
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

  // TODO:
  //task_role_arn            = var.ecs_task_definition_variables["task_role_arn"]
  //execution_role_arn       = var.ecs_task_definition_variables["execution_role_arn"]

  container_definitions    = <<TASK_DEFINITION
[
  {
    "name": "app",
    "image": "${resource.aws_ecr_repository.ecr_repository.repository_url}@${data.aws_ecr_image.ecr_image_app.image_digest}",
    "portMappings": [
      {
        "containerPort": 8080,
        "hostPort": 80,
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
  name                   = "${var.user_name}-app-ecs-service"
  cluster                = resource.aws_ecs_cluster.ecs_cluster.arn
  task_definition        = resource.aws_ecs_task_definition.ecs_task_definition.arn
  desired_count          = 1
  platform_version       = "1.4.0"
  enable_execute_command = true

  load_balancer {
    target_group_arn = module.before.lb_target_group_arn
    container_name   = "app"
    container_port   = 80
  }

  network_configuration {
    subnets          = split(",", module.before.private_subnet_ids)
    security_groups  = [module.before.sg_app_id]
  }
}
