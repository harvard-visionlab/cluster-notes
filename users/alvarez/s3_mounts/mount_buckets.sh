#!/bin/bash
#
# Mount multiple S3 buckets in parallel
# Usage: 
#   ./mount_buckets.sh                                    # Use default buckets
#   ./mount_buckets.sh bucket1 bucket2 bucket3            # Mount specific buckets
# 
# Default buckets are used if no arguments provided
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOUNT_SCRIPT="${MOUNT_SCRIPT_PATH:-$SCRIPT_DIR/mount_s3_bucket.sh}"

# Check for arguments - if provided, use them; otherwise use defaults
if [ $# -gt 0 ]; then
    # Use command line arguments as bucket list
    BUCKETS=("$@")    # <-- THIS is where "$@" becomes the BUCKETS array
else
    # Default buckets if no arguments provided
    BUCKETS=(
        "visionlab-datasets" 
        "visionlab-members"
    )
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting parallel S3 bucket mounting...${NC}"
echo "Buckets to mount: ${#BUCKETS[@]}"

# Check if mount script exists
if [ ! -f "$MOUNT_SCRIPT" ]; then
    echo -e "${RED}ERROR: Mount script not found at $MOUNT_SCRIPT${NC}"
    exit 1
fi

# Make sure mount script is executable
chmod +x "$MOUNT_SCRIPT"

# Function to mount a single bucket
mount_bucket() {
    local bucket=$1
    local log_file="/tmp/mount_${bucket}.log"
    
    echo -e "${YELLOW}[${bucket}] Starting mount...${NC}"
    
    if "$MOUNT_SCRIPT" "$bucket" > "$log_file" 2>&1; then
        echo -e "${GREEN}[${bucket}] ✅ Successfully mounted${NC}"
        return 0
    else
        echo -e "${RED}[${bucket}] ❌ Failed to mount${NC}"
        echo -e "${RED}[${bucket}] Check log: $log_file${NC}"
        return 1
    fi
}

# Start all mounts in parallel
pids=()
failed_buckets=()

for bucket in "${BUCKETS[@]}"; do
    mount_bucket "$bucket" &
    pids+=($!)
done

echo -e "${BLUE}All mount processes started. Waiting for completion...${NC}"

# Wait for all background processes and collect results
for i in "${!pids[@]}"; do
    pid=${pids[$i]}
    bucket=${BUCKETS[$i]}
    
    if wait $pid; then
        echo -e "${GREEN}[${bucket}] Background process completed successfully${NC}"
    else
        echo -e "${RED}[${bucket}] Background process failed${NC}"
        failed_buckets+=("$bucket")
    fi
done

echo ""
echo -e "${BLUE}=== SUMMARY ===${NC}"

if [ ${#failed_buckets[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All ${#BUCKETS[@]} buckets mounted successfully!${NC}"
    
    # Show mounted locations
    echo ""
    echo "Mounted buckets:"
    for bucket in "${BUCKETS[@]}"; do
        mount_point="${S3_MOUNT_ROOT:-~/s3_buckets}/$bucket"
        mount_point=$(eval echo "$mount_point")
        echo "  • $bucket → $mount_point"
    done
    
else
    echo -e "${RED}❌ ${#failed_buckets[@]} bucket(s) failed to mount:${NC}"
    for bucket in "${failed_buckets[@]}"; do
        echo -e "  • ${RED}$bucket${NC}"
        echo "    Log: /tmp/mount_${bucket}.log"
    done
    echo ""
    echo -e "${YELLOW}Successfully mounted: $((${#BUCKETS[@]} - ${#failed_buckets[@]})) buckets${NC}"
    exit 1
fi

# Cleanup log files on success
echo ""
echo "Cleaning up temporary log files..."
for bucket in "${BUCKETS[@]}"; do
    rm -f "/tmp/mount_${bucket}.log"
done

echo -e "${GREEN}Done!${NC}"
