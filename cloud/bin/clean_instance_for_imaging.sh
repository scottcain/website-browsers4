#!/bin/bash

# Clean up a running instance so that it can
# safely be shared as a public instance.

# Shell histories
find /root/.bash_history /home/*/.*history -exec rm -f {} \;


# Remove authorized keys
rm -rf /home/*/.ssh/authorized_keys2
rm -rf /home/*/.ssh/authorized_keys
rm -rf /home/*/.ssh/known_hosts
# Remove server ssh host keys
rm /etc/ssh/ssh_host*


#find /home -name "authorized_key"   –exec rm –f {} \;
#find /home -name 'authorized_keys2' –exec rm –f {} \;

# Remove known hosts
#find /home -name "known_hosts" –exec rm –f {} \;


