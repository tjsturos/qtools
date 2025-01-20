#! /bin/bash

# Install Flint

wget http://ftp.de.debian.org/debian/pool/main/g/gf2x/libgf2x3_1.3.0-1+b1_amd64.deb
sudo dpkg -i libgf2x3_1.3.0-1+b1_amd64.deb

wget http://ftp.de.debian.org/debian/pool/main/n/ntl/libntl43_11.4.3-1+b1_amd64.deb
sudo dpkg -i libntl43_11.4.3-1+b1_amd64.deb
wget http://ftp.de.debian.org/debian/pool/main/f/flint/libflint-2.6.3_2.6.3-3_amd64.deb
sudo dpkg -i libflint-2.6.3_2.6.3-3_amd64.deb

