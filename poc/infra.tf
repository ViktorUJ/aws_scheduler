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



resource "aws_dynamodb_table_item" "all" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "all"},
  "operational": {"S": "false"},
  "resource_type": {"S": "all"},
  "scheduler_type": {"S": "all"}
    }
ITEM



}


resource "aws_iam_policy" "aws_scheduler" {
  name = var.resources_prefix
  path        = "/"
  description = "for aws_scheduler "
  policy = file("../infrastructure/aws/iam_policy.json")
}


resource "aws_iam_user" "aws_scheduler" {
  name = var.resources_prefix
  path = "/"
}


resource "aws_iam_access_key" "aws_scheduler" {
  user    = aws_iam_user.aws_scheduler.name
}


resource "aws_iam_policy_attachment" "aws_scheduler" {
  name = var.resources_prefix
  policy_arn = aws_iam_policy.aws_scheduler.arn
  groups = []
  users = [
    aws_iam_user.aws_scheduler.name
  ]
  roles = []
}


output "AWS_KEY" {
  value =aws_iam_access_key.aws_scheduler.id
  sensitive = true
}

output "AWS_SECRET" {
  value =aws_iam_access_key.aws_scheduler.secret
  sensitive = true
}

output "DYNAMODB_TABLE_NAME" {
  value =aws_dynamodb_table.scheduler.name
}

output "DYNAMODB_REGION" {
  value =var.region
}


