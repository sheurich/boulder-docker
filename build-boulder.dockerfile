# syntax=docker/dockerfile:1
ARG BUILDER_IMAGE="golang:1-bookworm"
ARG RUNTIME_IMAGE="gcr.io/distroless/base-debian12:debug-nonroot"

FROM ${BUILDER_IMAGE} AS builder
ARG BOULDER_RELEASE_TAG="main"
RUN git clone --depth 1 --branch "$BOULDER_RELEASE_TAG" \
    https://github.com/letsencrypt/boulder.git \
    /go/src/github.com/letsencrypt/boulder
COPY ./build-boulder ./setup-go /usr/local/bin/
RUN chmod +x /usr/local/bin/*
WORKDIR /go/src/github.com/letsencrypt/boulder
RUN /usr/local/bin/setup-go
RUN BUILD_ID=${BOULDER_RELEASE_TAG} \
    BUILD_TIME=$(git log -1 --format=%at) \
    /usr/local/bin/build-boulder

FROM ${RUNTIME_IMAGE}
COPY --from=builder \
    /go/src/github.com/letsencrypt/boulder/bin/boulder \
    /usr/local/bin/boulder
USER nonroot
ENTRYPOINT [ "/usr/local/bin/boulder" ]
