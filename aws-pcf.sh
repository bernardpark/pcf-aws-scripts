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

ANY_CIDR="0.0.0.0/0"

OPSMAN_SG="pcf-ops-manager-security-group"
OPSMAN_SG_ID=""
OPSMAN_SG_DESC="Security Group for Ops Manager"

PCFVM_SG="pcf-vms-security-group"
PCFVM_SG_ID=""
PCFVM_SG_DESC="Security Group for PCF VMs"

WEBELB_SG="pcf-web-elb-security-group"
WEBELB_SG_ID=""
WEBELB_SG_DESC="Security Group for Web ELB"

SSHELB_SG="pcf-ssh-elb-security-group"
SSHELB_SG_ID=""
SSHELB_SG_DESC="Security Group for SSH ELB"

TCPELB_SG="pcf-tcp-elb-security-group"
TCPELB_SG_ID=""
TCPELB_SG_DESC="Security Group for TCP ELB"

OBDNAT_SG="pcf-nat-security-group"
OBDNAT_SG_ID=""
OBDNAT_SG_DESC="Security Group for Outbound NAT"

MYSQL_SG="MySQL"
MYSQL_SG_ID=""
MYSQL_SG_DESC="Security Group for MySQL"

# EC2
KEY_OPS_MAN="pcf-ops-manager-key"
NAT_INSTANCE="nat-instance"
NAT_INSTANCE_ID=""
NAT_INSTANCE_TYPE="t2.medium"
NAT_AMI="ami-bd6f59d8"
ENI_ID=""

#==============================================================================
#   Installation script below. Do not modify.
#==============================================================================

echo "*********************************************************************************************************"
echo "*** THIS SCRIPT WILL CONFIGURE AND USE YOUR AWS CLI. BEFORE YOU BEGIN MAKE SURE THIS SCRIPT IS SECURE ***"
echo "************************************ REQUIRES aws cli AND jw ********************************************"
echo "*********************************************************************************************************"
echo ""

# Configure AWS CLI (interactive)
aws configure

# Create S3 Buckets
echo "Creating S3 Buckets"
for BUCKET in "${BUCKETS[@]}"
do
  aws s3api create-bucket --bucket $BUCKET --region $REGION --create-bucket-configuration LocationConstraint=$REGION
  echo "Succesfully created $BUCKET in $REGION."
done

# Create IAM user
aws iam create-user --user-name $IAM_USER > pcf-user.json
echo "Succesfully created $IAM_USER."

aws iam create-access-key --user-name $IAM_USER > pcf-user-keys.json
echo "Succesfully created access keys for $IAM_USER."

aws iam put-user-policy --user-name $IAM_USER --policy-name $IAM_USER_POLICY --policy-document file://pcf-iam-policy.json
echo "Succesfully added inline policy for $IAM_USER."

# Create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.{VpcId:VpcId}' --output text --region $REGION)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC
echo "Successfully created VPC $VPC_ID named $VPC in $REGION."

# Create First Public Subnet
PUB_SN_AZ0_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUB_SN_AZ0_CIDR --availability-zone $SN_AZ0 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $PUB_SN_AZ0_ID --tags "Key=Name,Value=$PUB_SN_AZ0" --region $REGION
echo "Successfully created Subnet $PUB_SN_AZ0_ID named $PUB_SN_AZ0 in $SN_AZ0."

# Create First Private Subnet
PRI_SN_AZ0_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRI_SN_AZ0_CIDR --availability-zone $SN_AZ0 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $PRI_SN_AZ0_ID --tags "Key=Name,Value=$PRI_SN_AZ0" --region $REGION
echo "Successfully created Subnet $PRI_SN_AZ0_ID named $PRI_SN_AZ0 in $SN_AZ0."

# Create Internet gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text --region $REGION)
aws ec2 create-tags --resources $IGW_ID --tags "Key=Name,Value=$IGW" --region $REGION
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION
echo "Successfully created Internet Gateway $IGW_ID named $IGW attached to VPC $VPC_ID named $VPC."

# Create Route Table
RT_IGW_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.{RouteTableId:RouteTableId}' --output text --region $REGION)
aws ec2 create-tags --resources $RT_IGW_ID --tags "Key=Name,Value=$RT_IGW" --region $REGION
echo "Successfully created Route Table $RT_IGW_ID named $RT_IGW."

