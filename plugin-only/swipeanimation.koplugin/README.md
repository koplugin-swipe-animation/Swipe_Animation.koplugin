# Swipe Animation v4.3 — Plugin-only / Single-menu fork

> **非官方修改版 / Unofficial fork**  
> 上游动画项目及相关代码版权归原作者和贡献者所有。本分发包不代表上游作者发布或背书。

## 项目简介

本包基于上游 **Swipe_Animation.koplugin v4.3**，目标是在 KOReader 中通过普通 `.koplugin` 目录加载翻页擦除动画，避免安装时覆盖 `frontend/` 下的核心文件或把动画模块复制到 `patches/`。

本版本还将插件控制项与上游动画设置合并到一个入口：

**阅读时打开顶部菜单 → 设置（齿轮）→「翻页动画设置」**

菜单包含启用开关、上游动画参数及运行状态诊断。

## 功能

- 通过 `koreader/plugins/swipeanimation.koplugin/` 加载。
- 保留上游 v4.3 动画核心、设置项与 PDF 动画模块。
- 提供运行时桥接，不要求覆盖 `frontend/ui/uimanager.lua`。
- 将启用开关、原版参数与状态诊断合并到一个菜单。
- 附带完整插件源码、上游说明及 GPL-3.0 许可证文本。

## 安装教程（Kindle / Kobo Linux 设备）

1. **先备份整个 KOReader 目录**，至少备份配置和 `plugins/`。
2. 退出 KOReader。
3. 解压发布包。
4. 将里面的整个 `swipeanimation.koplugin` 文件夹复制到设备的 `koreader/plugins/` 目录。示例：

   ```text
   koreader/
   └── plugins/
       └── swipeanimation.koplugin/
           ├── main.lua
           ├── runtime_bridge.lua
           ├── upstream_core.lua
           ├── upstream_settings.lua
           └── upstream_pdf.lua
   ```

5. 如果以前安装过本项目的旧补丁或其他同类翻页动画实现，请先备份并移除重复版本，避免两个实现同时挂钩。
6. 安全弹出设备并重启 KOReader。
7. 打开一本书，进入 **设置（齿轮）→ 翻页动画设置**，启用动画并按需调整参数。
8. 先用一本不重要的书测试普通 EPUB 翻页，再测试 PDF。

**不要**把 `upstream_*.lua` 手动复制到 `koreader/patches/`，也不要把文件复制到 `frontend/`。本分发包的安装单位是整个 `.koplugin` 文件夹。

## 卸载与故障恢复

1. 退出 KOReader。
2. 删除 `koreader/plugins/swipeanimation.koplugin/` 整个文件夹。
3. 重启 KOReader，以清除运行时挂钩。
4. 如果仍有问题，请恢复安装前的备份。

如果设备中曾被手动替换过 `frontend/ui/uimanager.lua`，删除插件并不能还原该文件；请从你自己的备份恢复原文件。

## 兼容性与测试状态

- 目标设备：运行 KOReader 的 Linux 墨水屏设备；本修改版主要面向 Kindle Voyage。
- 上游 README 建议 KOReader **2026.07.1 或更新版本**。
- 这是使用运行时 Lua 挂钩的实验性移植，依赖 KOReader 内部接口；KOReader 更新后可能需要适配。
- 已检查分发包结构与 ZIP 完整性，并做过 Lua 语法/模拟逻辑检查。
- **未在所有 Kindle 型号、固件和 KOReader 版本上进行实机验证。** 单菜单版应视为实验版本；使用前请备份。
- 软件擦除动画由多段刷新组成，墨水屏的显示速度和分段感取决于设备、刷新模式和参数，不保证像 LCD/OLED 一样连续。

## 上游项目与署名

上游项目：  
https://github.com/koplugin-swipe-animation/Swipe_Animation.koplugin

上游 README 中列出的版本贡献者包括：

- 原作者：`xhs:5699990012`
- `nuku`（改进版）
- `Echoes`
- `小红薯6809667F`
- `斯普特尼克的漫游`

本包中的 `upstream_core.lua`、`upstream_settings.lua`、`upstream_pdf.lua` 来源于上游 v4.3 代码。请参阅 `UPSTREAM_README.md`、`UPSTREAM_README_en.md` 及 `LICENSE`。

## 本修改版的改动

- **插件化封装**：增加 KOReader 插件入口和元数据。
- **运行时桥接**：以插件加载时的运行时挂钩替代覆盖核心文件的安装方式。
- **菜单整合**：将插件开关、上游设置与诊断状态放到唯一的「翻页动画设置」入口。
- **文档与分发**：补充本分发包的安装、卸载、兼容性及许可说明。

本修改版的具体差异以包内完整源码为准。上游动画算法与上游设置/PDF 模块保留其原有版权及许可证声明。

## 许可证与再分发

本项目按上游采用的 **GNU General Public License v3.0 (GPL-3.0)** 分发，完整文本见 `LICENSE`。

本包包含对应源码。再分发或发布修改版时，请继续提供 GPL-3.0 许可证、保留适用的版权和许可证声明，并明确标注修改内容；不得将本包重新包装成限制接收者行使 GPL 权利的闭源版本。可收费再分发，但同样必须遵守 GPL-3.0。

本项目为非官方 fork，与上游项目无隶属关系；遇到问题时请在发布页面说明这是插件化移植版，避免把兼容性问题误报为上游原版问题。
