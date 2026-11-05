terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
  }

  required_version = ">= 1.17.1"

  /**
   * tfstateの保存先
   * ★ bucket を自分の環境に合わせて書き換えること
   *    例: my-project-tfstate-yamada-taro
   */
  backend "gcs" {
    bucket = "[プロジェクトID]-tfstate-[自分の名前]"
    prefix = "lesson6"
  }
}

provider "google" {
  project = var.project_id
  region  = "asia-northeast1"
}

variable "project_id" {}
variable "user_name" {}
