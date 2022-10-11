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
resource "aws_dynamodb_table_item" "test" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "test"},
  "operational": {"S": "true"},
  "period_type": {"S": "off_after_timestamp"},
  "namespace": {"S": "eu-west-1=doordawn-eks=test-sch"},
  "rds": {"S": "eu-west-1=test1"},
  "atlas_mongo": {"S": "b2c-16589-home-t=b2c-16589-home-t b2c-16589-home-t=bulletins"},
  "wait_rds_ready": {"S": "true"},
  "lock": {"S": ""},
  "target_time_stamp": {"S": "${local.target_time_stamp}"},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "off_after_timestamp"}
    }
ITEM

}

# real resouces doordawn

resource "aws_dynamodb_table_item" "doordawn-feature-tracing" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "eu-west-1-doordawn-eks-feature-tracing-manual"},
  "operational": {"S": "true"},
  "period_type": {"S": "work-hours"},
  "namespace": {"S": "eu-west-1=doordawn-eks=feature-tracing"},
  "rds": {"S": "eu-west-1=tracing-general"},
  "wait_rds_ready": {"S": "true"},
  "work_hours": {"S": "0430-1830"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM

}




# israel-qa
resource "aws_dynamodb_table_item" "israel-qa-feature-rewrite-2" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "eu-west-1-israel-qa-feature-rewrite-2-manual"},
  "operational": {"S": "true"},
  "period_type": {"S": "work-hours"},
  "namespace": {"S": "eu-west-1=israel-qa=feature-rewrite-2"},
  "rds": {"S": "eu-west-1=rewrite-2-israel-mysql-general eu-west-1=rewrite-2-israel-postgres-general"},
  "wait_rds_ready": {"S": "true"},
  "work_hours": {"S": "0430-2000"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM


}

resource "aws_dynamodb_table_item" "israel-qa-feature-rewrite-1" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "eu-west-1-israel-qa-feature-rewrite-1-manual"},
  "operational": {"S": "true"},
  "period_type": {"S": "work-hours"},
  "namespace": {"S": "eu-west-1=israel-qa=feature-rewrite-1"},
  "rds": {"S": "eu-west-1=rewrite-1-israel-mysql-general eu-west-1=rewrite-1-israel-postgres-general"},
  "wait_rds_ready": {"S": "true"},
  "work_hours": {"S": "0430-2000"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM


}
