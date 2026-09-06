#!/bin/bash
case "$1" in
  nvme)
    df -h / 2>/dev/null | awk 'NR==2 {print $3 "/" $2}'
    ;;
  ssd)
    target=$(lsblk -o MOUNTPOINT,NAME,TYPE -rn | grep -E 'part|disk' | awk '$1 != "/" && $1 != "" {print $1; exit}')
    if [ -n "$target" ]; then
      df -h "$target" 2>/dev/null | awk 'NR==2 {print $3 "/" $2}'
    fi
    ;;
  hd)
    target=$(lsblk -o MOUNTPOINT,NAME,TYPE -rn | grep -E 'part|disk' | awk '$1 != "/" && $1 != "" {print $1}' | sed -n '2p')
    if [ -n "$target" ]; then
      df -h "$target" 2>/dev/null | awk 'NR==2 {print $3 "/" $2}'
    fi
    ;;
esac