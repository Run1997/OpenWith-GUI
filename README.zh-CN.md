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

## 运行要求

- macOS 14 及以上
- 使用打包好的 `.app` 或 `.dmg` 时，不需要安装 Swift 或 Xcode

## 从 DMG 安装

下载或打开 DMG 后，将 `OpenWithGUI.app` 拖入 `Applications` 即可。

如果 macOS 因“未认证开发者”拦截应用，请手动放行：

1. 先把 `OpenWithGUI.app` 拖到 `Applications`
2. 在 Finder 中右键 `OpenWithGUI.app`
3. 点击“打开”
4. 在二次确认弹窗中再次点击“打开”

如果系统在“系统设置 -> 隐私与安全性”中出现安全提示，也可以在那里手动允许。

## 这个项目要解决什么问题

macOS 上默认应用管理一直很别扭：

- 一次通常只能改一个扩展名。
- 系统没有统一的总览面板。
- 很难快速看出某个扩展名当前到底由哪个 app 接管。
- 某些应用会注册过多关联，留下混乱状态。

OpenWithGUI 的目标，就是把这些关联关系直接可视化，并提供更直接的修改方式，不需要反复点 Finder，也不需要记复杂的 bundle ID。

## License

本项目使用 [MIT License](LICENSE)。

## 同类项目推荐

- [ColeMei/openwith](https://github.com/ColeMei/openwith) - 一个基于 Rust 的 TUI 项目，可以在终端里管理 macOS 文件扩展名关联。

## 鸣谢

- [linux.do](https://linux.do/)
