#!/bin/bash

case "$1" in
    nvme|ssd|hd)
        results=()

        while read -r disk disk_type rota rm; do

            # Physical disks only
            [[ "$disk_type" == "disk" ]] || continue

            # Ignore removable devices
            [[ "$rm" == "1" ]] && continue

            # Detect storage type
            if [[ "$disk" == nvme* ]]; then
                storage_type="nvme"
            elif [[ "$rota" == "1" ]]; then
                storage_type="hd"
            else
                storage_type="ssd"
            fi

            # Match requested type
            [[ "$storage_type" == "$1" ]] || continue

            # NVMe uses the root filesystem
            if [[ "$storage_type" == "nvme" ]]; then

                usage=$(df -h / 2>/dev/null |
                    awk 'NR==2 {print $3 "/" $2}')

                if [[ -n "$usage" ]]; then
                    results+=("$usage")
                fi

            # SSD / HDD: find a mounted partition
            else

                while read -r mountpoint; do

                    [[ -n "$mountpoint" ]] || continue
                    [[ "$mountpoint" == "[SWAP]" ]] && continue
                    [[ "$mountpoint" == "/" ]] && continue

                    usage=$(df -h "$mountpoint" 2>/dev/null |
                        awk 'NR==2 {print $3 "/" $2}')

                    if [[ -n "$usage" ]]; then
                        results+=("$usage")
                    fi

                done < <(
                    lsblk -nr -o MOUNTPOINTS "/dev/$disk" |
                    grep -v '^$'
                )

            fi

        done < <(
            lsblk -dnr -o NAME,TYPE,ROTA,RM
        )

        # Print all accumulated results cleanly with proper formatting
        if [[ ${#results[@]} -gt 0 ]]; then
            for i in "${!results[@]}"; do
                if [[ $i -eq 0 ]]; then
                    echo "${results[$i]}"
                else
                    echo "│           │ ${results[$i]}"
                fi
            done
        fi

        exit 0
        ;;

    *)
        echo "Usage: $0 {nvme|ssd|hd}"
        exit 1
        ;;
esac