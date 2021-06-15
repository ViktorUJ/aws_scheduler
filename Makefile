local:
	@echo 'local'
	docker  rm   aws_scheduler --force
	docker build    --compress  -t  aws_scheduler -f docker/Dockerfile .
	AWS_CUSTOM_CREDENTIALS=$(shell cat ~/.aws/credentials | base64)
	AWS_CUSTOM_CONFIG=$(shell cat ~/.aws/config | base64)
	AWS_IAM_TYPE="CUSTOM_PROFILE"
	docker run  --env AWS_CUSTOM_CREDENTIALS="$AWS_CUSTOM_CREDENTIALS" --env AWS_CUSTOM_CONFIG="$AWS_CUSTOM_CONFIG" --env AWS_IAM_TYPE="$AWS_IAM_TYPE"   --env DYNAMODB_REGION='us-west-2' --env DYNAMODB_TABLE_NAME='scheduler_dev' --env SLEEP_NEXT_RUN=10 --env SLEEP_NEXT_ITEM=1 --name aws_scheduler -d aws_scheduler
	docker  logs   aws_scheduler -f
