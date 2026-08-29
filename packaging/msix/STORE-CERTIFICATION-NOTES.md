# Microsoft Store 审核说明

## 包身份

运行 `build-msix.ps1 -Mode Store` 时，构建脚本会自动使用 Partner Center 为译读分配的正式身份。不要将开发身份 `YiDu.Desktop` 用于商店提交。

| 项目 | 值 |
| --- | --- |
| Package Identity Name | `zero-ljz.65035B1959F4` |
| Publisher | `CN=2393B316-80C9-466F-AA0D-A54F1924BC33` |
| Publisher Display Name | `zero-ljz` |
| Package Family Name | `zero-ljz.65035B1959F4_snc04fky3prkm` |
| Package SID | `S-1-15-2-3350770363-2201645723-1594348097-2279624397-2875228611-200618660-1072692571` |
| Store ID | `9MTM3STZL8L1` |
| Store URL | <https://apps.microsoft.com/detail/9MTM3STZL8L1> |
| Store protocol link | `ms-windows-store://pdp/?productid=9MTM3STZL8L1` |
| MSA 应用 ID | `2ba5067e-698f-470a-88dd-5fbb6c34f683` |

## `runFullTrust`

译读的主程序是基于 AutoHotkey v2 的 Win32 桌面应用，因此声明受限能力 `runFullTrust`。该能力用于：

- 注册用户配置的全局翻译与朗读快捷键；
- 通过 Win32 输入和剪贴板操作读取用户主动选中的文本，并恢复原剪贴板；
- 显示托盘菜单、输入窗口和翻译结果窗口；
- 读写用户目录中的应用配置与在线朗读临时文件；
- 调用用户选择的在线翻译和语音合成服务。

应用不会在 MSIX 环境中请求管理员权限，托盘菜单也不会显示管理员启动选项。

### Partner Center 受限能力说明（可直接粘贴）

译读是使用 AutoHotkey v2 编译的 Win32 桌面应用，MSIX 主程序以 `Windows.FullTrustApplication` 运行，因此需要 `runFullTrust`。该能力仅用于注册用户可配置的全局翻译与朗读快捷键、通过 Win32 输入和剪贴板操作读取用户主动选中的文本并恢复原剪贴板、显示托盘及应用窗口、读写 `%APPDATA%\YiDu` 配置与系统临时目录中的朗读文件，以及在用户明确同意并主动发起操作后访问所选在线翻译或语音服务。应用不请求管理员权限，不安装驱动或服务，不修改系统安全设置，不下载或执行远程代码。

## 开机启动任务

清单声明默认禁用的 `YiDuStartup`。只有用户在译读托盘菜单中主动开启“开机自启”后，`YiDuStartupTask.exe` 才会调用 Windows StartupTask API 请求启用。辅助程序在系统登录时仅启动主程序，不执行更新、下载或其他后台操作。

## 网络与隐私

译读首次运行时会显示“在线服务与隐私”窗口，明确说明在线翻译和在线朗读的数据接收方与用途。只有用户点击“同意并启用”后，应用才会启动在线语音工作进程，并在用户主动翻译或朗读时，将相应文本发送至用户选择的腾讯、有道或 Google 翻译服务，或 Microsoft 在线语音服务。

用户可以从托盘菜单打开“在线服务与隐私”，随时撤回或重新给予同意。撤回后，应用会中止正在进行的在线请求、停止语音工作进程，并阻止新的文本传输。应用不包含账户系统、广告、遥测或由开发者运营的数据收集服务器。

完整隐私政策：<https://yidu.iapp.run/privacy.html>

## 建议认证步骤

1. 安装使用 Partner Center 身份构建的测试包。
2. 验证默认不启用开机启动，且用户可从托盘菜单启用和禁用。
3. 首次启动时在“在线服务与隐私”窗口选择“暂不使用”，验证快捷键不会发送文本；随后从托盘菜单同意启用。
4. 验证 `Ctrl+F1` 翻译、`Ctrl+F2` 朗读及剪贴板恢复。
5. 从托盘菜单撤回在线服务同意，验证新的翻译和朗读操作会再次显示授权窗口。
6. 验证配置写入 `%APPDATA%\YiDu\YiDu.ini`，安装目录保持只读。
7. 验证应用界面不提供管理员模式入口。
