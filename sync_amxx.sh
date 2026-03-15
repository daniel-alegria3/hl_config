#!/bin/bash

HL_DIR="$HOME/.steam/steamcmd/Half-Life"
AMXX_DIR="$HL_DIR/valve/addons/amxmodx"
set -euox pipefail

rsync -avh --progress ./amxx_scripts/ "$AMXX_DIR/scripting"

SMA_FILES=(./amxx_scripts/*.sma)
(
    cd "$AMXX_DIR/scripting"
    for sma in "${SMA_FILES[@]}"; do
        plugin=$(basename "${sma%.sma}")
        ./amxxpc "$plugin.sma"
        mv "$plugin.amxx" "$AMXX_DIR/plugins/"
        if ! grep -qF "$plugin.amxx" "$AMXX_DIR/configs/plugins.ini"; then
            echo "$plugin.amxx" >> "$AMXX_DIR/configs/plugins.ini"
        fi
    done
)
