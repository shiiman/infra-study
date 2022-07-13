variable "availability_zones" { type = list(string) }
variable "subnet_public_cidr_blocks" { type = list(string) }
variable "subnet_private_cidr_blocks" { type = list(string) }

module "before" {
  source = "github.com/shiiman/infra-study//lesson4/0. before"

  availability_zones         = var.availability_zones
  subnet_public_cidr_blocks  = var.subnet_public_cidr_blocks
  subnet_private_cidr_blocks = var.subnet_private_cidr_blocks
  user_name                  = var.user_name
}
