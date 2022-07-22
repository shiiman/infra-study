/**
 * ECR作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecrpublic_repository
 */
resource "aws_ecr_repository" "ecr_repository" {
  name = "${var.user_name}-ecr"
}
