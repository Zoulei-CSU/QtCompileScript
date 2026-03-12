# Github访问方法

临时设置git访问环境，只在当前打开的终端中生效。

Github可以使用API key访问，API key一般会经常更换，当前的API key是：

```
ghp_xxxx你的密钥xxxxx
```



## 1. 设置环境变量（在新的终端窗口中）
```shell
export GIT_AUTHOR_NAME="Zoulei-CSU"
export GIT_AUTHOR_EMAIL="zoulei.csu@gmail.com"
export GIT_COMMITTER_NAME="Zoulei-CSU"
export GIT_COMMITTER_EMAIL="zoulei.csu@gmail.com"
```

Windows下：

```bash
set GIT_AUTHOR_NAME="Zoulei-CSU"
set GIT_AUTHOR_EMAIL="zoulei.csu@gmail.com"
set GIT_COMMITTER_NAME="Zoulei-CSU"
set GIT_COMMITTER_EMAIL="zoulei.csu@gmail.com"
```



## 2.克隆GitHub仓库

```shell
# 克隆代码可以用下面的方式
git clone https://github-user:ghp_your_pat_here@github.com/github-user/repo-name.git
# 即
git clone https://用户名:ghp密钥@github.com/username/repo.git
```

```shell
# 克隆（第一次）
git clone https://github.com/Zoulei-CSU/QtCompileScript.git
# 会提示输入用户名和密码
# 用户名：你的 GitHub 用户名
# 密码：粘贴你的 token（输入时不会显示）

# 或者直接写在 URL 里（不推荐明文写死）
git clone https://你的用户名:你的token@github.com/username/repo.git
git clone https://Zoulei-CSU:ghp_xxxx你的密钥xxxxx@github.com/Zoulei-CSU/QtCompileScript.git
```



## 3. 或者：如果是现有仓库，添加GitHub remote
```shell
git remote add github https://github-user:ghp_your_pat_here@github.com/github-user/repo-name.git
```



## 4. 进行一些修改
```shell
echo "test content" >> test.txt
git add test.txt
```



## 5. 提交（自动使用GitHub用户信息）
```shell
git commit -m "测试提交"
```



## 6. 推送到GitHub
```shell
git push github main
```



## 7. 从GitHub拉取更新
```shell
git pull github main
```



## 8.GHP密钥更新

如果使用ghp的方式同步的代码库，**ghp密钥（GitHub Personal Access Token）** 可能会在一段时间后过期，之后只能重新生成一个新的，并且更新已有仓库的远程地址。

1.先查看远程仓库地址

```bash
git remote -v
# 显示出以下内容
origin  https://Zoulei-CSU:ghp_old_expired_token@github.com/github-user/repo-name.git (fetch)
origin  https://Zoulei-CSU:ghp_old_expired_token@github.com/github.com/github-user/repo-name.git (push)
```

2.修改远程仓库地址

方法一：直接替换整个URL

```bash
git remote set-url origin https://Zoulei-CSU:YOUR_NEW_GHP_TOKEN@github.com/github-user/repo-name.git
```

方法二：如果用户名和仓库都不变，推荐更安全的做法：

```bash
# 先移除就的远程地址
git remote remove origin
# 再添加新的远程地址
git remote add origin https://Zoulei-CSU:YOUR_NEW_GHP_TOKEN@github.com/github-user/repo-name.git
```

3.验证

之后，可以执行git命令来测试是否生效：`git fetch origin`

如果命令执行成功，没有要求输入密码或报认证错误，则说明更新成功。之后您就可以正常进行 `git pull`、`git push`等操作了。

`git push --set-upstream origin main`



## 9.常用Git命令

下面是 **Git 命令行最常用、最实用的功能总结**（按日常使用频率排序），掌握这 30 多条命令，已经能搞定 95% 以上的工作。

