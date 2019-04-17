#!/bin/bash -ex
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo BEGIN
# wait for the zookeeper and kafka clusters to complete setup
max=100
for (( i=0; i <= $max; ++i ))
do
echo "waiting for Kafka - $i"
#ADDRESS="$(aws ec2 describe-instances --filters Name=tag:Name,Values=zookeeper1 | jq .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateIpAddress)"
if ! su ec2-user -c 'source ~/.bash_profile; ncat -vc ls $(aws ec2 describe-instances --filters Name=tag:Name,Values=zookeeper1 | jq -r .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddresses[].PrivateIpAddress) 2181'; then
  echo "kafka not ready"
  sleep 30
else
  su ec2-user -c 'source ~/.bash_profile; python /tmp/install-tools/conf_tools.py'
  su ec2-user -c 'source ~/.bash_profile; sudo /usr/local/bin/docker-compose -f /tmp/install-tools/zoonavigator-docker-compose.yml up -d --remove-orphans'
  su ec2-user -c 'source ~/.bash_profile; sudo /usr/local/bin/docker-compose -f /tmp/install-tools/kafka-manager-docker-compose.yml up -d --remove-orphans'
  break
fi
done
echo END