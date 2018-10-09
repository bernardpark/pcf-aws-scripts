#!/bin/bash
#******************************************************************************
#    AWS PCF Installation Script
#******************************************************************************i
#
# DESCRIPTION
#    Automates PCF Installation on AWS using the AWS CLI.
#
#
#==============================================================================
#   Modify variables below as needed
#==============================================================================

# Misc. Variables
RESULT=""

# AWS Region. Make sure this matches the region you configure with 'aws configure'
REGION="us-east-2"

# S3 Buckets. Make sure these are unique.
declare -a BUCKETS=("bpark-pcf-ops-manager-bucket" "bpark-pcf-buildpacks-bucket" "bpark-pcf-packages-bucket" "bpark-pcf-resources-bucket" "bpark-pcf-droplets-bucket")

# IAM
IAM_USER="pcf-user"
IAM_USER_POLICY="pcf-iam-policy"

# VPC, Initial Subnets, Internet Gateway, Route Tables, Elastic IP, NAT
VPC="pcf-vpc"
VPC_ID=""
VPC_CIDR="10.0.0.0/16"

SN_AZ0="us-east-2a"
PUB_SN_AZ0="pcf-public-subnet-az0"
PUB_SN_AZ0_ID=""
PUB_SN_AZ0_CIDR="10.0.0.0/24"
PRI_SN_AZ0="pcf-management-subnet-az0"
PRI_SN_AZ0_ID=""
PRI_SN_AZ0_CIDR="10.0.16.0/28"

IGW="pcf-internet-gateway"
IGW_ID=""

RT_IGW="rt_igw"
RT_IGW_ID=""
RT_IGW_DEST_CIDR="0.0.0.0/0"

RT_MAIN="rt_main"
RT_MAIN_ID=""
RT_MAIN_DEST_CIDR="0.0.0.0/0"

EIP_ALLOC="eipalloc_nat"
EIP_ALLOC_ID=""

# Additional Subnets
ERT_SN_AZ0="pcf-ert-subnet-az0"
ERT_SN_AZ0_ID=""
ERT_SN_AZ0_CIDR="10.0.4.0/24"
SVC_SN_AZ0="pcf-services-subnet-az0"
SVC_SN_AZ0_ID=""
SVC_SN_AZ0_CIDR="10.0.8.0/24"
RDS_SN_AZ0="pcf-rds-subnet-az0"
RDS_SN_AZ0_ID=""
RDS_SN_AZ0_CIDR="10.0.12.0/24"

SN_AZ1="us-east-2b"
PUB_SN_AZ1="pcf-public-subnet-az1"
PUB_SN_AZ1_ID=""
PUB_SN_AZ1_CIDR="10.0.1.0/24"
PRI_SN_AZ1="pcf-management-subnet-az1"
PRI_SN_AZ1_ID=""
PRI_SN_AZ1_CIDR="10.0.16.16/28"
ERT_SN_AZ1="pcf-ert-subnet-az1"
ERT_SN_AZ1_ID=""
ERT_SN_AZ1_CIDR="10.0.5.0/24"
SVC_SN_AZ1="pcf-services-subnet-az1"
SVC_SN_AZ1_ID=""
SVC_SN_AZ1_CIDR="10.0.9.0/24"
RDS_SN_AZ1="pcf-rds-subnet-az1"
RDS_SN_AZ1_ID=""
RDS_SN_AZ1_CIDR="10.0.13.0/24"

SN_AZ2="us-east-2c"
PUB_SN_AZ2="pcf-public-subnet-az2"
PUB_SN_AZ2_ID=""
PUB_SN_AZ2_CIDR="10.0.2.0/24"
PRI_SN_AZ2="pcf-management-subnet-az2"
PRI_SN_AZ2_ID=""
PRI_SN_AZ2_CIDR="10.0.16.32/28"
ERT_SN_AZ2="pcf-ert-subnet-az2"
ERT_SN_AZ2_ID=""
ERT_SN_AZ2_CIDR="10.0.6.0/24"
SVC_SN_AZ2="pcf-services-subnet-az2"
SVC_SN_AZ2_ID=""
SVC_SN_AZ2_CIDR="10.0.10.0/24"
RDS_SN_AZ2="pcf-rds-subnet-az2"
RDS_SN_AZ2_ID=""
RDS_SN_AZ2_CIDR="10.0.14.0/24"

