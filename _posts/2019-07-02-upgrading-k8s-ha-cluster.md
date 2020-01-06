---
layout: post
title: Upgrading kubeadm HA cluster from v1.13.5 to v1.14.0 (stacked etcd)
excerpt: "kubeadm is a tool which is a part of the Kubernetes project. It helps you deploy a Kubernetes cluster. This article will show you the way to upgrade a Highly Available Kubernetes cluster from v1.13.5 to v1.14.0"
tags: [Kubernetes]
author: truongnh
color: rgb(42,140,168)
---

kubeadm is a tool which is a part of the Kubernetes project. It helps you deploy a Kubernetes cluster. This article will show you the way to upgrade a Highly Available Kubernetes cluster from v1.13.5 to v1.14.0

**Contents:**


<!-- MarkdownTOC -->
[1. Deploying multi-master nodes (High Availability) K8S](#-deploying-ha-cluster)  

[2. Upgrading the first control plane node (Master 1)](#-upgrading-master-1)  

[3. Upgrading additional control plane nodes (Master 2 and Master 3)](#-upgrading-additional-control-plane-nodes)  

[4. Upgrading worker nodes (worker 1, worker 2 and worker 3)](#-upgrading-worker-nodes)

[5. Verify the status of cluster](#-verify)  

[6. References](#-refers)
<!-- /MarkdownTOC -->

<a name="-deploying-ha-cluster"><a/>
## 1. Deploying multi-master nodes (High Availability) K8S
Following [this tutorial guide](https://truongnh1992.github.io/tutorials/kubernetes/2019/01/31/ha-cluster-with-kubeadm.html) to setup cluster.  
The bare-metal server runs Ubuntu Server 16.04 and there are 7 Virtual Machine (VMs) will be installed on it. Both of the VMs also run Ubuntu Server 16.04.

* 3 master nodes
* 3 worker nodes
* 1 HAproxy load balancer

![nodes_configuration](/static/img/multi-master-ha/stacketcd.png)

{:.image-caption}
*The stacked etcd cluster*

**The result:**

```sh
master1@k8s-master1:~$ sudo kubectl get node
NAME          STATUS   ROLES    AGE   VERSION
k8s-master1   Ready    master   20h   v1.13.5
k8s-master2   Ready    master   19h   v1.13.5
k8s-master3   Ready    master   19h   v1.13.5
k8s-worker1   Ready    <none>   19h   v1.13.5
k8s-worker2   Ready    <none>   19h   v1.13.5
k8s-worker3   Ready    <none>   19h   v1.13.5
```

<a name="-upgrading-master-1"><a/>
## 2. Upgrading the first control plane node (Master 1)

**2.1. Find the version to upgrade to**

```sh
sudo apt update
sudo apt-cache policy kubeadm
```

**2.2. Upgrade the control plane (master) node**

```sh
sudo apt-mark unhold kubeadm
sudo apt update && sudo apt upgrade
sudo apt-get install kubeadm=1.14.0-00
sudo apt-mark hold kubeadm
```

**2.3. Verify that the download works and has the expected version**

```sh
sudo kubeadm version
```

**2.4. Modify `configmap/kubeadm-config` for this control plane node and remove the `etcd` section completely**

```sh
sudo kubectl edit configmap -n kube-system kubeadm-config
```

```yaml
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  ClusterConfiguration: |
    apiServer:
      certSANs:
      - 10.164.178.238
      extraArgs:
        authorization-mode: Node,RBAC
      timeoutForControlPlane: 4m0s
    apiVersion: kubeadm.k8s.io/v1beta1
    certificatesDir: /etc/kubernetes/pki
    clusterName: kubernetes
    controlPlaneEndpoint: 10.164.178.238:6443
    controllerManager: {}
    dns:
      type: CoreDNS
    etcd:
      local:
        dataDir: /var/lib/etcd
    imageRepository: k8s.gcr.io
    kind: ClusterConfiguration
    kubernetesVersion: v1.14.0
    networking:
      dnsDomain: cluster.local
      podSubnet: ""
      serviceSubnet: 10.96.0.0/12
    scheduler: {}
  ClusterStatus: |
    apiEndpoints:
      k8s-master1:
        advertiseAddress: 10.164.178.161
        bindPort: 6443
      k8s-master2:
        advertiseAddress: 10.164.178.162
        bindPort: 6443
      k8s-master3:
        advertiseAddress: 10.164.178.163
        bindPort: 6443
    apiVersion: kubeadm.k8s.io/v1beta1
    kind: ClusterStatus
kind: ConfigMap
metadata:
  creationTimestamp: "2019-05-21T10:08:03Z"
  name: kubeadm-config
  namespace: kube-system
  resourceVersion: "209870"
  selfLink: /api/v1/namespaces/kube-system/configmaps/kubeadm-config
  uid: 52419642-7bb0-11e9-8a89-0800270fde1d
```

**2.5. Upgrade the `kubelet` and `kubectl`**

```sh
sudo apt-mark unhold kubelet
sudo apt-get install kubelet=1.14.0-00 kubectl=1.14.0-00
sudo systemctl restart kubelet
```

**2.6. Start the upgrade**

```sh
sudo kubeadm upgrade apply v1.14.0
```

> Logs of the upgrading process can be found [here](https://raw.githubusercontent.com/truongnh1992/upgrade-kubeadm-cluster/8da34b5f83bd7bb04914edf42fbaf84db2abae29/logs/cluster-upgraded-to-v1140).

<a name="-upgrading-additional-control-plane-nodes"><a/>
## 3. Upgrading additional control plane nodes (Master 2 and Master 3)

**3.1. Find the version to upgrade to**

```sh
sudo apt update
sudo apt-cache policy kubeadm
```

**3.2. Upgrade `kubeadm`**

```sh
sudo apt-mark unhold kubeadm
sudo apt update && sudo apt upgrade
sudo apt-get install kubeadm=1.14.0-00
sudo apt-mark hold kubeadm
```

**3.3. Verify that the download works and has the expected version**

```sh
sudo kubeadm version
```

**3.4. Upgrade the `kubelet` and `kubectl`**

```sh
sudo apt-mark unhold kubelet
sudo apt-get install kubelet=1.14.0-00 kubectl=1.14.0-00
sudo systemctl restart kubelet
```

**3.5. Start the upgrade**

```sh
master2@k8s-master2:~$ sudo kubeadm upgrade node experimental-control-plane
```

```sh
master3@k8s-master3:~$ sudo kubeadm upgrade node experimental-control-plane
```

> Logs when upgrading master 2: [log-master2](https://raw.githubusercontent.com/truongnh1992/upgrade-kubeadm-cluster/master/logs/logs-master2)

> Logs when upgrading master 3: [log-master3](https://raw.githubusercontent.com/truongnh1992/upgrade-kubeadm-cluster/master/logs/logs-master3)

<a name="-upgrading-worker-nodes"><a/>
## 4. Upgrading worker nodes (worker 1, worker 2 and worker 3)

**4.1. Upgrade `kubeadm` on all worker nodes**

```sh
sudo apt-mark unhold kubeadm
sudo apt update && sudo apt upgrade
sudo apt-get install kubeadm=1.14.0-00
sudo apt-mark hold kubeadm
```

**4.2. Cordon the worker node, on the `Master node`, run:**

```sh
sudo kubectl drain $WORKERNODE --ignore-daemonsets
```
**4.3. Upgrade the `kubelet` config on `worker nodes`**

```sh
sudo kubeadm upgrade node config --kubelet-version v1.14.0
```
**4.4. Upgrade `kubelet` and `kubectl`**

```sh
sudo apt update && sudo apt upgrade
sudo apt-get install kubelet=1.14.0-00 kubectl=1.14.0-00
sudo systemctl restart kubelet
```
**4.5. Uncordon the worker nodes, bring the node back online by marking it schedulable**

```sh
sudo kubectl uncordon $WORKERNODE
```
<a name="-verify"><a/>
## 5. Verify the status of cluster

```sh
master1@k8s-master1:~$ sudo kubectl get node
NAME          STATUS   ROLES    AGE   VERSION
k8s-master1   Ready    master   21h   v1.14.0
k8s-master2   Ready    master   21h   v1.14.0
k8s-master3   Ready    master   21h   v1.14.0
k8s-worker1   Ready    <none>   20h   v1.14.0
k8s-worker2   Ready    <none>   20h   v1.14.0
k8s-worker3   Ready    <none>   20h   v1.14.0
```
<a name="-refers"><a/>
## 6. References

[1] https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade-ha-1-13/  
[2] https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade-1-14/  
[3] https://github.com/truongnh1992/upgrade-kubeadm-cluster  

Author: [truongnh1992](https://github.com/truongnh1992) - Email: nguyenhaitruonghp[at]gmail[dot]com
