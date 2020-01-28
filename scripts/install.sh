#!/bin/bash

# This script is intended to deploy all templates by manually

# ---- Configuration
env=manual
msk_instance_type=kafka.m5.large

# ---- Body
scripts="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
templates=${scripts}/../templates

# Create VPC
vpc_stack="VPC-${env}"

aws cloudformation deploy --template-file $templates/vpc.template --stack-name $vpc_stack --parameter-overrides "EnvironmentName=$env"

vpc_meta=$(aws cloudformation describe-stacks --stack-name $vpc_stack)
vpc_id=$(echo $vpc_meta | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "VPC") | .OutputValue')
vpc_private_subnets=$(echo $vpc_meta | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PrivateSubnets") | .OutputValue')
vpc_public_subnets=$(echo $vpc_meta | jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "PublicSubnets") | .OutputValue')


# Create security groups
msk_sg_stack="MSK-SG-${env}"

aws cloudformation deploy --template-file $templates/msk-sg.template --stack-name $msk_sg_stack \
    --parameter-overrides "EnvironmentName=$env" "VPC=$vpc_id"

msk_sg_meta=$(aws cloudformation describe-stacks --stack-name $msk_sg_stack)
msk_sg_security_group_id=$(echo $msk_sg_meta |jq -r '.Stacks[0].Outputs[] | select(.OutputKey == "MSKSecurityGroupID") | .OutputValue')

# Create MSK Cluster
msk_stack="MSK-${env}"

aws cloudformation deploy --template-file $templates/msk.template --stack-name $msk_stack \
    --parameter-overrides "EnvironmentName=$env" "VPC=$vpc_id" "ClientSubnets=${vpc_private_subnets}" \
        "InstanceType=$msk_instance_type" "MSKSecurityGroupID=$msk_sg_security_group_id"


ecs_stack="ECS-${env}"
aws cloudformation deploy --template-file $templates/ecs.template --stack-name $ecs_stack \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides "EnvironmentName=$env" "VPC=$vpc_id"


alb_stack="ALB-${env}"
aws cloudformation deploy --template-file $templates/alb.template --stack-name $alb_stack \
    --parameter-overrides "EnvironmentName=$env" "VPC=$vpc_id" "VpcPublicSubnets=${vpc_public_subnets}"
