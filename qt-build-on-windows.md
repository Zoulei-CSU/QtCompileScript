# Windows上源码编译Qt

## 1.配置环境

### 1.1安装VS

### 1.2安装Python（非必须）

### 1.3提前准备好其他依赖库（非必须）

如果需要，编译前，可以提前准备好其他依赖库。不准备也没关系，也可编译。比如我需要Oracle、Postgres数据库的支持，所以就准备了oci、libpq、openssl等三方库。



## 2.下载源码包

可以从官网下载，也可从镜像库下载。下载qt-everywhere的包，这个是完整代码包。

https://mirrors.tuna.tsinghua.edu.cn/qt/official_releases/qt/5.15/5.15.16/single/qt-everywhere-opensource-src-5.15.16.tar.xz

## 3.编译

Qt源码编译比较简单，直接configure，之后nmake、install即可。

如果有三方库，可通过`-I`和`-L`的方式传递到configure参数里。

```shell
# 将Python设置到环境变量（非必须）
set Path=D:\WinPython\WPy64-310111dot\python-3.10.11.amd64;%Path%

# 创建编译目录
md build
cd build

# configure
..\qt-everywhere-src-5.15.16\configure.bat -opensource -confirm-license -verbose -platform win32-msvc -release -gui -widgets -mp -qt-zlib -no-icu -openssl-linked -opengl dynamic -qt-freetype -qt-harfbuzz -qt-libpng -qt-libjpeg -qt-sqlite -nomake tests -nomake examples -prefix "F:\Qt\5.15.16-VS2022-rel" -skip qtdoc -skip qt3d -skip qtwebview -skip qtwebengine ^
-I"F:\temp\gdalbuld2024\install\libpq\include" -L"F:\temp\gdalbuld2024\install\libpq\lib"  ^
-I"F:\temp\gdalbuld2024\install\oci12\include" -L"F:\temp\gdalbuld2024\install\oci12\lib\msvc"  ^
-I"F:\temp\gdalbuld2024\install\openssl\include" -L"F:\temp\gdalbuld2024\install\openssl\lib"
```



样例Configure 输出：

