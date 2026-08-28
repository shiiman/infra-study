/**
 * Artifact Registry
 *
 * コンテナイメージの保管場所。AWSのECRに相当する。
 *
 * ★ ECRとの違い ★
 * ECRは「コンテナイメージ専用」だったが、
 * Artifact Registry は format を指定することで
 * Maven / npm / Python / Go / apt / yum なども同じ仕組みで扱える。
 *
 * リポジトリの単位も違う。
 *   ECR                : リポジトリ = イメージ1種類
 *   Artifact Registry  : リポジトリ = 複数のイメージを入れる箱
 *
 * https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository
 */
resource "google_artifact_registry_repository" "app" {
  location      = "asia-northeast1"
  repository_id = "${var.user_name}-repo"
  format        = "DOCKER"
  description   = "インフラ勉強会(GCP) 第5回"

  // 古いイメージを自動で消す
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}

output "repository_url" {
  value = "${google_artifact_registry_repository.app.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}
