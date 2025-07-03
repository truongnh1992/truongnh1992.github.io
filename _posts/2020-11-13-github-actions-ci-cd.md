---
layout: post
title: CI/CD với Github Actions
excerpt: "Bài viết này sẽ hướng dẫn chi tiết cách setup một Github Action CI/CD pipeline để tự động build mã nguồn mỗi khi bạn push lên Github Repo thành một Docker Image và đẩy lên Docker Hub."
categories: Github DevOps CI/CD
image: /static/img/github-actions.png
comments: false
---

<img src="/static/img/github-actions.png">

{:.image-caption}
*Source: https://github.blog/2019-08-08-github-actions-now-supports-ci-cd/*

Một khảo sát của Jetbrains [(2020 Jetbrains developer survey)](https://www.jetbrains.com/lp/devecosystem-2020/) chỉ ra rằng: hiện có tới 44% nhà phát triển đang sử dụng các công cụ CI/CD với Docker Containers. Họ dùng [Docker Hub](https://hub.docker.com) để lưu trữ và chia sẻ các `docker images`.

Theo cách làm "cổ điển", các developer sẽ phải lập trình, viết `Dockerfile` rồi build `Docker image` tại môi trường local dev một cách thủ công rồi mới có thể push docker image đó lên Docker Hub. Mỗi khi có chỉnh sửa gì ở mã nguồn, quy trình trên lại lặp lại, như vậy sẽ rất tốn thời gian và công sức.

GitHub Actions và các công cụ [CI/CD](https://www.redhat.com/en/topics/devops/what-is-ci-cd) ra đời để giúp chúng ta giải quyết được bài toán trên. GitHub Actions giúp bạn tự động hoá được quy trình phát triển phần mềm, nó theo hướng "event-driven", mình có thể giải thích đơn giản thuật ngữ "event-driven" bằng ví dụ: Mỗi khi có ai đó tạo một Pull Request trên Github repo, hệ thống sẽ tự động chạy các testing scripts có thể là: check PEP8 ở code python hoặc đối với các project CNCF thì kiểm tra xem user đã sign CLA chưa?...  

Bài viết này sẽ hướng dẫn chi tiết cách setup một GitHub Action CI/CD pipeline để tự động **build** mã nguồn mỗi khi bạn **push lên Github Repo** thành một **Docker Image** và đẩy lên **Docker Hub**.

<img src="/static/img/github-actions/workflow.png">

{:.image-caption}
*CI/CD workflow*

## Github Repo

Ở hướng dẫn này, mình sẽ tạo mới một Github Repo tại địa chỉ: [https://github.com/truongnh1992/demo-github-actions](https://github.com/truongnh1992/demo-github-actions). 

Dockerfile sẽ được sử dụng để build file mã nguồn [main.go](https://github.com/truongnh1992/demo-github-actions/blob/main/main.go) thành một Docker Image. Image này đóng gói một ứng dụng webserver đơn giản phản hồi lại các HTTP request và trả về dòng text `Hello, Github Actions!`.

## Github Actions workflow

Đến đây, chúng ta sẽ đi sâu vào chi tiết việc cài đặt một Github Actions workflow. 
GitHub Actions sử dụng các `YAML` file để định nghĩa các thành phần của một `workflow`.

* **`Workflow`**: Workflow là một quy trình tự động mà bạn tạo trên Github Repository. Một workflow có thể bao gồm một hoặc nhiều jobs được lên lịch và được trigger bởi event.
* **`Jobs`**: Một job là một tập các `steps` được thực thi trên cùng một runner. Runner ở đây **không phải** là vận động viên chạy bộ đâu nhé :D => "The runner is the application that runs a job from a GitHub Actions workflow". Runner sẽ lắng nghe tất cả các jobs đang sẵn có, chạy từng job một và report các process, logs và kết quả chạy cho GitHub. Bạn có thể hiểu đơn giản là đối với GitHub-hosted runners, mỗi job trong một workflow sẽ chạy trong một `virtual environment` based on Ubuntu Linux, Microsoft Windows hoặc macOS.
* **`Steps`**: Một step là một task đơn lẻ chạy các commands trong một job. Một step có thể là một `action` hoặc một shell command. Mỗi step trong một Job thực thi trong cùng runner, điều này cho phép các action chia sẻ dữ liệu với nhau.
* **`Actions`**: Action là đơn vị nhỏ nhất trong một workflow. Các actions là các lệnh độc lập (standalone commands) được kết hợp thành các `steps` để tạo nên một `job`.

Để tạo mới một Github Action workflow, bạn sẽ phải tạo một directory `.github/workflows` trong GitHub repo. Ở ví dụ trong hướng dẫn này, mình sẽ tạo workflow file có tên là `build.yml`:

```yaml
name: CI to Docker Hub
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
```

Mình đặt tên của workflow là: **CI to Docker Hub**. Workflow này sẽ chạy khi bạn push code hoặc tạo Pull Request trên branch `main`. Tiếp theo sẽ đến công đoạn định nghĩa các jobs. Dưới đây, job `build-docker` chạy trên runner `ubuntu-latest`.

```yml
jobs:
  build-docker:
    runs-on: ubuntu-latest
```

Step đầu tiên trong jobs là `Checkout` code từ GitHub repository:

```yml
steps:
  - name: Checkout
    uses: actions/checkout@v2
```
Verify xem step trên đã chạy thành công chưa bằng cách push code lên branch `main`. Thông tin chi tiết ở tab **Actions** trên GitHub repo:

<img src="/static/img/github-actions/step-checkout.png">

Để có thể push một Docker Image lên Docker Hub, bạn cần có một account và ở bước này, chúng ta sẽ tạo một **Personal Access Token** để xác thực. Đăng nhập vào Docke Hub và đi đến địa chỉ [https://hub.docker.com/settings/security](https://hub.docker.com/settings/security). Click vào **New Access Token**.

<img src="/static/img/github-actions/new_access_token.png">

Đặt tên cho Token:

<img src="/static/img/github-actions/name_access_token.png">

Click vào **Create** rồi copy Token bên dưới, và mình sẽ sử dụng nó cho phần cài đặt bên Github Repo.

<img src="/static/img/github-actions/dockerhub_access_token.png">

Quay trở lại với Github Repo, đi đến Settings tab và bạn cần tạo hai `GitHub Secrets`:

* DOCKER_HUB_ACCESS_TOKEN: Copy từ **Personal Access Token** ở bước trên
* DOCKER_HUB_USERNAME: đây là Docker Hub username của bạn

<img src="/static/img/github-actions/secrets_github.png">

Sau khi cấu hình việc xác thực giữa GitHub Repo và Docker Hub, chúng ta sẽ thêm vào step Login to Docker Hub:

<script src="https://gist.github.com/truongnh1992/ee6d6c911673df6371cccd87852b807d.js"></script>

Tiếp tục verify việc Login vào Docker Hub bằng cách push code lên branch `main`:

<img src="/static/img/github-actions/login.png">

Bước cuối cùng là build và push Docker Image lên Docker Hub, toàn bộ file workflow:

<script src="https://gist.github.com/truongnh1992/6305428c50c613312c8ca83bf404fbec.js"></script>

Verify kết quả tương tự các bước trên, ta thấy Docker Image đã được build và push lên Docker Hub.

<img src="/static/img/github-actions/done.png">

Docker Image `demo-github-actions` trên Docker Hub.

<img src="/static/img/github-actions/dockerhub.png">


## Tham khảo
- [Introduction to GitHub Actions](https://docs.github.com/en/free-pro-team@latest/actions/learn-github-actions/introduction-to-github-actions)
- https://docs.docker.com/ci-cd/github-actions/
