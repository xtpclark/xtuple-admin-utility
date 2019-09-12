DROP FUNCTION IF EXISTS scheduledxtuplebackup(text,integer,text,text);
CREATE OR REPLACE FUNCTION scheduledxTupleBackup(pHost     TEXT    = NULL,
                                                 pPort     INTEGER = NULL,
                                                 pUser     TEXT    = NULL,
                                                 pDatabase TEXT    = NULL)
  RETURNS TEXT AS $$
DECLARE
  _result INTEGER := 0;
  _ckresult TEXT;
  _ckjsonresult JSONB;
  _host   TEXT    := COALESCE(pHost, 'localhost');
  _port   INTEGER := pPort;
  _user   TEXT    := COALESCE(pUser, 'admin');
  _db     TEXT    := COALESCE(pDatabase, current_database());
  
  -- local checks from db running/logging process.
  _tmpdir TEXT    := fetchmetrictext('XTNLocalTempDir'); -- /xtdba
  _dest   TEXT    := fetchmetrictext('XTNBackupOffsiteStorageDir'); -- s3://ppc2
  _xtnacct TEXT	  := fetchmetrictext('XTNAcct'); -- ppc2
  _xtnsend TEXT	  := fetchmetrictext('XTNSend'); -- 'True/False' for sending to s3
  _xtndayskeep TEXT	  := fetchmetrictext('XTNDaysToKeep'); -- Not used here, how to implement.
  _xtnkeepannual TEXT := fetchmetrictext('XTNKeepAnnual'); -- Not used here, how to implement.
  
  --remote checks
  _xtedition TEXT; 
  _xtversion TEXT;
  _xtpkgs JSONB;
  _xtexts JSONB;
  _xtremitto TEXT;
  _xtregkey TEXT;
  _xtlastgl TEXT;
  
  _qry TEXT;
  _dbsize TEXT;
  _fname  TEXT;
  _buname TEXT;
  _cmd    TEXT;
  _status TEXT;
  _pgversion TEXT;
  _bustart TIMESTAMP WITH TIME ZONE;
  _bustop TIMESTAMP WITH TIME ZONE;
  _xfstart TIMESTAMP WITH TIME ZONE;
  _xfstop TIMESTAMP WITH TIME ZONE;

  _buvalid BOOLEAN;
  _isxTupleDB BOOLEAN;
  _isDrupalDB BOOLEAN;
  _isxTupleDrupalDB BOOLEAN;
  _hasxTExt BOOLEAN;
  _dbtype TEXT;
   
  _os     TEXT    := getserveros();
  _osinfo JSONB   :=
    -- vvv must exactly match what the ^^^^^ function returns
    '{ "win": { "sep": "\\", "cp": "aws --only-show-errors s3 cp",                "dir": "C:\\Windows\\Temp" },
       "mac": { "sep": "/",  "cp": "aws --only-show-errors s3 cp",  "dir": "/tmp" },
       "lin": { "sep": "/",  "cp": "aws --only-show-errors s3 cp", "dir": "/tmp" }
    }'::JSONB;
   
