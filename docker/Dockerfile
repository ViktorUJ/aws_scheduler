FROM amazon/aws-cli:2.1.17
RUN yum install jq -y
COPY source /usr/bin/
ENTRYPOINT ["scheduler.sh"]