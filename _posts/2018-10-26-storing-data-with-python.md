---
layout: post
title: Lưu trữ dữ liệu với Python
date: 2018-10-26
categories: [python]
tags: [python]
---

Khi lập trình, rất nhiều chương trình sẽ đòi hỏi người phát triển phải truyền vào một loại thông tin cụ thể nào đó, chẳng hạn như cho phép người dùng lưu trữ các tùy chọn trong game hoặc cung cấp dữ liệu điểm số, số lượt chơi còn lại... Bất kể chương trình là gì đi chăng nữa thì thông tin cũng sẽ được lưu trong các cấu trúc dữ liệu như danh sách (**lists**) hoặc từ điển (**dictionaries**). Khi người dùng đóng chương trình, những thông tin được tạo ra trong quá trình chạy chương trình (phải) được lưu lại. Một cách đơn giản để thực hiện việc này là lưu trữ data bằng cách sử dụng mô-đun (module) **json**.  

Mô-đun **json** cho phép ***dump*** (từ này mình không biết nên Việt hóa như thế nào nữa? :D) một cấu trúc dữ liệu Python đơn giản vào một file và tải (load) dữ liệu từ file đó vào lần chạy tiếp theo của chương trình. Người phát triển có thể dùng **json** để chia sẻ dữ liệu giữa các chương trình Python khác nhau. Một ưu điểm vượt trội khác là kiểu dữ liệu **JSON** được thiết kế để không chỉ dùng riêng cho Python nên người phát triển có thể chia sẻ dữ liệu lưu trữ ở định dạng JSON với những người phát triển ngôn ngữ lập trình khác, nó rất hữu ích và khả chuyển (portable).

> JSON (JavaScript Object Notation): Ban đầu JSON được phát triển cho JavaScript. Tuy nhiên, nó đã trở nên phổ biến và được dùng bởi nhiều ngôn ngữ lập trình khác, trong đó có Python.


**Trong bài viết:**

<!-- MarkdownTOC -->
[1. json.dump() và json.load()](#1-json-dump-load)  
[2. Lưu trữ và đọc dữ liệu User-Generated](#2-saving-reading-user-generated-data)  
[3. Refactoring](#3-Refactoring)  
<!-- /MarkdownTOC -->

<a name="1-json-dump-load"><a/>
## 1. json.dump() và json.load()
Chương trình **number_writer.py** lưu trữ một tập hợp các số và chương trình **number_reader.py** đọc những con số này ngược trở lại bộ nhớ. Chương trình thứ nhất sẽ sử dụng `json.dump()` để lưu trữ tập hợp số và chương trình thứ hai sử dụng `json.load()`.  

Hàm `json.dump()` nhận 2 đối số (arguments): dữ liệu lưu trữ và một đối tượng file dùng để lưu trữ dữ liệu.
```python
# number_writer.py

import json

numbers = [2, 3, 5, 7, 11, 13]

filename = 'numbers.json'
with open(filename, 'w') as f_obj:
	json.dump(numbers, f_obj)
```
Hàm `json.dump()` sẽ lưu trữ danh sách `numbers = [2, 3, 5, 7, 11, 13]` vào tệp *numbers.json*. Chương trình phía trên không có output nào ra console, nhưng nó sẽ tạo ra tệp *numbers.json* lưu trữ danh sách numbers theo định dạng giống như Python:
```sh
$ python number_writer.py
$ cat numbers.json
[2, 3, 5, 7, 11, 13]
```

Tiếp theo chương trình thứ hai **number_reader.py** sử dụng `json.load()` để đọc danh sách numbers ngược trở lại bộ nhớ.
```python
# number_reader.py

import json

filename = 'numbers.json'
with open(filename) as f_obj:
	numbers = json.load(f_obj)

print(numbers)
```
Hàm `json.load()` đọc thông tin lưu trữ trong tệp *numbers.json* và lưu thông tin vào biến numbers, chương trình sẽ in ra danh sách các số giống như danh sách được tạo ở **number_writer.py**
```sh
$ python number_reader.py
[2, 3, 5, 7, 11, 13]
```
Nội dung trên đã trình bày một cách đơn giản để chia sẻ dữ liệu giữa 2 chương trình.
<a name="2-saving-reading-user-generated-data"><a/>
## 2. Lưu trữ và đọc dữ liệu User-Generated

<a name="3-Refactoring"><a/>
## 3. Refactoring

*Nguồn: [Python Crash Course: A Hands-On, Project-Based Introduction to Programming](https://www.amazon.com/Python-Crash-Course-Hands-Project-Based/dp/1593276036)*