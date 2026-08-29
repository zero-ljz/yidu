#Requires AutoHotkey v2.0
#SingleInstance Off
;@Ahk2Exe-SetName 译读
;@Ahk2Exe-SetCompanyName zero-ljz（空心）
;@Ahk2Exe-SetDescription 译读
;@Ahk2Exe-SetCopyright Copyright (c) 2026 zero-ljz
;@Ahk2Exe-SetVersion 1.1.0.0

SendMode "Input"
CoordMode "Mouse", "Screen"

global APP_VERSION := "1.1.0"
global CONFIG := {
    Hotkey: "^F1",
    SpeakHotkey: "^F2",
    SpeechVoice: "zh-CN-XiaoyiNeural",
    TranslationService: "tencent",
    RunAsAdmin: false,
    ShowResultAtMouse: true,
    PrivacyChoiceMade: false,
    OnlineServicesConsent: false,
    RequestTimeoutMs: 10000,
    RequestPollIntervalMs: 50,
    SelectionTimeoutSeconds: 0.5,
    ApiUrl: "https://wxapp.translator.qq.com/api/translate",
    Referer: "https://servicewechat.com/wxb1070eabc6f9107e/117/page-frame.html",
    UserAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 16_3_1 like Mac OS X) "
        . "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 "
        . "MicroMessenger/8.0.32(0x18002035) NetType/WIFI Language/zh_TW"
}

global SPEECH_VOICES := [
    {Label: "云希 Yunxi · 自然男声", Voice: "zh-CN-YunxiNeural"},
    {Label: "晓晓 Xiaoxiao · 自然女声", Voice: "zh-CN-XiaoxiaoNeural"},
    {Label: "晓臻 HsiaoChen · 台湾女声", Voice: "zh-TW-HsiaoChenNeural"},
    {Label: "云哲 YunJhe · 台湾男声", Voice: "zh-TW-YunJheNeural"},
    {Label: "晓北 Xiaobei · 东北话", Voice: "zh-CN-liaoning-XiaobeiNeural"},
    {Label: "晓佳 HiuGaai · 粤语", Voice: "zh-HK-HiuGaaiNeural"},
    {Label: "云健 Yunjian · 新闻播报", Voice: "zh-CN-YunjianNeural"},
    {Label: "云扬 Yunyang · 短视频旁白", Voice: "zh-CN-YunyangNeural"},
    {Label: "晓伊 Xiaoyi · 萝莉音", Voice: "zh-CN-XiaoyiNeural"},
    {Label: "晓妮 Xiaoni · 陕西话（俏皮）", Voice: "zh-CN-shaanxi-XiaoniNeural"},
    {Label: "晓曼 HiuMaan · 港式女声", Voice: "zh-HK-HiuMaanNeural"},
    {Label: "万龙 WanLung · 港式男声", Voice: "zh-HK-WanLungNeural"},
    {Label: "晓雨 HsiaoYu · 台味女声", Voice: "zh-TW-HsiaoYuNeural"},
    {Label: "Jenny · 英语女声", Voice: "en-US-JennyNeural"},
    {Label: "Guy · 英语男声", Voice: "en-US-GuyNeural"}
]

global TRANSLATION_SERVICES := [
    {Label: "腾讯翻译", Service: "tencent"},
    {Label: "有道翻译", Service: "youdao"},
    {Label: "谷歌翻译", Service: "google"}
]

global IS_PACKAGED := IsPackagedApplication()
global CONFIG_DIRECTORY := IS_PACKAGED ? A_AppData . "\YiDu" : A_ScriptDir
global CONFIG_PATH := CONFIG_DIRECTORY . "\YiDu.ini"
global AUTOSTART_SHORTCUT := A_Startup . "\YiDu.lnk"
global PACKAGED_STARTUP_HELPER := A_ScriptDir . "\tools\YiDuStartupTask.exe"

global TranslationBusy := false
global ResultGui := 0
global ResultEdit := 0
global ResultPinButton := 0
global ResultSpeakButton := 0
global ResultCopyButton := 0
global ResultCloseButton := 0
global ResultPinned := false
global ShowResultAtMouse := true
global ResultManualPosition := 0
global AboutGui := 0
global PrivacyGui := 0
global ActiveInputDialog := 0
global ActiveTranslationRequest := 0
global TranslationServiceTrayMenu := 0
global SpeechVoiceTrayMenu := 0
global SpeechAudioPath := ""
global SpeechErrorPath := ""
global SpeechDonePath := ""
global SpeechBusy := false
global SpeechStartedAt := 0
global SpeechTimeoutMs := 60000
global SpeechSynthesisPending := false
global SpeechMciAlias := ""
global SpeechWorkerProcessId := 0
global SpeechWorkerScriptPath := ""
global SpeechWorkerRequestPath := ""
global SpeechWorkerReadyPath := ""

LoadConfig()
SetApplicationIcon()
EnsureConfiguredElevation()
ReplacePreviousInstance()
RegisterTranslationHotkey()
RegisterSpeakHotkey()
OnMessage(0x0100, HandleInputKeyDown)
OnMessage(0x0201, HandleWindowBackgroundDrag)
OnMessage(0x0006, HandleWindowActivation)
OnExit(CleanupSpeech)
SetupTrayMenu()
if CONFIG.OnlineServicesConsent
    SetTimer(EnsureSpeechWorker, -1)

if CONFIG.PrivacyChoiceMade
    ShowStartupNotification()
else
    SetTimer(OpenOnlineServicesPrivacyDialog.Bind(true), -1)


SetApplicationIcon()
{
    iconPath := A_ScriptDir . "\YiDu.ico"

    if FileExist(iconPath)
        try TraySetIcon(iconPath)
}


LoadConfig()
{
    global CONFIG, CONFIG_PATH, IS_PACKAGED, ShowResultAtMouse

    EnsureConfigDirectory()

    if !FileExist(CONFIG_PATH)
        CreateDefaultConfig()

    CONFIG.Hotkey := Trim(IniRead(CONFIG_PATH, "Settings", "Hotkey", CONFIG.Hotkey))
    CONFIG.SpeakHotkey := Trim(IniRead(
        CONFIG_PATH,
        "Settings",
        "SpeakHotkey",
        CONFIG.SpeakHotkey
    ))
    CONFIG.SpeechVoice := Trim(IniRead(
        CONFIG_PATH,
        "Settings",
        "SpeechVoice",
        CONFIG.SpeechVoice
    ))

    if GetSpeechVoiceIndex(CONFIG.SpeechVoice) = 0
        CONFIG.SpeechVoice := "zh-CN-XiaoyiNeural"

    CONFIG.TranslationService := Trim(IniRead(
        CONFIG_PATH,
        "Settings",
        "TranslationService",
        CONFIG.TranslationService
    ))

    if GetTranslationServiceIndex(CONFIG.TranslationService) = 0
        CONFIG.TranslationService := "tencent"

    CONFIG.RunAsAdmin := IS_PACKAGED
        ? false
        : ReadBooleanSetting("RunAsAdmin", CONFIG.RunAsAdmin)
    CONFIG.ShowResultAtMouse := ReadBooleanSetting(
        "ShowResultAtMouse",
        CONFIG.ShowResultAtMouse
    )
    CONFIG.PrivacyChoiceMade := ReadBooleanSetting(
        "PrivacyChoiceMade",
        CONFIG.PrivacyChoiceMade
    )
    CONFIG.OnlineServicesConsent := ReadBooleanSetting(
        "OnlineServicesConsent",
        CONFIG.OnlineServicesConsent
    )
    ShowResultAtMouse := CONFIG.ShowResultAtMouse
}


CreateDefaultConfig()
{
    global CONFIG, CONFIG_PATH

    EnsureConfigDirectory()

    IniWrite(CONFIG.Hotkey, CONFIG_PATH, "Settings", "Hotkey")
    IniWrite(CONFIG.SpeakHotkey, CONFIG_PATH, "Settings", "SpeakHotkey")
    IniWrite(CONFIG.SpeechVoice, CONFIG_PATH, "Settings", "SpeechVoice")
    IniWrite(
        CONFIG.TranslationService,
        CONFIG_PATH,
        "Settings",
        "TranslationService"
    )
    IniWrite(CONFIG.RunAsAdmin ? 1 : 0, CONFIG_PATH, "Settings", "RunAsAdmin")
    IniWrite(
        CONFIG.ShowResultAtMouse ? 1 : 0,
        CONFIG_PATH,
        "Settings",
        "ShowResultAtMouse"
    )
    IniWrite(
        CONFIG.PrivacyChoiceMade ? 1 : 0,
        CONFIG_PATH,
        "Settings",
        "PrivacyChoiceMade"
    )
    IniWrite(
        CONFIG.OnlineServicesConsent ? 1 : 0,
        CONFIG_PATH,
        "Settings",
        "OnlineServicesConsent"
    )
}


EnsureConfigDirectory()
{
    global CONFIG_DIRECTORY

    if !DirExist(CONFIG_DIRECTORY)
        DirCreate(CONFIG_DIRECTORY)
}


GetSpeechVoiceIndex(voice)
{
    global SPEECH_VOICES

    for index, item in SPEECH_VOICES
    {
        if item.Voice = voice
            return index
    }

    return 0
}


GetTranslationServiceIndex(service)
{
    global TRANSLATION_SERVICES

    for index, item in TRANSLATION_SERVICES
    {
        if item.Service = service
            return index
    }

    return 0
}


ReadBooleanSetting(name, defaultValue)
{
    global CONFIG_PATH

    value := Trim(IniRead(
        CONFIG_PATH,
        "Settings",
        name,
        defaultValue ? "1" : "0"
    ))

    return value = "1"
        || StrLower(value) = "true"
        || StrLower(value) = "yes"
        || StrLower(value) = "on"
}


WriteConfigSetting(name, value)
{
    global CONFIG_PATH

    EnsureConfigDirectory()
    IniWrite(value, CONFIG_PATH, "Settings", name)
}


EnsureConfiguredElevation()
{
    global CONFIG, IS_PACKAGED

    if IS_PACKAGED || !CONFIG.RunAsAdmin || A_IsAdmin
        return

    try
    {
        Run(GetLaunchCommand(true), A_ScriptDir)
        ExitApp()
    }
    catch Error as err
    {
        MsgBox(
            "无法以管理员身份启动：`n" . err.Message,
            "译读",
            "Icon!"
        )
        ExitApp()
    }
}


IsPackagedApplication()
{
    packageNameLength := 0
    result := DllCall(
        "kernel32\GetCurrentPackageFullName",
        "UInt*", &packageNameLength,
        "Ptr", 0,
        "UInt"
    )
    return result = 122
}


ReplacePreviousInstance()
{
    currentProcessId := DllCall("GetCurrentProcessId", "UInt")
    previousDetectHiddenWindows := A_DetectHiddenWindows
    previousProcessIds := []

    DetectHiddenWindows(true)

    try
    {
        for hwnd in WinGetList("ahk_class AutoHotkey")
        {
            try processId := WinGetPID("ahk_id " . hwnd)
            catch
                continue

            if processId = currentProcessId
                continue

            if !IsSameApplicationInstance(hwnd, processId)
                continue

            if !HasValue(previousProcessIds, processId)
                previousProcessIds.Push(processId)
        }

        for processId in previousProcessIds
        {
            try WinClose("ahk_pid " . processId . " ahk_class AutoHotkey")

            try
            {
                if ProcessWaitClose(processId, 3)
                    continue
            }

            try ProcessClose(processId)
            try ProcessWaitClose(processId, 2)
        }
    }
    finally
        DetectHiddenWindows(previousDetectHiddenWindows)
}


IsSameApplicationInstance(hwnd, processId)
{
    if A_IsCompiled
    {
        try processPath := ProcessGetPath(processId)
        catch
            return false

        return StrLower(processPath) = StrLower(A_ScriptFullPath)
    }

    try windowTitle := WinGetTitle("ahk_id " . hwnd)
    catch
        return false

    expectedTitlePrefix := A_ScriptFullPath . " - AutoHotkey"
    return InStr(windowTitle, expectedTitlePrefix, false) = 1
}


HasValue(values, expectedValue)
{
    for value in values
    {
        if value = expectedValue
            return true
    }

    return false
}


RegisterTranslationHotkey()
{
    global CONFIG

    try Hotkey(CONFIG.Hotkey, TranslateFromHotkey)
    catch Error
    {
        invalidHotkey := CONFIG.Hotkey
        CONFIG.Hotkey := "^F1"
        WriteConfigSetting("Hotkey", CONFIG.Hotkey)
        Hotkey(CONFIG.Hotkey, TranslateFromHotkey)
        MsgBox(
            "配置文件中的翻译快捷键无效：" . invalidHotkey
                . "`n已恢复为 " . FormatHotkey(CONFIG.Hotkey) . "。",
            "译读",
            "Icon!"
        )
    }
}


