import boto3
import pandas as pd
import psycopg2

from botocore.exceptions import ClientError
from sqlalchemy import create_engine


S3_BUCKET = "arapbi"
S3_FOLDER = "polygon/tickers/"

s3 = boto3.resource("s3")
my_bucket = s3.Bucket(S3_BUCKET)


# Use this code snippet in your app.
# If you need more information about configurations
# or implementing the sample code, visit the AWS docs:
# https://aws.amazon.com/developer/language/python/


def get_secret(secret_name="prod/arapbi/database", region_name="us-west-2"):

    secret_name = secret_name
    region_name = region_name

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(service_name="secretsmanager", region_name=region_name)

    try:
        get_secret_value_response = client.get_secret_value(SecretId=secret_name)
    except ClientError as e:
        # For a list of exceptions thrown, see
        # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        raise e

    secret = get_secret_value_response["SecretString"]
    return secret


object_list = []
for obj in my_bucket.objects.filter(Prefix=S3_FOLDER):
    object_list.append(obj)

secret = json.loads(secret)
user = secret.get("username")
password = secret.get("password")

conn_string = f"postgresql://{user}:{password}@arapbi20240406153310133100000001.c368i8aq0xtu.us-west-2.rds.amazonaws.com:5432/arapbi"
db = create_engine(conn_string)
conn = db.connect()


for i, file in enumerate(object_list):
    obj = object_list[i + 1].key
    bucket_name = object_list[i + 1].bucket_name
    df = pd.read_csv(f"s3a://{bucket_name}/{obj}").drop("Unnamed: 0", axis=1)
    df.to_sql("tickers", con=conn, if_exists="append", index=False)
    conn.commit()
    n_records = str(df.count())
    print(f"loaded {n_records} records from s3a://{bucket_name}/{obj}")


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
