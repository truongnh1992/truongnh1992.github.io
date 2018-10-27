---
layout: post
title: DIY, code nháy LED với Python trên Raspberry Pi 2
date: 2018-10-27
categories: [python, raspberry]
tags: [python, raspberry]
---

Nhân một buổi chiều rảnh rỗi, mình ngồi viết bài này hướng dẫn các bạn code một chương trình nho nhỏ bằng Python để điều khiển đèn LED nháy trên [Rasberry Pi 2](https://www.raspberrypi.org/products/raspberry-pi-2-model-b/).  

Chiếc Rasberry Pi của mình là Rasberry Pi 2, mình tậu em nó từ hồi năm cuối Đại học (2015), hàng UK nên dùng rất bền, mua về nhà cũng vọc vạch được khá nhiều trò hay ho với cái board này: Cài [OSMC](https://osmc.tv/download/) lên rồi cắm vô chiếc "stupid" TV nhà mình để biến nó thành smart hơn và cũng hỗ trợ đầy đủ app Youtube, multimedia server các kiểu...

Pi cũng rất thích hợp để nhóc em trai mình học lập trình, với cấu hình RAM: 1GB, SoC: BCM2836 kèm thẻ nhớ 8GB của nó là quá đủ để code Python, C... rồi.  

Chiếc Pi của mình trông nó như thế này:

![My workingspace](/static/img/raspberrypi/mypi.jpg)

Để thực hiện việc điều kiển nháy LED bằng code Python, thì việc đầu tiên cần làm là chuẩn bị những phần cứng và phần mềm cấn thiết.

## Phần cứng:
* Board mạch Raspberry Pi
* Board trắng để cắm đèn LED, dây nối và jump
* Điện trở 220 Ohm 

![Hardware](/static/img/raspberrypi/hardware.jpg)

## Phần mềm
Mình sẽ cài [Rasbian](https://www.raspberrypi.org/downloads/raspbian/) lên Pi, **Rasbian** là hệ điều hành nhân Linux được tuỳ biến riêng cho Rasberry Pi. [Hướng dẫn này](https://www.raspberrypi.org/documentation/installation/installing-images/README.md) sẽ nêu chi tiết các bước cài đặt.

## Lập trình
Giờ đến công đoạn cuối cùng là code và cài cắm đèn LED vào Pi.  

Raspberry Pi 2 có 40 chân GPIO (general-purpose input/output)

![pins-gpio](/static/img/raspberrypi/gpio-pins-pi2.jpg)

{:.image-caption}
*Ảnh: rasberrypi.org*
