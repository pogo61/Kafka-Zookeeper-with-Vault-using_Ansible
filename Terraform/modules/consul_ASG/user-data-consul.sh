#!/bin/bash -ex
# This script is meant to be run in the User Data of each EC2 Instance while it's booting. The script uses the
# run-consul script to configure and start Consul in client mode and then the run-vault script to configure and start
# consul in server mode.

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# set up http health check
echo "Hello, World" > index.html
nohup busybox httpd -f -p 8080 &

su ec2-user -c 'source ~/.bash_profile; python /tmp/install-consul/conf_consul.py'

# The cluster_tag variables below are filled in via Terraform interpolation
su ec2-user -c 'source ~/.bash_profile; export AWS_SDK_LOAD_CONFIG=1; export AWS_PROFILE=terraform; /opt/consul/bin/run-consul --server --cluster-tag-key ${consul_cluster_tag_key} --cluster-tag-value ${consul_cluster_tag_value}'