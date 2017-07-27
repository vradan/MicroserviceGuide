FROM alpine

MAINTAINER Lucas de Souza Morinigo

RUN apk update && \
  apk add ca-certificates && \
  update-ca-certificates && \
  apk add openssl && \
  apk add python && \
  apk add openjdk7-jre

RUN wget "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" &&\
  unzip awscli-bundle.zip &&\
  rm awscli-bundle.zip

RUN /awscli-bundle/install &&\
  cp /root/.local/lib/aws/bin/aws /usr/bin &&\
  rm -R /awscli-bundle

COPY CloudWatch.class /

CMD java CloudWatch
