resource "random_id" "id" {
  byte_length = 10
}

/*
resource "aws_dynamodb_table_item" "test-feature-env" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "${random_id.id.id}"},
  "operational": {"S": "true"},
  "period_type": {"S": "work-hours"},
 "resouces": {
    "M": {
      "NAMESPACE": {
        "L": [
          {
            "M": {
              "eks": {
                "S": "doordawn"
              },
              "name": {
                "S": "featute-sjfjksjdkfsdjk"
              },
              "region": {
                "S": "eu-west-1"
              }
            }
          }
        ]
      },
      "RDS": {
        "L": [
          {
            "M": {
              "name": {
                "S": "by-data-base"
              },
              "region": {
                "S": "eu-west-1"
              }
            }
          }
        ]
      }
    }
  },
  "work_hours": {"S": "0700-2100"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM



}


*/

resource "aws_dynamodb_table_item" "test-feature-env" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "${random_id.id.id}"},
  "operational": {"S": "force_sleep"},
  "period_type": {"S": "work-hours"},
  "namespace": {"S": "eu-west-1=doordawn-eks=tst-schedul"},
  "rds": {"S": "eu-west-1=scheduler eu-west-1=scheduler2"},
  "wait_rds_ready": {"S": "true"},
  "work_hours": {"S": "2100-0700"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM


}

resource "aws_dynamodb_table_item" "feature-release-v039990" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "eu-west-1-doordawn-eks-feature-release-v039990"},
  "operational": {"S": "true"},
  "period_type": {"S": "work-hours"},
  "namespace": {"S": "eu-west-1=doordawn-eks=feature-release-v039990"},
  "rds": {"S": "eu-west-1=release-v039990-general"},
  "wait_rds_ready": {"S": "true"},
  "work_hours": {"S": "0500-2000"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM


}

resource "aws_dynamodb_table_item" "feature-rewrite-2" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "eu-west-1-israel-qa-feature-rewrite-2"},
  "operational": {"S": "true"},
  "period_type": {"S": "work-hours"},
  "namespace": {"S": "eu-west-1=israel-qa=feature-rewrite-2"},
  "rds": {"S": "eu-west-1=rewrite-2-israel-mysql-general eu-west-1=rewrite-2-israel-postgres-general"},
  "wait_rds_ready": {"S": "true"},
  "work_hours": {"S": "0500-2000"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM


}


/*
resource "aws_dynamodb_table_item" "feature-tracing" {
  hash_key = "id"
  table_name = aws_dynamodb_table.scheduler.name
  item =  <<ITEM
{
  "id": {"S": "eu-west-1-doordawn-feature-tracing"},
  "operational": {"S": "true"},
  "period_type": {"S": "work-hours"},
  "namespace": {"S": "eu-west-1=doordawn-eks=feature-tracing"},
  "rds": {"S": "eu-west-1=tracing-general"},
  "work_hours": {"S": "0700-1800"},
  "lock": {"S": ""},
  "wait_rds_ready": {"S": "true"},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM


}
*/