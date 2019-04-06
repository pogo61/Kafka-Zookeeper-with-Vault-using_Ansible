import json
import boto3
import botocore
import subprocess
import sys

def updateHosts(kmaxInstances, zkmaxInstances):

    session = boto3.Session(profile_name='terraform')
    dynamodb = session.resource('dynamodb')
    ktable = dynamodb.Table('kafka-state')
    zktable = dynamodb.Table('zookeeper-state')

    try:
        response = ktable.get_item(
            Key={
                'state_name': 'kafka'
            }
        )
        print('the dynamodb response is: '+str(response))
        kdata = response['Item']
        print('the state stored in the dynamodb table is: '+str(kdata))
    except Exception as e:
        print('the exception is: '+str(e))
        if str(e) == '\'Item\'':
            print('there is no item the first time the table is read, ignore')
        else:
            raise e

    print (kdata)

    try:
        response = zktable.get_item(
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

    # s3 = session.resource('s3')
    #
    # filename = 'kafka_ips.json'
    # path = '/tmp/install-kafka/'
    # bucket_name = 'kafka-bucket-pp'
    #
    #
    # # get the zookeeper node file from S3
    # s3.Bucket(bucket_name).download_file(filename, path+filename)
    #
    # #Read JSON data into the datastore variable
    # data = json.load(open(path+filename,'r'))
    #
    # # Get the Zookeeper IP addresses
    # zkfilename = 'zookeeper_ips.json'
    # zkpath = '/tmp/install-kafka/'
    # zkbucket_name = 'zookeeper-bucket-pp'
    #
    # try:
    # # Download object at bucket-name with key-name to file-like object
    #     with open(zkpath+zkfilename, "w+") as f:
    #         s3.Bucket(zkbucket_name).download_fileobj(zkfilename, f)
    # except botocore.exceptions.ClientError as e:
    #     if e.response['Error']['Code'] == "404":
    #         print("The is a problem and there should be a Zookeeper cluster up")
    #         print(e)
    #         #raise e
    #     else:
    #         print(e)
    #         raise e
    #
    # #Read JSON data into the datastore variable
    # zkdata = json.load(open(zkpath+zkfilename,'r'))
    # print (zkdata)

    # stop kafka
    subprocess.check_output("sudo su ec2-user -c 'sudo service kafka stop'", shell=True, executable='/bin/bash')

    # Update the /etc/hosts file
    # Add hosts entries (mocking DNS) - put relevant IPs here
    #update the kafka IP's
    index = 0
    print('the max kafka instances is: '+str(kmaxInstances))
    while index < int(kmaxInstances):
        try:
            index += 1
            print('kafka'+str(index))
            print("sudo python /tmp/install-kafka/replaceAll.py /etc/hosts \'0.0.0.0 kafka"+str(index)+"\' \'"+kdata['kafka'+str(index)]+" kafka"+str(index)+"\'")
            subprocess.check_output("sudo python /tmp/install-kafka/replaceAll.py /etc/hosts \'0.0.0.0 kafka"+str(index)+"\' \'"+kdata['kafka'+str(index)]+" kafka"+str(index)+"\'", shell=True, executable='/bin/bash')
        except Exception as e:
            print(e)
            raise e

    #update the zookeeper IP's
    index = 0
    print('the max zookeeper instances is: '+str(zkmaxInstances))
    while index < int(zkmaxInstances):
        index += 1
        print(index, zkdata['zookeeper'+str(index)])
        subprocess.check_output("sudo python /tmp/install-kafka/replaceAll.py /etc/hosts \"0.0.0.0 zookeeper"+str(index)+"\" \""+zkdata['zookeeper'+str(index)]+" zookeeper"+str(index)+"\"", shell=True, executable='/bin/bash')

    # start kafka
    subprocess.check_output("sudo su ec2-user -c 'sudo service kafka start'", shell=True, executable='/bin/bash')

if __name__ == "__main__":
    print("This is the name of the script: ", sys.argv[0])
    print("Number of arguments: ", len(sys.argv))
    print("The arguments are: " , str(sys.argv))
    updateHosts(sys.argv[1],sys.argv[2])