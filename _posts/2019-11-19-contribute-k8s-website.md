---
layout: post
title: Dịch tài liệu Kubernetes sang Tiếng Việt
excerpt: "Hiện tại đang có một số bạn muốn giúp dịch tài liệu của Kubernetes sang Tiếng Việt. K8s là dự án mã nguồn mở nên các hoạt động này là từ phía cộng đồng. Bạn nào có hứng thú với việc contribute thì đọc hướng dẫn này nhé."
tags: [Kubernetes]
author: truongnh
color: rgb(42,140,152)
---

#### Contents

<!-- MarkdownTOC -->
[1. Sign the CLA](#-sign-the-cla)  
[2. Fork the kubernetes/website repository](#-fork-a-repository)  
[3. Clone fork repository to local](#-clone-fork-repository-to-local)  
[4. Tạo branch mới để bắt đầu việc dịch tài liệu](#-create-a-branch)  
[5. Commit and Push](#-commit)   
[6. Create a Pull Request](#-create-a-pull-request)   
<!-- /MarkdownTOC -->

<a name="-sign-the-cla"><a/>
### 1. Sign the CLA

Để có thể contribute vào dự án [Kubernetes](https://github.com/kubernetes/) thì trước tiên bạn phải sign **The Contributor License Agreement**  

#### 1.1. Log in to the Linux Foundation ID Portal with Github

- Nếu bạn là contributor độc lập, click vào link: https://identity.linuxfoundation.org/?destination=node/285/individual-signup
- Nếu bạn đóng góp dưới danh nghĩa cty, click vào link: https://identity.linuxfoundation.org/?destination=node/285/employee-signup

#### 1.2. Create Linux Foundation ID Portal account with correct e-mail address

#### 1.3. Complete signing process

Sau khi tạo xong tài khoản, làm theo các hướng dẫn để hoàn tất việc signing qua HelloSign.

#### 1.4. Look for an email indicating successful signup

> The Linux Foundation
> 
> Hello,
> 
> You have signed CNCF Individual Contributor License Agreement. You can see your document anytime by clicking View on HelloSign.
> 

<a name="-fork-a-repository"><a/>
### 2. Fork the kubernetes/website repository
* Đi đến https://github.com/kubernetes/website
* Click vào nút `Fork` để fork repo kubernetes/website về github của bạn.


<a name="-clone-fork-repository-to-local"><a/>
### 3. Clone the forked repository to local

Clone repo đã được forked ở [bước trên](#-fork-a-repository) về máy của bạn.
```sh
$ git clone https://github.com/$user/website.git

$ cd website

$ git remote add upstream https://github.com/kubernetes/website.git

# Never push to upstream master
$ git remote set-url --push upstream no_push

# Confirm that your remotes make sense:
$ git remote -v
```
`$user` là account github của bạn.

<a name="-create-a-branch"><a/>
### 4. Tạo branch mới để bắt đầu việc dịch tài liệu

Update local working directory:

```sh
$ cd website

$ git fetch upstream

$ git checkout master

$ git rebase upstream/master
```

**Please don't use `git pull` instead of `git fetch / rebase`. `git pull` does a merge, which leaves merge commits. These make the commit history messy and violate the principle commits.**

Tạo branch mới: `mybranch` là tên bất kì, tùy thuộc vào PR bạn tạo.
```sh
$ git checkout -b mybranch
```

<a name="-commit"><a/>
### 5. Commit and Push

##### Commit

Việc dịch tài liệu này chúng ta sẽ tập trung vào việc thêm các file vào thư mục nội dung Tiếng Việt: https://github.com/kubernetes/website/tree/master/content/vi

Các bạn ra ngoài thư mục `content Tiếng Anh`: https://github.com/kubernetes/website/tree/master/content/en và chọn nội dung mà các bạn thấy hứng thú dịch rồi add file đã dịch xong vào thư mục tương ứng của [nội dung Tiếng Việt](https://github.com/kubernetes/website/tree/master/content/vi)

```sh
$ cd website/content/vi
$ git add <file-dịch>
```
Commit your changes:
```sh
$ git commit
```
Enter your commit message to describe the changes. See the tips for a good commit message at [here](https://chris.beams.io/posts/git-commit/).  
Likely you go back and edit/build/test some more then `git commit --amend`

##### Push

Push your branch `mybranch` to your forked repo on github.com.
```sh
$ git push -f $remotename mybranch
```

<a name="-create-a-pull-request"><a/>
### 6. Create a Pull Request

- Go to your fork at https://github.com/$user/website
- Hit the button ![PR](/static/img/github/compare-pullrequest) next to branch `mybranch`
- Flow the following processes to create a new pull request