| 分类               | 命令                                                         | 说明 / 常见用法                                          |
| ------------------ | ------------------------------------------------------------ | -------------------------------------------------------- |
| **初始化与配置**   | `git config --global user.name "张三"`                       | 设置全局提交者姓名                                       |
|                    | `git config --global user.email zhangsan@example.com`        | 设置全局提交者邮箱                                       |
|                    | `git config --list`                                          | 查看所有配置                                             |
|                    | `git init`                                                   | 在当前目录新建仓库                                       |
|                    | `git clone https://github.com/xxx/yyy.git`                   | 克隆仓库                                                 |
| **基本增删改**     | `git status`                                                 | 查看当前状态（最常用！）                                 |
|                    | `git add .`                                                  | 添加所有改动                                             |
|                    | `git add file1 file2`                                        | 添加指定文件                                             |
|                    | `git add -p`                                                 | 交互式添加（可以只 add 部分 hunk，超实用）               |
|                    | `git commit -m "fix bug"`                                    | 普通提交                                                 |
|                    | `git commit -am "msg"`                                       | 一次性 add + commit（只对已跟踪的文件有效）              |
|                    | `git commit --amend`                                         | 修改上一次提交（改消息或加文件）                         |
| **远程操作**       | `git remote -v`                                              | 查看远程仓库地址                                         |
|                    | `git remote add origin https://...`                          | 添加远程（通常叫 origin）                                |
|                    | `git remote set-url origin https://...`                      | 更换远程地址                                             |
|                    | `git remote set-url origin https://token@github.com/xxx/yyy.git` | 用 token 永久免密（推荐）                                |
|                    | `git push origin main`                                       | 推送 main 分支                                           |
|                    | `git push -u origin main`                                    | 第一次推送并绑定上游分支（以后只需 git push）            |
|                    | `git push --force-with-lease`                                | 安全强制推送（推荐，比 --force 安全）                    |
|                    | `git pull`                                                   | = fetch + merge                                          |
|                    | `git pull --rebase`                                          | = fetch + rebase（保持线性历史，更干净）                 |
| **分支管理**       | `git branch`                                                 | 列出本地分支                                             |
|                    | `git branch -r`                                              | 列出远程分支                                             |
|                    | `git branch -a`                                              | 本地+远程全列出                                          |
|                    | `git checkout -b feature/xxx`                                | 创建并切换到新分支                                       |
|                    | `git switch -c feature/xxx`                                  | 同上（Git 2.23+ 新语法，更清晰）                         |
|                    | `git branch -d dev`                                          | 删除已合并的分支                                         |
|                    | `git branch -D dev`                                          | 强制删除分支                                             |
|                    | `git push origin --delete dev`                               | 删除远程分支                                             |
| **查看历史与差异** | `git log`                                                    | 查看提交历史                                             |
|                    | `git log --oneline --graph --all`                            | 最常用的美观历史视图                                     |
|                    | `git log -p`                                                 | 显示每次提交的详细 diff                                  |
|                    | `git diff`                                                   | 查看工作区与暂存区的差异                                 |
|                    | `git diff --cached`                                          | 查看暂存区与最后一次提交的差异                           |
|                    | `git diff HEAD`                                              | 查看工作区与最后一次提交的所有差异                       |
|                    | `git reflog`                                                 | 神器！查看所有操作记录（找回“丢掉”的提交）               |
| **撤销与回滚**     | `git restore file.txt`                                       | 撤销工作区修改（Git 2.23+）                              |
|                    | `git restore --staged file.txt`                              | 撤销暂存（把文件从暂存区拿出来）                         |
|                    | `git reset HEAD~1`                                           | 回退到上一次提交（保留工作区改动）                       |
|                    | `git reset --hard HEAD~3`                                    | 彻底回退 3 次提交（危险！）                              |
|                    | `git revert HEAD`                                            | 生成一个新提交，撤销上一次提交的内容（安全，不会改历史） |
|                    | `git checkout HEAD -- file.txt`                              | 丢弃工作区修改（老写法，等价于 git restore）             |
| **储藏（Stash）**  | `git stash`                                                  | 临时保存当前改动（切换分支神器）                         |
|                    | `git stash list`                                             | 查看所有 stash                                           |
|                    | `git stash pop`                                              | 恢复最近的 stash 并删除                                  |
|                    | `git stash apply`                                            | 恢复但不删除                                             |
|                    | `git stash drop stash@{1}`                                   | 删除指定 stash                                           |
| **标签（Tag）**    | `git tag v1.0.0`                                             | 打轻量标签                                               |
|                    | `git tag -a v1.0.0 -m "Release 1.0"`                         | 打带注释的标签                                           |
|                    | `git push origin v1.0.0`                                     | 推送单个标签                                             |
|                    | `git push origin --tags`                                     | 推送所有标签                                             |
| **高级操作**       | `git cherry-pick a1b2c3d`                                    | 把某个提交移植到当前分支                                 |
|                    | `git rebase -i HEAD~5`                                       | 交互式变基：合并、修改、删除、重新排序最近 5 次提交      |
|                    | `git bisect start` → `git bisect bad` → `git bisect good v1.0` | 二分法快速定位引入 bug 的提交                            |
|                    | `git worktree add ../myproject-hotfix hotfix`                | 在另一个目录检出不同分支（多分支并行开发神器）           |

