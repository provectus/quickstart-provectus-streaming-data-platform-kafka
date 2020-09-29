import os
import sys
import cfnresponse
import requests
from schema_registry.client import SchemaRegistryClient, schema
import boto3
import json

def lambda_handler(event, context):
    responseData = {}
    print(event)
    if 'SchemaRegistryURI' in os.environ:
        SchemaRegistryURI = os.environ['SchemaRegistryURI']
        print('SchemaRegistryURI is: {}'.format(SchemaRegistryURI))
    else: 
        responseData['cause'] = "Schema registry URI not provided"
        cfnresponse.send(event, context, cfnresponse.FAILED, responseData)

    if 'SchemaFile' in event['ResourceProperties']:
        s3 = boto3.resource('s3')
        content_object = s3.Object(event['ResourceProperties']['S3Bucket'], 
            event['ResourceProperties']['SchemaFile'])
        file_content = content_object.get()['Body'].read().decode('utf-8')
        json_content = json.loads(file_content)
        print("Loaded AVRO schema from file {}".format(json_content))
    else:
        responseData['status'] = "Location of Schema file not provided"
        responseData['cause'] = event['ResourceProperties']
        print('SchemaFile not provided')
        cfnresponse.send(event, context, cfnresponse.FAILED, responseData)

    if event['RequestType'] == 'Create':
        if 'type' in json_content:
            print("Looks like we got valide AVRO schema")
            try:
                client = SchemaRegistryClient(url=SchemaRegistryURI)
            except Exception as e:
                responseData['cause'] = "Schema registry client cannot be created {} \
                    ".format(e.__class__.__name__)
                print(responseData['cause'])
                cfnresponse.send(event, context, cfnresponse.FAILED, responseData)
            print('Schema registry client created')  
            avro_schema = schema.AvroSchema(json_content)
            print('AVRO schema object created')
            ###Get subjects, just for debug
            list_registered_subjects = requests.get(SchemaRegistryURI + "/subjects")
            print("Native http rest response, list of current subjects {}, \
                ".format(list_registered_subjects.json()))
            try:
                schema_id = client.register(event['ResourceProperties']['TopicName'] + "-value", avro_schema, timeout=2)
                responseData['cause'] = "Schema {} for subject {} created successfully, schema id is {} \
                    ".format(json_content['name'], event['ResourceProperties']['TopicName'], schema_id)
                print(responseData['cause'])
                cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData)
            except Exception as e:
                responseData['cause'] = "Some exception in request to schema register happened, {}\
                    ".format(responseData['cause'])
                print (responseData['cause'])
                cfnresponse.send(event, context, cfnresponse.FAILED, responseData)
        else:
            responseData['cause'] = 'Provided file not an AVRO schema, \
                there are no /"type/" field in request object'
            print(responseData['cause'])
            cfnresponse.send(event, context, cfnresponse.FAILED, responseData)

    else:
        #if event['RequestType'] == 'Delete' or event['RequestType'] == 'Update':
        responseData['cause'] = 'CloudFormation Delete and Update method not implemented, \
            just return cnfresponse=SUCCSESS without any job/modifications'
        cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData)