RegisterSpeakHotkey()
{
    global CONFIG

    try
    {
        if StrLower(CONFIG.SpeakHotkey) = StrLower(CONFIG.Hotkey)
            throw Error("朗读快捷键不能与翻译快捷键相同。")

        Hotkey(CONFIG.SpeakHotkey, SpeakFromHotkey)
    }
    catch Error
    {
        invalidHotkey := CONFIG.SpeakHotkey
        CONFIG.SpeakHotkey := StrLower(CONFIG.Hotkey) = "^f2"
            ? "^+F2"
            : "^F2"
        WriteConfigSetting("SpeakHotkey", CONFIG.SpeakHotkey)
        Hotkey(CONFIG.SpeakHotkey, SpeakFromHotkey)
        MsgBox(
            "配置文件中的朗读快捷键无效：" . invalidHotkey
                . "`n已恢复为 " . FormatHotkey(CONFIG.SpeakHotkey) . "。",
            "译读",
            "Icon!"
        )
    }
}


SetupTrayMenu()
{
    global CONFIG, IS_PACKAGED, ShowResultAtMouse
    global TRANSLATION_SERVICES, SPEECH_VOICES
    global TranslationServiceTrayMenu, SpeechVoiceTrayMenu

    A_TrayMenu.Delete()
    translateHotkeyText := FormatHotkey(CONFIG.Hotkey)
    speakHotkeyText := FormatHotkey(CONFIG.SpeakHotkey)
    translateMenuText := "翻译`t" . translateHotkeyText
    speakMenuText := "朗读`t" . speakHotkeyText
    A_TrayMenu.Add(translateMenuText, TranslateFromHotkey)
    A_TrayMenu.Add(speakMenuText, SpeakFromHotkey)

    TranslationServiceTrayMenu := Menu()

    for item in TRANSLATION_SERVICES
    {
        TranslationServiceTrayMenu.Add(
            item.Label,
            SetTranslationService.Bind(item.Service)
        )
    }

    UpdateTranslationServiceTrayChecks()
    A_TrayMenu.Add("翻译服务", TranslationServiceTrayMenu)

    SpeechVoiceTrayMenu := Menu()

    for item in SPEECH_VOICES
        SpeechVoiceTrayMenu.Add(item.Label, SetSpeechVoice.Bind(item.Voice))

    UpdateSpeechVoiceTrayChecks()
    A_TrayMenu.Add("语音角色", SpeechVoiceTrayMenu)
    A_TrayMenu.Add("在鼠标指针处显示结果", ToggleResultAtMouse)

    if ShowResultAtMouse
        A_TrayMenu.Check("在鼠标指针处显示结果")

    A_TrayMenu.Add()
    A_TrayMenu.Add("开机自启", ToggleAutostart)

    if !IS_PACKAGED
        A_TrayMenu.Add("以管理员身份启动", ToggleRunAsAdmin)

    if IsAutostartEnabled()
        A_TrayMenu.Check("开机自启")

    if !IS_PACKAGED && CONFIG.RunAsAdmin
        A_TrayMenu.Check("以管理员身份启动")

    A_TrayMenu.Add()
    A_TrayMenu.Add("在线服务与隐私", ShowOnlineServicesPrivacyDialog)
    A_TrayMenu.Add("关于译读", ShowAboutDialog)
    A_TrayMenu.Add()
    A_TrayMenu.Add("退出", (*) => ExitApp())
    A_TrayMenu.Default := translateMenuText
    A_TrayMenu.ClickCount := 1
    A_IconTip := SubStr(
        "译读 (翻译 " . translateHotkeyText
            . "，朗读 " . speakHotkeyText . ")",
        1,
        127
    )
}


ShowAboutDialog(*)
{
    global APP_VERSION, AboutGui

    if IsObject(AboutGui)
    {
        try
        {
            WinActivate("ahk_id " . AboutGui.Hwnd)
            return
        }

        AboutGui := 0
    }

    aboutWindow := Gui("-MinimizeBox -MaximizeBox", "关于译读")
    aboutWindow.MarginX := 18
    aboutWindow.MarginY := 16
    aboutWindow.BackColor := "171A1F"

    aboutWindow.SetFont("s16 w600 cF1F3F5", "Microsoft YaHei UI")
    aboutWindow.AddText("xm ym", "译读")
    aboutWindow.SetFont("s9 cA7ADB7", "Microsoft YaHei UI")
    aboutWindow.AddText(
        "xm y+4 w394",
        "Windows 划词翻译与在线朗读工具"
    )

    aboutWindow.SetFont("s10 cF1F3F5", "Microsoft YaHei UI")
    aboutWindow.AddText("xm y+18 w76", "软件版本")
    aboutWindow.AddText("x+8 yp w300", APP_VERSION)
    aboutWindow.AddText("xm y+12 w76", "软件作者")
    aboutWindow.AddText("x+8 yp w300", "zero-ljz（空心）")
    aboutWindow.AddText("xm y+12 w76", "开源仓库")
    repositoryLink := aboutWindow.AddLink(
        "x+8 yp w300",
        "<a href=`"https://github.com/zero-ljz/yidu`">"
            . "github.com/zero-ljz/yidu</a>"
    )
    aboutWindow.AddText("xm y+12 w76", "官方网站")
    websiteLink := aboutWindow.AddLink(
        "x+8 yp w300",
        "<a href=`"https://yidu.iapp.run`">yidu.iapp.run</a>"
    )
    aboutWindow.AddText("xm y+12 w76", "隐私政策")
    privacyLink := aboutWindow.AddLink(
        "x+8 yp w300",
        "<a href=`"https://yidu.iapp.run/privacy.html`">"
            . "查看隐私政策</a>"
    )
    aboutWindow.AddText("xm y+12 w76", "反馈邮箱")
    emailLink := aboutWindow.AddLink(
        "x+8 yp w300",
        "<a href=`"mailto:hi@iapp.run`">hi@iapp.run</a>"
    )

    closeButton := aboutWindow.AddButton("x334 y+20 w78 h28 Default", "关闭")
    closeButton.OnEvent("Click", CloseAboutDialog.Bind(aboutWindow))
    aboutWindow.OnEvent("Close", CloseAboutDialog)
    aboutWindow.OnEvent("Escape", CloseAboutDialog)
    ApplyDarkTheme(
        aboutWindow,
        repositoryLink,
        websiteLink,
        privacyLink,
        emailLink,
        closeButton
    )

    AboutGui := aboutWindow
    aboutWindow.Show("w430 h308")
    RedrawGuiWindow(aboutWindow)
}


CloseAboutDialog(aboutWindow, *)
{
    global AboutGui

    AboutGui := 0
    try aboutWindow.Destroy()
}


ShowOnlineServicesPrivacyDialog(*)
{
    OpenOnlineServicesPrivacyDialog(false)
}


OpenOnlineServicesPrivacyDialog(firstRun := false)
{
    global CONFIG, PrivacyGui

    if IsObject(PrivacyGui)
    {
        try
        {
            WinActivate("ahk_id " . PrivacyGui.Hwnd)
            return
        }

        PrivacyGui := 0
    }

    windowTitle := firstRun ? "开始使用译读" : "在线服务与隐私"
    privacyWindow := Gui("-MinimizeBox -MaximizeBox", windowTitle)
    privacyWindow.MarginX := 20
    privacyWindow.MarginY := 18
    privacyWindow.BackColor := "171A1F"

    privacyWindow.SetFont("s16 w600 cF1F3F5", "Microsoft YaHei UI")
    privacyWindow.AddText(
        "xm ym",
        firstRun ? "开始使用译读" : "在线服务与隐私"
    )
    privacyWindow.SetFont("s10 cF1F3F5", "Microsoft YaHei UI")
    privacyWindow.AddText(
        "xm y+16 w500",
        "选择文字后按 " . FormatHotkey(CONFIG.Hotkey) . " 翻译，按 "
            . FormatHotkey(CONFIG.SpeakHotkey)
            . " 朗读；没有选中文字时会打开输入窗口。"
    )
    privacyWindow.AddText(
        "xm y+12 w500",
        "译读只会在你主动按下翻译或朗读快捷键后处理选中的文本。"
    )
    privacyWindow.AddText(
        "xm y+12 w500",
        "在线翻译会将待翻译文本发送给你选择的腾讯、有道或 Google；"
            . "在线朗读会将待朗读文本和音色发送给 Microsoft 在线语音服务。"
    )
    privacyWindow.AddText(
        "xm y+12 w500",
        "文本可能包含个人或敏感信息。译读不保存翻译历史，"
            . "你可以随时从托盘菜单撤回同意。"
    )
    privacyWindow.SetFont("s9 cA7ADB7", "Microsoft YaHei UI")
    privacyLink := privacyWindow.AddLink(
        "xm y+12 w500",
        "<a href=`"https://yidu.iapp.run/privacy.html`">查看完整隐私政策</a>"
    )
    statusText := CONFIG.OnlineServicesConsent
        ? "当前状态：在线翻译和在线朗读已启用"
        : "当前状态：在线翻译和在线朗读未启用"
    privacyWindow.AddText("xm y+16 w500", statusText)

    privacyWindow.SetFont("s10 cF1F3F5", "Microsoft YaHei UI")
    if CONFIG.OnlineServicesConsent
    {
        primaryButton := privacyWindow.AddButton(
            "xm y+20 w100 h30",
            "撤回同意"
        )
        primaryButton.OnEvent(
            "Click",
            SetOnlineServicesConsent.Bind(false, privacyWindow)
        )
        closeButton := privacyWindow.AddButton("x+10 yp w78 h30 Default", "关闭")
        closeButton.OnEvent(
            "Click",
            CloseOnlineServicesPrivacyDialog.Bind(privacyWindow)
        )
        privacyWindow.OnEvent(
            "Close",
            CloseOnlineServicesPrivacyDialog.Bind(privacyWindow)
        )
        privacyWindow.OnEvent(
            "Escape",
            CloseOnlineServicesPrivacyDialog.Bind(privacyWindow)
        )
    }
    else
    {
        primaryButton := privacyWindow.AddButton(
            "xm y+20 w120 h30 Default",
            "同意并启用"
        )
        primaryButton.OnEvent(
            "Click",
            SetOnlineServicesConsent.Bind(true, privacyWindow)
        )
        closeButton := privacyWindow.AddButton("x+10 yp w100 h30", "暂不使用")
        closeButton.OnEvent(
            "Click",
            SetOnlineServicesConsent.Bind(false, privacyWindow)
        )
        privacyWindow.OnEvent(
            "Close",
            SetOnlineServicesConsent.Bind(false, privacyWindow)
        )
        privacyWindow.OnEvent(
            "Escape",
            SetOnlineServicesConsent.Bind(false, privacyWindow)
        )
    }

    ApplyDarkTheme(privacyWindow, privacyLink, primaryButton, closeButton)
    PrivacyGui := privacyWindow
    privacyWindow.Show("w540 h382")
    RedrawGuiWindow(privacyWindow)
}


SetOnlineServicesConsent(enabled, privacyWindow, *)
{
    global CONFIG

    CONFIG.PrivacyChoiceMade := true
    CONFIG.OnlineServicesConsent := enabled
    WriteConfigSetting("PrivacyChoiceMade", 1)
    WriteConfigSetting("OnlineServicesConsent", enabled ? 1 : 0)

    if enabled
        SetTimer(EnsureSpeechWorker, -1)
    else
        CancelActiveOnlineOperations()

    CloseOnlineServicesPrivacyDialog(privacyWindow)
    TrayTip(
        enabled
            ? "在线翻译和在线朗读已启用。"
            : "在线翻译和在线朗读已关闭。",
        "译读",
        1
    )
}


CloseOnlineServicesPrivacyDialog(privacyWindow, *)
{
    global PrivacyGui

    PrivacyGui := 0
    try privacyWindow.Destroy()
}


EnsureOnlineServicesConsent()
{
    global CONFIG

    if CONFIG.OnlineServicesConsent
        return true

    OpenOnlineServicesPrivacyDialog(false)
    TrayTip("请先决定是否启用在线服务。", "译读", 1)
    return false
}


CancelActiveOnlineOperations()
{
    global ActiveTranslationRequest, TranslationBusy

    SetTimer(CheckTranslationRequest, 0)

    if IsObject(ActiveTranslationRequest)
        try ActiveTranslationRequest.Http.Abort()

    ActiveTranslationRequest := 0
    TranslationBusy := false
    StopSpeech()
    StopSpeechWorker()
}


ShowStartupNotification()
{
    global CONFIG

    TrayTip(
        CONFIG.OnlineServicesConsent
            ? "已启动：" . FormatHotkey(CONFIG.Hotkey) . " 翻译，"
                . FormatHotkey(CONFIG.SpeakHotkey) . " 朗读。"
            : "已启动，在线功能当前未启用。可从托盘菜单启用。",
        "译读",
        1
    )
}


