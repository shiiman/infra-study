// TODO: 使用するGCPプロジェクトIDを指定
project_id = ""

// ★ 自分の名前に書き換えること
//   この名前が、push するブランチ名にもなります
user_name = "shiiman"

// subnet
subnet_public_cidr  = "172.16.0.0/24"
subnet_private_cidr = "172.16.10.0/24"

// TODO: Cloud DNS のマネージドゾーン名を指定
dns_zone_name = ""

// Googleに貸し出すレンジ
private_service_cidr = "172.16.192.0/20"
