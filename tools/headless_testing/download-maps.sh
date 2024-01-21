#!/bin/bash

env $(cat ./config.env) engine/*/pr-downloader --filesystem-writepath "/bar" --download-map "Full Metal Plate 1.5"
