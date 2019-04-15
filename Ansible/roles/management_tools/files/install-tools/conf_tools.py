import json
import boto3
import botocore
from six.moves import urllib
import subprocess
import time
import paramiko

def determineNode(nodelist, max, region):
    sum = 0
    print('in determineNode')
    for item in nodelist:
        print('item is: '+str(item))
        # Grab tag value
        tag = subprocess.check_output("aws ec2 describe-tags --profile=paul --filters \"Name=resource-id,Values="+item['InstanceId']+"\" \"Name=key,Values=Name\" --region="+region+" --output=text | cut -f5; echo",shell=True)
        tag = tag.replace('\n', '')
        tag = tag.strip()
        print("instance Tag is: "+tag)
        try:
            sum = sum + int(tag[-1:])
        except Exception as e:
            print(str(e))
        print('sum is: '+str(sum))

    # determine the sum of all nodes
    tSum = 0
    for i in range(max):
        tSum = tSum + i + 1

    # return the missing node
    sum = tSum - sum
    print('missing node is: '+str(sum))
    return sum

def getAWSValues():
    # Get the instances local IP address
    localIp = urllib.request.urlopen('http://169.254.169.254/latest/meta-data/local-ipv4').read()
    localIp = localIp.strip()
    print("instance IP is: "+localIp)

    # Get the Instance Name tag value
    instanceId=subprocess.check_output("curl http://169.254.169.254/latest/meta-data/instance-id; echo",shell=True)
    instanceId = instanceId.strip()
    print("instance ID is: "+instanceId)

    # Get the region instanc eis in
    region = subprocess.check_output("curl -s3 http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F: \'{print $2}\'; echo",shell=True)
    #print("region is: "+REGION)
    region = region.replace('"', '')
    region = region.replace(',', '')
    region = region.strip()
    print("region is: "+region)

    # Grab tag value
    tagName = subprocess.check_output("aws ec2 describe-tags --profile=paul --filters \"Name=resource-id,Values="+instanceId+"\" \"Name=key,Values=Name\" --region="+region+" --output=text | cut -f5; echo",shell=True)
    tagName = tagName.replace('\n', '')
    tagName = tagName.strip()
    print("instance Tag is: "+tagName)

    if tagName == '':
        print("there is no value for the instance tag, so wait and try again")
        time.sleep(180)
        tagName = subprocess.check_output("aws ec2 describe-tags --profile=paul --filters \"Name=resource-id,Values="+instanceId+"\" \"Name=key,Values=Name\" --region="+region+" --output=text | cut -f5; echo",shell=True)
        tagName = tagName.replace('\n', '')
        tagName = tagName.strip()
        print("instance Tag is: "+tagName)
        if tagName == '':
            print("there is still no value for the instance tag, so assuming it is kafka")
            tagName = 'management'


    # get the ASG details for kafka and zookeeper
    asg = boto3.client('autoscaling')
    kAsg = asg.describe_auto_scaling_groups(
        AutoScalingGroupNames=[
            'kafka_ASG',
        ]
    )
    print('the kafka ASGs are: '+str(kAsg['AutoScalingGroups']))
    print('the kafka ASG details are: '+str(kAsg['AutoScalingGroups'][0]['AutoScalingGroupName']))
    print('the kafka max instnces are: '+str(kAsg['AutoScalingGroups'][0]['MaxSize']))
    kmaxinstances = kAsg['AutoScalingGroups'][0]['MaxSize']
    instancelist = kAsg['AutoScalingGroups'][0]['Instances']

    zkAsg = asg.describe_auto_scaling_groups(
        AutoScalingGroupNames=[
            'zookeeper_ASG',
        ]
    )
    print('the zookeeper ASGs are: '+str(zkAsg['AutoScalingGroups']))
    print('the zookeeper ASG details are: '+str(zkAsg['AutoScalingGroups'][0]['AutoScalingGroupName']))
    print('the zookeeper max instnces are: '+str(zkAsg['AutoScalingGroups'][0]['MaxSize']))
    zkmaxinstances = zkAsg['AutoScalingGroups'][0]['MaxSize']

    return [localIp, instanceId, tagName, kmaxinstances, zkmaxinstances, instancelist, region]

