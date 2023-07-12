---
layout: post
title: Một số tips hữu ích khi làm việc với K8s
excerpt: "Công việc của một DevOps Engineer sẽ hiệu quả và năng suất hơn nếu làm chủ được những công cụ này."
categories: Kubernetes DevOps
image: /assets/img/k8s-tips.jpeg
comments: false
---

<img src="/assets/img/k8s-tips.jpeg">

{:.image-caption}
*Source: https://www.cncf.io/phippy/the-childrens-illustrated-guide-to-kubernetes/*


### Shell Aliases

Thêm vào file `~/.bashrc` hoặc `~/.zshrc` những dòng dưới đây để thao tác với lệnh `kubectl` nhanh hơn:

```bash
alias k=kubectl
alias kg="kubectl get"
alias kgdep="kubectl get deployment"
alias ksys="kubectl --namespace=kube-system"
alias kd="kubectl describe"
```

### Auto-complete kubectl command

Sau khi thêm dòng dưới đây vào `~/.bashrc` hoặc `~/.zshrc`, bạn có thể dùng `<Tab> <Tab>` với lệnh `kubectl` rồi :)

```bash
source <(kubectl completion bash)
```

### Imperative modify resource

```bash
kubectl edit deployments my-deployment
```

### Generate Resource Manifests

```bash
kubectl run example-demo --image=truongnh1992/hello-server:2.0 --dry-run -o yaml > example-demo.yaml
```

### Get container log

```bash
kubectl logs [POD-NAME] -c [CONTAINER-NAME]
```

### Attach to a container

```sh
kubectl attach [POD-NAME] -c [CONTAINER-NAME]

If you don't see a command prompt, try pressing enter.
```

### Port-forward

```bash
kubectl port-forward [POD-NAME] [host-port]:[container-port]
```

### Execute command in container

```sh
kubectl run alpine --image alpine --command -- sleep 999
kubectl exec [POD] -- [COMMAND]
```

### Troubleshoot a running container

```sh
kubectl run demo --image truongnh1992/hello-server:1.0 --expose --port 8080

kubectl run wget --image=busybox:1.28 --rm -it --restart=Never -- wget -qO- http://demo:8080
```

***Tham khảo:*** [Cloud Native Devops with Kubernetes](https://www.amazon.com/Cloud-Native-DevOps-Kubernetes-Applications/dp/1492040762)