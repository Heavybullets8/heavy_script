#!/bin/bash


enable_kube_api() {
    local rule_comment="iX Custom Rule to drop connection requests to k8s cluster from external sources"

    echo -e "${bold}Enabling Kubernetes API${reset}"

    local rule_exists
    rule_exists=$(iptables -t filter -L INPUT 2> /dev/null | grep -q "${rule_comment}")

    if $rule_exists; then
        if iptables -D INPUT -p tcp -m tcp --dport 6443 -m comment --comment "${rule_comment}" -j DROP; then
            echo -e "${green}Kubernetes API enabled${reset}"
        else
            echo -e "${red}Kubernetes API Enable FAILED${reset}"
        fi
    else
        echo -e "${green}Kubernetes API already enabled${reset}"
    fi
}