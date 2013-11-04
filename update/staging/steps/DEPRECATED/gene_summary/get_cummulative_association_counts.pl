#!/usr/bin/perl

# This all needs to be folded into the W::U::S::CompileOntolgyResources
# What a mess.

### main ###

use strict;

my $version = shift;
chomp $version;

my $data_directory = "/usr/local/wormbase/databases/$version/ontology/";

our %id2parents = build_hash($data_directory.'id2parents.txt');
our %id2name = build_hash($data_directory.'id2name.txt');
our %parent2ids = build_hash($data_directory.'parent2ids.txt');
our %id2association_counts = build_hash($data_directory.'id2association_counts.txt');

get_cummulative_associations($data_directory . 'id2total_associations.txt');

### subroutines

sub get_cummulative_associations {

	my $outfile = shift @_;
	my @ids = keys %id2name;
	
	open OUT, ">$outfile" or die "Cannot open output file\n";
	
	foreach my $term_id (@ids) {
	
		my @path_array = ($term_id); ## 
		my @paths = &call_list_paths(\@path_array,\%id2parents,\%id2name);
		my %descendants; 
	
		foreach my $path (@paths) {
		
			my @descendants = split '%', $path;
			foreach my $descendant (@descendants) {
	
				$descendants{$descendant} = 1;	
			}
		}
	
		my $total_count = 0;
		my @descendants = keys %descendants;
	
		shift  @descendants;
	
		foreach my $descendant (@descendants) {
	
			# print "DESC\:$descendant\:$id2association_counts{$descendant}\:$total_count\n";	
			$total_count = $total_count + $id2association_counts{$descendant};	
		}
	
		print OUT "$term_id\=\>$total_count\n";
	
	}
}

### end main ####


sub build_hash{
	my ($file_name) = @_;
	open FILE, "<$file_name" or die "Cannot open the file: $file_name\n";
	my %hash;
	foreach my $line (<FILE>) {
		chomp ($line);
		my ($key, $value) = split '=>',$line;
		$hash{$key} = $value;
	}
	return %hash;
}


sub call_list_paths {
	
	use DB_File;
	
	my ($path_array,$id2parents_ref,$id2name_hr) = @_;
	my @output;
	my $output_ar = \@output; 
	our %id2parents = %{$id2parents_ref};
	our %id2name = %{$id2name_hr};
	&list_paths($path_array,$output_ar);

}

sub list_paths {

	## enter array
	
	my ($destinations_ar, $output_ar) = @_;
	my @destinations = @{$destinations_ar};
	my @output_array = @{$output_ar};
	my @path_builds;
	
	if (!(@destinations)){

		my @return_data;
		foreach my $output_path (@output_array){					
				my $name_path = '';
				my $full_info_name_path = '';
				my @destination = split '%',$output_path;
				while (@destination){
					my $step = shift @destination;
					my $old_step = $step;
					$step =~ s/^.*&//;
					$name_path = $name_path."|".$id2name{$step};
					$full_info_name_path = $full_info_name_path. "%".$old_step; ## ."&".$id2name{$step}
				}
		
				push @return_data,$full_info_name_path;
			}
		return @return_data;
	}
	else {
		## get path from entered array
		foreach my $destination (@destinations){
			# print "DESTINATION\:$destination\n";
			## get term at head of the path
			my ($parent) = split '%',$destination; #
			# my $discard;
			$parent =~ s/^.*&//; 
			# ($discard,$child) = split '\&',$child;
			# print "$child\n";
	  		my $children = $parent2ids{$parent}; # $parents = $id2parents{$child}
			if($children){ ## $parents
				## get parents
				# print "PARENTS\:$parents\n";
				my  @children = split '\|', $children; ## @parents = split $parents;
				foreach my $child (@children) { ## $parent @parents
					## append parent to the rest of the path
					# print "append $parent to $child\n";
					my $updated_path = $child.'%'.$destination; ## $parent
					push @path_builds, $updated_path;
					## load path into array
				}
				
			}
			else {
				# print "FOR OUTPUT\:$destination\n";
				push @output_array, $destination;
			}
		} ### end foreach my $destination (@destinations)
		
		### print paths
		## enter array into program recursively
		list_paths(\@path_builds,\@output_array);
	}

}






