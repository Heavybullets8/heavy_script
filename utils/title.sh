#!/bin/bash


title(){
    # Set the text color to frost
    txt_frost='\033[38;2;248;248;242m'

    # Set the text color to snowstorm
    txt_snowstorm='\033[38;2;109;113;120m'

    # Set the text color to glacier
    txt_glacier='\033[38;2;60;78;82m'

    # Set the text color to frostflower
    txt_frostflower='\033[38;2;215;216;216m'

    # Reset the text color
    txt_reset='\033[0m'

    echo -e "${txt_frost} _   _                        _____           _       _   ${txt_reset}"
    echo -e "${txt_snowstorm}| | | |                      /  ___|         (_)     | | ${txt_reset}"
    echo -e "${txt_glacier}| |_| | ___  __ ___   ___   _\\ \`--.  ___ _ __ _ _ __ | |_${txt_reset}"
    echo -e "${txt_frostflower}|  _  |/ _ \/ _\` \\ \ / / | | |\`--. \/ __| '__| | '_ \\ __|${txt_reset}"
    echo -e "${txt_snowstorm}| | | |  __/ (_| |\\ V /| |_| /\\__/ / (__| |  | | |_) | |_ ${txt_reset}"
    echo -e "${txt_glacier}\\_| |_/\\___|\\__,_| \\_/  \\__, \\____/ \\___|_|  |_| .__/ \\__|${txt_reset}"
    echo -e "${txt_frostflower}                         __/ |                 | |        ${txt_reset}"
    echo -e "${txt_snowstorm}                        |___/                  |_|        ${txt_reset}"
    echo -e "${txt_snowstorm}$hs_version${txt_reset}"
    echo
}
export -f title