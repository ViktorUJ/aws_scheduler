variable "region" {
  default = "eu-west-1"
}

variable "resources_prefix" {
  default = "aws_scheduler"
}


provider "aws" {
  region = var.region
}

resource "aws_dynamodb_table" "scheduler" {
  name           = var.resources_prefix
  hash_key       = "id"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "id"
    type = "S"
  }

  lifecycle {
   prevent_destroy = false
  }

  tags = {
    Name = "aws_scheduler"
    project = "infra"
  }
}