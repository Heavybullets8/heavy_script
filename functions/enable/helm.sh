#!/bin/bash


enable_helm() {
    echo -e "${bold}Enabling Helm${reset}"

    if export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"; then
        echo -e "${green}Helm Enabled${reset}"
    else
        echo -e "${red}Helm Enable FAILED${reset}"
    fi
}