import boto3
import datetime as dt
import os

import awswrangler as wr
import pandas as pd

from concurrent.futures import ThreadPoolExecutor

from polygon import RESTClient

WORKERS = 50
S3_BUCKET = "arapbi"
S3_FOLDER = "polygon/tickers"

polygon_secret = os.getenv("POLYGON_API_KEY")
polygon_client = RESTClient(polygon_secret, retries=10, trace=False)
s3 = boto3.resource("s3")
s3_bucket = s3.Bucket(S3_BUCKET)

df = wr.athena.read_sql_query(
    sql="SELECT max(cast(date as date)) as max_dt FROM tickers", database="arapbi"
)
today = dt.date.today().strftime("%Y-%m-%d")
max_stored_date = df["max_dt"][0]
dates = [str(d)[:10] for d in pd.date_range(max_stored_date, today)]


# Scrape Polygon's website for stocks history for every ticker, make a dataframe out of the result,
# and append that dataframe to a list of all dataframes for all stocks. It will be concatenated to one dataframe below.
def fetch_stock_history(d):
    print(f"Fetching data for {d}")
    aggs = []
    for a in polygon_client.get_grouped_daily_aggs(d):
        aggs.append(a)

    if aggs:
        daily = [
            {
                "ticker": y.ticker,
                "timestamp": int(y.timestamp),
                "open": y.open,
                "close": y.close,
                "volume_weighted_average_price": y.vwap,
                "volume": y.volume,
                "transactions": y.transactions,
                "date": d,
            }
            for y in aggs
        ]
        df = pd.DataFrame(daily)
        print(f"uploading to s3a://{S3_BUCKET}/{S3_FOLDER}/dt={d}/{d}.csv")
        df.to_csv(f"s3a://{S3_BUCKET}/{S3_FOLDER}/dt={d}/{d}.csv")
        return df
    else:
        print(f"No ticker data for {d}")


print(f"Scraping web data")
# Using ThreadPoolExecutor to fetch stock histories concurrently
with ThreadPoolExecutor(max_workers=WORKERS) as executor:
    executor.map(fetch_stock_history, dates)


# Adding the partition to Athena
athena_config = {
    "OutputLocation": f"s3://{S3_BUCKET}/athena_results/Unsaved/{today[:4]}/{today[5:7]}/{today[8:10]}/",
    "EncryptionConfiguration": {"EncryptionOption": "SSE_S3"},
}

# Query Execution Parameters
sql = "MSCK REPAIR TABLE tickers"
# sql = "SELECT dt, count(*) from tickers group by 1"
context = {"Database": "arapbi"}

athena_client = boto3.client("athena")
athena_client.start_query_execution(
    QueryString=sql, QueryExecutionContext=context, ResultConfiguration=athena_config
)


df = wr.athena.read_sql_query(
    sql="SELECT max(cast(date as date)) as max_dt FROM tickers", database="arapbi"
)


# response = athena_client.get_query_results(
#    QueryExecutionId='99f84e2f-7c7c-4695-94d9-1858c39ccb39',
#    NextToken='string',
#    MaxResults=1000
# )
