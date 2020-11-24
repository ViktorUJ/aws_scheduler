this tool for stop, start  or  change type of aws  resources


````

docker build    --compress  -t  aws_scheduler -f docker/Dockerfile .

docker run  --env DYNAMODB_REGION='us-west-2' --env AWS_KEY='209320949907098' --env AWS_SECRET='09538y03498y308403r4808' --env DYNAMODB_TABLE_NAME='scheduler' --env SLEEP_NEXT_RUN=60 --env SLEEP_NEXT_ITEM=1 --name aws_scheduler -d aws_scheduler

docker  logs   aws_scheduler -f

docker  rm   aws_scheduler --force

`````