# Security Groups
MY_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
MY_IP_END="/32"
MY_CIDR="$MY_IP$MY_IP_END"

OPSMAN_SG="pcf-ops-manager-security-group"
OPSMAN_SG_ID=""
OPSMAN_SG_DESC="Security Group for Ops Manager"

PCFVM_SG="pcf-vms-security-group"
PCFVM_SG_ID=""
PCFVM_SG_DESC="Security Group for PCF VMs"

# EC2
KEY_OPS_MAN="pcf-ops-manager-key"
NAT_INSTANCE="nat-instance"
NAT_INSTANCE_ID=""
NAT_INSTANCE_TYPE="t2.medium"
NAT_AMI="ami-bd6f59d8"
ENI_ID=""

#==============================================================================
#   Functions below. Do not modify.
#==============================================================================

# S3 cleanup
s3_cleanup()
{
  echo "CLEANING UP BUCKETS"
  for BUCKET in "${BUCKETS[@]}"
  do
    aws s3api delete-bucket --bucket $BUCKET --region $REGION
    if [[ $? == 0 ]] ;
    then
      echo "Succesfully deleted $BUCKET."
    fi
  done
}

# IAM cleanup
iam_cleanup()
{
  echo "CLEANING UP IAM"
  aws iam delete-user-policy --user-name $IAM_USER --policy-name $IAM_USER_POLICY
  if [[ $? == 0 ]] ;
  then
    echo "Successfully deleted $IAM_USER_POLICY for $IAM_USER"
  fi

  RESULT=$(cat pcf-user-keys.json | jq -r '.AccessKey.AccessKeyId')
  aws iam delete-access-key --access-key $RESULT --user-name $IAM_USER
  if [[ $? == 0 ]] ;
  then
    echo "Successfully deleted access keys for $IAM_USER"
  fi

  aws iam delete-user --user-name $IAM_USER
  if [[ $? == 0 ]] ;
  then
    echo "Successfully deleted $IAM_USER"
  fi
}

# EIP cleanup
eip_cleanup()
{
  echo "CLEANING UP EIP"
  RESULT=$(aws ec2 describe-addresses --filter Name=tag:Name,Values=$EIP_ALLOC --query 'Addresses[].{AllocationId:AllocationId}' --output text)
  while read -r LINE; do
    aws ec2 release-address --allocation-id $LINE
    if [[ $? == 0 ]] ;
    then
      echo "Successfully deleted $LINE"
    fi
  done <<< "$RESULT"
}

