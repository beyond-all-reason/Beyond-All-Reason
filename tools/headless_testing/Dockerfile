FROM ubuntu:devel

WORKDIR /bar

RUN apt-get update && \
    apt-get install -y curl jq 7zip

RUN mkdir -p maps games engine

COPY --chmod=755 ./download-engine.sh /bar/
RUN /bar/download-engine.sh

RUN /bar/engine/*/pr-downloader --filesystem-writepath "/bar" download-map "Full Metal Plate 1.5"

COPY ./startscript.txt /bar/
COPY --chmod=755 ./start.sh /bar/

ENTRYPOINT /bar/start.sh /bar /bar/startscript.txt
