#!/usr/bin/perl

# This script emails various statistics on squid each morning to those
# listed in the TO constant.  It should be run from cron on
# fe.wormbase.org.

# Run this as a crontab so I can get stats mailed to me directly each AM
# * 5 * * * * /usr/local/website-admin/monitoring/email_squid_status.pl

use strict;
use LWP::UserAgent;
use Bio::GMOD::Util::Email;

use constant TO        => 'cron@tharris.org';
use constant FROM      => 'Squid Monitor <cron@tharris.org>';
use constant HTTP_ROOT => 'http://localhost:81/squid-monitor/';
use constant IMAGE_ROOT => '/usr/local/apache/htdocs/squid-monitor';

# Interval should be one of hour, 6hours, day, week
my $interval = shift;
$interval or die "Please provide an interval to display: hour, 6hours, day, week\n";
my $SUBJECT = "Squid status: past $interval";

# Touch the various scripts so that RRDTool can refresh the images
my %intervals2scripts = (day  => '1day.cgi',
			  hour => '1hour.cgi',
			  hours => '6hours.cgi',
			  week  => '1week.cgi');

my @images  = ('connections.%s.png',
	       'cpu.%s.png',
	       'fd.%s.png',
	       'hitratio.%s.png',
	       'objects.%s.png',
	       'svctime.%s.png');

my $ua      = LWP::UserAgent->new();
$ua->agent("Squid Status/0.1");
my $uri = HTTP_ROOT . $intervals2scripts{$interval};
my $request = HTTP::Request->new('GET',$uri);
my $response = $ua->request($request);

die unless ($response->is_success);

my %attachments;
foreach my $base (@images) {
  my $image = sprintf($base,$interval);
  $attachments{IMAGE_ROOT . '/' . $image} = 'image/png';
}

my $date = `date '+%Y %h %d %H:%M'`;
chomp $date;
my $content = <<END;
Squid status report (past $interval): $date

END


Bio::GMOD::Util::Email->send_email(-to      =>[TO],
				   -from    => FROM,
				   -subject => $SUBJECT,
				   -content => $content,
				   -attachments => \%attachments);

exit;