# Create route to Internet Gateway
RESULT=$(aws ec2 create-route --route-table-id $RT_IGW_ID --destination-cidr-block $RT_IGW_DEST_CIDR --gateway-id $IGW_ID --region $REGION)
echo "Successfully added route to $RT_IGW_DEST_CIDR in Route Table $RT_IGW_ID named $RT_IGW via Internet Gateway $IGW_ID named $IGW."

# Associate Public Subnet with Route Table
RESULT=$(aws ec2 associate-route-table --subnet-id $PUB_SN_AZ0_ID --route-table-id $RT_IGW_ID --region $REGION)
echo "Successfully associated Subnet $PUB_SN_AZ0_ID named $PUB_SN_AZ0 with Route Table $RT_IGW_ID named $RT_IGW."

# Enable Auto-assign Public IP on Public Subnet
aws ec2 modify-subnet-attribute --subnet-id $PUB_SN_AZ0_ID --map-public-ip-on-launch --region $REGION
echo "Successfully enabled 'Auto-assign Public IP' on Subnet $PUB_SN_AZ0_ID named $PUB_SN_AZ0."

# Allocate Elastic IP Address
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query '{AllocationId:AllocationId}' --output text --region $REGION)
aws ec2 create-tags --resources $EIP_ALLOC_ID --tags "Key=Name,Value=$EIP_ALLOC" --region $REGION
echo "Successfully allocated Elastic IP address $EIP_ALLOC_ID named $EIP_ALLOC."

# Create EC2 Key Pair
KEY_OPS_MAN_ID=$(aws ec2 create-key-pair --key-name $KEY_OPS_MAN)
echo "Successfully created ec2 key pair $KEY_OPS_MAN"

# Create NAT Instance
NAT_INSTANCE_ID=$(aws ec2 run-instances --image-id $NAT_AMI --count 1 --instance-type $NAT_INSTANCE_TYPE --key-name $KEY_OPS_MAN --subnet-id $PUB_SN_AZ0_ID --query 'Instances[].{InstanceId:InstanceId}' --output text)
aws ec2 create-tags --resources $NAT_INSTANCE_ID --tags "Key=Name,Value=$NAT_INSTANCE" --region $REGION
SECONDS=0
LAST_CHECK=0
STATE=""
until [[ "$STATE" == *RUNNING ]]; do
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
echo "Successfully created NAT Instance $NAT_INSTANCE_ID named $NAT_INSTANCE."

# Create Main Route Table route to NAT ENI
ENI_ID=$(aws ec2 describe-network-interfaces --filter Name=subnet-id,Values=$PUB_SN_AZ0_ID --query 'NetworkInterfaces[].{NetworkInterfaceId:NetworkInterfaceId}' --output text)
RT_MAIN_ID=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true --query 'RouteTables[*].{RouteTableId:RouteTableId}' --output text --region $REGION)
RESULT=$(aws ec2 create-route --route-table-id $RT_MAIN_ID --destination-cidr-block $RT_MAIN_DEST_CIDR --network-interface-id $ENI_ID --region $REGION)
echo "Successfully created route from $RT_MAIN_ID to NAT ENI $ENI_ID"

# Create Subsequent Public Subnets
PUB_SN_AZ1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUB_SN_AZ1_CIDR --availability-zone $SN_AZ1 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $PUB_SN_AZ1_ID --tags "Key=Name,Value=$PUB_SN_AZ1" --region $REGION
echo "Successfully created Subnet $PUB_SN_AZ1_ID named $PUB_SN_AZ1 in $SN_AZ1."

PUB_SN_AZ2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PUB_SN_AZ2_CIDR --availability-zone $SN_AZ2 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $PUB_SN_AZ2_ID --tags "Key=Name,Value=$PUB_SN_AZ2" --region $REGION
echo "Successfully created Subnet $PUB_SN_AZ2_ID named $PUB_SN_AZ2 in $SN_AZ2."

PRI_SN_AZ1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRI_SN_AZ1_CIDR --availability-zone $SN_AZ1 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $PRI_SN_AZ1_ID --tags "Key=Name,Value=$PRI_SN_AZ1" --region $REGION
echo "Successfully created Subnet $PRI_SN_AZ1_ID named $PRI_SN_AZ1 in $SN_AZ1."

