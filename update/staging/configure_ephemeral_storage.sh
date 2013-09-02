# A user data script to configure ephemeral storage
# relocating mysql and various other components.

# Relocate mysql to ephemeral0
/etc/init.d/mysql stop

cd /mnt/ephemeral0
mkdir -p var/log
cp -r /var/log/mysql var/log/.

mkdir -p var/lib
cp -r /var/lib/mysql var/lib/.

mkdir -p /etc
cp -r /etc/mysql /etc/.

chown -R mysql:mysql var
chown -R mysql:mysql etc

mount /var/lib/mysql
mount /var/log/mysql
mount /etc/mysql

/etc/init.d/mysql start

# Relocate acedb, ftp, and databases to ephemeral1
# FTP
cd /mnt/ephemeral1
mkdir -p usr/local/ftp/pub/wormbase/releases
mkdir -p usr/local/ftp/pub/wormbase/species
chown -R tharris:wormbase usr/
sudo mount /usr/local/ftp

# acedb
mkdir usr/local/wormbase/acedb
cp -r /usr/local/wormbase/acedb/bin usr/local/wormbase/acedb/.
chown -R tharris:wormbase usr/
sudo mount /usr/local/wormbase/acedb

# databases
mkdir usr/local/wormbase/databases
chown -R tharris:wormbase usr/
sudo mount /usr/local/wormbase/databases

