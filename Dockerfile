FROM alpine:latest

MAINTAINER Natan <natan@mokyun.net>

# Install dependencies and build
RUN \
    apk update \
    && apk add --no-cache --virtual .build-deps \
        cargo \
        git \
    && apk add --no-cache \
	gcc \
    && git clone --single-branch --branch master https://github.com/katattakd/KatWebX --recursive \
    && cd KatWebX \
    && cargo build --release

# Set KatWebX dir
WORKDIR KatWebX

# Cleanup
RUN apk del .build-deps

EXPOSE 80 443
CMD ./target/release/katwebx
