#!/bin/bash

set -ex

#sudo yum -y update

# Install packages to allow apt to use a repository over HTTPS:
#sudo yum install -y \
#    apt-transport-https \
#    ca-certificates \
#    curl \
#    software-properties-common

# install docker
sudo yum install -y docker

# install docker compose
sudo pip install docker-compose

# give permissions to execute docker
sudo usermod -aG docker $(whoami)