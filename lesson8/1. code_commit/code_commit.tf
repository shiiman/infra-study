resource "aws_codecommit_repository" "codecommit_repository" {
  repository_name = "${var.user_name}-repo"
}
