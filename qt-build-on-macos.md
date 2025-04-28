# MacOS上源码编译Qt

## 1.安装brew以及相关依赖

brew安装参考其他文档。如果要编译Postgres数据库插件，要安装libpq

```shell
brew install libpq # 安装Postgres的库
```



## 2.下载源码包

可以从官网下载，也可从镜像库下载。下载qt-everywhere的包，这个是完整代码包。

https://mirrors.tuna.tsinghua.edu.cn/qt/official_releases/qt/5.15/5.15.16/single/qt-everywhere-opensource-src-5.15.16.tar.xz

```shell
mkdir -p /Volumes/MacData/Dev/qt-src/build
cd /Volumes/MacData/Dev/qt-src/build
```

## 3.编译

Qt源码编译比较简单，直接configure，之后make、install即可。

```shell
../qt-everywhere-src-5.15.16/configure -opensource -confirm-license -release -prefix "/Volumes/MacData/Dev/Qt/5.15.16" -DCMAKE_OSX_ARCHITECTURES="x86_64" -no-qml-debug  -no-compile-examples -nomake tests -nomake examples -skip qtwebengine -skip qtwebview  -skip qtscript -skip qtquick3d
```



样例Configure 输出：

```
Configure summary:

Build type: macx-clang (x86_64, CPU features: cx16 mmx sse sse2 sse3 ssse3 sse4.1)
Compiler: clang (Apple) 16.0.0
Configuration: sse2 aesni sse3 ssse3 sse4_1 sse4_2 avx avx2 avx512f avx512bw avx512cd avx512dq avx512er avx512ifma avx512pf avx512vbmi avx512vl f16c largefile precompile_header rdrnd rdseed shani x86SimdAlways shared shared qt_framework rpath release c++11 c++14 c++17 c++1z concurrent dbus no-pkg-config reduce_exports stl
Build options:
  Mode ................................... release
  Optimize release build for size ........ no
  Building shared libraries .............. yes
  Using C standard ....................... C11
  Using C++ standard ..................... C++17
  Using ccache ........................... no
  Relocatable ............................ yes
  Using precompiled headers .............. yes
  Using LTCG ............................. no
  Target compiler supports:
    SSE .................................. SSE2 SSE3 SSSE3 SSE4.1 SSE4.2
    AVX .................................. AVX AVX2
    AVX512 ............................... F ER CD PF DQ BW VL IFMA VBMI
    Other x86 ............................ AES F16C RDRAND SHA
    Intrinsics without -mXXX option ...... yes
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
  Using system zlib ...................... yes
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
  CoreWLan ............................... yes
  getifaddrs() ........................... yes
  IPv6 ifname ............................ yes
  libproxy ............................... no
  SecureTransport ........................ yes
  OpenSSL ................................ no
    Qt directly linked to OpenSSL ........ no
  OpenSSL 1.1 ............................ no
  DTLS ................................... no
  OCSP-stapling .......................... no
  SCTP ................................... no
  Use system proxies ..................... yes
  GSSAPI ................................. yes
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
  EGL .................................... no
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
Qt Sql:
  SQL item models ........................ yes
Qt Widgets:
  GTK+ ................................... no
  Styles ................................. Fusion macOS Windows
Qt PrintSupport:
  CUPS ................................... yes
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
Qt Wayland Client ........................ no
Qt Wayland Compositor .................... no
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
  Video for Linux ........................ no
  OpenAL ................................. yes
  PulseAudio ............................. no
  Resource Policy (libresourceqt5) ....... no
  AVFoundation ........................... yes
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
  Mac Deployment Tool .................... yes
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

Note: No wayland-egl support detected. Cross-toolkit compatibility disabled.

WARNING: QDoc will not be compiled, probably because libclang could not be located. This means that you cannot build the Qt documentation.

Either ensure that llvm-config is in your PATH environment variable, or set LLVM_INSTALL_DIR to the location of your llvm installation.
On Linux systems, you may be able to install libclang by installing the libclang-dev or libclang-devel package, depending on your distribution.
On macOS, you can use Homebrew's llvm package.
On Windows, you must set LLVM_INSTALL_DIR to the installation path.

Qt is now configured for building. Just run 'make'.
Once everything is built, you must run 'make install'.
Qt will be installed into '/Volumes/MacData/Dev/Qt/5.15.16'.

Prior to reconfiguration, make sure you remove any leftovers from
the previous build.
```



