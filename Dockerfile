FROM alpine

RUN apk add --no-cache openssh-client python3 py-pip alpine-sdk python3-dev libffi-dev openssl-dev sshpass
RUN pip install ansible

RUN mkdir /playbook
VOLUME /playbook
WORKDIR /playbook

ENTRYPOINT ["ansible-playbook"]
