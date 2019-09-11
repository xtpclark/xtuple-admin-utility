Requires AWS CLI

https://docs.aws.amazon.com/cli/latest/userguide/install-windows.html

https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

https://docs.aws.amazon.com/cli/latest/userguide/install-macos.html


Metrics:
fetchmetrictext('XTNLocalTempDir'); -- /xtdba - Local Directory in your Server OS''s parlance...
fetchmetrictext('XTNBackupOffsiteStorageDir'); -- s3://ppc2 - AWS S3 Bucket
fetchmetrictext('XTNAcct'); -- ppc2 -- What xTuple Calls you i.e.: CRMACCT_NUMBER
fetchmetrictext('XTNSend'); -- 'True' for sending to s3
fetchmetrictext('XTNDaysToKeep'); -- Integer Not used here, how to implement.
fetchmetrictext('XTNKeepAnnual'); -- 'True' Not used here, how to implement.


Backup Current Local Database:

SELECT scheduledxtuplebackup();

Backup Remote Database:

SELECT scheduledxtuplebackup('192.168.0.42',5432,'admin','mydatabase');

TODO:
Screens: 
System -> xTuple Backup Manager

-- Lists Backups in xtadmin.buhead
-- Restore as New Name from Backup
-- Delete Backups



