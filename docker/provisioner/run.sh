#!/bin/bash

echo Environment variables
env

set -x

echo "Starting at $(date)"

####
echo "Creating topics $(date)"
./create_topics.sh

echo "Creating schemas $(date)"
python ./create_schemas.py $SCHEMA_REGISTRY_URL

echo "Creating connectors $(date)"
./create_connectors.sh $KAFKA_CONNECT_URL
####

echo "Finished at $(date)"

# TODO: Remove the line when a path to run the service once will be found
sleep 22896000

exit 0
