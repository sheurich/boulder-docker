Write these files:

1. A shell script called build-boulder:

- runs: `make`

2. . A shell script called `build-boulder-image` that can run on a macOS system or an Ubuntu system which:

- accepts an optional cli argument that specifies a release tag for the letsencrypt/boulder repo
  -- if no argument provided, uses `gh` to retrieve latest release tag of boulder from letsencrypt/boulder
- clones the boulder repo at the given release tag
- runs a to-be-specified `jq` command to retrieve GO_VER from boulder/.github/workflows/release.yml
- builds and runs this docker image while mounting the boulder repo into the container:

```
ARG GO_VER
FROM golang:$GO_VER AS builder
COPY ./build-boulder /usr/local/bin/build-boulder
WORKDIR /go/src/github.com/letsencrypt/boulder
RUN /usr/local/bin/build-boulder
```

- prints out a table showing the filename and sha256 of files in boulder/bin/\*

3. A GitHub actions workflow which runs on push to main to accomplish:

- checkout
- run ./build-boulder-image
- docker push to ghcr registry
