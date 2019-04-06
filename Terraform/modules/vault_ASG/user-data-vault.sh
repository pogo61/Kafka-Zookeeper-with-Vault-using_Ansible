#!/bin/bash -ex
# This script is meant to be run in the User Data of each EC2 Instance while it's booting. The script uses the
# run-consul script to configure and start Consul in client mode and then the run-vault script to configure and start
# Vault in server mode. Note that this script assumes it's running in an AMI built from the Packer template in
# examples/vault-consul-ami/vault-consul.json.

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

su ec2-user -c 'source ~/.bash_profile; python /tmp/install-vault/conf_vault.py'

# The Packer template puts the TLS certs in these file paths
readonly VAULT_TLS_CERT_FILE="/opt/vault/tls/vault.crt.pem"
readonly VAULT_TLS_KEY_FILE="/opt/vault/tls/vault.key.pem"

# The cluster_tag variables below are filled in via Terraform interpolation
#su ec2-user -c 'source ~/.bash_profile; /opt/consul/bin/run-consul --client --cluster-tag-key ${consul_cluster_tag_key} --cluster-tag-value ${consul_cluster_tag_value} --elb-name ${consul_elb_name}'
su ec2-user -c 'source ~/.bash_profile; /opt/vault/bin/run-vault --s3-bucket ${s3_bucket_name} --s3-bucket-region ${aws_region} --tls-cert-file /opt/vault/tls/vault.crt.pem  --tls-key-file /opt/vault/tls/vault.key.pem --elb-name ${consul_elb_name}'
