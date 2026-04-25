const switches = document.querySelectorAll("[data-preview]");
const sourcePreview = document.querySelector(".source-preview");
const renderedPreview = document.querySelector(".rendered-preview");
const languageToggle = document.querySelector("[data-language-toggle]");

const translations = {
  zh: {
    title: "PaperEdit - 轻量原生 Mac 编辑器",
    description: "PaperEdit 是一款轻量原生 macOS 编辑器，适合快速编辑 Markdown、JSON、YAML、TOML、XML、plist 和纯文本文件。",
    toggle: "EN",
    toggleLabel: "Switch to English",
    "nav.workflow": "工作流",
    "nav.formats": "格式",
    "nav.download": "下载",
    "hero.eyebrow": "PaperEdit for macOS. SwiftUI 构建。",
    "hero.title": "安静、原生，专为快速文件编辑而生。",
    "hero.copy": "打开配置文件、Markdown 笔记或项目目录。安心完成修改，然后回到真正的工作里。",
    "hero.download": "下载 macOS 版",
    "hero.source": "查看源码",
    "hero.requirement": "需要 macOS 14 或更高版本",
    "preview.source": "源码",
    "preview.preview": "预览",
    "app.favorites": "收藏",
    "app.recent": "最近",
    "app.explorer": "浏览器",
    "app.open": "打开",
    "app.find": "查找",
    "app.save": "保存",
    "app.sourceCode": `<span class="hash">#</span> PaperEdit

一款面向结构化文本的轻量原生 macOS 编辑器。

<span class="hash">##</span> 专注编辑

- Markdown 源码与预览
- JSON、YAML、TOML、XML、plist
- 收藏、最近、浏览器、快速打开
`,
    "app.renderedCopy": "一款面向结构化文本的轻量原生 macOS 编辑器。",
    "app.renderedHeading": "专注编辑",
    "app.renderedItem1": "Markdown 源码与预览",
    "app.renderedItem2": "JSON、YAML、TOML、XML、plist",
    "app.renderedItem3": "收藏、最近、浏览器、快速打开",
    "workflow.label": "工作流",
    "workflow.title": "更快打开准确的文件。",
    "workflow.copy": "PaperEdit 保持入口简单：收藏文件、最近工作、工作区浏览器，以及只面向文件的 Quick Open。",
    "workflow.item1": "Command-P 快速打开文件",
    "workflow.item2": "文件以标签页打开，目录以工作区打开",
    "workflow.item3": "收藏文件与最近文件独立管理",
    "workflow.search": "搜索文件",
    "formats.label": "格式",
    "formats.title": "小编辑器，也支持多种文件。",
    "formats.copy": "Markdown 支持源码与预览。结构化格式会在编辑区获得识别、语法着色和轻量校验。",
    "formats.item1": "Markdown、JSON、YAML、TOML、XML、plist",
    "formats.item2": "纯文本与 shell 友好的编辑体验",
    "formats.item3": "浅色、深色主题与原生 macOS 窗口质感",
    "native.label": "原生细节",
    "native.title": "看起来就该属于 Mac。",
    "native.copy": "界面保持克制：统一标题栏、熟悉的侧边栏、清晰的编辑器字体，以及刚好够用的日常编辑控件。",
    "native.item1": "在合适的位置使用 SwiftUI 与 AppKit",
    "native.item2": "命令面板和设置窗口",
    "native.item3Prefix": "命令行打开：",
    "command.title": "命令面板",
    "command.theme": "切换主题",
    "command.folder": "打开文件夹",
    "command.save": "保存文件",
    "command.settings": "显示设置",
    "download.title": "轻量，是设计目标。",
    "download.copy": "PaperEdit 是开源项目，在继续打磨为专注开发者快速文件编辑的原生编辑器期间，可免费使用。",
    "download.primary": "下载最新版本",
    "download.secondary": "GitHub 仓库",
    "footer.copy": "面向专注文件工作的原生 macOS 编辑器。"
  },
  en: {
    title: "PaperEdit - Lightweight native editor for Mac",
    description: "PaperEdit is a lightweight native macOS editor for Markdown, JSON, YAML, TOML, XML, plist, and plain text files.",
    toggle: "中文",
    toggleLabel: "切换到中文",
    "nav.workflow": "Workflow",
    "nav.formats": "Formats",
    "nav.download": "Download",
    "hero.eyebrow": "PaperEdit for macOS. Built with SwiftUI.",
    "hero.title": "A quiet, native editor for quick file edits.",
    "hero.copy": "Open a config file, Markdown note, or project folder. Make the change with confidence, then get back to work.",
    "hero.download": "Download for macOS",
    "hero.source": "View source",
    "hero.requirement": "macOS 14 or later",
    "preview.source": "Source",
    "preview.preview": "Preview",
    "app.favorites": "Favorites",
    "app.recent": "Recent",
    "app.explorer": "Explorer",
    "app.open": "Open",
    "app.find": "Find",
    "app.save": "Save",
    "app.sourceCode": `<span class="hash">#</span> PaperEdit

A lightweight native macOS editor for structured text.

<span class="hash">##</span> Focused editing

- Markdown source and preview
- JSON, YAML, TOML, XML, plist
- Favorites, Recent, Explorer, Quick Open
`,
    "app.renderedCopy": "A lightweight native macOS editor for structured text.",
    "app.renderedHeading": "Focused editing",
    "app.renderedItem1": "Markdown source and preview",
    "app.renderedItem2": "JSON, YAML, TOML, XML, plist",
    "app.renderedItem3": "Favorites, Recent, Explorer, Quick Open",
    "workflow.label": "Workflow",
    "workflow.title": "Open the exact file, fast.",
    "workflow.copy": "PaperEdit keeps the entry points simple: favorite files, recent work, a workspace explorer, and a file-only Quick Open.",
    "workflow.item1": "Quick Open with Command-P",
    "workflow.item2": "Files open as tabs, folders open as workspaces",
    "workflow.item3": "Favorites stay separate from recent files",
    "workflow.search": "Search files",
    "formats.label": "Formats",
    "formats.title": "Small editor, broad file support.",
    "formats.copy": "Markdown gets source and preview. Structured formats get recognition, syntax coloring, and lightweight validation in the editor surface.",
    "formats.item1": "Markdown, JSON, YAML, TOML, XML, plist",
    "formats.item2": "Plain text and shell-friendly editing",
    "formats.item3": "Light and dark themes with native macOS chrome",
    "native.label": "Native details",
    "native.title": "Designed to feel like it belongs on the Mac.",
    "native.copy": "The interface stays restrained: a unified titlebar, familiar sidebar, crisp editor typography, and just enough controls for everyday edits.",
    "native.item1": "SwiftUI and AppKit where they fit best",
    "native.item2": "Command palette and settings window",
    "native.item3Prefix": "Command line opener: ",
    "command.title": "Command Palette",
    "command.theme": "Toggle Theme",
    "command.folder": "Open Folder",
    "command.save": "Save File",
    "command.settings": "Show Settings",
    "download.title": "Lightweight by design.",
    "download.copy": "PaperEdit is open source and free to use while it grows into a focused native editor for quick developer file edits.",
    "download.primary": "Download latest release",
    "download.secondary": "GitHub repository",
    "footer.copy": "Native macOS editor for focused file work."
  }
};

