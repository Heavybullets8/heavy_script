#!/bin/bash


manage_kube_api() {
    local action="$1"
    local rule_comment="iX Custom Rule to drop connection requests to k8s cluster from external sources"

    case "$action" in
        enable)
            echo -e "${bold}Enabling Kubernetes API${reset}"
            if iptables -D INPUT -p tcp -m tcp --dport 6443 -m comment --comment "${rule_comment}" -j DROP 2> /dev/null; then
                echo -e "${green}Kubernetes API enabled${reset}"
            else
                echo -e "${green}Kubernetes API already enabled or rule not found${reset}"
            fi
            ;;
        disable)
            echo -e "${bold}Disabling Kubernetes API${reset}"
            if ! iptables -C INPUT -p tcp -m tcp --dport 6443 -m comment --comment "${rule_comment}" -j DROP 2> /dev/null; then
                if iptables -A INPUT -p tcp -m tcp --dport 6443 -m comment --comment "${rule_comment}" -j DROP; then
                    echo -e "${green}Kubernetes API disabled${reset}"
                else
                    echo -e "${red}Failed to add the iptables rule to disable Kubernetes API${reset}"
                fi
            else
                echo -e "${yellow}Kubernetes API is already disabled${reset}"
            fi
            ;;
    esac
}

export -f manage_kube_api
