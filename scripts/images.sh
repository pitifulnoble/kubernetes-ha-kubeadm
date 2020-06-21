#!/bin/bash

docker pull 172.16.249.159:8082/calico/node:v3.14.1
docker tag 172.16.249.159:8082/calico/node:v3.14.1 calico/node:v3.14.1
docker rmi 172.16.249.159:8082/calico/node:v3.14.1

docker pull 172.16.249.159:8082/calico/typha:v3.14.1
docker tag 172.16.249.159:8082/calico/typha:v3.14.1 calico/typha:v3.14.1
docker rmi 172.16.249.159:8082/calico/typha:v3.14.1

docker pull 172.16.249.159:8082/calico/cni:v3.14.1
docker tag 172.16.249.159:8082/calico/cni:v3.14.1 calico/cni:v3.14.1
docker rmi 172.16.249.159:8082/calico/cni:v3.14.1

docker pull 172.16.249.159:8082/calico/kube-controllers:v3.14.1
docker tag 172.16.249.159:8082/calico/kube-controllers:v3.14.1 calico/kube-controllers:v3.14.1
docker rmi 172.16.249.159:8082/calico/kube-controllers:v3.14.1

docker pull 172.16.249.159:8082/calico/pod2daemon-flexvol:v3.14.1
docker tag 172.16.249.159:8082/calico/pod2daemon-flexvol:v3.14.1 calico/pod2daemon-flexvol:v3.14.1
docker rmi 172.16.249.159:8082/calico/pod2daemon-flexvol:v3.14.1
