package WormBase::Update::EC2::MoveSQLDatabasesBetweenHosts;

use Moose;
extends qw/WormBase::Update::EC2/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => "move sql databases between hosts",
);

has 'target_host' => (
    is => 'rw',
    default => 'localhost');

has 'target_user' => (
    is => 'rw',
    default => 'root');

has 'target_pass' => (
    is => 'rw',
    default => '3l3g@nz');

has 'source_host' => (
    is => 'rw',
    default => 'localhost');

has 'source_user' => (
    is => 'rw',
    default => 'root');

has 'source_pass' => (
    is => 'rw',
    default => 'root');

sub run {
    my $self = shift;            

    my $release    = $self->release;
    my $target_host = $self->target_host;
    my $target_user = $self->target_user;
    my $target_pass = $self->target_pass;

    my ($species) = $self->wormbase_managed_species;
    foreach my $name (sort { $a cmp $b } @$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });
#	next unless $name =~ /elegans/;
	$self->log->info(uc($name). ': start');	
	
	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;
	my @dbs;
	foreach my $bioproject (@$bioprojects) {	    
	    my $id = $bioproject->bioproject_id;
	    push @dbs,join('_',$name,$id,$release);
	}
    }
    
    push @dbs,"clustal_$release"; # move the clustal database over, too.

    my $dbs = join(' ',@dbs);    

    my $script = <<END;
#!/bin/bash

declare -a dbs=($dbs);

# Environmentally dependent
TMPDIR=/usr/local/wormbase/tmp/database_dumps
mkdir -p \$TMPDIR

# Number of databases
COUNT=\${#dbs[@]}

function do_sql_load () {   
    this_db=\$1;
    
    # Use the *internal* ip of your RDS instance to avoid
    # data transfer charges.
    # This will ONLY work when run from within another EC2 instance!
    ADDRESSES=`dig +short $target_host`
    ADDRESSES_ARRAY=( \$ADDRESSES );
    TARGET_HOST=\${ADDRESSES_ARRAY[2]};
    
    echo "Dumping \${this_db} DB"
    echo "    Command is:"
    echo "    mysqldump --order-by-primary --host=$source_host --user=$source_user --password=$source_pass `echo \${this_db}` > $TMPDIR/`echo \${this_db}`.sql"
    
    time mysqldump --order-by-primary --host=$source_host --user=$source_user --password=$source_pass `echo ${this_db}` > $TMPDIR/`echo \${this_db}`.sql
    
    echo "Adding optimizations to \${this_db}"
    awk 'NR==1{\$0="SET autocommit=0; SET unique_checks=0; SET foreign_key_checks=0;\n"\$0}1' \$TMPDIR/`echo \${this_db}`.sql >> \$TMPDIR/`echo \${this_db}`X.sql
    mv \$TMPDIR/`echo \${this_db}`X.sql \$TMPDIR/`echo \${this_db}`.sql
    echo "SET unique_checks=1; SET foreign_key_checks=1; COMMIT;" >> \$TMPDIR/`echo \${this_db}`.sql
    echo "Creating \${this_db} on host $target_host"
    mysql --host=\$TARGET_HOST --user=$target_user --password=$target_pass -e "create database \${this_db}"
    
    echo "Copy \${this_db} into $target_host"
    time mysql --host=\$TARGET_HOST --user=$target_user --password=$target_pass `echo \${this_db}` < /\$TMPDIR/`echo \${this_db}`.sql    
}

j=0
while [ \$j -lt \${COUNT} ];
do
    this_db="\${dbs[\$j]}_$release"
    do_sql_load \${this_db}    
    j=\$((\$j+1))
done
END
;

    open OUT,">/tmp/script.sh";
    print OUT $script;
    $self->system_call("chmod 775 /tmp/script.sh");

    # Finally, run the script.
    $self->system_call("/tmp/script.sh");
    
}




1;
