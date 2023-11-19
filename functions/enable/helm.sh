#!/bin/bash


enable_helm() {
    local action="$1"
    local profiles=("$HOME/.bashrc" "$HOME/.zshrc")

    for profile in "${profiles[@]}"; do
        # Check if the profile file exists, create if it does not
        [[ -f "$profile" ]] || touch "$profile"

        case "$action" in
            enable)
                echo -e "${bold}Enabling Helm in $profile${reset}"
                if ! grep -q 'export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"' "$profile"; then
                    echo 'export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"' >> "$profile"
                    echo -e "${green}Helm Enabled in $profile. Please restart your shell or source your profile to apply changes.${reset}"
                else
                    echo -e "${yellow}Helm is already enabled in $profile.${reset}"
                fi
                ;;
            disable)
                echo -e "${bold}Disabling Helm in $profile${reset}"
                if grep -q 'export KUBECONFIG="/etc/rancher/k3s/k3s.yaml"' "$profile"; then
                    sed -i '/export KUBECONFIG="\/etc\/rancher\/k3s\/k3s.yaml"/d' "$profile"
                    echo -e "${green}Helm Disabled in $profile. Please restart your shell or source your profile to apply changes.${reset}"
                else
                    echo -e "${yellow}Helm is already disabled in $profile.${reset}"
                fi
                ;;
        esac
    done
}
export -f enable_helm