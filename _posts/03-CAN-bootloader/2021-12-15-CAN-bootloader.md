---
layout: post
title: CAN bootloader 简介
category: AUTOSAR
comments: true
---

# CAN bootloader 简介

当下，汽车行业正在经历重大变革，一呢，由传统油车到电车的转变，二呢，没有高级辅助驾驶功能，都不好意思说自己是车企了。然后呢，受特斯拉互联网思维的影响，各厂商也开始有样学样，先硬件该堆得都堆上去，软件后续功能慢慢迭代升级嘛，所以一辆车造出来，可能首先要求的是所有模块都必须支持OTA。

这里不介绍OTA，但不管怎样，汽车上的传统MCU控制器，基本都是以CAN网络为基础进行通信的，所以这里介绍对于MCU而言，通常其bootloader是如何设计及怎样工作的。

对于bootloader而言，其有2大主要功能：

* boot启动APP的过程
* loader响应升级请求，升级APP的过程

## boot启动APP的过程

对于汽车MCU而言，通常程序是固化在Flash空间，MCU上电后，会从Flash的特定地址处开始执行其存储的指令，那么这个特定地址空间通常用作为boot区间，用于存储bootloader程序。 然后，将boot区以外的区间用作application，存储应用程序。下图1是一个简单实例，红色区域用以分别表征boot和app的中断向量表。

![boot-flash-map](/ssas-public/images/boot-flash-map-startup-loader-chart.png)

通常而言，中断向量表的第一项为系统复位向量，存储着程序的开始函数地址，通常该函数为汇编编写，用以准备C运行时环境，比如初始化data段、bss段以及初始化堆栈，之后main函数就开始执行了，关于MCU的C运行时环境的准备过程这里不做过多介绍，有兴趣的可以自行谷歌学习相关内容。

这里，如上图2所示为boot main程序正常的启动APP的过程。正常启动APP的流程是相当简单的，这也是为了更快速的启动APP，提高系统的开机响应速度。

## loader升级APP的过程

通常来讲，MCU的loader是一个通用诊断服务（UDS）提供者，其作为服务器响应一切来自客户端的UDS服务请求，从而完成APP的升级过程，其流程大致如上图3所示。

这里暂不细讲，每一个步骤由哪些UDS服务所构成，这里先讲做bootloader项目通常需要的三个工程！

* bootloader 工程
* Flash Driver 工程
* Application 工程

这里将以QEMU Versatilepb虚拟机为例，讲解着三个工程大概的样子，以及一个完整的升级流程是怎样的。

