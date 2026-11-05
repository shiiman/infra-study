terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
  }

  required_version = ">= 1.17.1"
}

provider "google" {
  project = var.project_id
  region  = "asia-northeast1"
}

variable "project_id" {}
variable "user_name" {}
