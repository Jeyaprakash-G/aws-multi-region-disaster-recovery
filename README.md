# aws-multi-region-disaster-recovery
AWS multi-region disaster recovery architecture using Amazon EFS, Transit Gateway inter-region peering, and S3 Cross-Region Replication.
🌎 AWS Multi-Region Disaster Recovery

Amazon EFS | Transit Gateway Inter-Region Peering | Amazon S3 Cross-Region Replication

A hands-on AWS infrastructure project demonstrating cross-region connectivity, shared file storage, automated file monitoring, and Amazon S3 Cross-Region Replication (CRR).

This project connects an Amazon EC2 instance in Singapore (ap-southeast-1) to Amazon EFS in US East (N. Virginia, us-east-1) through AWS Transit Gateway inter-Region peering. Files created in the mounted EFS file system are detected on the EC2 instance, uploaded to a primary S3 bucket in N. Virginia, and replicated to a DR S3 bucket in Singapore.

🚀 Project Overview

The project demonstrates how AWS networking and storage services can work together to support a multi-region disaster recovery design.

🎯 Objectives

Configure VPC networking in two AWS Regions.

Attach each VPC to its regional AWS Transit Gateway.

Establish Transit Gateway inter-Region peering between N. Virginia and Singapore.

Mount an EFS file system from an EC2 instance in Singapore.

Monitor EFS file activity using inotifywait.

Automatically upload detected files to the primary S3 bucket.

Configure S3 Cross-Region Replication from N. Virginia to Singapore.

Verify that files reach both the primary and DR S3 buckets.

🏗️ Architecture

             PRIMARY REGION                              DR / SECONDARY REGION
       US East (N. Virginia)                              Asia Pacific (Singapore)
            us-east-1                                           ap-southeast-1

       ┌────────────────────┐                            ┌────────────────────┐
       │     Primary VPC    │                            │      DR VPC        │
       │   10.0.0.0/16      │                            │   10.1.0.0/16      │
       │                    │                            │                    │
       │  Public Subnet     │                            │  Public Subnet     │
       │  10.0.1.0/24       │                            │  10.1.1.0/24       │
       │                    │                            │                    │
       │  EFS Mount Target  │                            │  Ubuntu EC2        │
       │       │            │                            │       │            │
       │       ▼            │                            │       │ NFS : 2049  │
       │   Amazon EFS ◄─────┼──── TGW Inter-Region ──────┼───────┘            │
       │                    │       Peering              │                    │
       │  Primary S3 Bucket │                            │  DR S3 Bucket      │
       │  jp-s3-n.virginia  │                            │  jp-s3-oct2        │
       └─────────┬──────────┘                            └─────────▲──────────┘
                 │                                                  │
                 │             S3 Cross-Region Replication          │
                 └──────────────────────────────────────────────────┘

  File flow:
  EFS (/mnt/efs) → inotifywait → efs-to-s3.sh → Primary S3 → S3 CRR → DR S3

Important: Transit Gateway peering provides the network path between the VPCs. S3 Cross-Region Replication is a separate S3-managed data replication process.

🛠️ AWS Services and Tools

Service / Tool

Purpose

Amazon VPC

Provides isolated networking in each Region

Public Subnets

Host the project resources according to the implemented lab design

Internet Gateway

Provides internet connectivity for resources/routes configured to use it

Amazon EC2 (Ubuntu)

Runs the file-monitoring and S3 upload scripts

Amazon EFS

Provides shared file storage mounted at /mnt/efs

EFS Mount Target

Provides network access to EFS from the VPC

AWS Transit Gateway

Connects VPCs to the regional transit network

Transit Gateway Inter-Region Peering

Connects the regional Transit Gateways

Amazon S3

Stores uploaded files in the primary Region

S3 Cross-Region Replication

Replicates eligible objects to the DR bucket

inotifywait

Detects file-system events such as file creation and modification

AWS CLI

Lists and verifies S3 objects from the command line

Bash

Runs the efs-to-s3.sh upload script

🌐 Regional Network Configuration

Primary Region — US East (N. Virginia)

Region: us-east-1

VPC CIDR: 10.0.0.0/16

Public subnet CIDR: 10.0.1.0/24

Storage: Amazon EFS and primary S3 bucket

Primary S3 bucket: jp-s3-n.virginia

DR / Secondary Region — Singapore

Region: ap-southeast-1

VPC CIDR: 10.1.0.0/16

Public subnet CIDR: 10.1.1.0/24

Compute: Ubuntu EC2 instance

DR S3 bucket: jp-s3-oct2

Transit Gateway connectivity

Create a Transit Gateway in each Region.

Attach the regional VPC to its Transit Gateway.

Create a Transit Gateway peering attachment between the two Regions.

Accept the peering request in the peer Region.

Configure the required Transit Gateway route-table associations and propagations.

Add routes for the opposite VPC CIDR through the peering attachment.

Verify the network path and security rules.

EFS network requirement: Allow NFS traffic on TCP port 2049 from the authorized EC2/security-group or network source. Configure routes and security rules to match the actual VPC and EFS mount-target design.

