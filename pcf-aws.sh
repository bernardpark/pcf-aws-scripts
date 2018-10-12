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
IAM_USER_JSON="pcf-user.json"
IAM_USER_KEYS_JSON="pcf-user-keys.json"

IAM_ROLE="pcf-role"
IAM_ROLE_POLICY="pcf-iam-role-trust-policy"

IAM_PROFILE="pcf-profile"

# VPC, Initial Subnets, Internet Gateway, Route Tables, Elastic IP, NAT
VPC="pcf-vpc"
VPC_CIDR="10.0.0.0/16"

SN_AZ0="us-east-2a"
PUB_SN_AZ0="pcf-public-subnet-az0"
PUB_SN_AZ0_CIDR="10.0.0.0/24"
PRI_SN_AZ0="pcf-management-subnet-az0"
PRI_SN_AZ0_CIDR="10.0.16.0/28"

IGW="pcf-internet-gateway"

RT_IGW="rt_igw"
RT_IGW_DEST_CIDR="0.0.0.0/0"

RT_MAIN="rt_main"
RT_MAIN_DEST_CIDR="0.0.0.0/0"

# Additional Subnets
ERT_SN_AZ0="pcf-ert-subnet-az0"
ERT_SN_AZ0_CIDR="10.0.4.0/24"
SVC_SN_AZ0="pcf-services-subnet-az0"
SVC_SN_AZ0_CIDR="10.0.8.0/24"
RDS_SN_AZ0="pcf-rds-subnet-az0"
RDS_SN_AZ0_CIDR="10.0.12.0/24"

SN_AZ1="us-east-2b"
PUB_SN_AZ1="pcf-public-subnet-az1"
PUB_SN_AZ1_CIDR="10.0.1.0/24"
PRI_SN_AZ1="pcf-management-subnet-az1"
PRI_SN_AZ1_CIDR="10.0.16.16/28"
ERT_SN_AZ1="pcf-ert-subnet-az1"
ERT_SN_AZ1_CIDR="10.0.5.0/24"
SVC_SN_AZ1="pcf-services-subnet-az1"
SVC_SN_AZ1_CIDR="10.0.9.0/24"
RDS_SN_AZ1="pcf-rds-subnet-az1"
RDS_SN_AZ1_CIDR="10.0.13.0/24"

SN_AZ2="us-east-2c"
PUB_SN_AZ2="pcf-public-subnet-az2"
PUB_SN_AZ2_CIDR="10.0.2.0/24"
PRI_SN_AZ2="pcf-management-subnet-az2"
PRI_SN_AZ2_CIDR="10.0.16.32/28"
ERT_SN_AZ2="pcf-ert-subnet-az2"
ERT_SN_AZ2_CIDR="10.0.6.0/24"
SVC_SN_AZ2="pcf-services-subnet-az2"
SVC_SN_AZ2_CIDR="10.0.10.0/24"
RDS_SN_AZ2="pcf-rds-subnet-az2"
RDS_SN_AZ2_CIDR="10.0.14.0/24"

# Security Groups
MY_IP="$(curl -s http://whatismyip.akamai.com)"
MY_IP_END="/32"
MY_CIDR="$MY_IP$MY_IP_END"

ANY_CIDR="0.0.0.0/0"

OPSMAN_SG="pcf-ops-manager-security-group"
OPSMAN_SG_DESC="Security Group for Ops Manager"

PCFVM_SG="pcf-vms-security-group"
PCFVM_SG_DESC="Security Group for PCF VMs"

WEBELB_SG="pcf-web-elb-security-group"
WEBELB_SG_DESC="Security Group for Web ELB"

SSHELB_SG="pcf-ssh-elb-security-group"
SSHELB_SG_DESC="Security Group for SSH ELB"

TCPELB_SG="pcf-tcp-elb-security-group"
TCPELB_SG_DESC="Security Group for TCP ELB"

OBDNAT_SG="pcf-nat-security-group"
OBDNAT_SG_DESC="Security Group for Outbound NAT"

