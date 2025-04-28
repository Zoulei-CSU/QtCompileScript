# PyQt5编译安装



## 1.直接安装

PyQt5的编译，一定要注意版本对应关系，否则会各种出错。

编译`PyQt5 5.15.11 + sip 6.8.6`，可以用一个新的Python环境，直接pip安装依赖

```python
# PyQt5和sip需要组合，Bug很多，并且要自己修改
# 一定要用下面的版本
pip uninstall PyQt5 PyQt-builder sip -y
pip install PyQt5==5.15.11 PyQt-builder==1.16.0 sip==6.8.6
```

## 2.源码编译

### 2.1准备环境

```python
pip install PyQt-builder==1.16.0 sip==6.8.6	# 编译PyQt5 5.15.11版本用这个
# 或者
pip install pyqt-builder==1.15.4 sip==6.7.9	# 编译PyQt5 5.15.9版本用这个
```

**一定要注意版本！！！这个非常重要！！！**

### 2.2源码下载

下载PyQt5的源码和PyQt5_sip的源码，准备编译。

**一定要注意版本！！！这个非常重要！！！**

`PyQt5-5.15.9 + PyQt5_sip-12.11`

`PyQt5-5.15.11 + PyQt5_sip-12.15`

https://files.pythonhosted.org/packages/source/P/PyQt5/PyQt5-5.15.9.tar.gz
https://files.pythonhosted.org/packages/source/P/PyQt5_sip/PyQt5_sip-12.11.0.tar.gz

### 2.3编译安装PyQt5-sip

```bash
cd PyQt5_sip-12.11.0
pip install .
```

这会构建并安装 PyQt5 的 sip 模块桥接库，这是运行时注册 QtCore 的关键组件。

### 2.4编译安装PyQt5

PyQt5已经使用sip-install进行编译了。

源码包中有个`project.py`文件，可修改PyQt类的`__init__`函数中`self.bindings_factories`的列表，删除不需要的模块。这些不需要的模块的存在，可能导致编译失败。

```bash
call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"
set Path=D:\Qt\5.15.16-VS2022-rel\bin;%Path%

cd PyQt5-5.15.11
#sip-build  --verbose 
sip-install  --verbose --build-dir build
```

直接sip-install就好，不用先sip-build。每一次build或者install都会清空之前的编译内容，重新编译。

如果编译出现编码错误，可能是sip的一个bug，修改`Python\Lib\site-packages\sipbuild`下的`project.py`文件，将报错位置的`yield str(line, encoding=sys.stdout.encoding)`修改为`yield str(line, encoding='gbk')`即可。应该是Windows下的编码没处理。

### 2.5修改源码

PyQt5编译安装后，只是按照的Python封装，并没有对应的Qt二进制文件，可以手动拷贝进去，或者修改初始化文件，将Qt库加到环境变量中。

可以修改`Python\Lib\site-packages\PyQt5\__init__.py`文件，按照需要查找Qt二进制路径，比如下面的修改样例：

```python
import os, sys

# Support PyQt5 sub-packages that have been created by setuptools.
__path__ = __import__('pkgutil').extend_path(__path__, __name__)

def find_qt_path():
    # 检索Qt库路径
    path_list = [
        os.path.dirname(sys.executable),
        os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')),
        "D:/Qt/5.15.16-VS2022-rel/bin"
    ]

    qtPath = None
    qtPluginPath = None

    for path in path_list:
        abs_path = os.path.abspath(path) # 确保路径是绝对路径

        if not os.path.isdir(abs_path):
            continue

        qt5core_path = os.path.join(abs_path, "Qt5Core.dll")
        if os.path.isfile(qt5core_path):
            qtPath = os.path.dirname(qt5core_path)

            potential_plugin_paths = [
                abs_path,
                os.path.join(abs_path, "plugins"),          # 同级目录下的plugins
                os.path.join(os.path.dirname(abs_path), "plugins")  # 上一级目录下的plugins
            ]
            for pp_path in potential_plugin_paths:
                if os.path.isdir(os.path.join(abs_path, "platforms")):
                    qtPluginPath = pp_path
                    break

            if qtPath is not None:
                break

    return qtPath, qtPluginPath

def add_qt_to_path():
    # 检查当前目录下是否存在 Qt5Core.dll，当前目录存在就不用加各种环境变量了
    if os.path.isfile("Qt5Core.dll"):
        return
    
    qtPath, qtPluginPath = find_qt_path()
    # print(qtPath, qtPluginPath)

    if qtPath is None:
        raise RuntimeError("错误：找不到Qt5库文件")
    
    if qtPath not in sys.path:
        sys.path.insert(0, qtPath)
        # print("Add path", qtPath)

    if qtPluginPath is not None:
        if "QT_PLUGIN_PATH" not in os.environ or not os.environ["QT_PLUGIN_PATH"]:
            os.environ["QT_PLUGIN_PATH"] = qtPluginPath
            # print("Add plugin", qtPath)

    try:
        os.add_dll_directory(qtPath)
    except AttributeError:
        pass

add_qt_to_path()

del add_qt_to_path

```



