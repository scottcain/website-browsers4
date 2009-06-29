#!/usr/bin/perl

use strict;
use Ace;
use WWW::Mechanize;
use Digest::MD5 qw/md5_hex/;

my $password = shift or die "Usage $0 [password]\n";
chomp $password;

# The cross-referenced URL to submit to citeulike.
my $url = 'http://www.citeulike.org/posturl?url=http://www.wormbase.org/db/misc/paper?name=%s';

# Connect to our aceserver and get all the papers.
my $db = Ace->connect(-host=>'aceserver.cshl.org',-port=>2005);
my @papers = $db->fetch(Paper=>'*');

# A new mech object with in-memory cookies.
my $mech = WWW::Mechanize->new(
    cookie_jar => {},
    );

my %complete = get_complete();

# Login to citeulike.
$mech->get("http://www.citeulike.org/login?from=%2f");
$mech->submit_form(
    form_name => 'frm',
    fields => { username => 'tharris',
		password => $password,
    });



open ERR,">status-errors.txt";
open COMPLETE,">>status-uploaded.txt";
my $total = scalar @papers;
my $c;
foreach my $paper (@papers) {
  next unless $paper =~ /^WBPaper/;
  $c++;
  if ($complete{$paper->name}) {
    print STDERR "Already complete: $paper. Skipping...";
    print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
    next;
  }

  sleep(1);
  
  # Get the citeulike submit form for each paper.
  $mech->get(sprintf($url,$paper));

  # Add some tags
  my @tags = qw/WormBase caenorhabditis_elegans celegans c_elegans elegans nematode/;
  my @keywords = eval { $paper->Keyword };
  
  foreach my $key (@keywords) {
    $key =~ s/ /_/g;
    $key =~ s/\//-/g;
    push @tags,lc($key);
  }

  # Genes
  my @genes = $paper->Gene;
  if (@genes < 10) {
    foreach (@genes) {
      push @tags,$_->CGC_name if $_->CGC_name;
      push @tags,$_->Sequence_name if $_->Sequence_name && $_->Sequence_name ne $_->Public_name;
    }
  }
  
  push @tags,lc($paper->Type);
  # print join("; ",@tags) . "\n";

  my $content = $mech->content;

  # Make sure the paper has sufficient data for citeulike to parse.
  unless ($mech->form_name('frm')) {
    print ERR "$paper: insufficient data\n";
    next;
  }

  # print $content;
  
  # Get the article ID stored in a hidden field.
  # Formatting seems to vary.
  $content =~ /input type="hidden" value="(.*)" name="article_id"/;
  my $article_id = $1;
  unless ($article_id) {
    $content =~ /input type="hidden" name="article_id" value="(\d*)"/;
    $article_id = $1;
  }
  
  # Get the unique hidden name and value.
  $content =~ /document\.frm\.(.*)\.value = hex_md5\('(.*)'\);/;
  my $key_value = $1;
  my $to_hex = $2;

  # Dump out the hexing js.  Awkward.
  dump_js($to_hex);

  # Execute the js and retrieve the hexed value.
  my $hex = execute_js();

  # Submit the form with appropriate fields.
  #		    wname          => '',
  
  my $response = $mech->submit_form(
				    form_name => 'frm',
				    fields => { tags           => join(" ",@tags),
						post_action    => 'new',
						article_id     => $article_id,
						url            => sprintf($url,$paper),
						src_username   => '',
						$key_value     => $hex,
						to_own_library => 'on',
						to_group_6190  => 'on',
						to_read        => '3',
					      });
  if ($response->is_success) {
    print COMPLETE "$paper\n";
  } else {
    print ERR "$paper\n";
  }
	  
  print STDERR "$c of $total: $paper $article_id $key_value $hex; " . $response->is_success;
  print STDERR -t STDOUT && !$ENV{EMACS} ? "\r" : "\n";
}

