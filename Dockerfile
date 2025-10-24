# syntax=docker/dockerfile:1

ARG BOULDER_VERSION=main
ARG GO_VERSION=1

FROM golang:${GO_VERSION}-bookworm AS build
ARG BOULDER_VERSION
RUN git clone --depth 1 --branch "$BOULDER_VERSION" https://github.com/letsencrypt/boulder.git /go/src/github.com/letsencrypt/boulder
WORKDIR /go/src/github.com/letsencrypt/boulder
RUN --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    GIT_NAME="$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || echo detached)"; \
    GIT_SHA="$(git rev-parse --short=8 HEAD)"; \
    BUILD_ID="${GIT_NAME}@${GIT_SHA}"; \
    BUILD_TIME="$(git show -s --format=%cI HEAD)"; \
    BUILD_HOST="$(go env GOOS)/$(go env GOARCH)"; \
    make BUILD_ID="$BUILD_ID" BUILD_TIME="$BUILD_TIME" BUILD_HOST="$BUILD_HOST"
RUN /go/src/github.com/letsencrypt/boulder/bin/boulder --version

FROM gcr.io/distroless/base-nossl-debian12
LABEL org.opencontainers.image.source="https://github.com/letsencrypt/boulder"
COPY --from=build --link --chmod=0555 \
    /go/src/github.com/letsencrypt/boulder/bin/boulder /usr/local/bin/boulder
USER nonroot
ENTRYPOINT ["/usr/local/bin/boulder"]
