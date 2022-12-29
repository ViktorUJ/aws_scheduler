#test
variable "work_period_second" {
  default = 3600
}
resource "time_static" "time" {
triggers = {
  time=local.time_stamp
}
}

locals {
  time_stamp=timestamp()
  target_time_stamp= sum([tonumber(time_static.time.unix),tonumber(var.work_period_second)])
}

# work static Ireland

resource "aws_dynamodb_table_item" "dimid-doordawn-amazon-linux" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "dimid-doordawn-amazon-linux"},
  "operational": {"S": "true"},
  "period_type": {"S": "off_after_work-hours"},
  "resource_id": {"S": "i-08de7314d563c0e82"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "eu-west-1"},
  "work_hours": {"S": "0600-1800"},
  "lock": {"S": ""},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM

}

resource "aws_dynamodb_table_item" "ds-remote-machine-daslu-3" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "ds-remote-machine-daslu-3"},
  "operational": {"S": "true"},
  "period_type": {"S": "off_after_work-hours"},
  "resource_id": {"S": "i-09fec309e4bf0c137"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "eu-west-1"},
  "work_hours": {"S": "0600-1800"},
  "lock": {"S": ""},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM

}


resource "aws_dynamodb_table_item" "legacy-rewrite-1" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "legacy-rewrite-1"},
  "operational": {"S": "true"},
  "period_type": {"S": "off_after_work-hours"},
  "resource_id": {"S": "i-03dc59f4c74221f38"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "eu-west-1"},
  "work_hours": {"S": "0600-1800"},
  "lock": {"S": ""},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM

}


resource "aws_dynamodb_table_item" "legacy-rewrite-2" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "legacy-rewrite-2"},
  "operational": {"S": "true"},
  "period_type": {"S": "off_after_work-hours"},
  "resource_id": {"S": "i-0c35a577a958588fc"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "eu-west-1"},
  "work_hours": {"S": "0600-1800"},
  "lock": {"S": ""},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM

}


resource "aws_dynamodb_table_item" "power-bi-client" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "power-bi-client"},
  "operational": {"S": "true"},
  "period_type": {"S": "off_after_work-hours"},
  "resource_id": {"S": "i-0dd48bb94fe5560cc"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "eu-central-1"},
  "work_hours": {"S": "0600-1800"},
  "lock": {"S": ""},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM

}


resource "aws_dynamodb_table_item" "dimid-nyc-localize" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "dimid-nyc-localize"},
  "operational": {"S": "true"},
  "period_type": {"S": "off_after_work-hours"},
  "resource_id": {"S": "i-05fa0d6d64eeceb1b"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "us-east-1"},
  "work_hours": {"S": "0600-1800"},
  "lock": {"S": ""},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM

}


resource "aws_dynamodb_table_item" "index_machine" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "index_machine-localize"},
  "operational": {"S": "true"},
  "period_type": {"S": "off_after_work-hours"},
  "resource_id": {"S": "i-0df5d9ce20c9aaddb"},
  "resource_id_type": {"S": "id"},
  "resource_region": {"S": "us-east-1"},
  "work_hours": {"S": "0600-1800"},
  "lock": {"S": ""},
  "resource_type": {"S": "ec2"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM

}