MYSQL_SG="pcf-rds-security-group"
MYSQL_SG_DESC="Security Group for MySQL"

# EC2
KEY_OPS_MAN="pcf-ops-manager-key"

NAT_INSTANCE="pcf-nat"
NAT_INSTANCE_TYPE="t2.medium"
NAT_AMI="ami-bd6f59d8"

OPSMAN_INSTANCE="pcf-ops-manager"
OPSMAN_INSTANCE_TYPE="m5.large"
OPSMAN_AMI="ami-0af8611563c4da56c"

# Certificates
SSL_CERT_ARN="arn:aws:acm:us-east-2:008788954475:certificate/aceed5fc-98a9-4f89-8dfe-7aa06219695f"

# Load Balancers
WEB_ELB="pcf-web-elb"
WEB_ELB_L0="Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80,SSLCertificateId=$SSL_CERT_ARN"
WEB_ELB_L1="Protocol=HTTPS,LoadBalancerPort=443,InstanceProtocol=HTTP,InstancePort=80,SSLCertificateId=$SSL_CERT_ARN"
WEB_ELB_L2="Protocol=SSL,LoadBalancerPort=4443,InstanceProtocol=TCP,InstancePort=80,SSLCertificateId=$SSL_CERT_ARN"

SSH_ELB="pcf-ssh-elb"
SSH_ELB_L0="Protocol=TCP,LoadBalancerPort=2222,InstanceProtocol=TCP,InstancePort=2222"

TCP_ELB="pcf-tcp-elb"
TCP_ELB_L0="Protocol=TCP,LoadBalancerPort=1024,InstanceProtocol=TCP,InstancePort=1024"

# Route53
ZONE_ID="Z3ISWYVRXCVRDH"
ZONE_DOMAIN="pcfbpark.com"

ZONE_UPDATE_TEMPLATE="pcf-zone-records-template.json"
ZONE_UPDATE_JSON="pcf-zone-records.json"

APP_DOMAIN="apps.$ZONE_DOMAIN"
SYS_DOMAIN="system.$ZONE_DOMAIN"
SSH_DOMAIN="ssh.$ZONE_DOMAIN"
TCP_DOMAIN="tcp.$ZONE_DOMAIN"
PCF_DOMAIN="pcf.$ZONE_DOMAIN"

# RDS
RDS_SN_GRP="pcf-rds-subnet-group"
RDS_SN_GRP_DESC="RDS Subnet Group for PCF"
RDS_ID="pcf-ops-manager-director"
RDS_CLASS="db.m4.large"
RDS_NAME="bosh"

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
echo ""

# Create S3 Buckets
echo "Creating S3 Buckets"
for BUCKET in "${BUCKETS[@]}"
do
  aws s3api create-bucket \
    --bucket $BUCKET \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION
  echo "Successfully created $BUCKET in $REGION."
done

# Create IAM user
aws iam create-user \
  --user-name $IAM_USER \
  > $IAM_USER_JSON
echo "Successfully created $IAM_USER."

aws iam create-access-key \
  --user-name $IAM_USER \
  > $IAM_USER_KEYS_JSON
echo "Successfully created access keys for $IAM_USER."

aws iam put-user-policy \
  --user-name $IAM_USER \
  --policy-name $IAM_USER_POLICY \
  --policy-document file://$IAM_USER_POLICY.json
echo "Successfully added inline policy for $IAM_USER."

aws iam create-role \
  --role-name $IAM_ROLE \
  --assume-role-policy-document file://$IAM_ROLE_POLICY.json
echo "Successfully created role for $IAM_ROLE."

# Create IAM instance profile
IAM_PROFILE_ID=$(aws iam create-instance-profile \
  --instance-profile-name $IAM_PROFILE \
  --query 'InstanceProfile.{InstanceProfileId:InstanceProfileId}' \
  --output text)
aws iam add-role-to-instance-profile \
  --role-name $IAM_ROLE \
  --instance-profile-name $IAM_PROFILE

# Create VPC
VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --region $REGION \
  --query 'Vpc.{VpcId:VpcId}' \
  --output text)
