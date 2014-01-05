package WormBase::Update::Staging::DumpMySQLDatabases;

use Moose;
extends qw/WormBase::Update/;

# The symbolic name of this step
has 'step' => (
    is      => 'ro',
    default => "dump mysql databases for easy porting between instances",
);

has 'source_user' => (
    is => 'rw',
    default => 'root');

has 'source_pass' => (
    is => 'rw',
    default => '3l3g@nz');

sub run {
    my $self = shift;            

    my $release    = $self->release;
    my $source_user = $self->target_user;
    my $source_pass = $self->target_pass;

    my ($species) = $self->wormbase_managed_species;
    my @dbs;
    foreach my $name (sort { $a cmp $b } @$species) {
	my $species = WormBase->create('Species',{ symbolic_name => $name, release => $release });
	$self->log->info(uc($name). ': start');	
	
	# Now, for each species, iterate over the bioproject IDs.
	# These are just strings.
	my $bioprojects = $species->bioprojects;	
	foreach my $bioproject (@$bioprojects) {	    
	    my $id = $bioproject->bioproject_id;
	    push @dbs,join('_',$name,$id,$release);
	}
    }
    
    push @dbs,"clustal_$release";

    my $dbs = join(' ',@dbs);    
    my $tmp = "/usr/local/wormbase/databases/$release/sql_dumps";
    $self->system_call("mkdir -p $tmp");
    
    my $script = <<END;
#!/bin/bash

declare -a dbs=($dbs);

# Number of databases
COUNT=\${#dbs[@]}

function do_sql_load () {   
    this_db=\$1;
    
    echo "Dumping \${this_db} DB"
    echo "    Command is:"
    echo "    mysqldump --order-by-primary --host=localhost --user=$source_user --password=$source_pass `echo \${this_db}` > $tmp/`echo \${this_db}`.sql"
    
    time mysqldump --order-by-primary --host=localhost --user=$source_user --password=$source_pass `echo \${this_db}` > $tmp/`echo \${this_db}`.sql
    
    echo "Adding optimizations to \${this_db}"
    awk 'NR==1{\$0="SET autocommit=0; SET unique_checks=0; SET foreign_key_checks=0;\n"\$0}1' $tmp/`echo \${this_db}`.sql >> $tmp/`echo \${this_db}`X.sql
    mv $tmp/`echo \${this_db}`X.sql $tmp/`echo \${this_db}`.sql
    echo "SET unique_checks=1; SET foreign_key_checks=1; COMMIT;" >> $tmp/`echo \${this_db}`.sql
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
#    $self->system_call("/tmp/script.sh");    
}




1;
