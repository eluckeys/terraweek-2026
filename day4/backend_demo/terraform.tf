terraform {
  required_version = ">= 1.15"

  backend "s3" {
    bucket       = "saurabh-terraweek-state-97848a0b"
    key          = "day04/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}
