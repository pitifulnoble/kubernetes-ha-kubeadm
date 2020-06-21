# kubernetes的网络插件（CNI）
在网络层面，kubernetes没有进入的更底层的具体container的网络互通互联的解决方案的设计中，而是将网络互通功能一分为二，主要关注kubernetes的服务在网络中的暴露以及POD本身网络的配置动作，但是POD具体需要配置的网络参数以及service、POD之间的互通互联，则交给CNI来解决。

### CNI介绍
CNI(container network interface)的目的在于定义一个标准的接口规范，使得kubernetes在增删POD的时候，能够按照规范向CNI实例提供标准的输入并获取标准的输出，再将输出作为kubernetes管理这个POD的网络的参考。

在满足这个输入输出以及调用标准的CNI规范下，kubernetes委托CNI实例去管理POD的网络资源并为POD建立互通能力。

CNI本身实现了一些基本的插件(https://github.com/containernetworking/plugins)， 比如bridge、ipvlan、macvlan、loopback、vlan等网络接口管理插件，还有dhcp、host-local等IP管理插件，并且主流的container网络解决方案都有对应CNI的支持能力，比如Calico、Canal、Flannel、Kube-Router、Weave等。
其中kube-router算是官方方案，并且是基于BGP协议，非常简单高效，但目前还处于beta版本，所以不在我们考虑范围。
我们这里主要比较两种主流的方案：**Calico VS Flannel**

### Flannel
通过给每台宿主机分配一个子网的方式为容器提供虚拟网络，它基于Linux TUN/TAP，使用UDP封装IP包来创建overlay网络，并借助etcd维护网络的分配情况。

控制平面上host本地的flanneld负责从远端的ETCD集群同步本地和其它host上的subnet信息，并为POD分配IP地址。数据平面flannel通过Backend（比如UDP封装）来实现L3 Overlay，既可以选择一般的TUN设备又可以选择VxLAN设备。
flannel.png![Alt text](https://gitee.com/pa/kubernetes/raw/master/images/flannel.png)
> **优点：**
- 配置安装简单，使用方便
- 与公有云集成方便

> **缺点：**
- Vxlan模式对平滑重启支持不好（重启需要数秒来刷新ARP表，且不可变更配置，例如VNI、iface）
- 功能相对简单，不支持Network Policy
- Overlay存在一定Overhead

### Calico
Calico是一个纯三层的数据中心网络方案（不需要Overlay），并且与OpenStack、Mesos、Kubernetes、AWS、GCE等IaaS和容器平台都有良好的集成。

Calico是一个专门做数据中心网络的开源项目。当业界都痴迷于Overlay的时候，Calico实现multi-host容器网络的思路确可以说是返璞归真——pure L3，pure L3是指容器间的组网都是通过IP来完成的。这是因为，Calico认为L3更为健壮，且对于网络人员更为熟悉，而L2网络由于控制平面太弱会导致太多问题，排错起来也更加困难。那么，如果能够利用好L3去设计数据中心的话就完全没有必要用L2。

如下图所示，描述了从源容器经过源宿主机，经过数据中心的路由，然后到达目的宿主机最后分配到目的容器的过程。
![Alt text](https://gitee.com/pa/kubernetes/raw/master/images/calico.png)
整个过程中始终都是根据iptables规则进行路由转发，并没有进行封包，解包的过程，这和flannel比起来效率就会快多了。

> **优点：**
- 没有封包解包，性能高
- 丰富而灵活的网络Policy
- 支持Network Policy

> **缺点：**
- 多租户的地址没法Overlap

### 对比
从上述的原理可以看出，flannel在进行路由转发的基础上进行了封包解包的操作，这样浪费了CPU的计算资源。下图是从网上找到的各个开源网络组件的性能对比。可以看出无论是带宽还是网络延迟，calico和主机的性能是差不多的。
![Alt text](https://gitee.com/pa/kubernetes/raw/master/images/compare.png)
