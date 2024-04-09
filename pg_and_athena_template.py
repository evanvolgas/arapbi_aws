import pandas as pd
from sqlalchemy import create_engine

SCHEMA_NAME = "arapbi"
S3_STAGING_DIR = "s3://arapbi/athena_results/"
AWS_REGION = "us-west-1"

df = pd.read_csv(f"s3a://arapbi/polygon/tickers_temp/dt=2024-04-01/2024-04-01.csv")


import boto3
import time

athena_client = boto3.client("athena", region_name=AWS_REGION)


query_response = athena_client.start_query_execution(
    QueryString="SELECT * FROM tickers limit 50",
    QueryExecutionContext={"Database": SCHEMA_NAME},
    ResultConfiguration={
        "OutputLocation": S3_STAGING_DIR,
        "EncryptionConfiguration": {"EncryptionOption": "SSE_S3"},
    },
)
while True:
    try:
        # This function only loads the first 1000 rows
        athena_client.get_query_results(
            QueryExecutionId=query_response["QueryExecutionId"]
        )
        break
    except Exception as err:
        if "not yet finished" in str(err):
            time.sleep(0.001)
        else:
            raise err
