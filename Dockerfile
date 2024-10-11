FROM golang:1.22.0-alpine
WORKDIR /app
RUN apk add --no-cache git && \
    git status && \
    git clone https://gitlab.oit.duke.edu/devil-ops/patchmonkeyctl.git
RUN mkdir -p bin && \
    pwd && \
    tree


# RUN go build -o ./bin/patchmonkeyctl  ./cmd/patchmonkeyctl

# FROM gcr.io/distroless/static-debian12
