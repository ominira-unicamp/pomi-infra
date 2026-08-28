terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
    vercel = {
      source  = "vercel/vercel"
      version = "~> 4.8"
    }
  }
}
