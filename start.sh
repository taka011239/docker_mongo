#!/bin/bash

# Docker config
DOCKERIP="172.17.42.1"
DOCKERSOCK="/var/run/docker.sock"
LOCALPATH=${HOME}

# Clean up
containers=( skydns skydock mongod1 mongod2 mongod3 mongocfg mongos )
for c in ${containers[@]}; do
	docker kill ${c} 	> /dev/null 2>&1
	docker rm ${c} 		> /dev/null 2>&1
done

# verify that docker is installed 
if ! type docker > /dev/null 2>&1; then
    echo "Need to install docker!!"
    echo "See http://docs.docker.com/installation/"
    exit
fi

# check OS Type, currently support linux only.
case "${OSTYPE}" in
# OSX
darwin*)
    echo "Currently not support Mac!!"
    exit
    ;;
linux*)
    # Setup skydns/skydock
    docker run -d -p ${DOCKERIP}:53:53/udp --name skydns crosbymichael/skydns -nameserver 8.8.8.8:53 \
        -domain docker
    docker run -d -v ${DOCKERSOCK}:/docker.sock --name skydock crosbymichael/skydock -ttl 30 \
        -environment dev -s /docker.sock -domain docker -name skydns
    # Setup local db storage if not exist
    if [ ! -d "${LOCALPATH}/mongodata" ]; then
        mkdir -p ${LOCALPATH}/mongodata/mongo1/db
        mkdir -p ${LOCALPATH}/mongodata/mongo1/log
        mkdir -p ${LOCALPATH}/mongodata/mongo2/db
        mkdir -p ${LOCALPATH}/mongodata/mongo2/log
        mkdir -p ${LOCALPATH}/mongodata/mongo3/db
        mkdir -p ${LOCALPATH}/mongodata/mongo3/log
        mkdir -p ${LOCALPATH}/mongodata/mongocfg/db
        mkdir -p ${LOCALPATH}/mongodata/mongocfg/log
        mkdir -p ${LOCALPATH}/mongodata/mongos/log
    fi

    docker run --dns ${DOCKERIP} --name mongod1 -P -d -v ${LOCALPATH}/mongodata/mongo1/db:/data/db \
        -v ${LOCALPATH}/mongodata/mongo1/log:/var/log/mongodb taka011239/mongodb \
        mongod --shardsvr --dbpath /data/db --logpath /var/log/mongodb/mongod.log --port 27017
    docker run --dns ${DOCKERIP} --name mongod2 -P -d -v ${LOCALPATH}/mongodata/mongo2/db:/data/db \
        -v ${LOCALPATH}/mongodata/mongo2/log:/var/log/mongodb taka011239/mongodb \
        mongod --shardsvr --dbpath /data/db --logpath /var/log/mongodb/mongod.log --port 27017
    docker run --dns ${DOCKERIP} --name mongod3 -P -d -v ${LOCALPATH}/mongodata/mongo3/db:/data/db \
        -v ${LOCALPATH}/mongodata/mongo3/log:/var/log/mongodb taka011239/mongodb \
        mongod --shardsvr --dbpath /data/db --logpath /var/log/mongodb/mongod.log --port 27017

    docker run --dns ${DOCKERIP} --name mongocfg -P -d -v ${LOCALPATH}/mongodata/mongocfg/db:/data/db \
        -v ${LOCALPATH}/mongodata/mongocfg/log:/var/log/mongodb taka011239/mongodb \
        mongod --configsvr --dbpath /data/db --logpath /var/log/mongodb/mongod.log --port 27017

    sleep 10

    docker run --dns ${DOCKERIP} --name mongos -P -d -v ${LOCALPATH}/mongodata/mongos/log:/var/log/mongodb \
        taka011239/mongodb mongos --configdb mongocfg.mongodb.dev.docker:27017 --logpath /var/log/mongodb/mongod.log

    sleep 10

    docker run --dns ${DOCKERIP} -it --rm -v /home/taka/tmp/mongo/docker_mongo/js:/js \
        taka011239/mongodb mongo mongos.mongodb.dev.docker /js/addShard.js
    ;;
esac

