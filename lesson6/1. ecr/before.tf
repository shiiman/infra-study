variable "availability_zones" { type = list(string) }
variable "subnet_public_cidr_blocks" { type = list(string) }
variable "subnet_private_cidr_blocks" { type = list(string) }
variable "company_ip" { type = list(string) }
variable "route53_host_name" {}
variable "redis_cluster_parameter" { type = list(string) }
variable "db_parameter" { type = list(string) }
variable "rds_cluster_parameter" { type = list(string) }

module "before" {
  source = "github.com/shiiman/infra-study//lesson6/0. before"

  availability_zones         = var.availability_zones
  subnet_public_cidr_blocks  = var.subnet_public_cidr_blocks
  subnet_private_cidr_blocks = var.subnet_private_cidr_blocks
  user_name                  = var.user_name
  company_ip                 = var.company_ip
  route53_host_name          = var.route53_host_name
  redis_cluster_parameter    = var.redis_cluster_parameter
  db_parameter               = var.db_parameter
  rds_cluster_parameter      = var.rds_cluster_parameter
}
