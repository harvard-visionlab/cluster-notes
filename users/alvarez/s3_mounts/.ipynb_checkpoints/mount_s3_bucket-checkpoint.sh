#!/bin/bash
#
# One-time setup:
# mkdir -p ~/.config/rclone
# nano ~/.config/rclone/rclone.conf
# [s3_remote]
# type = s3
# provider = AWS
# env_auth = true
# region = us-east-1
# acl = public-read
# 
# Examples:
# chmod u+x mount_s3_bucket.sh
# ./mount_s3_bucket.sh teamspace-onboarding
# S3_MOUNT_ROOT="/n/holylabs/LABS/alvarez_lab/Users/alvarez/s3_buckets" ./mount_s3_bucket.sh teamspace-onboarding
# 
# to unmount
# fusermount -u /n/holylabs/LABS/alvarez_lab/Users/alvarez/s3_buckets/teamspace-onboarding

set -e  # Exit on any error

# Check for required argument
if [ $# -eq 0 ]; then
    echo ""
    echo "==> mount_s3_bucket.sh usage:"
    echo ""
    echo "Usage: $0 <bucket_name>"
    echo "Example: $0 my-s3-bucket"
    echo ""
    echo "Environment variables:"
    echo "  S3_MOUNT_ROOT - Where to mount buckets (default: ~/s3_buckets)"
    exit 1
fi

BUCKET_NAME="$1"

# Set defaults for environment variables
S3_MOUNT_ROOT="${S3_MOUNT_ROOT:-~/s3_buckets}"

# Expand tilde in S3_MOUNT_ROOT if present
S3_MOUNT_ROOT=$(eval echo "$S3_MOUNT_ROOT")

echo "Starting rclone setup..."
echo "Bucket: $BUCKET_NAME"
echo "Mount root: $S3_MOUNT_ROOT"

# Check if already mounted
if mountpoint -q "$S3_MOUNT_ROOT/$BUCKET_NAME" 2>/dev/null; then
    echo "INFO: $S3_MOUNT_ROOT/$BUCKET_NAME is already mounted"
    exit 0
fi

# Ensure required directories exist
mkdir -p ~/.config/rclone
mkdir -p "$S3_MOUNT_ROOT/$BUCKET_NAME"

# Verify rclone.conf exists
if [ ! -f ~/.config/rclone/rclone.conf ]; then
    echo "ERROR: Missing rclone config at ~/.config/rclone/rclone.conf"
    echo "See setup instructions at the top of this script."
    exit 1
fi

# Test AWS credentials and S3 access
echo "Testing S3 access..."
if ! rclone lsd s3_remote: > /dev/null 2>&1; then
    echo "ERROR: Cannot access S3 with current credentials"
    echo "Check your AWS credentials and rclone config."
    exit 1
fi

# Verify the specific bucket exists and is accessible
echo "Verifying bucket access..."
if ! rclone lsd "s3_remote:$BUCKET_NAME" > /dev/null 2>&1; then
    echo "ERROR: Cannot access bucket '$BUCKET_NAME'"
    echo "Check bucket name and permissions."
    exit 1
fi

# Mount S3 bucket
echo "Mounting S3 bucket '$BUCKET_NAME'..."
rclone mount "s3_remote:$BUCKET_NAME" "$S3_MOUNT_ROOT/$BUCKET_NAME" \
    --daemon \
    --vfs-cache-mode writes \
    --s3-chunk-size 50M \
    --s3-upload-cutoff 50M \
    --buffer-size 50M \
    --log-level INFO

# Wait and verify mount is active with retry logic
echo "Waiting for mount to become active..."
for i in {1..10}; do
    if mountpoint -q "$S3_MOUNT_ROOT/$BUCKET_NAME" 2>/dev/null; then
        echo "✅ Mount successful!"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "ERROR: S3 mount failed after 10 seconds"
        echo "Check rclone logs for details: rclone config show"
        exit 1
    fi
    sleep 1
done

echo ""
echo "✅ Setup completed successfully!"
echo "S3 bucket '$BUCKET_NAME' is now available at:"
echo "  $S3_MOUNT_ROOT/$BUCKET_NAME"
echo ""
echo "To unmount:"
echo "  fusermount -u $S3_MOUNT_ROOT/$BUCKET_NAME"