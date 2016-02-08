#!/bin/bash

sudo apt-get -y install fail2ban
sudo apt-get -y install ntp ntpdate
sudo apt-get -y install munin-node libdbd-pg-perl

sudo munin-node-configure --suggest

sudo ln -s /usr/share/munin/plugins/postgres_autovacuum /etc/munin/plugins/postgres_autovacuum
sudo ln -s /usr/share/munin/plugins/postgres_bgwriter /etc/munin/plugins/postgres_bgwriter
sudo ln -s /usr/share/munin/plugins/postgres_cache_	/etc/munin/plugins/postgres_cache_ALL
sudo ln -s /usr/share/munin/plugins/postgres_checkpoints /etc/munin/plugins/postgres_checkpoints
sudo ln -s /usr/share/munin/plugins/postgres_connections_ /etc/munin/plugins/postgres_connections_ALL
sudo ln -s /usr/share/munin/plugins/postgres_connections_db /etc/munin/plugins/postgres_connections_db
sudo ln -s /usr/share/munin/plugins/postgres_locks_ /etc/munin/plugins/postgres_locks_ALL                    
sudo ln -s /usr/share/munin/plugins/postgres_querylength_ /etc/munin/plugins/postgres_querylength_ALL              
sudo ln -s /usr/share/munin/plugins/postgres_size_ /etc/munin/plugins/postgres_size_ALL
sudo ln -s /usr/share/munin/plugins/postgres_transactions_ /etc/munin/plugins/postgres_transactions_ALL
sudo ln -s /usr/share/munin/plugins/postgres_users /etc/munin/plugins/postgres_users        
sudo ln -s /usr/share/munin/plugins/postgres_xlog /etc/munin/plugins/postgres_xlog         

