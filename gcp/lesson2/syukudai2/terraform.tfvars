// TODO: 使用するGCPプロジェクトIDを指定
project_id = ""

// ★ 自分の名前に書き換えること
user_name = "shiiman"

// subnet
subnet_public_cidr  = "172.16.0.0/24"
subnet_private_cidr = "172.16.10.0/24"

// 宿題2-1で追加したサブネット
subnet_web_cidr   = "172.16.20.0/22"
subnet_db_cidr    = "172.16.40.0/24"
subnet_cache_cidr = "172.16.50.0/24"

// 宿題2-2で追加した大阪リージョンのサブネット
subnet_osaka_public_cidr  = "172.16.100.0/24"
subnet_osaka_private_cidr = "172.16.110.0/24"
