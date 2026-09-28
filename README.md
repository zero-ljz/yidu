# 译读

<p align="center">
  <img src="assets/yidu-icon.png" width="128" alt="译读图标">
</p>

译读是一款使用 AutoHotkey v2 编写的 Windows 划词翻译与在线朗读工具。选中文字后按下快捷键，即可进行中英互译或朗读；未选中文字时，会自动打开输入窗口。

> [!IMPORTANT]
> **EXE 版本未进行数字签名，可能被 Windows Defender 或其他杀毒软件误报。推荐通过 [Microsoft Store](https://apps.microsoft.com/detail/9MTM3STZL8L1) 下载和安装。**

<p align="center">
  <a href="https://apps.microsoft.com/detail/9MTM3STZL8L1">
    <img src="https://get.microsoft.com/images/zh-cn%20dark.svg" alt="在 Microsoft Store 中获取">
  </a>
</p>

## 功能

- 自动获取当前选中的文本，同时保留原剪贴板内容
- 根据文本内容自动选择中文或英文作为目标语言
- 支持腾讯、有道和谷歌免费翻译接口，并记住上次选择
- 在鼠标指针附近显示翻译结果
- 支持长文本分段翻译、失败重试和请求超时处理
- 支持结果复制、窗口置顶和翻译结果朗读
- 长文本朗读优先按句末或换行分段，首段最多 200 字、后续最多 500 字；首段完成即播放，并提前合成下一段
- 支持中文普通话、方言、粤语、台湾腔及英语音色
- 支持 0.75×、1×、1.25×、1.5× 和 2× 朗读速度，并记住上次选择
- 支持开机自启、管理员模式和托盘菜单设置
- 支持跟随系统、深色、浅色界面以及可选的窗口半透明效果

## 运行要求

- Windows 10 或 Windows 11
- [AutoHotkey v2](https://www.autohotkey.com/)
- 可访问在线翻译和语音服务的网络连接

本项目不需要申请 API Key。

## 安装

前往 [Microsoft Store](https://apps.microsoft.com/detail/9MTM3STZL8L1) 获取译读。Microsoft Store 会负责安装并自动提供后续更新。

## 从源码运行

```powershell
git clone https://github.com/zero-ljz/yidu.git
cd yidu
```

安装 AutoHotkey v2 后，双击 `YiDu.ahk` 即可运行。请将 `YiDu.ico` 与脚本放在同一目录，以显示译读的托盘图标。

需要编译为独立可执行文件时，可以使用 AutoHotkey 自带的 Ahk2Exe，并选择 `YiDu.ico` 作为图标。

## 构建 MSIX

构建 x64 MSIX 需要安装 AutoHotkey v2（含 Ahk2Exe）和 Windows SDK（含 MakeAppx、SignTool 与 Windows Runtime 元数据）。运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\packaging\msix\build-msix.ps1
```

脚本会从 `YiDu.ahk` 的 Ahk2Exe 指令读取版本，编译主程序和开机启动任务组件，并在 `release` 目录生成经过开发证书签名的 `.msix` 与对应 `.cer`。首次旁加载可运行：

```powershell
.\packaging\msix\install-development-msix.ps1 `
  -PackagePath .\release\YiDu-1.2.0-MSIX-x64.msix
```

安装脚本会请求管理员权限，将开发证书导入本机信任区并安装包。正式提交 Microsoft Store 时，脚本会自动使用 Partner Center 分配给译读的包标识和发布者，并生成不带开发签名的商店包：

```powershell
.\packaging\msix\build-msix.ps1 -Mode Store
```

商店包清单使用 `zero-ljz.65035B1959F4`、`CN=2393B316-80C9-466F-AA0D-A54F1924BC33` 和发布者显示名称 `zero-ljz`。产品的 Microsoft Store ID 为 `9MTM3STZL8L1`。

MSIX 清单声明 `runFullTrust`，用于全局快捷键、选区读取、剪贴板、托盘程序和本地配置。MSIX 版本不提供管理员模式，并通过 Windows StartupTask 管理开机自启。

提交前可参考 [Microsoft Store 审核说明](packaging/msix/STORE-CERTIFICATION-NOTES.md) 核对受限能力、启动任务和隐私披露。

## 朗读测试

安装 AutoHotkey v2 后，可运行离线检查，验证托盘菜单、默认设置、联动音色选择、输入窗口布局、草稿恢复、翻译取消、分段、连续播放队列、暂停与继续、超时与停止清理：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-speech-tests.ps1
```

添加 `-Online` 可验证真实语音合成和 Windows 播放接口；该检查仅提交固定测试文本，并静音播放。

## 使用方法

| 操作 | 默认快捷键 | 说明 |
| --- | --- | --- |
| 翻译 | `Ctrl + F1` | 翻译选中的文本；没有选中文本时打开输入窗口并选择翻译服务 |
| 朗读 | `Ctrl + F2` | 朗读选中的文本；没有选中文本时打开输入窗口并选择音色 |

输入窗口中按 `Enter` 提交，按 `Shift + Enter` 插入换行。翻译结果窗口支持朗读、复制、置顶和拖动。

朗读输入窗口使用“分类 + 音色”两个联动下拉框，打开时自动定位到上次使用的音色及分类。

音色右侧的倍速按钮依次循环切换 0.75×、1×、1.25×、1.5× 和 2×，与托盘“朗读速度”菜单同步。默认 1×，修改后对下一次朗读生效。

输入窗口失焦关闭时会保留已编辑的草稿和光标位置，重新打开同类窗口可继续输入。翻译与朗读草稿分别保留在本次运行的内存中；翻译草稿在提交或主动取消后清除。翻译过程中关闭结果窗口会取消当前请求。

朗读输入窗口点击“朗读”后保持打开，文本仍可编辑。播放期间主按钮切换为“暂停／继续”，右侧按钮为“停止”；结束或停止后恢复“朗读”，保留文本供再次朗读。关闭或失焦只收起窗口并保留文本，后台朗读继续，重新打开后与托盘同步当前播放状态。修改文本、音色和语速对下一次朗读生效。

托盘的“暂停朗读／继续朗读”和翻译结果窗口的“暂停／继续”按钮同步控制当前朗读。暂停会保留播放位置，正在合成的分段可以完成，但不会自动播放；继续后从暂停处接着读。“停止朗读”会结束当前朗读并清理音频。

托盘菜单可以切换以下选项：

- 翻译服务
- 暂停朗读／继续朗读（合成或播放期间可用）
- 停止朗读（合成或播放期间可用）
- 朗读音色（按普通话、方言、粤语、台湾和英语分组）
- 朗读速度
- 在鼠标指针处显示结果
- 外观（主题：跟随系统、深色或浅色；窗口半透明）
- 开机自启
- 以管理员身份启动（MSIX 版本不提供）
- 打开数据目录
- 关于译读，包括作者、开源仓库、官方网站和反馈邮箱

首次使用会显示在线服务选择窗口；完成选择后，后续启动保持静默。

## 配置

首次运行时，源码版和绿色版会在自身所在目录生成 `YiDu.ini`；MSIX 版本则保存在 `%APPDATA%\YiDu\YiDu.ini`：

```ini
[Settings]
Hotkey=^F1
SpeakHotkey=^F2
SpeechVoice=zh-CN-XiaoyiNeural
SpeechSpeed=1
TranslationService=tencent
RunAsAdmin=0
ShowResultAtMouse=1
ColorTheme=system
WindowTransparency=0
PrivacyChoiceMade=0
OnlineServicesConsent=0
```

| 配置项 | 说明 |
| --- | --- |
| `Hotkey` | 翻译快捷键 |
| `SpeakHotkey` | 朗读快捷键，不能与翻译快捷键相同 |
| `SpeechVoice` | Microsoft Edge 在线语音的音色标识 |
| `SpeechSpeed` | 朗读倍速，可选 `0.75`、`1`、`1.25`、`1.5`、`2`，默认 `1` |
| `TranslationService` | 翻译服务，可选 `tencent`、`youdao` 或 `google` |
| `RunAsAdmin` | 是否以管理员身份启动，`1` 为开启 |
| `ShowResultAtMouse` | 是否在鼠标指针附近显示结果，`1` 为开启 |
| `ColorTheme` | 窗口主题，可选 `system`、`dark` 或 `light`，默认跟随系统 |
| `WindowTransparency` | 是否启用窗口半透明效果，`1` 为开启，新用户默认关闭，已有设置保留 |
| `PrivacyChoiceMade` | 是否已完成首次在线服务选择，`1` 表示已选择 |
| `OnlineServicesConsent` | 是否允许向所选第三方发送待翻译或朗读文本，`1` 为允许 |

快捷键使用 AutoHotkey 语法，例如 `^` 表示 `Ctrl`、`+` 表示 `Shift`、`!` 表示 `Alt`、`#` 表示 `Win`。

## 网络与隐私

译读可使用腾讯、有道或谷歌的免费翻译接口处理翻译请求，并使用 Microsoft Edge 在线语音服务合成朗读音频。翻译或朗读时，对应文本会发送到所选第三方在线服务，请勿处理不适合上传的敏感内容。

首次运行时，译读会在发送任何文本前征求在线服务授权。你可以从托盘菜单的“在线服务与隐私”随时撤回或重新给予同意。

这些在线接口可能随服务方调整而发生变化，稳定性和可用性不由本项目保证。

## 联系与反馈

- 软件作者：zero-ljz（空心）
- 开源仓库：[github.com/zero-ljz/yidu](https://github.com/zero-ljz/yidu)
- 官方网站：[yidu.iapp.run](https://yidu.iapp.run)
- 反馈邮箱：[hi@iapp.run](mailto:hi@iapp.run)

## 许可证

本项目使用 [MIT License](LICENSE)。
