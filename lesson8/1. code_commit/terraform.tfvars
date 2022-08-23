// TODO: ユーザ名設定.
user_name = [ユーザ名]

// subnet
availability_zones         = ["ap-northeast-1a", "ap-northeast-1c"]
subnet_public_cidr_blocks  = ["172.16.0.0/24", "172.16.1.0/24"]
subnet_private_cidr_blocks = ["172.16.10.0/24", "172.16.11.0/24"]

// 社内IP
company_ip = [
  // TODO: 会社のIP.
]

// TODO: route53で設定しているhostを指定.
route53_host_name = ""

ecs_task_iam_role_settings = {
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
  assume_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

ecs_task_execution_iam_role_settings = {
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
