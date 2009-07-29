#!/bin/bash

# This is a simple shell script
# for installing all required modules
# for WormBase in a local path.

# It does require some intervention.

PROJECT=$1
ROOT=/usr/local/wormbase
EXTLIB=extlib

# Base set of modules
MODULES=("LWP
          YAML
          ExtUtils::MakeMaker
          Bundle::CPAN
          Cache::Cache
          Cache::FileCache
          CGI
          CGI::Session
          CGI::Cache
          CGI::Toggle
          Date::Calc
          Date::Manip
          DB_File
          DBI
          DBD::mysql
          Digest::MD5
          GD
          GD::SVG
          GD::Graph
          GD::Graph::pie
          HTML::TokeParser
          IO::Scalar
          IO::String
          Image::GD::Thumbnail
          MIME::Lite
          Net::FTP
	  Net::FTP::Recursive
          Proc::Simple
          Term::ReadKey
          Search::Indexer
          SOAP::Lite
          Statistics::OLS
          Storable
          SVG
          SVG::Graph
          Test::Pod
          Text::Shellwords
          Time::Format
          WeakRef
          XML::SAX
          XML::Parser
          XML::DOM
          XML::Writer
          XML::Twig
          XML::Simple
          Class::Base
          Data::Stag
          Log::Log4perl
          Flickr::API
          mod_perl2
")


if [ ! "$PROJECT" ]
then
#  echo "Usage: $0 [classic|classic-gb2|2.0]"
  echo "Usage: $0 [website-classic|website-classic-gb2|website-2.0]"
  exit
fi



function alert() {
  msg=$1
  echo ""
  echo ${msg}
  echo ${SEPERATOR}
}


function failure() {
  msg=$1
  echo "  ---> ${msg}..."
  exit
}

function success() {
  msg=$1
  echo "  ${msg}."
}

BASE=${ROOT}/${PROJECT}/${EXTLIB}
mkdir ${BASE}
cd ${BASE}

# Set up our environment
perl -Mlocal::lib=./
eval $(perl -Mlocal::lib=--self-contained,./)

  # For logging sake, printenv
echo "\n\nYour PERL5LIB should now be set and ready to install..."
printenv | grep PERL5LIB

alert "Here we go..."
sleep 10

for MODULE in ${MODULES}
do

    alert "Installing ${MODULE} to ${BASE}"
    
    # Generic build
    if perl -MCPAN -e "CPAN::install(${MODULE})"
    then
	success "Succesfully installed ${MODULE}"
    else
	failure "Failed to install ${MODULE}; you might want to try it again manually"
    fi
    
    
      # Some modules require special handling.
      # Let's try to do them now
    
      # MySQL::DBD
    if "$MODULE" = "DBD::mysql"
    then
	cd ~/build/DBD-mysql*
	make realclean
	perl Makefile.PL INSTALL_BASE=${BASE} --testuser=root --testpassword=3l3g@nz
	make
	make test
	make install
    fi
    
      # Flickr::API::Simple is a private module
    if "$MODULE" = "Flickr::API::Simple"
    then
	cd /usr/local/wormbase/build/Flickr-API-Simple
	perl ./Build.PL --install_base ${BASE}
	./Build install
    fi    
done
