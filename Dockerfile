FROM golang:1.22.0-alpine AS golang
WORKDIR /app
RUN apk add --no-cache git && \
    git --version && \
    git clone https://gitlab.oit.duke.edu/devil-ops/patchmonkeyctl.git
RUN mkdir -p bin && \
    cd patchmonkeyctl && \     
    go build -o ../bin/patchmonkeyctl  ./cmd/patchmonkeyctl

FROM gcr.io/distroless/static-debian12
COPY --from=golang /app/bin/patchmonkeyctl .
CMD ["./patchmonkeyctl", "prometheus-exporter"]

