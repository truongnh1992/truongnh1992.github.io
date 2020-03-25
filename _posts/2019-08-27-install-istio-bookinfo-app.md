---
layout: post
title: Install Istio and deploy Bookinfo application on a Kubernetes cluster
excerpt: "Istio is an opensource platform to connect, manage and secure microservices. This article will show you the way to deploy Istio and Bookinfo on a K8s cluster steps-by-steps."
tags: [Kubernetes, Istio]
author: truongnh
---

Istio is an opensource platform to connect, manage and secure microservices. This article will show you the way to deploy Istio and Bookinfo app on a K8s cluster steps-by-steps.

![istio](/static/img/istio.jpg)

{:.image-caption}
*Illustration: Istio means "sail" in Greek. Source: Internet*

### Installing Istio

#### 1. Download Istio
```sh
curl -L https://git.io/getLatestIstio | ISTIO_VERSION=1.1.0 sh -
```
#### 2. Install all the Istio Custom Resource Definitions (CRDs)
```sh
cd istio-1.1.0
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
```

#### 3. Install istio-demo
```sh
kubectl apply -f install/kubernetes/istio-demo.yaml
```


#### 4. Uninstall Istio

```sh
kubectl delete -f install/kubernetes/istio-demo.yaml

for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl delete -f $i; done
```

### Installing Bookinfo app

#### 1. Label the namespace that will host the application with `istio-injection=enabled`
```sh
kubectl label namespace default istio-injection=enabled
```

#### 2. Deploy Bookinfo application
```sh
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

To confirm that the Bookinfo application is running.
```sh
kubectl exec -it $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage | grep -o "<title>.*</title>"

<title>Simple Bookstore App</title>
```

#### 3. Clean Bookinfo
```sh
samples/bookinfo/platform/kube/cleanup.sh
```

### Determining the ingress IP and port

#### 1. Define the ingress gateway for the application
```sh
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

#### 2. Confirm the gateway has been created
```sh
kubectl get gateway

NAME               AGE
bookinfo-gateway   32s
```

#### 3. Set the `INGRESS_HOST` and `INGRESS_PORT` for accessing the gateway

Setting the ingress ports:
```sh
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
```

Setting the ingress IP:
```sh
export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
```

#### 4. Set `GATEWAY_URL`
```sh
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
```

#### 5. Confirm the app is accessible from outside the cluster
Using web browser and goto `http://${GATEWAY_URL}/productpage` or:
```sh
curl -s http://${GATEWAY_URL}/productpage | grep -o "<title>.*</title>"

<title>Simple Bookstore App</title>
```



Author: [truongnh1992](https://github.com/truongnh1992) - Email: nguyenhaitruonghp[at]gmail[dot]com
