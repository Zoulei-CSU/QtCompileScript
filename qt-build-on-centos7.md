# CentOS 7 源码编译Qt

## 1.配置环境

### 1.1 安装高版本编译器

CentOS 7自带的gcc版本是4.8.5，太低了，需要安装高版本的编译器。可以自己通过源码编译安装高版本GCC，也可以安装devtoolset。

```shell
# 安装devtoolset-7, gcc 7.3编译器
yum install centos-release-scl
yum install devtoolset-7
```

```shell
# 使用时只需要命令即可激活当前gcc
# 激活gcc版本
scl enable devtoolset-7  bash
gcc -v
```


### 1.2 安装 xcb依赖库
Linux下编译Qt，依赖于xcb、xkb，否则编译出来的Qt无法运行于图形界面。xcb、xkb相关的开发库都要装上。

```shell
# 安装xcb、xkb相关的开发库
yum install libxcb libxcb-devel xcb-util xcb-util-devel libxkbcommon-devel libxkbcommon-x11-devel
yum install xcb-util-image-devel xcb-util-keysyms-devel xcb-util-renderutil-devel xcb-util-wm-devel
```

### 1.3 安装 MESA libs 

如果需要OpenGL支持，需要安装MESA的开发库。

```shell
# 安装 libGL
yum install mesa-libGL-devel
```

同理，如果需要EGL，也可安装libEGL库（可选）

```shell
# 安装 libEGL
yum install mesa-libEGL-devel
```

### 1.4 安装字体配置库

安装字体配置库。只有安装了字体配置库，图形界面才能使用系统的字体，否则要再Qt库中自己带字体文件。根据需要选择是否需要安装。

```shell
# 安装 字体库开发库
yum install fontconfig-devel
```

### 1.5 安装D-BUS库
```shell
yum install libdbusmenu-devel
```



## 2.下载源码包

可以从官网下载，也可从镜像库下载。下载qt-everywhere的包，这个是完整代码包。

```shell
wget https://mirrors.aliyun.com/qt/official_releases/qt/5.15/5.15.17/single/qt-everywhere-opensource-src-5.15.17.tar.xz
tar -xJf qt-everywhere-opensource-src-5.15.17.tar.xz
```



## 3.编译

### 3.1 基本说明

Qt源码编译比较简单，直接configure，之后make、install即可。

如果有三方库，可通过`-I`和`-L`的方式传递到configure参数里，比如：

```shell
-I"/home/zoulei/code/postgis/pg158/include"  -L"/home/zoulei/code/postgis/pg158/lib"
```



### 3.2 注意事项

1. 配置完成之后，要注意检查openssl、fontconfig、libdbus、postgres这几个库，确定是否需要。
2. 没有openssl可能无法使用安全连接，并且生成的Qt头文件也不一样，有些程序必须使用openssl的（比如QGIS），就无法使用这样的Qt。
3. 没有fontconfig，Qt不需要连接系统的字体库，也就无法使用系统的字体，需要自己再lib/font文件夹下放置字体文件，否则没有字体信息。
4. 注意iconv和ICU这两个库，至少要有一个，否则无法实现转码。想让Linux下可以识别GBK编码，就不行这两个库之一。
5. 连接到openssl有两种方式，`-openssl-linked`和`-openssl`，一个静态连接，一个动态连接
6. 如果系统的libpng库版本太低，可以带上`-qt-libpng`，使用源码内置png库
7. 不需要的模块可以跳过，比如：`-skip qtscript -skip qtquick3d`



3.3 配置样例

