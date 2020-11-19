this tool for stop, start , schange type of aws  resources

docker run  --env DYNAMODB_REGION='us-west-2' --env AWS_KEY='AKIAZMZQDJRLD3GRIW6K' --env AWS_SECRET='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' --env DYNAMODB_TABLE_NAME='scheduler' --env SLEEP_NEXT_RUN=60 --env SLEEP_NEXT_ITEM=1 --name aws_scheduler -d aws_scheduler

docker  logs   aws_scheduler -f

docker  rm   aws_scheduler --force
