#!/bin/bash -ex
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo BEGIN
su ec2-user -c 'source ~/.bash_profile; python /tmp/install-kafka/conf_kafka.py'
# wait for the zookeeper cluster to complete setup
max=10
for (( i=0; i <= $max; ++i ))
do
echo "waiting for Zookeeper - $i"
if ! su ec2-user -c 'source ~/.bash_profile; nc --send-only </dev/null zookeeper1 2181'; then
  echo "Zookeeper not ready"
  sleep 30
else
  # start kafka
  su ec2-user -c 'sudo service kafka start\'
  break
fi
done
echo END