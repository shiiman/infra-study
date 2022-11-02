variable "availability_zones" { type = list(string) }
variable "subnet_public_cidr_blocks" { type = list(string) }
variable "subnet_private_cidr_blocks" { type = list(string) }
variable "company_ip" { type = list(string) }
variable "route53_host_name" {}
variable "ecs_task_iam_role_settings" { type = map(string) }
variable "ecs_task_execution_iam_role_settings" { type = map(string) }

module "before" {
  source = "github.com/shiiman/infra-study//lesson8/0. before"

  availability_zones                   = var.availability_zones
  subnet_public_cidr_blocks            = var.subnet_public_cidr_blocks
  subnet_private_cidr_blocks           = var.subnet_private_cidr_blocks
  user_name                            = var.user_name
  company_ip                           = var.company_ip
  route53_host_name                    = var.route53_host_name
  ecs_task_iam_role_settings           = var.ecs_task_iam_role_settings
  ecs_task_execution_iam_role_settings = var.ecs_task_execution_iam_role_settings
}
