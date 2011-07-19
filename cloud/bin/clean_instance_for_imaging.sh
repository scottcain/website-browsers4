#!/bin/bash

# Clean up a running instance so that it can
# safely be shared as a public instance.

# Shell histories
find /root/.bash_history /home/*/.*history -exec rm -f {} \;


# Remove authorized keys
find / -name "authorized_keys" –exec rm –f {} \;

# Remove known hosts
find / -name "known_hosts" –exec rm –f {} \;

# Remove server ssh host keys
rm /etc/ssh/ssh_host*