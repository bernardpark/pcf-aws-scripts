#!/bin/bash
#******************************************************************************
#    AWS PAS Installation Script
#******************************************************************************i
#
# DESCRIPTION
#    Automates PAS Infrastructure installation on AWS using the AWS CLI.
#
#
#==============================================================================
#   Modify variables below as needed
#==============================================================================

echo ""

# Misc. Variables
RESULT=""

# S3 Buckets. Make sure these are unique.
declare -a BUCKETS=()
echo -n "Ops Manager Bucket Name [bpark-pcf-ops-manager-bucket] > "
read UINPUT1
if [ -z "$UINPUT1" ]; then
    UINPUT1="bpark-pcf-ops-manager-bucket"
fi
echo -n "Buildpacks Bucket Name [bpark-pcf-buildpacks-bucket] > "
read UINPUT2
if [ -z "$UINPUT2" ]; then
    UINPUT2="bpark-pcf-buildpacks-bucket"
fi
echo -n "Packages Bucket Name [bpark-pcf-packages-bucket] > "
read UINPUT3
if [ -z "$UINPUT3" ]; then
    UINPUT3="bpark-pcf-packages-bucket"
fi
echo -n "Resources Bucket Name [bpark-pcf-resources-bucket] > "
read UINPUT4
if [ -z "$UINPUT4" ]; then
    UINPUT4="bpark-pcf-resources-bucket"
fi
echo -n "Droplets Bucket Name [bpark-pcf-droplets-bucket] > "
read UINPUT5
if [ -z "$UINPUT5" ]; then
    UINPUT5="bpark-pcf-droplets-bucket"
fi
declare -a BUCKETS=($UINPUT1 $UINPUT2 $UINPUT3 $UINPUT4 $UINPUT5)

# RDS
RDS_SN_GRP="pcf-rds-subnet-group"
RDS_SN_GRP_DESC="RDS Subnet Group for PCF"
RDS_ID="pcf-ops-manager-director"
RDS_CLASS="db.m4.large"
RDS_NAME="bosh"



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


