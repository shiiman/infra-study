terraform {
    required_version = ">= 1.1.9"

  required_providers {
      aws = {
          source  = "hashicorp/aws"
          version = "4.10.0"
      }
}

provider "aws" {
    region = "ap-northeast-1"
}

/**
 * VPC作成
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
 */
resource "aws_vpc" "vpc" {
  cidr_block = "172.16.0.0/16"
}
