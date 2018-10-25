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

<a name="2-singal-disposition"><a/>
## 2. Signal disposition

<a name="3-standard-signals"><a/>
## 3. Các loại tín hiệu chuẩn

<a name="4-signal-handler-with-python"><a/>
## 4. Signal handler with Python
