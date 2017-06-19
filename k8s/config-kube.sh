#!/usr/bin/env bash

# Install kubectl
gcloud components install kubectl --quiet

# get dat IP ADDR 4 l8r
CL_ADDR=$1
IP_ADDR=$2

# if you are running this you must want to start from scratch with your certs... well I hope so at least...
rm -R pki

# setup the pki
if [[ ! -f pki/ca.crt ]];then
    docker run --user=$(id -u) -e OVPN_CN=$IP_ADDR  -e OVPN_SERVER_URL=tcp://$IP_ADDR:1194 -v $PWD:/etc/openvpn zambien/terraform-gcp-openvpn ovpn_initpki nopass $IP_ADDR
fi

# Setup the kubestack
#kubectl config set-cluster kubestack --insecure-skip-tls-verify=true --server=$CL_ADDR

# Setup creds
#gcloud container clusters get-credentials openvpn--cluster --zone us-east1-b --project terraform-gcp-openvpn

# Setup the docker container to run
#kubectl run terraform-gke-openvpn --image=zambien/terraform-gcp-openvpn
#sed "s/\${OVPN_CN}/$IP_ADDR/g;" k8s/deployment.yaml | sed "s/replaceme/$IP_ADDR/g;"  | kubectl create --namespace=$namespace -f -


# get ready to open up to the world
#kubectl expose deployment terraform-gke-openvpn --port=1194 --target-port=1194 \
#        --name=terraform-gke-openvpn --type=NodePort

# create the static public ip
#kubectl create -f k8s/terraform-gke-openvpn-ing.yaml

# mount GCS to local
#mkdir -p ~/gcsmount
#GOOGLE_APPLICATION_CREDENTIALS=~/.gcp/terraform-gcp-openvpn.json gcsfuse openvpn-gcp-bucket /home/vagrant/gcsmount







