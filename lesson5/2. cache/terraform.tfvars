user_name = "shiiman"

// subnet
availability_zones         = ["ap-northeast-1a", "ap-northeast-1c"]
subnet_public_cidr_blocks  = ["172.16.0.0/24", "172.16.1.0/24"]
subnet_private_cidr_blocks = ["172.16.10.0/24", "172.16.11.0/24"]

iam_instance_profile = "AmazonEC2RoleforSSM"

// 社内IP
company_ip = [
  // TODO: 会社のIP
]

// TODO: route53で設定しているhostを指定
route53_host_name = ""

redis_cluster_parameter = {
  cluster-enabled  = "no"
  maxmemory-policy = "volatile-lru"
  timeout          = "120"
  tcp-keepalive    = "60"
}
