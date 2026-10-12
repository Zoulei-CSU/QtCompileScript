# qt-configure-args-validation

> 一个 AI Skill：**生成 / 校验 / 验证** Qt5 与 Qt6 的 `configure` 参数串。

本目录是 [WorkBuddy](https://www.workbuddy.cn/) 的 Skill 包，也可当作**纯文档 + 脚本**独立使用
（不需要 AI 也能跑 `scripts/` 里的校验工具）。

---

## 它解决什么问题

拼 Qt 的 `configure` 参数是个高危操作：

- **只报第一个错**。`qtConfAddError` 就是 `message(FATAL_ERROR)`，撞上第一个非法选项立刻中断，
  后面的雷你得再跑一轮 CI 才知道 —— 而 Qt 全量编译一轮要 35 分钟到几小时。
- **Qt5 和 Qt6 的选项不兼容**。比如 `-no-compile-examples` / `-verbose` / `-mp` / `-platform`
  / `-no-angle` 只有 Qt5 有，Qt6 传了直接报 `Unknown command line option`。
- **`-D<str>` 不是 CMake 变量**，而是"预处理器宏定义"。想透传 CMake 变量必须用 `-- -DXXX=yyy`，
  写错了**不报错但静默失效**。
- **"配置成功" ≠ "特性生效"**。`-openssl-linked` 在找不到 OpenSSL 时 Qt6 会**静默降级**，
  configure 全绿但产物里根本没有 OpenSSL。

这个 Skill 把上述坑都固化成检查清单 + 可执行脚本。

## 目录内容

```
SKILL.md                       主文档：规则、Qt5/Qt6 差异表、陷阱、排查流程
scripts/validate.py            离线校验 configure 参数串（先联网拉选项字典）
scripts/verify_linked_libs.py  读产物二进制的导入表，证明特性真的被链接
```

## 快速上手（不依赖 AI）

```bash
# 1) 离线校验一串 configure 参数
python3 scripts/validate.py --major 6 --args "-release -shared -opengl desktop -no-icu"

# 2) 验证产物是否真的链接了某个库
python3 scripts/verify_linked_libs.py /path/to/Qt-6.8.3.tar.xz --find openssl,psql,wayland
```

`validate.py` 的判定依据是 **Qt 官方源码里的选项定义**（`qt_cmdline.cmake` / `config_help.txt`），
不是文档网页 —— 文档页是节选，容易误判。

## 作为 WorkBuddy Skill 使用

把本目录复制到用户级 skill 目录即可被自动加载：

```bash
cp -r docs/skills/qt-configure-args-validation ~/.workbuddy/skills/
```

之后在对话里涉及"生成/修改/排查 Qt configure 参数"时会自动触发。

## 与本仓库的关系

本仓库的 `.github/scripts/gen-configure-args.{sh,ps1}` 就是按本 Skill 的规则写出来的；
两者应当**同步演进** —— 若在 CI 里踩到新的 configure 坑，请同时更新本 Skill，
避免知识只留在某个脚本的注释里。