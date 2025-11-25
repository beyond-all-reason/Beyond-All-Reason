FROM ubuntu:devel

WORKDIR /bar

ENV BAR_ROOT=/bar
ENV BAR_CONFIG_JSON=./config.json
ENV BAR_CONFIG_ENV=./config.env

RUN apt-get update && \
    apt-get install -y curl jq p7zip-full && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p maps games engine

ADD https://launcher-config.beyondallreason.dev/config.json $BAR_CONFIG_JSON

COPY --chmod=755 ./parse-config.sh .
RUN ./parse-config.sh

COPY --chmod=755 ./download-engine.sh .
RUN export $(cat $BAR_CONFIG_ENV | xargs) && ./download-engine.sh

COPY --chmod=755 ./download-maps.sh .
RUN export $(cat $BAR_CONFIG_ENV | xargs) && ./download-maps.sh

COPY ./startscript.txt .
COPY ./springsettings.cfg .
COPY --chmod=755 ./start.sh .

ENTRYPOINT ./start.sh /bar /bar/startscript.txt
