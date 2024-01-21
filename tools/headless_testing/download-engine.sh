#!/bin/bash

json_url="https://launcher-config.beyondallreason.dev/config.json"
json=$(curl $json_url)

url=$(echo $json | jq -r '.setups[] | select(.package.id == "manual-linux") | .downloads.resources[] | select(.destination | contains("engine")) | .url')
destination=$(echo $json | jq -r '.setups[] | select(.package.id == "manual-linux") | .downloads.resources[] | select(.destination | contains("engine")) | .destination')
env_variables=$(echo $json | jq -r '.setups[] | select(.package.id == "manual-linux") | .env_variables | to_entries[] | "\(.key)=\(.value)"')

echo "$env_variables" > "config.env"

mkdir -p "$destination"

curl -L $url -o temp.7z && 7z x temp.7z -o"$destination" && rm -f temp.7z
