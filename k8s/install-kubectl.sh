#!/usr/bin/env bash

#curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.6.3/bin/linux/amd64/kubectl
#chmod +x ./kubectl
#sudo mv ./kubectl /usr/local/bin/kubectl

# install gcsfuse locally
export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

sudo apt-get update
sudo apt-get install -y gcsfuse

# install google cloud sdk
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init --quiet