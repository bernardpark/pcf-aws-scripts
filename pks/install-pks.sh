#!/bin/bash
#******************************************************************************
#    AWS PKS Installation Script
#******************************************************************************i
#
# DESCRIPTION
#    Automates PKS Installation on AWS using the AWS CLI.
#
#
#==============================================================================
#   Global properties and tags. Modify according to your configuration.
#==============================================================================

echo "*********************************************************************************************************"
echo "*** THIS SCRIPT WILL CONFIGURE AND USE YOUR AWS CLI. BEFORE YOU BEGIN MAKE SURE THIS SCRIPT IS SECURE ***"
echo "***************************** REQUIRES aws cli, jq, and terraform ***************************************"
echo "*********************************************************************************************************"
echo ""

# Misc. Variables
RESULT=""

# AWS Region. Make sure this matches the region you configure with 'aws configure'
echo -n "AWS Region [us-east-2] > "
read UINPUT
if [ -z "$UINPUT" ]; then
    UINPUT="us-east-2"
fi
RGN=$UINPUT

# IAM
IAM_USR="pks-user"
IAM_USR_JSN="pks-user.json"
IAM_USR_KEY_JSN="pks-user-keys.json"
# LEAVE THE FOLLOWING BLANK
IAM_USR_ACC_KEY=""
IAM_USR_SCR_KEY=""

# SSL Certificate
CRT_PEM="pks-cert.pem"
CRT_CSR="pks-cert.csr"
CRT_CNF="pks-cert.cnf"
# LEAVE THE FOLLOWING BLANK
CRT_PEM_BDY=""
CRT_CSR_BDY=""

# Ops Manager
OPS_MGR_AMI="ami-020dcf7cbc9b96723"

# DNS
DNS_SFX="pcfbpark.com"

# Terraform
TRF_DIR="./workspace/pivotal-cf-terraforming-aws-323eef9/terraforming-pks"
TRF_VAR_TPL="$TRF_DIR/terraform.tfvars.template"
TRF_VAR_TMP="$TRF_DIR/terraform.tfvars.tmp"
TRF_VAR="$TRF_DIR/terraform.tfvars"

#==============================================================================
#   Resources names. Modify to match your convention.
#==============================================================================

#==============================================================================
#   Configuration details. No need to modify.
#==============================================================================

#==============================================================================
#   Installation script below. Do not modify.
#==============================================================================

# Configure AWS CLI (interactive)
aws configure
echo ""
echo "*********************************************************************************************************"
echo "**************************** THIS SCRIPT WILL NOW MODIFY YOUR AWS RESOURCES *****************************"
echo "*********************************************************************************************************"
echo ""

echo -n "Are you sure you want to continue? [yN]"
read UINPUT
if [ -z "$UINPUT" ]; then
    exit 0
fi

# Create IAM user
echo ""
echo "*********************************************************************************************************"
echo "************************************ Creating IAM Service Account ***************************************"
echo ""

aws iam create-user \
  --user-name $IAM_USR \
  > $IAM_USR_JSN
echo "Successfully created $IAM_USR."

aws iam create-access-key \
  --user-name $IAM_USR \
  > $IAM_USR_KEY_JSN
echo "Successfully created access keys for $IAM_USR."

aws iam attach-user-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess \
  --user-name $IAM_USR

aws iam attach-user-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess \
  --user-name $IAM_USR

aws iam attach-user-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess \
  --user-name $IAM_USR

aws iam attach-user-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
  --user-name $IAM_USR

aws iam attach-user-policy \
  --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess \
  --user-name $IAM_USR

aws iam attach-user-policy \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess \
  --user-name $IAM_USR

aws iam attach-user-policy \
  --policy-arn arn:aws:iam::aws:policy/AWSKeyManagementServicePowerUser \
  --user-name $IAM_USR

echo "Successfully added policies for $IAM_USR."

IAM_USR_ACC_KEY=$(cat pks-user-keys.json | jq .AccessKey.AccessKeyId)
IAM_USR_SCR_KEY=$(cat pks-user-keys.json | jq .AccessKey.SecretAccessKey)

# Create root cert for Bosh deployed VMs
echo ""
echo "*********************************************************************************************************"
echo "********************************** Creating Self Signed Certificate *************************************"
echo ""

openssl req \
  -newkey rsa:2048 \
  -nodes \
  -keyout $CRT_PEM \
  -x509 \
  -days 365 \
  -out $CRT_CSR \
  -config $CRT_CNF

CRT_CSR_BDY=$(cat $CRT_CSR | awk '$1=$1' ORS='\\\\n')
CRT_PEM_BDY=$(cat $CRT_PEM | awk '$1=$1' ORS='\\\\n')

echo "Successfully created self-signed certificate."

# Create Terraform template
echo ""
echo "*********************************************************************************************************"
echo "************************************* Creating Terraform Template ***************************************"
echo ""

sed -e "s%IAM_USR_ACC_KEY%$IAM_USR_ACC_KEY%g" \
  -e "s%IAM_USR_SCR_KEY%$IAM_USR_SCR_KEY%g" \
  -e "s%RGN%$RGN%g" \
  -e "s%OPS_MGR_AMI%$OPS_MGR_AMI%g" \
  -e "s%DNS_SFX%$DNS_SFX%g" \
  -e "s%CRT_CSR_BDY%$CRT_CSR_BDY%g" \
  -e "s%CRT_PEM_BDY%$CRT_PEM_BDY%g" \
  $TRF_VAR_TPL > $TRF_VAR_TMP

awk '{gsub(/\\n/,"\n")}1' $TRF_VAR_TMP > $TRF_VAR

echo "Successfully created Terraform template."

# Run Terraform
echo ""
echo "*********************************************************************************************************"
echo "****************************************** Running Terraform ********************************************"
echo ""

cp ./terraform.tfvars.template ./TRF_DIR/terraform.tfvars.template
 
cd $TRF_DIR
terraform init
terraform plan -out=plan
terraform apply plan

echo "Successfully created PKS infrastructure."

echo ""
echo "********************************************** COMPLETED ************************************************"
echo "*********************************************************************************************************"
echo ""
echo ""

exit 0
