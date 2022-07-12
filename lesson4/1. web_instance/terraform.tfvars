user_name = "shiiman"

// subnet
availability_zones         = ["ap-northeast-1a", "ap-northeast-1c"]
subnet_public_cidr_blocks  = ["172.16.0.0/24", "172.16.1.0/24"]
subnet_private_cidr_blocks = ["172.16.10.0/24", "172.16.11.0/24"]

iam_instance_profile = "arn:aws:iam::216399654772:role/AmazonEC2RoleforSSM"
