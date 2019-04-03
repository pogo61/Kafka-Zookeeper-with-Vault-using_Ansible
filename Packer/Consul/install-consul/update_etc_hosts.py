import json
import boto3
import botocore
import subprocess
import sys

def updateHosts(vkmaxInstances):

    session = boto3.Session(profile_name='terraform')
    dynamodb = session.resource('dynamodb')
    table = dynamodb.Table('consul-state')

    try:
        response = table.get_item(
            Key={
                'state_name': 'consul'
            }
        )
        print('the dynamodb response is: '+str(response))
        vdata = response['Item']
        print('the state stored in the dynamodb table is: '+str(vdata))
    except Exception as e:
        print('the exception is: '+str(e))
        if str(e) == '\'Item\'':
            print('there is no item the first time the table is read, ignore')
        else:
            raise e

    print (vdata)

    #update the consul IP's
    index = 0
    print('the max consul instances is: '+str(vkmaxInstances))
    while index < int(vkmaxInstances):
        index += 1
        print(index, vdata['consul'+str(index)])
        subprocess.check_output("sudo python /tmp/install-consul/replaceAll.py /etc/hosts \"0.0.0.0 consul"+str(index)+"\" \""+vdata['consul'+str(index)]+" consul"+str(index)+"\"", shell=True, executable='/bin/bash')


if __name__ == "__main__":
    print("This is the name of the script: ", sys.argv[0])
    print("Number of arguments: ", len(sys.argv))
    print("The arguments are: " , str(sys.argv))
    updateHosts(sys.argv[1])