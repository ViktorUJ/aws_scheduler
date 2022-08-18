resource "random_id" "id" {
  byte_length = 10
}

resource "aws_dynamodb_table_item" "example_ec2_on_off" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "${random_id.id.b64_std}"},
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