FormatHotkey(hotkey)
{
    hotkey := Trim(hotkey)

    if hotkey = ""
        return ""

    keyUpPosition := RegExMatch(hotkey, "i)\s+up$")
    isKeyUp := keyUpPosition > 0

    if isKeyUp
        hotkey := RTrim(SubStr(hotkey, 1, keyUpPosition - 1))

    if RegExMatch(hotkey, "^(.*?)\s+&\s+(.*?)$", &combination)
    {
        displayText := FormatHotkeyChord(combination[1])
            . " + " . FormatHotkeyChord(combination[2])
    }
    else
        displayText := FormatHotkeyChord(hotkey)

    return displayText . (isKeyUp ? "（松开时）" : "")
}


FormatHotkeyChord(chord)
{
    chord := Trim(chord)
    modifiers := []
    position := 1
    chordLength := StrLen(chord)
    lastModifierSymbol := ""
    lastModifierSide := ""

    while position <= chordLength
    {
        symbol := SubStr(chord, position, 1)

        if symbol = "*" || symbol = "~" || symbol = "$"
        {
            position += 1
            continue
        }

        side := ""

        if (symbol = "<" || symbol = ">")
            && IsHotkeyModifierSymbol(SubStr(chord, position + 1, 1))
        {
            side := symbol
            symbol := SubStr(chord, position + 1, 1)
            position += 2
        }
        else if IsHotkeyModifierSymbol(symbol)
            position += 1
        else
            break

        lastModifierSymbol := symbol
        lastModifierSide := side
        modifiers.Push(FormatHotkeyModifier(symbol, side))
    }

    key := Trim(SubStr(chord, position))

    if key = ""
    {
        if modifiers.Length = 0
            return chord

        modifiers.Pop()
        keyText := lastModifierSide = ""
            ? lastModifierSymbol
            : FormatHotkeyModifier(lastModifierSymbol, lastModifierSide)
    }
    else
        keyText := FormatHotkeyKey(key)

    displayText := ""

    for modifier in modifiers
        displayText .= (displayText = "" ? "" : " + ") . modifier

    return displayText . (displayText = "" ? "" : " + ") . keyText
}


IsHotkeyModifierSymbol(symbol)
{
    return symbol = "#" || symbol = "!" || symbol = "^" || symbol = "+"
}


FormatHotkeyModifier(symbol, side := "")
{
    switch symbol
    {
        case "#": name := "Win"
        case "!": name := "Alt"
        case "^": name := "Ctrl"
        case "+": name := "Shift"
        default: return symbol
    }

    if side = "<"
        return "左 " . name

    if side = ">"
        return "右 " . name

    return name
}


FormatHotkeyKey(key)
{
    static names := Map(
        "esc", "Esc",
        "escape", "Esc",
        "space", "空格",
        "tab", "Tab",
        "enter", "Enter",
        "return", "Enter",
        "backspace", "Backspace",
        "bs", "Backspace",
        "delete", "Delete",
        "del", "Delete",
        "insert", "Insert",
        "ins", "Insert",
        "home", "Home",
        "end", "End",
        "pgup", "Page Up",
        "pgdn", "Page Down",
        "up", "↑",
        "down", "↓",
        "left", "←",
        "right", "→",
        "capslock", "Caps Lock",
        "scrolllock", "Scroll Lock",
        "numlock", "Num Lock",
        "printscreen", "Print Screen",
        "pause", "Pause",
        "break", "Break",
        "ctrlbreak", "Ctrl + Break",
        "appskey", "菜单键",
        "help", "Help",
        "sleep", "Sleep",
        "ctrl", "Ctrl",
        "control", "Ctrl",
        "lctrl", "左 Ctrl",
        "lcontrol", "左 Ctrl",
        "rctrl", "右 Ctrl",
        "rcontrol", "右 Ctrl",
        "shift", "Shift",
        "lshift", "左 Shift",
        "rshift", "右 Shift",
        "alt", "Alt",
        "lalt", "左 Alt",
        "ralt", "右 Alt",
        "altgr", "AltGr",
        "lwin", "左 Win",
        "rwin", "右 Win",
        "numpaddot", "小键盘 .",
        "numpaddiv", "小键盘 /",
        "numpadmult", "小键盘 *",
        "numpadadd", "小键盘 +",
        "numpadsub", "小键盘 -",
        "numpadenter", "小键盘 Enter",
        "numpadins", "小键盘 Insert",
        "numpadend", "小键盘 End",
        "numpaddown", "小键盘 ↓",
        "numpadpgdn", "小键盘 Page Down",
        "numpadleft", "小键盘 ←",
        "numpadclear", "小键盘 Clear",
        "numpadright", "小键盘 →",
        "numpadhome", "小键盘 Home",
        "numpadup", "小键盘 ↑",
        "numpadpgup", "小键盘 Page Up",
        "numpaddel", "小键盘 Delete",
        "lbutton", "鼠标左键",
        "rbutton", "鼠标右键",
        "mbutton", "鼠标中键",
        "xbutton1", "鼠标侧键 1",
        "xbutton2", "鼠标侧键 2",
        "wheelup", "滚轮向上",
        "wheeldown", "滚轮向下",
        "wheelleft", "滚轮向左",
        "wheelright", "滚轮向右",
        "browser_back", "浏览器后退",
        "browser_forward", "浏览器前进",
        "browser_refresh", "浏览器刷新",
        "browser_stop", "浏览器停止",
        "browser_search", "浏览器搜索",
        "browser_favorites", "浏览器收藏夹",
        "browser_home", "浏览器主页",
        "volume_mute", "静音",
        "volume_down", "降低音量",
        "volume_up", "提高音量",
        "media_next", "下一曲",
        "media_prev", "上一曲",
        "media_stop", "停止播放",
        "media_play_pause", "播放/暂停",
        "launch_mail", "启动邮件",
        "launch_media", "启动媒体播放器",
        "launch_app1", "启动应用 1",
        "launch_app2", "启动应用 2"
    )

    resolvedKey := key

    try
    {
        canonicalName := GetKeyName(key)

        if canonicalName != ""
            resolvedKey := canonicalName
    }

    lowerKey := StrLower(resolvedKey)

    if names.Has(lowerKey)
        return names[lowerKey]

    if RegExMatch(lowerKey, "^numpad([0-9])$", &numpadMatch)
        return "小键盘 " . numpadMatch[1]

    if RegExMatch(lowerKey, "^([0-9]*)joy([0-9]+)$", &joystickMatch)
    {
        joystickNumber := joystickMatch[1]
        buttonNumber := joystickMatch[2]
        return (joystickNumber = "" ? "手柄" : "手柄 " . joystickNumber)
            . " 按钮 " . buttonNumber
    }

    if RegExMatch(lowerKey, "^f([1-9]|1[0-9]|2[0-4])$")
        return StrUpper(resolvedKey)

    if RegExMatch(
        lowerKey,
        "^(vk[0-9a-f]{2}|sc[0-9a-f]{3}|vk[0-9a-f]{2}sc[0-9a-f]{3})$"
    )
        return StrUpper(resolvedKey)

    if StrLen(resolvedKey) = 1
        return StrUpper(resolvedKey)

    return resolvedKey
}


ToggleAutostart(*)
{
    global AUTOSTART_SHORTCUT, IS_PACKAGED

    try
    {
        if IsAutostartEnabled()
        {
            if IS_PACKAGED
                SetPackagedAutostart(false)
            else
                FileDelete(AUTOSTART_SHORTCUT)

            A_TrayMenu.Uncheck("开机自启")
        }
        else
        {
            if IS_PACKAGED
                SetPackagedAutostart(true)
            else
                CreateAutostartShortcut()

            A_TrayMenu.Check("开机自启")
        }
    }
    catch Error as err
    {
        MsgBox("修改开机自启失败：`n" . err.Message, "译读", "Icon!")
    }
}


IsAutostartEnabled()
{
    global AUTOSTART_SHORTCUT, IS_PACKAGED, PACKAGED_STARTUP_HELPER

    if IS_PACKAGED
    {
        if !FileExist(PACKAGED_STARTUP_HELPER)
            return false

        try return RunWait(
            QuoteCommandArgument(PACKAGED_STARTUP_HELPER) . " --status",
            A_ScriptDir,
            "Hide"
        ) = 0
        catch
            return false
    }

    return FileExist(AUTOSTART_SHORTCUT) != ""
}


SetPackagedAutostart(enable)
{
    global PACKAGED_STARTUP_HELPER

    if !A_IsCompiled || !FileExist(PACKAGED_STARTUP_HELPER)
        throw Error("MSIX 开机启动组件不可用。")

    action := enable ? "--enable" : "--disable"
    exitCode := RunWait(
        QuoteCommandArgument(PACKAGED_STARTUP_HELPER) . " " . action,
        A_ScriptDir,
        "Hide"
    )

    if enable && exitCode = 0
        return

    if !enable && (exitCode = 10 || exitCode = 11 || exitCode = 12)
        return

    if exitCode = 11
        throw Error("启动任务已在 Windows 启动应用设置中禁用。")

    if exitCode = 12
        throw Error("启动任务已被系统策略禁用。")

    throw Error("无法修改 MSIX 开机启动任务，错误代码 " . exitCode . "。")
}


CreateAutostartShortcut()
{
    global AUTOSTART_SHORTCUT

    shortcut := ComObject("WScript.Shell").CreateShortcut(AUTOSTART_SHORTCUT)

    if A_IsCompiled
    {
        shortcut.TargetPath := A_ScriptFullPath
        shortcut.Arguments := ""
    }
    else
    {
        shortcut.TargetPath := A_AhkPath
        shortcut.Arguments := QuoteCommandArgument(A_ScriptFullPath)
    }

    shortcut.WorkingDirectory := A_ScriptDir
    shortcut.Description := "译读"
    shortcut.IconLocation := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
    shortcut.Save()
}


ToggleRunAsAdmin(*)
{
    global CONFIG

    newValue := !CONFIG.RunAsAdmin

    try WriteConfigSetting("RunAsAdmin", newValue ? 1 : 0)
    catch Error as err
    {
        MsgBox("保存管理员启动设置失败：`n" . err.Message, "译读", "Icon!")
        return
    }

    CONFIG.RunAsAdmin := newValue

    if !CONFIG.RunAsAdmin
    {
        A_TrayMenu.Uncheck("以管理员身份启动")
        return
    }

    A_TrayMenu.Check("以管理员身份启动")

    if A_IsAdmin
        return

    try
    {
        Run(GetLaunchCommand(true), A_ScriptDir)
        ExitApp()
    }
    catch Error as err
    {
        CONFIG.RunAsAdmin := false
        try WriteConfigSetting("RunAsAdmin", 0)
        A_TrayMenu.Uncheck("以管理员身份启动")
        MsgBox(
            "未能以管理员身份重新启动，已撤销该设置：`n" . err.Message,
            "译读",
            "Icon!"
        )
    }
}


GetLaunchCommand(runAsAdmin := false)
{
    prefix := runAsAdmin ? "*RunAs " : ""

    if A_IsCompiled
        return prefix . QuoteCommandArgument(A_ScriptFullPath)
            . (runAsAdmin ? " /restart" : "")

    return prefix . QuoteCommandArgument(A_AhkPath)
        . (runAsAdmin ? " /restart " : " ")
        . QuoteCommandArgument(A_ScriptFullPath)
}


QuoteCommandArgument(value)
{
    return Chr(34) . StrReplace(value, Chr(34), Chr(92) . Chr(34)) . Chr(34)
}


ToggleResultAtMouse(*)
{
    global CONFIG, ResultGui, ShowResultAtMouse, ResultManualPosition

    menuText := "在鼠标指针处显示结果"
    ShowResultAtMouse := !ShowResultAtMouse
    CONFIG.ShowResultAtMouse := ShowResultAtMouse
    WriteConfigSetting("ShowResultAtMouse", ShowResultAtMouse ? 1 : 0)

    if ShowResultAtMouse
    {
        A_TrayMenu.Check(menuText)

        if IsObject(ResultGui)
        {
            try
            {
                GetPhysicalWindowRect(ResultGui.Hwnd, &windowX, &windowY)
                ResultManualPosition := {
                    X: windowX,
                    Y: windowY
                }

                if DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd)
                    PositionResultWindowAtMouse()
            }
        }
    }
    else
    {
        A_TrayMenu.Uncheck(menuText)

        if IsObject(ResultGui) && IsObject(ResultManualPosition)
        {
            try MoveWindowPhysical(
                ResultGui.Hwnd,
                ResultManualPosition.X,
                ResultManualPosition.Y
            )
        }
    }
}


TranslateFromHotkey(*)
{
    global ActiveInputDialog, TranslationBusy

    if IsObject(ActiveInputDialog)
    {
        try WinActivate("ahk_id " . ActiveInputDialog.Gui.Hwnd)
        return
    }

    if TranslationBusy
        return

    if !EnsureOnlineServicesConsent()
        return

    TranslationBusy := true

    try
    {
        sourceText := GetSelectedText()

        if sourceText = ""
        {
            sourceText := PromptForText("输入翻译内容", "翻译", "translation")

            if sourceText = ""
            {
                TranslationBusy := false
                return
            }
        }

        targetLanguage := GetTranslationTargetLanguage(sourceText)
        StartTranslationRequest(sourceText, targetLanguage)
    }
    catch Error as err
    {
        TranslationBusy := false
        ShowTranslationError(err.Message)
    }
}