### 强烈推荐的别名（加到 ~/.gitconfig，效率翻倍）

```ini
[alias]
    st = status -sb
    co = checkout
    br = branch
    cm = commit -m
    ca = commit --amend
    df = diff
    dc = diff --cached
    lg = log --oneline --graph --all
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = !gitk
```

这样就可以用 `git st`、`git lg`、`git ca` 这些超短命令了。





# Git不同仓库间同步方法

使用 **Patch（补丁）** 的方式可在 Linux 内核开发或高度隔离（气隙隔离）的内网环境中同步代码。Patch 主要有两种方式：一种是**简单的差异补丁（git diff）**，另一种是**带提交信息的正式补丁（git format-patch）**。

场景：电脑A上创建了一个本地的git代码仓库，并进行版本管理。之后将电脑A上的完整的git代码仓库，拷贝到了电脑B上，在电脑B上也进行了git代码修改并将代码同步回电脑A。

------

### 方案一：使用 `git format-patch`（推荐：保留提交历史）

这种方式会将你的每一个 Commit 转换成一个 `.patch` 文件。它不仅包含代码修改，还包含**作者、日期、提交说明**。

#### 1. 在电脑 B 上：提交并生成补丁

由于你现在有未提交的修改，先提交它们：


```shell
git add .
git commit -m "B 电脑上的修改"

# 生成最近 1 次提交的补丁文件（会生成一个 0001-xxx.patch 文件）
git format-patch -1
```

如果你有多次提交，可以使用 git format-patch HEAD~3（生成最近 3 次的补丁）。

将生成的 .patch 文件拷贝到 USB。

#### 2. 在电脑 A 上：应用补丁

将 USB 里的补丁拷贝到 A 的项目根目录：

```bash
# 先检查补丁是否能顺利应用（无冲突）
git apply --check 0001-xxx.patch

# 正式应用并自动生成提交记录
git am 0001-xxx.patch
# 有时候可能遇到空白或者换行问题，添加选项：--ignore-space-change --ignore-whitespace
```

------

### 方案二：使用 `git diff`（快速：不保留提交历史）

如果你不想在 B 上创建正式的 Commit，只想把当前“乱糟糟”的修改挪到 A 上，可以使用这个方法。

#### 1. 在电脑 B 上：导出差异

```bash
# 将当前未提交的所有修改导出为一个文件
git diff > changes.patch
```

#### 2. 在电脑 A 上：导入差异

```bash
# 直接应用修改，修改会出现在 A 的“未暂存区”
git apply changes.patch
```

*注意：`git apply` 不会帮你创建 Commit，你需要手动在 A 上 `git add` 和 `git commit`。*

------

### 方案三：更好的替代方案 —— `git bundle`（离线包）

虽然你问的是 Patch，但在 Git 离线同步中，**`git bundle`（归档包）** 其实比 Patch 更强大。它将代码压缩成一个单一的二进制文件，电脑 A 可以像对待“远程仓库”一样直接从这个文件里 `pull` 代码。

#### 1. 在电脑 B 上生成离线包：

```bash
# 将 B 上的 main 分支打包（包含 A 没有的所有历史记录）
git bundle create my_code.bundle main
```

#### 2. 在电脑 A 上拉取：

```bash
# 验证离线包是否有效
git bundle verify /e/my_code.bundle

# 像拉取 GitHub 代码一样拉取这个文件
git pull /e/my_code.bundle main
```

------

### 三种方式的对比：

| **方式**             | **保留提交记录？** | **处理冲突能力** | **适用场景**                                       |
| -------------------- | ------------------ | ---------------- | -------------------------------------------------- |
| **git diff**         | 否                 | 弱               | 临时搬运几行代码，不想要 Commit 历史               |
| **git format-patch** | **是**             | 中               | 传统的邮件列表开发模式，适合单次或少量提交         |
| **git bundle**       | **是**             | **强**           | **离线同步的首选**，等同于把 USB 当成移动版 GitHub |





