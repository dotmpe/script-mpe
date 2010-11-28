#!/bin/bash
host=$1
ip=$(echo $2 | sed 's/\./\\./g')

if test -z "$host" -o -z "$ip"
then 
	echo "Usage: reset-nfs host new-ip"
	exit 2
fi

oldip=$(egrep "\<$host$|\<$host[[:space:]]" /etc/hosts | sed 's/^\([\.0-9]\+\)\s\+.*/\1/' | sed 's/\./\\./g')
if test -z "$oldip"; then
	echo "Cannot find IP for host '$host'"
	exit 3
fi;
echo from $oldip to $ip
cp /etc/hosts /tmp/hosts
sed "s/$oldip/$ip/" /tmp/hosts > /etc/hosts

sudo /etc/init.d/nfs-common stop
sudo /etc/init.d/nfs-kernel-server stop
sudo /etc/init.d/nfs-common start
sudo /etc/init.d/nfs-kernel-server start
