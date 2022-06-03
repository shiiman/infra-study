terraform {
    required_version = ">= 1.1.9"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "4.10.0"
        }
    }
}

provider "aws" {
    region = "ap-northeast-1"
}

variable "user_name" { type = string }
