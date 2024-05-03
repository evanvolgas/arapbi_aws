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



create view stg_tickers as (
select
    ticker,
    try_cast(open as double) as open,
    try_cast(close as double) as close,
    try_cast(volume_weighted_average_price as double) as volume_weighted_average_price,
    try_cast(volume as bigint) as volume,
    try_cast(transactions as bigint) as transactions,
    try_cast(dt as date) as date
FROM tickers
);