```
[zoulei@localhost 5.15.16-gcc7-rel]$ scl enable devtoolset-7 llvm-toolset-7.0 bash
[zoulei@localhost 5.15.16-gcc7-rel]$ 
export SSL_DIR=/home/zoulei/code/sde/3rdparty/3rdparty_unix/openssl
export PATH=$SSL_DIR/bin:$PATH
export LD_LIBRARY_PATH=$SSL_DIR/lib:$LD_LIBRARY_PATH

[zoulei@localhost build]$ mkdir build
[zoulei@localhost build]$ cd build
[zoulei@localhost build]$ LDFLAGS='-L$SSL_DIR/lib -lssl -lcrypto' ../qt-everywhere-src-5.15.17/configure -opensource -confirm-license -xcb -xcb-xlib -release -ltcg -prefix "/home/zoulei/qt/5.15.17-gcc7-rel" -qt-libpng -no-qml-debug -no-angle -opengl desktop  -no-compile-examples -nomake tests -nomake examples -skip qtwebengine -skip qtwebview -openssl OPENSSL_INCDIR="$SSL_DIR/include" OPENSSL_LIBDIR="$SSL_DIR/lib" -I"/home/zoulei/code/postgis/pg158/include"  -L"/home/zoulei/code/postgis/pg158/lib"



+ cd qtbase
+ /home/southgis/qt/src/qt-everywhere-src-5.15.17/qtbase/configure -top-level -opensource -confirm-license -xcb -xcb-xlib -release -ltcg -prefix /home/southgis/qt/5.15.17-gcc7-rel -qt-libpng -no-qml-debug -no-angle -opengl desktop -no-compile-examples -nomake tests -nomake examples -skip qtwebengine -skip qtwebview -openssl OPENSSL_INCDIR=/home/southgis/code/sde/3rdparty/3rdparty_unix/openssl/include OPENSSL_LIBDIR=/home/southgis/code/sde/3rdparty/3rdparty_unix/openssl/lib -I/home/southgis/code/postgis/pg158/include -L/home/southgis/code/postgis/pg158/lib
  Preparing build tree...
  Creating qmake...  ...............................................................................................Done.

This is the Qt Open Source Edition.

You have already accepted the terms of the Open Source license.

Running configuration tests...
Checking for machine tuple... yes
Checking for valid makespec... yes
Checking for target architecture... arm64
Checking for alloca() in alloca.h... yes
Checking for C++14 support... yes
Checking for C++17 support... yes
Checking for C99 support... yes
Checking for C11 support... yes
Checking for pkg-config... yes
Checking for D-Bus >= 1.2... yes
Checking for dlopen()... yes
Checking for new dtags support... yes
Checking for D-Bus >= 1.2 (host)... yes
Checking for Support for Intel Control-flow Enforcement Technology... no
Checking for udev... no
Checking for POSIX fallocate()... yes
Checking for precompiled header support... yes
Checking for RDRAND instruction... no
Checking for RDSEED instruction... no
Checking for symbol visibility support... yes
Checking for -Bsymbolic-functions support... no
Checking for Signaling NaN for doubles... yes
Checking for STL compatibility... yes
Checking for zlib... yes
Checking for Zstandard... yes
Checking for clock_gettime()... yes
Checking for POSIX monotonic clock... yes
Checking for C++11 <future>... yes
Checking for eventfd... yes
Checking for futimens()... yes
Checking for getauxval()... yes
Checking for getentropy()... no
Checking for GLib... yes
Checking for GNU libc... yes
Checking for POSIX iconv... no
Checking for SUN libiconv... no
Checking for GNU libiconv... no
Checking for ICU... yes
Checking for inotify... yes
Checking for SysV IPC... yes
Checking for linkat()... yes
Checking for PCRE2... no
Checking for ppoll()... yes
Checking for renameat2()... no
Checking for slog2... no
Checking for statx() in libc... no
Checking for 64 bit atomics... yes
Checking for DoubleConversion... no
Checking for O_CLOEXEC... yes
Checking for C++11 <random>... yes
Checking for working std::atomic for function pointers... yes
Checking for OpenSSL Headers... yes
Checking for DTLS support in OpenSSL... yes
Checking for getifaddrs()... yes
Checking for KRB5 GSSAPI Support... yes
Checking for IPv6 ifname... yes
Checking for Linux AF_NETLINK sockets... yes
Checking for OCSP stapling support in OpenSSL... yes
Checking for XCB >= 1.11... yes
Checking for XCB ICCCM >= 0.3.9... yes
Checking for XCB SHM... yes
Checking for XCB Image >= 0.3.9... yes
Checking for XCB Keysyms >= 0.3.9... yes
Checking for XCB RandR... yes
Checking for XCB XRender... yes
Checking for XCB Renderutil >= 0.3.9... yes
Checking for XCB Shape... yes
Checking for XCB Sync... yes
Checking for XCB Xfixes... yes
Checking for XCB Xinerama... yes
Checking for XCB XKB... yes
Checking for XCB (extensions)... yes
Checking for xkbcommon >= 0.5.0... yes
Checking for xkbcommon-x11... yes
Checking for atspi... no
Checking for KMS... yes
Checking for DRM Atomic API... yes
Checking for Desktop OpenGL... yes
Checking for EGL... yes
Checking for XLib... yes
Checking for EGL on X11... yes
Checking for EGLDevice... yes
Checking for GBM... no
Checking for Mali EGL... no
Checking for Mali 2 EGL... no
Checking for i.Mx6 EGL... no
Checking for XCB Xlib... yes
Checking for evdev... yes
Checking for FreeType... yes
Checking for Fontconfig... yes
Checking for Harfbuzz NG... yes
Checking for LinuxFB... yes
Checking for mtdev... no
Checking for OpenVG... no
Checking for default QPA platform... xcb
Checking for HarfBuzz... no
Checking for libjpeg... yes
Checking for libmd4c... no
Checking for XCB XInput... yes
Checking for tslib... no
Checking for Vulkan... no
Checking for X11 prefix... /usr
Checking for XCB GLX... yes
Checking for X11 session management... no
Checking for GTK+ >= 3.6... no
Checking for CUPS... no
Checking for DB2 (IBM)... no
Checking for InterBase... no
Checking for MySQL... no
Checking for OCI (Oracle)... no
Checking for ODBC... no
Checking for PostgreSQL... yes
Checking for SQLite (version 2)... no
Checking for TDS (Sybase)... no
Checking for ntddmodm... no
Checking for Socket CAN... yes
Checking for Socket CAN FD... yes
Checking for 64bit pointers... yes
Checking for Sufficiently recent FPU on ARM... yes
Checking for python... /usr/bin/python
Checking for Direct3D 12... no
Checking for Assimp... no
Checking for SDL2... no
Checking for Assimp... no
Checking for Autodesk FBX... no
Checking for Wayland client library... yes
Checking for Wayland cursor library... yes
Checking for wayland-scanner... yes
Checking for EGL 1.5 with Wayland Platform... yes
Checking for Linux dma-buf Buffer Sharing... yes
Checking for DRM EGL Server... yes
Checking for Wayland EGL library... yes
Checking for libhybris EGL Server... no
Checking for XComposite... no
Checking for wayland-server... yes
Checking for Linux Client dma-buf Buffer Sharing... yes
Checking for Linux dma-buf Buffer Sharing... yes
Checking for BlueZ... no
Checking for sensorfw... no
Checking for Gypsy... no
Checking for WinRT Geolocation API... no
Checking for ALSA... no
Checking for GStreamer 1.0... no
Checking for GStreamer 0.10... no
Checking for Video for Linux... yes
Checking for OpenAL... no
Checking for PulseAudio >= 0.9.10... no
Checking for libresourceqt5... no
Checking for Flite... no
Checking for Speech Dispatcher... no
Checking for libclang... no
Done running configuration tests.

Configure summary:

Build type: linux-g++ (arm64, CPU features: neon)
Compiler: gcc 7.3.1
Configuration: enable_new_dtags largefile ltcg neon precompile_header shared shared rpath release c++11 c++14 c++17 c++1z concurrent dbus reduce_exports stl
Build options:
  Mode ................................... release
  Optimize release build for size ........ no
  Building shared libraries .............. yes
  Using C standard ....................... C11
  Using C++ standard ..................... C++17
  Using ccache ........................... no
  Using new DTAGS ........................ yes
  Relocatable ............................ yes
  Using precompiled headers .............. yes
  Using LTCG ............................. yes
  Target compiler supports:
    NEON ................................. yes
  Build parts ............................ libs tools
Qt modules and options:
  Qt Concurrent .......................... yes
  Qt D-Bus ............................... yes
  Qt D-Bus directly linked to libdbus .... yes
  Qt Gui ................................. yes
  Qt Network ............................. yes
  Qt Sql ................................. yes
  Qt Testlib ............................. yes
  Qt Widgets ............................. yes
  Qt Xml ................................. yes
Support enabled for:
  Using pkg-config ....................... yes
  udev ................................... no
  Using system zlib ...................... yes
  Zstandard support ...................... yes
Qt Core:
  DoubleConversion ....................... yes
    Using system DoubleConversion ........ no
  GLib ................................... yes
  iconv .................................. no
  ICU .................................... yes
  Built-in copy of the MIME database ..... yes
  Tracing backend ........................ <none>
  Logging backends:
    journald ............................. no
    syslog ............................... no
    slog2 ................................ no
  PCRE2 .................................. yes
    Using system PCRE2 ................... no
Qt Network:
  getifaddrs() ........................... yes
  IPv6 ifname ............................ yes
  libproxy ............................... no
  Linux AF_NETLINK ....................... yes
  OpenSSL ................................ yes
    Qt directly linked to OpenSSL ........ no
  OpenSSL 1.1 ............................ yes
  DTLS ................................... yes
  OCSP-stapling .......................... yes
  SCTP ................................... no
  Use system proxies ..................... yes
  GSSAPI ................................. yes
Qt Gui:
  Accessibility .......................... yes
  FreeType ............................... yes
    Using system FreeType ................ yes
  HarfBuzz ............................... yes
    Using system HarfBuzz ................ no
  Fontconfig ............................. yes
  Image formats:
    GIF .................................. yes
    ICO .................................. yes
    JPEG ................................. yes
      Using system libjpeg ............... yes
    PNG .................................. yes
      Using system libpng ................ no
  Text formats:
    HtmlParser ........................... yes
    CssParser ............................ yes
    OdfWriter ............................ yes
    MarkdownReader ....................... yes
      Using system libmd4c ............... no
    MarkdownWriter ....................... yes
  EGL .................................... yes
  OpenVG ................................. no
  OpenGL:
    Desktop OpenGL ....................... yes
    OpenGL ES 2.0 ........................ no
    OpenGL ES 3.0 ........................ no
    OpenGL ES 3.1 ........................ no
    OpenGL ES 3.2 ........................ no
  Vulkan ................................. no
  Session Management ..................... yes
Features used by QPA backends:
  evdev .................................. yes
  libinput ............................... no
  INTEGRITY HID .......................... no
  mtdev .................................. no
  tslib .................................. no
  xkbcommon .............................. yes
  X11 specific:
    XLib ................................. yes
    XCB Xlib ............................. yes
    EGL on X11 ........................... yes
    xkbcommon-x11 ........................ yes
QPA backends:
  DirectFB ............................... no
  EGLFS .................................. yes
  EGLFS details:
    EGLFS OpenWFD ........................ no
    EGLFS i.Mx6 .......................... no
    EGLFS i.Mx6 Wayland .................. no
    EGLFS RCAR ........................... no
    EGLFS EGLDevice ...................... yes
    EGLFS GBM ............................ no
    EGLFS VSP2 ........................... no
    EGLFS Mali ........................... no
    EGLFS Raspberry Pi ................... no
    EGLFS X11 ............................ yes
  LinuxFB ................................ yes
  VNC .................................... yes
  XCB:
    Using system-provided xcb-xinput ..... yes
    Native painting (experimental) ....... no
    GL integrations:
      GLX Plugin ......................... yes
        XCB GLX .......................... yes
      EGL-X11 Plugin ..................... yes
Qt Sql:
  SQL item models ........................ yes
Qt Widgets:
  GTK+ ................................... no
  Styles ................................. Fusion Windows
Qt PrintSupport:
  CUPS ................................... no
Qt Sql Drivers:
  DB2 (IBM) .............................. no
  InterBase .............................. no
  MySql .................................. no
  OCI (Oracle) ........................... no
  ODBC ................................... no
  PostgreSQL ............................. yes
  SQLite2 ................................ no
  SQLite ................................. yes
    Using system provided SQLite ......... no
  TDS (Sybase) ........................... no
Qt Testlib:
  Tester for item models ................. yes
Serial Port:
  ntddmodm ............................... no
Qt SerialBus:
  Socket CAN ............................. yes
  Socket CAN FD .......................... yes
  SerialPort Support ..................... yes
Further Image Formats:
  JasPer ................................. no
  MNG .................................... no
  TIFF ................................... yes
    Using system libtiff ................. yes
  WEBP ................................... yes
    Using system libwebp ................. no
Qt QML:
  QML network support .................... yes
  QML debugging and profiling support .... no
  QML just-in-time compiler .............. yes
  QML sequence object .................... yes
  QML XML http request ................... yes
  QML Locale ............................. yes
Qt QML Models:
  QML list model ......................... yes
  QML delegate model ..................... yes
Qt Quick:
  Direct3D 12 ............................ no
  AnimatedImage item ..................... yes
  Canvas item ............................ yes
  Support for Qt Quick Designer .......... yes
  Flipable item .......................... yes
  GridView item .......................... yes
  ListView item .......................... yes
  TableView item ......................... yes
  Path support ........................... yes
  PathView item .......................... yes
  Positioner items ....................... yes
  Repeater item .......................... yes
  ShaderEffect item ...................... yes
  Sprite item ............................ yes
QtQuick3D:
  Assimp ................................. yes
  System Assimp .......................... no
Qt Scxml:
  ECMAScript data model for QtScxml ...... yes
Qt Gamepad:
  SDL2 ................................... no
Qt 3D:
  Assimp ................................. yes
  System Assimp .......................... no
  Output Qt3D GL traces .................. no
  Use SSE2 instructions .................. no
  Use AVX2 instructions .................. no
  Aspects:
    Render aspect ........................ yes
    Input aspect ......................... yes
    Logic aspect ......................... yes
    Animation aspect ..................... yes
    Extras aspect ........................ yes
Qt 3D Renderers:
  OpenGL Renderer ........................ yes
  RHI Renderer ........................... no
Qt 3D GeometryLoaders:
  Autodesk FBX ........................... no
Qt Wayland Drivers:
  EGL .................................... yes
  Raspberry Pi ........................... no
  XComposite EGL ......................... no
  XComposite GLX ......................... no
  DRM EGL ................................ yes
  libhybris EGL .......................... no
  Linux dma-buf server buffer integration . yes
  Vulkan-based server buffer integration . no
  Shm emulation server buffer integration . yes
Qt Wayland Client Shell Integrations:
  xdg-shell .............................. yes
  xdg-shell unstable v5 (deprecated) ..... yes
  xdg-shell unstable v6 .................. yes
  ivi-shell .............................. yes
  wl-shell (deprecated) .................. yes
Qt Wayland Client ........................ yes
Qt Wayland Compositor .................... yes
Qt Wayland Compositor Layer Plugins:
  VSP2 hardware layer integration ........ no
Qt Bluetooth:
  BlueZ .................................. no
  BlueZ Low Energy ....................... no
  Linux Crypto API ....................... no
  Native Win32 Bluetooth ................. no
  WinRT Bluetooth API (desktop & UWP) .... no
  WinRT advanced bluetooth low energy API (desktop & UWP) . no
Qt Sensors:
  sensorfw ............................... no
Qt Quick Controls 2:
  Styles ................................. Default Fusion Imagine Material Universal
Qt Quick Templates 2:
  Hover support .......................... yes
  Multi-touch support .................... yes
Qt Positioning:
  Gypsy GPS Daemon ....................... no
  WinRT Geolocation API .................. no
Qt Location:
  Qt.labs.location experimental QML plugin . no
  Geoservice plugins:
    OpenStreetMap ........................ yes
    HERE ................................. yes
    Esri ................................. yes
    Mapbox ............................... yes
    MapboxGL ............................. yes
    Itemsoverlay ......................... yes
QtXmlPatterns:
  XML schema support ..................... yes
Qt Multimedia:
  ALSA ................................... no
  GStreamer 1.0 .......................... no
  GStreamer 0.10 ......................... no
  Video for Linux ........................ yes
  OpenAL ................................. no
  PulseAudio ............................. no
  Resource Policy (libresourceqt5) ....... no
  Windows Audio Services ................. no
  DirectShow ............................. no
  Windows Media Foundation ............... no
Qt TextToSpeech:
  Flite .................................. no
  Flite with ALSA ........................ no
  Speech Dispatcher ...................... no
Qt Tools:
  Qt Assistant ........................... yes
  Qt Designer ............................ yes
  Qt Distance Field Generator ............ yes
  kmap2qmap .............................. yes
  Qt Linguist ............................ yes
  Mac Deployment Tool .................... no
  makeqpf ................................ yes
  pixeltool .............................. yes
  qdbus .................................. yes
  qev .................................... yes
  Qt Attributions Scanner ................ yes
  qtdiag ................................. yes
  qtpaths ................................ yes
  qtplugininfo ........................... yes
  Windows deployment tool ................ no
  WinRT Runner Tool ...................... no
Qt Tools:
  QDoc ................................... no

Note: Also available for Linux: linux-clang linux-icc

Note: Disabling X11 Accessibility Bridge: D-Bus or AT-SPI is missing.

WARNING: QDoc will not be compiled, probably because libclang could not be located. This means that you cannot build the Qt documentation.

Either ensure that llvm-config is in your PATH environment variable, or set LLVM_INSTALL_DIR to the location of your llvm installation.
On Linux systems, you may be able to install libclang by installing the libclang-dev or libclang-devel package, depending on your distribution.
On macOS, you can use Homebrew's llvm package.
On Windows, you must set LLVM_INSTALL_DIR to the installation path.

Qt is now configured for building. Just run 'gmake'.
Once everything is built, you must run 'gmake install'.
Qt will be installed into '/home/southgis/qt/5.15.17-gcc7-rel'.

Prior to reconfiguration, make sure you remove any leftovers from
the previous build.

```

