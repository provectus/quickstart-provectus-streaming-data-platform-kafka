#!/bin/bash
# This script is intended to deploy all templates by hands
# without using a "parent" stack.

# ---- Configuration
env=${1:-man}
msk_instance_type=${2:-kafka.m5.large}

# ---- Body
scripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
templates=${scripts}/../templates

source ${scripts}/base.sh

stacks=(
"VPC-${env}"
"MSK-${env}"
"ECS-${env}"
"SchemaRegistry-${env}"
"KafkaConnect-${env}"
"SSH-${env}"
"SFTP-${env}"
"API-${env}"
"Provision-${env}"
)

function uninstall_stack(){
    stack=$1
    echo_info "Deleting stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -eq 0 ]; then
        echo_warn "There is stack $stack in AWS CloudFormation"
        aws cloudformation delete-stack --stack-name $stack
    fi

    wait_stack_deleted $stack 50 5
}

function uninstall_stacks(){
    for (( i=${#stacks[@]}-1; i>=0; i-- ))
    do
        uninstall_stack ${stacks[i]}
    done
}

uninstall_stacks