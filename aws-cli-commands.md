# AWS CLI Commands – Multi-Region Disaster Recovery Project

This document records the AWS CLI commands used to inspect, validate, and test the end-to-end multi-region storage and disaster recovery workflow.

## 1. Project Overview

### 1.1 Architecture

- **Primary Region:** US East (N. Virginia) — `us-east-1`
- **DR Region:** Asia Pacific (Singapore) — `ap-southeast-1`
- **Primary S3 bucket:** `jp-s3-n.virginia`
- **DR S3 bucket:** `jp-s3-oct2`
- **Primary VPC CIDR:** `10.0.0.0/16`
- **DR VPC CIDR:** `10.1.0.0/16`
- **EFS mount directory on EC2:** `/mnt/efs`

### 1.2 End-to-End Data Flow

```text
EC2 instance
    |
    v
Amazon EFS (/mnt/efs)
    |
    v
inotifywait detects a file event
    |
    v
efs-to-s3.sh automation script
    |
    v
Primary S3 bucket (us-east-1)
    |
    v
S3 Cross-Region Replication (asynchronous)
    |
    v
DR S3 bucket (ap-southeast-1)
```

**Important:** Transit Gateway inter-Region peering provides a network path between VPCs when routes and security controls are configured correctly. S3 Cross-Region Replication is a separate S3-managed object replication process.

> **Scope note:** Commands are grouped into AWS CLI commands and Linux commands. Resource IDs, mount target DNS names, and other placeholders must be replaced with the actual values from your AWS account. Commands that create or change resources are labelled accordingly.

## 2. AWS CLI Setup and Identity

### 2.1 Verify AWS CLI Installation

```bash
aws --version
```

### 2.2 Configure AWS CLI

```bash
aws configure
```

Enter the access key, secret key, default region (`us-east-1`), and output format (`json`) when prompted. Do not store credentials in this document or commit them to GitHub.

### 2.3 Verify the Current AWS Identity

```bash
aws sts get-caller-identity
```

### 2.4 Inspect Current CLI Configuration

```bash
aws configure list
```

### 2.5 Display the Configured Default Region

```bash
aws configure get region
```

## 3. Region Verification

### 3.1 List Available Regions

```bash
aws ec2 describe-regions \
  --query "Regions[].RegionName" \
  --output table
```

### 3.2 Check the Primary Region

```bash
aws ec2 describe-regions \
  --region us-east-1 \
  --output table
```

### 3.3 Check the DR Region

```bash
aws ec2 describe-regions \
  --region ap-southeast-1 \
  --output table
```

## 4. VPC, Subnet, and Route Table Validation

### 4.1 List VPCs in the Primary Region

```bash
aws ec2 describe-vpcs \
  --region us-east-1 \
  --query "Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,State:State}" \
  --output table
```

### 4.2 List VPCs in the DR Region

```bash
aws ec2 describe-vpcs \
  --region ap-southeast-1 \
  --query "Vpcs[].{VpcId:VpcId,CIDR:CidrBlock,State:State}" \
  --output table
```

### 4.3 List Subnets in the Primary Region

```bash
aws ec2 describe-subnets \
  --region us-east-1 \
  --query "Subnets[].{SubnetId:SubnetId,VpcId:VpcId,CIDR:CidrBlock,AZ:AvailabilityZone}" \
  --output table
```

### 4.4 List Subnets in the DR Region

```bash
aws ec2 describe-subnets \
  --region ap-southeast-1 \
  --query "Subnets[].{SubnetId:SubnetId,VpcId:VpcId,CIDR:CidrBlock,AZ:AvailabilityZone}" \
  --output table
```

### 4.5 Inspect VPC Route Tables

Primary Region:

```bash
aws ec2 describe-route-tables \
  --region us-east-1 \
  --output table
```

DR Region:

```bash
aws ec2 describe-route-tables \
  --region ap-southeast-1 \
  --output table
```

## 5. Transit Gateway and Inter-Region Peering Validation

### 5.1 List Transit Gateways in the Primary Region

```bash
aws ec2 describe-transit-gateways \
  --region us-east-1 \
  --output table
```

### 5.2 List Transit Gateways in the DR Region

```bash
aws ec2 describe-transit-gateways \
  --region ap-southeast-1 \
  --output table
```

### 5.3 Inspect VPC Attachments in the Primary Region

```bash
aws ec2 describe-transit-gateway-vpc-attachments \
  --region us-east-1 \
  --output table
```

### 5.4 Inspect VPC Attachments in the DR Region

