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
  "atlas_mongo": {"S": "israel-rewrite-2=rewrite-2=mongodb+srv://appuser:wIF5ZRz0kz9mFfQf@rewrite-2.cq67r.mongodb.net"},
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
  "atlas_mongo": {"S": "israel-rewrite-1=rewrite-1=mongodb+srv://appuser:(u1hNbjE2D3BzIlk@rewrite-1.3cgrt.mongodb.net"},
  "work_hours": {"S": "0430-2000"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM


}
