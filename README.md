# terraform-gcp-openvpn
Module for OpenVPN via Terraform in Google Cloud Platform using GKE (Kubernetes)

## Intro

This repo is a practical implementation containing everything needed to stand up a personal VPN on Google Cloud with GKE/Kubernetes.  Google Cloud Platform (GCP) offers an attractive always free tier that makes the idea of learning their stack appealing.  I became interested in using GCP for a free personal VPN a few months back and finally had some time to carve off to play around with this.

#### Lessons Learned

Using Kubernetes and the always free tier is a mixed bag.  You are charged for the nodes you run.  You will also be charged for load balancing generally in GPC.  A cheaper option may be to simply use google compute for a single personal VPN instance and I'll explore that next in a different repo.

The terraform provider for kubernetes is very green.  As such only non-beta APIs are supported so you will find that you end up using kubectl commands for some things via a null resource.  See the module for an example of this.

## Instructions

First, make sure you have the prerequisite software:

```
jq                    - https://stedolan.github.io/jq/download
docker engine         - https://www.docker.com/community-edition
terraform 0.9.6*      - https://www.terraform.io/downloads.html
```

* I usually run the latest terraform release but because of this issue, https://github.com/hashicorp/terraform/issues/15244, use 0.9.6.

### GCP initial setup

First thing to do is create a GCP account if you don't have one.  Then go setup a project and get your credentials.  If you name your project "terraform-gcp-openvpn" you won't have to change inputs for that.
I followed the steps here to setup my GCP credentials:

https://www.terraform.io/docs/providers/google/

Afterwards run:
```
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/keyfile.json"
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init --quiet
```

Then run

```
gcloud components install kubectl --quiet
```

This will setup your credentials and install google cloud sdk tools.


### Terraform

We use terraform to provision everything.  This is a multistep process because there are some issues with Terraform and GCP integration at the moment.

First create an env file which will contain your credentials.  You can omit this step but you will be asked for the creds each time you run the terraform command.

```
set +o history # disable history for this
echo "cluster_master_username=\"yourusername\"" > env.tfvars
echo "cluster_master_password=\"yourpassword\"" >> env.tfvars
set -o history # history back on
```

Prepare for provisioning by loading the built in modules:

`terraform get`

To see what will be created:

`terraform plan -var-file=env.tfvars`

#### Provision the infrastructure

1.  First, allow API access for Terraform.  Currently this is the only way to do this for the servicemanagement API.
   go here: https://console.developers.google.com/apis/api/servicemanagement.googleapis.com/overview?project=terraform-gcp-openvpn
   click enable

   Note, there is code in the project to do this automatically but currently this is not allowed by Google so you will see a failure if you don't do this manually.

2.  Create the cluster first so that we can authenticate with kubernetes.
`terraform apply -target="google_container_cluster.openvpn_cluster" -var-file=env.tfvars`

3.  Configure auth:
```
gcloud container clusters get-credentials openvpn--cluster --zone us-east1-b --project terraform-gcp-openvpn
kubectl get po # Seems to be neccessary to bootstrap access between kube and GCP.  Weird.
```

4.  Deploy the remaining components:
`terraform apply -var-file=env.tfvars`

After the apply finishes wait a minute or so and get your external IP address.


`kubectl get svc`

You will see this line:

```
terraform-gke-openvpn   10.7.240.194   <pending>     80:30662/TCP   3m
```

After a minute or so pending will become an IP address.  That is your VPN endpoint for your client.

### VPN Clients

Generate VPN client credentials for CLIENTNAME without password protection; leave 'nopass' out to enter password.

Since we are forwarding through a load balancer we will use port 80 for the VPN endpoint.

```
docker run --user=$(id -u) -v $PWD:/etc/openvpn -ti ptlange/openvpn easyrsa build-client-full CLIENTNAME nopass

export INGRESS_IP_ADDRESS=<YOUR_EXTERNAL_IP_ADDRESS>

docker run --user=$(id -u) -e OVPN_DEFROUTE=1 -e OVPN_SERVER_URL=tcp://$INGRESS_IP_ADDRESS:80 -v $PWD:/etc/openvpn --rm ptlange/openvpn ovpn_getclient CLIENTNAME > CLIENTNAME.ovpn
```

If you are pretty fast with this it may take a few minutes for the load balancer to get setup.  I've seen it take up to 30 minutes.  You can check the google console for networking to see what the status is.  If you can't ping it, you can't connect. :)

#### Remove the infrastructure

At some point you may want to clean this up so it isn't provisioned anymore.  Run:

`terraform destroy -var-file=env.tfvars`

### Additional Notes

You may notice that a global external IP is created for this project but that it is unused.  When using NodeType and a global static IP you will see MTU errors.  It seems that the global IP has an issue with it's MTU settings currently.

You may also notice that the global external IP is used for the cert and private key.  The load balancer IP will be different.  This does not affect operation of the VPN.

#### Credits

I used code from pieterlange's and kylemanna's openvpn repos in this work:

* https://github.com/pieterlange/kube-openvpn
* https://github.com/kylemanna/docker-openvpn



