#!/usr/bin/env bash


kubectl delete -f ./k8s/terraform-gke-openvpn-ing.yamls

kubectl delete service terraform-gke-openvpn

kubectl delete deployment terraform-gke-openvpn

    kubectl config delete-cluster kubestack

sudo rm -R ovpn/*
