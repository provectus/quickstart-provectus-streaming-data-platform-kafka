#!/usr/bin/env bash

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_BROWN='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_URL='\033[0;36m'
COLOR_NO='\033[0m' # No Color


function echo_err() {
    >&2 echo -e "${COLOR_RED}ERROR:${COLOR_NO} $1"
}

function echo_success() {
    echo -e "${COLOR_GREEN}SUCCESS:${COLOR_NO} $1"
}

function echo_warn() {
    >&2 echo -e "${COLOR_BROWN}WARNING:${COLOR_NO} $1"
}

function echo_info() {
    echo -e "${COLOR_BLUE}INFO:${COLOR_NO} $1"
}

function tmp_dir() {
    mkdir -p "/tmp/$1"
    if [[ ! -z $2 ]]; then
        mkdir -p "/tmp/$1/$2"
    fi
}

function wait_stack_status_up() {
    STACK=$1
    COUNT=$2
    STEP=$3
    STATUS="CREATE_COMPLETE"

    echo_info "Waiting for $STACK status will be $STATUS ..."
    while [ "$(aws cloudformation describe-stacks --stack-name $STACK | jq --raw-output '.Stacks[] | select(.StackName == "'$STACK'") | .StackStatus')" != "$STATUS" ]; do
        echo -ne "$STEP> $COUNT  \r"
        if [ -z $STEP ]; then
            sleep 1
        else
            sleep $STEP
        fi
        ((COUNT--))
        if [ $COUNT -eq 0 ]; then
          echo_err "Failed to start stack $STACK"
        fi
    done
    echo_success "$STACK is running"
}

function wait_stack_deleted() {
    STACK=$1
    COUNT=$2
    STEP=$3

    echo_info "Waiting for $STACK status will be deleted ..."
    while [ "$(aws cloudformation describe-stacks --stack-name $STACK &>/dev/null && echo 0 || echo 1)" -eq 0 ]; do
        echo -ne "$STEP> $COUNT  \r"
        if [ -z $STEP ]; then
            sleep 1
        else
            sleep $STEP
        fi
        ((COUNT--))
        if [ $COUNT -eq 0 ]; then
          echo_err "Failed to delete stack $STACK"
        fi
    done
    echo_success "$STACK is deleted"
}
