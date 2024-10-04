is_master() {
    MAIN_IP=$(yq '.service.clustering.main_ip' $QTOOLS_CONFIG_FILE)
    if echo "$(hostname -I)" | grep -q "$MAIN_IP"; then
        return 0
    else
        return 1
    fi
}

