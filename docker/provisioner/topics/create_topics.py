import os
from kafka.admin import KafkaAdminClient, NewTopic
import cfnresponse


def lambda_handler(event, context):
    responseData = {}
    responseStatus = cfnresponse.SUCCESS
    print ("Request body is:", event)
    if event['RequestType'] == 'Create':
        bootstrap_uri = "Bootstrap servers not provided in env"
        if 'BOOTSTRAP_SERVERS' in os.environ:
            bootstrap_uri = os.environ['BOOTSTRAP_SERVERS']
            print(bootstrap_uri)
        else: 
            print(bootstrap_uri)
            responseData['cause'] = "Bootstrap servers not mentioned in env variables"
            cfnresponse.send(event, context, cfnresponse.FAILED, responseData)

        try:
            admin_client = KafkaAdminClient(bootstrap_servers=bootstrap_uri, 
                client_id='lambda')
        except Exception as e:
            responseData['status'] = "Failed to make KafkaAdmin Client, posssible reasons:bootstrap server name not resolvable, \
            bootsrap servers not reacheable, MSK cluster not running"
            print(e)
            cfnresponse.send(event, context, cfnresponse.FAILED, responseData)

        if 'KafkaTopic' in event['ResourceProperties']:
            topic_list = []
            topic_list.append(NewTopic(name=event['ResourceProperties']['KafkaTopic']['name'], 
                    num_partitions=int(event['ResourceProperties']['KafkaTopic']['num_partitions']), 
                    replication_factor=int(event['ResourceProperties']['KafkaTopic']['replication_factor'])))
            try:
                admin_client.create_topics(new_topics=topic_list, validate_only=False)
                responseData['status'] = "Topic created successfully"
                
            except Exception as e:
                print("Failed to create topic:", e)
                responseData['status'] = 'FAILED'
                responseData['cause'] = e
                cfnresponse.send(event, context, cfnresponse.FAILED, responseData)
        else: 
            responseData['cause'] = 'Failed to create topics, no KafkaTopic provided'
            responseStatus = cfnresponse.FAILED

    else:
        #if event['RequestType'] == 'Delete' or event['RequestType'] == 'Update':
        responseData['cause'] = 'CloudFormation Delete and Update method not implemented, just return cnfresponse=SUCCSESS without any job/modifications'
        responseStatus = cfnresponse.SUCCESS
    cfnresponse.send(event, context, responseStatus, responseData)
