```shell
# 安装开发库
sudo apt install build-essential cmake
sudo apt install libgl1-mesa-dev  libglu1-mesa-dev
sudo apt install libegl1-mesa-dev
sudo apt install libpq-dev

sudo apt install libxcb*dev
sudo apt install libxkbcommon-dev libxkbcommon-x11-dev libxkbcommon0

#或者yum安装
yum install -y autoconf automake libtool make gcc gcc-c++ pkgconfig texinfo
yum install mesa-libGL-devel mesa-libEGL-devel mesa-libGLU-devel
yum install libxcb-devel xcb-util-devel xcb-util-image-devel xcb-util-keysyms-devel xcb-util-renderutil-devel xcb-util-wm-devel
yum install libX11-devel libXrender-devel libXi-devel libXext-devel libXfixes-devel libXrandr-devel libXcursor-devel libXinerama-devel libXcomposite-devel libdrm-devel
yum install libxkbcommon-devel libxkbcommon-x11-devel
yum install libinput-devel libudev-devel 
yum install compat-openssl10-devel
yum install fontconfig-devel
yum install libffi-devel
yum install libsecret-devel
yum install sqlite-devel
yum install bison flex pcre2-devel

#编译过程中，需要prel
yum install -y perl

: << 'EOF'
# 如果需要网络，可以设置代理
export http_proxy=http://172.16.50.112:7890
export https_proxy=http://172.16.50.112:7890
export HTTP_PROXY=http://172.16.50.112:7890
export HTTPS_PROXY=http://172.16.50.112:7890
EOF

# iconv编码转换
iconv -l | grep GBK	#是否支持GBK
iconv -f GBK -t UTF-8 broken.txt -o fixed.txt	#转UTF-8
# 主要iconv和icu必须有一个

# 注意Fontconfig，如果没有，则需要自备字体文件

#SSL, 需要-openssl-linked 静态连接到ssl库？还是-openssl动态连接？
# 如果系统库里有，可以直接连接系统库
#./config enable-shared --prefix=$HOME/Qt/openssl --openssldir=$HOME/Qt/openssl
#-openssl OPENSSL_INCDIR="$HOME/Qt/openssl/include" OPENSSL_LIBDIR="$HOME/Qt/openssl/lib"
export LD_LIBRARY_PATH=$HOME/Qt/openssl/lib:$LD_LIBRARY_PATH

#最好带上-qt-libpng，使用源码内置png库，否则遇到系统png版本太低，就惨了

[zouleik@localhost build]$ source ~/opt/gcc-10/enable
[zouleik@localhost build]$ ../qt-everywhere-src-5.15.17/configure -opensource -confirm-license -xcb -xcb-xlib -release -ltcg -prefix "$HOME/Qt/5.15.17-gcc10-rel" -qt-libpng -no-qml-debug -no-angle -opengl desktop  -no-compile-examples -nomake tests -nomake examples -skip qtwebengine -skip qtwebview  
#-openssl OPENSSL_INCDIR="$HOME/Qt/openssl/include" OPENSSL_LIBDIR="$HOME/Qt/openssl/lib"

+ cd qtbase
+ /home/zouleik/Qt/build/qt-everywhere-src-5.15.17/qtbase/configure -top-level -opensource -confirm-license -xcb -xcb-xlib -release -ltcg -prefix /home/zouleik/Qt/5.15.17-gcc10-rel -qt-libpng -no-qml-debug -no-angle -opengl desktop -no-compile-examples -nomake tests -nomake examples -skip qtwebengine -skip qtwebview
Preparing build tree...
Creating qmake...
...............................................................................................Done.
Info: creating super cache file /home/zouleik/Qt/build/build/.qmake.super
Info: creating cache file /home/zouleik/Qt/build/build/.qmake.cache
Info: creating stash file /home/zouleik/Qt/build/build/.qmake.stash

This is the Qt Open Source Edition.

You have already accepted the terms of the Open Source license.

Running configuration tests...
Checking for machine tuple... yes
Checking for valid makespec... yes
Checking for target architecture... x86_64
Checking for SSE2 instructions... yes
Checking for AES new instructions... yes
Checking for alloca() in alloca.h... yes
Checking for SSE3 instructions... yes
Checking for SSSE3 instructions... yes
Checking for SSE4.1 instructions... yes
Checking for SSE4.2 instructions... yes
Checking for AVX instructions... yes
Checking for AVX2 instructions... yes
Checking for AVX512 F instructions... yes
Checking for AVX512 BW instructions... yes
Checking for AVX512 CD instructions... yes
Checking for AVX512 DQ instructions... yes
Checking for AVX512 ER instructions... yes
Checking for AVX512 IFMA instructions... yes
Checking for AVX512 PF instructions... yes
Checking for AVX512 VBMI instructions... yes
Checking for AVX512 VL instructions... yes
Checking for C++14 support... yes
Checking for C++17 support... yes
Checking for C99 support... yes
Checking for C11 support... yes
Checking for pkg-config... yes
Checking for D-Bus >= 1.2... yes
Checking for dlopen()... yes
Checking for new dtags support... yes
Checking for F16C instructions... yes
Checking for D-Bus >= 1.2 (host)... yes
Checking for Support for Intel Control-flow Enforcement Technology... no
Checking for udev... yes
Checking for POSIX fallocate()... yes
Checking for precompiled header support... yes
Checking for RDRAND instruction... yes
Checking for RDSEED instruction... yes
Checking for symbol visibility support... yes
Checking for -Bsymbolic-functions support... yes
Checking for SHA new instructions... yes
Checking for Signaling NaN for doubles... yes
Checking for STL compatibility... yes
Checking for zlib... yes
Checking for Intrinsics without -mXXX argument... yes
Checking for Zstandard... no
Checking for clock_gettime()... yes
Checking for POSIX monotonic clock... yes
Checking for C++11 <future>... yes
Checking for eventfd... yes
Checking for futimens()... yes
Checking for getauxval()... yes
Checking for getentropy()... yes
Checking for GLib... yes
Checking for GNU libc... yes
Checking for POSIX iconv... yes
Checking for ICU... yes
Checking for inotify... yes
Checking for SysV IPC... yes
Checking for linkat()... yes
Checking for PCRE2... yes
Checking for ppoll()... yes
Checking for renameat2()... yes
Checking for slog2... no
Checking for statx() in libc... yes
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
Checking for atspi... yes
Checking for KMS... no
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
Checking for libinput... no
Checking for LinuxFB... yes
Checking for mtdev... no
Checking for OpenVG... no
Checking for default QPA platform... xcb
Checking for HarfBuzz... yes
Checking for libjpeg... yes
Checking for libmd4c... no
Checking for XCB XInput... yes
Checking for tslib... no
Checking for Vulkan... no
Checking for X11 prefix... /usr
Checking for XCB GLX... yes
Checking for X11 session management... no
Checking for GTK+ >= 3.6... yes
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
Checking for DRM EGL Server... yes
Checking for Wayland EGL library... yes
Checking for libhybris EGL Server... no
Checking for XComposite... yes
Checking for GLX... yes
Checking for wayland-server... yes
Checking for BlueZ... no
Checking for sensorfw... no
Checking for Gypsy... no
Checking for WinRT Geolocation API... no
Checking for ALSA... no
Checking for GStreamer 1.0... yes
Checking for GStreamer App 1.0... yes
Checking for GStreamer encoding-profile.h... yes
Checking for GStreamer OpenGL 1.0... yes
Checking for GStreamer Photography 1.0... no
Checking for Video for Linux... yes
Checking for OpenAL... no
Checking for PulseAudio >= 0.9.10... no
Checking for libresourceqt5... no
Checking for Flite... no
Checking for Speech Dispatcher... no
Checking for libclang... no
Done running configuration tests.

Configure summary:

Build type: linux-g++ (x86_64, CPU features: mmx sse sse2)
Compiler: gcc 10.5.0
Configuration: sse2 aesni sse3 ssse3 sse4_1 sse4_2 avx avx2 avx512f avx512bw avx512cd avx512dq avx512er avx512ifma avx512pf avx512vbmi avx512vl enable_new_dtags f16c largefile ltcg precompile_header rdrnd rdseed shani x86SimdAlways shared shared rpath release c++11 c++14 c++17 c++1z concurrent dbus reduce_exports reduce_relocations stl
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
    SSE .................................. SSE2 SSE3 SSSE3 SSE4.1 SSE4.2
    AVX .................................. AVX AVX2
    AVX512 ............................... F ER CD PF DQ BW VL IFMA VBMI
    Other x86 ............................ AES F16C RDRAND SHA
    Intrinsics without -mXXX option ...... yes
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
  udev ................................... yes
  Using system zlib ...................... yes
  Zstandard support ...................... no
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
    Using system PCRE2 ................... yes
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
    Using system HarfBuzz ................ yes
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
    EGLFS EGLDevice ...................... no
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
  GTK+ ................................... yes
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
  Use SSE2 instructions .................. yes
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
  XComposite EGL ......................... yes
  XComposite GLX ......................... yes
  DRM EGL ................................ yes
  libhybris EGL .......................... no
  Linux dma-buf server buffer integration . no
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
  GStreamer 1.0 .......................... yes
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

WARNING: QDoc will not be compiled, probably because libclang could not be located. This means that you cannot build the Qt documentation.

Either ensure that llvm-config is in your PATH environment variable, or set LLVM_INSTALL_DIR to the location of your llvm installation.
On Linux systems, you may be able to install libclang by installing the libclang-dev or libclang-devel package, depending on your distribution.
On macOS, you can use Homebrew's llvm package.
On Windows, you must set LLVM_INSTALL_DIR to the installation path.

Qt is now configured for building. Just run 'gmake'.
Once everything is built, you must run 'gmake install'.
Qt will be installed into '/home/zouleik/Qt/5.15.17-gcc10-rel'.

Prior to reconfiguration, make sure you remove any leftovers from
the previous build.
```

