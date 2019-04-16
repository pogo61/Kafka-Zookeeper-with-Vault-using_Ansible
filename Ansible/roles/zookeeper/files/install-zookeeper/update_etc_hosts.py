import json
import boto3
import botocore
import subprocess
import sys
from six.moves import urllib

def getAWSValues():
    # Get the instances IP address
    localip = urllib.request.urlopen('http://169.254.169.254/latest/meta-data/local-ipv4').read()
    localip = localip.strip()
    print("instance IP is: "+localip)

    # Get the Instance Name tag value
    instanceid=subprocess.check_output("curl http://169.254.169.254/latest/meta-data/instance-id; echo",shell=True)
    instanceid = instanceid.strip()
    print("instance ID is: "+instanceid)

    # Get the region instanc eis in
    region = subprocess.check_output("curl -s3 http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F: \'{print $2}\'; echo",shell=True)
    #print("region is: "+REGION)
    region = region.replace('"', '')
    region = region.replace(',', '')
    region = region.strip()
    print("region is: "+region)


    return [localip, instanceid, region]

def updateHosts(zkmaxInstances):

    # get the AWS values needed to lookup the relevant state and ASG data
    valueList = getAWSValues()
    LOCAL_IP = valueList[0]
    INSTANCE_ID = valueList[1]
    region = valueList[2]

    # initialise needed variables
    session = boto3.Session(profile_name='terraform', region_name=region)
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