该例子代码开源于： [autoas/qemu](https://github.com/autoas/qemu)

好吧，让我们先编译运行一把该例子吧。

首先，请参考 [开发环境搭建](https://autoas.github.io/ssas-public/autosar/2021/12/03/setup.html)，构建基础编译环境及其工具链， 之后双击ssas-public工程目录下的Console.bat启动ConEmu终端。

```sh
# app 页， 执行如下命令
D:\repository\ssas-public>cd app\platform
D:\repository\ssas-public\app\platform>git clone https://github.com/autoas/qemu.git
D:\repository\ssas-public\app\platform>cd ../..
# 开始编译
D:\repository\ssas-public>scons --app=Loader
D:\repository\ssas-public>scons --app=CanSimulator

# 设置CANFD模式，数据最大长度为64字节
D:\repository\ssas-public>set LL_DL=64
D:\repository\ssas-public>scons --cpl=QemuVersatilepbGCC --app=VersatilepbFlashDriver
# 第一次编译需要比较久，因为需要下载编译器gcc-arm-none-eabi
D:\repository\ssas-public>scons --cpl=QemuVersatilepbGCC --app=VersatilepbCanApp
D:\repository\ssas-public>scons --cpl=QemuVersatilepbGCC --app=VersatilepbCanBL

# 这个时候修改app/app/main.c, main函数里的打印输出如下：
# int main(int argc, char *argv[]) {
#   ASLOG(INFO, ("application v2 build @ %s %s\n", __DATE__, __TIME__));
# 然后重新编译CanAPP
D:\repository\ssas-public>scons --cpl=QemuVersatilepbGCC --app=VersatilepbCanApp

# 切换到 sim 页，运行CAN总线模拟器
D:\repository\ssas-public>build\nt\GCC\CanSimulator\CanSimulator.exe 0

# 切换回 app 页，启动qemu虚拟机
# 如果qemu没有安装，使用命令 “pacman -S mingw-w64-x86_64-qemu”进行安装
D:\repository\ssas-public>scons --cpl=QemuVersatilepbGCC --app=VersatilepbCanBLRun
scons: Reading SConscript files ...
qemu-system-arm.exe: -serial tcp:127.0.0.1:1103,server: info: QEMU waiting for connection on: disconnected:tcp:127.0.0.1:1103,server=on
QEMU: UART terminal online
qemu-system-arm.exe: -serial tcp:127.0.0.1:1104,server: info: QEMU waiting for connection on: disconnected:tcp:127.0.0.1:1104,server=on
INFO    :bootloader build @ Dec 15 2021 19:26:46
INFO    :application is valid
INFO    :application build @ Dec 14 2021 22:55:11
# 上面日志说明， boot成功启动APP, 并且没有v2字样，说明是没改之前的APP代码

# 等虚拟机启动完成，切换到 boot 页，如下命令开始升级
D:\repository\ssppas-public>build\nt\GCC\Loader\Loader.exe -a build\nt\QemuVersatilepbGCC\VersatilepbCanApp\VersatilepbCanApp.s19.sign -f build\nt\QemuVersatilepbGCC\VersatilepbFlashDriver\VersatilepbFlashDriver.s19.sign -l 64

# 因为是模拟，升级过程可能比较漫长，可能我的笔记本性能太差了，一帧CAN报文需要100ms左右的通信时间（bug待查）！
# 你可以在sim，app和boot页来回切换，观察输出日志。
# 如果看到任何错误日志，通常是由于windows非实时操作系统，CANTP通讯超时所导致，可重新运行上面的命令，重新开始
# 一次新的升级过程。

# 在boot页，最终可以看到如下日志
block information of build\nt\QemuVersatilepbGCC\VersatilepbCanApp\VersatilepbCanApp.s19.sign:
srec 0: address=0x00060000, length=0x000000B8, offset=0x00000000, data=18F09FE518F09FE5 crc16=CC60
srec 1: address=0x00070000, length=0x0000BB11, offset=0x000000B8, data=04B02DE500B08DE2 crc16=396F
srec 2: address=0x0015FFFE, length=0x00000002, offset=0x0000BBC9, data=A43D crc16=2B4B
block information of build\nt\QemuVersatilepbGCC\VersatilepbFlashDriver\VersatilepbFlashDriver.s19.sign:
srec 0: address=0x00050000, length=0x00000568, offset=0x00000000, data=010200A918000500 crc16=1E19
srec 1: address=0x00050FFE, length=0x00000002, offset=0x00000568, data=5FA8 crc16=376C
loader started:
enter extended session          progress  0.10%  okay
level 1 security access         progress  0.30%  okay
enter program session           progress  0.40%  okay
level 2 security access         progress  0.60%  okay
download flash driver           progress  3.62%  okay
erase flash okay
download application            progress 95.91%  okay
check integrity                 progress 96.01%  okay
ecu reset                       progress 99.00%  okay
loader exited without error
                                progress 100.00%
# 在APP页，可以看到如下日志
INFO    :bootloader build @ Dec 15 2021 19:26:46
INFO    :application is valid
INFO    :application build @ Dec 14 2021 22:55:11
DCM     :physical service 10, len=2
INFO    :App_GetSessionChangePermission(1 --> 3)
DCM     :physical service 27, len=2
INFO    :App_GetExtendedSessionSeed(seed = CF712C84)
DCM     :physical service 27, len=6
INFO    :App_CompareExtendedSessionKey(key = B7E26AF7(B7E26AF7))
DCM     :physical service 10, len=2
INFO    :App_GetSessionChangePermission(3 --> 2)
INFO    :bootloader build @ Dec 15 2021 19:26:46 # 此日志说明，系统复位，重新进入了bootloader
DCM     :physical service 27, len=2
DCM     :physical service 27, len=6
DCM     :physical service 34, len=11
DCM     :download memoryAddress=0x50000 memorySize=0x568
...
...
DCM     :physical service 31, len=4
DCM     :start p2server
DCM     :physical service 11, len=2
INFO    :bootloader build @ Dec 15 2021 19:26:46
INFO    :application is valid
INFO    :application v2 build @ Dec 15 2021 21:47:05
# 看到v2字样，说明升级成功，新版本APP开始运行了
```

上面的步骤很多，花费时间也很长，请耐心一点，等完成，你可以在ssas-public目录下找到ssas.log日志文件，可以文本编辑器打开，可看到如下类容，从此内容，即可知升级过程即一系列UDS服务的组合来共同实现升级APP的目的。

```txt
loader started:
enter extended session
 request service 10:
  TX: len=2 10 03
  RX: len=6 50 03 13 88 00 32
  PASS
 okay
level 1 security access
 request service 27:
  TX: len=2 27 01
  RX: len=6 67 01 CF 71 2C 84
  PASS
...
...
download flash driver
 request service 34:
  TX: len=11 34 00 44 00 05 00 00 00 00 05 68
  RX: len=4 74 20 02 02
  PASS

 request service 36:
  TX: len=514 36 01 01 02 00 A9 18 00 05 00 84 00 05 00 B0 00 05 00 2C 02 05 00 B8 03 05 00 04 B0 2D E5 00 B0
  RX: len=2 76 01
  PASS

 request service 36:
  TX: len=514 36 02 00 20 A0 E3 B4 20 C3 E1 03 00 00 EA 02 00 00 EA 18 30 1B E5 01 20 A0 E3 B4 20 C3 E1 00 00
  RX: len=2 76 02
  PASS

 request service 36:
  TX: len=362 36 03 0C 30 0B E5 20 30 1B E5 08 30 93 E5 10 30 0B E5 20 30 1B E5 10 30 93 E5 14 30 0B E5 10 30
  RX: len=2 76 03
  PASS

 request service 37:
  TX: len=1 37
  RX: len=1 77
  PASS
 ...
 ...
```



