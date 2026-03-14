#!/bin/bash

HL_DIR="$HOME/.steam/steamcmd/Half-Life"
export LD_LIBRARY_PATH="$HL_DIR:$LD_LIBRARY_PATH"

cd "$HL_DIR"
./hlds_run \
  -console \
  -game valve \
  -insecure \
  +sv_lan 1 \
  +maxplayers 16 \
  +map crossfire
