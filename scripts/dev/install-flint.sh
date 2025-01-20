#! /bin/bash

# Install Flint

cd $HOME
sudo apt-get install -y \
    build-essential \
    curl \
    git \
    cmake \
    libgmp-dev \
    libmpfr-dev \
    libmpfr6 \
    wget \
    m4 \
    pkg-config \
    gcc \
    g++ \
    make \
    autoconf \
    automake \
    libtool \
    && sudo rm -rf /var/lib/apt/lists/*

git clone https://github.com/flintlib/flint.git && \
    cd flint && \
    git checkout flint-3.0 && \
    ./bootstrap.sh && \
    ./configure \
        --prefix=/usr/local \
        --with-gmp=/usr/local \
        --with-mpfr=/usr/local \
        --enable-static \
        --disable-shared \
	CFLAGS="-O3" && \
    make && \
    make install