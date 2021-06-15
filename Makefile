DYNAMODB_REGION="us-west-2"
DYNAMODB_TABLE_NAME="scheduler_dev"
SLEEP_NEXT_RUN="10"
SLEEP_NEXT_ITEM="1"
CONTAINER_NAME="aws_scheduler"

local:
	@echo '***** local'
#	docker  rm   $CONTAINER_NAME --force
	docker build    --compress  -t  $CONTAINER_NAME -f docker/Dockerfile .
	AWS_CUSTOM_CREDENTIALS="$(shell cat ~/.aws/credentials | base64)"
	AWS_CUSTOM_CONFIG="$(shell cat ~/.aws/config | base64)"
	AWS_IAM_TYPE="CUSTOM_PROFILE"
	docker run  --env AWS_CUSTOM_CREDENTIALS="$AWS_CUSTOM_CREDENTIALS" --env AWS_CUSTOM_CONFIG="$AWS_CUSTOM_CONFIG" --env AWS_IAM_TYPE="$AWS_IAM_TYPE"   --env DYNAMODB_REGION="$DYNAMODB_REGION" --env DYNAMODB_TABLE_NAME="$DYNAMODB_TABLE_NAME" --env SLEEP_NEXT_RUN="$SLEEP_NEXT_RUN" --env SLEEP_NEXT_ITEM="$SLEEP_NEXT_ITEM" --name aws_scheduler -d $CONTAINER_NAME
	docker  logs   $CONTAINER_NAME -f
