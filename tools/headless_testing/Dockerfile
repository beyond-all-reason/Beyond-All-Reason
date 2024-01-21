FROM ubuntu:devel

WORKDIR /bar

RUN apt-get update && \
    apt-get install -y curl jq 7zip

RUN mkdir -p maps games engine

COPY --chmod=755 ./download-engine.sh /bar/
RUN ./download-engine.sh

COPY --chmod=755 ./download-maps.sh /bar/
RUN ./download-maps.sh

COPY ./startscript.txt /bar/
COPY ./springsettings.cfg /bar/
COPY --chmod=755 ./start.sh /bar/

ENTRYPOINT ./start.sh /bar /bar/startscript.txt
