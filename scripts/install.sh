#!/bin/bash

set -x

# This script is intended to deploy all templates by hands
# without using a "parent" stack.

# ---- Configuration
env=${1:-CreatedByScript}
msk_instance_type=${2:-kafka.m5.large}

# ---- Body
scripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
templates=${scripts}/../templates

# Create VPC
vpc_stack="VPC-${env}"

#aws cloudformation deploy --template-file $templates/vpc.template --stack-name $vpc_stack --parameter-overrides "EnvironmentName=$env"

vpc_meta=$(aws cloudformation describe-stacks --stack-name $vpc_stack)
vpc_id=$(echo $vpc_meta | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "VPC") | .OutputValue')
vpc_private_subnets=$(echo $vpc_meta | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PrivateSubnets") | .OutputValue')
vpc_public_subnets=$(echo $vpc_meta | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PublicSubnets") | .OutputValue')

## Create MSK Cluster
msk_stack="MSK-${env}"
#aws cloudformation deploy --template-file $templates/msk.template --stack-name $msk_stack \
#    --capabilities CAPABILITY_IAM \
#    --parameter-overrides "EnvironmentName=$env" "VPC=$vpc_id" "PrivateSubnets=${vpc_private_subnets}" \
#    "InstanceType=$msk_instance_type"

#msk_meta=$(aws cloudformation describe-stacks --stack-name $msk_stack)
#msk_arn=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MSKClusterArn") | .OutputValue')
#msk_info_brokers=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MskBrokers") | .OutputValue')
#msk_info_brokers_tls=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MskBrokersTls") | .OutputValue')

ecs_stack="ECS-${env}"
aws cloudformation deploy --template-file $templates/ecs-fargate.template --stack-name $ecs_stack \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides "VPC=$vpc_id" \
    "PrivateSubnets=${vpc_private_subnets}" "PublicSubnets=${vpc_public_subnets}"
