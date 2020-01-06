---
layout: post
title: Install and configure VNC server on Ubuntu
excerpt: "Tutorial for installing and configuring VNC server on Ubuntu."
tags: [Linux, Tutorials]
author: truongnh
color: rgb(42,140,152)
---

### 1. Install windows manager and desktop manager for Ubuntu

```sh
$ sudo apt-get install --no-install-recommends ubuntu-desktop gnome-panel gnome-settings-daemon metacity nautilus gnome-terminal gnome-core
```

### 2. Install and configure VNC server
```sh
$ sudo apt-get install vnc4server
```

#### 2.1 Set password for vnc server
```sh
$ vncserver
```

#### 2.2 Configure xstartup file
Before changing the configuration of VNC server, it have to be stopped.
```sh
$ vncserver -kill :1
```

Change the file `xstartup` with a text editor
```sh
$ vi ~/.vnc/xstartup
```

The content of file `xstartup`:
```sh
#!/bin/sh

# Uncomment the following two lines for normal desktop:
# unset SESSION_MANAGER
# exec /etc/X11/xinit/xinitrc

[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources
xsetroot -solid grey
vncconfig -iconic &
x-terminal-emulator -geometry 80x24+10+10 -ls -title "$VNCDESKTOP Desktop" &
x-window-manager &

gnome-panel &
gnome-settings-daemon &
metacity &
nautilus &
```

Now, restart the VNC server.
```sh
$ vncserver
```

### 3. Setup the VNC server as a `systemd service`

Create a new file in the directory `/etc/systemd/system/`

```sh
$ sudo vim /etc/systemd/system/vncserver@:1.service
```

The content of file `vncserver@:1.service`:
```sh
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=$USER
PAMName=login
PIDFile=/home/$USER/.vnc/%H%i.pid
#ExecStartPre=/usr/bin/vncserver -kill %i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1920x1200 %i
ExecStop=/usr/bin/vncserver -kill %i

[Install]
WantedBy=multi-user.target
```

Then,
```sh
$ sudo systemctl daemon-reload
```

Enable the service file.
```sh
$ sudo systemctl enable vncserver@\:1.service
```

Kill the instance is running
```sh
$ vncserver -kill :1
```

Start the `systemd` service.
```sh
$ sudo systemctl start vncserver@\:1.service
```

If the service runs correctly,
```
$ sudo systemctl status vncserver@\:1.service

● vncserver@:1.service - Start TightVNC server at startup
   Loaded: loaded (/etc/systemd/system/vncserver@:1.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2019-01-30 09:18:46 +07; 4h 8min ago
 Main PID: 1285 (Xvnc4)
   CGroup: /system.slice/system-vncserver.slice/vncserver@:1.service
           ‣ 1285 Xvnc4 :1 -desktop k8s:1 (vietkubers) -auth /home/vietkubers/.Xauthority -geometry 1920x1200 -depth 24 -rfbwait 30000 -rfbauth /home/vietkubers/.vnc/passwd -rfbport 5901 -pn -fp /usr/X11R6/lib/X11/fonts/Type1/,/usr/X11R6/

Jan 30 09:18:43 k8s systemd[1]: Starting Start TightVNC server at startup...
Jan 30 09:18:43 k8s systemd[1271]: pam_unix(login:session): session opened for user vietkubers by (uid=0)
Jan 30 09:18:46 k8s systemd[1]: Started Start TightVNC server at startup.
lines 1-10/10 (END)
```

### Happy hacking!

