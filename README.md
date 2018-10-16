# xTuple Admin Utility
The xTuple Admin Utility (xTAU) is a toolkit for administering xTuple on an Ubuntu Linux server. It includes options for performing a quick installation of xTuple, and for maintaining the PostgreSQL server and xTuple databases. 

xTAU runs on Linux, Ubuntu 14.04 LTS, 14.10, 15.04, and 16.04. Debian 7.x and 8.1, all 64bit only.

Quick Setup:

sudo apt-get install git

git clone https://github.com/xtuple/xtuple-admin-utility.git

cd xtuple-admin-utility && ./xtuple-utility.sh

If you are installing from scratch, choose Quick Install from the main menu. You will be prompted to choose web-enabled or non-web-enabled and then prompted to enter information such as postgresql port, cluster name, postgres user password, admin passwords and so on. Remember what you choose!

For an unattended install on a clean machine, try: ./xtuple-utility.sh -a

Help Output:
```
To get an interactive menu run xtuple-utility.sh with no arguments

  -h    Show this message
  -a    Install all (PostgreSQL (currently 9.6), demo database (currently 4.11.3) and web client (currently 4.11.3))
  -d    Specify database name to create
  -p    Override PostgreSQL version
  -n    Override instance name
  -x    Override xTuple version (applies to web client and database)
  -t    Specify the type of database to grab (demo/quickstart/empty)
```

Full instructions for getting, installing, and using the xTuple Admin Utility are available in the xTuple Admin Guide, on xTuple University. 

[Chapter 3. Web-Enabled Server Administration on Linux Using xTAU](https://xtupleuniversity.xtuple.com/sites/default/files/prodguide/admin-guide/xtau-admin.html).
