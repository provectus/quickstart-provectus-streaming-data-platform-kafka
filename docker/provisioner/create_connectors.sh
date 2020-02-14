#!/bin/bash 

for connector in connectors/*.json; do
  echo Installing $connector

  if [[ ! -e ${connector} ]]; then
    echo ERROR: Configuration file ${connector} is not found
    continue
  fi

  curl -s -X PUT -d @${connector}.json -H "Content-Type: application/json" ${1}/connectors/${connector}/config | jq .
done
