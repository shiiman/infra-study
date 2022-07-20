/**
 * db subnet group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group
 */
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.user_name}-rdssg"
  subnet_ids = split(",", module.before.private_subnet_ids)
}

variable "db_parameter" { type = map(string) }

/**
 * db parameter group作成
 * https://www.terraform.io/docs/providers/aws/r/db_parameter_group.html
 */
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

/**
 * ds cluster parameter group作成
 * https://www.terraform.io/docs/providers/aws/r/rds_cluster_parameter_group.html
 */
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

/**
 * rds cluster作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster
 */
resource "aws_rds_cluster" "rds_cluster" {
  cluster_identifier              = "${var.user_name}-db0001"
  db_subnet_group_name            = resource.aws_db_subnet_group.db_subnet_group.name
  db_cluster_parameter_group_name = resource.aws_rds_cluster_parameter_group.cluster_parameter_group.name
  engine                          = "aurora-mysql"
  engine_version                  = "5.7.mysql_aurora.2.08.2"
  master_username                 = "root"
  master_password                 = [ROOT_PASSWORD]
  availability_zones              = var.availability_zones
  vpc_security_group_ids          = [resource.aws_security_group.sg_db.id]
}

/**
 * rds cluster instance作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance
 */
resource "aws_rds_cluster_instance" "rds_cluster_instance" {
  count                        = 2
  identifier                   = format("${var.user_name}-db01%02d", count.index + 1)
  cluster_identifier           = resource.aws_rds_cluster.rds_cluster.id
  instance_class               = "db.t2.micro"
  engine                       = "aurora-mysql"
  engine_version               = "5.7.mysql_aurora.2.08.2"
  db_parameter_group_name      = resource.aws_db_parameter_group.parameter_group.name
}
