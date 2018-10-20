FROM ruby:2.5

ARG CFN_MANAGE_VERSION=0.5.0

RUN gem install cfn_manage -v ${CFN_MANAGE_VERSION}

CMD ["cfn_manage","help"]
