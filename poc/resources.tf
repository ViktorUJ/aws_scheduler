resource "random_id" "id" {
  byte_length = 10
}

resource "aws_dynamodb_table_item" "example_ec2_on_off" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "${random_id.id.id}"},
  "operational": {"S": "true"},
  "period_type": {"S": "work-hours"},
  "resource": {"S": "list of resousec"},
  "work_hours": {"S": "0700-2100"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM



}