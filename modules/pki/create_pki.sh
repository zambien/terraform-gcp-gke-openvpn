#!/usr/bin/env bash

# get dat IP ADDR data
IP_ADDR=$1

# if you are running this you must want to start from scratch with your certs... well I hope so at least...
rm -R pki

# setup the pki
if [[ ! -f pki/ca.crt ]];then
    docker run --user=$(id -u) -e OVPN_CN=$IP_ADDR  -e OVPN_SERVER_URL=tcp://$IP_ADDR:1194 -i -v $PWD:/etc/openvpn zambien/terraform-gcp-openvpn ovpn_initpki nopass $IP_ADDR
fi