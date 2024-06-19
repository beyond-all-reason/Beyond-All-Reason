#!/bin/bash

mkdir -p "$ENGINE_DESTINATION"

TEMP_FILE=$(mktemp --suffix=.7z)

curl -L "$ENGINE_URL" -o "$TEMP_FILE" && 7z x "$TEMP_FILE" -o"$ENGINE_DESTINATION" && rm -f temp.7z