def getStateFile(client, maxinstances, servername, tablename):
    #initialise the default json file
    state = {
        'state_name' : {'S':'management'},
        'changed'    : {'S':' '},
        'nodes'      : {'N':'0'},
        'semaphore'  : {'S':servername}
    }

    attributevalues = {
        ':val1': {'S':servername},
        ':val2': {'S':' '}
    }

    # create initialised table item
    index = 0
    while index < maxinstances:
        index += 1
        state['management'+str(index)] = {'S':'0.0.0.0'}

    print ('the default json data is: '+str(state))

    # update the table with the initialised values and set the semaphore,
    # unless someone has got there first - wait if they have
    index = 0
    while index < 10:
        index += 1
        try:
            client.update_item(
                Key={
                    'state_name' : {'S':'management'}
                },
                TableName=tablename,
                UpdateExpression='SET semaphore = :val1',
                ConditionExpression='(contains(semaphore,:val2)) or attribute_not_exists(semaphore)',
                ExpressionAttributeValues=attributevalues
            )
            break
        except botocore.exceptions.ClientError as e:
            # Ignore the ConditionalCheckFailedException, bubble up
            # other exceptions.
            if e.response['Error']['Code'] != 'ConditionalCheckFailedException':
                raise
        time.sleep(5)

    # if there was no error setting the semaphore then commence getting the current state
    if index < 10:
        try:
            response = client.get_item(
                Key={
                    'state_name': {'S':'management'}
                },
                TableName=tablename
            )
            print('the dynamodb response is: '+str(response))
            if response['Item']['nodes'] is None:
                print ('have just set the semaphore')
            else:
                state = response['Item']
            print('the state stored in the dynamodb table is: '+str(state))
        except Exception as e:
            print('the exception is: '+str(e))
            if str(e) == '\'Item\'':
                print('there is no item the first time the table is read, ignore')
            else:
                if str(e) == '\'nodes\'':
                    print ('have just set the semaphore, ignore')
                else:
                    raise e

        print ('the converted state is: '+str(state))
    else:
        raise Exception("the state file is locked and can't update it")

    state['semaphore'] = {'S':' '}
    return state



def changeTagName(tag, ip, state, list, maxinstances, region):
    # changing the default instance tag name to reflect the node in the ASG
    if tag == 'management':
        # if we're initialising the ASG
        if int(state.get('nodes').get('N')) < maxinstances:
            print('changing name for initial node')
            tag = tag+(str(int(state.get('nodes').get('N'))+1))
            state['nodes'] = {'N':str(int(state.get('nodes').get('N'))+1)}
        # if one of the nodes has died and been replaced in the ASG
        else:
            print('changing name for existing node')
            tag = tag+str(determineNode(list, maxinstances, region))
            print('TAG_VALUE is now: '+tag)
            state['nodes'] = {'N':str(int(state.get('nodes').get('N'))+1)}

    # Update the JSON with the changed IP for the server
    print (state[tag])
    state[tag] = {'S':ip}
    state['changed'] = {'S':tag}
    print (state)

    return [tag, state]


