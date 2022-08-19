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
  "operational": {"S": "true"},
  "period_type": {"S": "work-hours"},
  "namespace": {"S": "eu-west-1=doordawn-eks=tst-schedul"},
  "rds": {"S": "eu-west-1=scheduler eu-west-1=scheduler2"},
  "work_hours": {"S": "2100-0700"},
  "lock": {"S": ""},
  "resource_type": {"S": "feature_env"},
  "scheduler_type": {"S": "ON_OFF"}
    }
ITEM



}

