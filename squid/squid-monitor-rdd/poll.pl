#!/usr/bin/perl
#
# may want to remove -w if IO::Socket::INET warnings become too annoying
#
# usage: poll.pl host:port ...
#	       localhost:3128 # cache server
#	       localhost:80   # accelerator
# Originally at:
#   http://wessels.squid-cache.org/squid-rrd/
# Rewritten by Dan Kogai <dankogai@dan.co.jp>
# Rewritten by Duane Wessels <wessels@squid-cache.org>
# poll.pl,v 1.9 2004/03/30 18:55:27 wessels Exp
#

use strict;
use vars qw($DEBUG); $DEBUG = 1; # for 5.005 compat
use Fcntl;
use IO::Socket;
use Data::Dumper;

my $RRDS = init();
my %Vals;
my $cache = shift || die "usage: $0 host:port\n";
my $when = time;
my $root = '/usr/local/apache/htdocs/squid-monitor';

delete @ENV{qw/IFS CDPATH ENV BASH_ENV PATH/};
my $rrdtool = '/usr/local/rrd/bin/rrdtool';
$|=1;

#my ($dir) = ($0 =~ m,^(.*)/,o);
#$dir ||= '.';
#chdir $dir;

cachemgr_info();
cachemgr_counters();
cachemgr_5min();
cachemgr_diskd();
cachemgr_store_io();
cachemgr_storedir();

foreach my $rrd (keys %$RRDS) {
	rrd_update($rrd);
}

sub cachemgr_info {
     foreach (ask_squid($cache, 'info')) {
	$DEBUG>2 and warn $_;
	$Vals{disksize} = $1 if (/Storage Swap size:\s+([-0-9\.]+)\s+MB/);
	$Vals{disksize} = $1 / 1024 if (/Storage Swap size:\s+([-0-9\.]+)\s+KB/);
	$Vals{memsize}  = $1 if (/Storage Mem size:\s+([-0-9\.]+)\s+KB/);
	$Vals{numfd}    = $1 if (/Largest file desc currently in use:\s+(\d+)/);
	$Vals{numfd}    = $1 if (/Number of file desc currently in use:\s+(\d+)/);
	$Vals{storefd}  = $1 if (/Store Disk files open:\s+(\d+)/);
	$Vals{vm1}      = $1 / 1024 if (/Total Accounted ([-0-9\.]+) KB/);
	$Vals{vm1}      = $1 / 1024 if (/Total Accounted\s+=\s+([-0-9\.]+) KB/);
	$Vals{vm1}      = $1 / 1024 if (/Total accounted:\s+([-0-9\.]+) KB/);
	$Vals{vm2}      = $1 / 1024 if (/Total space in arena:\s+([-0-9\.]+) KB/i);
	$Vals{vm3}	= $1 / 1024 if (/Maximum Resident Size:\s+([-0-9\.]+) KB/i);
	$Vals{vm4}	= $1 / 1024 if (/Process Data Segment Size via sbrk\(\):\s+([-0-9\.]+) KB/i);
	$Vals{nconn}    = $1 if (/Number of connections:\s+(\d+)/);
	$Vals{nconn}    = $1 if (/Number of TCP connections:\s+(\d+)/);
	$Vals{nconn}    = $1 if (/Number of HTTP requests received:\s+(\d+)/);
	$Vals{nuconn}   = $1 if (/Number of UDP connections:\s+(\d+)/);
	$Vals{nuconn}   = $1 if (/Number of ICP messages received:\s+(\d+)/);
	$Vals{nobj}     = $1 if (/StoreEntry\s+\d+\s+x\s+(\d+)}/);
	$Vals{nobj}     = $1 if (/StoreEntry\s+(\d+)\s+x\s+\d+ bytes/);
	$Vals{nobj}     = $1 if (/(\d+) StoreEntries$/);
	$Vals{pfaults}  = $1 if (/Page faults with physical i\/o:\s+(\d+)/);
	$Vals{cpu_use}  = $1 if (/CPU Usage:\s+([-0-9\.]+)/i);
	$Vals{cpu_use}  = $1 if (/CPU Usage, 5 minute avg:\s+([-0-9\.]+)/i);
	$Vals{cpu_use}  = $1 if (/CPU Usage, 60 minute avg:\s+([-0-9\.]+)/i);
	$Vals{nhot}     = $1 if (/(\d+)\s+Hot Object Cache Items/i);
	$Vals{lruage}   = $1 if (/Storage LRU Expiration Age:\s+(\S+)/i);
	$Vals{lruage}   = $1 if (/Storage Replacement Threshold:\s+(\S+)/i);
	$Vals{dns_t}    = $2 if (/DNS Lookups:\s+(\S+)\s+(\S+)/);
	$Vals{svc_t}    = $2 if (/HTTP Requests \(All\):\s+(\S+)\s+(\S+)/);
	$Vals{hr}       = $2 if (/Request Hit Ratios:\s+5min:\s+([^%]+)%,\s+60min:\s+([^%]+)%/);
        $Vals{hr}       = $2 if (/Hits as % of all requests:\s+5min:\s+([^%]+)%,\s+60min:\s+([^%]+)%/);
	$Vals{bhr}      = $2 if (/Byte Hit Ratios:\s+5min:\s+([^%]+)%,\s+60min:\s+([^%]+)%/);
        $Vals{bhr}      = $2 if (/Hits as % of bytes sent:\s+5min:\s+([^%]+)%,\s+60min:\s+([^%]+)%/);
	$Vals{mpac}     = $1 if (/memPoolAlloc calls: (\d+)/);
	$Vals{mpfc}     = $1 if (/memPoolFree calls: (\d+)/);
     }
     $Vals{vm2} = 0  unless (defined($Vals{vm2}) && $Vals{vm2} > 0 && $Vals{vm2} < 2000000);
     $Vals{cpu_use} = 0 if ($Vals{cpu_use} < 0);
