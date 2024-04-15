provider "aws" {
  region = var.region
  #profile = "sandbox"

}

terraform {
  required_version = "~> 1.7.4"

  required_providers {
    aws = {
      version = ">= 5.42.0"
      source  = "hashicorp/aws"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.4"
    }
  }
  backend "s3" {
    bucket         = "df-terraform-nonprod"
    key            = "environments/prod/ecs-sv-infra-prod.tf"
    region         = "us-east-1"
    dynamodb_table = "df-terraform-nonprod-lock-db"
  }
}

