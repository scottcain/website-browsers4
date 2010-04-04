#!/bin/sh

# Back up the Movable type database so that 
# I can easily work with it on my laptop

if [ -d "/home/todd/mysqlhotcopy" ]
   then DIR=/home/todd/mysqlhotcopy
else 
   DIR=/Users/todd/mysqlhotcopy
fi
cd $DIR
rm -rf $DIR/wormbasemt
sudo mysqlhotcopy --u=root --p=kentwashere wormbasemt ${DIR}
tar czf wormbasemt.mysql.tgz wormbasemt
sudo -u todd scp wormbasemt.mysql.tgz brie3.cshl.org:.
rm -rf wormbasemt.mysql.tgz
