#!/bin/bash

# Simple script to toggle Apple Wireless Direct Link (AWDL) to prevent Wi-Fi stuttering during streaming.

if [ "$1" == "down" ]; then
    echo "Disabling AWDL (AirDrop/Handoff background scanning) to stabilize Wi-Fi stream..."
    sudo ifconfig awdl0 down
    echo "AWDL is now DOWN. Network frame drops should decrease significantly."
elif [ "$1" == "up" ]; then
    echo "Enabling AWDL (AirDrop/Handoff)..."
    sudo ifconfig awdl0 up
    echo "AWDL is now UP."
else
    echo "Usage: ./toggle_awdl.sh [up|down]"
    echo "  down : Disables AirDrop/Handoff scanning (Fixes 5GHz Wi-Fi stuttering)"
    echo "  up   : Restores AirDrop/Handoff scanning"
fi
