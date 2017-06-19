# terraform-gcp-openvpn
Module for OpenVPN via Terraform in Google Cloud Platform

## Intro

This repo is a practical implementation containing everything needed to stand up a personal VPN for free.

Google Cloud Platform (GCP) offers a really attractive always free tier that makes the idea of standing up a personal VPN appealing.  I became interested in using GCP for this a few months back and finally had some time to carve off to play around with this.

The repos is laid out as a learning exercise with full instructions for new users.

## Instructions

### Linux box setup

I use Vagrant/Virtualbox on my Mac.  This will expect you to do the same.

Software prereqs:

```
docker
terraform
```

We'll take you through installing the rest.

### GCP initial setup

First thing to do is create a GCP account if you don't have one.  Then go setup a project and get your credentials.  If you name your project "terraform-gcp-openvpn" you won't have to change inputs for that.
I followed the steps here to setup my GCP credentials:

https://www.terraform.io/docs/providers/google/

Once your project is created you will need to enable some APIs.  Some may be enabled in terraform but others MUST be done via the AWS console.  You will see which APIs need to be enables when running terraform apply.

install google cloud tools and kubectl

```
curl https://sdk.cloud.google.com | bash
gcloud components install kubectl
```


### GCS Fuse

We will use GCS and mount it to our local vagrant as well as the openvpn target.

Install:
```
export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

sudo apt-get update
sudo apt-get install gcsfuse
```

Mount:
```
mkdir -p ~/gcsmount
export GOOGLE_APPLICATION_CREDENTIALS=~/.gcp/terraform-gcp-openvpn.json && gcsfuse openvpn-gcp-bucket /home/vagrant/gcsmount
```

### Terraform

Run Terraform to set everything up.  The first time you will be asked for a username and password for your Kubernetes cluster which is where the VPN will actually run.

`./tf.sh apply`

### kubernetes

At any time you can view your config with

`kubectl config view`

Things are kind of fragmented with Terraform and GKE right now.  So some commands will be run in terraform and others in the shell.


```
docker run -v $OVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN kylemanna/openvpn
```


```
sed "s/\${OVPN_CN}/$OVPN_CN/g;" k8s/deployment.yaml | kubectl create --namespace=$namespace -f -
```

Get a static IP:
```
gcloud compute addresses create terraform-gcp-openvpn-ingress --global
```


Create your load balancer
```
kubectl expose deployment terraform-gke-openvpn --port=1194 --target-port=1194 \
        --name=terraform-gke-openvpn --type=NodePort

```

Create the ingress resource file to map the static ip to your services


Run the ingress resource creations

```
kubectl create -f k8s/terraform-gke-openvpn-ing.yaml
```

IP_ADDR=`gcloud compute addresses describe terraform-gcp-openvpn-ingress --global --format='value(address)'`

Note:  We extend kylemanna's openvpn docker container as it is very secure and reliable. More here:

https://github.com/kylemanna/docker-openvpn

```
OVPN_DATA="terraform-gcp-ovpn"
docker volume create --name $OVPN_DATA

mkdir -p ovpn

docker run -v ${PWD}/ovpn:/etc/openvpn --rm kylemanna/openvpn ovpn_genconfig -u udp://$IP_ADDR:1194
docker run -v ${PWD}/ovpn:/etc/openvpn --rm -it kylemanna/openvpn ovpn_initpki nopass
cp -r ${PWD}/ovpn/* ~/gcsmount



