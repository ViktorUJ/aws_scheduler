variable "region" {
  default = "eu-north-1"
}

variable "dynamodb_table_name" {
  default = "aws_scheduler"
}


provider "aws" {
  region = var.region
}

resource "aws_dynamodb_table" "dynamodb-state-lock" {
  name           = var.dynamodb_table_name
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

resource "aws_iam_policy" "aws_scheduler" {
  name = "aws_scheduler"
  path        = "/"
  description = "My test policy"
  policy = file("infrastructure/aws/iam_policy.json")
}