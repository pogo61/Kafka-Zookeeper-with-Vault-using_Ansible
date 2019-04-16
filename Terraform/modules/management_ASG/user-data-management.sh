#!/bin/bash -ex
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo BEGIN
# wait for the zookeeper and kafka clusters to complete setup
su ec2-user -c 'source ~/.bash_profile; python /tmp/install-tools/conf_tools.py'
max=10
for (( i=0; i <= $max; ++i ))
do
echo "waiting for Kafka - $i"
if ! su ec2-user -c 'source ~/.bash_profile; ncat -vc ls zookeeper1 2181'; then
  echo "kafka not ready"
  sleep 30
else
  su ec2-user -c 'source ~/.bash_profile; sudo /usr/local/bin/docker-compose -f /tmp/install-tools/zoonavigator-docker-compose.yml up -d'
  su ec2-user -c 'source ~/.bash_profile; sudo /usr/local/bin/docker-compose -f /tmp/install-tools/kafka-manager-docker-compose.yml up -d'
  break
fi
done
echo END