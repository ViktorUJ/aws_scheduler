FROM alpine

RUN apk -v --update add \
        ca-certificates \
        curl  openssh-client   jq    \
        python \
		netcat-openbsd \
		bash \
		tree\
        py-pip \
        && \
    pip install --upgrade pip && \
    pip install --upgrade awscli s3cmd python-magic && \
    apk -v --purge del py-pip && \
    rm /var/cache/apk/*
COPY source /usr/bin/