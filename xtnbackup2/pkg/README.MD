# Requires AWS CLI

https://docs.aws.amazon.com/cli/latest/userguide/install-windows.html

https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

https://docs.aws.amazon.com/cli/latest/userguide/install-macos.html


# Metrics:
<pre>
fetchmetrictext('XTNLocalTempDir'); -- /xtdba - Local Directory in your Server OS's conventions.
fetchmetrictext('XTNBackupOffsiteStorageDir'); -- s3://ppc2 - AWS S3 Bucket
fetchmetrictext('XTNAcct'); -- ppc2 -- What xTuple Calls you i.e.: CRMACCT_NUMBER
fetchmetrictext('XTNSend'); -- 'True' for sending to s3
fetchmetrictext('XTNDaysToKeep'); -- Integer Not used here, how to implement.
fetchmetrictext('XTNKeepAnnual'); -- 'True' Not used here, how to implement.
</pre>

# Backup Current Database:

<code>SELECT scheduledxtuplebackup();</code>

# Backup Local Database:

<code>SELECT scheduledxtuplebackup('localhost',5432,'admin','localDBName');</code>

# Backup Remote Database:

<code>SELECT scheduledxtuplebackup('192.168.0.42',5432,'admin','mydatabase');</code>

# Logging:
See xtadmin.buhead table for logged backups.

## TODO:

Screens:

System -> xTuple Backup Manager

* Lists Backups in xtadmin.buhead
* Restore as New Name from Backup
* Delete Backups
* Set Metrics
* Send notficiations
