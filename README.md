# Setting up PCF Reference Architecture on AWS using CLI

This repository contains a rudimentary shell script to implement PCF on AWS Reference Architecture, as well as tearing it down. It is not meant for production use, but rather a learning experience.

## Getting Started

Clone this repository to an environment of your choice.

```bash
git clone https://github.com/bernardpark/pcf-aws-scripts.git
```

## Prerequisites

### File a Ticket

Your AWS account requires that it can launch more than 20 instances. Navigate to the EC2 Service in AWS and on the left pane, click Limits. Submit a ticket so you can launch up to 50 t2.micro instances and 20 c4.large instances. Depending on your support plan, this request can take up to around 5 business days.

### Acquire a Domain and Certificate

If you use Route53, create a Hosted Zone and acquire a domain. An example of such would be *.pearsonpcf.com. If you use an external provider, make sure you have a domain dedicated to this PCF foundation and have access to modify CNAME and A records.

### Install AWS CLI

Most tasks in this script utilizes the AWS CLI. Install by following this guide, or the following commands that assume the following requirements.

* Python 2 version 2.6.5+ or Python 3 version 3.3+
* Windows, Linux, macOS, or Unix

```bash
Install awscli
pip install awscli --upgrade --user
aws
```

### Configure AWS CLI (example)
```bash
aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-2
Default output format [None]: json
```

You can find or create a new set of your access keys by navigating to IAM -> Users -> {YOUR-ACCOUNT} -> Security credentials -> Access Keys.


## Preparing the Scripts

Make sure your repository is in a secure location, and you have executable rights to your shell scripts (pcf-aws.sh, destroy-pcf-aws.sh).

```bash
chmod +x pcf-aws.sh
chmod +x destroy-pcf-aws.sh
```

### Running the Install Script
Run your script.

```bash
./pcf-aws.sh
```

The first portion of the script runs the `aws configure` command. The following script is made interactive for you to add your configuration details.

### Running the Destroy Script
Run your script.

```bash
./destroy-pcf-aws.sh
```

The destroy script is designed to clean up your environment in the reverse order from which your resources were created. Currently, there are issues with some parts of the script that does not delete particular resources (i.e. your virtual network, disks, snapshots, etc). After running this script, you will have to manually delete these resources from your console to achieve a clean slate.

## Resources

* [Installing PCF on AWS Manually](https://docs.pivotal.io/pivotalcf/2-3/om/aws/prepare-env-manual.html) - Pivotal's official guide
* [PCF on AWS Reference Architecture](https://docs.pivotal.io/pivotalcf/2-1/refarch/aws/aws_ref_arch.html) - Pivotal's PCF on AWS architecture design


## Authors

* **Bernard Park** - [Github Repo](https://github.com/bernardpark)

