#!/bin/bash 

bs=${bs:-$PROVISION_BOOTSTRAP_SERVERS}

if [[ -z $bs ]]; then
  echo Bootstrap servers are not found. Export \$PROVISION_BOOTSTRAP_SERVERS variable with bootstrap servers
  exit 1
fi

function create_topic() {
  local topic_name=$1
  local partitions=${2:-8}
  local replication_factor=${3:-3}

  if [[ $(kafka-topics --bootstrap-server $bs --list | grep "^${topic_name}\$" | wc -l) == 0 ]]; then
    echo "Creating topic ${topic_name}"
    kafka-topics --create --topic ${topic_name} --partitions ${partitions} \
      --replication-factor ${replication_factor} --bootstrap-server $bs
  else
    echo "Topic ${topic_name} already created, skipping"
  fi
}

IFS=,
for topic in $PROVISION_NEW_KAFKA_TOPICS; do
  create_topic "$topic"
done
