// TODO: 使用するGCPプロジェクトIDを指定
project_id = ""

// ★ 自分の名前に書き換えること
user_name = "yamada-taro"

// subnet
subnet_public_cidr  = "172.16.0.0/24"
subnet_private_cidr = "172.16.10.0/24"

// 勉強会で共有するCloud DNSのゾーン名（ドメイン名ではない）
dns_zone_name = "infra-study-gcp"

// 社内IP（公開リポジトリには記載しない）
// TODO: 限定公開の第3回スライドにある社内IPを、コピー先の作業ディレクトリで設定する
company_ip = []
