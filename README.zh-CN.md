# OpenWithGUI

OpenWithGUI 是一个 macOS 桌面应用，用来集中查看和修改“文件扩展名 -> 默认打开应用”的关联关系。

相比 Finder 里繁琐的 `显示简介 -> 打开方式 -> 全部更改...` 操作，OpenWithGUI 更像一个表格管理器：把系统当前状态一次性展示出来，并支持批量修改。

[English README](README.md)

## 界面截图

![OpenWithGUI 界面截图](docs/assets/openwithgui-screenshot.png)

## 主要功能

- 用一张表集中展示扩展名和默认应用的映射关系。
- 显示每个扩展名当前的默认应用、Bundle ID 和状态。
- 支持按默认应用筛选，快速查看某个 app 绑定了哪些扩展名。
- 支持按状态筛选。
- 搜索框仅搜索扩展名，结果更稳定清晰。
- 支持多选后统一改成同一个应用。
- 修改单个扩展名时，会展示 Candidate Apps 供选择。
- 支持手动添加扩展名，也支持删除用户自己添加的扩展名。

## 当前范围

第一版目前只处理：

- `文件扩展名 -> 默认应用`

暂不处理 UTI / Uniform Type、文件夹、URL scheme 等其他关联类型。

## 运行要求

- macOS 14 及以上
- Swift 6 工具链，或支持 Swift 6 的较新版本 Xcode

## 构建与启动

打包 `.app`：

```bash
./scripts/package-macos-app.sh
```

打包 release 版本：

```bash
./scripts/package-macos-app.sh --release
```

打包后立即打开：

```bash
./scripts/package-macos-app.sh --open
```

生成后的应用位置：

```text
dist/OpenWithGUI.app
```

## 项目结构

```text
Sources/OpenWithGUIApp    SwiftUI 应用、模型、服务、视图模型、界面
Tests/OpenWithGUIAppTests 单元测试
scripts/                  打包脚本
docs/assets/              README 图片资源
```

## 这个项目要解决什么问题

macOS 上默认应用管理一直很别扭：

- 一次通常只能改一个扩展名。
- 系统没有统一的总览面板。
- 很难快速看出某个扩展名当前到底由哪个 app 接管。
- 某些应用会注册过多关联，留下混乱状态。

OpenWithGUI 的目标，就是把这些关联关系直接可视化，并提供更直接的修改方式，不需要反复点 Finder，也不需要记复杂的 bundle ID。

## 鸣谢

- linux.do
