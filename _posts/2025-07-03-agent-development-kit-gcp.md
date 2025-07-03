---
layout: post
title: Tạo nhanh một "Tác nhân AI" với ADK trên Google Cloud
categories: [GCP, ADK, Gemini]
excerpt: "Tác nhân AI (AI agent) là một chương trình độc lập (tự trị, tự điều khiển, tự động), giao tiếp với mô hình AI để thực hiện một hoạt động dựa trên mục tiêu bằng cách sử dụng các công cụ và ngữ cảnh mà nó có, đồng thời có khả năng tự đưa ra quyết định căn cứ vào các sự thật."
image: /assets/img/ADK.png
---

Tác nhân AI **(AI agent)** là một chương trình độc lập (tự trị, tự điều khiển, tự động), giao tiếp với mô hình AI để thực hiện một hoạt động dựa trên mục tiêu bằng cách sử dụng các công cụ và ngữ cảnh mà nó có, đồng thời có khả năng tự đưa ra quyết định căn cứ vào các sự thật.

### ADK là gì?

Agent Development Kit (ADK) là một framework linh hoạt và có cấu trúc mô-đun (modular) để phát triển và triển khai các tác nhân AI (AI agents). ADK được thiết kế để việc phát triển tác nhân mang lại cảm giác quen thuộc như phát triển phần mềm, giúp lập trình viên dễ dàng hơn trong việc tạo, triển khai và điều phối các kiến trúc dạng tác nhân (agentic architectures), từ những tác vụ đơn giản đến các quy trình công việc (workflows) phức tạp.

<img src="/assets/img/ADK.png">

Mặc dù được tối ưu hóa cho Gemini và hệ sinh thái của Google, tuy nhiên ADK `không phụ thuộc` vào mô hình AI (model-agnostic), không phụ thuộc vào nền tảng triển khai (deployment-agnostic) và được xây dựng để tương thích với các framework khác.

Trong khuôn khổ bài viết này, mình sẽ dùng Gemini trên Google Cloud để tạo mới một AI Agent.

### Chuẩn bị
- Một Google Cloud project (billing enabled)
- Python
- [uv](https://github.com/astral-sh/uv): tool này kiểu như `pip`, `pyenv`, `virtualenv` nhưng nó nhanh hơn 10-100 lần :D

### Tạo một AI Agent

Chạy những lệnh sau trên Terminal máy tính của bạn:

```bash
mkdir your-first-agent
cd your-first-agent
uv init
```
Tiếp theo, thêm package `google-adk` vào project trên:

```bash
uv add google-adk
```
Terminal của bạn sẽ trả về các output như dưới đây:

<img src="/assets/img/uv-google-adk.png">

Bây giờ, chúng ta đã sẵn sàng để tạo mới một agent rồi.

```bash
uv run adk create my-agent
```
Sau câu lệnh trên, chương trình sẽ hỏi một số câu hỏi:

```console
Choose a model for the root agent:
1. gemini-2.0-flash-001
2. Other models (fill later)
Choose model (1, 2): 1
1. Google AI
2. Vertex AI
Choose a backend (1, 2): 2
```

Mình chọn model số 1 `gemini-2.0-flash-001` và backend số 2 `Vertex AI`. Lúc này, chương trình tạo mới thư mục tên là `my-agent` trong đó có file `agent.py`:
```
~/your-first-agent   main ?7 ❯ tree                                                                                                             
.
├── README.md
├── main.py
├── my-agent
│   ├── __init__.py
│   └── agent.py
├── pyproject.toml
└── uv.lock

1 directory, 6 files
```
Bạn có thể sửa file `agent.py` để tùy biến agent vừa tạo, ở đây mình sẽ chọn lại model Gemini mới nhất ở thời điểm hiện tại: `gemini-2.5-pro` và đặt tên cho agent là: "Smart_agent". (Bước này là tùy chọn, không bắt buộc)

```python
from google.adk.agents import Agent

root_agent = Agent(
    model='gemini-2.5-pro',
    name='Smart_agent',
    description='A helpful assistant for user questions.',
    instruction='Answer user questions to the best of your knowledge',
)
```

Việc cần làm bây giờ là khởi động ADK qua giao diện web bằng cách chạy lệnh sau:

```bash
uv run adk web
```
Một webserver local sẽ được khởi chạy tại địa chỉ http://127.0.0.1:8000

```console
INFO:     Started server process [67579]
INFO:     Waiting for application startup.

+-----------------------------------------------------------------------------+
| ADK Web Server started                                                      |
|                                                                             |
| For local testing, access at http://localhost:8000.                         |
+-----------------------------------------------------------------------------+

INFO:     Application startup complete.
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```
Lúc này bạn có thể hỏi đáp với Agent do chình mình vừa tạo.
<img src="/assets/img/myagent.png">

Khi bạn nhập câu hỏi vào giao diện trên, cùng lúc Terminal cũng output ra log sau, phù hợp với cài đặt trong file `agent.py` trước đó.

```
LLM Request:
-----------------------------------------------------------
System Instruction:
Answer user questions to the best of your knowledge

You are an agent. Your internal name is "Smart_agent".

 The description about you is "A helpful assistant for user questions."
```
Happy hacking :)