SpeakFromHotkey(*)
{
    global CONFIG, ActiveInputDialog

    if IsObject(ActiveInputDialog)
    {
        try WinActivate("ahk_id " . ActiveInputDialog.Gui.Hwnd)
        return
    }

    if !EnsureOnlineServicesConsent()
        return

    try
    {
        sourceText := GetSelectedText()

        if sourceText = ""
            sourceText := PromptForText("输入朗读内容", "朗读", "voice")

        if sourceText != ""
            StartEdgeSpeech(sourceText, CONFIG.SpeechVoice)
    }
    catch Error as err
    {
        TrayTip("无法朗读：" . err.Message, "译读朗读", 2)
    }
}


GetSelectedText()
{
    global CONFIG

    savedClipboard := ClipboardAll()
    selectedText := ""

    try
    {
        A_Clipboard := ""
        Send "^c"

        if ClipWait(CONFIG.SelectionTimeoutSeconds)
            selectedText := A_Clipboard
    }
    finally
    {
        A_Clipboard := savedClipboard
    }

    return Trim(selectedText)
}


PromptForText(windowTitle, submitLabel, selectorType := "")
{
    global CONFIG, SPEECH_VOICES, TRANSLATION_SERVICES, ActiveInputDialog

    state := {
        Confirmed: false,
        Text: "",
        Pinned: false
    }

    inputGui := Gui(
        "+Resize -MinimizeBox -MaximizeBox +MinSize"
            . (selectorType != "" ? "460" : "360") . "x200",
        windowTitle
    )
    inputGui.MarginX := 10
    inputGui.MarginY := 10
    inputGui.BackColor := "171A1F"
    inputGui.SetFont("s10 cF1F3F5", "Microsoft YaHei UI")

    inputEdit := inputGui.AddEdit(
        "xm ym w440 h204 +Multi +WantReturn Background20242B cF1F3F5"
    )
    pinButton := inputGui.AddButton("xm y+10 w72 h26", "钉住")
    selectorList := 0

    if selectorType = "voice"
    {
        voiceLabels := []

        for item in SPEECH_VOICES
            voiceLabels.Push(item.Label)

        selectorList := inputGui.AddDropDownList("x90 yp w220", voiceLabels)
        selectorList.Choose(GetSpeechVoiceIndex(CONFIG.SpeechVoice))
        selectorList.OnEvent("Change", ChangeSpeechVoice)
    }
    else if selectorType = "translation"
    {
        serviceLabels := []

        for item in TRANSLATION_SERVICES
            serviceLabels.Push(item.Label)

        selectorList := inputGui.AddDropDownList("x90 yp w220", serviceLabels)
        selectorList.Choose(GetTranslationServiceIndex(CONFIG.TranslationService))
        selectorList.OnEvent("Change", ChangeTranslationService)
    }

    submitButton := inputGui.AddButton(
        "x318 yp w72 h26 Default",
        submitLabel
    )
    cancelButton := inputGui.AddButton("x+8 yp w52 h26", "取消")

    if IsObject(selectorList)
        CenterControlVertically(pinButton, selectorList)

    ActiveInputDialog := {
        Gui: inputGui,
        Edit: inputEdit,
        PinButton: pinButton,
        SelectorList: selectorList,
        SubmitButton: submitButton,
        CancelButton: cancelButton,
        State: state
    }

    pinButton.OnEvent(
        "Click",
        ToggleInputPinned.Bind(state, inputGui, pinButton)
    )
    submitButton.OnEvent(
        "Click",
        SubmitTextInput.Bind(state, inputEdit, inputGui)
    )
    cancelButton.OnEvent("Click", CancelTranslationInput.Bind(inputGui))
    inputGui.OnEvent("Close", CancelTranslationInput.Bind(inputGui))
    inputGui.OnEvent("Escape", CancelTranslationInput.Bind(inputGui))
    inputGui.OnEvent(
        "Size",
        ResizeInputWindow.Bind(
            inputEdit,
            pinButton,
            selectorList,
            submitButton,
            cancelButton
        )
    )

    themedControls := [inputEdit, pinButton, submitButton, cancelButton]

    if IsObject(selectorList)
        themedControls.Push(selectorList)

    ApplyDarkTheme(inputGui, themedControls*)
    inputGui.Show("w460 h260")
    WinSetTransparent(238, "ahk_id " . inputGui.Hwnd)
    inputEdit.Focus()
    RedrawGuiWindow(inputGui)

    WinWaitClose("ahk_id " . inputGui.Hwnd)
    ActiveInputDialog := 0
    return state.Confirmed ? state.Text : ""
}


ChangeSpeechVoice(voiceList, *)
{
    global SPEECH_VOICES

    if voiceList.Value < 1 || voiceList.Value > SPEECH_VOICES.Length
        return

    SetSpeechVoice(SPEECH_VOICES[voiceList.Value].Voice)
}


ChangeTranslationService(serviceList, *)
{
    global TRANSLATION_SERVICES

    if serviceList.Value < 1
        || serviceList.Value > TRANSLATION_SERVICES.Length
    {
        return
    }

    SetTranslationService(TRANSLATION_SERVICES[serviceList.Value].Service)
}


SetSpeechVoice(voice, *)
{
    global CONFIG

    if GetSpeechVoiceIndex(voice) = 0
        return

    CONFIG.SpeechVoice := voice
    WriteConfigSetting("SpeechVoice", CONFIG.SpeechVoice)
    UpdateSpeechVoiceTrayChecks()
}


SetTranslationService(service, *)
{
    global CONFIG

    if GetTranslationServiceIndex(service) = 0
        return

    CONFIG.TranslationService := service
    WriteConfigSetting("TranslationService", CONFIG.TranslationService)
    UpdateTranslationServiceTrayChecks()
}


UpdateSpeechVoiceTrayChecks()
{
    global CONFIG, SPEECH_VOICES, SpeechVoiceTrayMenu

    if !IsObject(SpeechVoiceTrayMenu)
        return

    for item in SPEECH_VOICES
    {
        SpeechVoiceTrayMenu.Uncheck(item.Label)

        if item.Voice = CONFIG.SpeechVoice
            SpeechVoiceTrayMenu.Check(item.Label)
    }
}


UpdateTranslationServiceTrayChecks()
{
    global CONFIG, TRANSLATION_SERVICES, TranslationServiceTrayMenu

    if !IsObject(TranslationServiceTrayMenu)
        return

    for item in TRANSLATION_SERVICES
    {
        TranslationServiceTrayMenu.Uncheck(item.Label)

        if item.Service = CONFIG.TranslationService
            TranslationServiceTrayMenu.Check(item.Label)
    }
}


ToggleInputPinned(state, inputGui, pinButton, *)
{
    state.Pinned := !state.Pinned
    WinSetAlwaysOnTop(state.Pinned, "ahk_id " . inputGui.Hwnd)
    pinButton.Text := state.Pinned ? "取消钉住" : "钉住"
}


SubmitTextInput(state, inputEdit, inputGui, *)
{
    global ActiveInputDialog

    text := Trim(inputEdit.Value)

    if text = ""
    {
        inputEdit.Focus()
        return
    }

    state.Text := text
    state.Confirmed := true
    ActiveInputDialog := 0
    inputGui.Destroy()
}


CancelTranslationInput(inputGui, *)
{
    global ActiveInputDialog

    ActiveInputDialog := 0
    try inputGui.Destroy()
}


HandleInputKeyDown(wParam, lParam, message, hwnd)
{
    global ActiveInputDialog

    if !IsObject(ActiveInputDialog)
        return

    if hwnd != ActiveInputDialog.Edit.Hwnd || wParam != 0x0D
        return

    if GetKeyState("Shift")
    {
        newline := "`r`n"
        SendMessage(
            0x00C2,
            true,
            StrPtr(newline),
            ,
            "ahk_id " . hwnd
        )
    }
    else
    {
        SubmitTextInput(
            ActiveInputDialog.State,
            ActiveInputDialog.Edit,
            ActiveInputDialog.Gui
        )
    }

    return 0
}


HandleWindowBackgroundDrag(wParam, lParam, message, hwnd)
{
    global ResultGui, ActiveInputDialog

    isResultBackground := IsObject(ResultGui)
        && hwnd = ResultGui.Hwnd

    isInputBackground := IsObject(ActiveInputDialog)
        && hwnd = ActiveInputDialog.Gui.Hwnd

    if !isResultBackground && !isInputBackground
        return

    PostMessage(
        0x00A1,
        2,
        0,
        ,
        "ahk_id " . hwnd
    )

    return 0
}


HandleWindowActivation(wParam, lParam, message, hwnd)
{
    global ActiveInputDialog

    if !IsObject(ActiveInputDialog)
        return

    if hwnd != ActiveInputDialog.Gui.Hwnd
        return

    if (wParam & 0xFFFF) != 0 || ActiveInputDialog.State.Pinned
        return

    SetTimer(CloseInactiveInputWindow.Bind(hwnd), -1)
}


CloseInactiveInputWindow(hwnd)
{
    global ActiveInputDialog

    if !IsObject(ActiveInputDialog)
        return

    if ActiveInputDialog.Gui.Hwnd != hwnd
        return

    if ActiveInputDialog.State.Pinned
        return

    if !WinActive("ahk_id " . hwnd)
        CancelTranslationInput(ActiveInputDialog.Gui)
}


ResizeInputWindow(
    inputEdit,
    pinButton,
    selectorList,
    submitButton,
    cancelButton,
    guiObject,
    minMax,
    width,
    height
)
{
    if minMax = -1
        return

    inputEdit.Move(10, 10, Max(200, width - 20), Max(100, height - 56))
    pinButton.Move(10, height - 36)

    if IsObject(selectorList)
    {
        selectorList.Move(width - 370)
        CenterControlVertically(pinButton, selectorList)
    }

    submitButton.Move(width - 142, height - 36)
    cancelButton.Move(width - 62, height - 36)
    RedrawGuiWindow(guiObject)
}


CenterControlVertically(referenceControl, targetControl)
{
    referenceControl.GetPos(, &referenceY, , &referenceHeight)
    targetControl.GetPos(, , , &targetHeight)
    targetY := referenceY + Floor((referenceHeight - targetHeight) / 2)
    targetControl.Move(, targetY)
}


GetTranslationTargetLanguage(text)
{
    chineseCharacterCount := 0
    latinWordCount := 0
    position := 1

    while position := RegExMatch(
        text,
        "[\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{F900}-\x{FAFF}]",
        ,
        position
    )
    {
        chineseCharacterCount++
        position++
    }

    position := 1

    while position := RegExMatch(text, "[A-Za-z]+", &match, position)
    {
        latinWordCount++
        position += StrLen(match[0])
    }

    return chineseCharacterCount >= latinWordCount ? "en" : "zh"
}


StartTranslationRequest(sourceText, targetLanguage)
{
    global CONFIG, ActiveTranslationRequest

    StopSpeech()
    chunks := SplitTranslationText(sourceText)
    ActiveTranslationRequest := {
        Chunks: chunks,
        ChunkIndex: 0,
        Results: [],
        TargetLanguage: targetLanguage,
        Service: CONFIG.TranslationService,
        Http: 0,
        StartedAt: 0,
        Attempt: 0,
        MaximumAttempts: 3
    }
    ShowTranslationResult(
        chunks.Length > 1
            ? "翻译中...（共 " . chunks.Length . " 段）"
            : "翻译中...",
        true
    )

    try StartNextTranslationChunk()
    catch Error
    {
        FinishTranslationRequest()
        throw
    }
}


StartNextTranslationChunk(retryCurrent := false)
{
    global CONFIG, ActiveTranslationRequest

    if !IsObject(ActiveTranslationRequest)
        throw Error("翻译请求状态无效。")

    requestState := ActiveTranslationRequest

    if retryCurrent
        requestState.Attempt++
    else
    {
        requestState.ChunkIndex++
        requestState.Attempt := 1
    }

    sourceText := requestState.Chunks[requestState.ChunkIndex]
    requestOptions := BuildTranslationRequest(
        requestState.Service,
        sourceText,
        requestState.TargetLanguage,
        requestState.ChunkIndex,
        requestState.Attempt
    )

    request := requestOptions.Transport = "xmlhttp"
        ? ComObject("MSXML2.XMLHTTP.6.0")
        : ComObject("WinHttp.WinHttpRequest.5.1")

    if requestOptions.Transport = "winhttp"
    {
        request.SetTimeouts(
            CONFIG.RequestTimeoutMs,
            CONFIG.RequestTimeoutMs,
            CONFIG.RequestTimeoutMs,
            CONFIG.RequestTimeoutMs
        )
    }

    request.Open(requestOptions.Method, requestOptions.Url, true)
    request.SetRequestHeader("Content-Type", requestOptions.ContentType)
    request.SetRequestHeader("User-Agent", CONFIG.UserAgent)

    if requestOptions.Referer != ""
        request.SetRequestHeader("Referer", requestOptions.Referer)

    request.SetRequestHeader("Cache-Control", "no-cache")

    try
    {
        if requestOptions.Body = ""
            request.Send()
        else
            request.Send(requestOptions.Body)
    }
    catch Error as err
    {
        if IsTimeoutError(err)
            throw Error("翻译请求超时，请稍后重试。")

        throw Error("翻译请求失败，请检查网络连接后重试。")
    }

    requestState.Http := request
    requestState.StartedAt := A_TickCount
    SetTimer(CheckTranslationRequest, CONFIG.RequestPollIntervalMs)
}


