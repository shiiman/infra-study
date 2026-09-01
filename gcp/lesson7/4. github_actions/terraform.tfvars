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

// TODO: 講師が作成した Cloud Build のリポジトリリンクを指定
//   形式: projects/[プロジェクトID]/locations/asia-northeast1/connections/[接続名]/repositories/[リポジトリ名]
//   確認: gcloud builds repositories list --connection=[接続名] --region=asia-northeast1
cloudbuild_repository = ""

// TODO: 講師が作成した Workload Identity プールのフルリソース名を指定
//   形式: projects/[プロジェクト番号]/locations/global/workloadIdentityPools/[プールID]
//   確認: gcloud iam workload-identity-pools describe [プールID] \
//           --location=global --format="value(name)"
workload_identity_pool_id = ""
