import json
import boto3
import botocore
import subprocess
import sys

def updateHosts(zkmaxInstances):

    session = boto3.Session(profile_name='terraform')
    dynamodb = session.resource('dynamodb')
    table = dynamodb.Table('zookeeper-state')

    try:
        response = table.get_item(
            Key={
                'state_name': 'zookeeper'
            }
        )
        print('the dynamodb response is: '+str(response))
        zkdata = response['Item']
        print('the state stored in the dynamodb table is: '+str(zkdata))
    except Exception as e:
        print('the exception is: '+str(e))
        if str(e) == '\'Item\'':
            print('there is no item the first time the table is read, ignore')
        else:
            raise e

    print (zkdata)

    # stop zookeeper
    subprocess.check_output("sudo su ec2-user -c 'sudo service zookeeper stop'", shell=True, executable='/bin/bash')

    #update the zookeeper IP's
    index = 0
    print('the max zookeeper instances is: '+str(zkmaxInstances))
    while index < int(zkmaxInstances):
        index += 1
        print(index, zkdata['zookeeper'+str(index)])
        subprocess.check_output("sudo python /tmp/install-zookeeper/replaceAll.py /etc/hosts \"0.0.0.0 zookeeper"+str(index)+"\" \""+zkdata['zookeeper'+str(index)]+" zookeeper"+str(index)+"\"", shell=True, executable='/bin/bash')

    # start zookeeper
    subprocess.check_output("sudo su ec2-user -c 'sudo service zookeeper start'", shell=True, executable='/bin/bash')

if __name__ == "__main__":
    print("This is the name of the script: ", sys.argv[0])
    print("Number of arguments: ", len(sys.argv))
    print("The arguments are: " , str(sys.argv))
    updateHosts(sys.argv[1])