# xTuple Admin Utility
management of the linux-based xTuple stack. 

Getting Started, Ubuntu 14.04 LTS, 14.10, and 15.04. Debian 7.x and 8.1, all 64bit only

sudo apt-get install git

git clone https://github.com/xtuple/xtuple-admin-utility.git

cd xtuple-admin-utility && ./xtuple-utility.sh

If you are installing from scratch, choose privisioning from the main menu. To install everything, choose installpg93, provisioncluster, initdb, demodb, and webclient. You will be prompted along the way for information such as postgresql port, cluster name, postgres user password, admin passwords and so on. Remember what you choose! Work on implementing #7 will be forthcoming. 

For an unattended install on a clean machine, try: ./xtuple-utility.sh -a

Help Output:
```
To get an interactive menu run xtuple-utility.sh with no arguments

  -h    Show this message
  -a    Install all (PostgreSQL (currently 9.3), demo database (currently 4.9.1) and web client (currently 4.9.1))
  -d    Specify database name to create
  -p    Override PostgreSQL version
  -n    Override instance name
  -x    Override xTuple version (applies to web client and database)
  -t    Specify the type of database to grab (demo/quickstart/empty)
```
