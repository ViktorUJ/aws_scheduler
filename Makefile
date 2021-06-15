DYNAMODB_REGION='us-west-2'
DYNAMODB_TABLE_NAME=scheduler_dev
SLEEP_NEXT_RUN='10'
SLEEP_NEXT_ITEM='1'
CONTAINER_NAME=aws_scheduler
AWS_IAM_TYPE='CUSTOM_PROFILE'
DOCKERHUB_TAG='0.3.03'
DOCKERHUB_REPO='viktoruj/aws_scheduler:${DOCKERHUB_TAG}'
DOCKERHUB_REPO_LATEST='viktoruj/aws_scheduler'
AWS_CUSTOM_CREDENTIALS='$(shell cat ~/.aws/credentials | base64  | tr -d '\n')'
AWS_CUSTOM_CONFIG='$(shell cat ~/.aws/config  | base64 | tr -d '\n')'


local:
	@echo '***** local'
	git pull
	-docker  rm   ${CONTAINER_NAME} --force
	docker build    --compress  -t  ${CONTAINER_NAME} -f docker/Dockerfile .
	trivy ${CONTAINER_NAME}
	docker run  --env AWS_CUSTOM_CREDENTIALS=${AWS_CUSTOM_CREDENTIALS} --env AWS_CUSTOM_CONFIG=${AWS_CUSTOM_CONFIG} --env AWS_IAM_TYPE=${AWS_IAM_TYPE}   --env DYNAMODB_REGION=${DYNAMODB_REGION} --env DYNAMODB_TABLE_NAME=${DYNAMODB_TABLE_NAME} --env SLEEP_NEXT_RUN=${SLEEP_NEXT_RUN} --env SLEEP_NEXT_ITEM=${SLEEP_NEXT_ITEM} --name ${CONTAINER_NAME} -d ${CONTAINER_NAME}
	docker  logs   ${CONTAINER_NAME} -f


release:
	@echo '***** release'
	git pull
	docker build    --compress  -t  ${DOCKERHUB_REPO} -f docker/Dockerfile .
	trivy ${DOCKERHUB_REPO}
	docker login
	docker push ${DOCKERHUB_REPO}

release_latest:
	@echo '***** release'
	git pull
	docker build    --compress  -t  ${DOCKERHUB_REPO} -f docker/Dockerfile .
	trivy ${DOCKERHUB_REPO_LATEST}
	docker login
	docker push ${DOCKERHUB_REPO_LATEST}