```bash
aws ec2 describe-transit-gateway-vpc-attachments \
  --region ap-southeast-1 \
  --output table
```

### 5.5 Inspect Peering Attachments in the Primary Region

```bash
aws ec2 describe-transit-gateway-peering-attachments \
  --region us-east-1 \
  --output table
```

### 5.6 Inspect Peering Attachments in the DR Region

```bash
aws ec2 describe-transit-gateway-peering-attachments \
  --region ap-southeast-1 \
  --output table
```

### 5.7 List Transit Gateway Route Tables

Primary Region:

```bash
aws ec2 describe-transit-gateway-route-tables \
  --region us-east-1 \
  --output table
```

DR Region:

```bash
aws ec2 describe-transit-gateway-route-tables \
  --region ap-southeast-1 \
  --output table
```

### 5.8 Search Active Routes in a Transit Gateway Route Table

Replace `<tgw-route-table-id>` with the actual route table ID.

```bash
aws ec2 search-transit-gateway-routes \
  --region us-east-1 \
  --transit-gateway-route-table-id <tgw-route-table-id> \
  --filters Name=state,Values=active \
  --output table
```

Repeat in the DR Region using the appropriate region and route table ID.

## 6. EC2 and Security Group Validation

### 6.1 List EC2 Instances in the Primary Region

```bash
aws ec2 describe-instances \
  --region us-east-1 \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}" \
  --output table
```

### 6.2 List EC2 Instances in the DR Region

```bash
aws ec2 describe-instances \
  --region ap-southeast-1 \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}" \
  --output table
```

### 6.3 Find Security Groups Attached to an Instance

Replace `<instance-id>` with the instance ID.

```bash
aws ec2 describe-instances \
  --region ap-southeast-1 \
  --instance-ids <instance-id> \
  --query "Reservations[].Instances[].SecurityGroups" \
  --output table
```

### 6.4 Inspect a Security Group

Replace `<security-group-id>` with the security group ID.

```bash
aws ec2 describe-security-groups \
  --region us-east-1 \
  --group-ids <security-group-id> \
  --output json
```

For EFS NFS access, the relevant security group rules must allow TCP port `2049` from the authorized source.

## 7. Amazon EFS Validation

### 7.1 List EFS File Systems in the Primary Region

```bash
aws efs describe-file-systems \
  --region us-east-1 \
  --output table
```

### 7.2 Inspect a Specific EFS File System

Replace `<efs-file-system-id>` with the actual file system ID.

```bash
aws efs describe-file-systems \
  --region us-east-1 \
  --file-system-id <efs-file-system-id> \
  --output json
```

### 7.3 List EFS Mount Targets

```bash
aws efs describe-mount-targets \
  --region us-east-1 \
  --file-system-id <efs-file-system-id> \
  --output table
```

### 7.4 Check Security Groups on an EFS Mount Target

Replace `<mount-target-id>` with the actual mount target ID.

```bash
aws efs describe-mount-target-security-groups \
  --region us-east-1 \
  --mount-target-id <mount-target-id> \
  --output table
```

### 7.5 Inspect the EFS File System Policy

```bash
aws efs describe-file-system-policy \
  --region us-east-1 \
  --file-system-id <efs-file-system-id>
```

If no file system policy is configured, this command may return an error indicating that the policy does not exist.

## 8. Linux Commands for EFS Mounting and File Monitoring

The following are **Linux commands**, not AWS CLI commands. Run them on the EC2 instance that is intended to mount EFS.

### 8.1 Create the Mount Directory

```bash
sudo mkdir -p /mnt/efs
```

### 8.2 Mount EFS Using NFS

Replace `<efs-mount-target-dns-name>` with the correct, resolvable mount target DNS name.

```bash
sudo mount -t nfs4 \
  -o nfsvers=4.1 \
  <efs-mount-target-dns-name>:/ \
  /mnt/efs
```

Cross-region EFS mounting requires working routes, security rules, DNS/address resolution, and a supported connectivity design. Transit Gateway peering alone does not guarantee that the EFS mount will work.

### 8.3 Verify the Mount

```bash
df -h | grep /mnt/efs
```

```bash
mount | grep efs
```

### 8.4 Install `inotifywait` on Ubuntu, If Needed

```bash
sudo apt update
sudo apt install inotify-tools -y
```

### 8.5 Monitor File Events on EFS

```bash
inotifywait -m /mnt/efs \
  -e create \
  -e close_write \
  -e moved_to
```

### 8.6 Make the Automation Script Executable