```
Configure summary:

Build type: win32-msvc (x86_64, CPU features: sse sse2)
Compiler: msvc 193632534
Configuration: sse2 aesni sse3 ssse3 sse4_1 sse4_2 avx avx2 avx512f avx512bw avx512cd avx512dq avx512er avx512ifma avx512pf avx512vbmi avx512vl compile_examples f16c largefile msvc_mp precompile_header rdrnd rdseed shani x86SimdAlways shared shared release c++11 c++14 c++17 c++1z concurrent dbus no-pkg-config stl
Build options:
  Mode ................................... release
  Optimize release build for size ........ no
  Building shared libraries .............. yes
  Using C standard ....................... C89
  Using C++ standard ..................... C++17
  Relocatable ............................ yes
  Using precompiled headers .............. yes
  Using LTCG ............................. no
  Target compiler supports:
    SSE .................................. SSE2 SSE3 SSSE3 SSE4.1 SSE4.2
    AVX .................................. AVX AVX2
    AVX512 ............................... F ER CD PF DQ BW VL IFMA VBMI
    Other x86 ............................ AES F16C RDRAND SHA
  Build parts ............................ libs tools
  App store compliance ................... no
Qt modules and options:
  Qt Concurrent .......................... yes
  Qt D-Bus ............................... yes
  Qt D-Bus directly linked to libdbus .... no
  Qt Gui ................................. yes
  Qt Network ............................. yes
  Qt Sql ................................. yes
  Qt Testlib ............................. yes
  Qt Widgets ............................. yes
  Qt Xml ................................. yes
Support enabled for:
  Using pkg-config ....................... no
  udev ................................... no
  Using system zlib ...................... no
  Zstandard support ...................... no
Qt Core:
  DoubleConversion ....................... yes
    Using system DoubleConversion ........ no
  GLib ................................... no
  iconv .................................. no
  ICU .................................... no
  Built-in copy of the MIME database ..... yes
  Tracing backend ........................ <none>
  Logging backends:
    journald ............................. no
    syslog ............................... no
    slog2 ................................ no
  PCRE2 .................................. yes
    Using system PCRE2 ................... no
Qt Network:
  getifaddrs() ........................... no
  IPv6 ifname ............................ no
  libproxy ............................... no
  Schannel ............................... no
  OpenSSL ................................ yes
    Qt directly linked to OpenSSL ........ yes
  OpenSSL 1.1 ............................ yes
  DTLS ................................... yes
  OCSP-stapling .......................... yes
  SCTP ................................... no
  Use system proxies ..................... yes
  GSSAPI ................................. no
Qt Gui:
  Accessibility .......................... yes
  FreeType ............................... yes
    Using system FreeType ................ no
  HarfBuzz ............................... yes
    Using system HarfBuzz ................ no
  Fontconfig ............................. no
  Image formats:
    GIF .................................. yes
    ICO .................................. yes
    JPEG ................................. yes
      Using system libjpeg ............... no
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
    ANGLE ................................ yes
    Combined ANGLE Library ............... no
    Desktop OpenGL ....................... no
    Dynamic OpenGL ....................... yes
    OpenGL ES 2.0 ........................ no
    OpenGL ES 3.0 ........................ no
    OpenGL ES 3.1 ........................ no
    OpenGL ES 3.2 ........................ no
  Vulkan ................................. no
  Session Management ..................... yes
Features used by QPA backends:
  evdev .................................. no
  libinput ............................... no
  INTEGRITY HID .......................... no
  mtdev .................................. no
  tslib .................................. no
  xkbcommon .............................. no
  X11 specific:
    XLib ................................. no
    XCB Xlib ............................. no
    EGL on X11 ........................... no
    xkbcommon-x11 ........................ no
QPA backends:
  DirectFB ............................... no
  EGLFS .................................. no
  LinuxFB ................................ no
  VNC .................................... no
  Windows:
    Direct 2D ............................ yes
    DirectWrite .......................... yes
    DirectWrite 2 ........................ yes
Qt Sql:
  SQL item models ........................ yes
Qt Widgets:
  GTK+ ................................... no
  Styles ................................. Fusion Windows WindowsVista
Qt PrintSupport:
  CUPS ................................... no
Qt Sql Drivers:
  DB2 (IBM) .............................. no
  InterBase .............................. no
  MySql .................................. no
  OCI (Oracle) ........................... yes
  ODBC ................................... yes
  PostgreSQL ............................. yes
  SQLite2 ................................ no
  SQLite ................................. yes
    Using system provided SQLite ......... no
  TDS (Sybase) ........................... no
Qt Testlib:
  Tester for item models ................. yes
Serial Port:
  ntddmodm ............................... yes
Qt SerialBus:
  Socket CAN ............................. no
  Socket CAN FD .......................... no
  SerialPort Support ..................... yes
Further Image Formats:
  JasPer ................................. no
  MNG .................................... no
  TIFF ................................... yes
    Using system libtiff ................. no
  WEBP ................................... yes
    Using system libwebp ................. no
Qt QML:
  QML network support .................... yes
  QML debugging and profiling support .... yes
  QML just-in-time compiler .............. yes
  QML sequence object .................... yes
  QML XML http request ................... yes
  QML Locale ............................. yes
Qt QML Models:
  QML list model ......................... yes
  QML delegate model ..................... yes
Qt Quick:
  Direct3D 12 ............................ yes
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
Qt Wayland Client ........................ no
Qt Wayland Compositor .................... no
Qt Bluetooth:
  BlueZ .................................. no
  BlueZ Low Energy ....................... no
  Linux Crypto API ....................... no
  Native Win32 Bluetooth ................. no
  WinRT Bluetooth API (desktop & UWP) .... yes
  WinRT advanced bluetooth low energy API (desktop & UWP) . yes
Qt Sensors:
  sensorfw ............................... no
Qt Quick Controls 2:
  Styles ................................. Default Fusion Imagine Material Universal
Qt Quick Templates 2:
  Hover support .......................... yes
  Multi-touch support .................... yes
Qt Positioning:
  Gypsy GPS Daemon ....................... no
  WinRT Geolocation API .................. yes
Qt Location:
  Qt.labs.location experimental QML plugin . no
  Geoservice plugins:
    OpenStreetMap ........................ yes
    HERE ................................. yes
    Esri ................................. yes
    Mapbox ............................... yes
    MapboxGL ............................. no
    Itemsoverlay ......................... yes
QtXmlPatterns:
  XML schema support ..................... yes
Qt Multimedia:
  ALSA ................................... no
  GStreamer 1.0 .......................... no
  GStreamer 0.10 ......................... no
  Video for Linux ........................ no
  OpenAL ................................. no
  PulseAudio ............................. no
  Resource Policy (libresourceqt5) ....... no
  Windows Audio Services ................. yes
  DirectShow ............................. yes
  Windows Media Foundation ............... yes
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
  Windows deployment tool ................ yes
  WinRT Runner Tool ...................... no
Qt Tools:
  QDoc ................................... no

Note: When linking against OpenSSL, you can override the default
library names through OPENSSL_LIBS.
For example:
    OPENSSL_LIBS='-L/opt/ssl/lib -lssl -lcrypto' ./configure -openssl-linked

Note: No wayland-egl support detected. Cross-toolkit compatibility disabled.

WARNING: QDoc will not be compiled, probably because libclang could not be located. This means that you cannot build the Qt documentation.

Either ensure that llvm-config is in your PATH environment variable, or set LLVM_INSTALL_DIR to the location of your llvm installation.
On Linux systems, you may be able to install libclang by installing the libclang-dev or libclang-devel package, depending on your distribution.
On macOS, you can use Homebrew's llvm package.
On Windows, you must set LLVM_INSTALL_DIR to the installation path.

Qt is now configured for building. Just run 'nmake'.
Once everything is built, you must run 'nmake install'.
Qt will be installed into 'F:\Qt\5.15.16-VS2022-rel'.

Prior to reconfiguration, make sure you remove any leftovers from
the previous build.
```



