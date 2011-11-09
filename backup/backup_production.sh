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


BLOG_HOST=wb-social.oicr.on.ca
BLOG_USER=tharris
FORUM_HOST=wb-social.oicr.on.ca
FORUM_USER=tharris
WIKI_HOST=wb-social.oicr.on.ca
WIKI_USER=tharris


##############################
# BRIE6
#    WormBook prodution site and wbg database
#
##############################
if [ ${THIS_HOST} = "wb-dev" ]
then

    #######################
    #  WormBase User
    #######################
    # Create a suitable backup directory
    echo "Backing up production:wormbase_user to ${BACKUP_HOST}";

    # Dump the wormbase_user database    
#    mkdir -p /usr/local/wormbase/backups/mysqldumps/user
#    /usr/local/mysql/bin/mysqldump \
#             -h ${MYSQL_HOST} -u wormbase wormbase_user \
#	     | gzip -c > /usr/local/wormbase/backups/userdb/${DATE}-production-wormbase_user.sql.gz

    # Rsync the site directory for easy restoration
    # No reason to maintain daily backups; 1 copy is sufficient.
#     rsync -avv --rsh=ssh --exclude logs/ /usr/local/bookworm/ \
#	  ${BACKUP_USER}@${BACKUP_HOST}:backups/wormbook/production/.
#     rsync -avv --rsh=ssh /usr/local/bookworm/ \
#	  ${BACKUP_USER}@${BACKUP_HOST}:backups/wormbook/production/.

    # Back up the wiki, the blog, the forums

    #######################
    #  Blog
    #######################
    echo "Backing up production:blog to ${BACKUP_HOST}";
    # One copy
#    /usr/local/mysql/bin/mysqldump \
#             -h wb-social.oicr.on.ca -u wormbase -p3l3g@nz wormbase_wordpress_blog \
#	     | gzip -c > /usr/local/wormbase/backups/blog/mysqldumps/${DATE}-mysqldump-wormbase_wordpress_blog.sql.gz
#
#    rsync -avv --rsh=ssh --exclude logs/ ${BLOG_USER}@${BLOG_HOST}:/usr/local/wormbase/website-blog/ \
#	  /usr/local/wormbase/backups/blog/.

    # Or daily copies
    mkdir -p /usr/local/wormbase/backups/blog/${DATE}
    /usr/local/mysql/bin/mysqldump \
             -h wb-social.oicr.on.ca -u wormbase -p3l3g@nz wormbase_wordpress_blog \
	     | gzip -c > /usr/local/wormbase/backups/blog/${DATE}/${DATE}-mysqldump-wormbase_wordpress_blog.sql.gz
    rsync -avv --rsh=ssh --exclude logs/ ${BLOG_USER}@${BLOG_HOST}:/usr/local/wormbase/website-blog/ \
	  /usr/local/wormbase/backups/blog/${DATE}/.
    cd /usr/local/wormbase/backups/blog
    tar -czf ${DATE}.tgz ${DATE}
    rm -rf ${DATE}

    #######################
    #  Wiki
    #######################
    echo "Backing up production:wiki to ${BACKUP_HOST}";
    # One copy
#    /usr/local/mysql/bin/mysqldump \
#             -h wb-social.oicr.on.ca -u wormbase -p3l3g@nz wormbasewiki \
#	     | gzip -c > /usr/local/wormbase/backups/wiki/mysqldumps/${DATE}-mysqldump-wormbasewiki.sql.gz
#
#    rsync -avv --rsh=ssh --exclude logs/ ${BLOG_USER}@${BLOG_HOST}:/usr/local/wormbase/website-wiki/ \
#	  /usr/local/wormbase/backups/wiki/.

    # Or daily copies
    mkdir -p /usr/local/wormbase/backups/wiki/${DATE}
    /usr/local/mysql/bin/mysqldump \
             -h wb-social.oicr.on.ca -u wormbase -p3l3g@nz wormbasewiki \
	     | gzip -c > /usr/local/wormbase/backups/wiki/${DATE}/${DATE}-mysqldump-wormbasewiki.sql.gz
    rsync -avv --rsh=ssh --exclude logs/ ${BLOG_USER}@${BLOG_HOST}:/usr/local/wormbase/website-wiki/ \
	  /usr/local/wormbase/backups/wiki/${DATE}/.
    cd /usr/local/wormbase/backups/wiki
    tar -czf ${DATE}.tgz ${DATE}
    rm -rf ${DATE}

    #######################
    #  Forums
    #######################
    echo "Backing up production:forums to ${BACKUP_HOST}";
    # One copy
#    /usr/local/mysql/bin/mysqldump \
#             -h wb-social.oicr.on.ca -u wormbase -p3l3g@nz wormbaseforumsmf \
#	     | gzip -c > /usr/local/wormbase/backups/wiki/mysqldumps/${DATE}-mysqldump-wormbaseforumsmf.sql.gz
#
#    rsync -avv --rsh=ssh --exclude logs/ ${BLOG_USER}@${BLOG_HOST}:/usr/local/wormbase/website-forums/ \
#	  /usr/local/wormbase/backups/forums/.

    # Or daily copies
    mkdir -p /usr/local/wormbase/backups/forums/${DATE}
    /usr/local/mysql/bin/mysqldump \
             -h wb-social.oicr.on.ca -u wormbase -p3l3g@nz wormbaseforumsmf \
	     | gzip -c > /usr/local/wormbase/backups/forums/${DATE}/${DATE}-mysqldump-wormbaseforumsmf.sql.gz
    rsync -avv --rsh=ssh --exclude logs/ ${BLOG_USER}@${BLOG_HOST}:/usr/local/wormbase/website-forums/ \
	  /usr/local/wormbase/backups/forums/${DATE}/.
    cd /usr/local/wormbase/backups/forums
    tar -czf ${DATE}.tgz ${DATE}
    rm -rf ${DATE}

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
