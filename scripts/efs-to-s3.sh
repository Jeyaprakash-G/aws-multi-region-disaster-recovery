#!/usr/bin/env bash
#
# efs-to-s3.sh
# Monitor an EFS-mounted directory and upload completed files to a primary S3 bucket.
#
# Prerequisites:
#   - Run this script on the EC2 instance where EFS is mounted.
#   - EFS must be mounted at WATCH_DIR.
#   - inotifywait (inotify-tools) must be installed.
#   - AWS CLI must be installed and configured, or the instance must have an IAM role
#     with permission to upload objects to the target S3 bucket.
#
# Example:
#   chmod +x efs-to-s3.sh
#   ./efs-to-s3.sh

set -uo pipefail

# Project configuration
WATCH_DIR="/mnt/efs"
S3_BUCKET="jp-s3-n.virginia"
AWS_REGION="us-east-1"

# Check required tools
for command in inotifywait aws; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "ERROR: Required command '$command' was not found." >&2
    echo "Install inotify-tools and AWS CLI, then run this script again." >&2
    exit 1
  fi
done

# Check that the EFS directory exists and is mounted
if [[ ! -d "$WATCH_DIR" ]]; then
  echo "ERROR: Watch directory '$WATCH_DIR' does not exist." >&2
  exit 1
fi

if ! mountpoint -q "$WATCH_DIR"; then
  echo "WARNING: '$WATCH_DIR' is not reported as a mount point."
  echo "Confirm that EFS is mounted there before continuing." >&2
fi

echo "Monitoring: $WATCH_DIR"
echo "S3 destination: s3://$S3_BUCKET/"
echo "AWS Region: $AWS_REGION"
echo "Press Ctrl+C to stop."

# Watch recursively for completed writes and files moved into the directory.
# close_write helps avoid uploading a file while it is still being written.
inotifywait --monitor --recursive \
  --event close_write \
  --event moved_to \
  --format '%w%f' \
  "$WATCH_DIR" |
while IFS= read -r FILE_PATH; do
  # Ignore paths that are no longer regular files.
  if [[ ! -f "$FILE_PATH" ]]; then
    continue
  fi

  # Convert the full path into an S3 object key relative to WATCH_DIR.
  RELATIVE_KEY="${FILE_PATH#"$WATCH_DIR"/}"

  if [[ -z "$RELATIVE_KEY" || "$RELATIVE_KEY" == "$FILE_PATH" ]]; then
    echo "WARNING: Could not determine an S3 key for '$FILE_PATH'; skipping." >&2
    continue
  fi

  echo "Uploading '$FILE_PATH' to s3://$S3_BUCKET/$RELATIVE_KEY ..."

  if aws s3 cp "$FILE_PATH" "s3://$S3_BUCKET/$RELATIVE_KEY" \
      --region "$AWS_REGION"; then
    echo "SUCCESS: Uploaded '$RELATIVE_KEY'."
  else
    echo "ERROR: Upload failed for '$FILE_PATH'." >&2
  fi
done
