#!/bin/bash

function main (){
    echo "starting tincd..."
    
    mkdir -p /dev/net
    mknod -m 666 /dev/net/tun c 10 200
    
    /usr/sbin/tincd --config=/config --no-detach
}

function genconf (){
    
}

if [ "${PEERS}" == "" ]; then
    echo "PEERS not set, using default of 1"
    PEERS=1
fi

if [ "${PEERS}" -gt "253" ]; then
    echo "peers set to ${PEERS} that is greater than 253, please define something smaller than 253"
    echo "setting peers to 1"
    PEERS=1
fi

if [ "${TINC_SUBNET}" == "" ]; then
    TINC_SUBNET="192.168.222.0/24"
    echo "TINC_SUBNET not set using default of ${TINC_SUBNET}"
fi

TINC_NETMASK="${TINC_SUBNET#*/}"
TINC_SUBNET_PRE="${TINC_SUBNET%.*}"
TINC_SERVER_IP="${TINC_SUBNET_PRE}.1/32"

if [ "${TINC_SERVER_NAME}" == "" ]; then
    TINC_SERVER_NAME="dockerserver"
    echo "TINC_SERVER_NAME not set using default of ${TINC_SERVER_NAME}"
fi

if [ "${1}" == "" ]; then
    if [ "$(ls -A /config)" == "" ]; then
        echo "directory /config is empty, generating config with ${PEERS} peers"
        genconf
    fi
    main

elif [ "${1}" == "genconf" ]; then
    genconf

else
    /usr/sbin/tincd ${@}

fi

