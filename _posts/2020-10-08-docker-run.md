---
layout: post
title: How to use docker run command
excerpt: "The docker run command is used to launch and run containers. Learning how to use docker run command is a recommendation for any developers who want to get familiar with Docker."
tags: [Docker]
image: /assets/thumbnails/pexels/docker.png
author: truongnh
---

<img src="/assets/thumbnails/pexels/docker.png">

{:.image-caption}
*Docker logo*


The docker run command is used to launch and run containers. Learning how to use `docker run` command is a recommendation for any developers who want to get familiar with Docker.

When working with Docker, software developers mostly use the `docker run` command to:

<!-- MarkdownTOC -->

[Run a container with a defined name](#-run-a-container-with-a-defined-name)  

[Run a container in the foreground](#-run-a-container-in-the-foreground)  

[Run a container in the detached mode](#-run-a-container-in-the-detached-mode)  

[Run a container in the interactive mode](#-run-a-container-in-the-interactive-mode)  

[Port-forwarding a container](#-port-forwarding-a-container)  

[Mounting volumes of a container](#-mounting-volumes-of-a-container)

[Remove a container once it stopped](#-remove-a-container-once-it-stopped)
<!-- /MarkdownTOC -->

Now, we will go to the detail of how to use the `docker run` with corresponding examples.

<a name="-docker-run-command"><a/>
## Docker run command

The syntax of the command:

```sh
$ docker run [options] image-name [command] [arg...]
```

In order to run a docker container, you can simply run the following command, assuming you have already installed docker:

```sh
$ docker run image-name
```

**Where:**

`image-name` could be a docker image on your local machine or be pulled from the online registry such as Docker Hub and Quay.io.

In the following example, you’ll run a container from a public image `hello-world` which is located on Docker Hub.

```sh
$ sudo docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
0e03bdcc26d7: Pull complete 
Digest: sha256:7f0a9f93b4aa3022c3a4c147a449bf11e0941a1fd0bf4a8e6c9408b2600777c5
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.
...
```

The first time you run the container, the Docker daemon pulls the image `hello-world` from the Docker Hub. Then, it creates a new container from that image and streams the output to your terminal. From now on, the image was download to your local machine. You can list all of the docker images by running:

```sh
$ sudo docker image ls
```

Output:

```console
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ubuntu              latest              4e2eef94cd6b        9 days ago          73.9MB
nginx               latest              4bb46517cac3        2 weeks ago         133MB
alpine              latest              a24bb4013296        3 months ago        5.57MB
truongnh1992/go     latest              57b4af3567ac        3 months ago        7.41MB
hello-world         latest              bf756fb1ae65        7 months ago        13.3kB
```

The next time you run that image, it is faster than the first one and you can use the IMAGE-ID instead of image name. For example:

```sh
$ sudo docker run bf756fb1ae65

Hello from Docker!
This message shows that your installation appears to be working correctly.
...
```

> **Note:** From the Docker version 1.13, due to the new syntax of its release, we use `docker container run` instead of `docker run`.


<a name="-run-a-container-with-a-defined-name"><a/>
## Run a container with a defined name

When you run a container with the basic syntax `docker container run`, the Docker will randomly generate a name for each container as you can see in the below:

```sh
$ sudo docker container ls -a
```

Output:

```console
CONTAINER ID        IMAGE               COMMAND             CREATED              STATUS                          PORTS               NAMES
941b67537bbb        ubuntu              "/bin/bash"         4 seconds ago        Exited (0) 3 seconds ago                            musing_elgamal
a7b197b56d2c        bf756fb1ae65        "/hello"            About a minute ago   Exited (0) About a minute ago                       determined_faraday
0b40e331161e        hello-world         "/hello"            4 minutes ago        Exited (0) 4 minutes ago                            nervous_sammet
```

If you want to explicitly assign a name for your container, let’s run the command with the following syntax:

```sh
$ docker container run --name container-name image-name
```

For example:

```sh
$ sudo docker container run --name hello-linoxide hello-world
```

Output:

```sh
$ sudo docker container ls -a
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS                      PORTS               NAMES
eb2f0c9cc658        hello-world         "/hello"            21 seconds ago      Exited (0) 20 seconds ago                       hello-linoxide
...
```

<a name="-run-a-container-in-the-foreground"><a/>
## Run a container in the foreground

When we working with docker containers, there are two modes of running them: `attached mode` and `detached mode`.

By default, Docker runs the container in foreground. It means container process attaches to the terminal session and displays the output. If the container is still running, it will not return the command prompt.

For example:

```sh
$ sudo docker container run nginx

/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
```

<a name="-run-a-container-in-the-detached-mode"><a/>
## Run a container in the detached mode

If you want to run that container in background process (detached mode), let’s use the `-d` option:

```sh
$ sudo docker container run -d nginx
4fd8f2933eafaebcc75ef4fe6d0a961f76d8fdbf64383caff7f422a25c60951f
```

<a name="-run-a-container-in-the-interactive-mode"><a/>
## Run a container in interactive mode

Docker supports running a container in the interactive mode. Thanks to this feature, you can execute commands inside a container with a shell.

Using the `-it` option following with `/bin/bash` or `/bin/sh` to launch the interactive mode, for example:

```sh
$ sudo docker container run -it ubuntu /bin/bash
root@d99e70bff763:/# echo $0
/bin/bash
```

```sh
$ sudo docker container run -it ubuntu /bin/sh
# echo $0
/bin/sh
```
<a name="-port-forwarding-a-container"><a/>
## Port-forwarding a container

By default, in order to access the process running inside a container, you have to go into inside it. If you want to access it from the outside, let’s open a port. By publishing ports, you can map the container ports to the ports on your host machine using `-p` option as follows:

```sh
$ dock container run -p host-port:container-port image
```

For example, to map port 80 of container nginx to port 8080 on the host machine, run:

```sh
$ sudo docker container run -d -p 8080:80 nginx
cd85a291dab1ff92fa2ee6275446f758baa8322de2b706f7b581a54825142c5b
```

Now, let's use `curl` to retrieve the content from localhost:8080

```sh
$ curl localhost:8080
```

Output:

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
...
```

<a name="-mounting-volumes-of-a-container"><a/>
## Mounting volumes of a container

Data in a container is ephemeral, it is no longer existed when the container is stopped. If you want to keep the data in the container persistently, you have to mount it to a shared storage volume.

Let’s use `-v` option as the follows for mounting volumes:

```sh
$ docker container run -v host-machine-location:container-storage image
```

For example, let’s mount the `share-data` directory on your host machine into `/home` in the container:

```sh
$ mkdir share-data/
$ echo "Hello linoxide readers" > share-data/test.txt
$ sudo docker container run -it -v $(pwd)/share-data:/home alpine
```

Output:

```sh
/ # ls /home/
test.txt
/ # cat /home/test.txt 
Hello linoxide readers
```

<a name="-remove-a-container-once-it-stopped"><a/>
## Remove a container once it stopped

By default, when a container stops, its file system still remains on the host machine. They consume a large mount of storage. If you want to automatically remove the container after it exits, use `--rm` option:

```sh
$ docker container run --rm image
```

For example, running a docker container without `--rm` option:

```sh
$ sudo docker container run ubuntu
$ sudo docker container ls -a
CONTAINER ID        IMAGE               COMMAND                  CREATED              STATUS                      PORTS                  NAMES
ad348fb61463        ubuntu              "/bin/bash"              8 seconds ago        Exited (0) 6 seconds ago                
```

When using `--rm` option, once the container stopped, it will be automatically removed.

```sh
$ sudo docker container run --rm ubuntu
$ sudo docker container ls -a
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```

## Conclusion

Docker is an opensource platform that enables software developers to build, deploy, and manage containerized applications. Docker is a really powerful tool for any developer especially DevOps engineers. Mastering the way to use `docker container run` commands is the key to discover the power of Docker.

Thanks for reading and please leave your suggestion in the below comment section.

*Author: [truongnh1992](https://github.com/truongnh1992)* - Email: nguyenhaitruonghp[at]gmail[dot]com

**P/s:** I also published this article on *linoxide.com*
