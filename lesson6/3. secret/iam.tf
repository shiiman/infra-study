// ECSタスクロール ===============================================================

variable "ecs_task_iam_role_settings" { type = map(string) }

/**
 * iam role作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy
 */
resource "aws_iam_role" "ecs_task_iam_role" {
  name               = "Cloud9-${var.user_name}-ecs-task-iam-role"
  assume_role_policy = var.ecs_task_iam_role_settings["assume_role_policy"]
}

/**
 * iam policy作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy
 */
resource "aws_iam_policy" "ecs_task_iam_policy" {
  name   = "${var.user_name}-ecs-task-iam-role-policy"
  policy = var.ecs_task_iam_role_settings["assume_policy"]
}

/**
 * iam role policy attachment作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
 */
resource "aws_iam_role_policy_attachment" "ecs_task_iam_role_policy_attachment" {
  role       = resource.aws_iam_role.ecs_task_iam_role.id
  policy_arn = resource.aws_iam_policy.ecs_task_iam_policy.arn
}

// ECSタスクロール ===============================================================

// ECSタスク実行ロール ===============================================================

variable "ecs_task_execution_iam_role_settings" { type = map(string) }

resource "aws_iam_role" "ecs_task_execution_iam_role" {
  name               = "Cloud9-${var.user_name}-ecs-task-execution-iam-role"
  assume_role_policy = var.ecs_task_execution_iam_role_settings["assume_role_policy"]
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_iam_role_policy_attachment1" {
  role       = resource.aws_iam_role.ecs_task_execution_iam_role.id
  policy_arn = var.ecs_task_execution_iam_role_settings["policy_arn"]
}

resource "aws_iam_policy" "ecs_task_execution_iam_policy" {
  name   = "${var.user_name}-ecs-task-execution-iam-role-policy"
  policy = var.ecs_task_execution_iam_role_settings["assume_policy"]
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_iam_role_policy_attachment2" {
  role       = resource.aws_iam_role.ecs_task_execution_iam_role.id
  policy_arn = resource.aws_iam_policy.ecs_task_execution_iam_policy.arn
}

// ECSタスク実行ロール ===============================================================
