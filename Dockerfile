ARG BOULDER_TAG="main"

FROM golang:bookworm AS build
ARG BOULDER_TAG
RUN git clone --depth 1 --branch $BOULDER_TAG \
    https://github.com/letsencrypt/boulder.git /go/src/github.com/letsencrypt/boulder
WORKDIR /go/src/github.com/letsencrypt/boulder
RUN make

FROM gcr.io/distroless/base-nossl-debian12
COPY --from=build /go/src/github.com/letsencrypt/boulder/bin/boulder /boulder
ENTRYPOINT ["/boulder"]
