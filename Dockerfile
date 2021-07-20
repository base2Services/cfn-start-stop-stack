FROM ruby:2.7-slim

ARG CFN_MANAGE_VERSION=0.8.3

RUN apt-get update && apt-get install -y git && \
    useradd -ms /bin/bash -u 1000 cfn-manage

COPY . /src

WORKDIR /src

RUN gem build cfn_manage.gemspec && \
    gem install cfn_manage-${CFN_MANAGE_VERSION}.gem && \
    rm -rf /src

USER cfn-manage

CMD cfn_manage