RetryCurrentTranslationChunk()
{
    global ActiveTranslationRequest

    if !IsObject(ActiveTranslationRequest)
        return false

    requestState := ActiveTranslationRequest

    if requestState.Attempt >= requestState.MaximumAttempts
        return false

    try requestState.Http.Abort()
    SetTimer(CheckTranslationRequest, 0)
    ShowTranslationResult(
        "翻译请求不稳定，正在重试（"
            . (requestState.Attempt + 1) . "/"
            . requestState.MaximumAttempts . "）...",
        true
    )

    try
    {
        StartNextTranslationChunk(true)
        return true
    }
    catch Error
    {
        return RetryCurrentTranslationChunk()
    }
}


CheckTranslationRequest()
{
    global CONFIG, ActiveTranslationRequest

    if !IsObject(ActiveTranslationRequest)
    {
        SetTimer(CheckTranslationRequest, 0)
        return
    }

    requestState := ActiveTranslationRequest

    if A_TickCount - requestState.StartedAt >= CONFIG.RequestTimeoutMs
    {
        try requestState.Http.Abort()

        if RetryCurrentTranslationChunk()
            return

        FinishTranslationRequest()
        ShowTranslationError("翻译请求超时，请稍后重试。")
        return
    }

    try
    {
        if !IsTranslationResponseReady(requestState)
            return
    }
    catch Error as err
    {
        if RetryCurrentTranslationChunk()
            return

        FinishTranslationRequest()

        if IsTimeoutError(err)
            ShowTranslationError("翻译请求超时，请稍后重试。")
        else
            ShowTranslationError("翻译请求失败，请检查网络连接后重试。")

        return
    }

    try
    {
        translatedText := ParseTranslationResponse(
            requestState.Http,
            requestState.Service
        )
        requestState.Results.Push(translatedText)

        if requestState.ChunkIndex < requestState.Chunks.Length
        {
            StartNextTranslationChunk()
            return
        }

        combinedResult := JoinTranslationResults(requestState.Results)
        FinishTranslationRequest()
        ShowTranslationResult(combinedResult)
    }
    catch Error as err
    {
        retryable := true

        try
        {
            status := requestState.Http.Status
            retryable := status < 400
                || status = 408
                || status = 429
                || status >= 500
        }

        if retryable && RetryCurrentTranslationChunk()
            return

        FinishTranslationRequest()
        ShowTranslationError(err.Message)
    }
}


IsTranslationResponseReady(requestState)
{
    if requestState.Service = "google"
        return requestState.Http.readyState = 4

    return requestState.Http.WaitForResponse(0)
}


FinishTranslationRequest()
{
    global TranslationBusy, ActiveTranslationRequest

    SetTimer(CheckTranslationRequest, 0)
    ActiveTranslationRequest := 0
    TranslationBusy := false
}


BuildTranslationRequest(service, sourceText, targetLanguage, chunkIndex, attempt)
{
    global CONFIG

    if service = "youdao"
    {
        return {
            Method: "POST",
            Url: "https://aidemo.youdao.com/trans",
            Transport: "winhttp",
            ContentType: "application/x-www-form-urlencoded; charset=UTF-8",
            Referer: "https://ai.youdao.com/",
            Body: "q=" . UrlEncode(sourceText) . "&from=Auto&to=Auto"
        }
    }

    if service = "google"
    {
        googleTarget := targetLanguage = "zh" ? "zh-CN" : targetLanguage
        params := "client=dict-chrome-ex&sl=auto&tl="
            . UrlEncode(googleTarget) . "&q=" . UrlEncode(sourceText)

        return {
            Method: "GET",
            Url: "https://clients5.google.com/translate_a/t?" . params,
            Transport: "xmlhttp",
            ContentType: "application/json",
            Referer: "",
            Body: ""
        }
    }

    params := "source=auto"
        . "&target=" . UrlEncode(targetLanguage)
        . "&sourceText=" . UrlEncode(sourceText)
        . "&platform=WeChat_APP"
        . "&candidateLangs=en%7Czh"
        . "&guid=ahk_v2_" . A_TickCount . "_"
        . chunkIndex . "_" . attempt

    return {
        Method: "GET",
        Url: CONFIG.ApiUrl . "?" . params,
        Transport: "winhttp",
        ContentType: "application/json",
        Referer: CONFIG.Referer,
        Body: ""
    }
}


ParseTranslationResponse(request, service)
{
    status := request.Status

    if status < 200 || status >= 300
        throw Error("翻译服务返回 HTTP " . status . "。")

    try
    {
        responseText := service = "tencent"
            ? request.ResponseText
            : ReadUtf8HttpResponse(request)
        response := JsonParser.Parse(responseText)
    }
    catch Error
    {
        throw Error("翻译服务响应解析失败。")
    }

    if service = "youdao"
        return ParseYoudaoTranslationResponse(response)

    if service = "google"
        return ParseGoogleTranslationResponse(response)

    if !(response is Map)
        || !response.Has("targetText")
        || Type(response["targetText"]) != "String"
        || Trim(response["targetText"]) = ""
    {
        throw Error("翻译服务接口返回异常。")
    }

    return response["targetText"]
}


ReadUtf8HttpResponse(request)
{
    stream := ComObject("ADODB.Stream")
    stream.Type := 1
    stream.Open()

    try
    {
        stream.Write(request.ResponseBody)
        stream.Position := 0
        stream.Type := 2
        stream.Charset := "utf-8"
        responseText := stream.ReadText()
    }
    finally
    {
        stream.Close()
    }

    if SubStr(responseText, 1, 1) = Chr(0xFEFF)
        responseText := SubStr(responseText, 2)

    return responseText
}


ParseYoudaoTranslationResponse(response)
{
    if !(response is Map)
        || !response.Has("errorCode")
        || response["errorCode"] != "0"
        || !response.Has("translation")
        || !(response["translation"] is Array)
    {
        throw Error("有道翻译接口返回异常。")
    }

    translatedText := ""

    for item in response["translation"]
    {
        if Type(item) != "String" || Trim(item) = ""
            continue

        if translatedText != ""
            translatedText .= "`r`n"

        translatedText .= item
    }

    if translatedText = ""
        throw Error("有道翻译接口未返回翻译结果。")

    return translatedText
}


ParseGoogleTranslationResponse(response)
{
    if !(response is Array)
        || response.Length = 0
        || !(response[1] is Array)
    {
        throw Error("谷歌翻译接口返回异常。")
    }

    translatedText := ""

    if response[1].Length > 0 && Type(response[1][1]) = "String"
        return response[1][1]

    for segment in response[1]
    {
        if !(segment is Array)
            || segment.Length = 0
            || Type(segment[1]) != "String"
        {
            continue
        }

        translatedText .= segment[1]
    }

    if Trim(translatedText) = ""
        throw Error("谷歌翻译接口未返回翻译结果。")

    return translatedText
}


SplitTranslationText(text, maximumEncodedLength := 6000)
{
    chunks := []
    remaining := text

    while remaining != ""
    {
        if StrLen(UrlEncode(remaining)) <= maximumEncodedLength
        {
            chunks.Push(remaining)
            break
        }

        low := 1
        high := StrLen(remaining)
        maximumCharacters := 1

        while low <= high
        {
            middle := Floor((low + high) / 2)
            candidate := SubStr(remaining, 1, middle)

            if StrLen(UrlEncode(candidate)) <= maximumEncodedLength
            {
                maximumCharacters := middle
                low := middle + 1
            }
            else
            {
                high := middle - 1
            }
        }

        if maximumCharacters < StrLen(remaining)
            && Ord(SubStr(remaining, maximumCharacters, 1)) >= 0xD800
            && Ord(SubStr(remaining, maximumCharacters, 1)) <= 0xDBFF
        {
            maximumCharacters--
        }

        splitPosition := FindTranslationSplitPosition(
            remaining,
            maximumCharacters
        )
        chunks.Push(SubStr(remaining, 1, splitPosition))
        remaining := SubStr(remaining, splitPosition + 1)
    }

    return chunks
}


FindTranslationSplitPosition(text, maximumCharacters)
{
    candidate := SubStr(text, 1, maximumCharacters)
    newlinePosition := InStr(candidate, "`n", false, -1)
    spacePosition := InStr(candidate, " ", false, -1)
    preferredPosition := Max(newlinePosition, spacePosition)

    if preferredPosition >= Floor(maximumCharacters / 2)
        return preferredPosition

    return maximumCharacters
}


JoinTranslationResults(results)
{
    combined := ""

    for translatedText in results
    {
        if combined != ""
            combined .= "`r`n"

        combined .= translatedText
    }

    return combined
}


IsTimeoutError(err)
{
    if InStr(err.Message, "timed out", false)
        || InStr(err.Message, "timeout", false)
        || InStr(err.Message, "超时")
    {
        return true
    }

    return err is OSError && (err.Number & 0xFFFF) = 12002
}


UrlEncode(text)
{
    bufferSize := StrPut(text, "UTF-8")
    utf8 := Buffer(bufferSize)
    byteCount := StrPut(text, utf8, "UTF-8") - 1
    encoded := ""

    Loop byteCount
    {
        byte := NumGet(utf8, A_Index - 1, "UChar")

        if (byte >= 0x30 && byte <= 0x39)
            || (byte >= 0x41 && byte <= 0x5A)
            || (byte >= 0x61 && byte <= 0x7A)
            || byte = 0x2D
            || byte = 0x2E
            || byte = 0x5F
            || byte = 0x7E
        {
            encoded .= Chr(byte)
        }
        else
        {
            encoded .= Format("%{:02X}", byte)
        }
    }

    return encoded
}


ShowTranslationResult(translatedText, pending := false)
{
    global ResultGui, ResultEdit, ResultPinButton, ResultSpeakButton
    global ResultCopyButton, ResultCloseButton
    global ShowResultAtMouse

    isNewWindow := !IsObject(ResultGui)
    wasVisible := !isNewWindow
        && DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd)

    if isNewWindow
        CreateResultWindow()

    ResultEdit.Value := translatedText
    ResultEdit.Opt(pending ? "+ReadOnly" : "-ReadOnly")
    ResultSpeakButton.Enabled := !pending
    ResultCopyButton.Enabled := !pending

    if isNewWindow
    {
        ApplyDarkTheme(
            ResultGui,
            ResultEdit,
            ResultPinButton,
            ResultSpeakButton,
            ResultCopyButton,
            ResultCloseButton
        )
        ResultGui.Show("w360 h200")
        WinSetTransparent(225, "ahk_id " . ResultGui.Hwnd)
    }
    else
    {
        try
        {
            if WinGetMinMax("ahk_id " . ResultGui.Hwnd) = -1
                WinRestore("ahk_id " . ResultGui.Hwnd)
        }

        ResultGui.Show()
    }

    if ShowResultAtMouse && (pending || isNewWindow || !wasVisible)
        PositionResultWindowAtMouse()

    WinActivate("ahk_id " . ResultGui.Hwnd)
    RedrawGuiWindow(ResultGui)
}


PositionResultWindowAtMouse()
{
    global ResultGui, ResultPinned

    if !IsObject(ResultGui) || ResultPinned
        return

    try
    {
        if WinGetMinMax("ahk_id " . ResultGui.Hwnd) != 0
            WinRestore("ahk_id " . ResultGui.Hwnd)

        cursorPoint := Buffer(8, 0)

        if !DllCall("GetCursorPos", "Ptr", cursorPoint.Ptr)
            return

        mouseX := NumGet(cursorPoint, 0, "Int")
        mouseY := NumGet(cursorPoint, 4, "Int")
        GetPhysicalWindowRect(
            ResultGui.Hwnd,
            ,
            ,
            &windowWidth,
            &windowHeight
        )

        monitor := GetMonitorAtPoint(mouseX, mouseY)
        MonitorGetWorkArea(
            monitor,
            &workLeft,
            &workTop,
            &workRight,
            &workBottom
        )

        gap := 12
        targetX := mouseX + gap
        targetY := mouseY + gap

        if targetX + windowWidth > workRight
            targetX := mouseX - windowWidth - gap

        if targetY + windowHeight > workBottom
            targetY := mouseY - windowHeight - gap

        maxX := workRight - windowWidth
        maxY := workBottom - windowHeight
        targetX := maxX < workLeft
            ? workLeft
            : Min(Max(targetX, workLeft), maxX)
        targetY := maxY < workTop
            ? workTop
            : Min(Max(targetY, workTop), maxY)

        MoveWindowPhysical(
            ResultGui.Hwnd,
            targetX,
            targetY
        )
    }
}


