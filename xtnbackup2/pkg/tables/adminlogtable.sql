CREATE SCHEMA xtadmin;
GRANT ALL ON SCHEMA xtadmin TO PUBLIC;

SELECT xt.create_table('buhead', 'xtadmin');

ALTER TABLE xtadmin.buhead DISABLE TRIGGER ALL;

SELECT
 xt.add_column('buhead','buhead_id', 			'serial', 	'not null', 'xtadmin'),
 xt.add_column('buhead','buhead_database', 		'text', 	'default current_database()', 'xtadmin'),
 xt.add_column('buhead','buhead_username', 		'text', 	'',                         'xtadmin'),
 xt.add_column('buhead','buhead_date', 			'timestamp with time zone', '', 'xtadmin'),
 xt.add_column('buhead','buhead_status', 		'text', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_valid', 		'boolean', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_dbtype', 		'text', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_hasext', 		'boolean', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_filename', 	    'text', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_dbsize', 	    'integer', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_bustart', 	    'timestamp with time zone', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_bustop', 	    'timestamp with time zone', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_xfstart', 	    'timestamp with time zone', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_xfstop', 	    'timestamp with time zone', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_lastgl', 	    'text', 	'', 			'xtadmin'),
 xt.add_column('buhead','buhead_host', 	        'text', 	'', 			'xtadmin'),          
 xt.add_column('buhead','buhead_port', 	        'text', 	'', 			'xtadmin'),          
 xt.add_column('buhead','buhead_dbname', 	    'text', 	'', 			'xtadmin'),        
 xt.add_column('buhead','buhead_filename', 	    'text', 	'', 			'xtadmin'),      
 xt.add_column('buhead','buhead_appver',        'text', 	'', 			'xtadmin'),      
 xt.add_column('buhead','buhead_pkgs',          'jsonb', 	'', 			'xtadmin'),      
 xt.add_column('buhead','buhead_exts',          'jsonb', 	'', 			'xtadmin'),      
 xt.add_column('buhead','buhead_edition',       'text', 	'', 			'xtadmin'),      
 xt.add_column('buhead','buhead_storurl',       'text', 	'', 			'xtadmin'),      
 xt.add_column('buhead','buhead_regkey',        'text', 	'', 			'xtadmin'),      
 xt.add_column('buhead','buhead_remitto',       'text', 	'', 			'xtadmin'),      
 xt.add_column('buhead','buhead_pgversion',     'text', 	'', 			'xtadmin'),      
 xt.add_column('buhead','buhead_backend_pid',   'integer', 'default pg_backend_pid()',	'xtadmin'),
 (TRUE);

comment on table xtadmin.buhead is 'xTuple Audit Logging';
grant all on table xtadmin.buhead to admin;
grant all on table xtadmin.buhead to xtrole;
grant all on xtadmin.buhead_buhead_id_seq to xtrole;
grant all on xtadmin.buhead_buhead_id_seq to admin;

alter table xtadmin.buhead owner to admin;
alter table xtadmin.buhead_buhead_id_seq owner to admin;
alter table xtadmin.buhead enable trigger all;