PRI_SN_AZ2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $PRI_SN_AZ2_CIDR --availability-zone $SN_AZ2 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $PRI_SN_AZ2_ID --tags "Key=Name,Value=$PRI_SN_AZ2" --region $REGION
echo "Successfully created Subnet $PRI_SN_AZ2_ID named $PRI_SN_AZ2 in $SN_AZ2."

ERT_SN_AZ0_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $ERT_SN_AZ0_CIDR --availability-zone $SN_AZ0 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $ERT_SN_AZ0_ID --tags "Key=Name,Value=$ERT_SN_AZ0" --region $REGION
echo "Successfully created Subnet $ERT_SN_AZ0_ID named $ERT_SN_AZ0 in $SN_AZ0."

ERT_SN_AZ1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $ERT_SN_AZ1_CIDR --availability-zone $SN_AZ1 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $ERT_SN_AZ1_ID --tags "Key=Name,Value=$ERT_SN_AZ1" --region $REGION
echo "Successfully created Subnet $ERT_SN_AZ1_ID named $ERT_SN_AZ1 in $SN_AZ1."

ERT_SN_AZ2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $ERT_SN_AZ2_CIDR --availability-zone $SN_AZ2 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $ERT_SN_AZ2_ID --tags "Key=Name,Value=$ERT_SN_AZ2" --region $REGION
echo "Successfully created Subnet $ERT_SN_AZ2_ID named $ERT_SN_AZ2 in $SN_AZ2."

SVC_SN_AZ0_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SVC_SN_AZ0_CIDR --availability-zone $SN_AZ0 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $SVC_SN_AZ0_ID --tags "Key=Name,Value=$SVC_SN_AZ0" --region $REGION
echo "Successfully created Subnet $SVC_SN_AZ0_ID named $SVC_SN_AZ0 in $SN_AZ0."

SVC_SN_AZ1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SVC_SN_AZ1_CIDR --availability-zone $SN_AZ1 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $SVC_SN_AZ1_ID --tags "Key=Name,Value=$SVC_SN_AZ1" --region $REGION
echo "Successfully created Subnet $SVC_SN_AZ1_ID named $SVC_SN_AZ1 in $SN_AZ1."

SVC_SN_AZ2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SVC_SN_AZ2_CIDR --availability-zone $SN_AZ2 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $SVC_SN_AZ2_ID --tags "Key=Name,Value=$SVC_SN_AZ2" --region $REGION
echo "Successfully created Subnet $SVC_SN_AZ2_ID named $SVC_SN_AZ2 in $SN_AZ2."

RDS_SN_AZ0_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $RDS_SN_AZ0_CIDR --availability-zone $SN_AZ0 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $RDS_SN_AZ0_ID --tags "Key=Name,Value=$RDS_SN_AZ0" --region $REGION
echo "Successfully created Subnet $RDS_SN_AZ0_ID named $RDS_SN_AZ0 in $SN_AZ0."

RDS_SN_AZ1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $RDS_SN_AZ1_CIDR --availability-zone $SN_AZ1 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $RDS_SN_AZ1_ID --tags "Key=Name,Value=$RDS_SN_AZ1" --region $REGION
echo "Successfully created Subnet $RDS_SN_AZ1_ID named $RDS_SN_AZ1 in $SN_AZ1."

RDS_SN_AZ2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $RDS_SN_AZ2_CIDR --availability-zone $SN_AZ2 --query 'Subnet.{SubnetId:SubnetId}' --output text --region $REGION)
aws ec2 create-tags --resources $RDS_SN_AZ2_ID --tags "Key=Name,Value=$RDS_SN_AZ2" --region $REGION
echo "Successfully created Subnet $RDS_SN_AZ2_ID named $RDS_SN_AZ2 in $SN_AZ2."