aws ec2 create-tags \
  --resources $VPC_ID \
  --tags Key=Name,Value=$VPC
echo "Successfully created VPC $VPC in $REGION."

# Create First Public Subnet
PUB_SN_AZ0_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUB_SN_AZ0_CIDR \
  --availability-zone $SN_AZ0 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $PUB_SN_AZ0_ID \
  --region $REGION \
  --tags "Key=Name,Value=$PUB_SN_AZ0"
echo "Successfully created Subnet $PUB_SN_AZ0 in $SN_AZ0."

# Create First Private Subnet
PRI_SN_AZ0_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRI_SN_AZ0_CIDR \
  --availability-zone $SN_AZ0 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $PRI_SN_AZ0_ID \
  --tags "Key=Name,Value=$PRI_SN_AZ0" \
  --region $REGION
echo "Successfully created Subnet $PRI_SN_AZ0 in $SN_AZ0."

# Create Internet gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --region $REGION \
  --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
  --output text)
aws ec2 create-tags \
  --resources $IGW_ID \
  --region $REGION \
  --tags "Key=Name,Value=$IGW"
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $IGW_ID \
  --region $REGION
echo "Successfully created Internet Gateway $IGW attached to VPC $VPC."

# Create Route Table
RT_IGW_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'RouteTable.{RouteTableId:RouteTableId}' \
  --output text)
aws ec2 create-tags \
  --resources $RT_IGW_ID \
  --tags "Key=Name,Value=$RT_IGW" \
  --region $REGION
echo "Successfully created Route Table $RT_IGW."

# Create route to Internet Gateway
aws ec2 create-route \
  --route-table-id $RT_IGW_ID \
  --destination-cidr-block $RT_IGW_DEST_CIDR \
  --gateway-id $IGW_ID \
  --region $REGION
echo "Successfully added route to $RT_IGW_DEST_CIDR in Route Table $RT_IGW via Internet Gateway $IGW."

# Associate Public Subnet with Route Table
aws ec2 associate-route-table \
  --subnet-id $PUB_SN_AZ0_ID \
  --route-table-id $RT_IGW_ID \
  --region $REGION
echo "Successfully associated Subnet $PUB_SN_AZ0 with Route Table $RT_IGW."

# Enable Auto-assign Public IP on Public Subnet
aws ec2 modify-subnet-attribute \
  --subnet-id $PUB_SN_AZ0_ID \
  --map-public-ip-on-launch \
  --region $REGION
echo "Successfully enabled 'Auto-assign Public IP' on Subnet $PUB_SN_AZ0."

# Create EC2 Key Pair
KEY_OPS_MAN_ID=$(aws ec2 create-key-pair \
  --key-name $KEY_OPS_MAN)
echo "Successfully created ec2 key pair $KEY_OPS_MAN"

# Create NAT Instance
NAT_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $NAT_AMI \
  --count 1 \
  --instance-type $NAT_INSTANCE_TYPE \
  --key-name $KEY_OPS_MAN \
  --subnet-id $PUB_SN_AZ0_ID \
  --query 'Instances[].{InstanceId:InstanceId}' \
  --output text)
aws ec2 create-tags \
  --resources $NAT_INSTANCE_ID \
  --tags "Key=Name,Value=$NAT_INSTANCE" \
  --region $REGION
