FROM amazon/aws-cli:2.8.0
COPY yum.repos /etc/yum.repos.d/
RUN yum install jq bc mongodb-atlas-cli mongodb-mongosh -y && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv kubectl /usr/local/bin/kubectl
COPY source /usr/bin/
RUN chmod +x /usr/bin/cmdb_utill.sh
ENTRYPOINT ["scheduler.sh"]