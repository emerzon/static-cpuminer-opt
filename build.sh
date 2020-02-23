docker build -t cpu .
CID=$(sudo docker create cpu)
hash=$(cat /proc/cpuinfo | grep flags | uniq | md5sum | cut -b 1-8)
sudo docker cp ${CID}:/usr/src/cpuminer-opt/cpuminer ./cpuminer-opt-${hash}
sudo docker cp ${CID}:/usr/src/cpuminer-RKZ/cpuminer ./cpuminer-rkz-${hash}
sudo docker cp ${CID}:/usr/src/xmrig/build/xmrig ./xmrig-${hash}
sudo docker rm ${CID}