#    warn $Vals{hr};
#    warn $Vals{bhr};
#    die;
}

sub cachemgr_counters {
     for (ask_squid($cache, 'counters')) {
	$DEBUG>2 and warn $_;
	$Vals{client_http_errors} = $1 if (/client_http\.errors = (\d+)/);
     }
}

sub cachemgr_diskd {
     for (ask_squid($cache, 'diskd')) {
	$DEBUG>2 and warn $_;
	$Vals{max_away}	= $1 if (/max_away: (\d+)/);
	$Vals{max_shmuse}	= $1 if (/max_shmuse: (\d+)/);
	$Vals{open_fail_queue_len} = $1 if (/open_fail_queue_len: (\d+)/);
	$Vals{block_queue_len} = $1 if (/block_queue_len: (\d+)/);
     }
}

sub cachemgr_store_io {
     for (ask_squid($cache, 'store_io')) {
	$DEBUG>2 and warn $_;
	$Vals{create_calls}	= $1 if (/create.calls (\d+)/);
	$Vals{create_select_fail} = $1 if (/create.select_fail (\d+)/);
	$Vals{create_create_fail} = $1 if (/create.create_fail (\d+)/);
	$Vals{create_success}	= $1 if (/create.success (\d+)/);
     }
}

sub cachemgr_storedir {
     my $idx;
     for (ask_squid($cache, 'storedir')) {
	$DEBUG>2 and warn $_;
	$idx				= $1 if (/Store Directory #(\d+)/);
	$Vals{"disk_theoretical_$idx"}  = $1 if (/Percent Used: ([\d\.]+)%/);
	$Vals{"disk_actual_$idx"}	= 100*$1/$2 if (/Filesystem Space in use: (\d+)\/(\d+) KB/);
     }
}

sub cachemgr_5min {
     for (ask_squid($cache, '5min')) {
	$DEBUG>2 and warn $_;
	$Vals{select_loops}		= $1 if (/^select_loops = ([0-9\.]+)/);
	$Vals{select_fds}		= $1 if (/^select_fds = ([0-9\.]+)/);
	$Vals{average_select_fd_period} = $1 if (/^average_select_fd_period = ([0-9\.]+)/);
	$Vals{median_select_fds}	= $1 if (/^median_select_fds = ([0-9\.]+)/);
     }
}

sub ask_squid($$) {
	my $host = shift;
	my $what = shift;
        print STDERR "WHAT: $what\n\n";

	my $port ||= 3128; # squid's default
	my $sock;
	$host =~ s/:(\d+)$//o and $port = $1;
	$host =~ m/^([\w\.:]+)$/o and $host = $1; # untaint
	$DEBUG>1 and print STDERR "connecting to host=[$host] port=[$port]";
	$sock = IO::Socket::INET->new(PeerAddr => scalar($host),
				 PeerPort => $port,
				 Proto    => 'tcp') or
	$sock = IO::Socket::INET->new(PeerAddr => scalar($host),
				 PeerPort => $port,
				 Proto    => 'tcp') or
	die("$host:$port: $!");
	$sock->autoflush(1);
	$DEBUG>1 and print STDERR "GET cache_object://$host/$what HTTP/1.0\n";
	print $sock "GET cache_object://$host/$what HTTP/1.0\n\n";
	my @result = <$sock>;
	print STDERR join("\n",@result);
	close $sock;
	return wantarray ? @result : join('' => @result);
}

sub rrd_update {
	my $rrd = shift;
	my $file = "$rrd.rrd";
	my $tmpl = format_template($rrd);
	my $nums = format_values($rrd);
	my @cmd = ($rrdtool, 'update', "$root/$rrd.rrd", '--template', $tmpl, $nums);
	$DEBUG and print join(" " => @cmd);
	system @cmd;
}

sub format_template {
        my $rrd = shift;
        my $x = $RRDS->{$rrd}->{DS};
        join(':', keys %$x);
}

sub format_values {
        my $rrd = shift; 
        my $x = $RRDS->{$rrd}->{DS};
        my @y;
        foreach my $k (keys %$x) {
		my $v;
		if (defined($x->{$k}->{valkey})) {
			$v = $Vals{$x->{$k}->{valkey}};
		} else {
			$v = $Vals{$k};
		}
		if (defined($v)) {
			push(@y, sprintf($x->{$k}->{format}, $v));
		} else {
			push(@y, 'U');
		}
#	if ($k eq 'volume') {
#        print $v,"\n";
#	print join(" ",@y),"\n";
#	die;
#}

        }
        join(':', $when, @y);
}

sub init
{
	my $RRDS = {
		'connections-old' => {
			DS => {
				http => { format => '%d', type => 'DERIVE', valkey => 'nconn', },
				icp => { format => '%d', type => 'DERIVE', valkey => 'nuconn', },
				htcp => { format => '%d', type => 'DERIVE', valkey => 'zero', },
				snmp => { format => '%d', type => 'DERIVE', valkey => 'client_http_errors', },
			}
		},
		connections => {
			DS => {
				http => { format => '%d', type => 'DERIVE', valkey => 'nconn', },
				http_errors => { format => '%d', type => 'DERIVE', valkey => 'client_http_errors', },
				icp => { format => '%d', type => 'DERIVE', valkey => 'nuconn', },
				htcp => { format => '%d', type => 'DERIVE', valkey => 'zero', },
				snmp => { format => '%d', type => 'DERIVE', valkey => 'zero', },
			}
		},
		objects => {
			DS => {
				disk => { format => '%d', type => 'GAUGE', valkey => 'nobj', },
				mem => { format => '%d', type => 'GAUGE', valkey => 'nhot', },
			}
		},
		volume => {
			DS => {
				disk => { format => '%d', type => 'GAUGE', valkey => 'disksize', },
				mem => { format => '%d', type => 'GAUGE', valkey => 'zero', },
			}
		},
		memory => {
			DS => {
				mallinfo => { format => '%f', type => 'GAUGE', valkey => 'vm2', },
				accounted => { format => '%f', type => 'GAUGE', valkey => 'vm1', },
				rss => { format => '%f', type => 'GAUGE', valkey => 'vm3', },
				sbrk => { format => '%f', type => 'GAUGE', valkey => 'vm4', },
			}
		},
		fd => {
			DS => {
				all => { format => '%d', type => 'GAUGE', valkey => 'numfd', },
				store => { format => '%d', type => 'GAUGE', valkey => 'storefd', },
			}
		},
		'pagefaults-old' => {
			DS => {
				pf => { format => '%d', type => 'COUNTER', valkey => 'pfaults', },
			}
		},
		pagefaults => {
			DS => {
				pf => { format => '%d', type => 'DERIVE', valkey => 'pfaults', },
			}
		},
		cpu => {
			DS => {
				usage => { format => '%f', type => 'GAUGE', valkey => 'cpu_use', },
			}
		},
		replacement => {
			DS => {
				thresh => { format => '%f', type => 'GAUGE', valkey => 'lruage', },
			}
		},
		svctime => {
			DS => {
				http => { format => '%f', type => 'GAUGE', valkey => 'svc_t', },
				dns => { format => '%f', type => 'GAUGE', valkey => 'dns_t', },
				icp => { format => '%f', type => 'GAUGE', valkey => 'zero', },
				htcp => { format => '%f', type => 'GAUGE', valkey => 'zero', },
			}
		},
		hitratio => {
			DS => {
				count => { format => '%f', type => 'GAUGE', valkey => 'hr', },
				volume => { format => '%f', type => 'GAUGE', valkey => 'bhr', },
			}
		},
		'diskd-old' => {
			DS => {
				max_away => { format => '%d', type => 'GAUGE', },
				max_shmuse => { format => '%d', type => 'GAUGE', },
				open_fail_queue_len => { format => '%d', type => 'DERIVE', },
				block_queue_len => { format => '%d', type => 'DERIVE', },
			}
		},
		diskd => {
			DS => {
				max_away => { format => '%d', type => 'GAUGE', },
				max_shmuse => { format => '%d', type => 'GAUGE', },
				open_fail_queue_len => { format => '%d', type => 'DERIVE', },
				block_queue_len => { format => '%d', type => 'DERIVE', },
			}
		},
		select => {
			DS => {
				sl => { format => '%f', type => 'GAUGE', valkey => 'select_loops', },
				sf => { format => '%f', type => 'GAUGE', valkey => 'select_fds', },
				asfp => { format => '%f', type => 'GAUGE', valkey => 'average_select_fd_period', },
				msf => { format => '%f', type => 'GAUGE', valkey => 'median_select_fds', },
			}
		},
       	store_io => {
			DS => {
				create_calls => { format => '%d', type => 'GAUGE' },
				create_select_fail => { format => '%d', type => 'GAUGE' },
				create_create_fail => { format => '%d', type => 'GAUGE' },
				create_success => { format => '%d', type => 'GAUGE' }
			}
		},
		'mempool-old' => {
			DS => {
				alloc => { format => '%d', type => 'COUNTER', valkey => 'mpac', },
				free=> { format => '%d', type => 'COUNTER', valkey => 'mpfc', },
			}
		},
		mempool => {
			DS => {
				alloc => { format => '%d', type => 'DERIVE', valkey => 'mpac', },
				free=> { format => '%d', type => 'DERIVE', valkey => 'mpfc', },
			}
		},
		disk_pct_theoretical => {
			DS => {
				d0 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_0', },
				d1 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_1', },
				d2 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_2', },
				d3 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_3', },
				d4 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_4', },
				d5 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_5', },
				d6 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_6', },
				d7 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_7', },
				d8 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_8', },
				d9 => { format => '%f', type => 'GAUGE', valkey => 'disk_theoretical_9', },
			}
		},
		disk_pct_actual => {
			DS => {
				d0 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_0', },
				d1 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_1', },
				d2 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_2', },
				d3 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_3', },
				d4 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_4', },
				d5 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_5', },
				d6 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_6', },
				d7 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_7', },
				d8 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_8', },
				d9 => { format => '%f', type => 'GAUGE', valkey => 'disk_actual_9', },
			}
		},
##		blank => {
##			DS => {
##				blank => {
##					format => '%d',
##					type => 'GAUGE',
##					valkey => 'zero',
##				},
##			}
##		},
	};
}
