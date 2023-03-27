#!/bin/bash


generate_config_ini() {
  if [ ! -f config.ini ]; then
    cp .default.config.ini config.ini
  fi
}
