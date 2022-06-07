user_name = "shiiman"

// subnet
availability_zones         = ["ap-northeast-1a", "ap-northeast-1c"]
subnet_public_cidr_blocks  = ["172.16.0.0/24", "172.16.1.0/24"]
subnet_private_cidr_blocks = ["172.16.10.0/24", "172.16.11.0/24"]
subnet_web_cidr_blocks     = ["172.16.20.0/22", "172.16.24.0/22"]
subnet_db_cidr_blocks      = ["172.16.40.0/24", "172.16.41.0/24"]
subnet_cache_cidr_blocks   = ["172.16.50.0/24", "172.16.51.0/24"]

// 社内IP
company_ip = [
  // TODO: 会社のIP
]
