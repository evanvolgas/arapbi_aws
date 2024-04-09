import boto3
import pandas as pd

from concurrent.futures import ThreadPoolExecutor
from google.cloud import storage
from threading import Lock


WORKERS = 50
BUCKET_NAME = "arapbi-polygon"
GCP_FOLDER_NAME = "polygon/tickers/"
S3_BUCKET = "arapbi"
S3_FOLDER = "polygon/tickers_temp/"

storage_client = storage.Client()
s3 = boto3.resource("s3")
my_bucket = s3.Bucket(S3_BUCKET)


def scrape_gcp_for_csvs(file: str) -> None:
    print(f"Downloading {file.name}")
    file_path = f"gs://{file.bucket.name}/{file.name}"
    file = file.name.split("/")[-1].split(".")[0]
    df = pd.read_csv(file_path)
    print(f"writing to s3://arapbi/polygon/tickers/{file}.parquet")
    df.to_parquet(f"s3://arapbi/polygon/tickers/{file}.parquet")
    return df


files = list(
    storage_client.list_blobs(bucket_or_name=BUCKET_NAME, prefix=GCP_FOLDER_NAME)
)

# scrape_gcp_for_csvs(files[0])
with ThreadPoolExecutor(max_workers=WORKERS) as executor:
    executor.map(scrape_gcp_for_csvs, files[0:1])


object_list = []
for obj in my_bucket.objects.filter(Prefix=S3_FOLDER):
    object_list.append(obj)
object_list[0]

print(len(object_list))
print(len(files))
