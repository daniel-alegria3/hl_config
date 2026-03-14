#!/bin/bash
set -e

## Download the files
wget -nc "https://github.com/rehlds/ReHLDS/releases/download/3.14.0.857/rehlds-bin-3.14.0.857.zip" -O /tmp/rehlds.zip &
wget -nc "https://github.com/rehlds/Metamod-R/releases/download/1.3.0.149/metamod-bin-1.3.0.149.zip" -O /tmp/metamod.zip &
wget -nc "https://www.amxmodx.org/amxxdrop/1.10/amxmodx-1.10.0-git5474-base-linux.tar.gz" -O /tmp/amxmodx.tar.gz &
steamcmd +force_install_dir "./Half-Life/" \
    +login anonymous \
    +app_set_config 90 mod cstrike \
    +app_update 90 -beta steam_legacy validate \
    +quit &

wait || exit

HL_DIR="$HOME/.steam/steamcmd/Half-Life"
set -euox pipefail

## Copy the files
mkdir -p /tmp/rehlds /tmp/metamod /tmp/amxmodx
unzip -o /tmp/rehlds.zip -d /tmp/rehlds
unzip -o /tmp/metamod.zip -d /tmp/metamod
tar -xf /tmp/amxmodx.tar.gz -C /tmp/amxmodx

mkdir -p "$HL_DIR/valve/addons"
rsync -avh --progress /tmp/rehlds/bin/linux32/ "$HL_DIR"
rsync -avh --progress /tmp/metamod/addons/ "$HL_DIR/valve/addons"
rsync -avh --progress /tmp/amxmodx/addons/ "$HL_DIR/valve/addons"

chmod +x "$HL_DIR/hlds_linux"
find "$HL_DIR" -name "*.so" ! -type l -exec patchelf --clear-execstack {} +

## Configure the mods
sed -i 's|gamedll_linux "dlls/hl.so"|gamedll_linux "addons/metamod/metamod_i386.so"|' \
  "$HL_DIR/valve/liblist.gam"

cat > "$HL_DIR/valve/addons/metamod/plugins.ini" << 'EOF'
linux addons/amxmodx/dlls/amxmodx_mm_i386.so
EOF
