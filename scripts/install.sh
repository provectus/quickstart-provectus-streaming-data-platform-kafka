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

function create_vpc(){
    # Create VPC
    stack="VPC-${env}"
    echo_info "Creating stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -ne 0 ]; then
        echo_warn "There is no stack $stack in AWS CloudFormation"
        aws cloudformation deploy --template-file $templates/vpc.template \
         --stack-name $stack\
         --parameter-overrides "EnvironmentName=$env"
    fi

    wait_stack_status_up $stack 50 1
    vpc_meta=$(aws cloudformation describe-stacks --stack-name $stack)
    vpc_id=$(echo $vpc_meta | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "VPC") | .OutputValue')
    vpc_private_subnets=$(echo $vpc_meta | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PrivateSubnets") | .OutputValue')
    vpc_public_subnets=$(echo $vpc_meta | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PublicSubnets") | .OutputValue')

    echo_success "There is stack $stack in AWS CloudFormation with id=$vpc_id, vpc_private_subnets=$vpc_private_subnets, vpc_public_subnets=$vpc_public_subnets"
}

function create_msk_cluster(){
    # Create MSK Cluster
    stack="MSK-${env}"
    echo_info "Creating stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -ne 0 ]; then
        echo_warn "There is no stack $stack in AWS CloudFormation"
        aws cloudformation deploy --template-file $templates/msk.template --stack-name $stack \
            --capabilities CAPABILITY_IAM \
            --parameter-overrides "EnvironmentName=$env" "VPC=$vpc_id" "PrivateSubnets=${vpc_private_subnets}" \
            "InstanceType=$msk_instance_type"
    fi

    wait_stack_status_up $stack 50 1
    msk_meta=$(aws cloudformation describe-stacks --stack-name $stack)
    msk_arn=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MSKClusterArn") | .OutputValue')
    msk_info_brokers=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MskBrokers") | .OutputValue')
    #msk_info_brokers_tls=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MskBrokersTls") | .OutputValue')
    msk_info_zookeepers=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MskZookeepers") | .OutputValue')
    msk_info_client_group_id=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "KafkaClientInstanceSecurityGroupID") | .OutputValue')

    echo_success "There is $stack in AWS CloudFormation with msk_arn=$msk_arn, msk_info_brokers=$msk_info_brokers, msk_info_zookeepers=$msk_info_zookeepers, msk_info_client_group_id=$msk_info_client_group_id"

}

function create_ecs_fargate(){
    stack="ECS-${env}"

    echo_info "Creating stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -ne 0 ]; then
        echo_warn "There is no stack $stack in AWS CloudFormation"
        aws cloudformation deploy --template-file $templates/ecs-fargate.template --stack-name $stack \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides "VPC=$vpc_id" \
            "PrivateSubnets=${vpc_private_subnets}" "PublicSubnets=${vpc_public_subnets}" \
            "EnvironmentName=$env" \
            "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
            "BootstrapServers=$msk_info_brokers" \
            "ZookeeperServers=$msk_info_zookeepers"
    fi

    wait_stack_status_up $stack 50 1

    ecs_meta=$(aws cloudformation describe-stacks --stack-name $stack)
    exec_role=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "ExecutionRole") | .OutputValue')
    task_role=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "TaskRole") | .OutputValue')
    ecs_cluster=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "Cluster") | .OutputValue')
    ecs_private_ns=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PrivateNamespaceId") | .OutputValue')
    ecs_autoscaling_role=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "AutoScalingRole") | .OutputValue')
}

function create_schema_registry(){
    stack="SchemaRegistry-${env}"

    echo_info "Creating stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -ne 0 ]; then
        echo_warn "There is no stack $stack in AWS CloudFormation"
        aws cloudformation deploy --template-file $templates/schema-registry.template --stack-name $stack \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides "VPC=$vpc_id" \
            "PrivateSubnets=${vpc_private_subnets}" \
            "ExecutionRole=$exec_role" \
            "TaskRole=$task_role" \
            "Cluster=$ecs_cluster" \
            "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
            "BootstrapServers=$msk_info_brokers" \
            "ZookeeperServers=$msk_info_zookeepers" \
            "PrivateNamespaceId=$ecs_private_ns"
    fi

    wait_stack_status_up $stack 50 1


}

