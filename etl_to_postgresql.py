import json

import boto3
import pandas as pd
import psycopg2

from io import StringIO

from botocore.exceptions import ClientError

# Currently this boils the ocean on the table refresh
# TODO: make it incremental and intelligent

S3_BUCKET = "arapbi"
S3_FOLDER = "polygon/tickers/"
DATABASE_URI = (
    "arapbi20240409222908967700000003.c368i8aq0xtu.us-west-2.rds.amazonaws.com:5432"
)

s3 = boto3.resource("s3")
my_bucket = s3.Bucket(S3_BUCKET)


def get_secret(secret_name="prod/arapbi/database", region_name="us-west-2"):

    secret_name = secret_name
    region_name = region_name

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager", region_name=region_name)

    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
    except ClientError as e:
        raise e

    secret = get_secret_value_response["SecretString"]
    return secret


# Fetch all objects
object_list = []
for obj in my_bucket.objects.filter(Prefix=S3_FOLDER):
    object_list.append(obj)

# Fetch secret
secret = get_secret()
secret = json.loads(secret)
user = secret.get("username")
password = secret.get("password")

# Connect to Postgresql
conn_string = f"postgresql://{user}:{password}@{DATABASE_URI}/arapbi"
pg_conn = psycopg2.connect(conn_string, database="arapbi")

# Upload all the CSVs to PG
for i, file in enumerate(object_list[1:-1]):
    cur = pg_conn.cursor()
    output = StringIO()

    obj = object_list[i + 1].key
    bucket_name = object_list[i + 1].bucket_name

    df = pd.read_csv(f"s3a://{bucket_name}/{obj}").drop("Unnamed: 0", axis=1)
    output.write(df.to_csv(index=False, header=False, na_rep="NaN"))
    output.seek(0)

    cur.copy_expert(f"COPY tickers FROM STDIN WITH CSV HEADER", output)
    pg_conn.commit()
    cur.close()
    n_records = str(len(df))
    print(f"loaded {n_records} records from s3a://{bucket_name}/{obj}")
pg_conn.close()

'''

def write_sql(file):
    sql = f"""
        COPY tickers
        FROM '{file}'
        DELIMITER ',' CSV;
        """
    return sql


table_create_sql = """
CREATE TABLE IF NOT EXISTS public.tickers (  ticker      varchar(20),
                                      timestamp         bigint,
                                      open              double precision,
                                      close             double precision,
                                      volume_weighted_average_price double precision,
                                      volume            double precision,
                                      transactions      double precision,
                                      date              date
)"""

# Create the table
pg_conn = psycopg2.connect(conn_string, database="arapbi")
cur = pg_conn.cursor()
cur.execute(table_create_sql)
pg_conn.commit()
cur.close()
pg_conn.close()

# attempt to upload one file to the table
s = write_sql(object_list[-1].key)
pg_conn = psycopg2.connect(conn_string, database="arapbi")
cur = pg_conn.cursor()
cur.execute(s)
pg_conn.commit()
cur.close()
pg_conn.close()
'''


pg_conn = psycopg2.connect(conn_string, database="arapbi")
cursor = pg_conn.cursor()

sql = """select date, count(*) from tickers group by 1 order by 1 desc limit 10 """

cursor.execute(sql)
cursor.fetchall()

pg_conn.commit()
pg_conn.close()
