#!/bin/bash


function dns_help() {
  echo -e "${bold}DNS Command Help${reset}"
  echo -e "${bold}----------------${reset}"
  echo
  echo -e "${blue}heavyscript dns${reset}"
  echo
  echo -e "${bold}Subcommands${reset}"
  echo -e "${bold}-----------${reset}"
  echo -e "${blue}--all${reset}     | Show all application DNS names and their web ports"
  echo -e "${blue}--help${reset}    | Display this help menu"
  echo
  echo -e "${bold}Examples${reset}"
  echo -e "${bold}--------${reset}"
  echo -e "${blue}heavyscript dns --all${reset}"
  echo -e "${blue}heavyscript dns --help${reset}"
  echo
}