function setLanguage(language) {
  const copy = translations[language];
  document.documentElement.lang = language === "zh" ? "zh-CN" : "en";
  document.title = copy.title;
  document.querySelector('meta[name="description"]')?.setAttribute("content", copy.description);

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const key = element.dataset.i18n;
    if (copy[key]) {
      element.textContent = copy[key];
    }
  });

  document.querySelectorAll("[data-i18n-html]").forEach((element) => {
    const key = element.dataset.i18nHtml;
    if (copy[key]) {
      element.innerHTML = copy[key];
    }
  });

  languageToggle.textContent = copy.toggle;
  languageToggle.setAttribute("aria-label", copy.toggleLabel);
  languageToggle.dataset.currentLanguage = language;
}

switches.forEach((button) => {
  button.addEventListener("click", () => {
    const showSource = button.dataset.preview === "source";

    switches.forEach((item) => {
      const selected = item === button;
      item.classList.toggle("active", selected);
      item.setAttribute("aria-selected", String(selected));
    });

    sourcePreview.hidden = !showSource;
    renderedPreview.hidden = showSource;
  });
});

languageToggle.addEventListener("click", () => {
  const nextLanguage = languageToggle.dataset.currentLanguage === "zh" ? "en" : "zh";
  setLanguage(nextLanguage);
});

setLanguage("zh");
