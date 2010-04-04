#!/bin/bash

echo ' ' > /usr/local/acedb/elegans/database/serverlog.wrm

# ensure that acedb owns the logs - there is some other log rotation
# functionality that periodically sets the owner to root.
chown acedb:acedb /usr/local/acedb/elegans/database/serverlog.wrm
chown acedb:acedb /usr/local/acedb/elegans/database/log.wrm
