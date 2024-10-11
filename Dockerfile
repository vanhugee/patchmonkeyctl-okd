FROM golang:1.22.0-alpine
WORKDIR /app
RUN apk add --no-cache git
RUN git --version
RUN git clone https://gitlab.oit.duke.edu/devil-ops/patchmonkeyctl.git
RUN tree
RUN pwd
RUN ls -l
RUN cd patchmonkeyctl




