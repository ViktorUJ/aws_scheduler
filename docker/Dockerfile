FROM amazon/aws-cli:2.2.11
RUN yum install jq -y
COPY source /usr/bin/
ENTRYPOINT ["scheduler.sh"]