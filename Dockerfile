# syntax=docker/dockerfile:1

ARG BOULDER_VERSION
ARG GO_VERSION

ARG FETCH_BASE_IMAGE=debian:bookworm-slim
ARG BUILD_BASE_IMAGE=debian:bookworm-slim
ARG RUNTIME_BASE_IMAGE=gcr.io/distroless/base-nossl-debian12:nonroot

# Stage 1: Fetch Boulder source and GPG-verified Go toolchain
FROM ${FETCH_BASE_IMAGE} AS fetch
ARG BOULDER_VERSION
ARG GO_VERSION
ARG TARGETARCH

# Install minimal packages for verification
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl git gpgv

# The embedded Google signing key is used to verify Go releases.
# To update:
# curl -fsSL https://dl.google.com/linux/linux_signing_key.pub |
#   gpg --dearmor > google-go-signing-key.gpg
COPY google-go-signing-key.gpg /etc/google-go-signing-key.gpg

# Download and verify Go using gpgv with embedded key
RUN set -eux; \
    WORKDIR="$(mktemp -d)"; \
    FILENAME="go${GO_VERSION}.linux-${TARGETARCH}.tar.gz"; \
    \
    echo "Downloading Go ${GO_VERSION} for linux-${TARGETARCH}..."; \
    curl -fsSL "https://dl.google.com/go/${FILENAME}" -o "${WORKDIR}/${FILENAME}"; \
    curl -fsSL "https://dl.google.com/go/${FILENAME}.asc" -o "${WORKDIR}/${FILENAME}.asc"; \
    \
    echo "Verifying signature with gpgv using embedded key..."; \
    gpgv --keyring /etc/google-go-signing-key.gpg \
         "${WORKDIR}/${FILENAME}.asc" \
         "${WORKDIR}/${FILENAME}"; \
    \
    echo "Signature verified. Extracting Go toolchain..."; \
    tar -C /usr/local -xzf "${WORKDIR}/${FILENAME}"; \
    \
    rm -rf "${WORKDIR}"

# Clone Boulder repository and extract build metadata
RUN git clone --depth 1 --branch "$BOULDER_VERSION" \
    https://github.com/letsencrypt/boulder.git /src/boulder && \
    cd /src/boulder && \
    git symbolic-ref --short HEAD 2>/dev/null > .git-name || echo "detached" > .git-name && \
    git rev-parse --short=8 HEAD > .git-sha && \
    git show -s --format=%cI HEAD > .git-time && \
    git show -s --format=%ct HEAD > .git-epoch

# Stage 2: Build Boulder with verified Go
FROM ${BUILD_BASE_IMAGE} AS build
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends gcc libc6-dev
COPY --link --from=fetch /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
COPY --link --from=fetch /src/boulder /build/boulder
WORKDIR /build/boulder

RUN --network=none \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
    export GOPROXY=off GOSUMDB=off; \
    GIT_NAME="$(cat .git-name)"; \
    GIT_SHA="$(cat .git-sha)"; \
    BUILD_ID="${GIT_NAME}@${GIT_SHA}"; \
    BUILD_TIME="$(cat .git-time)"; \
    BUILD_HOST="$(go env GOOS)/$(go env GOARCH)"; \
    SOURCE_DATE_EPOCH="$(cat .git-epoch)"; \
    export SOURCE_DATE_EPOCH; \
    GOBIN=/build/boulder/bin go install -mod=vendor -trimpath -buildvcs=false \
        -ldflags="-buildid= -w -s \
            -X 'github.com/letsencrypt/boulder/core.BuildID=${BUILD_ID}' \
            -X 'github.com/letsencrypt/boulder/core.BuildTime=${BUILD_TIME}' \
            -X 'github.com/letsencrypt/boulder/core.BuildHost=${BUILD_HOST}'" \
        ./...

RUN /build/boulder/bin/boulder --version

# Stage 3: Minimal runtime
FROM ${RUNTIME_BASE_IMAGE}
LABEL org.opencontainers.image.source="https://github.com/letsencrypt/boulder"
COPY --link --from=build --chmod=0555 /build/boulder/bin/boulder /usr/local/bin/boulder
ENTRYPOINT ["/usr/local/bin/boulder"]
