#!/bin/bash
set -e

if [  "$1" = 'mongod' ]; then
    chown -R mongodb /data/db
    chown -R mongodb /var/log/mongodb
    exec gosu mongodb "$@"
fi

exec "$@"