function create_kafka_connect(){
    stack="KafkaConnect-${env}"

    echo_info "Creating stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -ne 0 ]; then
        echo_warn "There is no stack $stack in AWS CloudFormation"
        aws cloudformation deploy --template-file $templates/kafka-connect.template --stack-name $stack \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides "VPC=$vpc_id" \
            "PrivateSubnets=${vpc_private_subnets}" \
            "ExecutionRole=$exec_role" \
            "TaskRole=$task_role" \
            "Cluster=$ecs_cluster" \
            "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
            "BootstrapServers=$msk_info_brokers" \
            "ZookeeperServers=$msk_info_zookeepers" \
            "PrivateNamespaceId=$ecs_private_ns"
    fi

    wait_stack_status_up $stack 50 1
}
function create_ssh(){
    stack="SSH-${env}"

    echo_info "Creating stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -ne 0 ]; then
        echo_warn "There is no stack $stack in AWS CloudFormation"
        aws cloudformation deploy --template-file $templates/ssh.template --stack-name $stack \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides "VPC=$vpc_id" \
            "PrivateSubnets=${vpc_public_subnets}" \
            "ExecutionRole=$exec_role" \
            "TaskRole=$task_role" \
            "Cluster=$ecs_cluster" \
            "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
            "BootstrapServers=$msk_info_brokers" \
            "ZookeeperServers=$msk_info_zookeepers" \
            "PrivateNamespaceId=$ecs_private_ns"
    fi

    wait_stack_status_up $stack 50 1
}

function create_sftp(){
    stack="SFTP-${env}"

    echo_info "Creating stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -ne 0 ]; then
        echo_warn "There is no stack $stack in AWS CloudFormation"
        aws cloudformation deploy --template-file $templates/sftp.template --stack-name $stack \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides \
            "EnvironmentName=$env" \
            "PublicSshKey=ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsRe9vcYiSmTz9tBMQMxC/Y5d+QlJml01OQu4ovJihFTnG98/k7MajOM/AWp7+AK5rWNrcVCwtp+KR0KJXmxlsO2AM6bt124yacd0YRmn6W/sgDZUZT9eG0RvGmzyRUL6aHi9oNcyBJ5mzIWnfiJHc8BX9j0mX2x2nejo3Pmq4Xy97x2McFA253vZ0Yba8aW+XcLlSNpHLHZSdH0G/nDAZLTC0q5I/Tnl7GF4LILXbkdHIRLG2cUg+aQYZeJkW6XtKFeGIb02KjhqRFYcfTGvcUJbTlSS6ydU3pa0iigm2n6K6wmbJ16oIHUMiTBznfK8Q30+PneojXW8TgFYUYZLIQ== ags@localhost.localdomain"
    fi

    wait_stack_status_up $stack 50 1
}

function create_api(){
    stack="API-${env}"

    echo_info "Creating stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -ne 0 ]; then
        echo_warn "There is no stack $stack in AWS CloudFormation"
        aws cloudformation deploy --template-file $templates/kafka-swagger-rest.template --stack-name $stack \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides "VPC=$vpc_id" \
            "PublicSubnets=${vpc_public_subnets}" \
            "PrivateSubnets=${vpc_private_subnets}" \
            "EnvironmentName=$env" \
            "Image=provectuslabs/kafka-swagger-rest:1cc5433" \
            "ExecutionRole=$exec_role" \
            "TaskRole=$task_role" \
            "Cluster=$ecs_cluster" \
            "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
            "BootstrapServers=$msk_info_brokers" \
            "ZookeeperServers=$msk_info_zookeepers" \
            "PrivateNamespaceId=$ecs_private_ns" \
            "AutoScalingRole=$ecs_autoscaling_role"
    fi

    wait_stack_status_up $stack 50 1


}
function create_app_provisioner(){
    stack="Provision-${env}"

    echo_info "Creating stack $stack in AWS CloudFormation ..."
    if [ "$(aws cloudformation describe-stacks --stack-name $stack &>/dev/null && echo 0 || echo 1)" -ne 0 ]; then
        echo_warn "There is no stack $stack in AWS CloudFormation"
        aws cloudformation deploy --template-file $templates/app-provisioner.template --stack-name $stack \
            --capabilities CAPABILITY_NAMED_IAM \
            --parameter-overrides "VPC=$vpc_id" \
            "PrivateSubnets=${vpc_private_subnets}" \
            "ExecutionRole=$exec_role" \
            "TaskRole=$task_role" \
            "Cluster=$ecs_cluster" \
            "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
            "BootstrapServers=$msk_info_brokers" \
            "PrivateNamespaceId=$ecs_private_ns"
    fi

    wait_stack_status_up $stack 50 1


}

create_vpc
create_msk_cluster
create_ecs_fargate
create_schema_registry
create_kafka_connect
#create_ssh
create_sftp
create_api
create_app_provisioner