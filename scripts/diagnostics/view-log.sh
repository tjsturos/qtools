#!/bin/bash
sudo journalctl -u ceremonyclient.service -f --no-hostname -o cat