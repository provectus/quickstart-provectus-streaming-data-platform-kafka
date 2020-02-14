
import os
import sys

import requests


directory = "avro"
schema_registry_url = sys.argv[1]


def register_schema(topic, schema_file, schema_registry_url):
    aboslute_path_to_schema = os.path.join(os.getcwd(), schema_file)
    print("Schema Registry URL: " + schema_registry_url)
    print("Topic: " + topic)
    print("Schema file: " + schema_file)
    print("Absolute path to file: " + aboslute_path_to_schema)
    print("...")

    with open(aboslute_path_to_schema, 'r') as content_file:
        schema = content_file.read()

    payload = "{ \"schema\": \"" \
              + schema.replace("\"", "\\\"").replace("\t", "").replace("\n", "") \
              + "\" }"

    url = schema_registry_url + "/subjects/" + topic + "-value/versions"
    headers = {"Content-Type": "application/vnd.schemaregistry.v1+json"}

    r = requests.post(url, headers=headers, data=payload)
    if r.status_code == requests.codes.ok:
        print("Success")
        print("...")
    else:
        r.raise_for_status()


for file in os.listdir(directory):
    filename = file
    if filename.endswith(".avsc"):
        fullname = os.path.join(directory, filename)
        topic = filename.split(".")[0]
        register_schema(topic, fullname, schema_registry_url)
        continue
    else:
        continue

