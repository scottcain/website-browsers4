#!/bin/bash

###########################################
# Backup WormBase information
###########################################

BACKUP_HOST=wb-dev.oicr.on.ca
BACKUP_USER=tharris

MYSQL_HOST=206.108.125.165

# Which host are we running on?
THIS_HOST=`hostname`
DATE=`date +%Y-%m-%d`
BACKUPS_ROOT=/home/tharris/backups


##############################
# BRIE6
#    WormBook prodution site and wbg database
#
##############################
if [ ${THIS_HOST} = "wb-dev" ]
then

    #######################
    #  WORMBOOK / THE WBG
    #######################
    # Create a suitable backup directory
    echo "Backing up production:wormbase_user to ${BACKUP_HOST}";

    # Dump the wormbase_user database    
#    mkdir -p /usr/local/wormbase/backups/mysqldumps/user
#    /usr/local/mysql/bin/mysqldump \
#             -h ${MYSQL_HOST} -u wormbase wormbase_user \
#	     | gzip -c > /usr/local/wormbase/backups/mysqldumps/user/${DATE}-production-wormbase_user.sql.gz

    # Rsync the site directory for easy restoration
    # No reason to maintain daily backups; 1 copy is sufficient.
#     rsync -avv --rsh=ssh --exclude logs/ /usr/local/bookworm/ \
#	  ${BACKUP_USER}@${BACKUP_HOST}:backups/wormbook/production/.
#     rsync -avv --rsh=ssh /usr/local/bookworm/ \
#	  ${BACKUP_USER}@${BACKUP_HOST}:backups/wormbook/production/.

    # Back up the wiki, the blog, the forums
    echo "Backing up production:blog to ${BACKUP_HOST}";
    /usr/local/mysql/bin/mysqldump \
             -h wb-social.oicr.on.ca -u wormbase -p3l3g@nz wormbase_wordpress_blog \
	     | gzip -c > /usr/local/wormbase/backups/mysqldumps/blog/${DATE}-production-blog.sql.gz

    echo "Backing up production:wiki to ${BACKUP_HOST}";
    /usr/local/mysql/bin/mysqldump \
             -h wb-social.oicr.on.ca -u wormbase -p3l3g@nz wormbasewiki \
	     | gzip -c > /usr/local/wormbase/backups/mysqldumps/wiki/${DATE}-production-wiki.sql.gz

    echo "Backing up production:forums to ${BACKUP_HOST}";
    /usr/local/mysql/bin/mysqldump \
             -h wb-social.oicr.on.ca -u wormbase -p3l3g@nz wormbaseforumsmf \
	     | gzip -c > /usr/local/wormbase/backups/mysqldumps/forums/${DATE}-production-forums.sql.gz

fi
  


##############################
# BRIE3
# WormBook dev site
##############################
if [ ${THIS_HOST} = "brie3.cshl.edu" ]
then

    #######################
    #  WORMBOOK / THE WBG
    #######################
    # Create a suitable backup directory
    echo "Backing up WormBook to ${BACKUP_HOST}";

    # Dump the mysql database for the wbg
    /usr/local/mysql/bin/mysqldump --socket=/usr/local/mysql/mysql.sock \
	  -u root  wormbook_wordpress | \
          gzip -c >  /usr/local/bookworm/mysqldump/${DATE}-wormbook_wordpress-worm_breeders_gazette.sql.gz


    # Rsync the site directory for easy restoration
    # No reason to maintain daily backups; 1 copy is sufficient.
     rsync -avv --rsh=ssh --exclude logs/ /usr/local/bookworm/ \
	  ${BACKUP_USER}@${BACKUP_HOST}:backups/wormbook/dev/.

fi
