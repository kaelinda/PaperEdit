# PaperEdit

<p align="center">
  <img src="Assets/AppIcon.png" alt="PaperEdit icon" width="96" height="96">
</p>

PaperEdit 是一个使用 SwiftUI 构建的 macOS 文本编辑器原型，面向 Markdown、JSON、YAML、TOML、XML、Property List 和纯文本文件的轻量编辑场景。项目使用 Swift Package Manager 管理，可直接通过 `swift run` 启动，也提供脚本生成 `.app` 和 zip 发布包。

## 功能概览

- 多标签文件编辑，支持新建、打开、保存和另存为。
- Markdown 编辑、分屏预览和组合预览模式。
- JSON、YAML、TOML、XML、plist 与纯文本格式识别。
- 工作区侧边栏、最近文件、打开标签和文件树浏览。
- 命令面板、应用设置、主题切换和侧边栏折叠。
- 拖拽文件打开、最近文件持久化和基础状态栏信息。

## 环境要求

- macOS 14 或更高版本。
- Swift 6.3 或兼容版本。
- Xcode Command Line Tools。

检查 Swift 环境：

```bash
swift --version
```

## 快速开始

在项目根目录执行：

```bash
swift run PaperEditApp
```

如果只想先确认项目可以构建：

```bash
swift build
```

## 测试

运行全部测试：

```bash
swift test
```

当前测试覆盖了演示场景切换、侧边栏宽度限制、外部文件打开、重复文件复用、保存脏文件以及 JSON 折叠状态切换等核心状态逻辑。

## 打包发布

项目提供发布脚本，用于构建 release 可执行文件、生成 macOS `.app` 包、签名并压缩为 zip：

```bash
./scripts/build_release_app.sh 0.1.0
```

生成结果位于 `dist/`：

- `dist/PaperEdit.app`
- `dist/PaperEdit-0.1.0-macOS.zip`

发布脚本依赖 `Assets/AppIcon.png` 生成 `.icns` 图标文件。

## 项目结构

```text
.
├── Package.swift
├── Assets/
│   ├── AppIcon.png
│   └── AppIcon.svg
├── Sources/
│   └── PaperEditApp/
│       ├── App/
│       ├── Models/
│       ├── Store/
│       ├── Theme/
│       └── Views/
├── Tests/
│   └── PaperEditAppTests/
└── scripts/
    └── build_release_app.sh
```

主要模块：

- `App/`：应用入口、AppDelegate 和菜单命令。
- `Models/`：编辑器文件格式、视图模式、命令项、标签页和状态模型。
- `Store/`：`WorkspaceStore`，集中管理工作区状态、文件打开保存、命令执行和持久化。
- `Theme/`：PaperEdit 的主题颜色与视觉样式。
- `Views/`：工作区、侧边栏、编辑器、Markdown 预览、命令面板和设置界面。

## 常用快捷键

| 快捷键 | 功能 |
| --- | --- |
| `Command + N` | 新建文件 |
| `Command + O` | 打开文件 |
| `Command + S` | 保存 |
| `Command + Shift + S` | 另存为 |
| `Command + Shift + P` | 打开命令面板 |
| `Command + Option + 0` | 切换侧边栏 |
| `Command + Option + T` | 切换主题 |
| `Command + ,` | 打开设置 |

## 开发说明

PaperEdit 当前是 Swift Package 形式的 macOS 应用。新增功能时优先保持状态逻辑在 `WorkspaceStore` 中集中管理，视图层通过 `EnvironmentObject` 读取和触发操作。涉及用户流程的修改建议同步补充 `Tests/PaperEditAppTests` 中的状态测试。