# Some of the hidden fields on the citeulike new submission form.
#<input type="hidden" value="new" name="post_action"/>
#<input type="hidden" value="" name="wname"/>
#<input type="hidden" value="3169749" name="article_id"/>
#<input type="hidden" value="http://www.wormbase.org/db/misc/paper?name=WBPaper00000184" name="url"/>
#<input type="hidden" value="2FA117C21526D4A27683D90D41135944DF702AA1" name="x4975FF7E2A3585E5EF9BC6F7C155FA58EF1BDD34"/>
#<input type="hidden" value="" name="src_username"/>
#<input type="hidden" value="B67870767EA098A65AAF4B034BDEFCFD88274723" name="x4975FF7E2A3585E5EF9BC6F7C155FA58EF1BDD34"/>


# Dump out a javascript file suitable for generating the hexed ID.
sub dump_js {
  my $id = shift;

  open JS,">get_hex.js";
  print JS <<END;
var md5size=8;

function hex_md5(s){
  return binb2hex(core_md5(str2binb(s),s.length*md5size));
}

function core_md5(x,len){
  x[len>>5]|=0x80<<(24-len%32);
  x[((len+64>>9)<<4)+15]=len;
  var w=Array(80);
  var a=1732584193;
  var b=-271733879;
  var c=-1732584194;
  var d=271733878;
  var e=-1009589776;
  for(var i=0;i<x.length;i+=16){
    var olda=a;
    var oldb=b;
    var oldc=c;
    var oldd=d;
    var olde=e;
    for(var j=0;j<80;j++){
      if(j<16)w[j]=x[i+j];
      else w[j]=rol(w[j-3]^w[j-8]^w[j-14]^w[j-16],1);
      var t=safe_add(safe_add(rol(a,5),md5_ft(j,b,c,d)),safe_add(safe_add(e,w[j]),md5_kt(j)));
      e=d;
      d=c;
      c=rol(b,30);
      b=a;
      a=t;
	}
    a=safe_add(a,olda);
    b=safe_add(b,oldb);
    c=safe_add(c,oldc);
    d=safe_add(d,oldd);
    e=safe_add(e,olde);
  }
  return Array(a,b,c,d,e);
}

function md5_ft(t,b,c,d){
  if(t<20)return(b&c)|((~b)&d);
  if(t<40)return b^c^d;
  if(t<60)return(b&c)|(b&d)|(c&d);
  return b^c^d;
}

function md5_kt(t){
  return(t<20)?1518500249:(t<40)?1859775393:(t<60)?-1894007588:-899497514;
}

function safe_add(x,y){
  var lsw=(x&0xFFFF)+(y&0xFFFF);
  var msw=(x>>16)+(y>>16)+(lsw>>16);
  return(msw<<16)|(lsw&0xFFFF);
}

function rol(num,cnt){
  return(num<<cnt)|(num>>>(32-cnt));
}

function str2binb(str){
  var bin=Array();
  var mask=(1<<md5size)-1;
  for(var i=0;i<str.length*md5size;i+=md5size)bin[i>>5]|=(str.charCodeAt(i/md5size)&mask)<<(32-md5size-i%32);
  return bin;
}

function binb2str(bin){
  var str="";
  var mask=(1<<md5size)-1;
  for(var i=0;i<bin.length*32;i+=md5size)str+=String.fromCharCode((bin[i>>5]>>>(32-md5size-i%32))&mask);
  return str;
}

function binb2hex(binarray){
  var hex_tab="0123456789ABCDEF";
  var str="";
  for(var i=0;i<binarray.length*4;i++){
    str+=hex_tab.charAt((0x7*(binarray[i>>2]>>((3-i%4)*8+4)))&0xF)+hex_tab.charAt((0x7*(binarray[i>>2]>>((3-i%4)*8)))&0xF);
  } 
  print(str);
  return str;
}

hex_md5("$id");
END
;
}

# Execute the javascript.
sub execute_js {
  my $hex = `./spidermonkey/src/Darwin_DBG.OBJ/js get_hex.js`;
  system("rm -rf get_hex.js");
  chomp $hex;
  return $hex;
}


sub get_complete {
  my %complete;
  open IN,"status-uploaded.txt";
  while (<IN>) {
    chomp;
    $complete{$_}++;
  }
  close IN;
  return %complete;
}
