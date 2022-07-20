variable "availability_zones" { type = list(string) }
variable "subnet_public_cidr_blocks" { type = list(string) }
variable "subnet_private_cidr_blocks" { type = list(string) }
variable "iam_instance_profile" {}
variable "company_ip" { type = list(string) }
variable "route53_host_name" {}

module "before" {
  source = "github.com/shiiman/infra-study//lesson5/0. before"

  availability_zones         = var.availability_zones
  subnet_public_cidr_blocks  = var.subnet_public_cidr_blocks
  subnet_private_cidr_blocks = var.subnet_private_cidr_blocks
  user_name                  = var.user_name
  iam_instance_profile       = var.iam_instance_profile
  company_ip                 = var.company_ip
  route53_host_name          = var.route53_host_name
}