GetPhysicalWindowRect(
    hwnd,
    &x := 0,
    &y := 0,
    &width := 0,
    &height := 0
)
{
    rect := Buffer(16, 0)

    if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect.Ptr)
        throw OSError()

    left := NumGet(rect, 0, "Int")
    top := NumGet(rect, 4, "Int")
    right := NumGet(rect, 8, "Int")
    bottom := NumGet(rect, 12, "Int")

    x := left
    y := top
    width := right - left
    height := bottom - top
}


MoveWindowPhysical(hwnd, x, y)
{
    static SWP_NOSIZE_NOZORDER_NOACTIVATE := 0x0015

    if !DllCall(
        "SetWindowPos",
        "Ptr", hwnd,
        "Ptr", 0,
        "Int", Round(x),
        "Int", Round(y),
        "Int", 0,
        "Int", 0,
        "UInt", SWP_NOSIZE_NOZORDER_NOACTIVATE
    )
    {
        throw OSError()
    }
}


GetMonitorAtPoint(x, y)
{
    monitorCount := MonitorGetCount()

    Loop monitorCount
    {
        MonitorGet(
            A_Index,
            &monitorLeft,
            &monitorTop,
            &monitorRight,
            &monitorBottom
        )

        if x >= monitorLeft
            && x < monitorRight
            && y >= monitorTop
            && y < monitorBottom
        {
            return A_Index
        }
    }

    return MonitorGetPrimary()
}


ShowTranslationError(message)
{
    ShowTranslationResult("翻译失败：`r`n" . message)
}


CreateResultWindow()
{
    global ResultGui, ResultEdit, ResultPinButton, ResultSpeakButton
    global ResultCopyButton, ResultCloseButton

    ResultGui := Gui("+Resize +MinSize320x128", "翻译结果")
    ResultGui.MarginX := 10
    ResultGui.MarginY := 10
    ResultGui.BackColor := "171A1F"
    ResultGui.SetFont("s10 cF1F3F5", "Microsoft YaHei UI")

    ResultEdit := ResultGui.AddEdit(
        "xm ym w360 h144 +Multi +WantReturn Background20242B cF1F3F5"
    )
    ResultPinButton := ResultGui.AddButton("xm y+10 w72 h26", "钉住")
    ResultSpeakButton := ResultGui.AddButton("x146 yp w64 h26", "朗读")
    ResultCopyButton := ResultGui.AddButton("x+8 yp w72 h26 Default", "复制结果")
    ResultCloseButton := ResultGui.AddButton("x+8 yp w52 h26", "关闭")

    ResultPinButton.OnEvent("Click", ToggleResultPinned)
    ResultSpeakButton.OnEvent("Click", SpeakCurrentTranslation)
    ResultCopyButton.OnEvent("Click", CopyCurrentTranslation)
    ResultCloseButton.OnEvent("Click", HideResultWindow)
    ResultGui.OnEvent("Close", HideResultWindow)
    ResultGui.OnEvent("Escape", HideResultWindow)
    ResultGui.OnEvent(
        "Size",
        ResizeResultWindow.Bind(
            ResultEdit,
            ResultPinButton,
            ResultSpeakButton,
            ResultCopyButton,
            ResultCloseButton
        )
    )
}


HideResultWindow(*)
{
    global ResultGui

    if IsObject(ResultGui)
        ResultGui.Hide()
}


CopyCurrentTranslation(*)
{
    global ResultGui, ResultEdit, ResultCopyButton

    if IsObject(ResultEdit)
    {
        A_Clipboard := ResultEdit.Value
        ResultCopyButton.Text := "已复制"
        SetTimer(RestoreCopyButtonFeedback, -900)
        RedrawGuiWindow(ResultGui)
    }
}


RestoreCopyButtonFeedback()
{
    global ResultGui, ResultCopyButton

    if !IsObject(ResultCopyButton)
        return

    ResultCopyButton.Text := "复制结果"

    if IsObject(ResultGui)
        RedrawGuiWindow(ResultGui)
}


ToggleResultPinned(*)
{
    global ResultGui, ResultPinButton, ResultPinned

    if !IsObject(ResultGui)
        return

    ResultPinned := !ResultPinned
    WinSetAlwaysOnTop(ResultPinned, "ahk_id " . ResultGui.Hwnd)
    ResultPinButton.Text := ResultPinned ? "取消钉住" : "钉住"
}


SpeakCurrentTranslation(*)
{
    global CONFIG, ResultEdit, SpeechBusy

    if SpeechBusy
    {
        StopSpeech()
        return
    }

    if !IsObject(ResultEdit)
        return

    text := Trim(ResultEdit.Value)

    if text = ""
        return

    StartEdgeSpeech(text, CONFIG.SpeechVoice)
}


StartEdgeSpeech(text, voice)
{
    global ResultSpeakButton, SpeechAudioPath, SpeechErrorPath, SpeechDonePath
    global SpeechBusy, SpeechStartedAt
    global SpeechTimeoutMs, SpeechSynthesisPending
    global SpeechWorkerRequestPath

    if !EnsureOnlineServicesConsent()
        return

    StopSpeech()

    if !EnsureSpeechWorker()
    {
        TrayTip("无法启动系统语音工作进程。", "译读朗读", 2)
        return
    }

    uniqueId := DllCall("GetCurrentProcessId", "UInt") . "_" . A_TickCount
    SpeechAudioPath := A_Temp . "\YiDuTTS_" . uniqueId . ".mp3"
    SpeechErrorPath := A_Temp . "\YiDuTTS_" . uniqueId . ".error"
    SpeechDonePath := A_Temp . "\YiDuTTS_" . uniqueId . ".done"
    requestTempPath := SpeechWorkerRequestPath . ".tmp"
    payload := Base64EncodeUtf8(text) . "`n"
        . Base64EncodeUtf8(voice) . "`n"
        . Base64EncodeUtf8(SpeechAudioPath) . "`n"
        . Base64EncodeUtf8(SpeechErrorPath) . "`n"
        . Base64EncodeUtf8(SpeechDonePath)

    try
    {
        if FileExist(requestTempPath)
            FileDelete(requestTempPath)

        if FileExist(SpeechWorkerRequestPath)
            FileDelete(SpeechWorkerRequestPath)

        FileAppend(payload, requestTempPath, "UTF-8")
        FileMove(requestTempPath, SpeechWorkerRequestPath, true)
    }
    catch Error as err
    {
        StopSpeech()
        TrayTip(
            "无法提交语音合成任务：" . err.Message,
            "译读朗读",
            2
        )
        return
    }

    SpeechBusy := true
    SpeechSynthesisPending := true
    SpeechStartedAt := A_TickCount
    SpeechTimeoutMs := 60000
    if IsObject(ResultSpeakButton)
        ResultSpeakButton.Text := "停止"
    SetTimer(CheckSpeechSynthesis, 50)
}


CheckSpeechSynthesis()
{
    global SpeechAudioPath, SpeechErrorPath, SpeechDonePath
    global SpeechStartedAt, SpeechTimeoutMs
    global SpeechSynthesisPending, SpeechWorkerProcessId

    if !SpeechSynthesisPending
    {
        SetTimer(CheckSpeechSynthesis, 0)
        return
    }

    if A_TickCount - SpeechStartedAt >= SpeechTimeoutMs
    {
        StopSpeech()
        TrayTip("在线语音合成超时，请稍后重试。", "译读朗读", 2)
        return
    }

    if !SpeechWorkerProcessId || !ProcessExist(SpeechWorkerProcessId)
    {
        StopSpeech()
        TrayTip("在线语音工作进程意外退出。", "译读朗读", 2)
        return
    }

    if !FileExist(SpeechDonePath)
        return

    SetTimer(CheckSpeechSynthesis, 0)
    SpeechSynthesisPending := false
    try FileDelete(SpeechDonePath)
    SpeechDonePath := ""
    errorMessage := ""

    if FileExist(SpeechErrorPath)
    {
        try errorMessage := Trim(FileRead(SpeechErrorPath, "UTF-8"))
        try FileDelete(SpeechErrorPath)
        SpeechErrorPath := ""
    }

    if errorMessage != ""
    {
        StopSpeech()
        TrayTip(
            "在线语音合成失败：" . errorMessage,
            "译读朗读",
            2
        )
        return
    }

    try
    {
        if !FileExist(SpeechAudioPath)
            throw Error("语音服务没有生成音频。")

        PlaySpeechAudio(SpeechAudioPath)
    }
    catch Error as err
    {
        StopSpeech()
        TrayTip("无法播放语音：" . err.Message, "译读朗读", 2)
    }
}


PlaySpeechAudio(audioPath)
{
    global SpeechMciAlias

    SpeechMciAlias := "YiDuTTS"
        . DllCall("GetCurrentProcessId", "UInt")
    quotedPath := Chr(34) . audioPath . Chr(34)
    result := MciSend(
        "open " . quotedPath . " type mpegvideo alias " . SpeechMciAlias
    )

    if result
        throw Error(GetMciErrorMessage(result))

    result := MciSend("play " . SpeechMciAlias)

    if result
    {
        MciSend("close " . SpeechMciAlias)
        SpeechMciAlias := ""
        throw Error(GetMciErrorMessage(result))
    }

    SetTimer(CheckSpeechPlayback, 200)
}


CheckSpeechPlayback()
{
    global SpeechMciAlias

    if SpeechMciAlias = ""
    {
        SetTimer(CheckSpeechPlayback, 0)
        return
    }

    mode := MciGetMode(SpeechMciAlias)

    if mode != "playing" && mode != "seeking"
        StopSpeech()
}


StopSpeech(*)
{
    global ResultSpeakButton, SpeechAudioPath, SpeechErrorPath, SpeechDonePath
    global SpeechBusy, SpeechStartedAt, SpeechMciAlias
    global SpeechTimeoutMs, SpeechSynthesisPending

    SetTimer(CheckSpeechSynthesis, 0)
    SetTimer(CheckSpeechPlayback, 0)

    if SpeechSynthesisPending
        StopSpeechWorker()

    if SpeechMciAlias != ""
    {
        MciSend("stop " . SpeechMciAlias)
        MciSend("close " . SpeechMciAlias)
        SpeechMciAlias := ""
    }

    if SpeechAudioPath != "" && FileExist(SpeechAudioPath)
        try FileDelete(SpeechAudioPath)

    if SpeechErrorPath != "" && FileExist(SpeechErrorPath)
        try FileDelete(SpeechErrorPath)

    if SpeechDonePath != "" && FileExist(SpeechDonePath)
        try FileDelete(SpeechDonePath)

    SpeechAudioPath := ""
    SpeechErrorPath := ""
    SpeechDonePath := ""
    SpeechBusy := false
    SpeechStartedAt := 0
    SpeechTimeoutMs := 60000
    SpeechSynthesisPending := false

    if IsObject(ResultSpeakButton)
        ResultSpeakButton.Text := "朗读"
}


CleanupSpeech(*)
{
    StopSpeech()
    StopSpeechWorker()
}


EnsureSpeechWorker(*)
{
    global SpeechWorkerProcessId, SpeechWorkerScriptPath
    global SpeechWorkerRequestPath, SpeechWorkerReadyPath

    if SpeechWorkerProcessId && ProcessExist(SpeechWorkerProcessId)
        return true

    StopSpeechWorker()
    workerId := DllCall("GetCurrentProcessId", "UInt")
    SpeechWorkerScriptPath := A_Temp
        . "\YiDuTTS_Worker_" . workerId . ".ps1"
    SpeechWorkerRequestPath := A_Temp
        . "\YiDuTTS_Worker_" . workerId . ".request"
    SpeechWorkerReadyPath := A_Temp
        . "\YiDuTTS_Worker_" . workerId . ".ready"

    for staleWorkerFile in [
        SpeechWorkerScriptPath,
        SpeechWorkerRequestPath,
        SpeechWorkerRequestPath . ".tmp",
        SpeechWorkerReadyPath
    ]
    {
        if FileExist(staleWorkerFile)
            try FileDelete(staleWorkerFile)
    }

    script := BuildEdgeSpeechWorkerPowerShell(
        SpeechWorkerRequestPath,
        SpeechWorkerReadyPath,
        workerId
    )

    try
    {
        FileAppend(script, SpeechWorkerScriptPath, "UTF-8")
        command := "powershell.exe -NoLogo -NoProfile -NonInteractive "
            . "-ExecutionPolicy Bypass -File "
            . QuoteCommandArgument(SpeechWorkerScriptPath)
        Run(command, , "Hide", &SpeechWorkerProcessId)
        return true
    }
    catch Error
    {
        StopSpeechWorker()
        return false
    }
}


