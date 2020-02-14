#!/bin/bash
# This script is intended to deploy all templates by hands
# without using a "parent" stack.

# ---- Configuration
env=${1:-man}
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

msk_meta=$(aws cloudformation describe-stacks --stack-name $msk_stack)
msk_arn=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MSKClusterArn") | .OutputValue')
msk_info_brokers=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MskBrokers") | .OutputValue')
#msk_info_brokers_tls=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MskBrokersTls") | .OutputValue')
msk_info_zookeepers=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MskZookeepers") | .OutputValue')
msk_info_client_group_id=$(echo $msk_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "KafkaClientInstanceSecurityGroupID") | .OutputValue')


ecs_stack="ECS-${env}"
#aws cloudformation deploy --template-file $templates/ecs-fargate.template --stack-name $ecs_stack \
#    --capabilities CAPABILITY_NAMED_IAM \
#    --parameter-overrides "VPC=$vpc_id" \
#    "PrivateSubnets=${vpc_private_subnets}" "PublicSubnets=${vpc_public_subnets}" \
#    "EnvironmentName=$env" \
#    "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
#    "BootstrapServers=$msk_info_brokers" \
#    "ZookeeperServers=$msk_info_zookeepers"


ecs_meta=$(aws cloudformation describe-stacks --stack-name $ecs_stack)
exec_role=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "ExecutionRole") | .OutputValue')
task_role=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "TaskRole") | .OutputValue')
ecs_cluster=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "Cluster") | .OutputValue')
ecs_private_ns=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PrivateNamespaceId") | .OutputValue')
ecs_autoscaling_role=$(echo $ecs_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "AutoScalingRole") | .OutputValue')

ecs_task="SchemaRegistry-${env}"
#aws cloudformation deploy --template-file $templates/schema-registry.template --stack-name $ecs_task \
#    --capabilities CAPABILITY_NAMED_IAM \
#    --parameter-overrides "VPC=$vpc_id" \
#    "PrivateSubnets=${vpc_private_subnets}" \
#    "ExecutionRole=$exec_role" \
#    "TaskRole=$task_role" \
#    "Cluster=$ecs_cluster" \
#    "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
#    "BootstrapServers=$msk_info_brokers" \
#    "ZookeeperServers=$msk_info_zookeepers" \
#    "PrivateNamespaceId=$ecs_private_ns"

ecs_task="KafkaConnect-${env}"
#aws cloudformation deploy --template-file $templates/kafka-connect.template --stack-name $ecs_task \
#    --capabilities CAPABILITY_NAMED_IAM \
#    --parameter-overrides "VPC=$vpc_id" \
#    "PrivateSubnets=${vpc_private_subnets}" \
#    "ExecutionRole=$exec_role" \
#    "TaskRole=$task_role" \
#    "Cluster=$ecs_cluster" \
#    "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
#    "BootstrapServers=$msk_info_brokers" \
#    "ZookeeperServers=$msk_info_zookeepers" \
#    "PrivateNamespaceId=$ecs_private_ns"

ecs_task="SSH-${env}"
#aws cloudformation deploy --template-file $templates/ssh.template --stack-name $ecs_task \
#    --capabilities CAPABILITY_NAMED_IAM \
#    --parameter-overrides "VPC=$vpc_id" \
#    "PrivateSubnets=${vpc_public_subnets}" \
#    "ExecutionRole=$exec_role" \
#    "TaskRole=$task_role" \
#    "Cluster=$ecs_cluster" \
#    "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
#    "BootstrapServers=$msk_info_brokers" \
#    "ZookeeperServers=$msk_info_zookeepers" \
#    "PrivateNamespaceId=$ecs_private_ns"

sftp_stack="SFTP-${env}"
#aws cloudformation deploy --template-file $templates/sftp.template --stack-name $sftp_stack \
#    --capabilities CAPABILITY_NAMED_IAM \
#    --parameter-overrides \
#    "EnvironmentName=$env" \
#    "PublicSshKey=ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAsRe9vcYiSmTz9tBMQMxC/Y5d+QlJml01OQu4ovJihFTnG98/k7MajOM/AWp7+AK5rWNrcVCwtp+KR0KJXmxlsO2AM6bt124yacd0YRmn6W/sgDZUZT9eG0RvGmzyRUL6aHi9oNcyBJ5mzIWnfiJHc8BX9j0mX2x2nejo3Pmq4Xy97x2McFA253vZ0Yba8aW+XcLlSNpHLHZSdH0G/nDAZLTC0q5I/Tnl7GF4LILXbkdHIRLG2cUg+aQYZeJkW6XtKFeGIb02KjhqRFYcfTGvcUJbTlSS6ydU3pa0iigm2n6K6wmbJ16oIHUMiTBznfK8Q30+PneojXW8TgFYUYZLIQ== ags@localhost.localdomain"

set -x

api_task="API-${env}"
aws cloudformation deploy --template-file $templates/kafka-swagger-rest.template --stack-name $api_task \
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

provision_task="Provision-${env}"
aws cloudformation deploy --template-file $templates/app-provisioner.template --stack-name $provision_task \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides "VPC=$vpc_id" \
    "PrivateSubnets=${vpc_private_subnets}" \
    "ExecutionRole=$exec_role" \
    "TaskRole=$task_role" \
    "Cluster=$ecs_cluster" \
    "KafkaClientInstanceSecurityGroup=$msk_info_client_group_id" \
    "BootstrapServers=$msk_info_brokers" \
    "PrivateNamespaceId=$ecs_private_ns"
