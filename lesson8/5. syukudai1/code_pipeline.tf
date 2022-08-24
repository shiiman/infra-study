# ロール作成 =====================================================

variable "codepipeline_role_settings" { type = map(string) }

resource "aws_iam_role" "codepipeline_iam_role" {
  name               = "Cloud9-${var.user_name}-codepipeline-iam-role"
  assume_role_policy = var.codepipeline_role_settings["assume_role_policy"]
}

resource "aws_iam_policy" "codepipeline_iam_policy" {
  name   = "${var.user_name}-codepipeline-iam-role-policy"
  policy = var.codepipeline_role_settings["assume_policy"]
}

resource "aws_iam_role_policy_attachment" "codepipeline_iam_role_policy_attachment" {
  role       = resource.aws_iam_role.codepipeline_iam_role.id
  policy_arn = resource.aws_iam_policy.codepipeline_iam_policy.arn
}

# =============================================================

resource "aws_s3_bucket" "codepipeline_artifacts_bucket" {
  bucket = "${var.user_name}-codepipeline-artifacts-bucket"
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = resource.aws_s3_bucket.codepipeline_artifacts_bucket.id
  acl    = "private"
}

/**
 * Code Pipeline 作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline
 */
resource "aws_codepipeline" "codepipeline" {
  name     = "${var.user_name}-codepipeline"
  role_arn = resource.aws_iam_role.codepipeline_iam_role.arn

  artifact_store {
    type     = "S3"
    location = resource.aws_s3_bucket.codepipeline_artifacts_bucket.bucket
  }

  // Source
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        S3Bucket             = resource.aws_s3_bucket.codebuild_artifacts_bucket.bucket
        S3ObjectKey          = "app.zip"
        PollForSourceChanges = true
      }
    }
  }

  // Build
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = resource.aws_codebuild_project.codebuild_project.name
      }
    }
  }

  // Deploy
  stage {
    name = "Deploy"

    # web
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["BuildArtifact"]

      configuration = {
        ApplicationName                = resource.aws_codedeploy_app.codedeploy_app.name
        DeploymentGroupName            = resource.aws_codedeploy_deployment_group.codedeploy_deployment_group.deployment_group_name
        TaskDefinitionTemplateArtifact = "BuildArtifact"
        AppSpecTemplatePath            = "codedeploy/appspec.yml"
        AppSpecTemplateArtifact        = "BuildArtifact"
        TaskDefinitionTemplatePath     = "codedeploy/taskdef.json"
      }
    }
  }
}
