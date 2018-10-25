---
layout: post
title: Signal handler with Python
date: 2018-10-25
tags: python signal-handler Linux
---

Bài viết sẽ trình bày một cách tổng quan về tín hiệu (**signals**) trên hệ thống [Linux](https://en.wikipedia.org/wiki/Linux) và cách mà [Python](https://www.python.org/) xử lý (**handle**) những tín hiệu này.

**Contents:**

<!-- MarkdownTOC -->
[1. Signals trên hệ thống Linux là gì?](#1-what-is-a-signal-in-linux)  
[2. Signal disposition](#2-singal-disposition)  
[3. Các loại tín hiệu chuẩn](#3-standard-signals)  
[4. Signal handler with Python](#4-signal-handler-with-python)  
<!-- /MarkdownTOC -->

<a name="1-what-is-a-signal-in-linux"><a/>
## 1. Signals trên hệ thống Linux là gì?
**Signals** được dịch một cách đơn giản sang Tiếng Việt là **tín hiệu**, còn theo định nghĩa trong Chương 9 của cuốn sách [Linux System Programming](https://www.oreilly.com/library/view/linux-system-programming/0596009585/ch09.html) (NXB: O'Reilly):
> Signals are software interrupts that provide a mechanism for handling asynchronous events. These events can originate from outside the system—such as when the user generates the interrupt character (usually via Ctrl-C)—or from activities within the program or kernel, such as when the process executes code that divides by zero. As a primitive form of interprocess communication (IPC), one process can also send a signal to another process.

```
Tín hiệu là những phần mềm ngắt cung cấp cơ chế xử lý các sự kiện bất đồng bộ. Các sự kiện này có thể bắt nguồn từ bên ngoài hệ thống, ví dụ như khi người dùng truyền vào kí tự ngắt (thông thường là qua tổ hợp phím Ctrl+C) hoặc từ các hoạt động bên trong chương trình hoặc nhân hệ thống (kernel), chẳng hạn như việc thực thi đoạn mã (code) chia một số cho 0. Là một dạng nguyên thủy của truyền thông liên tiến trình (Interprocess Communication - IPC), một tiến trình cũng có thể gửi một tín hiệu đến tiến trình khác.
```

Các định nghĩa ở trên rất hàn lâm nên chúng ta có thể hiểu một cách đơn giản là: *Tín hiệu* là một thông báo **(notification)** được gửi đến một tiến trình **(process)** hoặc một luồng cụ thể **(specific thread)** trong cùng tiến trình để thông báo **(notify)** về một sự kiện đã xảy ra.

<a name="2-singal-disposition"><a/>
## 2. Signal disposition

| Term | Terminate the process                                         |
|------|---------------------------------------------------------------|
| Ign  | Ignore the signal                                             |
| Core | Terminate the process and dump core                           |
| Stop | Stop the process                                              |
| Cont | Continue the process if it is currently               stopped |

<a name="3-standard-signals"><a/>
## 3. Các loại tín hiệu chuẩn

<a name="4-signal-handler-with-python"><a/>
## 4. Signal handler with Python
