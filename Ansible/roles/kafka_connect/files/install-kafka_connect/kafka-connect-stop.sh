#!/bin/sh
PID=$(ps ax | grep -i 'kafka.connect' | grep -v grep | awk '{print $1}' | tr '\n' ' ' | cut -d ' ' -f1)
sudo kill -9 $PID