# Create and configure Security Group for Ops Manager
OPSMAN_SG_ID=$(aws ec2 create-security-group --group-name $OPSMAN_SG --description "$OPSMAN_SG_DESC" --vpc-id $VPC_ID --query '{GroupId:GroupId}' --output text)
aws ec2 authorize-security-group-ingress --group-id $OPSMAN_SG_ID --protocol tcp --port 80 --cidr $MY_CIDR
aws ec2 authorize-security-group-ingress --group-id $OPSMAN_SG_ID --protocol tcp --port 443 --cidr $MY_CIDR
aws ec2 authorize-security-group-ingress --group-id $OPSMAN_SG_ID --protocol tcp --port 22 --cidr $MY_CIDR
aws ec2 authorize-security-group-ingress --group-id $OPSMAN_SG_ID --protocol tcp --port 6868 --cidr $VPC_CIDR
aws ec2 authorize-security-group-ingress --group-id $OPSMAN_SG_ID --protocol tcp --port 25555 --cidr $VPC_CIDR
echo "Successfully created and configured Security Group $OPSMAN_SG_ID named $OPSMAN_SG in $VPC_ID."

# Create and configure Security Group for PCF VMS
PCFVM_SG_ID=$(aws ec2 create-security-group --group-name $PCFVM_SG --description "$PCFVM_SG_DESC" --vpc-id $VPC_ID --query '{GroupId:GroupId}' --output text)
aws ec2 authorize-security-group-ingress --group-id $PCFVM_SG_ID --protocol all --port -1 --cidr $VPC_CIDR
echo "Successfully created and configured Security Group $PCFVM_SG_ID named $PCFVM_SG in $VPC_ID."

# Create and configure Security Group for Web ELB
WEBELB_SG_ID=$(aws ec2 create-security-group --group-name $WEBELB_SG --description "$WEBELB_SG_DESC" --vpc-id $VPC_ID --query '{GroupId:GroupId}' --output text)
aws ec2 authorize-security-group-ingress --group-id $WEBELB_SG_ID --protocol tcp --port 4443 --cidr $ANY_CIDR
aws ec2 authorize-security-group-ingress --group-id $WEBELB_SG_ID --protocol tcp --port 80 --cidr $ANY_CIDR
aws ec2 authorize-security-group-ingress --group-id $WEBELB_SG_ID --protocol tcp --port 443 --cidr $ANY_CIDR
echo "Successfully created and configured Security Group $WEBELB_SG_ID named $WEBELB_SG in $VPC_ID."

# Create and configure Security Group for SSH ELB
SSHELB_SG_ID=$(aws ec2 create-security-group --group-name $SSHELB_SG --description "$SSHELB_SG_DESC" --vpc-id $VPC_ID --query '{GroupId:GroupId}' --output text)
aws ec2 authorize-security-group-ingress --group-id $SSHELB_SG_ID --protocol tcp --port 2222 --cidr $ANY_CIDR
echo "Successfully created and configured Security Group $SSHELB_SG_ID named $SSHELB_SG in $VPC_ID."

# Create and configure Security Group for TCP ELB
TCPELB_SG_ID=$(aws ec2 create-security-group --group-name $TCPELB_SG --description "$TCPELB_SG_DESC" --vpc-id $VPC_ID --query '{GroupId:GroupId}' --output text)
aws ec2 authorize-security-group-ingress --group-id $TCPELB_SG_ID --protocol tcp --port 1024-1123 --cidr $ANY_CIDR
echo "Successfully created and configured Security Group $TCPELB_SG_ID named $TCPELB_SG in $VPC_ID."

# Create and configure Security Group for Outbound NAT
OBDNAT_SG_ID=$(aws ec2 create-security-group --group-name $OBDNAT_SG --description "$OBDNAT_SG_DESC" --vpc-id $VPC_ID --query '{GroupId:GroupId}' --output text)
aws ec2 authorize-security-group-ingress --group-id $OBDNAT_SG_ID --protocol all --port -1 --cidr $VPC_CIDR
echo "Successfully created and configured Security Group $OBDNAT_SG_ID named $OBDNAT_SG in $VPC_ID."

# Create and configure Security Group for Outbound NAT
MYSQL_SG_ID=$(aws ec2 create-security-group --group-name $MYSQL_SG --description "$MYSQL_SG_DESC" --vpc-id $VPC_ID --query '{GroupId:GroupId}' --output text)
aws ec2 authorize-security-group-ingress --group-id $MYSQL_SG_ID --protocol tcp --port 3306 --cidr $VPC_CIDR
aws ec2 authorize-security-group-egress --group-id $MYSQL_SG_ID --protocol all --port -1 --cidr $VPC_CIDR
echo "Successfully created and configured Security Group $MYSQL_SG_ID named $MYSQL_SG in $VPC_ID."

echo "COMPLETED"
exit 0
