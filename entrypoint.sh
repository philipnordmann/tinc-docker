#!/bin/bash

function main (){
    echo "starting tincd..."
    
    mkdir -p /dev/net
    mknod -m 666 /dev/net/tun c 10 200

    update_conf firststart
    
    TINC_PID="$(cat /tmp/tinc.pid)"
    while ps -p ${TINC_PID} > /dev/null; do
        update_conf
        TINC_PID="$(cat /tmp/tinc.pid)"
        sleep 30
    done

}

function restart_tincd () {
    if [ -f /tmp/tinc.pid ]; then  
        /usr/sbin/tincd -k
        TINC_PID="$(cat /tmp/tinc.pid)"
        ps -p ${TINC_PID} > /dev/null
        PID_RUNNING="${?}"
        i=0
        while [[ "${PID_RUNNING}" == "0" && "${i}" -lt "60" ]]; do
            i=$((i + 1))
            sleep 1
            ps -p ${TINC_PID} > /dev/null
            PID_RUNNING="${?}"
        done
    fi
    /usr/sbin/tincd --config=/config --no-detach &
    printf "$!" > /tmp/tinc.pid
}

function update_conf () {
    if [ "${1}" == "firststart" ]; then
        UPDATED=true
    else
        UPDATED=false
    fi
    start=$PWD
    cd /opt/tincd/git/
    if [ -d .git ]; then
        git remote update
        git status -uno | grep -q "Your branch is behind"
        if [ "${?}" == "0" ]; then
            UPDATED=true
            git pull
        fi
    else
        git clone https://${GIT_USERNAME}:${GIT_TOKEN}@${GIT_REPOSITORY} .
        UPDATED=true
    fi
    cd ${start}

    if [ "${UPDATED}" == "true" ]; then
        /opt/tincd/genconf.py --config /opt/tincd/git/config.yml --name ${TINC_NAME} --configure /config --templates /opt/tincd/git/templates
        restart_tincd
    fi
}

if [ "${TINC_NAME}" == "" ]; then
    echo "\${TINC_NAME} not set"
    exit 1
fi

if [ "${1}" == "" ]; then
    main
else
    /usr/sbin/tincd ${@}
fi