StopSpeechWorker(*)
{
    global SpeechWorkerProcessId, SpeechWorkerScriptPath
    global SpeechWorkerRequestPath, SpeechWorkerReadyPath

    if SpeechWorkerProcessId && ProcessExist(SpeechWorkerProcessId)
    {
        try ProcessClose(SpeechWorkerProcessId)
        try ProcessWaitClose(SpeechWorkerProcessId, 2)
    }

    workerFiles := [
        SpeechWorkerScriptPath,
        SpeechWorkerRequestPath,
        SpeechWorkerRequestPath != "" ? SpeechWorkerRequestPath . ".tmp" : "",
        SpeechWorkerReadyPath
    ]

    for workerFile in workerFiles
    {
        if workerFile != "" && FileExist(workerFile)
            try FileDelete(workerFile)
    }

    SpeechWorkerProcessId := 0
    SpeechWorkerScriptPath := ""
    SpeechWorkerRequestPath := ""
    SpeechWorkerReadyPath := ""
}


MciSend(command)
{
    return DllCall(
        "winmm\mciSendStringW",
        "Str", command,
        "Ptr", 0,
        "UInt", 0,
        "Ptr", 0,
        "UInt"
    )
}


MciGetMode(alias)
{
    resultBuffer := Buffer(64 * 2, 0)
    result := DllCall(
        "winmm\mciSendStringW",
        "Str", "status " . alias . " mode",
        "Ptr", resultBuffer.Ptr,
        "UInt", 64,
        "Ptr", 0,
        "UInt"
    )

    return result ? "" : StrGet(resultBuffer, "UTF-16")
}


GetMciErrorMessage(errorCode)
{
    messageBuffer := Buffer(256 * 2, 0)

    if DllCall(
        "winmm\mciGetErrorStringW",
        "UInt", errorCode,
        "Ptr", messageBuffer.Ptr,
        "UInt", 256
    )
    {
        return StrGet(messageBuffer, "UTF-16")
    }

    return "MCI 错误 " . errorCode
}


BuildEdgeSpeechWorkerPowerShell(requestPath, readyPath, parentProcessId)
{
    script := '
(
$ErrorActionPreference = 'Stop'
$requestPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__REQUEST__'))
$readyPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__READY__'))
$parentProcessId = __PARENT_PROCESS_ID__
try { $parentProcess = [Diagnostics.Process]::GetProcessById($parentProcessId) }
catch { exit }
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

public sealed class PrefixStream : Stream
{
    private readonly Stream inner;
    private readonly byte[] prefix;
    private int position;

    public PrefixStream(Stream inner, byte[] source, int offset, int count)
    {
        this.inner = inner;
        prefix = new byte[count];
        Buffer.BlockCopy(source, offset, prefix, 0, count);
    }

    public override bool CanRead { get { return true; } }
    public override bool CanSeek { get { return false; } }
    public override bool CanWrite { get { return true; } }
    public override long Length { get { throw new NotSupportedException(); } }
    public override long Position {
        get { throw new NotSupportedException(); }
        set { throw new NotSupportedException(); }
    }

    public override int Read(byte[] buffer, int offset, int count)
    {
        if (position < prefix.Length) {
            int available = Math.Min(count, prefix.Length - position);
            Buffer.BlockCopy(prefix, position, buffer, offset, available);
            position += available;
            return available;
        }
        return inner.Read(buffer, offset, count);
    }

    public override void Write(byte[] buffer, int offset, int count)
    {
        inner.Write(buffer, offset, count);
    }

    public override void Flush() { inner.Flush(); }
    public override long Seek(long offset, SeekOrigin origin)
    {
        throw new NotSupportedException();
    }
    public override void SetLength(long value)
    {
        throw new NotSupportedException();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) inner.Dispose();
        base.Dispose(disposing);
    }
}

'@
$trustedToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4'
$edgeVersion = '143.0.3650.75'
$edgePaths = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe'))

foreach ($edgePath in $edgePaths) {
    if ($edgePath -and (Test-Path -LiteralPath $edgePath)) {
        $installedVersion = (Get-Item -LiteralPath $edgePath).VersionInfo.ProductVersion
        if ($installedVersion) { $edgeVersion = $installedVersion }
        break
    }
}

$edgeMajor = $edgeVersion.Split('.')[0]
$userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ' +
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/' + $edgeMajor +
    '.0.0.0 Safari/537.36 Edg/' + $edgeMajor + '.0.0.0'

function Get-SecMsGec {
    $seconds = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 11644473600
    $seconds -= $seconds % 300
    $ticks = [Int64]$seconds * 10000000
    $bytes = [Text.Encoding]::ASCII.GetBytes(([string]$ticks) + $trustedToken)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Get-EdgeTimestamp {
    return [DateTime]::UtcNow.ToString(
        "ddd MMM dd yyyy HH:mm:ss 'GMT+0000 (Coordinated Universal Time)'",
        [Globalization.CultureInfo]::InvariantCulture)
}

function Send-WebSocketText($socket, [string]$message) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($message)
    $segment = [ArraySegment[byte]]::new($bytes)
    $null = $socket.SendAsync(
        $segment,
        [Net.WebSockets.WebSocketMessageType]::Text,
        $true,
        [Threading.CancellationToken]::None).GetAwaiter().GetResult()
}

function Open-EdgeWebSocket([string]$uri) {
    $requestUri = [Uri]$uri
    $tcp = [Net.Sockets.TcpClient]::new()
    $tcp.Connect($requestUri.Host, 443)
    $ssl = [Net.Security.SslStream]::new($tcp.GetStream(), $false)
    $ssl.AuthenticateAsClient($requestUri.Host)
    $keyBytes = [byte[]]::new(16)
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($keyBytes)
    $webSocketKey = [Convert]::ToBase64String($keyBytes)
    $crlf = [char]13 + [char]10
    $handshake = 'GET ' + $requestUri.PathAndQuery + ' HTTP/1.1' + $crlf +
        'Host: ' + $requestUri.Host + $crlf +
        'Connection: Upgrade' + $crlf +
        'Pragma: no-cache' + $crlf +
        'Cache-Control: no-cache' + $crlf +
        'User-Agent: ' + $userAgent + $crlf +
        'Upgrade: websocket' + $crlf +
        'Origin: chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold' + $crlf +
        'Sec-WebSocket-Version: 13' + $crlf +
        'Accept-Encoding: gzip, deflate, br' + $crlf +
        'Accept-Language: en-US,en;q=0.9' + $crlf +
        'Cookie: muid=' + [Guid]::NewGuid().ToString('N').ToUpperInvariant() + ';' +
        $crlf + 'Sec-WebSocket-Key: ' + $webSocketKey + $crlf + $crlf
    $requestBytes = [Text.Encoding]::ASCII.GetBytes($handshake)
    $ssl.Write($requestBytes, 0, $requestBytes.Length)
    $ssl.Flush()

    $headerStream = [IO.MemoryStream]::new()
    $headerBuffer = [byte[]]::new(4096)
    $responseHeaders = ''
    $headerEnd = -1
    while ($headerStream.Length -lt 16384) {
        $bytesRead = $ssl.Read($headerBuffer, 0, $headerBuffer.Length)
        if ($bytesRead -le 0) {
            throw '语音服务在 WebSocket 握手时断开连接。'
        }
        $headerStream.Write($headerBuffer, 0, $bytesRead)
        $allBytes = $headerStream.ToArray()
        $responseText = [Text.Encoding]::ASCII.GetString($allBytes)
        $headerEnd = $responseText.IndexOf($crlf + $crlf)
        if ($headerEnd -ge 0) {
            $headerEnd += 4
            $responseHeaders = $responseText.Substring(0, $headerEnd)
            break
        }
    }
    $headerStream.Dispose()

    if ($headerEnd -lt 0) {
        throw 'WebSocket 握手响应头过大。'
    }

    if (-not $responseHeaders.StartsWith('HTTP/1.1 101')) {
        throw 'WebSocket 握手失败：' + $responseHeaders.Split($crlf)[0]
    }

    $acceptSource = [Text.Encoding]::ASCII.GetBytes(
        $webSocketKey + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
    $sha1 = [Security.Cryptography.SHA1]::Create()
    try { $expectedAccept = [Convert]::ToBase64String($sha1.ComputeHash($acceptSource)) }
    finally { $sha1.Dispose() }
    if ($responseHeaders -notmatch
        ('(?im)^Sec-WebSocket-Accept:\s*' + [Regex]::Escape($expectedAccept) + '\s*$')) {
        throw '语音服务返回了无效的 WebSocket 握手。'
    }

    $internalBuffer = [byte[]]::new(65536)
    $webSocketStream = [PrefixStream]::new(
        $ssl,
        $allBytes,
        $headerEnd,
        $allBytes.Length - $headerEnd)
    $createMethod = [Net.WebSockets.WebSocket].GetMethod('CreateClientWebSocket')
    $socket = $createMethod.Invoke(
        $null,
        [object[]]@(
            $webSocketStream,
            $null,
            16384,
            16384,
            [TimeSpan]::FromSeconds(20),
            $false,
            [ArraySegment[byte]]::new($internalBuffer)))
    return [PSCustomObject]@{
        Socket = $socket
        Stream = $webSocketStream
        Tcp = $tcp
    }
}

function Close-EdgeSpeechConnection {
    if ($null -eq $script:edgeConnection) { return }
    try { $script:edgeConnection.Socket.Abort() } catch {}
    try { $script:edgeConnection.Socket.Dispose() } catch {}
    try { $script:edgeConnection.Stream.Dispose() } catch {}
    try { $script:edgeConnection.Tcp.Dispose() } catch {}
    $script:edgeConnection = $null
}

function Open-EdgeSpeechConnection {
    $connectionId = [Guid]::NewGuid().ToString('N')
    $gec = Get-SecMsGec
    $uri = 'wss://speech.platform.bing.com/consumer/speech/synthesize/' +
        'readaloud/edge/v1?TrustedClientToken=' + $trustedToken +
        '&ConnectionId=' + $connectionId + '&Sec-MS-GEC=' + $gec +
        '&Sec-MS-GEC-Version=1-' + $edgeVersion
    $script:edgeConnection = Open-EdgeWebSocket $uri
    $crlf = [char]13 + [char]10
    $config = 'X-Timestamp:' + (Get-EdgeTimestamp) + $crlf +
        'Content-Type:application/json; charset=utf-8' + $crlf +
        'Path:speech.config' + $crlf + $crlf +
        '{"context":{"synthesis":{"audio":{"metadataoptions":' +
        '{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},' +
        '"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}' + $crlf
    Send-WebSocketText $script:edgeConnection.Socket $config
}

function Get-EdgeSpeechSocket {
    if ($null -eq $script:edgeConnection -or
        $script:edgeConnection.Socket.State -ne [Net.WebSockets.WebSocketState]::Open) {
        Close-EdgeSpeechConnection
        Open-EdgeSpeechConnection
    }
    return $script:edgeConnection.Socket
}

function Invoke-EdgeTtsChunk([string]$chunk, [IO.Stream]$audioStream) {
    $chunkStart = $audioStream.Position
    $audioBytesBefore = $script:audioBytes

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try {
            $requestId = [Guid]::NewGuid().ToString('N')
            $socket = Get-EdgeSpeechSocket
            $crlf = [char]13 + [char]10
            $escapedText = [Security.SecurityElement]::Escape($chunk)
            $ssml = "<speak version='1.0' " +
                "xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'>" +
                "<voice name='$voice'><prosody pitch='+0Hz' rate='+0%' volume='+0%'>" +
                $escapedText + '</prosody></voice></speak>'
            $request = 'X-RequestId:' + $requestId + $crlf +
                'Content-Type:application/ssml+xml' + $crlf +
                'X-Timestamp:' + (Get-EdgeTimestamp) + 'Z' + $crlf +
                'Path:ssml' + $crlf + $crlf + $ssml
            Send-WebSocketText $socket $request

            :receiveLoop while ($true) {
                $message = [IO.MemoryStream]::new()
                try {
                    do {
                        $buffer = [byte[]]::new(16384)
                        $segment = [ArraySegment[byte]]::new($buffer)
                        $received = $socket.ReceiveAsync(
                            $segment,
                            [Threading.CancellationToken]::None).GetAwaiter().GetResult()
                        if ($received.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) {
                            throw '语音服务提前关闭了连接。'
                        }
                        $message.Write($buffer, 0, $received.Count)
                    } while (-not $received.EndOfMessage)

                    $data = $message.ToArray()
                    if ($received.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Text) {
                        $responseText = [Text.Encoding]::UTF8.GetString($data)
                        if ($responseText.Contains('Path:turn.end')) { break receiveLoop }
                    }
                    elseif ($data.Length -ge 2) {
                        $headerLength = ([int]$data[0] * 256) + [int]$data[1]
                        $audioOffset = 2 + $headerLength
                        if ($audioOffset -lt $data.Length) {
                            $audioLength = $data.Length - $audioOffset
                            $audioStream.Write($data, $audioOffset, $audioLength)
                            $script:audioBytes += $audioLength
                        }
                    }
                }
                finally { $message.Dispose() }
            }

            return
        }
        catch {
            Close-EdgeSpeechConnection
            $audioStream.SetLength($chunkStart)
            $audioStream.Position = $chunkStart
            $script:audioBytes = $audioBytesBefore
            if ($attempt -ge 2) { throw }
        }
    }
}

function Invoke-EdgeSpeechRequest(
    [string]$text,
    [string]$voice,
    [string]$audioPath,
    [string]$errorPath,
    [string]$donePath) {
    try {
    if (Test-Path -LiteralPath $audioPath) { Remove-Item -LiteralPath $audioPath -Force }
    if (Test-Path -LiteralPath $errorPath) { Remove-Item -LiteralPath $errorPath -Force }
    if (Test-Path -LiteralPath $donePath) { Remove-Item -LiteralPath $donePath -Force }
    $text = [Text.RegularExpressions.Regex]::Replace(
        $text,
        '[\x00-\x08\x0B\x0C\x0E-\x1F]',
        ' ')
    $script:audioBytes = 0
    $audioStream = [IO.File]::Open(
        $audioPath,
        [IO.FileMode]::Create,
        [IO.FileAccess]::Write,
        [IO.FileShare]::Read)
    try {
        for ($start = 0; $start -lt $text.Length; $start += $length) {
            $length = [Math]::Min(1000, $text.Length - $start)
            if ($start + $length -lt $text.Length -and
                [char]::IsHighSurrogate($text[$start + $length - 1])) {
                $length--
            }
            Invoke-EdgeTtsChunk $text.Substring($start, $length) $audioStream
        }
    }
    finally { $audioStream.Dispose() }
    if ($script:audioBytes -eq 0) {
        throw '语音服务没有返回音频。'
    }
    }
    catch {
        try {
            [IO.File]::WriteAllText(
                $errorPath,
                $_.Exception.Message,
                [Text.UTF8Encoding]::new($false))
        }
        catch {}
    }
    finally {
        try {
            [IO.File]::WriteAllText(
                $donePath,
                '1',
                [Text.UTF8Encoding]::new($false))
        }
        catch {}
    }
}

if (Test-Path -LiteralPath $readyPath) { Remove-Item -LiteralPath $readyPath -Force }
$script:edgeConnection = $null
try { Open-EdgeSpeechConnection } catch { Close-EdgeSpeechConnection }
[IO.File]::WriteAllText($readyPath, '1', [Text.UTF8Encoding]::new($false))

try {
    while (-not $parentProcess.HasExited) {
        if (Test-Path -LiteralPath $requestPath) {
            $audioPath = $null
            $errorPath = $null
            $donePath = $null
            try {
                $requestLines = [IO.File]::ReadAllLines(
                    $requestPath,
                    [Text.Encoding]::UTF8)
                Remove-Item -LiteralPath $requestPath -Force
                if ($requestLines.Length -ne 5) {
                    throw '语音任务格式无效。'
                }

                $text = [Text.Encoding]::UTF8.GetString(
                    [Convert]::FromBase64String($requestLines[0]))
                $voice = [Text.Encoding]::UTF8.GetString(
                    [Convert]::FromBase64String($requestLines[1]))
                $audioPath = [Text.Encoding]::UTF8.GetString(
                    [Convert]::FromBase64String($requestLines[2]))
                $errorPath = [Text.Encoding]::UTF8.GetString(
                    [Convert]::FromBase64String($requestLines[3]))
                $donePath = [Text.Encoding]::UTF8.GetString(
                    [Convert]::FromBase64String($requestLines[4]))
                Invoke-EdgeSpeechRequest $text $voice $audioPath $errorPath $donePath
            }
            catch {
                if ($errorPath) {
                    try {
                        [IO.File]::WriteAllText(
                            $errorPath,
                            $_.Exception.Message,
                            [Text.UTF8Encoding]::new($false))
                    }
                    catch {}
                }
                if ($donePath) {
                    try {
                        [IO.File]::WriteAllText(
                            $donePath,
                            '1',
                            [Text.UTF8Encoding]::new($false))
                    }
                    catch {}
                }
            }
        }

        Start-Sleep -Milliseconds 20
    }
}
finally {
    Close-EdgeSpeechConnection
    try { $parentProcess.Dispose() } catch {}
    foreach ($workerFile in @($requestPath, $requestPath + '.tmp', $readyPath)) {
        if (Test-Path -LiteralPath $workerFile) {
            Remove-Item -LiteralPath $workerFile -Force -ErrorAction SilentlyContinue
        }
    }
    if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
        Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
    }
}
)'

    script := StrReplace(script, "__REQUEST__", Base64EncodeUtf8(requestPath))
    script := StrReplace(script, "__READY__", Base64EncodeUtf8(readyPath))
    return StrReplace(script, "__PARENT_PROCESS_ID__", parentProcessId)
}


