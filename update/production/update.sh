#!/bin/bash

# Start the update process
VERSION=$1
OLD_VERSION=$2

VERSION=$1

if [[ ! "$VERSION" && ! "$OLD_VERSION" ]]
then
  echo "Usage: $0 NEW_WSVERSION EXPIRING_WSVERSION"
  exit
fi

# Concatenate and analyze logs on the front end.
# This command needs sudo privileges; will this work?
#ssh fe.wormbase.org "/usr/local/wormbase-admin/log_maintenance/analysis/concatenate_logs.sh ${OLD_VERSION} www.wormbase.org"

# Reset the squid cache on fe
#ssh fe.wormbase.org 'sudo /etc/rc.d/init.d/squid fullreset'

# Analyze logs; this shouldn't be done until the concatenation is done.
#ssh brie6 '/usr/local/wormbase-admin/log_maintenance/analysis/analyze_logs.sh'

# Update production nodes
./push_software.sh
./push_databases.sh ${VERSION}
./restart_services.sh

# Send out an update notice
ssh brie6 '/usr/local/wormbase-admin/update_scripts/send_release_notification.pl'

# Prepare to build a virtual machine
ssh -t be1 "/usr/local/vmx/admin/virtual_machines/prepare_virtual_machine.sh ${VERSION}"
