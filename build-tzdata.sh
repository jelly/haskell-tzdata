#!/bin/bash

set -e

VER=2016e

base=$(dirname $(readlink -f $0))
cd $base

echo Downloading... >&2
wget -c http://www.iana.org/time-zones/repository/releases/tzdata$VER.tar.gz
wget -c http://www.iana.org/time-zones/repository/releases/tzcode$VER.tar.gz
wget -c http://www.iana.org/time-zones/repository/releases/tzdata$VER.tar.gz.asc
wget -c http://www.iana.org/time-zones/repository/releases/tzcode$VER.tar.gz.asc

echo Checking... >&2
gpg --verify tzdata$VER.tar.gz.asc
gpg --verify tzcode$VER.tar.gz.asc
sha512sum -c /dev/stdin <<EOF
dcaf615ada96920e60ffb336253f53541861153decc156d41661f43e0bfb128c6c231b0b776bbe3f2176549346275fc5a879074f4977d5141228e58cb33a41c6  tzcode$VER.tar.gz
dace0f6fc87a73879ca3a1b143d7dcf9c50803e23e6b8c91f83711704e28129af776676c547c42f14dee7f1e8e285ce25296e53a52d11f4c8f155b5f80f4beb3  tzdata$VER.tar.gz
EOF

echo Unpacking... >&2
rm -rf ./tzdist
mkdir tzdist
cd tzdist
tar xzf ../tzcode$VER.tar.gz
tar xzf ../tzdata$VER.tar.gz

echo Building... >&2
make TOPDIR=$base/tzdist/dest install

echo Renaming... >&2
cd $base
rm -rf tzdata
mv tzdist/dest/etc/zoneinfo tzdata
cd tzdata
find . -type f -name '[A-Z]*' -exec mv '{}' '{}.zone' \;
rm localtime posixrules

echo Building symlinked zoneinfo for compilation... >&2
cd $base/tzdist
make clean
make TOPDIR=$base/tzdist/dest CFLAGS=-DHAVE_LINK=0 install

echo Cleaning up zoneinfo root directory... >&2
cd $base/tzdist/dest/etc/zoneinfo
# We don't want these:
rm -f *.tab Factory posixrules localtime
mkdir Root
find . -maxdepth 1 -type f -exec mv '{}' Root \;
for f in Root/*; do ln -s $f .; done

echo Compiling the tool... >&2
cd $base
stack build tools/

echo Creating DB.hs... >&2
cd $base
stack exec genZones tzdist/dest/etc/zoneinfo/ Data/Time/Zones/DB.hs.template Data/Time/Zones/DB.hs
