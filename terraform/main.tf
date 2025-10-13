# Banking Infrastructure - EKS Cluster with Terraform
# Author: DevOps Team
# Version: 1.0
# Description: Complete EKS infrastructure for banking applications

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
    # Configure your S3 backend for state management
    # bucket = "banking-terraform-state-bucket"
    # key    = "eks/terraform.tfstate"
    # region = "us-west-2"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "banking-k8s"
      Owner       = "DevOps"
      CreatedBy   = "Terraform"
      CostCenter  = "Banking-IT"
    }
  }
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = "${var.environment}-banking-eks"

  common_tags = {
    Environment = var.environment
    Project     = "banking-k8s"
    ManagedBy   = "Terraform"
  }
}
