# 译读

<p align="center">
  <img src="assets/yidu-icon.png" width="128" alt="译读图标">
</p>

译读是一款使用 AutoHotkey v2 编写的 Windows 划词翻译与在线朗读工具。选中文字后按下快捷键，即可进行中英互译或朗读；未选中文字时，会自动打开输入窗口。

<p align="center">
  <a href="https://github.com/zero-ljz/yidu/releases/latest/download/YiDu.exe">
    <img src="https://img.shields.io/badge/%E4%B8%8B%E8%BD%BD%E6%9C%80%E6%96%B0%E7%89%88-YiDu.exe-0078D4?style=for-the-badge&amp;logo=windows11&amp;logoColor=white" alt="下载最新版 YiDu.exe">
  </a>
</p>

## 功能

- 自动获取当前选中的文本，同时保留原剪贴板内容
- 根据文本内容自动选择中文或英文作为目标语言
- 在鼠标指针附近显示翻译结果
- 支持长文本分段翻译、失败重试和请求超时处理
- 支持结果复制、窗口置顶和翻译结果朗读
- 支持中文普通话、方言、粤语、台湾腔及英语音色
- 支持开机自启、管理员模式和托盘菜单设置

## 运行要求

- Windows 10 或 Windows 11
- [AutoHotkey v2](https://www.autohotkey.com/)
- 可访问在线翻译和语音服务的网络连接

本项目不需要申请 API Key。

## 快速开始

```powershell
git clone https://github.com/zero-ljz/yidu.git
cd yidu
```

安装 AutoHotkey v2 后，双击 `YiDu.ahk` 即可运行。请将 `YiDu.ico` 与脚本放在同一目录，以显示译读的托盘图标。

需要编译为独立可执行文件时，可以使用 AutoHotkey 自带的 Ahk2Exe，并选择 `YiDu.ico` 作为图标。

## 使用方法

| 操作 | 默认快捷键 | 说明 |
| --- | --- | --- |
| 翻译 | `Ctrl + F1` | 翻译选中的文本；没有选中文本时打开输入窗口 |
| 朗读 | `Ctrl + F2` | 朗读选中的文本；没有选中文本时打开输入窗口并选择音色 |

输入窗口中按 `Enter` 提交，按 `Shift + Enter` 插入换行。翻译结果窗口支持朗读、复制、置顶和拖动。

托盘菜单可以切换以下选项：

- 在鼠标指针处显示结果
- 开机自启
- 以管理员身份启动
- 关于译读，包括作者、开源仓库、官方网站和反馈邮箱

## 配置

首次运行时，脚本会在自身所在目录生成 `YiDu.ini`：

```ini
[Settings]
Hotkey=^F1
SpeakHotkey=^F2
SpeechVoice=zh-CN-XiaoyiNeural
RunAsAdmin=0
ShowResultAtMouse=1
```

| 配置项 | 说明 |
| --- | --- |
| `Hotkey` | 翻译快捷键 |
| `SpeakHotkey` | 朗读快捷键，不能与翻译快捷键相同 |
| `SpeechVoice` | Microsoft Edge 在线语音的音色标识 |
| `RunAsAdmin` | 是否以管理员身份启动，`1` 为开启 |
| `ShowResultAtMouse` | 是否在鼠标指针附近显示结果，`1` 为开启 |

快捷键使用 AutoHotkey 语法，例如 `^` 表示 `Ctrl`、`+` 表示 `Shift`、`!` 表示 `Alt`、`#` 表示 `Win`。

## 网络与隐私

译读使用腾讯翻译相关接口处理翻译请求，使用 Microsoft Edge 在线语音服务合成朗读音频。翻译或朗读时，对应文本会发送到第三方在线服务，请勿处理不适合上传的敏感内容。

这些在线接口可能随服务方调整而发生变化，稳定性和可用性不由本项目保证。

## 联系与反馈

- 软件作者：zero-ljz（空心）
- 开源仓库：[github.com/zero-ljz/yidu](https://github.com/zero-ljz/yidu)
- 官方网站：[yidu.iapp.run](https://yidu.iapp.run)
- 反馈邮箱：[hi@iapp.run](mailto:hi@iapp.run)

## 许可证

本项目使用 [MIT License](LICENSE)。
