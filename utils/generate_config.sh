#!/bin/bash


generate_config_ini() {
  if [ ! -f config.ini ]; then
    cp .config.default.ini config.ini
  fi
}
