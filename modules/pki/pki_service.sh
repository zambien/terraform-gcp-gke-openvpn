#!/usr/bin/env bash

set -e

# extract the variables for use in this shell service
eval "$(jq -r '@sh "endpoint_server=\(.endpoint_server)"')"

ca_crt=$(cat pki/ca.crt)
cert_crt=$(cat pki/issued/$endpoint_server.crt)
private_key=$(cat pki/private/$endpoint_server.key)
dh_pem=$(cat pki/dh.pem)
ta_key=$(cat pki/ta.key)


jq -n --arg ca_crt "$ca_crt" \
      --arg cert_crt "$cert_crt" \
      --arg private_key "$private_key" \
      --arg dh_pem "$dh_pem" \
      --arg ta_key "$ta_key" \
      '{"ca_crt":$ca_crt, "cert_crt":$cert_crt, "private_key": $private_key,"dh_pem":$dh_pem, "ta_key":$ta_key}'