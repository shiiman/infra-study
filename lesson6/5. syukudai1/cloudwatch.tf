/**
 * Cloud Watch log group作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
 */
resource "aws_cloudwatch_log_group" "cloud_watch_log_group" {
  name = "/aws/ecs/${var.user_name}/app"
}
