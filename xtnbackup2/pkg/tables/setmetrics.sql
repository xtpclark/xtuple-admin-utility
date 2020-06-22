SELECT setmetric('XTNLocalTempDir','/xtdba','XTN');
SELECT setmetric('XTNBackupOffsiteStorageDir','s3://my_s3_bucket','XTN');
SELECT setmetric('XTNAcct','XTUPLE_CUSTOMER_NUMBER','XTN');
SELECT setmetric('XTNSend','f','XTN');
SELECT setmetric('XTNDaysToKeep','3','XTN');
SELECT setmetric('XTNKeepAnnual','f','XTN');

