#!/usr/bin/env bash
#
# Scan for remote <hostname>, unmount all filesystems.
#
# Written for Darwin.

hostname=$1; shift

[ -z "$hostname" ] && {
    echo Missing hostname argument
    exit 1
}

scan_mounts()
{
    mount | grep $1 | cut -d' ' -f3
}

[ "$(uname -s)" = "Darwin" ] && {

disk_unmount()
{
    diskutil umount $1
}

} || [ "$(uname -s)" = "Linux" ] && {

disk_unmount()
{
    sudo umount $1
}

} || {
    echo Unknown OS $(uname -s)
    exit 1
}


while [ -n "$(mount | grep $hostname)" ]
do
    scan_mounts $hostname | while \
        read mountpoint
        do
            echo "Unmounting $mountpoint"
            disk_unmount $mountpoint
        done
    if [ -n "$(mount | grep $hostname)" ]
    then
        echo Waiting to retry unmounts
        sleep 5
    fi
done

