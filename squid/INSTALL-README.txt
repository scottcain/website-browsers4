This document describes how to build and configure the primary front end caching server (fe.wormbase.org) at WormBase.  This server runs the squid software as a reverse proxy.

== Building the primary front end server (fe.wormbase.org) ==

The primary front end server was configured as follows:

1. Set up /etc/hosts

 # roundrobin.wormbase.org is a pseudo-host where all redirection
 # requests are sent. This corresponds to localhost.
 143.48.220.124          fe.wormbase.org fe
 143.48.220.124         roundrobin.wormbase.org
 143.48.220.84           dev.wormbase.org
 143.48.220.56           vab.wormbase.org
 143.48.220.86           unc.wormbase.org
 143.48.220.41           blast.wormbase.org
 143.48.220.84           brie3.cshl.org
 143.48.220.28           aceserver.cshl.org 
 143.48.220.99           gene.wormbase.org

2. cvs checkout the wormbase-admin module

This module contains squid configuration files.

 fe> sudo mkdir /usr/local/wormbase-admin
 fe> sudo chgrp wormbase /usr/local/wormbase-admin
 fe> sudo chmod 2775 wormbase-admin
 fe> cd /usr/local/wormbase-admin
 fe> cvs checkout wormbase-admin
 fe> mv wormbase-admin/* . ; rm -rf wormbase-admin

3. Build and install squid

*Pretuning the kernel

The server running squid must be able to handle a large number of open file handles.  1024 may be sufficient but more may be required for very active caches.  Most modern operating systems should already support a sufficient number of file handles .  You can check this by:

  % ulimit -n

*Fetching the Squid source

Fetch the current squid source from www.squidcache.org.  As of 8/2005, WormBase is using squid.2.5 STABLE10.  Version 3 of squid is on the horizon and may offer interesting options for the WormBase site.

*Patching Squid to enable httpd style logging

Although squid 2.x has an option to emulate httpd style logging, these entries do not include referer or user-agent (which end up logged to separate files).  To create true httpd style logs, patch the squid source with the customlog patch:

   $ cd squid-stable/
   $ wget "http://devel.squid-cache.org/cgi-bin/diff2/customlog-2_5.patch?s2_5" -O customlog-2.5.patch
   $ patch -p1 < customlog-2.5.patch

Increase the size of MAX_URL to 16384 bytes:
  emacs src/defines.h
  #define MAX_URL 16384

*./configure options and compilation

Squid supports a large number of options during configuration.  The squid server at WormBase is configured with the following options:

 --prefix=/usr/local/squid

Defaults to /usr/local/squid - this is provided just for completeness.

 --enable-removal-policies=heap,lru

This directive enables multiple algorithms for handling removal of entries from the cache.  We will typically use LRU but providing this directive during configuration opens up other options which can be enabled in squid.conf at a later date.

 --enable-icmp

Enables round-trip measurements of cache requests. Techincally not required.

 --enable-delay-pools

This directive enables delay pools which can be used to throttle spiders and programmatic users. Currently not in use.

 --enable-useragent-log

Enable logging of HTTP user agent.  This can be enabled/disabled in the configuration file after compilation.

 --enable-referer-log

Enable logging of cache referer. Logging can be enabled/disabled in the configuration file after compilation.

 --disable-wccp

Turn off the optional WCCP code.

 --enable-snmp

Enable code that allows SNMP queries of the health of the cache.

 --enable-cachemgr-hostname=[hostname]

Enable the cache manager CGI with a specific hostname.

 --disable-internal-dns

Turn off Squid's internal DNS lookup protocol. Currently, we rely on Squid to fetch hostname entries from /etc/hosts.  This is faster than relying on DNS.

The following options may be useful in the future but are not currently used.

 --localstatedir=DIR

This flag controls the destination of the squid var/ directory which holds the squid cache and logs. It may be useful to place the var/ directory on a seperate disk from that powering the website databases.

 --sysconfdir=DIR

This directive specifies where to place the etc/ directory.  This may be useful if, for example, we want to store the config files in the the WormBase CVS repository.

--enable-carp

This enables forwarding of cache misses to other caches. Not sure of its usage at this point.

 --enable-htcp

HTCP is an alternative to ICP inter-cache communications.

 --enable-cache-digests

Cache digests are another alternative to ICP with a slightly different structure. The current configure command looks like this:

  % ./configure --prefix=/usr/local/squid-VERSION \
                --enable-removal-policies=heap,lru \
                --enable-icmp \
                --enable-delay-pools \
                --enable-useragent-log \
                --enable-referer-log \
                --disable-wccp \
                --enable-snmp \
                --enable-cachemgr-hostname=www.wormbase.org \
                --disable-internal-dns

To run config at a later date with the same parameters:

  % ./config.status --recheck
  % make
  % sudo make install

Set up an appropirate symlink:
 
  % cd /usr/local
  % sudo rm squid; ln -s squid-VERSION squid


== Preparing the system to run a squid server ==

#Creating users and groups

Since squid will need to listen to ports less than 1000, it needs to be run with root privileges.  Squid, however, should not be run as root.  Instead, create a squid user and group.

 $ sudo /usr/sbin/useradd squid -d /usr/local/squid

In the squid.conf file, you will set parameters that tell squid to run as the quid user/group.  See the "cache_effective_user" and "cache_effective_group" config file options described below.

#Fix directory permissions

Directory permissions should be secured as follows.

  Path                  owner:group   octal
  /usr/local/squid      root:root     775
  /usr/local/squid/bin  root:root     775
  /usr/local/squid/etc  root:squid    2775
  /usr/local/squid/var	squid:squid   2775

== Configuring Squid: the squid.conf file ==

Squid accepts an enormous number of configuration options many of which influence the behavior of other options.  These are housed in
the squid config file kept under CVS control:

 /usr/local/wormbase-admin/squid/etc/squid.conf.

Those that are most important for our configuration are described here.  See the squid.conf for a full description of all options in use at WormBase.

 http_port 80

The IP address and port where the squid server will listen for http requests.  This corresponds to the address of fe.wormbase.org:

 http_port 143.48.220.124:80

 cache_effective_user, cache_effective_group

Squid needs to run as the squid user and group. To control this, set the two following options:

  cache_effective_user  squid
  cache_effective_group squid

The following options specify which host and port to forward requests. It is sufficient for each squid server to point to the localhost in
our configuration.

 httpd_accel_host, httpd_accel_port

httpd_accel_host is where all requests are sent. Since we are accelerating multiple hosts, we set this value to an arbitrary hostname, mapped to localhost in /etc/hosts.  The load balancing redirector scripts will receive requests for this domain.  The httpd_accel_port option specifies to the port that the accel host is listening on.

  httpd_accel_host    roundrobin.wormbase.org
  httpd_accel_port    80

 redirect_program

A program that rewrites URLs, sending requests to the appropriate origin server.  Currently, WormBase uses a script which sends GBrowse requests to vab and all other requests to unc:

 redirect_program /usr/local/wormbase-admin/squid/redirectors/separate_gbrowse_acedb.pl

See this script for additional details of its use.

 refresh_pattern

The refresh_patern directive specifies how to handle pages lacking appropriate expire and last-modified headers.  At WormBase, this includes dynamic content.  To ensure that such pages are cached, we use the following setting.

  refresh_pattern -i db 10000 100% 30000

(The options ignore-reload override-expire override-lastmod may also be useful but are not strictly required)

  refresh_pattern -i db 10000 100% 30000 ignore-reload override-expire override-lastmod

Squid creates a number of useful (and some useless logs). Since Squid is handling all requests for WormBase, it is our primary source of logging information. The following directives control the logging behavior of squid.

 cache_store_log

The cache.store log is particularly useless as it just contains a log of all object names cached.  To turn it off, specify

  cache_store_log  none

 httpd style logs

To create httpd style logs, we rely on two new directives provided by the customlog patch.  Note that the squid logs will now be our primary source of logging information as the primary httpd logs will only contain squid accessions.  We have squid place these logs within the primary WormBase logging directory. 

Add the following lines to the squid.conf file to emulate WormBase / httpd style logs (these directives are made available through the custom_log patch): 

  logformat combined %>a %ui %un [%tl] %{Referer}>h "%{User-Agent}>h" "%rm %ru HTTP/%rv" %Hs %<st %Ss:%Sh  
  access_log /usr/local/squid/logs/access_log combined

 *** Make sure that this squid directory exists and is writable by
 *** squid. Squid will exit if it cannot write to its logs!

With these directives safely in place, we can now safely turn off squids primary access log:

 cache_access_log  none
 emulate_httpd_log off   // Rather reduandant

Access control lists (ACLs) are directives that specify hosts, destinations, URLs, etc for which specific actions should be taken. ACLs are associated with rules that specify when the ACL should be tested.  A brief description of some of the ACLs (and their
associated rules) currently in use at WormBase follows.

 no_cache

The no_cache directive specifies which URLs should NOT be cached. We use the following ACLs to prevent caching of specific items at the WormBase site.

 acl GBROWSE urlpath_regex -i /db/seq/gbrowse/
 acl news     url_regex -i rss
 acl feedback url_regex -i feedback
 acl Bugzilla url_regex -i bug

 no_cache deny GBROWSE
 no_cache deny bugzilla
 no_cache deny news     // RSS feeds can probably be safely cached
 no_cache deny feedback // Feedback form (caching results in odd behaviors)

 http_access

It is also critical to control what requests can pass through the proxy (and what destination URLs are tolerated).  Without these directives, the proxy would serve any request to any remote site.  We define the following ACLs:

 acl all src 0.0.0.0/0.0.0.0
 acl localhost src 127.0.0.1/255.255.255.255
 acl to_localhost dst 127.0.0.0/255.255.255.255

 # LOAD BALANCING - each of the backend servers must be listed here
 acl vab      dst 143.48.220.56/255.255.255.255
 acl blast    dst 143.48.220.41/255.255.255.255
 acl unc      dst 143.48.220.86/255.255.255.255
 acl from_unc src 143.48.220.86/255.255.255.255 // cachemgr requests
 acl server_pool dst 143.48.220.86/32 143.48.220.56/32 143.48.220.41/32

 # The public facing host - destination
 acl from_proxy_host dst 143.48.220.124/255.255.255.255
 acl proxy_host dst 143.48.220.124/255.255.255.255
 acl proxy_port port 80
 acl PURGE method purge

 # only allow access to cache
 # manager from th and localhost
 acl CacheManager proto cache_object
 acl ToddAtHome src 24.10.175.230/255.255.255.255

Finally, apply these ACLs using the http_access rule:

 # Allow access to the localhost
 http_access allow proxy_host
 http_access allow localhost
 http_access allow CacheManager localhost
 http_access allow CacheManager from_proxy_host
 http_access deny CacheManager

 # Allow cache purging from the localhost only
 http_access allow purge localhost
 http_access deny purge

 # Specifically allow access to our backend servers
 # This is all handled below by a single directive....
 # http_access allow vab
 # http_access allow unc

 # http_access deny !server_pool

 # And finally deny all other access except for requests
 # directed towards this proxy
 http_access deny !proxy_host
 http_access deny !proxy_port
 http_access allow all

After making changes to your configuration file, it is a good idea to check its syntax.

 fe> squid -k parse

== Starting and stopping squid ==

Before we can test squid, we need to initialize the cache hierarchy of nested directories.  The "-z" option in the following command does this.  It needs to be issued only the first time that squid is started (or anytime the cache needs to be reset).

 fe> sudo /usr/local/squid/sbin/squid -z \
    -f /usr/local/wormbase-admin/squid/etc/squid.conf

To test the squid installation, invoke it like this:

 fe> sudo /usr/local/squid/sbin/squid -N -d 1 -D -z -f \
     /usr/local/wormbase-admin/squid/etc/squid.conf

We want to be able to see that Squid is doing something useful, so we increase the debug level (using -d 1) and tell it not to go into the background (using -N.) If your machine is not connected to the Internet (you are doing a trial squid-install on your home machine, for example) you should use the -D flag too, since Squid tries to do DNS lookups for a few common domains, and dies with an error if it is not able to resolve them.

Now try connecting to the squid server:

 fe> squidclient http://www.wormbase.org/

You can stop squid by issuing

 fe> squid -k shutdown

If the pid file is missing, find the pid for the primary squid provess and kill it by

 fe> kill -TERM [PID]

Check the cache.log file to confirm that squid has shut down.

== Launching squid at system startup ==

We want squid to launch as a daemon in the background whenever the system boots. A suitable init.d script exists at

  /usr/local/wormbase-admin/suiqd/util/squid.initd

Copy this file to /etc/init.d/squid. You can thus launch squid by:

 fe> sudo /etc/init.d/squid start

See the separate document "wormbase_administration.pod" for additional details or execute the following command:

 fe> sudo /etc/rc.d/init.d/squid help

== Building back end (origin) servers ==

For a general overview on how to build a satellite server, see HOWTO-build_a_mirror.pod.

== Appendix: Glossary ==

'''reverse proxy server'''

A server that intercepts requests for a primary web server and then does interesting things (such as caching or load balancing of responses). Reverse proxy servers are also referred to as surrogate servers.  WormBase uses the open-source proxy server Squid.

'''origin server'''

A webserver such as apache that resides behind a reverse proxy server.

'''HTTP acceleration'''

The process of caching web pages generated by an origin server on disk or in memory to accelerate future requests for that resource.

== See Also ==

[[WormBase Infrastructure]]

== Author ==

Author: --[[User:Tharris|Tharris]] 13:03, 10 February 2006 (EST) (harris@cshl.org)

Copyright @ 2004-2006 Cold Spring Harbor Laboratory






Squid 3.0

cd ~/src
wget http://www.squid-cache.org/Versions/v3/3.1/squid-3.1.1.tar.gz
tar xzf squid-3.1.1.tar.gz
cd squid-3.1.1
./configure --prefix=/usr/local/squid-3.1.1 \
            --enable-removal-policies=heap,lru \
            --enable-icmp \
            --enable-delay-pools \
            --enable-useragent-log \
            --enable-referer-log \
            --enable-ssl \
            --disable-wccp \
            --enable-snmp \
            --enable-cachemgr-hostname=www.wormbase.org

sudo make install

This will install squid into

  /usr/local/squid-3.1.1


Fix permissions
----------------
cd /usr/local/squid-3.0.STABLE1
sudo chown -R squid:squid var logs
cd /usr/local
sudo rm squid // if symlink
sudo ln -s squid-3.0.STABLE1 squid

Initialize the cache
---------------------

sudo /usr/local/squid-3.0.STABLE1/sbin/squid -N -d 9 -z -f \
/home/todd/projects/wormbase/admin/conf/squid/squid-3.0.STABLE1/squid.conf


Start squid
------------
sudo /usr/local/squid-3.0.STABLE1/sbin/squid -N -d 9 -f
/home/todd/projects/wormbase/admin/conf/squid/squid-3.0.STABLE1/squid.conf

Add the -X flag to enable full debugging.

Debugging ACLs:
debug_options ALL,1 33,2
