import os
import sys
import cfnresponse
import requests
from schema_registry.client import SchemaRegistryClient, schema
import json

def lambda_handler(event, context):
    responseData = {}
    print(event)
    if 'SCHEMA_REEGISTRY_URI' in os.environ:
        SchemaRegistryURI = os.environ['SCHEMA_REEGISTRY_URI']
        print('SchemaRegistryURI is: {}'.format(SchemaRegistryURI))
    else: 
        responseData['cause'] = "Schema registry URI not provided"
        cfnresponse.send(event, context, cfnresponse.FAILED, responseData)

    if 'SchemaConfig' in event['ResourceProperties']:
        json_content = json.loads(event['ResourceProperties']['SchemaConfig'])
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
                schema_id = client.register(json_content['name'] + "-value", avro_schema, timeout=2)
                responseData['cause'] = "Schema {} created successfully, schema id is {} \
                    ".format(json_content['name'], schema_id)
                print(responseData['cause'])
                cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData)
            except Exception as e:
                responseData['cause'] = "Some exception in request to schema register happened, {}\
                    ".format(format(e.__class__.__name__))
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
