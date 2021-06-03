FROM amazon/aws-cli:2.2.8
RUN yum install jq -y
COPY source /usr/bin/
ENTRYPOINT ["scheduler.sh"]