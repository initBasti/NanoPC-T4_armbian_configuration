#!/bin/bash

build_location=$1

cp patch/misc/* "$build_location/patch/misc/"

if [ ! -d "$build_location/userpatches" ]
then
    mkdir -p "$build_location/userpatches/kernel/rockchip64-dev"
fi

cp -r userpatches/kernel/rockchip64-dev/ "$build_location/userpatches/kernel/"
cp userpatches/config-example.conf "$build_location/userpatches/config-example.conf"
cp userpatches/config-default.conf "$build_location/userpatches/config-default.conf"
cp userpatches/lib.config "$build_location/userpatches/lib.config"
cp userpatches/linux-rockchip64-dev.config "$build_location/userpatches/linux-rockchip64-dev.config"
