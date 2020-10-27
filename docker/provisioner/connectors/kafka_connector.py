import json
import os
import cfnresponse
import requests


def lambda_handler(event, context):
    responseData = {}
    print ("Request body is:", event)
    headers = {'Content-Type': 'application/json', 'Accept': 'application/json'}
    if event['RequestType'] == 'Create':
        ### Check provided data, it will be passed to Kafka Connect rest api /connections/
        if 'connector_definition' in event['ResourceProperties'] and 'KAFKA_CONNECT_ENDPOINT' in os.environ:
            connect_endpoint = os.environ['KAFKA_CONNECT_ENDPOINT']
            print ("Provided Kafka connect config is:", event['ResourceProperties']['connector_definition'])
            print ("Received object type is:", type(event['ResourceProperties']['connector_definition']))
            print ("Provided Kafka endpoint:", connect_endpoint)
            try:
                r = requests.post(connect_endpoint + '/connectors', 
                    data=json.dumps(event['ResourceProperties']['connector_definition']), headers=headers)
                print("KafkaConnect response for Connector creation request is:", r.status_code, r.json())
                responseStatus = cfnresponse.SUCCESS
                responseData['Status'] = "SUCCESS"
            except Exception as e:
                print(e)
                responseData['status'] = 'FAILED create Kafka connect worker'
                responseData['cause'] = e
                cfnresponse.send(event, context, cfnresponse.FAILED, responseData)

        elif 'get_connectors' in event['ResourceProperties'] and 'KAFKA_CONNECT_ENDPOINT' in os.environ:
            try:
                r = requests.get(os.environ['KAFKA_CONNECT_ENDPOINT'] + '/connectors',  headers=headers)
                print("List of KafkaConnect connectors:", r.status_code, r.text)
                if type(r.json()) is list and len(r.json()) > 0:
                    for connector in r.json():
                        connector_config = requests.get(os.environ['KAFKA_CONNECT_ENDPOINT'] + 
                            '/connectors/' + connector,  headers=headers)
                        connector_status = requests.get(os.environ['KAFKA_CONNECT_ENDPOINT'] + 
                            '/connectors/' + connector + "/status",  headers=headers)
                        print("Connector config for {}, is {}, status is {}"
                            .format(connector, connector_config.json(), connector_status.json()))
                responseStatus = cfnresponse.SUCCESS
            except Exception as e:
                responseStatus = cfnresponse.FAILED
                print(e)
                responseData['status'] = 'FAILED to create Kafka connector'
                responseData['cause'] = e
                cfnresponse.send(event, context, responseStatus, responseData)
        else:
            responseData['Status'] = "Kafka config or connect_endpoint not provided"
            print (responseData['Status'])
            responseStatus = cfnresponse.FAILED

        
    elif event['RequestType'] == 'Update':
        if 'connector_definition' in event['ResourceProperties'] and 'KAFKA_CONNECT_ENDPOINT' in os.environ:
            connect_endpoint = os.environ['KAFKA_CONNECT_ENDPOINT']
            print ("Provided Kafka connect config is:", event['ResourceProperties']['connector_definition'])
            print ("Provided Kafka endpoint:", connect_endpoint)
            try:
                r = requests.put(connect_endpoint + '/connectors/' + event['ResourceProperties']['connector_definition']['name'] + '/config', 
                    data=json.dumps(event['ResourceProperties']['connector_definition']['config']), headers=headers)
                print("KafkaConnect response for Connector update request is:", r.status_code, r.json())
                responseStatus = cfnresponse.SUCCESS
                responseData['Status'] = "SUCCESS"
            except Exception as e:
                responseStatus = cfnresponse.FAILED
                print(e)
                responseData['status'] = 'FAILED to Update Kafka connector'
                responseData['cause'] = e
                cfnresponse.send(event, context, responseStatus, responseData)

    elif event['RequestType'] == 'Delete':
        if 'connector_definition' in event['ResourceProperties'] and 'KAFKA_CONNECT_ENDPOINT' in os.environ:
            connect_endpoint = os.environ['KAFKA_CONNECT_ENDPOINT']
            print ("Provided Kafka connect config is:", event['ResourceProperties']['connector_definition'])
            print ("Provided Kafka endpoint:", connect_endpoint)
            try:
                r = requests.delete(connect_endpoint + '/connectors/' 
                    + event['ResourceProperties']['connector_definition']['name'] + '/')
                print("KafkaConnect response for Connector deletion request is:", r.status_code)
                responseStatus = cfnresponse.SUCCESS
                responseData['Status'] = "SUCCESS"
            except Exception as e:
                responseStatus = cfnresponse.FAILED
                print(e)
                responseData['status'] = 'FAILED to Delete Kafka connector'
                responseData['cause'] = e
                cfnresponse.send(event, context, responseStatus, responseData)
    else:
        responseData['cause'] = 'Requested method not found'
        responseData['Status'] = "SUCCESS"
    cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData)
