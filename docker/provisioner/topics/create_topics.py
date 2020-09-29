import json
import os
from kafka.admin import KafkaAdminClient, NewTopic
import cfnresponse


def lambda_handler(event, context):
    responseData = {}
    print ("Request body is:", event)
    if event['RequestType'] == 'Create':
        bootstrap_uri = "Bootstrap servers not provided in env"
        if 'BootstrapServers' in os.environ:
            bootstrap_uri = os.environ['BootstrapServers']
            print(bootstrap_uri)
        else: 
            print(bootstrap_uri)
            responseData['cause'] = "Bootstrap servers not mentioned in env variables"
            cfnresponse.send(event, context, cfnresponse.FAILED, responseData)

        try:
            admin_client = KafkaAdminClient(bootstrap_servers=bootstrap_uri, 
                client_id='test')
        except Exception as e:
            responseData['status'] = "Failed to make KafkaAdmin Client, posssible reasons:bootstrap server name not resolvable, \
            bootsrap servers not reacheable, MSK cluster not running"
            print(e)
            cfnresponse.send(event, context, cfnresponse.FAILED, responseData)

        if 'kafka_topic' in event['ResourceProperties']:
            topic_list = []
            topic_list.append(NewTopic(name=event['ResourceProperties']['kafka_topic']['name'], 
                    num_partitions=int(event['ResourceProperties']['kafka_topic']['num_partitions']), 
                    replication_factor=int(event['ResourceProperties']['kafka_topic']['replication_factor'])))
            try:
                admin_client.create_topics(new_topics=topic_list, validate_only=False)
                responseData['status'] = "Topic created successfully"
                responseStatus = cfnresponse.SUCCESS
            except Exception as e:
                print("Failed to create topic:", e)
                responseData['status'] = 'FAILED'
                responseData['cause'] = e
                responseStatus = cfnresponse.FAILED
        else: 
            responseData['cause'] = 'Failed to create topics, no kafka_topic provided'
            responseStatus = cfnresponse.FAILED

        cfnresponse.send(event, context, responseStatus, responseData)
    else:
        #if event['RequestType'] == 'Delete' or event['RequestType'] == 'Update':
        responseData['cause'] = 'CloudFormation Delete and Update method not implemented, just return cnfresponse=SUCCSESS without any job/modifications'
        cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData)
