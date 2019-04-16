#!/bin/bash -ex
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo BEGIN
su ec2-user -c 'source ~/.bash_profile; python /tmp/install-kafka_connect/conf_kafka_connect.py'
# wait for the zookeeper and kafka clusters to complete setup
max=10
for (( i=0; i <= $max; ++i ))
do
echo "waiting for Kafka - $i"
if ! su ec2-user -c 'source ~/.bash_profile; ncat -vc ls zookeeper1 2181'; then
  echo "kafka not ready"
  sleep 30
else
  su ec2-user -c 'source ~/.bash_profile; sudo service kafkaconnect stop'
  result=$(su ec2-user -c 'source ~/.bash_profile; /opt/kafka/bin/kafka-topics.sh --list --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka')
  if [[ $result == *"connect-offsets"* ]] || [[ $result == *"connect-config"* ]] || [[ $result == *"connect-status"* ]] || [[ $result == *"connect-data"* ]]; then
    echo "kafka connect topics already created"
    # run kafka connect
    su ec2-user -c 'source ~/.bash_profile; sudo service kafkaconnect start'
    break
  else
    # set up kafka connect topics in existing kafka cluster
    su ec2-user -c 'source ~/.bash_profile; /opt/kafka/bin/kafka-topics.sh --create --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --replication-factor 2 --partitions 3 --topic connect-offsets'
    su ec2-user -c 'source ~/.bash_profile; /opt/kafka/bin/kafka-topics.sh --create --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --replication-factor 2 --partitions 3 --topic connect-config'
    su ec2-user -c 'source ~/.bash_profile; /opt/kafka/bin/kafka-topics.sh --create --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --replication-factor 2 --partitions 3 --topic connect-status'
    su ec2-user -c 'source ~/.bash_profile; /opt/kafka/bin/kafka-topics.sh --create --zookeeper zookeeper1:2181,zookeeper2:2181,zookeeper3:2181/kafka --replication-factor 2 --partitions 3 --topic connect-data'
    # run kafka connect
    su ec2-user -c 'source ~/.bash_profile; sudo service kafkaconnect start'
    break
  fi
fi
done
echo END