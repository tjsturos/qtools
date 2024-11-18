
CURRENT_STATE=$(cat /sys/devices/system/cpu/smt/control)

if [ "$CURRENT_STATE" != "on" ]; then
    echo "Disabling hyperthreading"
    sudo sh -c 'echo "on" > /sys/devices/system/cpu/smt/control'
else
    echo "Enabling hyperthreading"
    sudo sh -c 'echo "off" > /sys/devices/system/cpu/smt/control'
fi
