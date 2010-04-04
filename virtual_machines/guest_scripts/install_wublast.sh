cd ~
scp todd@brie3.cshl.org:wublast.tgz .
tar xzf wublast.tgz 
cd usr/local
sudo mv wublast.WB.all /usr/local/.
cd /usr/local/
sudo chgrp -R wormbase wublast.WB.all/
sudo rm -rf wublast
sudo rm -rf wublast.WB.all/wublast.WB.2005-03-26/blast2.linux24-i686.tar.gz 
sudo ln -s wublast.WB.all/wublast.WB.2005-03-26 wublast
cd ~
rm -rf usr/ wublast.tgz 
scp todd@brie3.cshl.org:/usr/local/wormbase/util/admin/blat_server.initd .
sudo mv blat_server.initd /etc/rc.d/init.d/blat_server

# Create suitable start up symlinks
cd /etc/rc3.d/
sudo ln -s ../init.d/blat_server S99blat_server
cd /etc/rc5.d/
sudo ln -s ../init.d/blat_server S99blat_server


# Install blat
cd ~
scp todd@brie3.cshl.org:blat.tgz .
tar xzf blat.tgz
sudo mv usr/local/blat /usr/local/blat
cd /usr/local
sudo chown root:acedb blat
sudo chmod 2775 blat
sudo chown -R tharris:acedb blat/*
cd ~
rm -rf usr blat.tgz

