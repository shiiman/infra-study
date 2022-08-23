/**
 * Code Commit リポジトリ作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codecommit_repository
 */
resource "aws_codecommit_repository" "codecommit_repository" {
  repository_name = "${var.user_name}-repo"
}
