DROP TABLE IF EXISTS tickers;

CREATE EXTERNAL TABLE tickers
    (rownum STRING,
    ticker STRING,
    timestamp STRING,
    open STRING,
    close STRING,
    volume_weighted_average_price STRING,
    volume STRING,
    transactions STRING,
    date STRING
)
PARTITIONED BY (dt STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ("separatorChar" = ",", "escapeChar" = "\\","skip.header.line.count"="1",  "serialization.null.format"="")
LOCATION 's3://arapbi/polygon/tickers';

MSCK REPAIR TABLE tickers;