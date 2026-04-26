# PaperEdit

<p align="center">
  <img src="Assets/AppIcon.svg" alt="PaperEdit icon" width="96" height="96">
</p>

PaperEdit 是一个使用 SwiftUI 构建的 macOS 轻量文本编辑器，面向 Markdown、JSON、YAML、TOML、XML、Property List 和纯文本文件的快速编辑场景。项目使用 Swift Package Manager 管理，可直接通过 `swift run` 启动，也提供脚本生成 `.app` 和 zip 发布包。

## 功能概览

- 多标签文件编辑，支持新建、打开、保存和另存为。
- Markdown 编辑、分屏预览和组合预览模式。
- JSON、YAML、TOML、XML、plist 与纯文本格式识别。
- 工作区侧边栏按 Favorites、Recent、Explorer 组织文件入口。
- Quick Open 支持在当前工作区和最近文件中快速定位文件。
- Favorites 手动收藏常用文件，并独立于最近文件持久化。
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

## 命令行打开

发布脚本会同时生成 `dist/paper` 命令行入口。把它放到 PATH 后，可以直接打开文件或目录：

```bash
paper x.json
paper ~/Documents/notes
```

文件会作为标签页打开，目录会作为工作区显示在侧边栏。`paper` 会优先打开同目录下的 `PaperEdit.app`，也可以通过 `PAPEREDIT_APP_PATH=/path/to/PaperEdit.app paper x.json` 指定应用位置。

## 测试

运行全部测试：

```bash
swift test
```

当前测试覆盖了演示场景切换、侧边栏宽度限制、外部文件打开、重复文件复用、Favorites 持久化、Quick Open 结果排序与异常文件处理、保存脏文件以及 JSON 折叠状态切换等核心状态逻辑。

## 打包发布

项目提供发布脚本，用于构建 release 可执行文件、生成 macOS `.app` 包、签名并压缩为 zip：

```bash
./scripts/build_release_app.sh 0.1.5
```

生成结果位于 `dist/`：

- `dist/PaperEdit.app`
- `dist/paper`
- `dist/PaperEdit-0.1.5-macOS.zip`

发布脚本依赖 `Assets/AppIcon.png` 生成 `.icns` 图标文件。

自动更新基于 Sparkle。发布正式构建前先生成 Sparkle EdDSA 密钥，将私钥保存在发布机钥匙串或 CI secret 中，构建时写入公开验签 key：

```bash
SPARKLE_PUBLIC_ED_KEY="your-public-ed-key" \
APPCAST_URL="https://github.com/kaelinda/PaperEdit/releases/latest/download/appcast.xml" \
./scripts/build_release_app.sh 0.1.5
```

每次发布 zip 后，用 Sparkle 的 `generate_appcast` 为 `dist/` 生成 appcast，并把 `appcast.xml` 与 zip 一起上传到 GitHub Release。应用启动后会按 Sparkle 策略自动检查更新，也可以通过 `PaperEdit > Check for Updates...` 手动检查。

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
| `Command + P` | Quick Open |
| `Command + Shift + P` | 打开命令面板 |
| `Command + Option + 0` | 切换侧边栏 |
| `Command + Option + T` | 切换主题 |
| `Command + ,` | 打开设置 |

## 版本更新

### v0.1.5

- 设置面板的主题、强调色、材质和字号改为真实可操作并持久化的偏好设置，补上恢复默认入口。
- Quick Open、命令面板、标题栏和侧边栏增强了选中态、可访问标签、长文本截断与对比度表现，收紧轻量编辑场景下的交互细节。
- 官网移动端布局补齐导航与应用预览适配，编辑器输入热路径和首屏图标加载链路同步优化，减少整篇重高亮和无意义重绘。

### v0.1.4

- 新增 Sparkle 自动更新能力，应用启动后会按更新策略检查版本，并在 `PaperEdit > Check for Updates...` 支持手动检查。
- Quick Open 支持按文件名、文件夹名和部分路径组合搜索，工作区文件会显示更短的相对路径。
- 标题栏操作区调整为更清晰的 Open、Find、Save 控件，常用文件入口更贴近轻量编辑场景。

### v0.1.3

- 编辑器支持 `Command +` / `Command -` 调整字号，并持久化记住偏好设置。
- JSON、YAML、TOML、XML、plist 与 shell 脚本编辑区补充语法高亮，结构化格式在编辑态也会直接显示校验结果。
- 优化编辑器与预览面板视觉层级，改进当前行强调、卡片式面板、Markdown 分块预览和代码行号对齐。
- 结构化预览树与左侧侧边栏补充更顺滑的展开/折叠反馈，预览节点支持整行点击展开收起。
- 标题栏新增明暗模式切换按钮，侧边栏字体、行高和图标尺寸同步优化，提高可读性。

### v0.1.2

- 重新梳理侧边栏文件入口，以 Favorites、Recent、Explorer 区分常用文件、最近文件和工作区浏览。
- 新增文件专用的 Quick Open，可从侧边栏、标题栏放大镜或 `Command + P` 快速打开文件。
- Favorites 支持手动收藏和持久化，重新打开应用后仍保留常用文件入口。
- Quick Open 优先搜索当前工作区，再补充最近文件；重复打开同一文件时会聚焦已有标签页。
- 改进删除、不可读文件等异常场景处理，避免静默失败或打开占位标签页。

## 开发说明

PaperEdit 当前是 Swift Package 形式的 macOS 应用。新增功能时优先保持状态逻辑在 `WorkspaceStore` 中集中管理，视图层通过 `EnvironmentObject` 读取和触发操作。涉及用户流程的修改建议同步补充 `Tests/PaperEditAppTests` 中的状态测试。
