terraform {
  required_providers {
    aws = {
      version = "= 5.79.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}
