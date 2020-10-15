#!/bin/bash
### This script will create Lambda package with library dependencies ready for install
set -x
WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $WORKDIR
rm -rf .dependencies
rm create_topics.zip
mkdir .dependencies
pipenv lock --requirements > requirements.txt
pipenv run pip install -r requirements.txt  -t .dependencies
cd .dependencies
cp ../*.py .
zip -r ../create_topics.zip .
cd ..
rm -rf .dependencies