if __name__ == "__main__":


    # get the AWS values needed to lookup the relevant state and ASG data
    valueList = getAWSValues()
    LOCAL_IP = valueList[0]
    INSTANCE_ID = valueList[1]
    TAG_VALUE = valueList[2]
    kmaxInstances = valueList[3]
    zkmaxInstances = valueList[4]
    instanceList = valueList[5]
    region = valueList[6]

    # initialise needed variables
    session = boto3.Session(profile_name='terraform', region_name=region)
    client = session.client('dynamodb')
    tablename = 'management-state'

    # get the current details from the DynamoDB table
    # data = getStateFile(table, kmaxInstances)
    data = getStateFile(client, kmaxInstances, TAG_VALUE, tablename)

    # change the intances tag Name to reflect the node in the ASG
    retvals = changeTagName(TAG_VALUE, LOCAL_IP, data, instanceList, kmaxInstances, region)
    TAG_VALUE = retvals[0]
    data = retvals[1]
    print('updated data is :'+str(data))

    # Uploads the given file using a managed uploader, which will split up large
    # files automatically and upload parts in parallel.
    #s3.Bucket(bucket_name).put_object(Key=filename, Body=json.dumps(data))
    client.put_item(
        Item=data,
        TableName=tablename
    )

    # Change the instance Name tag value
    ec2 = session.resource('ec2')
    ec2.create_tags(Resources=[INSTANCE_ID], Tags=[{'Key':'Name', 'Value':TAG_VALUE}])

    # Update the /etc/hosts file
    # Add hosts entries (mocking DNS) - put relevant IPs here
    subprocess.check_output("sudo su ec2-user -c \'python /tmp/install-tools/update_etc_hosts.py "+str(kmaxInstances)+" "+str(zkmaxInstances)+" "+str(region)+"\'", shell=True, executable='/bin/bash')

    # update the services.properties file
    node = TAG_VALUE[-1:]
    index = 0
    zookeeperList = ''
    while index < zkmaxInstances:
        index += 1
        zookeeperList = zookeeperList+'zookeeper'+str(index)+":2181,"

    # remove extraneous comma at en of the list
    zookeeperList = zookeeperList[:-1]
    print ('the zookeeper list is: '+zookeeperList)

    index = 0
    kafkaList = ''
    while index < kmaxInstances:
        index += 1
        kafkaList = kafkaList+'kakfa'+str(index)+":9092,"

    # remove extraneous comma at en of the list
    kafkaList = kafkaList[:-1]
    print ('the kafka list is: '+kafkaList)

    if node != "1":
        subprocess.check_output("sudo python /tmp/install-tools/replaceAll.py /tmp/install-tools/kafka-manager-docker-compose.yml \'ZOOKEEPER_HOSTS: \"zookeeper1:2181,zookeeper2:2181,zookeeper3:2181\"\' \'ZOOKEEPER_HOSTS: \""+zookeeperList+"\"\'", shell=True, executable='/bin/bash')
        # change the app secret to something you want - default is change_me_please
        subprocess.check_output("sudo python /tmp/install-tools/replaceAll.py /tmp/install-tools/kafka-manager-docker-compose.yml \'APPLICATION_SECRET: change_me_please\' \'APPLICATION_SECRET: change_me_please\'", shell=True, executable='/bin/bash')

    # update the /etc/hosts on existing kafka nodes to reflect change on this node
    for key in data:
        print('key is: ')
        print(key)
        jsonName = key.encode("utf-8")
        print('jsonName is: ')
        print(jsonName)
        print('node in data is: ')
        print(data[jsonName].get('S'))
        if jsonName != TAG_VALUE and jsonName != 'changed' and jsonName != '' and jsonName != 'nodes' and jsonName != 'state_name' and jsonName != 'semaphore' and data[jsonName] != '0.0.0.0':
            try:
                print('updating etc hosts on: '+jsonName)
                private_key = paramiko.RSAKey.from_private_key_file('/tmp/install-tools/<your .pem file>')
                client = paramiko.client.SSHClient()
                client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                client.connect(jsonName, port=22, username='ec2-user', pkey=private_key)
                s = client.get_transport().open_session()
                s.exec_command("sudo su ec2-user -c \'python /tmp/install-tools/update_etc_hosts.py "+str(kmaxInstances)+" "+str(zkmaxInstances)+"\'")
            except Exception as e:
                print(str(e))