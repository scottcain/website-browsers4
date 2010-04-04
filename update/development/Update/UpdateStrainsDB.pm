package Update::UpdateStrainsDB;

use strict;
use FindBin '$Bin';
use Ace;
use Search::Indexer;
use Storable qw(store retrieve nstore);
use base 'Update';

# The symbolic name of this step
sub step { return 'update strains database'; }

sub run {
    my $self = shift;    
    my $release   = $self->release;
    
#    $self->strains_dir($self->root . "/website-classic/html/strains/$release");      
    $self->strains_dir($self->root . "/databases/$release/strains"); 
    $self->_make_dir($self->strains_dir);
    
    $self->make_html_files();
    $self->index_files;
    
    my $fh = $self->master_log;
    print $fh $self->step . " complete...\n";
}

# This is ripped directly from Igor's make_html_files.  Don't have time to polish.
sub make_html_files {
    my $self = shift;
    
    chdir($self->strains_dir);
    system("wget -N http://www.cbs.umn.edu/CGC/strains/gophstrnt.txt");
    
    my $gopher_file = $self->strains_dir . "/gophstrnt.txt";    
    open IN, "<$gopher_file" || die "$!\n";
    
    my $release    = $self->release;
    my $acedb_path = $self->acedb_root . "/wormbase_$release";
    my $db = Ace->connect($acedb_path) || die "Connection failure: ", Ace->error;
    my %status=$db->status;
    my $output = $self->strains_dir;
    
    my $now=localtime;
    
    my $query="find strain";
    
    my @tmp=$db->find($query);
    print scalar @tmp, " strains in $status{database}{title} $status{database}{version} found on $now\n";
    my %strain_hash_wb=();
    foreach (@tmp) {
	$strain_hash_wb{$_}=1;
    }
    
    
#my ($strain, $species, $genotype, $description, $mutagen, $outcrossed, $reference, $made_by, $recieved);
    my %hash=();
    my $count=0;
    my $strain='';
    my $section='';
    my $content='';
    my $not_in_wormbase_count=0;
    my %strain_hash_cgc=();
    my $body = qq{onload='highlightIgorSearchTerms(document.referrer);' class="noboiler"};
    while (<IN>) {
	s/\r\n/\n/g;
	s/\r/\n/g;
	chomp;
	next unless $_;
	next if /----------/;
	if (/Strain:/) {
	    if ($strain) {
		my $filename = "$output/$strain.html";
		open OUT, ">$filename" || die "cannot open $filename\n";
#	    print OUT "<html><head><title>$strain</title><script language=\"JavaScript\" src=\"js/highlightTerms.js\"></script></head>\n";
#	    print OUT "<body bgcolor=\"FFFFF0\" onload=\'highlightIgorSearchTerms(document.referrer);\'><h1>$strain</h1>\n";
#	    print OUT "<html><body>";
		$self->print_top($strain, \*OUT, $body);
		print OUT qq{<script language="JavaScript" src="/js/highlightTerms.js"></script><h1>$strain</h1>};
		
		print OUT qq{<div class="warning">The details of this new strain have been drawn from the CGC. The full record will be integrated into WormBase in the near future.</div>};
		print OUT "<dl>\n";
		foreach my $s ('Strain', 'Species', 'Genotype', 'Description', 'Mutagen', 'Outcrossed', 'Available at CGC', 'WormBase Strain Report', 'Reference', 'Made by', 'Received') {
		    if (!$hash{$s}) {
			$hash{$s}='';
		    } 
		    $hash{$s}=~s/\t/ /g;
		    $hash{$s}=~s/\s{2,}/ /g;
		    print OUT "<dt title=\"$s\"><strong>$s:</strong></dt>\n";
		    print OUT "<dd>$hash{$s}</dd>\n";
		}
		print OUT "<br>\n";
		$self->print_bottom(\*OUT);
		print OUT "</body></html>\n";
		close OUT;
	    }
	    %hash=();
	    $section="Strain";
	    $strain=$_=~/Strain:\s+(.+)/ ? $1 : 'no_name';
	    $hash{$section}.=$strain;
	    $hash{'Available at CGC'}='Yes';
	    if ($strain_hash_wb{$strain} || $strain_hash_wb{lc $strain} || $strain_hash_wb{uc $strain}) {
		$hash{'WormBase Strain Report'}="<a href=/db/gene/strain?name=$strain;class=Strain>$strain</a>";
	    }
	    else {
		$hash{'WormBase Strain Report'} = "Strain not yet available through WormBase";
		$not_in_wormbase_count++;
	    }
	    if ($strain_hash_cgc{$strain}) {
		print "$strain already parsed\n";
	    }
	    else {
		$strain_hash_cgc{$strain}=1;
		$count++;
	    }
	}
	elsif (/Species:/) {
	    $section="Species";
	    $content=$_=~/^\s*\w+:\s+(.+)/ ? $1 : '';
	    $hash{$section}.=$content;
	}
	elsif (/Genotype:/) {
	    $section="Genotype";
	    $content=$_=~/^\s*\w+:\s+(.+)/ ? $1 : '';
	    $hash{$section}.=$content;
	}
	elsif (/Description:/) {
	    $section="Description";
	    $content=$_=~/^\s*\w+:\s+(.+)/ ? $1 : '';
	    $hash{$section}.=$content;
	}
	elsif (/Mutagen:/) {
	    $section="Mutagen";
	    $content=$_=~/^\s*\w+:\s+(.+)/ ? $1 : '';
	    $hash{$section}.=$content;
	}
	elsif (/Outcrossed:/) {
	    $section="Outcrossed";
	    $content=$_=~/^\s*\w+:\s+(.+)/ ? $1 : '';
	    $hash{$section}.=$content;
	}
	elsif (/Reference:/) {
	    $section="Reference";
	    $content=$_=~/^\s*\w+:\s+(.+)/ ? $1 : '';
	    $hash{$section}.=$content;
	}
	elsif (/Made by:/) {
	    $section="Made by";
	    $content=$_=~/^\s*Made by:\s+(.+)/ ? $1 : '';
	    $hash{$section}.=$content;
	}
	elsif (/Received:/) {
	    $section="Received";
	    $content=$_=~/^\s*\w+:\s+(.+)/ ? $1 : '';
	    $hash{$section}.=$content;
	}
	else {
	    $hash{$section}.=$_;
	}
    }
    
    if ($strain) {
	my $filename= "$output/$strain.html";
	open OUT, ">$filename" || die "cannot open $filename\n";
#    print OUT "<html><head><title>$strain</title><script language=\"JavaScript\" src=\"js/highlightTerms.js\"></script></head>\n";
#    print OUT "<body bgcolor=\"FFFFF0\" onload=\'highlightIgorSearchTerms(document.referrer);\'><h1>$strain</h1>\n";
	$self->print_top($strain, \*OUT, $body);
	print OUT "<script language=\"JavaScript\" src=\"js/highlightTerms.js\"></script><h1>$strain</h1>\n";
	print OUT qq{<div class="warning">This new CGC strain has not yet been entered into WormBase.</div>};
	
	print OUT "<dl>\n";
	foreach my $s ('Strain', 'Species', 'Genotype', 'Description', 'Mutagen', 'Outcrossed', 'Available at CGC', 'WormBase Strain Report', 'Reference', 'Made by', 'Received') {
	    if (!$hash{$s}) {
		$hash{$s}='';
	    } 
	    $hash{$s}=~s/\t/ /g;
	    $hash{$s}=~s/\s{2,}/ /g;
	    print OUT "<dt title=\"$s\"><strong>$s:</strong></dt>\n";
	    print OUT "<dd>$hash{$s}</dd>\n";
	}
	print OUT "<br>\n";
	$self->print_bottom(\*OUT);
#    print OUT "<script language=\"JavaScript\">highlightIgorSearchTerms(document.referrer);</script></body></html>\n";
	print OUT "</body></html>\n";
#    print OUT "</dl><hr><a href=\"mailto:webmaster\@wormbase.org\">webmaster\@www.wormbase.org</a></body></html>\n";
	close OUT;
    }
    
    
    my $not_in_cgc_count=0;
    my $no_info_count=0;
    
    print "parsing strains from WormBase\n";
    $query="find strain";
    @tmp=$db->find($query);
    
    foreach (@tmp) {
	%hash=();
	if ($strain_hash_cgc{$_} || $strain_hash_cgc{lc $_} || $strain_hash_cgc{uc $_}) {
	    next;
	}
	else {
	    my $line='';
	    eval {
		$line=$_->asAce();
	    };
	    if ($@) {
#		print "$_\n";
#		print "$@\n";
		$no_info_count++;
		$line='';
	    }
	    
	    my @lines=split('\n', $line);
	    $strain=$_;
	    $hash{'Available at CGC'}='No';
	    $hash{'WormBase Strain Report'}="<a href=http://www.wormbase.org/db/gene/strain?name=$strain;class=Strain>$strain</a>";
	    $hash{'Strain'}=$strain;
	    
	    foreach (@lines) {
		if (/^Contains\s+Gene/) {
		    $section="Gene";
		    my @tmp=split('\t');
		    $tmp[2]=~s/\"//g;
		    my $name=$db->fetch(Gene=>$tmp[2])->Public_name;
		    push @{$hash{$section}}, $name;
		}
		elsif (/^Contains\s+Variation/) {
		    $section="Variation";
		    my @tmp=split('\t');
		    $tmp[2]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[2];
		}
		elsif (/^Contains\s+Rearrangement/) {
		    $section="Rearrangement";
		    my @tmp=split('\t');
		    $tmp[2]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[2];
		}
		elsif (/^Contains\s+Clone/) {
		    $section="Clone";
		    my @tmp=split('\t');
		    $tmp[2]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[2];
		}
		elsif (/^Contains\s+Transgene/) {
		    $section="Transgene";
		    my @tmp=split('\t');
		    $tmp[2]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[2];
		}
		elsif (/^Genotype/) {
		    $section="Genotype";
		    my @tmp=split('\t');
		    $tmp[1]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[1];
		}
		elsif (/^Outcrossed/) {
		    $section="Outcrossed";
		    my @tmp=split('\t');
		    $tmp[1]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[1];
		}
		elsif (/^Mutagen/) {
		    $section="Mutagen";
		    my @tmp=split('\t');
		    $tmp[1]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[1];
		}
		elsif (/^Location/) {
		    $section="Laboratory";
		    my @tmp=split('\t');
		    $tmp[1]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[1];
		}
		elsif (/^Made_by/) {
		    $section="Made by";
		    my @tmp=split('\t');
		    $tmp[1]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[1];
		}
		elsif (/^Remark/) {
		    $section="Description";
		    my @tmp=split('\t');
		    $tmp[1]=~s/\"//g;
		    push @{$hash{$section}}, $tmp[1];
		}
		elsif (/^Reference/) {
		    $section="Reference";
		    my @tmp=split('\t');
		    $tmp[1]=~s/\"//g;
		    my $paper=$db->fetch(Paper=>$tmp[1])->Brief_citation;
		    push @{$hash{$section}}, $paper;
		}
	    }
	    	    
	    my $filename="$output/$strain.html";
	    open OUT, ">$filename" || die "cannot open $filename\n";
	    if (! fileno(OUT)) {
		print "$filename file is not opened\n";
		next;
	    }
	    $self->print_top($strain, \*OUT, $body);
	    print OUT "<script language=\"JavaScript\" src=\"js/highlightTerms.js\"></script><h1>$strain</h1>\n";
	    print OUT "<dl>\n";
	    foreach my $s ('Strain', 'Species', 'Genotype', 'Description', 'Mutagen', 'Outcrossed', "Gene", "Variation", "Rearrangement", "Clone", "Transgene", 'Available at CGC', "Laboratory", 'WormBase Strain Report', 'Reference', 'Made by', 'Received') {
		if (!$hash{$s}) {
		    next;
		}
		eval {
		    $hash{$s}=join(', ', @{$hash{$s}});
		};
		if ($@) {
#		    print "$@";
		}
		
		$hash{$s}=~s/\t/ /g;
		$hash{$s}=~s/\s{2,}/ /g;
		print OUT "<dt title=\"$s\"><strong>$s:</strong></dt>\n";
		print OUT "<dd>$hash{$s}</dd>\n";
	    }
	    print OUT "<br>\n";
	    $self->print_bottom(\*OUT);
#	    print OUT "<script language=\"JavaScript\">highlightIgorSearchTerms(document.referrer);</script></body></html>\n";
	    print OUT "</body></html>\n";
#	    print OUT "</dl><hr><a href=\"mailto:webmaster\@wormbase.org\">webmaster\@www.wormbase.org</a></body></html>\n";
	    close OUT;
	    $not_in_cgc_count++;
	    $count++;
	    if ($not_in_cgc_count % 100 == 0) {
#		print "$not_in_cgc_count strains processed\n";
	    }
	    
	}
    }
}