BEGIN

   CREATE TEMPORARY TABLE IF NOT EXISTS  opsstdout (line SERIAL, data TEXT);
   CREATE TEMPORARY TABLE IF NOT EXISTS  opsstdoutjson (line SERIAL, data JSONB);
  
  IF _port IS NULL THEN
    SELECT setting FROM pg_settings WHERE name = 'port' INTO _port;
  END IF;
  
  IF _tmpdir IS NULL THEN
    _tmpdir = _osinfo #>> ARRAY[ _os, 'dir' ];
  END IF;
  
  _buname := _db || '-' || to_char(now(), 'YYYYMMDD-HHmmss') || '.backup';
  _fname := _tmpdir || (_osinfo #>> ARRAY[ _os, 'sep' ]) ||
            _db || '-' || to_char(now(), 'YYYYMMDD-HHmmss') || '.backup';

  BEGIN
 
 _bustart = CURRENT_TIMESTAMP;

   EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM '
                         PGPASSWORD=admin psql -AtX -U %s -h %s -p %s postgres -c "
                            SELECT EXISTS( 
                              SELECT * FROM pg_database 
                                WHERE datname=''%s'')::text;
                              "'$f$, 
                          _user, _host, _port, _db); 
  
    SELECT data INTO _ckresult FROM opsstdout ORDER BY line DESC LIMIT 1;
         
    IF _ckresult IS NULL THEN
    _buvalid := FALSE;
    _status = 'FAILED - SERVER DOES NOT EXIST OR LISTEN';
     
     INSERT INTO xtadmin.buhead (buhead_host, buhead_port, buhead_username, buhead_dbname, buhead_date, buhead_status, buhead_valid) VALUES (_host, _port, _user, _db, _bustart, _status, _buvalid);    
     RETURN _status;
     
    ELSIF _ckresult = 'false' THEN
    _buvalid := FALSE;
    _status = 'FAILED - DB DOES NOT EXIST OR BAD CREDENTIALS';
            
     INSERT INTO xtadmin.buhead (buhead_host, buhead_port, buhead_username, buhead_dbname, buhead_date, buhead_status, buhead_valid) VALUES (_host, _port, _user, _db, _bustart, _status, _buvalid);    
     RETURN _status;
          
    END IF;
    
    EXCEPTION WHEN OTHERS THEN -- is likely returning '<NULL>'
    _buvalid := FALSE;
    _status = 'FAILED - OTHER CONNECTION PROBLEM';
         
     INSERT INTO xtadmin.buhead (buhead_host, buhead_port, buhead_username, buhead_dbname, buhead_date, buhead_status, buhead_valid) VALUES (_host, _port, _user, _db, _bustart, _status, _buvalid);    
     RETURN _status;
        
  END;

   EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM 'PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "SELECT version();"'$f$, _user, _host, _port, _db); 
   _pgversion :=  data FROM opsstdout ORDER BY line DESC LIMIT 1;
 
 BEGIN   
 
    -- Is it xTuple DB?
   EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM '
                         PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "
                            SELECT EXISTS( 
                              SELECT * FROM information_schema.tables 
                                WHERE table_name = ''metric'')::text;
                             "'$f$,
                         _user, _host, _port, _db); 
  
    SELECT data INTO _ckresult FROM opsstdout ORDER BY line DESC LIMIT 1;
    RAISE NOTICE 'Metric Check - Result of _ckresult is %', _ckresult;
    
    IF _ckresult = 'true' THEN
    _isxTupleDB := TRUE;
    ELSE
    _isxTupleDB := FALSE;
    END IF;

    _status := 'CKOK';
    
   EXCEPTION WHEN OTHERS THEN
   _status := 'Check FAIL';
   _ckresult := data FROM opsstdout ORDER BY line DESC LIMIT 1;
    RAISE NOTICE 'xTuple DB Check Result of Metric Check is %, %', _ckresult, _status;

 END;

IF _isxTupleDB THEN    
  BEGIN   
    
   EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM '
                         PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "
                            SELECT EXISTS( 
                              SELECT * FROM information_schema.tables 
                                WHERE table_schema = ''xt'' 
                                AND table_name = ''ext'')::text;
                             "'$f$,
                         _user, _host, _port, _db); 
  
    SELECT data INTO _ckresult FROM opsstdout ORDER BY line DESC LIMIT 1;
    RAISE NOTICE 'XT.EXT Check - Result of _ckresult is %', _ckresult;
    
    IF _ckresult = 'true' THEN
     _hasxTExt := TRUE;
    ELSE
     _hasxTExt := FALSE;
    END IF;

    _status := 'CKOK';
    
   EXCEPTION WHEN OTHERS THEN
   _status := 'Check XT.EXT FAIL';
    RAISE NOTICE 'Result of _ckresult is %', _ckresult;

  END;

END IF;

 BEGIN   
   EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM '
                         PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "
                            SELECT EXISTS( 
                              SELECT * FROM information_schema.tables 
                                WHERE table_name ~ ''watchdog'')::text;
                             "'$f$,
                         _user, _host, _port, _db); 
  
    SELECT data INTO _ckresult FROM opsstdout ORDER BY line DESC LIMIT 1;
    RAISE NOTICE 'drupal watchdog Check - Result of _ckresult is %', _ckresult;

    IF _ckresult = 'true' THEN
    _isDrupalDB := TRUE;
    ELSE
    _isDrupalDB := FALSE;
    END IF;

    _status := 'CKOK';
    
   EXCEPTION WHEN OTHERS THEN
   _status := 'Check FAIL';
    RAISE NOTICE 'Result of Drupal _ckresult is %', _ckresult;

 END;

IF _isxTupleDB AND _isDrupalDB THEN
  _dbtype = 'xTupleERP And DrupalDB Combined';
ELSIF _isxTupleDB AND NOT _isDrupalDB THEN
  _dbtype = 'xTupleERP';
ELSIF NOT _isxTupleDB AND _isDrupalDB THEN
  _dbtype = 'DrupalDB';
ELSIF NOT _isxTupleDB AND NOT _isDrupalDB THEN
  _dbtype = 'Unknown Type';
END IF;
    
