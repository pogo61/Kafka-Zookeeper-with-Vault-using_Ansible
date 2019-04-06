#!/bin/bash
#
# chkconfig:    345 83 04
# description: Zookeeper is a distributed name/valur pair and config manager
# processname: zookeeper
#
### BEGIN INIT INFO
# Provides: zookeeper
# Required-Start: $all
# Required-Stop: $all
# Short-Description: start and stop zookeeper process control system
# Description: Zookeeper is a distributed name/valur pair and config manager
### END INIT INFO

# Source function library
. /etc/rc.d/init.d/functions

#/etc/init.d/zookeeper
DAEMON_PATH=/opt/zookeeper/kafka/bin
DAEMON_NAME=zookeeper
# Check that networking is up.
#[ ${NETWORKING} = "no" ] && exit 0

PATH=$PATH:$DAEMON_PATH

# See how we were called.
case "$1" in
  start)
        # Start daemon.
        pid=`ps ax | grep -i 'org.apache.zookeeper' | grep -v grep | awk '{print $1}'`
        if [ -n "$pid" ]
          then
            echo "Zookeeper is already running";
        else
          echo "Starting $DAEMON_NAME";
          $DAEMON_PATH/zookeeper-server-start.sh -daemon /opt/zookeeper/kafka/config/zookeeper.properties
        fi
        ;;
  stop)
        echo "Shutting down $DAEMON_NAME";
        $DAEMON_PATH/zookeeper-server-stop.sh
        ;;
  restart)
        $0 stop
        sleep 2
        $0 start
        ;;
  status)
        pid=`ps ax | grep -i 'org.apache.zookeeper' | grep -v grep | awk '{print $1}'`
        if [ -n "$pid" ]
          then
          echo "Zookeeper is Running as PID: $pid"
        else
          echo "Zookeeper is not Running"
        fi
        ;;
  *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
esac

exit 0