############################################################
#
#    written by Igor Antoshechkin
#    igor.antoshechkin@caltech.edu
#    Dec. 2005
#
############################################################
sub index_files {
    my $self = shift;
    my $strains_dir = $self->strains_dir;
    
    my $release = $self->release;
    my $acedb   = $self->acedb_root . "/wormbase_$release";    
    my $db = Ace->connect($acedb) || die "Connection failure: ", Ace->error;

    my $lookupFileName="lookup.strains";
    
    my $ix = new Search::Indexer({dir => $strains_dir, writeMode => 1});
    my $pref = $self->strains_dir;
    my @allfilestmp = `ls -R $pref`;
    my @dirs;
    
    my $pathtmp;
    my @allfiles=();
    foreach (@allfilestmp) {
	chomp;
	next if $_ eq 'ixw.bdb';
	next if $_ eq 'ixp.bdb';
	next if $_ eq 'ixd.bdb';
	next if $_ eq 'lookup.strains';
	next if $_ =~ /goph/;
	
	next unless $_;
	if (/\:$/) {
	    $pathtmp=$_;
	    $pathtmp=~s/\://g;
	    next;
	}
	next unless $pathtmp;
	next unless  (/\.html$/i or /\.htm$/i);
	push @allfiles, "$pathtmp/$_";
    }
    
    foreach (@allfiles) {
	$_=~s/\/\//\//g;
    }
    
    if (!@allfiles) {
	print "no files found in $pref\n" if $pref;
	exit;
    }
    
    print scalar @allfiles, " found in $pref\n" if $pref;
    
    my $i=0;
    
    my %strain_hash=();
    
    foreach my $f (sort {$a cmp $b} @allfiles) {
	my $content='';
	my $section='';
	my $inCGC='No';
	my $inWB='No';
	my $genotype='';
	my $title='';
	my $tmp_filename=$f;
	open (FILE, "<$f") || die "cannot open $f : $!\n";
	while (<FILE>) {
	    chomp;
	    next unless $_;
	    if (/<title.*>(.*)<\/title>/i) {
		$title=$1;
		$content.=$title;
		my $lab=$title=~/(\D+)\d+/ ? $1 : '';
		$content.=" $lab ";
	    }
	    elsif (/<dt\s+title=\"([^\"]+)\">/) {
		$section=$1;
		
	    }
	    elsif (/<dd>/) {
		$content.=" $_ ";
		if ($section eq 'Available at CGC') {
		    $inCGC=$_=~/Yes/ ? "Yes" : "No";
		}
		elsif ($section eq 'Genotype') {
		    $genotype=$_;
		    $genotype=~s/<.*?>//gs;
		}
		elsif ($section eq 'WormBase Strain Report') {
		    $inWB=$_=~/class=Strain/ ? "Yes" : "No";
		}
	    }
	}    
	
	close FILE;
	$content=~s/<.*?>/ /gs;
	$content=~s/\t/ /g;
	$content=~s/\s{2,}/ /g;
	if (! $content) {
#	    $i++;
	    next;
	}
#	$i++;
#	print STDERR "$i $genotype\n";


	$ix->add($i, $content);
	$strain_hash{$i}{strain}=$title;
	$strain_hash{$i}{CGC}=$inCGC;
	$strain_hash{$i}{WB}=$inWB;
	$strain_hash{$i}{genotype}=$genotype;
	$strain_hash{$i}{file}=$tmp_filename;
	$i++;
	
	if ($i % 1000 == 0) {
	    print "$i files processed\n";
	}
    }
    
    my $tmpout=$strains_dir . "/$lookupFileName";
    nstore \%strain_hash, $tmpout || die "cannot store strain_hash in $tmpout : $!\n";
    print "$i files indexed\n";
}