SECONDS=0
LAST_CHECK=0
STATE=""
until [[ "$STATE" == *RUNNING ]]; do
  INTERVAL=$SECONDS-$LAST_CHECK
  if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
    STATE=$(aws ec2 describe-instances \
      --instance-ids $NAT_INSTANCE_ID \
      --region $REGION \
      --query 'Reservations[].Instances[].{State:State}'  \
      --output text)
    STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
    LAST_CHECK=$SECONDS
  fi
  SECS=$SECONDS
  STATUS_MSG=$(printf $FORMATTED_MSG $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
  printf "    $STATUS_MSG\033[0K\r"
  sleep 1
done
echo "Successfully created NAT Instance $NAT_INSTANCE."

# Create Main Route Table route to NAT ENI
ENI_ID=$(aws ec2 describe-network-interfaces \
  --filter Name=subnet-id,Values=$PUB_SN_AZ0_ID \
  --query 'NetworkInterfaces[].{NetworkInterfaceId:NetworkInterfaceId}' \
  --output text)
RT_MAIN_ID=$(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true \
  --region $REGION \
  --query 'RouteTables[*].{RouteTableId:RouteTableId}' \
  --output text)
aws ec2 create-route \
  --route-table-id $RT_MAIN_ID \
  --destination-cidr-block $RT_MAIN_DEST_CIDR \
  --network-interface-id $ENI_ID \
  --region $REGION
echo "Successfully created route from $RT_MAIN to NAT ENI $ENI_ID"

# Create Subsequent Public Subnets
PUB_SN_AZ1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUB_SN_AZ1_CIDR \
  --availability-zone $SN_AZ1 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $PUB_SN_AZ1_ID \
  --tags "Key=Name,Value=$PUB_SN_AZ1" \
  --region $REGION
echo "Successfully created Subnet $PUB_SN_AZ1 in $SN_AZ1."

PUB_SN_AZ2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUB_SN_AZ2_CIDR \
  --availability-zone $SN_AZ2 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags --resources $PUB_SN_AZ2_ID --tags "Key=Name,Value=$PUB_SN_AZ2" --region $REGION
echo "Successfully created Subnet $PUB_SN_AZ2 in $SN_AZ2."

PRI_SN_AZ1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRI_SN_AZ1_CIDR \
  --availability-zone $SN_AZ1 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $PRI_SN_AZ1_ID \
  --tags "Key=Name,Value=$PRI_SN_AZ1" \
  --region $REGION
echo "Successfully created Subnet $PRI_SN_AZ1 in $SN_AZ1."

PRI_SN_AZ2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRI_SN_AZ2_CIDR \
  --availability-zone $SN_AZ2 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $PRI_SN_AZ2_ID \
  --tags "Key=Name,Value=$PRI_SN_AZ2" \
  --region $REGION
echo "Successfully created Subnet $PRI_SN_AZ2 in $SN_AZ2."

ERT_SN_AZ0_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $ERT_SN_AZ0_CIDR \
  --availability-zone $SN_AZ0 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $ERT_SN_AZ0_ID \
  --tags "Key=Name,Value=$ERT_SN_AZ0" \
  --region $REGION
echo "Successfully created Subnet $ERT_SN_AZ0 in $SN_AZ0."

ERT_SN_AZ1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $ERT_SN_AZ1_CIDR \
  --availability-zone $SN_AZ1 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $ERT_SN_AZ1_ID \
  --tags "Key=Name,Value=$ERT_SN_AZ1" \
  --region $REGION
echo "Successfully created Subnet $ERT_SN_AZ1 in $SN_AZ1."

ERT_SN_AZ2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $ERT_SN_AZ2_CIDR \
  --availability-zone $SN_AZ2 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $ERT_SN_AZ2_ID \
  --tags "Key=Name,Value=$ERT_SN_AZ2" \
  --region $REGION
echo "Successfully created Subnet $ERT_SN_AZ2 in $SN_AZ2."

SVC_SN_AZ0_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SVC_SN_AZ0_CIDR \
  --availability-zone $SN_AZ0 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $SVC_SN_AZ0_ID \
  --tags "Key=Name,Value=$SVC_SN_AZ0" \
  --region $REGION
echo "Successfully created Subnet $SVC_SN_AZ0 in $SN_AZ0."

SVC_SN_AZ1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SVC_SN_AZ1_CIDR \
  --availability-zone $SN_AZ1 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $SVC_SN_AZ1_ID \
  --tags "Key=Name,Value=$SVC_SN_AZ1" \
  --region $REGION
echo "Successfully created Subnet $SVC_SN_AZ1 in $SN_AZ1."

SVC_SN_AZ2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $SVC_SN_AZ2_CIDR \
  --availability-zone $SN_AZ2 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $SVC_SN_AZ2_ID \
  --tags "Key=Name,Value=$SVC_SN_AZ2" \
  --region $REGION
echo "Successfully created Subnet $SVC_SN_AZ2 in $SN_AZ2."

RDS_SN_AZ0_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $RDS_SN_AZ0_CIDR \
  --availability-zone $SN_AZ0 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $RDS_SN_AZ0_ID \
  --tags "Key=Name,Value=$RDS_SN_AZ0" \
  --region $REGION
echo "Successfully created Subnet $RDS_SN_AZ0 in $SN_AZ0."

RDS_SN_AZ1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $RDS_SN_AZ1_CIDR \
  --availability-zone $SN_AZ1 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $RDS_SN_AZ1_ID \
  --tags "Key=Name,Value=$RDS_SN_AZ1" \
  --region $REGION
echo "Successfully created Subnet $RDS_SN_AZ1 in $SN_AZ1."

RDS_SN_AZ2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $RDS_SN_AZ2_CIDR \
  --availability-zone $SN_AZ2 \
  --region $REGION \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text)