If `efs-to-s3.sh` is in the current directory:

```bash
chmod +x efs-to-s3.sh
```

### 8.7 Run the Automation Script

```bash
./efs-to-s3.sh
```

The exact script command depends on the script's implementation. The script should watch the intended directory and upload the appropriate files to the primary bucket.

## 9. Amazon S3 Bucket Validation

### 9.1 List Buckets Available to the Current Identity

```bash
aws s3 ls
```

### 9.2 List Objects in the Primary Bucket

```bash
aws s3 ls s3://jp-s3-n.virginia/ \
  --region us-east-1
```

### 9.3 List Objects in the DR Bucket

```bash
aws s3 ls s3://jp-s3-oct2/ \
  --region ap-southeast-1
```

### 9.4 Check the Primary Bucket's Region

```bash
aws s3api get-bucket-location \
  --bucket jp-s3-n.virginia
```

### 9.5 Check the DR Bucket's Region

```bash
aws s3api get-bucket-location \
  --bucket jp-s3-oct2
```

### 9.6 Check Versioning on the Primary Bucket

```bash
aws s3api get-bucket-versioning \
  --bucket jp-s3-n.virginia \
  --region us-east-1
```

### 9.7 Check Versioning on the DR Bucket

```bash
aws s3api get-bucket-versioning \
  --bucket jp-s3-oct2 \
  --region ap-southeast-1
```

S3 Cross-Region Replication requires versioning to be enabled on both the source and destination buckets.

## 10. End-to-End File Creation and S3 Upload Test

### 10.1 Create a Test File on EFS

Run on the EC2 instance where EFS is mounted:

```bash
echo "Multi-region EFS and S3 replication test" \
  | sudo tee /mnt/efs/replication-test.txt
```

### 10.2 Read the Test File

```bash
cat /mnt/efs/replication-test.txt
```

### 10.3 List Files on EFS

```bash
ls -l /mnt/efs/
```

### 10.4 Manually Upload the Test File to Primary S3

This command tests S3 upload independently of the automation script.

```bash
aws s3 cp /mnt/efs/replication-test.txt \
  s3://jp-s3-n.virginia/replication-test.txt \
  --region us-east-1
```

### 10.5 Verify the Object in Primary S3

```bash
aws s3 ls s3://jp-s3-n.virginia/ \
  --region us-east-1
```

### 10.6 Download the Object for a Content Check

```bash
aws s3 cp \
  s3://jp-s3-n.virginia/replication-test.txt \
  /tmp/replication-test-downloaded.txt \
  --region us-east-1
```

```bash
cat /tmp/replication-test-downloaded.txt
```

> The manual upload command is a test. In the automated flow, the monitoring script performs the upload after detecting the file event.

## 11. S3 Cross-Region Replication Validation

### 11.1 Inspect the Primary Bucket's Replication Configuration

```bash
aws s3api get-bucket-replication \
  --bucket jp-s3-n.virginia \
  --region us-east-1
```

This command returns the replication configuration if one is configured. If no replication configuration exists, AWS returns an error.

### 11.2 Confirm DR Bucket Versioning

```bash
aws s3api get-bucket-versioning \
  --bucket jp-s3-oct2 \
  --region ap-southeast-1
```

### 11.3 List Objects in the DR Bucket

```bash
aws s3 ls s3://jp-s3-oct2/ \
  --region ap-southeast-1
```

### 11.4 Check the Source Object's Replication Status

```bash
aws s3api head-object \
  --bucket jp-s3-n.virginia \
  --key replication-test.txt \
  --region us-east-1
```

Inspect `ReplicationStatus` in the response when present. Possible values include `PENDING`, `COMPLETED`, and `FAILED`; the field may not be returned for every object or configuration.

### 11.5 Check the Destination Object

```bash
aws s3api head-object \
  --bucket jp-s3-oct2 \
  --key replication-test.txt \
  --region ap-southeast-1
```

S3 replication is asynchronous, so allow time for the object to appear in the destination. Existing objects uploaded before replication was configured may require a separate existing-object replication operation.

## 12. S3 Troubleshooting Commands

### 12.1 Verify AWS Identity

```bash
aws sts get-caller-identity
```

### 12.2 Test Primary Bucket Access

```bash
aws s3 ls s3://jp-s3-n.virginia/ \
  --region us-east-1
```

### 12.3 Test DR Bucket Access

```bash
aws s3 ls s3://jp-s3-oct2/ \
  --region ap-southeast-1
```

### 12.4 Test Uploading a Local File