BEGIN

  IF _isxTupleDB THEN

  EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM 'PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "SELECT fetchmetrictext(''ServerVersion'') "'$f$, _user, _host, _port, _db); 
  _xtversion :=  data FROM opsstdout ORDER BY line DESC LIMIT 1;

  EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM 'PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "SELECT fetchmetrictext(''Application'') "'$f$, _user, _host, _port, _db); 
  _xtedition :=  data FROM opsstdout ORDER BY line DESC LIMIT 1;

  EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM 'PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "SELECT fetchmetrictext(''remitto_name''); "'$f$, _user, _host, _port, _db); 
  _xtremitto :=  data FROM opsstdout ORDER BY line DESC LIMIT 1;

  EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM 'PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "SELECT fetchmetrictext(''RegistrationKey''); "'$f$, _user, _host, _port, _db); 
  _xtregkey :=  data FROM opsstdout ORDER BY line DESC LIMIT 1;
 
  EXECUTE format($f$COPY opsstdoutjson (data) FROM PROGRAM 'PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "SELECT array_to_json(array_agg(row_to_json(t))) from ( SELECT pkghead_name,pkghead_version FROM pkghead ORDER BY 1) t;"'$f$, _user, _host, _port, _db); 
  _xtpkgs :=   data FROM opsstdoutjson ORDER BY line DESC LIMIT 1;

  EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM 'PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "SELECT gltrans_created::text FROM gltrans order by 1 desc limit 1;"'$f$, _user, _host, _port, _db); 
  _xtlastgl :=  data FROM opsstdout ORDER BY line DESC LIMIT 1;
  
  EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM 'PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "SELECT pg_database_size(CURRENT_DATABASE())::text; "'$f$, _user, _host, _port, _db); 
  _dbsize :=  data FROM opsstdout ORDER BY line DESC LIMIT 1;

    IF _hasxTExt THEN
     EXECUTE format($f$COPY opsstdoutjson (data) FROM PROGRAM 'PGPASSWORD=admin psql -AtX -U %s -h %s -p %s %s -c "SELECT array_to_json(array_agg(row_to_json(t))) from ( SELECT ext_name FROM xt.ext ORDER BY 1) t;"'$f$, _user, _host, _port, _db); 
     _xtexts :=   data FROM opsstdoutjson ORDER BY line DESC LIMIT 1;
    END IF;

  END IF;
END;

BEGIN

  BEGIN
   _bustart := clock_timestamp()::timestamp with time zone;
   
   RAISE NOTICE 'Starting pg_dump of %:%:%', _host, _port, _db;
   _cmd := format('PGPASSWORD=admin pg_dump -h %s -p %s -U %s -Fc -f %s %s 2>&1',
                  _host, _port, _user, _fname, _db);
   _cmd := replace(_cmd, ';', '');
   EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM '%s'$f$, _cmd);
    _status := 'CPOK';
    
   EXCEPTION WHEN OTHERS THEN
   _status := 'FAIL';
  END;

  _bustop := clock_timestamp()::timestamp with time zone;

-- Send it to remote
  IF _xtnsend = 'True' AND _xtnacct IS NOT NULL THEN
    IF _status = 'CPOK' AND _dest IS NOT NULL THEN
     _xfstart := clock_timestamp()::timestamp with time zone;
    BEGIN
      RAISE NOTICE 'Starting copy of % to %/%', _db, _dest, _buname;
       _cmd := format('%s %s %s/%s', (_osinfo #>> ARRAY[_os, 'cp']), _fname, _dest, _buname);
       EXECUTE format($f$COPY opsstdout (data) FROM PROGRAM '%s'$f$, _cmd);
      _status :='OK';
      _buvalid := TRUE;
       EXCEPTION WHEN OTHERS THEN
      _status := 'FAIL';
    END;
    _xfstop := clock_timestamp()::timestamp with time zone; 
    END IF;
  END IF;


INSERT INTO xtadmin.buhead (buhead_host, buhead_port, buhead_username, buhead_dbname, buhead_filename, buhead_appver, buhead_edition, buhead_pkgs, buhead_dbsize, buhead_storurl, 
buhead_regkey, buhead_remitto, buhead_date, buhead_bustart,buhead_bustop,buhead_xfstart,buhead_xfstop, buhead_dbtype, buhead_valid, buhead_hasext, buhead_lastgl, buhead_exts, buhead_pgversion) 
VALUES (_host, _port, _user, _db,_fname, _xtversion, _xtedition, _xtpkgs, _dbsize::integer, _dest||'/'||_buname, _xtregkey, _xtremitto, now(),_bustart,_bustop,_xfstart,_xfstop, _dbtype, _buvalid, _hasxTExt, _xtlastgl, _xtexts, _pgversion);


  RETURN _status;
  
END;
END;
$$ LANGUAGE plpgsql;
