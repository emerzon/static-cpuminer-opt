#!/bin/bash
sudo docker build --pull -t cpu -f Dockerfile.alpine .
CID=$(sudo docker create cpu)
hash=$(cat /proc/cpuinfo | grep flags | uniq | md5sum | cut -b 1-8)
mkdir -p artifacts
sudo docker cp ${CID}:/usr/src/cpuminer-opt/cpuminer artifacts/cpuminer-opt-musl-${hash}
sudo docker cp ${CID}:/usr/src/cpuminer-gr-avx2/cpuminer artifacts/cpuminer-gr-musl-${hash}
#sudo docker cp ${CID}:/usr/src/xmrig/build/xmrig artifacts/xmrig-${hash}
#sudo docker cp ${CID}:/usr/src/xmrig-upx/build/xmrig artifacts/xmrig-upx-${hash}
sudo docker rm ${CID}
[[ -d ~/linuxmining ]] && cp -fv artifacts/* ~/linuxmining/bin
