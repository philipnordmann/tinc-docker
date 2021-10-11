#!/bin/bash

function main (){
    echo "starting tincd..."
    
    mkdir -p /dev/net
    mknod -m 666 /dev/net/tun c 10 200
    
    /usr/sbin/tincd --config=/config --no-detach
}

function genconf_server (){

    echo "generating server conf"
    mkdir -p /config/hosts/
    cat << EOF > /config/tinc.conf
Name = ${TINC_SERVER_NAME}
AddressFamily = ipv4
Interface = tun0
EOF

    expect -c 'spawn "/usr/sbin/tincd" "--config=/config" "--generate-keys=4096"; send "\r"; send "/config/id_rsa.pub\r"; expect eof'
    echo ""
    echo "generating ${TINC_SERVER_NAME}"

    if [ "${TINC_EXTERNAL_PORT}" == "" ]; then
        cat <<EOF > /config/hosts/${TINC_SERVER_NAME}
Address = ${TINC_ADDRESS}
Subnet = ${TINC_SERVER_IP}
EOF
    else
        cat <<EOF > /config/hosts/${TINC_SERVER_NAME}
Address = ${TINC_ADDRESS} ${TINC_EXTERNAL_PORT}
Subnet = ${TINC_SERVER_IP}
EOF
    fi

    cat /config/id_rsa.pub >> /config/hosts/${TINC_SERVER_NAME}

    echo "generating tinc-up"
    
    cat <<EOF > /config/tinc-up
#!/bin/sh
ip link set \$INTERFACE up
ip addr add ${TINC_SERVER_IP} dev \$INTERFACE
ip route add ${TINC_SUBNET} dev \$INTERFACE
EOF
    
    echo "generating tinc-down"

    cat <<EOF > /config/tinc-down
#!/bin/sh
ip route del ${TINC_SUBNET} dev \$INTERFACE
ip addr del ${TINC_SERVER_IP} dev \$INTERFACE
ip link set \$INTERFACE down
EOF
    
    chmod u+x /config/tinc-*
}

function genconf_client (){
    local CLIENT_NUM="${1}"
    local CLIENT_NAME="client${CLIENT_NUM}"
    local CLIENT_IP="${TINC_SUBNET_PRE}.$((CLIENT_NUM+1))/32"
    echo "generating client ${CLIENT_NAME}"
    mkdir -p /config/clients/${CLIENT_NAME}/hosts

    cat <<EOF > /config/clients/${CLIENT_NAME}/tinc.conf
Name = ${CLIENT_NAME}
AddressFamily = ipv4
Interface = tun0
ConnectTo = ${TINC_SERVER_NAME}
EOF

    expect -c "spawn \"/usr/sbin/tincd\" \"--config=/config/clients/${CLIENT_NAME}\" \"--generate-keys=4096\"; send \"\r\"; send \"/config/clients/${CLIENT_NAME}/id_rsa.pub\r\"; expect eof"

    cat <<EOF > /config/clients/${CLIENT_NAME}/hosts/${CLIENT_NAME}
Subnet = ${CLIENT_IP}
EOF

    cat /config/clients/${CLIENT_NAME}/id_rsa.pub >> /config/clients/${CLIENT_NAME}/hosts/${CLIENT_NAME}

    cat <<EOF > /config/clients/${CLIENT_NAME}/tinc-up
#!/bin/sh
ip link set \$INTERFACE up
ip addr add ${CLIENT_IP} dev \$INTERFACE
ip route add ${TINC_SUBNET} dev \$INTERFACE
EOF
    
    cat <<EOF > /config/clients/${CLIENT_NAME}/tinc-down
#!/bin/sh
ip route del ${TINC_SUBNET} dev \$INTERFACE
ip addr del ${CLIENT_IP} dev \$INTERFACE
ip link set \$INTERFACE down
EOF
    
    chmod u+x /config/clients/${CLIENT_NAME}/tinc-*

    cp /config/clients/${CLIENT_NAME}/hosts/${CLIENT_NAME} /config/hosts/
    cp /config/hosts/${TINC_SERVER_NAME} /config/clients/${CLIENT_NAME}/hosts/

}

function genconf (){
    
    genconf_server

    for i in $(seq 1 ${PEERS}); do
        genconf_client ${i}
    done

    for i in $(seq 1 ${PEERS}); do
        local CLIENT_NAME="client${i}"
        for j in $(seq 1 ${PEERS}); do
            if [ "${i}" != "${j}" ]; then
                cp /config/clients/client${j}/hosts/client${j} /config/clients/${CLIENT_NAME}/hosts/
            fi
        done
    done
    
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

