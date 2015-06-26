#!/bin/bash

# This is a script to migrate staged GFF databases
# to our RDS endpoint.

# For this to work, it will probably be necessary to update mysql
# (/etc/my.cnf) to write to a tmpdir with higher capacity.
# I'm using /mnt/ephemeral1

#declare -a dbs=(dbname1 dbname2 dbname3 dbname4);
# This list should be discoverable and  should use the g_species_BPID_WSXXX format

VERSION=$1

if [ ! $VERSION ]; then
    exit "Usage: $0 WSXXX"
fi

#declare -a dbs=(t_spiralis_PRJNA12603)
#declare -a dbs=(wormbase_wiki)
# Hard-coded. Uncool.
declare -a dbs_gff=(
    a_ceylanicum_PRJNA231479
    a_suum_PRJNA80881
    a_suum_PRJNA62057
    b_malayi_PRJNA10729
    b_xylophilus_PRJEA64437
    c_angaria_PRJNA51225
    c_brenneri_PRJNA20035
    c_briggsae_PRJNA10731
    c_elegans_PRJNA13758
    c_japonica_PRJNA12591
    c_remanei_PRJNA53967
    c_sp5_PRJNA194557
    c_tropicalis_PRJNA53597
    d_immitis_PRJEB1797
    h_bacteriophora_PRJNA13977
    h_contortus_PRJEB506
    h_contortus_PRJNA205202
    l_loa_PRJNA60051
    m_hapla_PRJNA29083
    m_incognita_PRJEA28837
    n_americanus_PRJNA72135
    o_volvulus_PRJEB513
    p_pacificus_PRJNA12644
    p_exspectatus_PRJEB6009
    p_redivivus_PRJNA186477
    s_ratti_PRJEA62033
    t_spiralis_PRJNA12603
    t_suis_PRJNA208415
    t_suis_PRJNA208416
)

# RDS endpoint (CNAME)
RDS_HOSTNAME=www.wormbase.org
RDS_USER=wormbase
RDS_PASSWORD=sea3l3ganz

SOURCE_HOST=localhost
SOURCE_USER=root
SOURCE_PASS=3l3g@nz

TMPDIR=/mnt/ephemeral0/usr/local/wormbase/tmp/database_dumps
mkdir -p $TMPDIR

# Number of databases
COUNT=${#dbs_gff[@]}

function do_sql_load () {   
    this_db=$1;
    
    # Use the *internal* ip of your RDS instance to avoid
    # data transfer charges.
    # This will ONLY work when run from within another EC2 instance!
    ADDRESSES=`dig +short ${RDS_HOSTNAME}`
    ADDRESSES_ARRAY=( $ADDRESSES );
    RDS_ENDPOINT=${ADDRESSES_ARRAY[1]};
    
    echo "Dumping ${this_db} DB"
    echo "    Command is:"
    echo "    mysqldump --order-by-primary --host=$SOURCE_HOST --user=$SOURCE_USER --password=$SOURCE_PASS `echo ${this_db}` > $TMPDIR/`echo ${this_db}`.sql"
    
    time mysqldump --order-by-primary --host=$SOURCE_HOST --user=$SOURCE_USER --password=$SOURCE_PASS `echo ${this_db}` > $TMPDIR/`echo ${this_db}`.sql
#    time mysqldump --order-by-primary --user=$SOURCE_USER --password=$SOURCE_PASS `echo ${this_db}` > $TMPDIR/`echo ${this_db}`.sql
    
    echo "Adding optimizations to ${this_db}"
    awk 'NR==1{$0="SET autocommit=0; SET unique_checks=0; SET foreign_key_checks=0;\n"$0}1' $TMPDIR/`echo ${this_db}`.sql >> $TMPDIR/`echo ${this_db}`X.sql
    mv $TMPDIR/`echo ${this_db}`X.sql $TMPDIR/`echo ${this_db}`.sql
    echo "SET unique_checks=1; SET foreign_key_checks=1; COMMIT;" >> $TMPDIR/`echo ${this_db}`.sql
    echo "Creating ${this_db} on shared ysql host $RDS_ENDPOINT"
    echo "     Command is:"
    echo "mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD -e \"create database ${this_db}\""
    mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD -e "create database ${this_db}"
#    mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD -e "grant select on ${this_db}.* to 'wormbase'@'%' IDENTIFIED BY 'sea3l3ganz'"
    mysql --host=$RDS_ENDPOINT --user=root --password=$RDS_PASSWORD -e "grant select on ${this_db}.* to 'wormbase'@'%' IDENTIFIED BY 'sea3l3ganz'"
    
    echo "Copy ${this_db} into RDS"
#    time mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD `echo ${this_db}` < /$TMPDIR/`echo ${this_db}`.sql &
    time mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD `echo ${this_db}` < /$TMPDIR/`echo ${this_db}`.sql    
    rm -f /$TMPDIR/`echo ${this_db}`.sql
}




#j=0
#while [ $j -lt ${COUNT} ];
#do
#    this_db="${dbs[$j]}_${VERSION}"
#
#    # Use the *internal* ip of our RDS instance to avoid
#    # data transfer charges.
#    # This will ONLY work when run from an EC2 instance!
#    ADDRESSES=`dig +short ${RDS_HOSTNAME}`
#    ADDRESSES_ARRAY=( $ADDRESSES );
#    RDS_ENDPOINT=${ADDRESSES_ARRAY[2]};
#
#    echo "Dumping ${this_db} DB"
#    echo "    Command is:"
#    echo "    mysqldump --order-by-primary --host=$SOURCE_HOST --user=$SOURCE_USER --password=$SOURCE_PASS `echo ${this_db}` > $TMPDIR/`echo ${this_db}`.sql"
#
#    time mysqldump --order-by-primary --host=$SOURCE_HOST --user=$SOURCE_USER --password=$SOURCE_PASS `echo ${this_db}` > $TMPDIR/`echo ${this_db}`.sql
#
#    echo "Adding optimizations to ${this_db}"
#    awk 'NR==1{$0="SET autocommit=0; SET unique_checks=0; SET foreign_key_checks=0;\n"$0}1' $TMPDIR/`echo ${this_db}`.sql >> $TMPDIR/`echo ${this_db}`X.sql
#    mv $TMPDIR/`echo ${this_db}`X.sql $TMPDIR/`echo ${this_db}`.sql
#    echo "SET unique_checks=1; SET foreign_key_checks=1; COMMIT;" >> $TMPDIR/`echo ${this_db}`.sql
#    echo "Creating ${this_db} on RDS host $RDS_ENDPOINT"
#    mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD -e "create database ${this_db}"
#
#    echo "Copy ${this_db} into RDS"
##    time mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD `echo ${this_db}` < /$TMPDIR/`echo ${this_db}`.sql &
#    time mysql --host=$RDS_ENDPOINT --user=$RDS_USER --password=$RDS_PASSWORD `echo ${this_db}` < /$TMPDIR/`echo ${this_db}`.sql
#    
#    j=$(($j+1))
#done

j=0
while [ $j -lt ${COUNT} ];
do
    this_db="${dbs_gff[$j]}_${VERSION}"
#    this_db="${dbs_gff[$j]}"
    do_sql_load ${this_db}    
    j=$(($j+1))
done

# Also copy over the clustal database
do_sql_load "clustal_${VERSION}"
