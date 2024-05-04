#!/bin/bash

rm -rf $1/LuaUI/Config
$1/engine/*/spring-headless --isolation --write-dir "$1" "$2"