Base64EncodeUtf8(value)
{
    bufferSize := StrPut(value, "UTF-8")
    utf8Buffer := Buffer(bufferSize)
    byteCount := StrPut(value, utf8Buffer, "UTF-8") - 1
    return Base64EncodeBuffer(utf8Buffer.Ptr, byteCount)
}


Base64EncodeBuffer(dataPointer, byteCount)
{
    static CRYPT_STRING_BASE64_NOCRLF := 0x40000001
    characterCount := 0

    if !DllCall(
        "crypt32\CryptBinaryToStringW",
        "Ptr", dataPointer,
        "UInt", byteCount,
        "UInt", CRYPT_STRING_BASE64_NOCRLF,
        "Ptr", 0,
        "UIntP", &characterCount
    )
    {
        throw OSError()
    }

    encoded := Buffer(characterCount * 2, 0)

    if !DllCall(
        "crypt32\CryptBinaryToStringW",
        "Ptr", dataPointer,
        "UInt", byteCount,
        "UInt", CRYPT_STRING_BASE64_NOCRLF,
        "Ptr", encoded.Ptr,
        "UIntP", &characterCount
    )
    {
        throw OSError()
    }

    return StrGet(encoded, "UTF-16")
}


ApplyDarkTheme(guiObject, controls*)
{
    enabled := Buffer(4, 0)
    NumPut("Int", 1, enabled)

    try
    {
        result := DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "Ptr", guiObject.Hwnd,
            "Int", 20,
            "Ptr", enabled.Ptr,
            "Int", enabled.Size,
            "Int"
        )

        if result != 0
        {
            DllCall(
                "dwmapi\DwmSetWindowAttribute",
                "Ptr", guiObject.Hwnd,
                "Int", 19,
                "Ptr", enabled.Ptr,
                "Int", enabled.Size,
                "Int"
            )
        }
    }

    for control in controls
    {
        try DllCall(
            "uxtheme\SetWindowTheme",
            "Ptr", control.Hwnd,
            "Str", "DarkMode_Explorer",
            "Ptr", 0
        )
    }
}


RedrawGuiWindow(guiObject)
{
    static RDW_INVALIDATE := 0x0001
    static RDW_ERASE := 0x0004
    static RDW_ALLCHILDREN := 0x0080
    static RDW_UPDATENOW := 0x0100
    static RDW_FRAME := 0x0400

    try DllCall(
        "RedrawWindow",
        "Ptr", guiObject.Hwnd,
        "Ptr", 0,
        "Ptr", 0,
        "UInt", RDW_INVALIDATE
            | RDW_ERASE
            | RDW_ALLCHILDREN
            | RDW_UPDATENOW
            | RDW_FRAME
    )
}


ResizeResultWindow(
    resultEdit,
    pinButton,
    speakButton,
    copyButton,
    closeButton,
    guiObject,
    minMax,
    width,
    height
)
{
    if minMax = -1
        return

    resultEdit.Move(10, 10, Max(120, width - 20), Max(72, height - 56))
    pinButton.Move(10, height - 36)
    speakButton.Move(width - 214, height - 36)
    copyButton.Move(width - 142, height - 36)
    closeButton.Move(width - 62, height - 36)
    RedrawGuiWindow(guiObject)
}


class JsonParser
{
    static Parse(source)
    {
        parser := JsonParser(source)
        value := parser.ParseValue()
        parser.SkipWhitespace()

        if parser.Position <= parser.Length
            parser.Fail("JSON 根值后存在多余内容")

        return value
    }


    __New(source)
    {
        this.Source := source
        this.Position := 1
        this.Length := StrLen(source)
    }


    ParseValue()
    {
        this.SkipWhitespace()

        if this.Position > this.Length
            this.Fail("缺少 JSON 值")

        character := SubStr(this.Source, this.Position, 1)

        switch character
        {
            case "{":
                return this.ParseObject()
            case "[":
                return this.ParseArray()
            case Chr(34):
                return this.ParseString()
            case "t":
                return this.ParseLiteral("true", true)
            case "f":
                return this.ParseLiteral("false", false)
            case "n":
                return this.ParseLiteral("null", "")
            default:
                return this.ParseNumber()
        }
    }


    ParseObject()
    {
        result := Map()
        this.Position++
        this.SkipWhitespace()

        if this.Consume("}")
            return result

        loop
        {
            this.SkipWhitespace()

            if SubStr(this.Source, this.Position, 1) != Chr(34)
                this.Fail("JSON 对象键必须是字符串")

            key := this.ParseString()
            this.SkipWhitespace()
            this.Expect(":")
            result[key] := this.ParseValue()
            this.SkipWhitespace()

            if this.Consume("}")
                return result

            this.Expect(",")
        }
    }


    ParseArray()
    {
        result := []
        this.Position++
        this.SkipWhitespace()

        if this.Consume("]")
            return result

        loop
        {
            result.Push(this.ParseValue())
            this.SkipWhitespace()

            if this.Consume("]")
                return result

            this.Expect(",")
        }
    }


    ParseString()
    {
        quote := Chr(34)
        backslash := Chr(92)
        this.Expect(quote)
        result := ""

        while this.Position <= this.Length
        {
            character := SubStr(this.Source, this.Position, 1)
            this.Position++

            if character = quote
                return result

            if character != backslash
            {
                if Ord(character) < 0x20
                    this.Fail("JSON 字符串包含无效控制字符")

                result .= character
                continue
            }

            if this.Position > this.Length
                this.Fail("JSON 转义序列不完整")

            escape := SubStr(this.Source, this.Position, 1)
            this.Position++

            switch escape
            {
                case Chr(34), backslash, "/":
                    result .= escape
                case "b":
                    result .= Chr(8)
                case "f":
                    result .= Chr(12)
                case "n":
                    result .= "`n"
                case "r":
                    result .= "`r"
                case "t":
                    result .= "`t"
                case "u":
                    result .= this.ParseUnicodeEscape()
                default:
                    this.Fail("JSON 转义序列无效")
            }
        }

        this.Fail("JSON 字符串未结束")
    }


    ParseUnicodeEscape()
    {
        codePoint := this.ReadHexCodeUnit()

        if codePoint >= 0xD800 && codePoint <= 0xDBFF
        {
            if SubStr(this.Source, this.Position, 2) != Chr(92) . "u"
                this.Fail("JSON Unicode 高代理项后缺少低代理项")

            this.Position += 2
            lowSurrogate := this.ReadHexCodeUnit()

            if lowSurrogate < 0xDC00 || lowSurrogate > 0xDFFF
                this.Fail("JSON Unicode 低代理项无效")

            codePoint := 0x10000
                + ((codePoint - 0xD800) << 10)
                + (lowSurrogate - 0xDC00)
        }
        else if codePoint >= 0xDC00 && codePoint <= 0xDFFF
        {
            this.Fail("JSON Unicode 低代理项缺少高代理项")
        }

        return Chr(codePoint)
    }


    ReadHexCodeUnit()
    {
        hex := SubStr(this.Source, this.Position, 4)

        if StrLen(hex) != 4 || !RegExMatch(hex, "^[0-9A-Fa-f]{4}$")
            this.Fail("JSON Unicode 转义无效")

        this.Position += 4
        return Integer("0x" . hex)
    }


    ParseNumber()
    {
        remaining := SubStr(this.Source, this.Position)

        if !RegExMatch(
            remaining,
            "^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?",
            &match
        )
        {
            this.Fail("JSON 数值无效")
        }

        literal := match[0]
        this.Position += StrLen(literal)
        return literal + 0
    }


    ParseLiteral(literal, value)
    {
        if SubStr(this.Source, this.Position, StrLen(literal)) != literal
            this.Fail("JSON 字面量无效")

        this.Position += StrLen(literal)
        return value
    }


    SkipWhitespace()
    {
        while this.Position <= this.Length
        {
            character := SubStr(this.Source, this.Position, 1)

            if character != " "
                && character != "`t"
                && character != "`r"
                && character != "`n"
            {
                return
            }

            this.Position++
        }
    }


    Consume(expected)
    {
        if SubStr(this.Source, this.Position, 1) != expected
            return false

        this.Position++
        return true
    }


    Expect(expected)
    {
        if !this.Consume(expected)
            this.Fail("预期字符 " . expected)
    }


    Fail(message)
    {
        throw Error(message . "（位置 " . this.Position . "）")
    }
}