### 2.6测试

install完成后，可以测试以下PyQt5是不是可以用了。

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import platform
import time
from datetime import datetime
from PyQt5.QtWidgets import (QApplication, QMainWindow, QLabel, 
                            QPushButton, QVBoxLayout, QWidget, QTextEdit)
from PyQt5.QtCore import QT_VERSION_STR, QTimer
from PyQt5.Qt import PYQT_VERSION_STR


class SystemInfoWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        
        # 设置窗口标题和大小
        self.setWindowTitle("PyQt5 系统信息测试")
        self.setGeometry(100, 100, 600, 450)
        
        # 创建主部件和布局
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout()
        central_widget.setLayout(layout)
        
        # 添加时间显示标签
        self.time_label = QLabel()
        self.time_label.setStyleSheet("font-size: 16px; font-weight: bold;")
        layout.addWidget(self.time_label)
        
        # 添加文本编辑框用于显示信息
        self.info_display = QTextEdit()
        self.info_display.setReadOnly(True)
        layout.addWidget(self.info_display)
        
        # 添加按钮
        self.refresh_button = QPushButton("刷新信息")
        self.refresh_button.clicked.connect(self.display_system_info)
        layout.addWidget(self.refresh_button)
        
        # 设置定时器更新时间
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_time)
        self.timer.start(1000)  # 每秒更新一次
        
        # 记录程序启动时间
        self.start_time = datetime.now()
        
        # 初始显示信息
        self.update_time()
        self.display_system_info()
    
    def update_time(self):
        """更新时间显示"""
        now = datetime.now()
        time_str = now.strftime("当前时间: %Y-%m-%d %H:%M:%S")
        self.time_label.setText(time_str)
    
    def get_boot_time(self):
        """尝试获取系统启动时间（跨平台兼容）"""
        try:
            # Linux系统
            if hasattr(platform, 'boot_time'):
                return datetime.fromtimestamp(platform.boot_time())
            
            # Windows系统（替代方法）
            elif platform.system() == 'Windows':
                import ctypes
                lib = ctypes.windll.kernel32
                tick = lib.GetTickCount64()
                return datetime.now() - time.timedelta(milliseconds=tick)
            
            # macOS系统（替代方法）
            elif platform.system() == 'Darwin':
                import subprocess
                boot_time = subprocess.check_output(['sysctl', '-n', 'kern.boottime']).decode()
                timestamp = boot_time.strip().split('=')[1].split(',')[0].strip()
                return datetime.fromtimestamp(int(timestamp))
            
            # 其他系统
            else:
                return None
                
        except Exception:
            return None
    
    def display_system_info(self):
        """收集并显示系统信息"""
        info = []
        
        # 系统信息
        info.append("=== 系统信息 ===")
        info.append(f"操作系统: {platform.system()} {platform.release()}")
        info.append(f"系统版本: {platform.version()}")
        info.append(f"机器类型: {platform.machine()}")
        info.append(f"处理器: {platform.processor()}")
        info.append("")
        
        # Python信息
        info.append("=== Python 信息 ===")
        info.append(f"Python 版本: {platform.python_version()}")
        info.append(f"Python 实现: {platform.python_implementation()}")
        info.append(f"Python 编译器: {platform.python_compiler()}")
        info.append("")
        
        # Qt和PyQt信息
        info.append("=== Qt 和 PyQt 信息 ===")
        info.append(f"Qt 运行时版本: {QT_VERSION_STR}")
        info.append(f"PyQt 版本: {PYQT_VERSION_STR}")
        info.append(f"PyQt 绑定的 Qt 版本: {PYQT_VERSION_STR.split('.')[0]}.{PYQT_VERSION_STR.split('.')[1]}")
        info.append("")
        
        # 时间信息
        info.append("=== 时间信息 ===")
        info.append(f"程序启动时间: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        boot_time = self.get_boot_time()
        if boot_time:
            info.append(f"系统启动时间: {boot_time.strftime('%Y-%m-%d %H:%M:%S')}")
        else:
            info.append("系统启动时间: 无法获取（平台不支持）")
        
        # 显示所有信息
        self.info_display.setPlainText("\n".join(info))


if __name__ == "__main__":
    # 创建应用实例
    app = QApplication(sys.argv)
    
    # 创建并显示主窗口
    window = SystemInfoWindow()
    window.show()
    
    # 运行应用主循环
    sys.exit(app.exec_())
```



# 将自定义类编译进PyQt5

理论上说，可以自己编写模块，编写sip封装，但各种尝试均告失败。因此，尝试写一个简单的类，将其加入到PyQt5的QtWidgets模块中。

## 1.准备自定义C++代码

自定义扩展类：

```cpp
// idataextent.h
#ifndef IDATA_EXTENT_H
#define IDATA_EXTENT_H

#include <QWidget>

class iDataDemoWidget {

public:
    explicit iDataDemoWidget();
    virtual ~iDataDemoWidget();

    static QWidget* getMainWindow();
    static unsigned long long windowPtr2Long(const QWidget* w);
    static QWidget* long2WindowPtr(unsigned long long ptr);
};

#endif // IDATA_EXTENT_H 
```

```cpp
// idataextent.cpp
#include "idataextent.h"

#include <QApplication>

iDataDemoWidget::iDataDemoWidget()
{
}
iDataDemoWidget::~iDataDemoWidget()
{
}

QWidget* iDataDemoWidget::getMainWindow()
{
    QWidget* mainWidows = nullptr;
	unsigned long long ptr = qApp->property("MAINWINDOW").toULongLong();
	if (ptr > 0xFF)
		mainWidows = (QWidget*)ptr;
    return mainWidows;
}

unsigned long long iDataDemoWidget::windowPtr2Long(const QWidget* w)
{
    return (unsigned long long)w;
} 

QWidget* iDataDemoWidget::long2WindowPtr(unsigned long long ptr)
{
	if (ptr < 0xFF)
		return nullptr;

    return (QWidget*)ptr;
}
```

## 2.自定义sip文件

自定义sip文件，并将其报错到源码路径sip\QtWidgets下：

```cpp
// idataextent.sip 

class iDataDemoWidget
{
%TypeHeaderCode
#include <idataextent.h>
%End

public:
    iDataDemoWidget();
    virtual ~iDataDemoWidget();
    
    static QWidget* getMainWindow();
    static long long windowPtr2Long(QWidget* w);
    static QWidget* long2WindowPtr(long long ptr);
};

```

## 3.修改QtWidgetsmod.sip文件

修改源码sip\QtWidgets目录下的QtWidgetsmod.sip，在文件最后将idataextent.sip加入其中：

```cpp
%Include idataextent.sip
```



## 4.修改project.py

修改project.py文件，将自定义类加入编译。找到其中QtWidgets类的代码，在其中添加如下的generate函数，目的是将上面的cpp和h文件加入编译。

```python
class QtWidgets(PyQtBindings):
    """ The QtWidgets bindings. """

    def __init__(self, project):
        """ Initialise the bindings. """

        super().__init__(project, 'QtWidgets', qmake_QT=['widgets'],
                test_headers=['qwidget.h'], test_statement='new QWidget()')
        
    def generate(self):
        """ Generate the bindings source code and return the corresponding
        buildable.
        """

        buildable = super().generate()

        work_path = "G:/build/PyQt5-5.15.9"

        cpp = 'idataextent.cpp'
        # out_path = os.path.join(buildable.build_dir, cpp)
        out_path = work_path + "/" + cpp
        buildable.sources.append(out_path)
        # print("QtWidgets build Files:", buildable.sources)

        if not work_path in buildable.include_dirs:
            buildable.include_dirs.append(work_path)
        # print("QtWidgets include paths:", buildable.include_dirs)

        return buildable
```

开始编译后，将上面的cpp文件和h文件，放到源码的编辑目录下，等待编译使用。路径就是上面代码里写的。

如果文件放在了build文件下，每次build或者install都会被清理。

## 5.编译

参考上面的方式，编译PyQt5。编译安装完成后，自定义类就被放在了QtWidgets模块下。

## 6.测试

install完成后，可以测试以下PyQt5是不是可以用了。顺便测试iDataDemoWidget是否工作。

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
from PyQt5.QtWidgets import (QApplication, QMainWindow)
from PyQt5.QtWidgets import iDataDemoWidget

if __name__ == "__main__":
    app = QApplication(sys.argv)
    
    # 创建并显示主窗口
    window = QMainWindow()
    window.setWindowTitle("PyQt5 测试")
    window.setGeometry(100, 100, 600, 450)
    
    # 测试iDataDemoWidget
    ptr = iDataDemoWidget.windowPtr2Long(window)
    print("Test ptr is:", ptr)
    w = iDataDemoWidget.long2WindowPtr(ptr)
    if w is not None:
        w.setWindowTitle("iDataDemoWidget 测试")

    m = iDataDemoWidget.getMainWindow()
    if m is None:
        print("MainWindow not set.")
    else:
        print("MainWindow is:", iDataDemoWidget.windowPtr2Long(m))
    
    window.show()
    
    # 运行应用主循环
    sys.exit(app.exec_())
```