sub print_top {
    my ($self,$title,$fh,$body) = @_;
    if ($fh) {
	if (!fileno($fh)) {
	    print "filehandle $fh is not opened: print_top\n";
	    exit;
	}
	select($fh);
    }

    print qq(
	     <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
	     <html><head>
	     <title>$title</title>
	     
	     
	     <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
	     <link rel="stylesheet" href="/stylesheets/wormbase.css"></head><body $body>
	     <script type="text/javascript">
	     <!--
	     function c(p){location.href=p;return false;}
	     // -->
	     </script>
	     <table border="0" cellpadding="4" cellspacing="1" width="100%">
	     <tbody><tr>
	     <td style="" onclick="c('/')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://wormbase.org/" class="binactive"><font color="#ffff99"><b>Home</b></font></a></td>
	     <td style="" onclick="c('/db/seq/gbrowse/wormbase/')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://www.wormbase.org/db/seq/gbrowse/wormbase/" class="binactive"><font color="#ffffff">Genome</font></a></td>
	     <td style="" onclick="c('/db/searches/blat')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://www.wormbase.org/db/searches/blat" class="binactive"><font color="#ffffff">Blast / Blat</font></a></td>
	     <td style="" onclick="c('http://www.wormbase.org/Multi/martview')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://www.wormbase.org/Multi/martview" class="binactive"><font color="#ffffff">WormMart</font></a></td>
	     <td style="" onclick="c('/db/searches/advanced/dumper')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://www.wormbase.org/db/searches/advanced/dumper" class="binactive"><font color="#ffffff">Batch Sequences</font></a></td>
	     <td style="" onclick="c('/db/searches/strains')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://www.wormbase.org/db/searches/strains" class="binactive"><font color="#ffffff">Markers</font></a></td>
	     <td style="" onclick="c('/db/gene/gmap')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://www.wormbase.org/db/gene/gmap" class="binactive"><font color="#ffffff">Genetic Maps</font></a></td>
	     <td style="" onclick="c('/db/curate/base')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://www.wormbase.org/db/curate/base" class="binactive"><font color="#ffffff">Submit</font></a></td>
	     <td style="" onclick="c('/db/misc/site_map?format=searches')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://www.wormbase.org/db/misc/site_map?format=searches" class="binactive"><font color="#ffffff"><b>Searches</b></font></a></td>
	     <td style="" onclick="c('/db/misc/site_map')" align="center" bgcolor="#5870a3" nowrap="nowrap">
	     <a href="http://www.wormbase.org/db/misc/site_map" class="binactive"><font color="#ffffff"><b>Site Map</b></font></a></td>
	     </tr>
	     </tbody></table><table nowrap="1" border="0" cellpadding="0" cellspacing="1" width="100%"><tbody><tr class="white" nowrap="1" valign="top"><td align="left" valign="middle" width="50%">
	     	     
	     <form method="post" action="http://www.wormbase.org/db/searches/basic" enctype="multipart/form-data">
	     <b>Find: <input name="query" size="12" type="text"></b> 
	     <i><select name="class">
	     <option value="Any">Anything</option>
	     <option selected="selected" value="AnyGene">Any Gene</option>
	     <option value="Author_Person">Author/Person</option>
	     <option value="Variation">Allele</option>
	     <option value="Cell">Cell</option>
	     <option value="Clone">Clone</option>
	     <option value="Model">Database Model</option>
	     <option value="GO_term">Gene Ontology Term</option>
	     <option value="Gene_class">Gene class</option>
	     <option value="Genetic_map">Genetic Map</option>
	     <option value="Accession_number">Genbank Acc. Num</option>
	     <option value="Paper">Literature Search</option>
	     <option value="Microarray_results">Microarray Expt</option>
	     <option value="Operon">Operon</option>
	     <option value="PCR_Product">Primer Pair</option>
	     <option value="Protein">Protein, Any</option>
	     <option value="Wormpep">Protein, C. elegans</option>
	     <option value="Motif">Protein Family/Motif</option>
	     <option value="RNAi">RNAi Result</option>
	     <option value="Sequence">Sequence, Any</option>
	     <option value="Genome_sequence">Sequence, C. elegans</option>
	     <option value="Strain">Strain, C. elegans</option>
	     <option value="Y2H">Y2H interaction</option>
	     </select> </i>
	     </form>
	     
	     </td> <td align="right"><a href="http://www.wormbase.org/"><img src="/images/image_new_colour.jpg" alt="WormBase Banner" border="0"></a></td></tr></tbody></table><br>                                               
	     
	     
	     <p>   <!-- End of Wormbase Header -->                                   
	     </p>
	     );
    
    if ($fh) {
	select(STDOUT);
    }
}

sub print_bottom {
    my ($self,$fh) = @_;
    if ($fh) {
	if (!fileno($fh)) {
	    print "filehandle $fh is not opened\n";
	    exit;
	}
	select($fh);
    }

    print qq (
	      <hr>
	      <table width="100%"><tbody><tr><td class="small" align="left"><a href="mailto:webmaster\@wormbase.org">webmaster\@www.wormbase.org</a></td> <td class="small" align="right"><a href="http://www.wormbase.org/copyright.html">Copyright Statement</a></td></tr> <tr><td class="small" align="left"><a target="_blank" href="http://www.wormbase.org/db/misc/feedback">Send comments or questions to WormBase</a></td> <td class="small" align="right"><a href="http://www.wormbase.org/privacy.html">Privacy Statement</a></td></tr></tbody></table>
	      );
    if ($fh) {
	select(STDOUT);
    }
}







1;