aws ec2 create-tags \
  --resources $RDS_SN_AZ2_ID \
  --tags "Key=Name,Value=$RDS_SN_AZ2" \
  --region $REGION
echo "Successfully created Subnet $RDS_SN_AZ2 in $SN_AZ2."

# Create and configure Security Group for Ops Manager
OPSMAN_SG_ID=$(aws ec2 create-security-group \
  --group-name $OPSMAN_SG \
  --description "$OPSMAN_SG_DESC" \
  --vpc-id $VPC_ID \
  --query '{GroupId:GroupId}' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $OPSMAN_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr $MY_CIDR
aws ec2 authorize-security-group-ingress \
  --group-id $OPSMAN_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr $MY_CIDR
aws ec2 authorize-security-group-ingress \
  --group-id $OPSMAN_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_CIDR
aws ec2 authorize-security-group-ingress \
  --group-id $OPSMAN_SG_ID \
  --protocol tcp \
  --port 6868 \
  --cidr $VPC_CIDR
aws ec2 authorize-security-group-ingress \
  --group-id $OPSMAN_SG_ID \
  --protocol tcp \
  --port 25555 \
  --cidr $VPC_CIDR
echo "Successfully created and configured Security Group $OPSMAN_SG in $VPC_ID."

# Create and configure Security Group for PCF VMS
PCFVM_SG_ID=$(aws ec2 create-security-group \
  --group-name $PCFVM_SG \
  --description "$PCFVM_SG_DESC" \
  --vpc-id $VPC_ID \
  --query '{GroupId:GroupId}' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $PCFVM_SG_ID \
  --protocol all \
  --port -1 \
  --cidr $VPC_CIDR
echo "Successfully created and configured Security Group $PCFVM_SG in $VPC_ID."

# Create and configure Security Group for Web ELB
WEBELB_SG_ID=$(aws ec2 create-security-group \
  --group-name $WEBELB_SG \
  --description "$WEBELB_SG_DESC" \
  --vpc-id $VPC_ID \
  --query '{GroupId:GroupId}' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $WEBELB_SG_ID \
  --protocol tcp \
  --port 4443 \
  --cidr $ANY_CIDR
aws ec2 authorize-security-group-ingress \
  --group-id $WEBELB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr $ANY_CIDR
aws ec2 authorize-security-group-ingress \
  --group-id $WEBELB_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr $ANY_CIDR
echo "Successfully created and configured Security Group $WEBELB_SG in $VPC_ID."

# Create and configure Security Group for SSH ELB
SSHELB_SG_ID=$(aws ec2 create-security-group \
  --group-name $SSHELB_SG \
  --description "$SSHELB_SG_DESC" \
  --vpc-id $VPC_ID \
  --query '{GroupId:GroupId}' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $SSHELB_SG_ID \
  --protocol tcp \
  --port 2222 \
  --cidr $ANY_CIDR
echo "Successfully created and configured Security Group $SSHELB_SG in $VPC_ID."

# Create and configure Security Group for TCP ELB
TCPELB_SG_ID=$(aws ec2 create-security-group \
  --group-name $TCPELB_SG \
  --description "$TCPELB_SG_DESC" \
  --vpc-id $VPC_ID \
  --query '{GroupId:GroupId}' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $TCPELB_SG_ID \
  --protocol tcp \
  --port 1024-1123 \
  --cidr $ANY_CIDR
echo "Successfully created and configured Security Group $TCPELB_SG in $VPC_ID."

# Create and configure Security Group for Outbound NAT
OBDNAT_SG_ID=$(aws ec2 create-security-group \
  --group-name $OBDNAT_SG \
  --description "$OBDNAT_SG_DESC" \
  --vpc-id $VPC_ID \
  --query '{GroupId:GroupId}' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $OBDNAT_SG_ID \
  --protocol all \
  --port -1 \
  --cidr $VPC_CIDR
echo "Successfully created and configured Security Group $OBDNAT_SG in $VPC_ID."

# Create and configure Security Group for MySQL
MYSQL_SG_ID=$(aws ec2 create-security-group \
  --group-name $MYSQL_SG \
  --description "$MYSQL_SG_DESC" \
  --vpc-id $VPC_ID \
  --query '{GroupId:GroupId}' \
  --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $MYSQL_SG_ID \
  --protocol tcp \
  --port 3306 \
  --cidr $VPC_CIDR
aws ec2 authorize-security-group-egress \
  --group-id $MYSQL_SG_ID \
  --protocol all \
  --port -1 \
  --cidr $VPC_CIDR
echo "Successfully created and configured Security Group $MYSQL_SG in $VPC_ID."

# Create Ops Manager Instance
OPSMAN_INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $OPSMAN_AMI \
  --count 1 \
  --instance-type $OPSMAN_INSTANCE_TYPE \
  --key-name $KEY_OPS_MAN \
  --subnet-id $PUB_SN_AZ0_ID \
  --iam-instance-profile Name=$IAM_PROFILE \
  --security-group-ids $OPSMAN_SG_ID \
  --block-device-mapping file://pcf-opsman-block-device-mapping.json \
  --query 'Instances[].{InstanceId:InstanceId}' \
  --output text)
SECONDS=0
LAST_CHECK=0
STATE=""
until [[ "$STATE" == *RUNNING ]]; do
  INTERVAL=$SECONDS-$LAST_CHECK
  if [[ $INTERVAL -ge $CHECK_FREQUENCY ]]; then
    STATE=$(aws ec2 describe-instances \
      --instance-ids $OPSMAN_INSTANCE_ID \
      --query 'Reservations[].Instances[].{State:State}' \
      --output text \
      --region $REGION)
    STATE=$(echo $STATE | tr '[:lower:]' '[:upper:]')
    LAST_CHECK=$SECONDS
  fi
  SECS=$SECONDS
  STATUS_MSG=$(printf $FORMATTED_MSG $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
  printf "    $STATUS_MSG\033[0K\r"
  sleep 1
done
aws ec2 create-tags \
  --resources $OPSMAN_INSTANCE_ID \
  --tags "Key=Name,Value=$OPSMAN_INSTANCE" \
  --region $REGION
echo "Successfully created Ops Manager Instance $OPSMAN_INSTANCE."

# Create certificate
# TODO?

# Create Web Load Balancer
WEB_ELB_DNS=$(aws elb create-load-balancer \
  --load-balancer-name $WEB_ELB \
  --listeners $WEB_ELB_L0 $WEB_ELB_L1 $WEB_ELB_L2 \
  --scheme internal \
  --subnets $PUB_SN_AZ0_ID $PUB_SN_AZ1_ID $PUB_SN_AZ2_ID \
  --security-groups $WEBELB_SG_ID \
  --query '{DNSName:DNSName}' \
  --output text)
aws elb configure-health-check \
  --load-balancer-name $WEB_ELB \
  --health-check Target=HTTP:8080/health,Interval=5,UnhealthyThreshold=3,HealthyThreshold=6,Timeout=3
echo "Successfully created Web ELB $WEB_ELB at $WEB_ELB_DNS"

# Create SSH Load Balancer
SSH_ELB_DNS=$(aws elb create-load-balancer \
  --load-balancer-name $SSH_ELB \
  --listeners $SSH_ELB_L0 \
  --scheme internal \
  --subnets $PUB_SN_AZ0_ID $PUB_SN_AZ1_ID $PUB_SN_AZ2_ID \
  --security-groups $WEBELB_SG_ID \
  --query '{DNSName:DNSName}' \
  --output text)
aws elb configure-health-check \
  --load-balancer-name $SSH_ELB \
  --health-check Target=TCP:2222,Interval=5,UnhealthyThreshold=3,HealthyThreshold=6,Timeout=3
echo "Successfully created SSH ELB $SSH_ELB at $SSH_ELB_DNS"

# Create TCP Load Balancer
TCP_ELB_DNS=$(aws elb create-load-balancer \
  --load-balancer-name $TCP_ELB \
  --listeners "$TCP_ELB_L0" \
  --scheme internal \
  --subnets $PUB_SN_AZ0_ID $PUB_SN_AZ1_ID $PUB_SN_AZ2_ID \
  --security-groups $TCPELB_SG_ID \
  --query '{DNSName:DNSName}' \
  --output text)
aws elb configure-health-check \
  --load-balancer-name $TCP_ELB \
  --health-check Target=TCP:80,Interval=5,UnhealthyThreshold=3,HealthyThreshold=6,Timeout=3
echo "Successfully created TCP ELB $TCP_ELB at $TCP_ELB_DNS"

# Update CNAME and A records
OPSMAN_IP=$(aws ec2 describe-instances \
  --instance-ids $OPSMAN_INSTANCE_ID \
  --query 'Reservations[].Instances[].{PublicIpAddress:PublicIpAddress}' \
  --output text)
sed -e "s+APP_DOMAIN+$APP_DOMAIN+g" -e "s+WEB_ELB+$WEB_ELB_DNS+g" \
  -e "s+SYS_DOMAIN+$SYS_DOMAIN+g" \
  -e "s+SSH_DOMAIN+$SSH_DOMAIN+g" -e "s+SSH_ELB+$SSH_ELB_DNS+g" \
  -e "s+TCP_DOMAIN+$TCP_DOMAIN+g" -e "s+TCP_ELB+$TCP_ELB_DNS+g" \
  -e "s+PCF_DOMAIN+$PCF_DOMAIN+g" -e "s+OPSMAN_IP+$OPSMAN_IP+g" \
  $ZONE_UPDATE_TEMPLATE > $ZONE_UPDATE_JSON
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file://$ZONE_UPDATE_JSON
echo "Successfully updated CNAME and A records"

# Update NAT EC2 Instance Security Group
aws ec2 modify-instance-attribute \
  --instance-id $NAT_INSTANCE_ID \
  --groups $OBDNAT_SG_ID
echo "Successfully updated NAT instance $NAT_INSTANCE security group to $OBDNAT_SG"

# Create RDS Subnet Group
aws rds create-db-subnet-group \
  --db-subnet-group-name $RDS_SN_GRP \
  --db-subnet-group-description "$RDS_SN_GRP_DESC" \
  --subnet-ids $RDS_SN_AZ0_ID $RDS_SN_AZ1_ID $RDS_SN_AZ2_ID
echo "Successfully created RDS Subnet Group"

# Create RDS Instance
aws rds create-db-instance \
  --allocated-storage 100 \
  --storage-type gp2 \
  --db-instance-class $RDS_CLASS \
  --db-instance-identifier $RDS_ID \
  --engine mysql \
  --db-subnet-group-name $RDS_SN_GRP \
  --no-publicly-accessible \
  --vpc-security-group-ids $MYSQL_SG_ID \
  --db-name $RDS_NAME \
  --master-username admin \
  --master-user-password password
echo "Successfully created RDS Instance"

echo "COMPLETED"
exit 0