Ensure `/tmp/test.txt` exists before running this command.

```bash
aws s3 cp /tmp/test.txt \
  s3://jp-s3-n.virginia/test.txt \
  --region us-east-1
```

### 12.5 Inspect Replication Configuration

```bash
aws s3api get-bucket-replication \
  --bucket jp-s3-n.virginia \
  --region us-east-1
```

### 12.6 Check an Object in the DR Bucket

```bash
aws s3api head-object \
  --bucket jp-s3-oct2 \
  --key test.txt \
  --region ap-southeast-1
```

### 12.7 Inspect Bucket Policies

Primary bucket:

```bash
aws s3api get-bucket-policy \
  --bucket jp-s3-n.virginia \
  --region us-east-1
```

DR bucket:

```bash
aws s3api get-bucket-policy \
  --bucket jp-s3-oct2 \
  --region ap-southeast-1
```

If a bucket has no bucket policy, the command can return an error. That alone does not establish that the bucket is inaccessible.

## 13. Optional Resource-Creation Commands

> **Caution:** These commands create or modify resources. Use them only when required. Bucket names are globally unique, and the example names may already exist. Do not run creation commands against existing resources without checking first.

### 13.1 Create a Primary S3 Bucket in N. Virginia

```bash
aws s3api create-bucket \
  --bucket jp-s3-n.virginia \
  --region us-east-1
```

### 13.2 Create a DR S3 Bucket in Singapore

```bash
aws s3api create-bucket \
  --bucket jp-s3-oct2 \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1
```

### 13.3 Enable Versioning on the Primary Bucket

```bash
aws s3api put-bucket-versioning \
  --bucket jp-s3-n.virginia \
  --versioning-configuration Status=Enabled \
  --region us-east-1
```

### 13.4 Enable Versioning on the DR Bucket

```bash
aws s3api put-bucket-versioning \
  --bucket jp-s3-oct2 \
  --versioning-configuration Status=Enabled \
  --region ap-southeast-1
```

These commands do not create the replication IAM role or replication rule. Those require additional configuration and permissions.

## 14. End-to-End Validation Checklist

Use this checklist to confirm the workflow:

- [ ] AWS CLI is installed and the expected AWS identity is active.
- [ ] The primary and DR VPCs exist in the correct regions.
- [ ] Transit Gateway attachments and inter-Region peering are available.
- [ ] Route tables include the required routes, and security rules permit intended traffic.
- [ ] The EFS file system and mount targets are available.
- [ ] EFS is mounted at `/mnt/efs` on the intended EC2 instance.
- [ ] `inotifywait` detects the intended file events.
- [ ] The automation script uploads files to the primary S3 bucket.
- [ ] Versioning is enabled on both S3 buckets.
- [ ] The primary bucket has the intended replication configuration.
- [ ] The test object appears in the DR bucket after replication completes.

## 15. Expected End-to-End Workflow

```text
1. Create a file on EFS
          |
          v
2. inotifywait detects the file event
          |
          v
3. efs-to-s3.sh uploads the file
          |
          v
4. Primary S3 bucket (us-east-1)
          |
          v
5. S3 Cross-Region Replication
          |
          v
6. DR S3 bucket (ap-southeast-1)
          |
          v
7. Verify the replicated object
```

## 16. Security and GitHub Notes

- Do not commit AWS access keys, secret keys, session tokens, passwords, private keys, or credential files.
- Prefer IAM roles for EC2-based workloads where possible.
- Follow least-privilege IAM permissions.
- Restrict NFS TCP port `2049` to authorized sources.
- Keep S3 Block Public Access enabled unless a documented requirement dictates otherwise.
- Replace placeholders such as `<efs-file-system-id>`, `<mount-target-id>`, `<instance-id>`, and `<security-group-id>` with the correct values before execution.
- Review commands before running them. Some commands inspect resources; others create resources or change configuration.

## 17. Summary

This command reference covers the AWS CLI and supporting Linux commands used to inspect and validate the project's key components:

- VPCs, subnets, and route tables
- Transit Gateways and inter-Region peering
- EC2 instances and security groups
- Amazon EFS and mount targets
- Amazon S3 buckets and versioning
- EFS file monitoring and S3 uploads
- S3 Cross-Region Replication
- End-to-end validation and troubleshooting

**Network connectivity and object replication are separate:** Transit Gateway inter-Region peering supports VPC-to-VPC network connectivity when correctly configured, while S3 Cross-Region Replication copies eligible objects between the configured S3 buckets.
