
<img src="https://github.com/localizedev/aws_scheduler/raw/master/img/aws_sceduler_arch.jpg" width="1440">


````

docker  rm   aws_scheduler --force 
docker build    --compress  -t  aws_scheduler -f docker/Dockerfile .

#docker run  --env DYNAMODB_REGION='us-west-2' --env AWS_KEY='209320949907098' --env AWS_SECRET='09538y03498y308403r4808' --env DYNAMODB_TABLE_NAME='scheduler' --env SLEEP_NEXT_RUN=60 --env SLEEP_NEXT_ITEM=1 --name aws_scheduler -d aws_scheduler





AWS_CUSTOM_CREDENTIALS="$(cat ~/.aws/credentials | base64)"
AWS_CUSTOM_CONFIG="$(cat ~/.aws/config | base64)"
AWS_IAM_TYPE="CUSTOM_PROFILE"

docker run  --env AWS_CUSTOM_CREDENTIALS="$AWS_CUSTOM_CREDENTIALS" --env AWS_CUSTOM_CONFIG="$AWS_CUSTOM_CONFIG" --env AWS_IAM_TYPE="$AWS_IAM_TYPE"   --env DYNAMODB_REGION='us-west-2' --env DYNAMODB_TABLE_NAME='scheduler_dev' --env SLEEP_NEXT_RUN=10 --env SLEEP_NEXT_ITEM=1 --name aws_scheduler -d aws_scheduler

docker  logs   aws_scheduler -f

`````
