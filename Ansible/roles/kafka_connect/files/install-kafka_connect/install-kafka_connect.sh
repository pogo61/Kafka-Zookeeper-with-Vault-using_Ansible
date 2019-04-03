#!/bin/bash

set -ex

cd /tmp

# download Kafka. Recommended is latest Kafka (0.10.2.1) and Scala 2.12
wget https://archive.apache.org/dist/kafka/0.11.0.2/kafka_2.12-0.11.0.2.tgz
tar -xvzf kafka_2.12-0.11.0.2.tgz
ls -las
#sudo mkdir -p /opt/kafka
sudo mv /tmp/kafka_2.12-0.11.0.2 /opt/kafka
sudo ls -las /opt/kafka

rm kafka_2.12-0.11.0.2.tgz

sudo cp /tmp/install-kafka_connect/worker.properties /opt/kafka/config/worker.properties
sudo cp /tmp/install-kafka_connect/connect-log4j.properties /opt/kafka/config/connect-log4j.properties
sudo cp /tmp/install-kafka_connect/kafka-connect-stop.sh /opt/kafka/bin/kafka-connect-stop.sh
sudo chmod +x /opt/kafka/bin/kafka-connect-stop.sh

# Install Kafka connect boot scripts
sudo mv /tmp/install-kafka_connect/kafka_connect_service /etc/init.d/kafkaconnect
sudo chmod +x /etc/init.d/kafkaconnect
sudo chown root:root /etc/init.d/kafkaconnect

sudo chkconfig --add kafkaconnect
sudo chkconfig kafkaconnect on

# start kafka
sudo service kafkaconnect start


