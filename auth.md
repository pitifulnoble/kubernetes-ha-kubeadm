# 理解认证授权
## 1. 认证授权的概念
#### 1.1 为什么要认证
想理解认证，我们得从认证解决什么问题、防止什么问题的发生入手。
防止什么问题呢？是防止有人入侵你的集群，root你的机器后让我们集群依然安全吗？不是吧，root都到手了，那就为所欲为，防不胜防了。
其实网络安全本身就是为了解决在某些假设成立的条件下如何防范的问题。比如一个非常重要的假设就是两个节点或者ip之间的通讯网络是不可信任的，可能会
被第三方窃取，也可能会被第三方篡改。就像我们上学时候给心仪的女孩传纸条，传送的过程可能会被别的同学偷看，甚至内容可能会从我喜欢你修改成我不喜
欢你了。当然这种假设不是随便想出来的，而是从网络技术现状和实际发生的问题中发现、总结出来的。kubernetes的认证也是从这个问题出发来实现的。
#### 1.2 概念梳理
为了解决上面说的问题，kubernetes并不需要自己想办法，毕竟是网络安全层面的问题，是每个服务都会遇到的问题，业内也有成熟的方案来解决。这里我们一
起了解一下业内方案和相关的概念。
- **对称加密/非对称加密**
这两个概念属于密码学的东西，对于没接触过的同学不太容易理解。可以参考知乎大神的生动讲解：[《如何用通俗易懂的话来解释非对称加密》][1]
- **SSL/TLS**
了解了对称加密和非对称加密后，我们就可以了解一下SSL/TLS了。同样，已经有大神总结了非常好的入门文章：[《SSL/TLS协议运行机制的概述》][2]

#### 1.3 什么是授权
授权的概念就简单多了，就是什么人具有什么样的权限，一般通过角色作为纽带把他们组合在一起。也就是一个角色一边拥有多种权限，一边拥有多个人。这样
就把人和权限建立了一个关系。
## 2. kubernetes的认证授权
Kubernetes集群的所有操作基本上都是通过kube-apiserver这个组件进行的，它提供HTTP RESTful形式的API供集群内外客户端调用。需要注意的是：认证授权>过程只存在HTTPS形式的API中。也就是说，如果客户端使用HTTP连接到kube-apiserver，那么是不会进行认证授权的。所以说，可以这么设置，在集群内部组件
间通信使用HTTP，集群外部就使用HTTPS，这样既增加了安全性，也不至于太复杂。
对APIServer的访问要经过的三个步骤，前面两个是认证和授权，第三个是 Admission Control，它也能在一定程度上提高安全性，不过更多是资源管理方面的>作用。
#### 2.1 kubernetes的认证
kubernetes提供了多种认证方式，比如客户端证书、静态token、静态密码文件、ServiceAccountTokens等等。你可以同时使用一种或多种认证方式。只要通过>任何一个都被认作是认证通过。下面我们就认识几个常见的认证方式。
- **客户端证书认证**
客户端证书认证叫作TLS双向认证，也就是服务器客户端互相验证证书的正确性，在都正确的情况下协调通信加密方案。
为了使用这个方案，api-server需要用--client-ca-file选项来开启。
- **引导Token**
当我们有非常多的node节点时，手动为每个node节点配置TLS认证比较麻烦，这时就可以用到引导token的认证方式，前提是需要在api-server开启 experimental-bootstrap-token-auth 特性，客户端的token信息与预先定义的token匹配认证通过后，自动为node颁发证书。当然引导token是一种机制，可以用到各种场景
中。
- **Service Account Tokens 认证**
有些情况下，我们希望在pod内部访问api-server，获取集群的信息，甚至对集群进行改动。针对这种情况，kubernetes提供了一种特殊的认证方式：Service Account。 Service Account 和 pod、service、deployment 一样是 kubernetes 集群中的一种资源，用户也可以创建自己的 Service Account。
ServiceAccount 主要包含了三个内容：namespace、Token 和 CA。namespace 指定了 pod 所在的 namespace，CA 用于验证 apiserver 的证书，token 用作身
份验证。它们都通过 mount 的方式保存在 pod 的文件系统中。
#### 2.2 kubernetes的授权
在Kubernetes1.6版本中新增角色访问控制机制（Role-Based Access，RBAC）让集群管理员可以针对特定使用者或服务账号的角色，进行更精确的资源访问控制
。在RBAC中，权限与角色相关联，用户通过成为适当角色的成员而得到这些角色的权限。这就极大地简化了权限的管理。在一个组织中，角色是为了完成各种工
作而创造，用户则依据它的责任和资格来被指派相应的角色，用户可以很容易地从一个角色被指派到另一个角色。
目前 Kubernetes 中有一系列的鉴权机制，因为Kubernetes社区的投入和偏好，相对于其它鉴权机制而言，RBAC是更好的选择。具体RBAC是如何体现在kubernetes系统中的我们会在后面的部署中逐步的深入了解。
#### 2.3 kubernetes的AdmissionControl
AdmissionControl - 准入控制本质上为一段准入代码，在对kubernetes api的请求过程中，顺序为：先经过认证 & 授权，然后执行准入操作，最后对目标对象
进行操作。这个准入代码在api-server中，而且必须被编译到二进制文件中才能被执行。
在对集群进行请求时，每个准入控制代码都按照一定顺序执行。如果有一个准入控制拒绝了此次请求，那么整个请求的结果将会立即返回，并提示用户相应的error信息。
常用组件（控制代码）如下：
- AlwaysAdmit：允许所有请求
- AlwaysDeny：禁止所有请求，多用于测试环境
- ServiceAccount：它将serviceAccounts实现了自动化，它会辅助serviceAccount做一些事情，比如如果pod没有serviceAccount属性，它会自动添加一个default，并确保pod的serviceAccount始终存在
- LimitRanger：他会观察所有的请求，确保没有违反已经定义好的约束条件，这些条件定义在namespace中LimitRange对象中。如果在kubernetes中使用LimitRange对象，则必须使用这个插件。
- NamespaceExists：它会观察所有的请求，如果请求尝试创建一个不存在的namespace，则这个请求被拒绝。

[1]:https://www.zhihu.com/question/33645891/answer/57721969
[2]:http://www.ruanyifeng.com/blog/2014/02/ssl_tls.html
