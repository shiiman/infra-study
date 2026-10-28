// TODO: 使用するGCPプロジェクトIDを指定
project_id = ""

// ★ 自分の名前に書き換えること
user_name = "yamada-taro"

// subnet
subnet_public_cidr  = "172.16.0.0/24"
subnet_private_cidr = "172.16.10.0/24"

// 勉強会で共有するCloud DNSのゾーン名（ドメイン名ではない）
dns_zone_name = "infra-study-gcp"

// 限定公開サービスアクセス用に切り出すレンジ
// Googleに貸し出すレンジ。小さすぎるとCloud SQLが作れない
private_service_cidr = "172.16.192.0/20"
