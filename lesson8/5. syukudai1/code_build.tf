# ロール作成 =====================================================

variable "codebuild_role_settings" { type = map(string) }

resource "aws_iam_role" "codebuild_iam_role" {
  name               = "Cloud9-${var.user_name}-codebuild-iam-role"
  assume_role_policy = var.codebuild_role_settings["assume_role_policy"]
}

resource "aws_iam_policy" "codebuild_iam_policy" {
  name   = "${var.user_name}-codebuild-iam-role-policy"
  policy = var.codebuild_role_settings["assume_policy"]
}

resource "aws_iam_role_policy_attachment" "codebuild_iam_role_policy_attachment" {
  role       = resource.aws_iam_role.codebuild_iam_role.id
  policy_arn = resource.aws_iam_policy.codebuild_iam_policy.arn
}

# =============================================================

resource "aws_security_group" "sg_codebuild" {
  name   = "${var.user_name}-codebuild-sg"
  vpc_id = module.before.vpc_id

  tags = {
    Name = "${var.user_name}-codebuild-sg"
  }
}

resource "aws_security_group_rule" "security_group_rule_egress_codebuild" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = resource.aws_security_group.sg_codebuild.id
}

resource "aws_ecr_repository" "ecr_repository" {
  name = "${var.user_name}-ecr"
}

/**
 * Code Build 作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project
 */
resource "aws_codebuild_project" "codebuild_project" {
  name          = "${var.user_name}-codebuild"
  service_role  = resource.aws_iam_role.codebuild_iam_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "REPOSITORY"
      value = resource.aws_ecr_repository.ecr_repository.repository_url
    }
  }

  source {
    type = "CODEPIPELINE"
  }

  vpc_config {
    vpc_id             = module.before.vpc_id
    subnets            = split(",", module.before.private_subnet_ids)
    security_group_ids = [resource.aws_security_group.sg_codebuild.id]
  }
}

# =============================================================

resource "aws_s3_bucket" "codebuild_artifacts_bucket" {
  bucket = "${var.user_name}-codebuild-artifacts-bucket"
}

resource "aws_s3_bucket_acl" "s3_bucket_codebuild_artifacts_bucket_acl" {
  bucket = resource.aws_s3_bucket.codebuild_artifacts_bucket.id
  acl    = "private"
}

resource "aws_codebuild_project" "codebuild_project_deploy" {
  name           = "${var.user_name}-deploy"
  service_role   = resource.aws_iam_role.codebuild_iam_role.arn
  source_version = "refs/heads/master"

  artifacts {
    type      = "S3"
    location  = resource.aws_s3_bucket.codebuild_artifacts_bucket.bucket
    name      = "app.zip"
    packaging = "ZIP"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  source {
    type      = "CODECOMMIT"
    location  = resource.aws_codecommit_repository.codecommit_repository.clone_url_http
    buildspec = "buildspec_deploy.yml"
  }

  vpc_config {
    vpc_id             = module.before.vpc_id
    subnets            = split(",", module.before.private_subnet_ids)
    security_group_ids = [resource.aws_security_group.sg_codebuild.id]
  }
}

resource "aws_vpc_endpoint" "endpoint_codecommit" {
  vpc_id              = module.before.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.ap-northeast-1.codecommit"
  subnet_ids          = split(",", module.before.private_subnet_ids)
  security_group_ids  = [resource.aws_security_group.sg_codebuild.id]
}

resource "aws_vpc_endpoint" "endpoint_git_codecommit" {
  vpc_id              = module.before.vpc_id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.ap-northeast-1.git-codecommit"
  subnet_ids          = split(",", module.before.private_subnet_ids)
  security_group_ids  = [resource.aws_security_group.sg_codebuild.id]
}
