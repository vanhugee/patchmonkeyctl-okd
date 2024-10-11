FROM golang:1.22.0-alpine
WORKDIR /app
RUN apk add --no-cache git
RUN git --version
RUN git clone https://gitlab.oit.duke.edu/devil-ops/patchmonkeyctl.git
RUN cd patchmonkeyctl
RUN mkdir -p ./bin
RUN pwd
RUN ls -l
RUN tree
# RUN go build -o ./bin/patchmonkeyctl  ./cmd/patchmonkeyctl

# FROM gcr.io/distroless/static-debian12
