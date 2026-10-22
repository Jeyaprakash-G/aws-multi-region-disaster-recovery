# Troubleshooting Guide — Level 1 Multi-Region EFS, Transit Gateway & S3 Replication

## Project
**Designing Resilient, Private Cross-Region Storage & Network Connectivity for a Global Enterprise**

- Primary Region: US East (N. Virginia) — `us-east-1`
- Secondary Region: Asia Pacific (Singapore) — `ap-southeast-1`
- North Virginia VPC: `10.0.0.0/16`; subnet: `10.0.1.0/24`
- Singapore VPC: `10.1.0.0/16`; subnet: `10.1.1.0/24`

> **Documentation note:** The attached implementation document says public subnets were used in both VPCs and that private subnets were not used in this hands-on setup. The guide below gives troubleshooting checks for the documented flow. The source document does not record exact error messages for every issue, so these are validation steps rather than claims that each error definitely occurred.

## 1. Cross-Region EC2-to-EFS Connectivity

**Symptom:** The Singapore EC2 instance cannot reach or mount the EFS hosted in North Virginia.

**Checks and resolution**
1. Confirm the Singapore EC2 is in `10.1.0.0/16` and the EFS is in the North Virginia VPC `10.0.0.0/16`.
2. Confirm both VPCs have attachments to their regional Transit Gateways.
3. Confirm the TGW inter-Region peering attachment is **Active** and the peer request was accepted.
4. Verify VPC route tables:
   - North Virginia: `10.1.0.0/16` → local North Virginia TGW.
   - Singapore: `10.0.0.0/16` → local Singapore TGW.
5. Verify TGW route tables:
   - North Virginia TGW: `10.1.0.0/16` → TGW peering attachment.
   - Singapore TGW: `10.0.0.0/16` → TGW peering attachment.
6. Check TGW route-table associations and propagation where required.
7. Check security groups and network ACLs along the path.

Test from Singapore EC2:
```bash
nc -zv <EFS-Mount-Target-IP> 2049
```
A successful TCP connection confirms reachability to the mount-target IP on NFS port 2049, but does not by itself prove the filesystem mount or file permissions are correct.

## 2. EFS Mount Fails

**Symptom:** The mount command fails or EFS does not appear in the filesystem list.

**Checks and resolution**
1. Confirm the EFS file system exists in `us-east-1`.
2. Confirm an EFS mount target exists in the North Virginia VPC and obtain its IP address.
3. Confirm the EFS security group allows inbound **TCP 2049 (NFS)** from the intended source. The source must permit the Singapore EC2 traffic over the routed cross-region network.
4. Recheck VPC routes, TGW routes and return routing.
5. Confirm NFS client utilities are installed on the EC2 instance.
6. Create the mount directory and mount using the correct mount-target address and options.

```bash
sudo mkdir -p /mnt/efs
df -h
```

After mounting, `df -h` should show the EFS filesystem. If not, inspect the mount command's error output and re-test TCP 2049.

## 3. EFS Read/Write Test Fails

**Symptom:** EFS appears mounted, but a test file cannot be created, read or modified.

**Checks and resolution**
1. Confirm `/mnt/efs` is the mounted EFS filesystem and not an ordinary local directory.
2. Inspect the mount:
   ```bash
   df -h
   mount | grep /mnt/efs
   ```
3. Test writing and reading:
   ```bash
   echo "Hello from Singapore EC2" > /mnt/efs/test.txt
   cat /mnt/efs/test.txt
   ```
4. If there is a permission error, inspect file/directory ownership and permissions. Avoid making the directory broadly writable as a workaround.

## 4. Transit Gateway Peering or Routing Does Not Work

**Symptom:** Peering exists, but traffic between the VPCs does not pass.

**Checks and resolution**
- Confirm the peering request was accepted in the peer Region and the attachment is **Active**.
- Distinguish the attachment types:
  - **VPC attachment:** connects a VPC to its regional TGW.
  - **Peering attachment:** connects the two regional TGWs.
- Confirm both TGW route tables route the opposite VPC CIDR through the peering attachment.
- Confirm VPC route tables send the remote VPC CIDR to the local TGW.
- Confirm CIDRs do not overlap. Here, `10.0.0.0/16` and `10.1.0.0/16` are distinct.
- Check security groups and network ACLs.

## 5. `inotifywait` Does Not Detect EFS File Changes

**Symptom:** A file is created or modified under `/mnt/efs`, but the monitoring command/script does not react.

