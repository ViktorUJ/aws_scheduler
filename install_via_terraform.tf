variable "region" {
  default = "eu-north-1"
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
  policy = file("infrastructure/aws/iam_policy.json")
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
}

output "AWS_SECRET" {
  value =aws_iam_access_key.aws_scheduler.secret
}

output "DYNAMODB_TABLE_NAME" {
  value =aws_dynamodb_table.scheduler.name
}

output "DYNAMODB_REGION" {
  value =var.region
}




## Examples
#/*

resource "aws_dynamodb_table_item" "example_ec2_on_off" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "example_ec2_on_off"},
  "operational": {"S": "false"},
  "period_type": {"S": "work-hours"},
  "resource_id": {"S": "i-052adc06ce62d699a"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "us-west-2"},
  "work_hours": {"S": "0700-2100"},
  "lock": {"S": ""},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM



}


resource "aws_dynamodb_table_item" "example_ec2_switch" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "example_ec2_on_switch"},
  "operational": {"S": "false"},
  "period_type": {"S": "work-hours"},
  "resource_id": {"S": "i-052adc06ce62d699a"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "us-west-2"},
  "work_hours": {"S": "0700-2100"},
  "lock": {"S": ""},
  "work_hours": {"S": "0700-2100"},
  "sleep_instance_type": {"S": "t3.micro"},
  "work_instance_type": {"S": "t3.small"},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "SWITCH"}
    }
ITEM



}



resource "aws_dynamodb_table_item" "example_ec2_switch_weekend" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "example_ec2_switch_weekend"},
  "operational": {"S": "false"},
  "period_type": {"S": "work-hours_weekend"},
  "weekend_days": {"S": "Fri,Thu"},
  "resource_id": {"S": "i-052adc06ce62d699a"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "us-west-2"},
  "work_hours": {"S": "0700-2100"},
  "lock": {"S": ""},
  "work_hours": {"S": "0700-2100"},
  "sleep_instance_type": {"S": "t3.micro"},
  "work_instance_type": {"S": "t3.small"},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "SWITCH"}
    }
ITEM



}
# end of examples
#*/
