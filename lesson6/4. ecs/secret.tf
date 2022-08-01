/**
 * Secretmanager secret作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret
 */
resource "aws_secretsmanager_secret" "secretsmanager_secret" {
  name        = "${var.user_name}-db-secret"
}

locals {
  secret_string = {
    DB_PASS    = var.rds_master_password
    DB_HOST    = module.before.rds_cluster_endpoint
    CACHE_HOST = module.before.elasticache_replication_group_primary_endpoint_address
  }
}

/**
 * Secretmanager secret version作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version
 */
resource "aws_secretsmanager_secret_version" "secretsmanager_secret_version" {
  secret_id     = resource.aws_secretsmanager_secret.secretsmanager_secret.id
  secret_string = jsonencode(locals.secret_string)
}
