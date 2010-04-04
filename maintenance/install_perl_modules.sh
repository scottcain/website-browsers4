#!/bin/bash

# This is a simple shell script
# for installing all required modules
# for WormBase in a local path.

# It does require some intervention.

EXTLIBPATH=$1
DO_CATALYST=$2

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
          HTML::Entities
          HTML::TokeParser
          IO::Scalar
          IO::String
          Image::GD::Thumbnail
          MIME::Lite
          Net::FTP
	  Net::FTP::Recursive
          Proc::Simple
          Term::ReadKey
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
          Flickr::API::Simple
          Bio::Perl
          Bio::Graphics
          Ace
          Template
          mod_perl2
")

CATALYST=("Task::Catalyst
           Catalyst::Devel
           Catalyst::Model::DBI
           Catalyst::Model::Adaptor
           Catalyst::Plugin::ConfigLoader
           Catalyst::Plugin::Session
           Catalyst::Plugin::Session::State
           Catalyst::Plugin::Session::State::Cookie
           Catalyst::Plugin::Session::Store::FastMMap
           Catalyst::Action::RenderView
           Catalyst::Action::Rest
           Catalyst::Log::Log4perl
           Test::YAML::Valid
           ")


#          Search::Indexer  Problematic

if [ ! "$EXTLIBPATH" ]
then
  echo "Usage: $0 [/path/to/extlib] [DO_CATALYST]"
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

mkdir -p ${EXTLIBPATH}
cd ${EXTLIBPATH}

# Set up our environment
perl -Mlocal::lib=./
eval $(perl -Mlocal::lib=--self-contained,./)

# For logging sake, printenv
echo ""
echo ""
echo "Your PERL5LIB should now be set and ready to install..."
printenv | grep PERL5LIB

alert "Here we go..."
sleep 10



# Install Catalyst requirements
if [ "${DO_CATALYST}" ]; then
    for MODULE in ${CATALYST}
    do
	if perl -MCPAN -e "CPAN::install(${MODULE})"
	then
	    success "Succesfully installed ${MODULE}"
	else
	    failure "Failed to install ${MODULE}; you might want to try it again manually"
	fi
    done
    exit  
fi

for MODULE in ${MODULES}
do
    alert "Installing ${MODULE} to ${EXTLIBPATH}"
    
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
    if [ "$MODULE" = "DBD::mysql" ]; then
	cd ~/build/DBD-mysql*
	make realclean
	perl Makefile.PL INSTALL_BASE=${EXTLIBPATH} --testuser=root --testpassword=3l3g@nz
	make
	make test
	make install
    fi
    
      # Flickr::API::Simple is a private module
    if [ "$MODULE" = "Flickr::API::Simple" ]; then
	cd /usr/local/wormbase/build/Flickr-API-Simple
	perl ./Build.PL --install_base ${EXTLIBPATH}
	./Build install
    fi    	
done


