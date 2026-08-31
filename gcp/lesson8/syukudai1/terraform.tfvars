// TODO: 使用するGCPプロジェクトIDを指定
project_id = ""

// ★ 自分の名前に書き換えること
user_name = "shiiman"

// subnet
subnet_public_cidr  = "172.16.0.0/24"
subnet_private_cidr = "172.16.10.0/24"

// TODO: Cloud DNS のマネージドゾーン名を指定
dns_zone_name = ""

// Googleに貸し出すレンジ
private_service_cidr = "172.16.192.0/20"

// TODO: 講師が作成した Slack 通知チャンネルの表示名を指定
//   確認: gcloud beta monitoring channels list --format="value(displayName,type)"
notification_channel_name = ""
