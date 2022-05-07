#!/bin/bash

dir=$(pwd)
git remote set-url origin https://github.com/truecharts/truescript.git 2>&1 >/dev/null
git fetch 2>&1 >/dev/null
git update-index -q --refresh 2>&1 >/dev/null
echo "script requires update"
git reset --hard 2>&1 >/dev/null
git checkout main 2>&1 >/dev/null
git pull 2>&1 >/dev/null
echo "script updated"
$dir/truescript.sh
