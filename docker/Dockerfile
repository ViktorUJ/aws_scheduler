FROM amazon/aws-cli:2.7.24
RUN yum install jq -y
COPY source /usr/bin/
ENTRYPOINT ["scheduler.sh"]