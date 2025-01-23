#!/bin/bash
 
export CFLAGS="-O3 -march=native -mtune=native"
export CXXFLAGS="-O3 -march=native -mtune=native"
 
pushd /tmp
 
curl -L https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz -o gmp-6.3.0.tar.xz
tar -xf gmp-6.3.0.tar.xz
pushd gmp-6.3.0
./configure --enable-cxx --disable-static
make -j $(nproc)
pushd tune
make tuneup
./tuneup > gmp-mparam.h
cp gmp-mparam.h ../mpn/x86_64/zen3/gmp-mparam.h
cp gmp-mparam.h ../mpn/x86_64/zen4/gmp-mparam.h
popd
make clean
make -j $(nproc)
make install
popd
rm -rf gmp-6.3.0
rm gmp-6.3.0.tar.xz
 
curl -L https://www.mpfr.org/mpfr-current/mpfr-4.2.1.tar.gz -o mpfr-4.2.1.tar.gz
tar -xf mpfr-4.2.1.tar.gz
pushd mpfr-4.2.1
./configure --disable-static
make -j $(nproc)
make install
popd
rm -rf mpfr-4.2.1
rm mpfr-4.2.1.tar.gz
 
curl -L https://flintlib.org/download/flint-3.1.2.tar.gz -o flint-3.1.2.tar.gz
tar -xf flint-3.1.2.tar.gz
pushd flint-3.1.2
(./configure --disable-static --enable-avx512 && make -j $(nproc)) || (./configure --disable-static --enable-avx2 && make -j $(nproc))
make install
popd
rm -rf flint-3.1.2
rm flint-3.1.2.tar.gz
 
popd
 
ldconfig /usr/local/lib
 