# VPC cleanup
vpc_cleanup()
{
  echo "CLEANING UP VPC"

  RESULT=$(aws ec2 describe-vpcs --filter Name=tag:Name,Values=$VPC --query 'Vpcs[].{VpcId:VpcId}' --output text)
  while read -r LINE; do
    RESULT_SUBNET=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=$LINE --query 'Subnets[].{SubnetId:SubnetId}' --output text)
    while read -r LINE_SUBNET; do
      aws ec2 delete-subnet --subnet-id $LINE_SUBNET
      if [[ $? == 0 ]] ;
      then
        echo "  Successfully deleted $LINE_SUBNET"
      fi
    done <<< "$RESULT_SUBNET"

    RESULT_RT=$(aws ec2 describe-route-tables --filter Name=vpc-id,Values=$LINE --query 'RouteTables[].{RouteTableId:RouteTableId}' --output text)
    while read -r LINE_RT; do
      aws ec2 delete-route-table --route-table-id $LINE_RT
      if [[ $? == 0 ]] ;
      then
        echo "  Successfully deleted $LINE_RT"
      fi
    done <<< "$RESULT_RT"

    RESULT_IGW=$(aws ec2 describe-internet-gateways --filter Name=attachment.vpc-id,Values=$LINE --query 'InternetGateways[].{InternetGatewayId:InternetGatewayId}' --output text)
    while read -r LINE_IGW; do
      aws ec2 detach-internet-gateway --internet-gateway-id $LINE_IGW
      aws ec2 delete-internet-gateway --internet-gateway-id $LINE_IGW
      if [[ $? == 0 ]] ;
      then
        echo "  Successfully deleted $LINE_IGW"
      fi
    done <<< "$RESULT_IGW"

    RESULT_ACL=$(aws ec2 describe-network-acls --filter Name=vpc-id,Values=$LINE --query 'NetworkAcls[].{NetworkAclId:NetworkAclId}' --output text)
    while read -r LINE_ACL; do
      aws ec2 delete-network-acl --network-acl-id $LINE_ACL
      if [[ $? == 0 ]] ;
      then
        echo "  Successfully deleted $LINE_ACL"
      fi
    done <<< "$RESULT_ACL"

    RESULT_SEC_GROUP=$(aws ec2 describe-security-groups --filter Name=vpc-id,Values=$LINE --query 'SecurityGroups[].{GroupId:GroupId}' --output text)
    while read -r LINE_SEC_GROUP; do
      aws ec2 delete-security-group --group-id $LINE_SEC_GROUP
      if [[ $? == 0 ]] ;
      then
        echo "  Successfully deleted $LINE_SEC_GROUP"
      fi
    done <<< "$RESULT_SEC_GROUP"
    aws ec2 delete-vpc --vpc-id $LINE
    if [[ $? == 0 ]] ;
    then
      echo "Successfully deleted $LINE"
    fi
  done <<< "$RESULT"  
}

# NAT EC2 Cleanup
nat_cleanup()
{
  echo "CLEANING UP EC2 NAT INSTANCE"
  RESULT=$(aws ec2 describe-instances --filter Name=tag:Name,Values=$NAT_INSTANCE --query 'Reservations[].Instances[].{InstanceId:InstanceId}' --output text)
  while read -r LINE; do
    aws ec2 terminate-instances --instance-ids $LINE
    SECONDS=0
    LAST_CHECK=0
    STATE=""
    until [[ "$STATE" == *TERMINATED ]]; do
      INTERVAL=$SECONDS-$LAST_CHECK
      if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
        STATE=$(aws ec2 describe-instances --instance-ids $LINE --query 'Reservations[].Instances[].{State:State}'  --output text --region $REGION)
        STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
        LAST_CHECK=$SECONDS
      fi
      SECS=$SECONDS
      STATUS_MSG=$(printf $FORMATTED_MSG $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
      printf "    $STATUS_MSG\033[0K\r"
      sleep 1
    done

    if [[ $? == 0 ]] ;
    then
      echo "Successfully deleted $LINE"
    fi
  done <<< "$RESULT"
}

# EC2 Keypair Cleanup
kp_cleanup()
{
  aws ec2 delete-key-pair --key-name $KEY_OPS_MAN
  if [[ $? == 0 ]] ;
  then
    echo "Successfully deleted $KEY_OPS_MAN"
  fi
}

# Cleanup all
cleanup()
{
  kp_cleanup
  nat_cleanup
  vpc_cleanup
  eip_cleanup
  iam_cleanup
  s3_cleanup
  exit 0
}

#==============================================================================
#   Teardown script below. Do not modify.
#==============================================================================

echo "*********************************************************************************************************"
echo "*** THIS SCRIPT WILL CONFIGURE AND USE YOUR AWS CLI. BEFORE YOU BEGIN MAKE SURE THIS SCRIPT IS SECURE ***"
echo "************************************ REQUIRES aws cli AND jw ********************************************"
echo "*********************************************************************************************************"
echo ""

cleanup
exit 0

