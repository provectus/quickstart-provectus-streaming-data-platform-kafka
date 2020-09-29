#!/bin/bash
### This script will create Lambda package with library dependencies ready for install
set -x
WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $WORKDIR
rm -rf .dependencies
mkdir .dependencies
pipenv clean
pipenv run \
pip install -r requirements.txt  -t .dependencies && \
cp *.py .dependencies && \
cd .dependencies && \
zip -r ../schemas.zip . && \
cd .. 
rm -rf .dependencies