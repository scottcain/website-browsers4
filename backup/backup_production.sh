#!/bin/bash

###########################################
# Backup WormBase information
###########################################

BACKUP_HOST=wb-dev.oicr.on.ca

# Grab images from Caltech via rsync over ssh
KEY=/home/tharris/cron/rsync-user-key 

WORMBASE_USER_DB_HOST=23.21.171.141


DATE=`date +%Y-%m-%d`

SOCIAL_USER=tharris
SOCIAL_HOST=23.21.171.141

#######################
#  WormBase User DB
#######################
# Create a suitable backup directory
echo "Backing up production:wormbase_user to ${BACKUP_HOST}";

# Dump the wormbase_user database    
#/usr/local/mysql/bin/mysqldump \
#         -h ${WORMBASE_USER_DB_HOST} -u wormbase wormbase_user \
#	 | gzip -c > /usr/local/wormbase/backups/userdb/${DATE}-production-wormbase_user.sql.gz

#######################
#  Blog
#######################
echo "Backing up production:blog to ${BACKUP_HOST}";
# One copy
mkdir -p /usr/local/wormbase/backups/blog/mysqldumps
/usr/local/mysql/bin/mysqldump \
             -h ${SOCIAL_HOST} -u wormbase wormbase_wordpress_blog \
	     | gzip -c > /usr/local/wormbase/backups/blog/mysqldumps/${DATE}-mysqldump-wormbase_wordpress_blog.sql.gz

rsync -avv -e "/usr/bin/ssh -i $KEY" --rsh=ssh --exclude logs/ ${SOCIAL_USER}@${SOCIAL_HOST}:/usr/local/wormbase/website/social/blog/ \
	  /usr/local/wormbase/backups/blog/.

# Or daily copies, each with its own mysqldump
#mkdir -p /usr/local/wormbase/backups/blog/${DATE}
#/usr/local/mysql/bin/mysqldump \
#             -h ${WORMBASE_USER_DB_HOST} -u wormbase wormbase_wordpress_blog \
#	     | gzip -c > /usr/local/wormbase/backups/blog/${DATE}/${DATE}-mysqldump-wormbase_wordpress_blog.sql.gz
#    rsync -avv -e "/usr/bin/ssh -i $KEY" --exclude logs/ ${SOCIAL_USER}@${SOCIAL_HOST}:/usr/local/wormbase/website/social/blog/ \
#	                    /usr/local/wormbase/backups/blog/${DATE}/.
#    cd /usr/local/wormbase/backups/blog
#    tar -czf ${DATE}.tgz ${DATE}
#    rm -rf ${DATE}

#######################
#  Wiki
#######################
echo "Backing up production:wiki to ${BACKUP_HOST}";

# One copy
mkdir -p /usr/local/wormbase/backups/wiki/mysqldumps
/usr/local/mysql/bin/mysqldump \
             -h ${SOCIAL_HOST} -u wormbase wormbasewiki \
	     | gzip -c > /usr/local/wormbase/backups/wiki/mysqldumps/${DATE}-mysqldump-wormbasewiki.sql.gz

rsync -avv -e "/usr/bin/ssh -i $KEY" --exclude logs/ ${SOCIAL_USER}@${SOCIAL_HOST}:/usr/local/wormbase/website/social/wiki/ \
	  /usr/local/wormbase/backups/wiki/.

# Or daily copies
#mkdir -p /usr/local/wormbase/backups/wiki/${DATE}
#/usr/local/mysql/bin/mysqldump \
#             -h ${WORMBASE_USER_DB_HOST} -u wormbase wormbase_wiki \
#	     | gzip -c > /usr/local/wormbase/backups/wiki/${DATE}/${DATE}-mysqldump-wormbasewiki.sql.gz
##    rsync -avv --rsh=ssh --exclude logs/ ${SOCIAL_USER}@${SOCIAL_HOST}:/usr/local/wormbase/website-wiki/ \
##	  /usr/local/wormbase/backups/wiki/${DATE}/.
#    rsync -avv -e "/usr/bin/ssh -i $KEY" --exclude logs/ ${SOCIAL_USER}@${SOCIAL_HOST}:/usr/local/wormbase/website/social/wiki/ \
#	  /usr/local/wormbase/backups/wiki/${DATE}/.
#    cd /usr/local/wormbase/backups/wiki
#    tar -czf ${DATE}.tgz ${DATE}
#    rm -rf ${DATE}

#######################
#  Forums
#######################
echo "Backing up production:forums to ${BACKUP_HOST}";

# One copy
mkdir -p /usr/local/wormbase/backups/forums/mysqldumps
    /usr/local/mysql/bin/mysqldump \
             -h ${SOCIAL_HOST} -u wormbase wormbaseforumsmf \
	     | gzip -c > /usr/local/wormbase/backups/forums/mysqldumps/${DATE}-mysqldump-wormbaseforumsmf.sql.gz

rsync -avv -e "/usr/bin/ssh -i $KEY" --exclude logs/ ${SOCIAL_USER}@${SOCIAL_HOST}:/usr/local/wormbase/website/social/forums/ \
	  /usr/local/wormbase/backups/forums/.

# Or daily copies
#mkdir -p /usr/local/wormbase/backups/forums/${DATE}
#/usr/local/mysql/bin/mysqldump \
#             -h ${WORMBASE_USER_DB_HOST} -u wormbase wormbaseforumsmf \
#	     | gzip -c > /usr/local/wormbase/backups/forums/${DATE}/${DATE}-mysqldump-wormbaseforumsmf.sql.gz
#    rsync -avv --rsh=ssh --exclude logs/ ${SOCIAL_USER}@${SOCIAL_HOST}:/usr/local/wormbase/website/social/forums/ \
#	  /usr/local/wormbase/backups/forums/${DATE}/.
#rsync -avv -e "/usr/bin/ssh -i $KEY" --exclude logs/ ${SOCIAL_USER}@${SOCIAL_HOST}:/usr/local/wormbase/website/social/forums/ \
#       /usr/local/wormbase/backups/forums/${DATE}/.
#cd /usr/local/wormbase/backups/forums
#tar -czf ${DATE}.tgz ${DATE}
#rm -rf ${DATE}

  


