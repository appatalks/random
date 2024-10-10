#!/bin/bash

git rev-list --objects --all \
  | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
  | awk '/^blob/ {print substr($0,6)}' \
  | sort --numeric-sort --key=2 \
  | cut -c 13- \
  | numfmt --field=2 --to=iec-i --suffix=B --padding=7 --round=nearest \
  | tee >(echo "Total objects processed: $(wc -l | awk '{print $1}')")
