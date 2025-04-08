#!/bin/bash
#
# NEEDS TESTING
 
# Set variables
BACKING_FILE="/tmp/backingfile.img"
LOOP_DEVICE="/dev/loop10"
ERROR_DEVICE="test_error"
MOUNT_POINT="/data/user"
TEST_FILE="$MOUNT_POINT/testfile.fio"
REPORT_FILE="$MOUNT_POINT/stress_test_report.txt"

# Create a backing file
echo "Creating backing file..."
sudo dd if=/dev/zero of=$BACKING_FILE bs=1M count=1024

# Attach it to a loop device
echo "Attaching backing file to loop device..."
sudo losetup $LOOP_DEVICE $BACKING_FILE

# Get the size (in sectors) of the loop device
SECTORS=$(sudo blockdev --getsz $LOOP_DEVICE)

# Create a device-mapper table that always reports errors
echo "Creating device-mapper error target..."
echo "0 ${SECTORS} error" | sudo dmsetup create $ERROR_DEVICE

# Format and mount the error device
echo "Formatting and mounting the error device..."
sudo mkfs.ext4 /dev/mapper/$ERROR_DEVICE
sudo mount /dev/mapper/$ERROR_DEVICE $MOUNT_POINT

# Run fio stress test
echo "Running fio stress test..."
sudo fio --name=stress_test \
    --filename=$TEST_FILE \
    --rw=randrw \
    --bs=32k \
    --size=50G \
    --ioengine=libaio \
    --iodepth=64 \
    --numjobs=8 \
    --runtime=180 \
    --time_based \
    --group_reporting | tee $REPORT_FILE

# Monitor kernel logs
echo "Monitoring kernel logs (dmesg)..."
dmesg -w &

# Wait for the fio command to complete before stopping the log monitoring
wait

# Unmount and clean up
echo "Cleaning up..."
sudo umount $MOUNT_POINT
sudo dmsetup remove $ERROR_DEVICE
sudo losetup -d $LOOP_DEVICE
rm $BACKING_FILE

echo "Stress test completed. Report saved to $REPORT_FILE."
