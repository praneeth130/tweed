####################################################
####################################################
FROM golang:1.13 AS stage1

RUN apt-get update \
 && apt-get install -y libgpgme-dev libassuan-dev libbtrfs-dev libdevmapper-dev \
 && mkdir /bins

RUN mkdir -p /go/src/github.com/containers \
 && git clone https://github.com/containers/skopeo \
 && cd skopeo \
 && make binary-local \
 && cp skopeo /bins/skopeo

WORKDIR /go/src/github.com/tweedproject/tweed
COPY . .

ENV GO111MODULE=on
RUN cd /go/src/github.com/tweedproject/tweed \
 && go build -mod=vendor ./cmd/tweed \
 && cp tweed /bins/tweed

RUN chmod 0755 /bins/*

####################################################
####################################################
FROM ubuntu:18.04 AS stage2
RUN apt-get update \
    && apt-get install -y curl ca-certificates unzip \
    && mkdir /bins \
    && curl -Lo /bins/safe       https://github.com/starkandwayne/safe/releases/download/v1.4.1/safe-linux-amd64 \
    && curl -Lo /bins/spruce     https://github.com/geofffranks/spruce/releases/download/v1.23.0/spruce-linux-amd64 \
    && curl -Lo /bins/jq         https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
    && curl -Lo /bins/runc       https://github.com/opencontainers/runc/releases/download/v1.0.0-rc9/runc.amd64

COPY --from=stage1 /bins/* /bins/
RUN chmod 0755 /bins/*

####################################################
####################################################
FROM ubuntu:18.04
RUN apt-get update \
 && apt-get install --no-install-recommends -y libgpgme-dev libassuan-dev libdevmapper-dev ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=stage2 /bins/* /usr/bin/
COPY bin /tweed/bin

ADD entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
