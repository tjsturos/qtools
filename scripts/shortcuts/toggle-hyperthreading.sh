
CURRENT_STATE=$(cat /sys/devices/system/cpu/smt/control)

MANUAL_STATE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --on)
            MANUAL_STATE="on"
            shift
            ;;
        --off)
            MANUAL_STATE="off" 
            shift
            ;;
        *)
            shift
            ;;
    esac
done

enable_hyperthreading() {
    echo "Enabling hyperthreading"
    sudo sh -c 'echo "on" > /sys/devices/system/cpu/smt/control'
}

disable_hyperthreading() {
    echo "Disabling hyperthreading"
    sudo sh -c 'echo "off" > /sys/devices/system/cpu/smt/control'
}

if [ "$MANUAL_STATE" == "on" ]; then        
    enable_hyperthreading
elif [ "$MANUAL_STATE" == "off" ]; then
    disable_hyperthreading
elif [ "$CURRENT_STATE" != "on" ]; then
    enable_hyperthreading
else
    disable_hyperthreading
fi
