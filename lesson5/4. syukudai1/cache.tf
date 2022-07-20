/**
 * elasticache subnet group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group
 */
resource "aws_elasticache_subnet_group" "elasticache_subnet_group" {
  name       = "${var.user_name}-esg"
  subnet_ids = split(",", module.before.private_subnet_ids)
}

variable "redis_cluster_parameter" { type = map(string) }

/**
 * elasticache parameter group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_parameter_group
 */
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

/**
 * elasticache replication group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group
 */
resource "aws_elasticache_replication_group" "aws_elasticache_replication_group" {
  replication_group_id          = "${var.user_name}-cache0001"
  replication_group_description = "Managed by Terraform"
  node_type                     = "cache.t2.micro"
  engine                        = "redis"
  engine_version                = "5.0.6"
  port                          = "6379"
  number_cache_clusters         = "2"
  automatic_failover_enabled    = true
  subnet_group_name             = resource.aws_elasticache_subnet_group.elasticache_subnet_group.name
  parameter_group_name          = resource.aws_elasticache_parameter_group.parameter_group.id
  security_group_ids            = [resource.aws_security_group.sg_cache.id]
}
