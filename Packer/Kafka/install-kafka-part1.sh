#!/bin/bash

set -ex

# Packages
#sudo yum -y update
#sudo yum -y install wget ca-certificates zip net-tools tar nmap-ncat

# Java Open JDK 8
#wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u152-b16/aa0333dd3019491ca4f6ddbe78cdb6d0/jdk-8u152-linux-x64.rpm"
#sudo yum -y localinstall jdk-8u152-linux-x64.rpm
#rm jdk-8u152-linux-x64.rpm
#java -version


# Add file limits configs - allow to open 100,000 file descriptors
#echo "* hard nofile 100000
#* soft nofile 100000" | sudo tee --append /etc/security/limits.conf

# we verify the disk is empty - should return "data"
#sudo file -s /dev/xvdf

# Note on Kafka: it's better to format volumes as xfs:
# https://kafka.apache.org/documentation/#filesystems
# Install packages to mount as xfs
#sudo yum -y install xfsprogs

# format as xfs
#sudo mkfs.xfs -f /dev/xvdf

# create kafka directory
sudo mkdir -p /data/kafka
# mount volume
#sudo mount -t xfs /dev/xvdf /data/kafka
# check it's working
sudo df -h /data/kafka

# EBS Automount On Reboot
sudo cp /etc/fstab /etc/fstab.bak # backup
echo "/dev/xvdf /data/kafka xfs defaults 0 0"| sudo tee --append /etc/fstab

exit 0