📁 EFS Mount and File Monitoring

The EFS file system is mounted on the Ubuntu EC2 instance at:

/mnt/efs

The lab uses inotifywait to detect file-system activity and a Bash script (efs-to-s3.sh) to upload the detected file to the primary S3 bucket.

Workflow

Create or modify a file under /mnt/efs.

inotifywait detects the configured event.

The monitoring workflow invokes efs-to-s3.sh.

The script uploads the file to jp-s3-n.virginia.

S3 Cross-Region Replication copies eligible objects to jp-s3-oct2.

Event-based monitoring can detect changes without waiting for a periodic cron interval. The monitoring process must be running for events to be handled.

🪣 Amazon S3 Cross-Region Replication

Replication direction

Primary S3 Bucket
jp-s3-n.virginia
Region: us-east-1
        │
        │ S3 Cross-Region Replication
        ▼
DR S3 Bucket
jp-s3-oct2
Region: ap-southeast-1

Configuration checklist

Enable versioning on both source and destination buckets.

Configure an S3 replication rule on the source bucket.

Select the destination bucket in Singapore.

Configure the required IAM replication role and permissions.

Ensure the rule scope matches the intended objects or prefixes.

Upload a test file to the primary bucket.

Verify that the object appears in the destination bucket.

S3 replication applies to objects covered by the configured rule. Objects that existed before replication was enabled may require a separate replication action to copy them.

🧪 Validation and Testing

Use the commands below on the Ubuntu EC2 instance where applicable.

1. Verify the EFS mount

df -h | grep /mnt/efs

2. Test NFS connectivity to the EFS mount target

Replace the example IP with the mount target IP for your environment:

nc -vz 10.0.1.164 2049

3. Create a test file

echo "Multi-region EFS and S3 replication test" | sudo tee /mnt/efs/replication-test.txt

4. Check the primary S3 bucket

aws s3 ls s3://jp-s3-n.virginia/

5. Check the DR S3 bucket

aws s3 ls s3://jp-s3-oct2/ --region ap-southeast-1

Expected result

The EFS file is visible from the EC2 instance.

The monitoring script detects the configured file event.

The file is uploaded to the primary S3 bucket.

After replication completes, the object appears in the DR S3 bucket.

Replication is asynchronous, so the destination object may not appear immediately.

🔐 Security Considerations

Follow least-privilege IAM permissions for EC2, S3 replication, and other resources.

Restrict NFS TCP 2049 to authorized sources only.

Do not expose EFS or other resources more broadly than required.

Keep S3 Block Public Access enabled unless a specific, reviewed requirement says otherwise.

Avoid storing AWS access keys in scripts or in this repository.

Never commit private keys, credentials, or sensitive configuration files.

Review bucket policies, IAM roles, and security groups before using this design outside a lab.

⚠️ Troubleshooting Checklist

Issue

What to check

EFS does not mount

Mount target, NFS TCP 2049, security groups, routes, and EFS DNS/mount configuration

EC2 cannot reach EFS

Transit Gateway attachment status, peering status, route tables, VPC routes, and security rules

File is not uploaded

Confirm inotifywait is running, the watched path is correct, and the upload script has execute permission

S3 upload fails

Check AWS CLI identity, IAM permissions, bucket name, Region, and network access

Object is missing from DR bucket

Check source/destination versioning, replication rule status, IAM role permissions, rule scope, and replication status

Replication is delayed

Allow time for asynchronous replication and inspect the object's replication status

📂 Suggested Repository Structure

aws-multi-region-disaster-recovery/
│
├── README.md
├── scripts/
│   └── efs-to-s3.sh
├── docs/
│   └── architecture.png
└── .gitignore

Add only the scripts and documentation that belong to your actual implementation. If you include additional scripts, explain their purpose in this README.

🎓 Key Learning Outcomes

Built VPC networking across two AWS Regions.

Practiced Transit Gateway VPC attachments and inter-Region peering.

Understood the routing and security requirements for cross-region network access.

Mounted Amazon EFS on an EC2 Ubuntu instance.

Used inotifywait for event-based file monitoring.

Automated file uploads from EFS to Amazon S3.

Configured and validated S3 Cross-Region Replication.

Verified the end-to-end storage workflow using AWS CLI commands.

🚀 Future Improvements

Automate VPC, Transit Gateway, EFS, and S3 provisioning with Terraform.

Add CloudWatch alarms and monitoring for the file-monitoring process.

Document and test a disaster-recovery runbook.

Add automated validation for uploaded and replicated objects.

Review recovery objectives and perform periodic DR exercises.

⭐ Project Summary

This hands-on project combines Amazon EFS, EC2, AWS Transit Gateway inter-Region peering, Amazon S3, and S3 Cross-Region Replication to demonstrate a multi-region storage and connectivity workflow.

The network connectivity path and S3 replication path serve different purposes: Transit Gateway peering supports private network communication between the regional VPCs, while S3 CRR replicates eligible objects from the primary bucket in N. Virginia to the DR bucket in Singapore.

Learn → Build → Connect → Automate → Replicate → Validate 🚀
