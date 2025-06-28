#!/bin/bash
BUCKET_NAME="$1"
S3_MOUNT_ROOT="${S3_MOUNT_ROOT:-~/s3_buckets}"
S3_MOUNT_ROOT=$(eval echo "$S3_MOUNT_ROOT")

echo "Unmounting $BUCKET_NAME..."

# Then unmount rclone mount
if mountpoint -q "$S3_MOUNT_ROOT/$BUCKET_NAME"; then
    fusermount -u "$S3_MOUNT_ROOT/$BUCKET_NAME"
    echo "Rclone mount unmounted"
fi

echo "Cleanup complete"