**Checks and resolution**
1. Confirm EFS is mounted at `/mnt/efs` using `df -h`.
2. Confirm `inotifywait` is installed on the Singapore EC2 instance.
3. Start monitoring:
   ```bash
   inotifywait -m /mnt/efs
   ```
4. Create or modify a test file through the mount and observe the event output.
5. Remember: `inotifywait` detects events; it does **not** upload files to S3. The script must handle the event and run the AWS CLI upload.
6. Check the script's watched path, event filters and file path. If it reacts before a file has finished writing, add handling to avoid uploading an incomplete file.

The source document identifies `CREATE`, `OPEN` and `MODIFY` as events to monitor; it does not provide a recorded `inotifywait` error message.

## 6. EFS-to-S3 Upload Fails

**Symptom:** A detected file does not appear in the North Virginia primary S3 bucket.

**Checks and resolution**
1. Confirm the script reads the intended file under `/mnt/efs`.
2. Confirm the destination is the **North Virginia primary bucket**, not the Singapore replica bucket.
3. Check AWS CLI installation and credentials.
4. Verify the active identity and bucket access:
   ```bash
   aws sts get-caller-identity
   aws s3 ls s3://<north-virginia-bucket>/
   ```
5. Ensure the identity used by the script can upload objects (for example, required `s3:PutObject` permission and any required KMS permissions).
6. Run the upload manually to separate event/script issues from AWS CLI or permission issues:
   ```bash
   aws s3 cp /mnt/efs/test.txt s3://<north-virginia-bucket>/
   ```
7. Check the command's error output and verify the object:
   ```bash
   aws s3 ls s3://<north-virginia-bucket>/
   ```

Never store AWS access keys, secret credentials or private keys in this file or commit them to GitHub.

## 7. S3 Cross-Region Replication Does Not Copy the Object

**Symptom:** An object exists in the North Virginia bucket but is not visible in the Singapore replica bucket.

**Checks and resolution**
1. Confirm versioning is enabled on **both** source and destination buckets.
2. Confirm the CRR rule is enabled and uses the correct buckets:
   - Source: North Virginia S3 (`us-east-1`).
   - Destination: Singapore S3 (`ap-southeast-1`).
3. Confirm the replication IAM role and required permissions are configured.
4. Check the source object's replication status and review rule filters/scope.
5. Upload a new test object after the rule is enabled, then check the destination bucket.
6. If replication still fails, inspect S3 replication status, IAM permissions and bucket policies. TGW connectivity is not what controls S3 CRR.

**Important:** EFS-to-S3 upload and S3-to-S3 replication are separate stages.

## 8. End-to-End Validation Checklist

Troubleshoot one stage at a time:

1. **Network:** TGW peering is active; VPC and TGW routes are present in both directions.
2. **NFS connectivity:** From Singapore EC2, test the North Virginia EFS mount-target IP on TCP 2049.
3. **Mount:** `/mnt/efs` appears in `df -h`.
4. **File I/O:** Create and read `/mnt/efs/test.txt`.
5. **Monitoring:** `inotifywait -m /mnt/efs` reports the test file event.
6. **Upload:** AWS CLI uploads the object to North Virginia S3.
7. **Replication:** The object appears in Singapore S3.

```text
Singapore EC2
   -> NFS / TCP 2049
   -> North Virginia EFS mounted at /mnt/efs
   -> inotifywait detects a file event
   -> EFS-to-S3 script runs
   -> AWS CLI uploads to North Virginia S3
   -> S3 Cross-Region Replication
   -> Singapore S3 replica
```

## 9. Project Scope Note

The attached implementation document says public subnets were used in both VPCs and explicitly states that private subnets were not used in this hands-on setup. If this project is presented as a **private** cross-region architecture, implement the intended private-subnet design and document its routing/egress approach before claiming that requirement is complete.

## Interview Summary

“I configured Transit Gateway inter-Region peering between North Virginia and Singapore, routed traffic between the VPCs, and mounted the North Virginia EFS from a Singapore EC2 instance using NFS. I used `inotifywait` to monitor the mounted EFS directory, a script and AWS CLI to upload changed files to the primary S3 bucket, and S3 Cross-Region Replication to copy objects to Singapore. The main troubleshooting checkpoints are TGW/VPC routes, NFS TCP 2049 and EFS mount configuration, file-event monitoring, AWS CLI upload permissions, and S3 replication settings.”
