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

redis_cluster_parameter = {
  cluster-enabled  = "no"
  maxmemory-policy = "volatile-lru"
  timeout          = "120"
  tcp-keepalive    = "60"
}

db_parameter = {
  slow_query_log  = "1"
  long_query_time = "0.5"
  max_connections = "16000"
  sql_mode        = "ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"
}

rds_cluster_parameter = {
  character_set_client       = "utf8mb4"
  character_set_connection   = "utf8mb4"
  character_set_database     = "utf8mb4"
  character_set_filesystem   = "utf8mb4"
  character_set_results      = "utf8mb4"
  character_set_server       = "utf8mb4"
  collation_connection       = "utf8mb4_unicode_ci"
  collation_server           = "utf8mb4_unicode_ci"
  time_zone                  = "Asia/Tokyo"
}

// TODO: RDS rootパスワード設定.
rds_master_password = [ROOT_PASSWORD]

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
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
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
  assume_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}
