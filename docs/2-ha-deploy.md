# 二. 搭建高可用集群
## 1. 部署keepalived - apiserver高可用（任选两个master节点）
#### 1.1 安装keepalived
```bash
# 在两个主节点上安装keepalived（一主一备）
$ yum install -y keepalived
```
#### 1.2 创建keepalived配置文件
```bash
# 创建目录
$ ssh <user>@<master-ip> "mkdir -p /etc/keepalived"
$ ssh <user>@<backup-ip> "mkdir -p /etc/keepalived"

# 分发配置文件
$ scp target/configs/keepalived-master.conf <user>@<master-ip>:/etc/keepalived/keepalived.conf
$ scp target/configs/keepalived-backup.conf <user>@<backup-ip>:/etc/keepalived/keepalived.conf

# 分发监测脚本
$ scp target/scripts/check-apiserver.sh <user>@<master-ip>:/etc/keepalived/
$ scp target/scripts/check-apiserver.sh <user>@<backup-ip>:/etc/keepalived/
```

#### 1.3 启动keepalived
```bash
# 分别在master和backup上启动服务
$ systemctl enable keepalived && service keepalived start

# 检查状态
$ systemctl status keepalived

# 查看日志
$ journalctl -f -u keepalived

# 查看虚拟ip
$ ip a
```

## 2. 部署第一个主节点
```bash
# 准备配置文件
$ scp target/configs/kubeadm-config.yaml <user>@<node-ip>:~
# ssh到第一个主节点，执行kubeadm初始化系统（注意保存最后打印的加入集群的命令）
# $ kubeadm init --config=kubeadm-config.yaml --experimental-upload-certs
$ kubeadm init --config=kubeadm-config.yaml --upload-certs
# copy kubectl配置（上一步会有提示）
$ mkdir -p ~/.kube
$ cp -i /etc/kubernetes/admin.conf ~/.kube/config

# 测试一下kubectl
$ kubectl get pods --all-namespaces

# **备份init打印的join命令**

```

## 3. 部署网络插件 - calico
我们使用calico官方的安装方式来部署，请参阅下面的地址

[Calico配置文件说明](https://docs.projectcalico.org/getting-started/kubernetes/self-managed-onprem/onpremises#install-calico-with-kubernetes-api-datastore-50-nodes-or-less)

```bash
# 创建目录（在配置了kubectl的节点上执行）
$ mkdir -p /etc/kubernetes/addons

# 上传calico配置到配置好kubectl的节点（一个节点即可）
$ scp target/addons/calico* <user>@<node-ip>:/etc/kubernetes/addons/

# addons 有两个配置文件 具体的内容请参阅 上面的那个 Calico配置文件说明 链接地址
# less-50-calico.yaml 节点数量小于50使用的配置文件
# more-50-calico.yaml 节点数量大于50台使用的配置文件

# 官方提供的地址
# 当节点数量大于 50台的时候使用
# curl https://docs.projectcalico.org/manifests/calico-typha.yaml -o calico.yaml
# 当节点数量小于50台使用
# curl https://docs.projectcalico.org/manifests/calico.yaml -O

# 部署calico
# 修改文件名称，根据具体的情况自行修改
$ mv /etc/kubernetes/addons/less-50-calico.yaml calico.yaml
$ kubectl apply -f /etc/kubernetes/addons/calico.yaml

# 查看状态
$ kubectl get pods -n kube-system
```
## 4. 加入其它master节点
```bash
# 使用之前保存的join命令加入集群
$ kubeadm join ...
# 例如：
$ kubeadm join 172.16.249.133:6443 --token 8mr8km.w3ucsw6gbq50ffpw \
    --discovery-token-ca-cert-hash sha256:b7eb3ab4c45577386a6801e166aa7d844a246b5afcaf7890126e1a95bfad3d30 \
    --control-plane --certificate-key d5c80e1843f6b0f5eddb0c88d215390dbe2c0ef6d4f6b63463b3c2ef6dfd726e

# 耐心等待一会，并观察日志
$ journalctl -f

# 查看集群状态
# 1.查看节点
$ kubectl get nodes
# 2.查看pods
$ kubectl get pods --all-namespaces

# 遇到问题
# certificate-key 默认2小时的有效期，如果过期按照提示重新生成
error execution phase control-plane-prepare/download-certs: error downloading certs: error downloading the secret: Secret "kubeadm-certs" was not found in the "kube-system" Namespace. This Secret might have expired. Please, run `kubeadm init phase upload-certs --upload-certs` on a control plane to generate a new one
# 使用命令重新生成 certificate-key 
# 用新证书替换--certificate-key后面的内容
# 如上面的命令中的:d5c80e1843f6b0f5eddb0c88d215390dbe2c0ef6d4f6b63463b3c2ef6dfd726e
$ kubeadm init phase upload-certs --upload-certs
[upload-certs] Using certificate key:
a542b8308394773278da70ab0d11914f6e048fcd73524ecfef56b3633a39d3f1

```

## 5. 加入worker节点
```bash
# 使用之前保存的join命令加入集群
$ kubeadm join ...
# 例如
$ kubeadm join 172.16.249.133:6443 --token 8mr8km.w3ucsw6gbq50ffpw \
    --discovery-token-ca-cert-hash sha256:b7eb3ab4c45577386a6801e166aa7d844a246b5afcaf7890126e1a95bfad3d30

# 耐心等待一会，并观察日志
$ journalctl -f

# 查看节点
$ kubectl get nodes
# 重新添加节点
# 默认情况下，kubeadm init产生的token的有效期是24个小时,在一天之后才kubeadm join的,用下面的命令来重新产生token
$ kubeadm token create --certificate-key xxxx --print-join-command
例如
kubeadm token create --certificate-key a542b8308394773278da70ab0d11914f6e048fcd73524ecfef56b3633a39d3f1 --print-join-command
# 直接使用 kubeadm token create --print-join-command 也可以
```

