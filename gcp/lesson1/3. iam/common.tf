terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  required_version = ">= 1.9.0"

  /**
   * tfstateの保存先
   * バケットは Step1 で gcloud コマンドを使って作成済み(Terraform管理外)
   * backendブロックには変数が使えないため、バケット名は直接書く必要がある
   * ★ bucket を自分の環境に合わせて書き換えること
   *    例: my-project-tfstate-yamada-taro
   */
  backend "gcs" {
    bucket = "[プロジェクトID]-tfstate-[自分の名前]"
    prefix = "lesson1"
  }
}

provider "google" {
  project = var.project_id
  region  = "asia-northeast1"
}

variable "project_id" {}
variable "user_name" {}
