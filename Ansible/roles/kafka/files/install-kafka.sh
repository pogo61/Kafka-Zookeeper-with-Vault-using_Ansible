#!/bin/bash

set -ex

# create kafka directory
sudo mkdir -p /data/kafka

# check it's working
sudo df -h /data/kafka

sudo chown -R ec2-user:ec2-user /data/kafka

cd /tmp

# download Kafka.
wget https://archive.apache.org/dist/kafka/0.11.0.2/kafka_2.12-0.11.0.2.tgz
tar -xvzf kafka_2.12-0.11.0.2.tgz
ls -las
#sudo mkdir -p /opt/kafka
sudo mv /tmp/kafka_2.12-0.11.0.2 /opt/kafka
sudo ls -las /opt/kafka


rm kafka_2.12-0.11.0.2.tgz

sudo mv /tmp/install-kafka/server.properties /opt/kafka/config/server.properties
# launch kafka - make sure things look okay

# Install Kafka boot scripts
sudo mv /tmp/install-kafka/kafka_service /etc/init.d/kafka
sudo chmod +x /etc/init.d/kafka
sudo chown root:root /etc/init.d/kafka

sudo chkconfig --add kafka
sudo chkconfig kafka on

# start kafka
sudo service kafka start
# verify it's working
#nc -vz localhost 9092
# look at the logs
#cat /home/ubuntu/kafka/logs/server.log

exit 0