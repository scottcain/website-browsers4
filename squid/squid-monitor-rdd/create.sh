#!/bin/sh

START=""

RRAS="
RRA:AVERAGE:0.99:1:288
RRA:AVERAGE:0.99:6:336
RRA:AVERAGE:0.99:12:744
RRA:AVERAGE:0.99:288:365
RRA:AVERAGE:0.99:2016:520
"


test -f connections.rrd || rrdtool create connections.rrd \
		$START \
		--step 300 \
		DS:http:DERIVE:600:0:U \
		DS:http_errors:DERIVE:600:0:U \
		DS:icp:DERIVE:600:0:U \
		DS:htcp:DERIVE:600:0:U \
		DS:snmp:DERIVE:600:0:U \
		$RRAS


test -f objects.rrd || rrdtool create objects.rrd \
		$START \
		--step 300 \
		DS:disk:GAUGE:600:U:U \
		DS:mem:GAUGE:600:U:U \
		$RRAS

test -f volume.rrd || rrdtool create volume.rrd \
		$START \
		--step 300 \
		DS:disk:GAUGE:600:U:U \
		DS:mem:GAUGE:600:U:U \
		$RRAS

test -f memory.rrd || rrdtool create memory.rrd \
		$START \
		--step 300 \
		DS:mallinfo:GAUGE:600:U:U \
		DS:accounted:GAUGE:600:U:U \
		DS:rss:GAUGE:600:U:U \
		DS:sbrk:GAUGE:600:U:U \
		$RRAS

test -f fd.rrd || rrdtool create fd.rrd \
		$START \
		--step 300 \
		DS:all:GAUGE:600:U:U \
		DS:store:GAUGE:600:U:U \
		$RRAS

test -f pagefaults.rrd || rrdtool create pagefaults.rrd \
		$START \
		--step 300 \
		DS:pf:DERIVE:600:0:U \
		$RRAS

test -f cpu.rrd || rrdtool create cpu.rrd \
		$START \
		--step 300 \
		DS:usage:GAUGE:600:U:U \
		$RRAS

test -f replacement.rrd || rrdtool create replacement.rrd \
		$START \
		--step 300 \
		DS:thresh:GAUGE:600:U:U \
		$RRAS

test -f svctime.rrd || rrdtool create svctime.rrd \
		$START \
		--step 300 \
		DS:http:GAUGE:600:U:U \
		DS:dns:GAUGE:600:U:U \
		DS:icp:GAUGE:600:U:U \
		DS:htcp:GAUGE:600:U:U \
		$RRAS

test -f hitratio.rrd || rrdtool create hitratio.rrd \
		$START \
		--step 300 \
		DS:count:GAUGE:600:U:99 \
		DS:volume:GAUGE:600:U:99 \
		$RRAS

test -f ip_proto.rrd || rrdtool create ip_proto.rrd \
		--step 300 \
		DS:icmpInMsgs:GAUGE:600:U:U \
		DS:icmpOutMsgs:GAUGE:600:U:U \
		DS:tcpInSegs:GAUGE:600:U:U \
		DS:tcpOutSegs:GAUGE:600:U:U \
		DS:udpInDatagrams:GAUGE:600:U:U \
		DS:udpOutDatagrams:GAUGE:600:U:U \
		$RRAS

test -f if_octets.rrd || rrdtool create if_octets.rrd \
		--step 300 \
		DS:in:GAUGE:600:U:U \
		DS:out:GAUGE:600:U:U \
		$RRAS

test -f diskd.rrd || rrdtool create diskd.rrd \
		--step 300 \
		DS:max_away:GAUGE:600:U:U \
		DS:max_shmuse:GAUGE:600:U:U \
		DS:open_fail_queue_len:DERIVE:600:0:U \
		DS:block_queue_len:DERIVE:600:0:U \
		$RRAS

test -f store_io.rrd || rrdtool create store_io.rrd \
		--step 300 \
		DS:create_calls:DERIVE:600:0:U \
		DS:create_select_fail:DERIVE:600:0:U \
		DS:create_create_fail:DERIVE:600:0:U \
		DS:create_success:DERIVE:600:0:U \
		$RRAS

test -f mempool.rrd || rrdtool create mempool.rrd \
		--step 300 \
		DS:alloc:DERIVE:600:0:U \
		DS:free:DERIVE:600:0:U \
		$RRAS

test -f disk_pct_theoretical.rrd || rrdtool create disk_pct_theoretical.rrd \
		--step 300 \
		DS:d0:GAUGE:600:0:100 \
		DS:d1:GAUGE:600:0:100 \
		DS:d2:GAUGE:600:0:100 \
		DS:d3:GAUGE:600:0:100 \
		DS:d4:GAUGE:600:0:100 \
		DS:d5:GAUGE:600:0:100 \
		DS:d6:GAUGE:600:0:100 \
		DS:d7:GAUGE:600:0:100 \
		DS:d8:GAUGE:600:0:100 \
		DS:d9:GAUGE:600:0:100 \
		$RRAS

test -f disk_pct_actual.rrd || rrdtool create disk_pct_actual.rrd \
		--step 300 \
		DS:d0:GAUGE:600:0:100 \
		DS:d1:GAUGE:600:0:100 \
		DS:d2:GAUGE:600:0:100 \
		DS:d3:GAUGE:600:0:100 \
		DS:d4:GAUGE:600:0:100 \
		DS:d5:GAUGE:600:0:100 \
		DS:d6:GAUGE:600:0:100 \
		DS:d7:GAUGE:600:0:100 \
		DS:d8:GAUGE:600:0:100 \
		DS:d9:GAUGE:600:0:100 \
		$RRAS

test -f select.rrd || rrdtool create select.rrd \
		--step 300 \
		DS:sl:GAUGE:600:0:U \
		DS:sf:GAUGE:600:0:U \
		DS:asfp:GAUGE:600:0:U \
		DS:msf:GAUGE:600:0:U \
		$RRAS

chmod 644 *.rrd
