# ============================================================
# terraform.tf — provider & backend configuration
# ============================================================
# Provider version requirements:
#   hashicorp/aws  : >= 6.42  (required by eks module v21.x)
#   hashicorp/tls  : >= 4.0   (required by eks module v21.x)
#   hashicorp/time : >= 0.9   (required by eks module v21.x)
#   hashicorp/http : >= 3.0   (for bastion my-ip lookup)
# ============================================================

terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.42"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # -------------------------------------------------------
  # Uncomment and configure for remote state (recommended):
  # -------------------------------------------------------
  # backend "s3" {
  #   bucket         = "<your-state-bucket>"
  #   key            = "silver-stack/terraform/aws/eks-kodekloud/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "<your-lock-table>"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "silver-stack"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
