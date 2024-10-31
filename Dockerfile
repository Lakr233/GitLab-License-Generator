FROM ruby:bookworm
WORKDIR /license-generator
COPY ./ ./
RUN <<EOF
gem install gitlab-license
EOF
VOLUME /license-generator/build
ENV LICENSE_NAME="Tim Cook"
ENV LICENSE_COMPANY="Apple Computer, Inc."
ENV LICENSE_EMAIL="tcook@apple.com"
ENV LICENSE_PLAN="ultimate"
ENV LICENSE_USER_COUNT="2147483647"
ENV LICENSE_EXPIRE_YEAR="2500"

CMD [ "./make.sh" ]