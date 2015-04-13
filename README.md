# xTuple Admin Utility
management of the linux-based xTuple stack. 

Getting Started, Ubuntu 14.04 or 14.10 x86_64:

apt-get install git

git clone https://github.com/davidbeauchamp/xtuple-utility.git

cd xtuple-utility && ./xtuple-utility.sh

If you are installing from scratch, choose privisioning from the main menu. To install everything, choose installpg93, provisioncluster, initdb, demodb, and webclient. You will be prompted along the way for information such as postgresql port, cluster name, postgres user password, admin passwords and so on. Remember what you choose! Work on implementing #7 will be forthcoming. 
