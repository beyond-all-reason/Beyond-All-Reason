#!/bin/bash

url=$(cat "$BAR_CONFIG_JSON" | jq -r '.setups[] | select(.package.id == "manual-linux") | .downloads.resources[] | select(.destination | contains("engine")) | .url')
destination=$(cat "$BAR_CONFIG_JSON" | jq -r '.setups[] | select(.package.id == "manual-linux") | .downloads.resources[] | select(.destination | contains("engine")) | .destination')
env_variables=$(cat "$BAR_CONFIG_JSON" | jq -r '.setups[] | select(.package.id == "manual-linux") | .env_variables | to_entries[] | "\(.key)=\(.value)"')

echo "$env_variables" > "$BAR_CONFIG_ENV"
echo "ENGINE_URL=\"$url\"" >> "$BAR_CONFIG_ENV"
echo "ENGINE_DESTINATION=\"$destination\"" >> "$BAR_CONFIG_ENV"
