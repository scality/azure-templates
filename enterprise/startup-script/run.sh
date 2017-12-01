#!/bin/bash

export STORAGE_ACCESS_ACCOUNT=$1
export STORAGE_ACCESS_KEY=$2
export FQDN=$3

sudo nohup docker run -d --name scalityconnect -p 8000:8000 \
-e FQDN=$FQDN \
-e AZURE_STORAGE_ACCESS_KEY=$STORAGE_ACCESS_KEY \
-e AZURE_STORAGE_ACCOUNT=$STORAGE_ACCESS_ACCOUNT \
--log-opt max-size=5g --log-opt max-file=10 \
--restart always scality/connect &
