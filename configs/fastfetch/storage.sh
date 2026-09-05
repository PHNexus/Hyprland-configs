#!/bin/bash
case "$1" in
  nvme)
    findmnt -n -o SOURCE / | grep -E '^/dev/nvme' | xargs -I {} df -h {} 2>/dev/null | awk 'NR==2 {print $3 "/" $2}'
    ;;
  ssd)
    lsblk /dev/sda -b -o SIZE -nr 2>/dev/null | awk 'NR==1 {print "0/" int($1/1024/1024/1024) "G"}'
    ;;
esac