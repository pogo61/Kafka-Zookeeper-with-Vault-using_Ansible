#!/bin/bash

set -ex

sudo yum -y update

# Install packages to allow apt to use a repository over HTTPS:
sudo yum install -y \
    apt-transport-https \
    wget \
    zip \
    net-tools \
    tar \
    nmap-ncat \
    ca-certificates \
    curl \
    software-properties-common

# Java JDK 8
wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u152-b16/aa0333dd3019491ca4f6ddbe78cdb6d0/jdk-8u152-linux-x64.rpm"
sudo yum -y localinstall jdk-8u152-linux-x64.rpm
rm jdk-8u152-linux-x64.rpm
java -version

cd /tmp

# download Kafka. Recommended is latest Kafka (0.10.2.1) and Scala 2.12
wget http://apache.mirror.digitalpacific.com.au/kafka/0.11.0.2/kafka_2.12-0.11.0.2.tgz
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


