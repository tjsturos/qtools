#!/bin/bash

STATISTICS_DIR=$QTOOLS_PATH/grafana-statistics

mkdir -p $STATISTICS_DIR

cd $STATISTICS_DIR

append_to_file $STATISTICS_DIR/.env "service_name=$STATISTICS_SERVICE_NAME"

wget https://github.com/fpatron/Quilibrium-Dashboard/raw/master/grafana/exporter/quilibrium_exporter.py
wget https://github.com/fpatron/Quilibrium-Dashboard/raw/master/grafana/exporter/requirements.txt

sudo apt install -y python3 python3-pip python3-virtualenv

virtualenv venv
source venv/bin/activate
pip3 install -r $STATISTICS_DIR/requirements.txt

install_statistics_service() {
    echo "[Unit]
Description=Quilibrium Statistics Service
After=network.target
[Service]
User=$USER
Group=$USER
WorkingDirectory=$STATISTICS_DIR
ExecStart=$STATISTICS_DIR/venv/bin/python $STATISTICS_DIR/quilibrium_exporter.py
Restart=always
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/$STATISTICS_SERVICE_NAME.service
    sudo systemctl daemon-reload
    sudo systemctl enable $STATISTICS_SERVICE_NAME
    sudo systemctl start $STATISTICS_SERVICE_NAME
}

install_grafana_alloy() {
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null                              
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
    sudo apt update
    sudo apt-get install alloy -y
    DEFAULT_ALLOY_CONFIG_DESTINATION=/etc/alloy/config.alloy
    if [ -f $DEFAULT_ALLOY_CONFIG_DESTINATION ]; then
        DEFAULT_CONFIG_FILE=$QTOOLS_PATH/files/alloy.conf
        if [ -f $DEFAULT_CONFIG_FILE ]; then
            cp $DEFAULT_CONFIG_FILE $DEFAULT_ALLOY_CONFIG_DESTINATION

            # get the values from the config file
            PROMETHEUS_ENDPOINT=$(yq eval '.scheduled_tasks.statistics.prometheus.endpoint' $QTOOLS_CONFIG_FILE)
            PROMETHEUS_USERNAME=$(yq eval '.scheduled_tasks.statistics.prometheus.username' $QTOOLS_CONFIG_FILE)
            PROMETHEUS_PASSWORD=$(yq eval '.scheduled_tasks.statistics.prometheus.password' $QTOOLS_CONFIG_FILE)
            LOKI_ENDPOINT=$(yq eval '.scheduled_tasks.statistics.loki.endpoint' $QTOOLS_CONFIG_FILE)
            LOKI_USERNAME=$(yq eval '.scheduled_tasks.statistics.loki.username' $QTOOLS_CONFIG_FILE)
            LOKI_PASSWORD=$(yq eval '.scheduled_tasks.statistics.loki.password' $QTOOLS_CONFIG_FILE)
            
            # replace values in the alloy config file
            sed -i "s|<PROMETHEUS_ENDPOINT>|$PROMETHEUS_ENDPOINT|g" $DEFAULT_ALLOY_CONFIG_DESTINATION
            sed -i "s|<PROMETHEUS_USERNAME>|$PROMETHEUS_USERNAME|g" $DEFAULT_ALLOY_CONFIG_DESTINATION
            sed -i "s|<PROMETHEUS_PASSWORD>|$PROMETHEUS_PASSWORD|g" $DEFAULT_ALLOY_CONFIG_DESTINATION
            sed -i "s|<LOKI_ENDPOINT>|$LOKI_ENDPOINT|g" $DEFAULT_ALLOY_CONFIG_DESTINATION
            sed -i "s|<LOKI_USERNAME>|$LOKI_USERNAME|g" $DEFAULT_ALLOY_CONFIG_DESTINATION
            sed -i "s|<LOKI_PASSWORD>|$LOKI_PASSWORD|g" $DEFAULT_ALLOY_CONFIG_DESTINATION
            sed -i "s|<QUIL_SERVICE_NAME>|$QUIL_SERVICE_NAME|g" $DEFAULT_ALLOY_CONFIG_DESTINATION
        fi
    fi
}

install_statistics_service

install_grafana_alloy
