# Microsoft Store 审核说明

## 包身份

正式提交前，使用 Partner Center 为译读分配的 Package Identity Name、Publisher 和 Publisher Display Name 调用 `build-msix.ps1 -Mode Store`。不要将开发身份 `YiDu.Desktop` 用于商店提交。

## `runFullTrust`

译读的主程序是基于 AutoHotkey v2 的 Win32 桌面应用，因此声明受限能力 `runFullTrust`。该能力用于：

- 注册用户配置的全局翻译与朗读快捷键；
- 通过 Win32 输入和剪贴板操作读取用户主动选中的文本，并恢复原剪贴板；
- 显示托盘菜单、输入窗口和翻译结果窗口；
- 读写用户目录中的应用配置与在线朗读临时文件；
- 调用用户选择的在线翻译和语音合成服务。

应用不会在 MSIX 环境中请求管理员权限，托盘菜单也不会显示管理员启动选项。

## 开机启动任务

清单声明默认禁用的 `YiDuStartup`。只有用户在译读托盘菜单中主动开启“开机自启”后，`YiDuStartupTask.exe` 才会调用 Windows StartupTask API 请求启用。辅助程序在系统登录时仅启动主程序，不执行更新、下载或其他后台操作。

## 网络与隐私

译读仅在用户主动翻译或朗读时，将相应文本发送至用户选择的腾讯、有道或 Google 翻译服务，或 Microsoft 在线语音服务。应用不包含账户系统、广告、遥测或由开发者运营的数据收集服务器。

完整隐私政策：<https://yidu.iapp.run/privacy.html>

## 建议认证步骤

1. 安装使用 Partner Center 身份构建的测试包。
2. 验证默认不启用开机启动，且用户可从托盘菜单启用和禁用。
3. 验证 `Ctrl+F1` 翻译、`Ctrl+F2` 朗读及剪贴板恢复。
4. 验证配置写入 `%APPDATA%\YiDu\YiDu.ini`，安装目录保持只读。
5. 验证应用界面不提供管理员模式入口。
