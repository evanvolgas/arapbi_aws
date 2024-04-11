import datetime as dt
import json
import os

# import boto3
import pandas as pd

from opensearchpy import OpenSearch, RequestsHttpConnection

# Currently this boils the ocean on the index refresh
# TODO: make it incremental and intelligent


def rec_to_actions(df):
    for record in df.to_dict(orient="records"):
        yield (f'{{ "index" : {{ "_index" : "{INDEX_NAME}" }}}}')
        yield (json.dumps(record, default=int))


if __name__ == "__main__":

    ES_ENDPOINT = "search-arapbi-hbe6ymmxkg2dr223fsvcqs43ly.us-west-2.es.amazonaws.com"
    ES_USER = "arapbi"
    ES_PW = os.getenv("ES_PW")
    INDEX_NAME = "arapbi-tickers"
    S3_BUCKET = "arapbi"
    S3_FOLDER = "polygon/tickers"

    auth = (ES_USER, ES_PW)

    # s3 = boto3.resource("s3")
    # s3_bucket = s3.Bucket(S3_BUCKET)

    # List of all objects
    #    object_list = []
    #    for obj in s3_bucket.objects.filter(Prefix=S3_FOLDER):
    #        object_list.append(obj)

    # Create the client with SSL/TLS enabled, but hostname verification disabled.
    client = OpenSearch(
        hosts=[{"host": ES_ENDPOINT, "port": 443}],
        http_compress=True,  # enables gzip compression for request bodies
        http_auth=auth,
        use_ssl=True,
        verify_certs=True,
        connection_class=RequestsHttpConnection,
        pool_maxsize=20,
    )

    query = '{"aggs": {"max_date": { "max": { "field": "date" } }},  "size": 0}'
    response = client.search(query, index="arapbi-tickers")
    max_date = response["aggregations"]["max_date"]["value_as_string"][:10]

    today = dt.date.today().strftime("%Y-%m-%d")
    dates = [str(d)[:10] for d in pd.date_range(max_date, today)][1:]
    obj_list = [f"s3://arapbi/polygon/tickers/{d}/{d}.csv" for d in dates]

    index_body = {"settings": {"index": {"number_of_shards": 2}}}
    # response = client.indices.delete(INDEX_NAME)
    response = client.indices.create(INDEX_NAME, body=index_body)

    for obj in obj_list:
        if obj:
            file = obj
            df = pd.read_csv(file)
            client.bulk(rec_to_actions(df), request_timeout=600)
