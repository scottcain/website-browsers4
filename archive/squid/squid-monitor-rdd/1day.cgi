#!/usr/local/rrd/bin/rrdcgi
<HTML>
<HEAD>
<TITLE>Squid Stats</TITLE>
<META HTTP-EQUIV="Refresh" CONTENT="150">
</HEAD>
<BODY>

<RRD::GRAPH svctime.day.png --title="Service Time -- 1day"
        --start -1day
	--upper-limit 0.5
        --imgformat PNG
        --vertical-label "seconds"
        --width 300 --height 150
        DEF:http=svctime.rrd:http:AVERAGE
        DEF:dns=svctime.rrd:dns:AVERAGE
        AREA:http#0000FF:HTTP
        AREA:dns#00FF00:DNS
        >

<RRD::GRAPH connections.day.png --title="Connections -- 1day"
        --start -1day
        --imgformat PNG
        --vertical-label "req/sec"
        --width 300 --height 150
        DEF:http=connections.rrd:http:AVERAGE
        AREA:http#0000FF:HTTP
        >

<RRD::GRAPH objects.day.png --title="Cached Objects -- 1day"
        --start -1day
        --imgformat PNG
        --vertical-label "count"
        --width 300 --height 150
        DEF:disk=objects.rrd:disk:AVERAGE
        DEF:mem=objects.rrd:mem:AVERAGE
        AREA:disk#0000FF:Disk
        LINE2:mem#00FF00:Memory
        >

<RRD::GRAPH fd.day.png --title="File Descriptors -- 1day"
        --start -1day
        --imgformat PNG
        --vertical-label "count"
        --width 300 --height 150
        DEF:all=fd.rrd:all:AVERAGE
        DEF:store=fd.rrd:store:AVERAGE
        AREA:all#0000FF:All
        AREA:store#7FFF7F:Store
        >

<RRD::GRAPH hitratio.day.png --title="Hit Ratio -- 1day"
        --start -1day
        --imgformat PNG
        --vertical-label "Percent"
        --width 300 --height 150
        DEF:count=hitratio.rrd:count:AVERAGE
        DEF:volume=hitratio.rrd:volume:AVERAGE
        AREA:count#0000FF:Request
        LINE2:volume#7FFF7F:Volume
        >

<RRD::GRAPH cpu.day.png --title="CPU Usage -- 1day"
        --start -1day
        --imgformat PNG
        --vertical-label "Percent"
        --width 300 --height 150
        DEF:usage=cpu.rrd:usage:AVERAGE
        AREA:usage#FF0000:Usage
        >

<!--
RRD::GRAPH memory.day.png --title="Memory -- 1day"
        --start -1day
        --imgformat PNG
        --vertical-label "Megabytes"
        --width 300 --height 150
        DEF:mallinfo=memory.rrd:mallinfo:AVERAGE
        DEF:accounted=memory.rrd:accounted:AVERAGE
        DEF:rss=memory.rrd:rss:AVERAGE
        DEF:sbrk=memory.rrd:sbrk:AVERAGE
        AREA:rss#FFFF00:MaxRSS  
        AREA:accounted#FF7F7F:Accounted
        LINE2:sbrk#0000FF:sbrk
        LINE2:mallinfo#00FF00:Mallinfo
-->
<!--
RRD::GRAPH select.day.png --title="Select Stats -- 1day"
        --start -1day
        --imgformat PNG
        --vertical-label "rate"
        --width 300 --height 150
        DEF:sl=select.rrd:sl:AVERAGE
        DEF:sf=select.rrd:sf:AVERAGE
        DEF:asfp=select.rrd:asfp:AVERAGE
        DEF:msf=select.rrd:msf:AVERAGE
        LINE2:sl#0000FF:SelectLoops
        LINE2:sf#FF0000:SelectFDs
        LINE2:asfp#00FF00:AvgSelectFDPeriod
        LINE2:msf#FF00FF:MedianSelectFDs
 -->       

</center>
</BODY>
</HTML>
