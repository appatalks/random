#!/bin/bash
#
# Needs testing. Maybe some stress-testing.

fio --name=stress_test \
    --filename=/data/user/testfile.fio \
    --rw=randrw \
    --bs=32k \
    --size=50G \
    --ioengine=libaio \
    --iodepth=64 \
    --numjobs=8 \
    --runtime=180 \
    --time_based \
    --group_reporting
