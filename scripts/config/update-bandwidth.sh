#!/bin/bash

# Default values

D_SCORE=4
D_OUT=2

set_default_bandwidth() {
    D=6
    D_LO=5
    D_HI=12
    D_SCORE=4
}

set_low_bandwidth() {
    LOW_WATERMARK=48
    HIGH_WATERMARK=16
    D=4
    D_LO=2
    D_HI=4
}

set_high_bandwidth() {
    LOW_WATERMARK=16
    HIGH_WATERMARK=48
    D=6
    D_LO=5
    D_HI=12
}

plan="default"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --plan)
            plan="$2"
            shift 2
            ;;
        --clear)
            # Use defaults
            shift
            ;;
        --d)
            D="$2"
            shift 2
            ;;
        --dLo)
            D_LO="$2"
            shift 2
            ;;
        --dHi)
            D_HI="$2"
            shift 2
            ;;
        --dOut)
            D_OUT="$2"
            shift 2
            ;;
        --lower-watermark)
            LOW_WATERMARK="$2"
            shift 2
            ;;
        --high-watermark)
            HIGH_WATERMARK="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

if [ "$plan" == "low" ]; then
    set_low_bandwidth
elif [ "$plan" == "high" ]; then
    set_high_bandwidth
else
    set_default_bandwidth
fi

# Update the config file
yq -i ".p2p.lowWatermarkConnections = $LOW_WATERMARK" $QUIL_CONFIG_FILE
yq -i ".p2p.highWatermarkConnections = $HIGH_WATERMARK" $QUIL_CONFIG_FILE
yq -i ".p2p.d = $D" $QUIL_CONFIG_FILE
yq -i ".p2p.dLo = $D_LO" $QUIL_CONFIG_FILE
yq -i ".p2p.dHi = $D_HI" $QUIL_CONFIG_FILE
yq -i ".p2p.dOut = $D_OUT" $QUIL_CONFIG_FILE
yq -i ".p2p.dScore = $D_SCORE" $QUIL_CONFIG_FILE
