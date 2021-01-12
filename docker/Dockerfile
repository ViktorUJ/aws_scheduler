FROM alpine

RUN apk update && apk -v --update add \
        ca-certificates  \
        curl  gcc openssh-client   jq  coreutils  \
        python3 \
		netcat-openbsd \
		bash \
		tree \
		glibc groff  less
 #       py-pip3 \
  #      && \
  #  pip3 install --upgrade pip && \
  #  pip3 install --upgrade awscli s3cmd python-magic && \
#    apk -v --purge del py-pip && \
 #   rm /var/cache/apk/*
COPY source /usr/bin/

ENTRYPOINT ["scheduler.sh"]