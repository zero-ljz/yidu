global ResultSpeakButton := {Text: ""}
global ResultPauseButton := {Text: "", Enabled: false}
global ResultEdit := 0
global ResultPinButton := 0
global ResultCopyButton := 0
global ResultCloseButton := 0
global ResultIconButtons := Map()
global ResultPinned := false
global TestDirectory := A_Args[1]
global CONFIG_DIRECTORY := TestDirectory
global CONFIG_PATH := TestDirectory . "\YiDu.ini"
global AUTOSTART_SHORTCUT := TestDirectory . "\test-autostart.lnk"
global TestPackagedAutostart := false
global TestRestartOffers := 0
global TestPrivacyCancellations := 0
global PrivacyGui := 0
global AboutGui := 0
global TestDuringAutostart := 0
global TestSaveCancelAttempts := 0
global TestSaveCancelledBeforeCommit := false
global TestIsAdmin := true
global TestSettingsErrors := []
global TestHelpCalls := []
global IS_PACKAGED := false
global ShowResultAtMouse := true
global TestPlaybackMode := "stopped"
global TestPlaybackCount := 0
global TestPlaybackError := false
global TestMciErrorCommand := ""
global TestNotifications := []
global TestWorkerStops := 0
global TestConsent := true
global TestFirstRunCount := 0
global TestAppearanceUpdates := 0
global TestSettingsShows := []
global TestResultPositionCalls := 0
global ActiveInputDialog := 0
global InputDrafts := Map()
global TestInputClipboard := "Alpha"
global TestDraftScenario := 0
global TestVoiceScenario := ""
global TestVoiceSession := 0
global TestSelectedText := ""
global TranslationBusy := false
global ActiveTranslationRequest := 0
global TestTranslationResults := []
global TestTranslationErrors := []
global TestTranslationTransport := 0
global ResultGui := 0
global ResultView := 0
global TestInputError := ""
global TestTooltipHwnd := 0
global TestTranslateHotkeyCount := 0
global TestSpeakHotkeyCount := 0

DetectHiddenWindows(true)
OnMessage(0x002B, DrawDropDownItem)

; Keep timer callbacks out of deterministic state-transition checks.
Critical
try
{
    TestTraySettings()
    FileAppend("PASS: tray menus, saved settings and quiet startup`n", "*")
    if TestTranslationOnly
    {
        TestTranslationCancellation()
        TestTranslationLanguages()
        TestResultSpeechControls()
        FileAppend("PASS: unified translation window, icons, adaptive pane heights, height limits, paste, clear, drafts and request replacement`n", "*")
        FileAppend(BuildEdgeSpeechWorkerPowerShell("request", "ready", DllCall("GetCurrentProcessId", "UInt")),
            TestDirectory . "\worker.ps1", "UTF-8")
        ExitApp(0)
    }
    TestTrayOrganization()
    FileAppend("PASS: unified settings, drafts, persistence, rollback, consent and packaged window`n", "*")
    TestHotkeySettings()
    FileAppend("PASS: hotkey recording, live rebinding, swaps, persistence, cancellation and rollback`n", "*")
    TestInputWindows()
    FileAppend("PASS: flat voice selector, saved selection and input layout`n", "*")
    TestInputDrafts()
    FileAppend("PASS: input drafts, selection restoration and explicit dismissal`n", "*")
    TestVoiceInputPlayback()
    FileAppend("PASS: retained speech input, playback controls, background playback and reopening`n", "*")
    TestTranslationCancellation()
    FileAppend("PASS: translation cancellation, late callbacks and subsequent requests`n", "*")
    TestTranslationLanguages()
    FileAppend("PASS: explicit source and target languages for all translation services`n", "*")
    TestSplitting()
    FileAppend("PASS: splitting`n", "*")
    TestPlaybackQueue()
    FileAppend("PASS: playback queue`n", "*")
    TestSpeechPause()
    FileAppend("PASS: pause, resume, segment boundaries and paused cleanup`n", "*")
    TestResultSpeechControls()
    FileAppend("PASS: result speech controls, tray synchronization and result layout`n", "*")
    TestFailuresAndCancellation()
    FileAppend(BuildEdgeSpeechWorkerPowerShell("request", "ready", DllCall("GetCurrentProcessId", "UInt")),
        TestDirectory . "\worker.ps1", "UTF-8")
    FileAppend("PASS: splitting, playback queue, failures and cancellation`n", "*")
    ExitApp(0)
}
catch Error as testError
{
    StopSpeech()
    FileAppend("FAIL: " . testError.Message . " (line " . testError.Line . ")`n", "*")
    ExitApp(1)
}

Assert(condition, message)
{
    if !condition
        throw Error(message)
}

MenuItemPosition(menu, label)
{
    count := DllCall("GetMenuItemCount", "Ptr", menu.Handle, "Int")
    Loop count
    {
        menuTextBuffer := Buffer(512, 0)
        DllCall("GetMenuStringW", "Ptr", menu.Handle, "UInt", A_Index - 1,
            "Ptr", menuTextBuffer.Ptr, "Int", 256, "UInt", 0x400)
        if StrGet(menuTextBuffer, "UTF-16") = label
            return A_Index - 1
    }
    return -1
}

MenuItemState(menu, label)
{
    position := MenuItemPosition(menu, label)
    Assert(position >= 0, "Missing menu item: " . label)
    return DllCall("GetMenuState", "Ptr", menu.Handle, "UInt", position, "UInt", 0x400, "UInt")
}

TestTraySettings()
{
    global CONFIG, CONFIG_PATH, SPEECH_VOICES
    global TestAppearanceUpdates
    global TestFirstRunCount, TestNotifications
    global SPEECH_SPEEDS
    Assert(!CONFIG.WindowTransparency, "New default transparency")
    Assert(CONFIG.SpeechVoice = "zh-CN-XiaoyiNeural", "Default voice preserved")
    Assert(CONFIG.SpeechSpeed = 1, "Default speech speed")
    LoadConfig()
    Assert(IniRead(CONFIG_PATH, "Settings", "WindowTransparency") = "0", "New config defaults")
    Assert(IniRead(CONFIG_PATH, "Settings", "SpeechSpeed") = "1", "Default speech speed persisted")
    IniDelete(CONFIG_PATH, "Settings", "SpeechSpeed")
    LoadConfig()
    Assert(CONFIG.SpeechSpeed = 1, "Older config without speed")
    for invalidSpeed in ["fast", "3", "", "0", "-1"]
    {
        IniWrite(invalidSpeed, CONFIG_PATH, "Settings", "SpeechSpeed")
        LoadConfig()
        Assert(CONFIG.SpeechSpeed = 1, "Invalid speed falls back to normal")
    }
    IniWrite("1.5", CONFIG_PATH, "Settings", "SpeechSpeed")
    IniWrite(1, CONFIG_PATH, "Settings", "WindowTransparency")
    IniWrite("zh-HK-HiuGaaiNeural", CONFIG_PATH, "Settings", "SpeechVoice")
    IniWrite("dark", CONFIG_PATH, "Settings", "ColorTheme")
    IniWrite(1, CONFIG_PATH, "Settings", "PrivacyChoiceMade")
    LoadConfig()
    Assert(CONFIG.WindowTransparency && CONFIG.ColorTheme = "dark", "Saved appearance preserved")
    Assert(CONFIG.SpeechVoice = "zh-HK-HiuGaaiNeural", "Saved voice preserved")
    Assert(CONFIG.SpeechSpeed = 1.5, "Saved speech speed preserved")
    TestStartup()
    Assert(TestNotifications.Length = 0 && TestFirstRunCount = 0, "Existing user quiet startup")
    Assert(MenuItemState(A_TrayMenu, "停止朗读") & 3, "Idle stop item disabled")
    Assert(MenuItemState(A_TrayMenu, "暂停朗读") & 3, "Idle pause item disabled")
    Assert(MenuItemPosition(A_TrayMenu, "语音角色") = -1, "Old voice menu removed")
    Assert(MenuItemPosition(A_TrayMenu, "窗口半透明") = -1, "Transparency belongs to settings")
    SetSpeechVoice("en-US-GuyNeural")
    Assert(IniRead(CONFIG_PATH, "Settings", "SpeechVoice") = "en-US-GuyNeural", "Quick voice choice persisted")
}


AssertTrayOrganization()
{
    global CONFIG
    labels := ["翻译`t" . FormatHotkey(CONFIG.Hotkey), "朗读`t" . FormatHotkey(CONFIG.SpeakHotkey),
        "暂停朗读", "停止朗读", "", "设置", "打开数据目录", "关于译读", "", "退出"]
    Assert(DllCall("GetMenuItemCount", "Ptr", A_TrayMenu.Handle, "Int") = labels.Length, "Compact root menu")
    for index, label in labels
    {
        if label != ""
            Assert(MenuItemPosition(A_TrayMenu, label) = index - 1, "Root item order: " . label)
    }
    Assert(!DllCall("GetSubMenu", "Ptr", A_TrayMenu.Handle, "Int", 5, "Ptr"), "Settings is a direct command")
    Assert(A_TrayMenu.Default = labels[1] && A_TrayMenu.ClickCount = 1, "Default tray action remains translate")
}


DispatchSettingsCommand(menu, label)
{
    commandId := DllCall("GetMenuItemID", "Ptr", menu.Handle, "Int", MenuItemPosition(menu, label), "UInt")
    PostMessage(0x0111, commandId, 0, , "ahk_id " . A_ScriptHwnd)
    Critical "Off"
    Sleep(30)
    Critical
}

TestTrayOrganization()
{
    global CONFIG, CONFIG_PATH, IS_PACKAGED, SettingsDialog, ShowResultAtMouse
    global TestRestartOffers, TestPrivacyCancellations, TestAppearanceUpdates
    global PrivacyGui, TestDuringAutostart, TestSaveCancelAttempts, TestSaveCancelledBeforeCommit
    AssertTrayOrganization()
    DispatchSettingsCommand(A_TrayMenu, "设置")
    dialog := SettingsDialog
    Assert(IsObject(dialog) && dialog.Page = 1, "Tray opens general settings")
    for header in dialog.HeaderButtons
        Assert((ControlGetStyle(header) & 0xF) = 0xB, "Page headers retain owner drawing after showing the window")
    SelectSettingsPage(dialog, 2)
    Assert(dialog.Consent.Visible && !dialog.Transparency.Visible && !dialog.TranslationButton.Visible, "Only selected page controls are visible")
    SelectSettingsPage(dialog, 3)
    Assert(dialog.TranslationButton.Visible && !dialog.Consent.Visible, "Keyboard page replaces service controls")
    HandleSettingsPageKeyDown(0x25, 0, 0x0100, dialog.HeaderButtons[3].Hwnd)
    Assert(dialog.Page = 2, "Arrow keys navigate page headers")
    SelectSettingsPage(dialog, 1)
    transparencyProbe := Gui()
    transparencyProbe.Show("Hide w100 h100")
    ApplyWindowTransparency(transparencyProbe)
    Assert(WinGetTransparent("ahk_id " . transparencyProbe.Hwnd) = 235, "Saved transparency applied to windows")
    dialog.Transparency.Value := false
    dialog.ThemeList.Choose(3)
    beforePreview := TestAppearanceUpdates
    PreviewSettingsAppearance(dialog)
    for header in dialog.HeaderButtons
        Assert((ControlGetStyle(header) & 0xF) = 0xB, "Theme preview preserves flat page headers")
    ApplyWindowTransparency(transparencyProbe)
    Assert(WinGetTransparent("ahk_id " . transparencyProbe.Hwnd) = ""
        && CONFIG.WindowTransparency && IniRead(CONFIG_PATH, "Settings", "WindowTransparency") = "1",
        "Transparency preview updates windows without saving preference")
    Assert(GetEffectiveColorTheme() = "light" && CONFIG.ColorTheme = "dark"
        && IniRead(CONFIG_PATH, "Settings", "ColorTheme") = "dark"
        && TestAppearanceUpdates > beforePreview, "Theme preview updates windows without changing runtime preference or disk")
    dialog.ResultPosition.Value := false
    dialog.Autostart.Value := true
    dialog.Admin.Value := true
    dialog.ServiceList.Choose(2)
    dialog.SpeedList.Choose(GetSpeechSpeedIndex(2))
    dialog.Consent.Value := true
    Assert(CONFIG.ColorTheme = "dark" && !IsAutostartEnabled(), "Edits remain drafts")
    CloseSettings(dialog)
    Assert(CONFIG.ColorTheme = "dark" && !IsAutostartEnabled(), "Cancel discards all pages")
    Assert(GetEffectiveColorTheme() = "dark" && TestAppearanceUpdates > beforePreview + 1, "Cancel restores original theme on open windows")
    ApplyWindowTransparency(transparencyProbe)
    Assert(WinGetTransparent("ahk_id " . transparencyProbe.Hwnd) = 235, "Cancel restores saved transparency")
    ShowSettings()
    dialog := SettingsDialog
    dialog.ThemeList.Choose(3)
    dialog.Transparency.Value := false
    dialog.ResultPosition.Value := false
    dialog.Autostart.Value := true
    dialog.Admin.Value := true
    dialog.ServiceList.Choose(2)
    dialog.SpeedList.Choose(GetSpeechSpeedIndex(2))
    dialog.Consent.Value := true
    PrivacyGui := Gui()
    privacyHwnd := PrivacyGui.Hwnd
    TestDuringAutostart := TryCancelSettingsSave.Bind(dialog)
    Critical "Off"
    saved := SaveSettings(dialog)
    Sleep(60)
    Critical
    Assert(saved, "Save all settings")
    Assert(TestSaveCancelAttempts = 1 && !TestSaveCancelledBeforeCommit, "Window events cannot interrupt settings persistence")
    Assert(!IsObject(PrivacyGui) && !DllCall("IsWindow", "Ptr", privacyHwnd), "Saving consent closes stale first-run disclosure")
    Assert(CONFIG.ColorTheme = "light" && !CONFIG.WindowTransparency && !ShowResultAtMouse, "Appearance and position applied")
    Assert(GetEffectiveColorTheme() = "light" && !IsObject(SettingsDialog), "Saved theme remains after preview closes")
    ApplyWindowTransparency(transparencyProbe)
    Assert(WinGetTransparent("ahk_id " . transparencyProbe.Hwnd) = ""
        && IniRead(CONFIG_PATH, "Settings", "WindowTransparency") = "0", "Saved transparency remains after preview closes")
    transparencyProbe.Destroy()
    Assert(CONFIG.TranslationService = "youdao" && CONFIG.SpeechSpeed = 2 && CONFIG.OnlineServicesConsent, "Speech and service applied")
    Assert(IsAutostartEnabled() && CONFIG.RunAsAdmin && TestRestartOffers = 1, "Autostart applied and restart offered after save")
    LoadConfig()
    Assert(CONFIG.TranslationService = "youdao" && CONFIG.ColorTheme = "light" && CONFIG.RunAsAdmin, "All pages persist")
    ShowSettings(2)
    dialog := SettingsDialog
    RestoreSettingsDefaults(dialog)
    Assert(!dialog.Consent.Value && CONFIG.OnlineServicesConsent, "Default consent remains draft")
    Assert(dialog.ThemeList.Value = 3 && dialog.Admin.Value, "Restore defaults affects current page only")
    CloseSettings(dialog)
    ShowSettings()
    dialog := SettingsDialog
    dialog.Autostart.Value := false
    dialog.ThemeList.Choose(2)
    beforeFailure := FileRead(CONFIG_PATH)
    FileSetAttrib("+R", CONFIG_PATH)
    try
    {
        Assert(!SaveSettings(dialog), "Settings write failure reported")
        Assert(IsAutostartEnabled() && CONFIG.ColorTheme = "light" && FileRead(CONFIG_PATH) == beforeFailure, "Failure rolls back OS state and preserves all preferences")
    }
    finally FileSetAttrib("-R", CONFIG_PATH)
    CloseSettings(dialog)
    ShowSettings(2)
    dialog := SettingsDialog
    dialog.Consent.Value := false
    Assert(SaveSettings(dialog) && !CONFIG.OnlineServicesConsent && TestPrivacyCancellations = 1, "Revocation stops online work only after save")
    ShowSettings(2)
    dialog := SettingsDialog
    PrivacyGui := Gui()
    SetOnlineServicesConsent(true, PrivacyGui)
    Assert(CONFIG.OnlineServicesConsent && dialog.Consent.Value, "First-run choice updates an open settings draft")
    CloseSettings(dialog)
    PrivacyGui := Gui()
    SetOnlineServicesConsent(false, PrivacyGui)
    IS_PACKAGED := true
    try
    {
        SetupTrayMenu()
        AssertTrayOrganization()
        ShowSettings()
        dialog := SettingsDialog
        Assert(!IsObject(dialog.Admin), "Packaged settings omit administrator option")
        dialog.Autostart.Value := true
        Assert(SaveSettings(dialog) && IsAutostartEnabled(), "Packaged autostart saves")
        SetAutostartEnabled(false)
    }
    finally
    {
        if IsObject(SettingsDialog)
            CloseSettings(SettingsDialog)
        IS_PACKAGED := false
        SetAutostartEnabled(false)
        CONFIG.RunAsAdmin := false
        WriteConfigSetting("RunAsAdmin", 0)
        SetupTrayMenu()
    }
}


TryCancelSettingsSave(dialog, *)
{
    global SettingsDialog, TestSaveCancelAttempts, TestSaveCancelledBeforeCommit
    TestSaveCancelAttempts += 1
    TestSaveCancelledBeforeCommit := IsObject(SettingsDialog)
    CloseSettings(dialog)
}


TestHotkeySettings()
{
    global CONFIG, CONFIG_PATH, SettingsDialog
    global TestTranslateHotkeyCount, TestSpeakHotkeyCount

    oldTranslation := CONFIG.Hotkey
    oldSpeech := CONFIG.SpeakHotkey
    configBefore := FileRead(CONFIG_PATH)
    CONFIG.Hotkey := "^!F7"
    CONFIG.SpeakHotkey := "^!F8"
    WriteHotkeyConfig(CONFIG.Hotkey, CONFIG.SpeakHotkey)
    SetupTrayMenu()
    SetConfiguredHotkeysEnabled(true)
    try
    {
        IniWrite("preserved", CONFIG_PATH, "Other", "Example")
        ShowSettings(3)
        dialog := SettingsDialog
        Assert(IsObject(dialog), "Settings menu opens hotkey dialog")
        ShowSettings(3)
        Assert(SettingsDialog = dialog, "Repeated open reuses hotkey dialog")
        Assert(dialog.TranslationButton.Text = FormatHotkey(CONFIG.Hotkey)
            && dialog.SpeechButton.Text = FormatHotkey(CONFIG.SpeakHotkey), "Current bindings displayed")

        StartHotkeyRecording(dialog, "Translation")
        SendRecordedHotkey("^!k")
        Assert(dialog.Recording = "" && CanonicalHotkey(dialog.TranslationHotkey) = CanonicalHotkey("^!k"), "InputHook captures full Ctrl Alt chord (recording=" . dialog.Recording . ", key=" . dialog.TranslationHotkey . ", candidate=" . dialog.Candidate . ")")
        StartHotkeyRecording(dialog, "Speech")
        SendRecordedHotkey("#!{F9}")
        Assert(dialog.Recording = "" && CanonicalHotkey(dialog.SpeechHotkey) = CanonicalHotkey("#!F9"), "InputHook captures Win chord")
        StartHotkeyRecording(dialog, "Translation")
        SendRecordedHotkey("{Escape}")
        Assert(dialog.Recording = "" && SettingsDialog = dialog
            && CanonicalHotkey(dialog.TranslationHotkey) = CanonicalHotkey("^!k"), "Escape cancels capture without closing or changing binding")
        StartHotkeyRecording(dialog, "Speech")
        HandleSettingsActivation(0, 0, 0x0006, dialog.Gui.Hwnd)
        Assert(dialog.Recording = "" && !IsObject(dialog.Hook), "Deactivation releases keyboard capture")
        Assert(TestTranslateHotkeyCount = 0 && TestSpeakHotkeyCount = 0, "Recording does not run actions")

        StartHotkeyRecording(dialog, "Translation")
        SendRecordedHotkey("{Backspace}")
        Assert(dialog.TranslationHotkey = "" && !SaveSettings(dialog), "Empty binding rejected")
        dialog.TranslationHotkey := "^!F9"
        dialog.SpeechHotkey := "!^f9"
        Assert(!SaveSettings(dialog) && InStr(dialog.ErrorText.Text, "相同"), "Modifier order and case do not bypass duplicate validation")
        dialog.SpeechHotkey := "ordinary-key-does-not-exist"
        Assert(!SaveSettings(dialog), "Invalid key rejected")
        dialog.SpeechHotkey := "a"
        Assert(!SaveSettings(dialog), "Plain typing key rejected")
        Assert(CONFIG.Hotkey = "^!F7" && CONFIG.SpeakHotkey = "^!F8"
            && IniRead(CONFIG_PATH, "Settings", "Hotkey") = "^!F7", "Validation failures preserve runtime and disk settings")

        dialog.SpeechHotkey := "^!F10"
        Assert(SaveSettings(dialog) && !IsObject(SettingsDialog), "Save applies and closes window")
        Assert(CONFIG.Hotkey = "^!F9" && CONFIG.SpeakHotkey = "^!F10", "Saved shortcuts immediately active")
        Assert(IniRead(CONFIG_PATH, "Settings", "SpeakHotkey") = "^!F10"
            && IniRead(CONFIG_PATH, "Other", "Example") = "preserved", "Both shortcuts persisted without losing other settings")
        Assert(MenuItemPosition(A_TrayMenu, "翻译`t" . FormatHotkey(CONFIG.Hotkey)) = 0
            && InStr(A_IconTip, FormatHotkey(CONFIG.SpeakHotkey)), "Tray labels and tooltip updated")
        TriggerTestHotkeys("^!{F9}^!{F10}")
        Assert(TestTranslateHotkeyCount = 1 && TestSpeakHotkeyCount = 1, "New shortcuts dispatch correct live actions (translate=" . TestTranslateHotkeyCount . ", speech=" . TestSpeakHotkeyCount . ")")

        ApplyHotkeySettings("^!F11", "^!F12")
        TriggerTestHotkeys("^!{F9}^!{F10}")
        Assert(TestTranslateHotkeyCount = 1 && TestSpeakHotkeyCount = 1, "Old bindings are disabled")
        ApplyHotkeySettings("^!F12", "^!F11")
        TriggerTestHotkeys("^!{F12}")
        Assert(TestTranslateHotkeyCount = 2 && TestSpeakHotkeyCount = 1, "Swapping bindings preserves translation action")
        TriggerTestHotkeys("^!{F11}")
        Assert(TestSpeakHotkeyCount = 2, "Swapping bindings preserves speech action")

        ShowSettings(3)
        dialog := SettingsDialog
        RestoreHotkeyDefaults(dialog)
        Assert(dialog.TranslationHotkey = "^F1" && dialog.SpeechHotkey = "^F2"
            && CONFIG.Hotkey = "^!F12", "Restore defaults stays pending until save")
        CloseSettings(dialog)
        Assert(CONFIG.Hotkey = "^!F12" && IniRead(CONFIG_PATH, "Settings", "Hotkey") = "^!F12", "Cancel discards pending defaults")

        ShowSettings(3)
        dialog := SettingsDialog
        dialog.TranslationHotkey := "^!F13"
        dialog.SpeechHotkey := "^!F14"
        beforeFailure := FileRead(CONFIG_PATH)
        FileSetAttrib("+R", CONFIG_PATH)
        try
        {
            Assert(!SaveSettings(dialog) && SettingsDialog = dialog, "Write failure keeps settings window open")
            Assert(CONFIG.Hotkey = "^!F12" && CONFIG.SpeakHotkey = "^!F11"
                && FileRead(CONFIG_PATH) == beforeFailure, "Write failure rolls back runtime and file")
            temporaryPath := CONFIG_PATH . ".settings." . DllCall("GetCurrentProcessId", "UInt") . ".tmp"
            Assert(!FileExist(temporaryPath), "Failed save cleans temporary file")
        }
        finally FileSetAttrib("-R", CONFIG_PATH)
        CloseSettings(dialog)
        TriggerTestHotkeys("^!{F13}^!{F14}")
        Assert(TestTranslateHotkeyCount = 2 && TestSpeakHotkeyCount = 2, "Failed save leaves no new active bindings")
        TriggerTestHotkeys("^!{F12}^!{F11}")
        Assert(TestTranslateHotkeyCount = 3 && TestSpeakHotkeyCount = 3, "Rollback restores original callbacks after swap")
        LoadConfig()
        Assert(CONFIG.Hotkey = "^!F12" && CONFIG.SpeakHotkey = "^!F11", "Reload retains saved shortcuts")
    }
    finally
    {
        if IsObject(SettingsDialog)
            CloseSettings(SettingsDialog)
        SetConfiguredHotkeysEnabled(false)
        CONFIG.Hotkey := oldTranslation
        CONFIG.SpeakHotkey := oldSpeech
        FileSetAttrib("-R", CONFIG_PATH)
        FileDelete(CONFIG_PATH)
        FileAppend(configBefore, CONFIG_PATH, "UTF-8")
        SetupTrayMenu()
    }
}

SendRecordedHotkey(keys)
{
    SendLevel(1)
    Critical "Off"
    try
    {
        SendEvent(keys)
        ; InputHook suppresses modifier downs, so explicitly emit their matching ups.
        SendEvent("{LCtrl up}{RCtrl up}{LAlt up}{RAlt up}{LShift up}{RShift up}{LWin up}{RWin up}")
        Sleep(80)
    }
    finally
    {
        SendLevel(0)
        Critical
    }
}

TriggerTestHotkeys(keys)
{
    SendRecordedHotkey(keys)
}

TranslateFromHotkey(*)
{
    global TestTranslateHotkeyCount
    TestTranslateHotkeyCount += 1
}

SpeakFromHotkey(*)
{
    global TestSpeakHotkeyCount
    TestSpeakHotkeyCount += 1
}

TestInputWindows()
{
    global CONFIG, TestInputError, TestTooltipHwnd
    for mode in ["voice", "voice", "translation", ""]
    {
        TestInputError := ""
        TestTooltipHwnd := 0
        Critical "Off"
        result := PromptForText("Input test", "朗读", mode)
        Critical
        Assert(TestInputError = "", TestInputError)
        Assert(result = "", "Input cancellation")
        Assert(!TestTooltipHwnd || !DllCall("IsWindow", "Ptr", TestTooltipHwnd), "Tooltip cleaned up with input window")
    }
}

InspectTestInput(mode)
{
    global ActiveInputDialog, CONFIG, CONFIG_PATH, SPEECH_VOICES, SettingsDialog
    global TestInputError, TestTooltipHwnd, SPEECH_SPEEDS
    global TestDraftScenario, TestVoiceScenario
    Critical
    if !IsObject(ActiveInputDialog)
        return
    if TestVoiceScenario != ""
    {
        InspectVoicePlaybackInput()
        return
    }
    if IsObject(TestDraftScenario)
    {
        InspectDraftInput(mode)
        return
    }
    clientRect := Buffer(16, 0)
    DllCall("GetClientRect", "Ptr", ActiveInputDialog.Gui.Hwnd, "Ptr", clientRect.Ptr)
    if NumGet(clientRect, 8, "Int") < 200
        return
    try
    {
        dialog := ActiveInputDialog
        Assert(IsObject(dialog), "Input window initialized")
        Assert(!dialog.HasOwnProp("CategoryList"), "Input window has no category selector")
        Assert(!HasInputIconFont("YiDu Missing Icon Font"), "Missing icon font falls back to text")
        if dialog.IconButtons.Count
        {
            Assert(dialog.IconButtons.Count = (mode = "voice" ? 3 : 2), "Input icon buttons initialized")
            AssertInputIcon(dialog, dialog.PinButton, 0xE718, "钉住")
            AssertInputIcon(dialog, dialog.CancelButton, 0xE711, mode = "voice" ? "关闭" : "取消")
            ToggleInputPinned(dialog.State, dialog.Gui, dialog.PinButton)
            AssertInputIcon(dialog, dialog.PinButton, 0xE77A, "取消钉住")
            ToggleInputPinned(dialog.State, dialog.Gui, dialog.PinButton)
            AssertInputIcon(dialog, dialog.PinButton, 0xE718, "钉住")
        }
        if mode = "voice"
        {
            Assert(dialog.SpeedButton.Text = GetSpeechSpeedLabel(), "Saved speed restored on button")
            dialog.SelectorList.GetPos(, , &voiceWidth)
            Assert(voiceWidth = 220, "Full voice selector width restored")
            Assert(IsObject(dialog.SpeedTooltip), "Native speed tooltip created")
            TestTooltipHwnd := dialog.SpeedTooltip.Hwnd
            Assert(DllCall("IsWindow", "Ptr", TestTooltipHwnd), "Tooltip window is alive")
            Assert(StrGet(dialog.SpeedTooltip.TextBuffer, "UTF-16") = "朗读速度，点击切换", "Speed tooltip text")
            SetSpeechSpeed(0.75)
            for speed in [1, 1.25, 1.5, 2, 0.75]
            {
                buttonId := DllCall("GetDlgCtrlID", "Ptr", dialog.SpeedButton.Hwnd, "Int")
                DllCall("PostMessageW", "Ptr", dialog.Gui.Hwnd, "UInt", 0x111,
                    "UPtr", buttonId, "Ptr", dialog.SpeedButton.Hwnd)
                Critical "Off"
                Sleep(30)
                Critical
                Assert(CONFIG.SpeechSpeed = speed, "Speed button cycles and wraps")
                Assert(dialog.SpeedButton.Text = GetSpeechSpeedLabel(), "Speed button label updated")
                Assert(IniRead(CONFIG_PATH, "Settings", "SpeechSpeed") + 0 = speed, "Speed choice persisted")
                dialog.SpeedButton.GetPos(, , &buttonWidth)
                Assert(buttonWidth = 56, "Speed button width stays fixed")
            }
            SetSpeechSpeed(2)
            Assert(CONFIG.SpeechSpeed = 2 && dialog.SpeedButton.Text = "2×", "Saved speed syncs input button")
            ShowSettings(2)
            pending := SettingsDialog
            pending.SpeedList.Choose(GetSpeechSpeedIndex(1.25))
            pending.VoiceList.Choose(1)
            Assert(SaveSettings(pending), "Unified settings save with active voice input")
            Assert(dialog.SpeedButton.Text = "1.25×" && dialog.SelectorList.Value = 1, "Settings update active voice and speed controls")
            savedIndex := GetSpeechVoiceIndex(CONFIG.SpeechVoice)
            Assert(dialog.SelectorList.Value = savedIndex, "Saved voice restored")
            count := SendMessage(0x0146, , , , "ahk_id " . dialog.SelectorList.Hwnd)
            Assert(count = SPEECH_VOICES.Length, "Flat selector contains all voices")
            for index, item in SPEECH_VOICES
            {
                dialog.SelectorList.Choose(index)
                ChangeSpeechVoice(dialog.SelectorList)
                Assert(CONFIG.SpeechVoice = item.Voice, "Flat selection maps to correct voice")
                Assert(IniRead(CONFIG_PATH, "Settings", "SpeechVoice") = item.Voice, "Voice choice persisted")
            }
        }
        else
        {
            Assert(!IsObject(dialog.SpeedButton), "Other modes have no speed button")
            if mode = "translation"
            {
                dialog.SelectorList.Choose(2)
                ChangeTranslationService(dialog.SelectorList)
                Assert(CONFIG.TranslationService = "youdao", "Translation selector still works")
            }
            else
                Assert(!IsObject(dialog.SelectorList), "Plain input has no selectors")
        }

        minimumWidth := mode = "voice" ? (dialog.IconButtons.Count ? 412 : 524) : (mode = "translation" ? 300 : 360)
        if mode = "voice"
        {
            minMaxInfo := Buffer(40, 0)
            SendMessage(0x0024, 0, minMaxInfo.Ptr, , "ahk_id " . dialog.Gui.Hwnd)
            GetPhysicalWindowRect(dialog.Gui.Hwnd, , , &windowWidth)
            DllCall("GetClientRect", "Ptr", dialog.Gui.Hwnd, "Ptr", clientRect.Ptr)
            dpi := DllCall("GetDpiForWindow", "Ptr", dialog.Gui.Hwnd, "UInt")
            expectedMinimum := Round(minimumWidth * dpi / 96) + windowWidth - NumGet(clientRect, 8, "Int")
            Assert(Abs(NumGet(minMaxInfo, 24, "Int") - expectedMinimum) <= 1, "Speech window minimum allows compact row")
        }
        for size in [{Width: minimumWidth, Height: 200}, {Width: 800, Height: 380}]
        {
            ResizeInputWindow(dialog.Edit, dialog.PinButton, dialog.SelectorList,
                dialog.SpeedButton, dialog.SubmitButton, dialog.CancelButton,
                dialog.Gui, 0, size.Width, size.Height)
            AssertInputLayout(dialog, size.Width, size.Height)
            if mode = "voice" && size.Width = minimumWidth
            {
                dialog.PinButton.GetPos(&pinX, , &pinWidth)
                dialog.SelectorList.GetPos(&selectorX)
                Assert(Abs(selectorX - pinX - pinWidth - 8) <= 1, "Compact speech row removes excess pin gap")
            }
        }
    }
    catch Error as inputError
        TestInputError := inputError.Message
    finally
    {
        if IsObject(ActiveInputDialog)
            CancelTranslationInput(ActiveInputDialog.Gui)
    }
}

TestInputDrafts()
{
    global InputDrafts, TestInputClipboard
    InputDrafts.Clear()
    TestInputClipboard := "Alpha"
    RunDraftInput("translation", {Expected: "Alpha", Action: "blur"})
    Assert(!InputDrafts.Has("translation"), "Unedited translation clipboard does not become a draft")

    RunDraftInput("voice", {Expected: "Alpha", Action: "blur"})
    Assert(InputDrafts["voice"].Text == "Alpha", "Speech input retains unedited clipboard text")

    RunDraftInput("voice", {Expected: "Alpha", Text: "alpha", Selection: 2, Action: "blur"})
    Assert(InputDrafts["voice"].Text == "alpha", "Case-only edits preserved")
    SetSpeechSpeed(1.25)
    RunDraftInput("voice", {Expected: "alpha", ExpectedSelection: 2, Action: "blur"})
    Assert(InputDrafts.Has("voice"), "Restored draft remains after another blur")

    RunDraftInput("translation", {Expected: "Alpha", Text: "  draft`r`n text  ", Selection: 4, SelectionEnd: 10, Action: "blur"})
    translationText := InputDrafts["translation"].Text
    Assert(InStr(translationText, "`n") && SubStr(translationText, 1, 2) = "  ", "Whitespace preserved")
    Assert(InputDrafts["voice"].Text == "alpha", "Mode drafts are independent")
    RunDraftInput("voice", {Expected: "alpha", Text: "", Selection: 0, Action: "blur"})
    Assert(InputDrafts.Has("voice") && InputDrafts["voice"].Text = "", "Empty edited draft retained")
    RunDraftInput("voice", {Expected: "", ExpectedSelection: 0, Action: "cancel"})
    Assert(InputDrafts.Has("voice") && InputDrafts["voice"].Text = ""
        && InputDrafts.Has("translation"), "Closing voice input retains empty text and independent translation draft")

    result := RunDraftInput("translation", {Expected: translationText, ExpectedSelection: 4, ExpectedSelectionEnd: 10, Action: "submit"})
    Assert(result == Trim(translationText) && !InputDrafts.Has("translation"), "Submission clears restored draft")

    for action in ["cancel", "close", "escape"]
    {
        RunDraftInput("translation", {Expected: "Alpha", Text: "saved text", Selection: 3, Action: "blur"})
        RunDraftInput("translation", {Expected: "saved text", ExpectedSelection: 3, Action: action})
        Assert(!InputDrafts.Has("translation"), "Explicit translation dismissal clears draft: " . action)
    }
    RunDraftInput("voice", {Expected: "", Text: "pinned draft", Selection: 5, Action: "pinned"})
    Assert(InputDrafts["voice"].Text == "pinned draft", "Pinned draft retained after unpinning and blur")
    InputDrafts.Clear()
}

TestVoiceInputPlayback()
{
    global CONFIG, InputDrafts, TestVoiceSession, SpeechSession, SpeechBusy, ActiveInputDialog
    global TestSelectedText, TestVoiceScenario, TestInputError
    savedVoice := CONFIG.SpeechVoice
    savedSpeed := CONFIG.SpeechSpeed
    InputDrafts.Clear()
    try
    {
        for scenario in ["start", "reopen-playing", "reopen-paused"]
        {
            if scenario = "reopen-paused"
                ToggleSpeechPause()
            TestVoiceScenario := scenario
            TestInputError := ""
            Critical "Off"
            SpeakText(false)
            Critical
            TestVoiceScenario := ""
            Assert(TestInputError = "", TestInputError)
            Assert(!IsObject(ActiveInputDialog), "Speech input can be dismissed")
            Assert(InputDrafts["voice"].Text == "  next text  ", "Dismissal retains exact editable text")
            if scenario != "reopen-paused"
                Assert(SpeechBusy && SpeechSession = TestVoiceSession, "Closing input does not stop or restart background speech")
        }
        Assert(!SpeechBusy, "Stopped or completed speech stays stopped after input closes")
        TestSelectedText := "selected text"
        SpeakText(true)
        Assert(!IsObject(ActiveInputDialog) && SpeechSession.Chunks[1] = TestSelectedText, "Selected text starts speech without input window")
        StopSpeech()
    }
    finally
    {
        TestVoiceScenario := ""
        TestSelectedText := ""
        StopSpeech()
        if IsObject(ActiveInputDialog)
            CancelTranslationInput(ActiveInputDialog.Gui)
        InputDrafts.Clear()
        SetSpeechVoice(savedVoice)
        SetSpeechSpeed(savedSpeed)
    }
}

AssertVoiceInputControls(dialog, paused := false, busy := true)
{
    Assert(IsObject(dialog) && DllCall("IsWindow", "Ptr", dialog.Gui.Hwnd), "Speech input remains alive")
    Assert(dialog.SubmitButton.Text = (busy ? (paused ? "继续" : "暂停") : "朗读"), "Speech input primary label")
    Assert(dialog.CancelButton.Text = (busy ? "停止" : "关闭"), "Speech input secondary label")
    if dialog.IconButtons.Count
    {
        AssertInputIcon(dialog, dialog.SubmitButton, busy ? (paused ? 0xE768 : 0xE769) : 0xE995,
            busy ? (paused ? "继续" : "暂停") : "朗读")
        AssertInputIcon(dialog, dialog.CancelButton, busy ? 0xE71A : 0xE711, busy ? "停止" : "关闭")
    }
    AssertSpeechControls(paused, busy)
}


AssertInputIcon(dialog, control, glyph, label)
{
    button := dialog.IconButtons[control.Hwnd]
    Assert(button.Glyph = glyph, "Input icon follows action: " . label)
    Assert(control.Text = label, "Native accessible caption retained: " . label)
    Assert(IsObject(button.Tooltip) && StrGet(button.Tooltip.TextBuffer, "UTF-16") = label,
        "Input icon tooltip follows action: " . label)
    nativeText := Buffer(512, 0)
    toolInfo := Buffer(A_PtrSize = 8 ? 72 : 48, 0)
    NumPut("UInt", toolInfo.Size, "UInt", 0x11, toolInfo)
    NumPut("Ptr", dialog.Gui.Hwnd, "UPtr", control.Hwnd, toolInfo, 8)
    NumPut("Ptr", nativeText.Ptr, toolInfo, 8 + (3 * A_PtrSize) + 16)
    DllCall("SendMessageW", "Ptr", button.Tooltip.Hwnd, "UInt", 0x0438,
        "Ptr", 0, "Ptr", toolInfo.Ptr)
    Assert(StrGet(nativeText, "UTF-16") = label, "Native tooltip text updated: " . label)
    control.GetPos(, , &width, &height)
    Assert(width = 28 && height = 26, "Input icon dimensions stay compact and fixed")
    Assert((ControlGetStyle(control) & 0xF) = 0xB, "Native icon button uses owner drawing: " . ControlGetStyle(control))
}


DispatchInputButton(button)
{
    global ActiveInputDialog
    buttonId := DllCall("GetDlgCtrlID", "Ptr", button.Hwnd, "Int")
    PostMessage(0x0111, buttonId, button.Hwnd, , "ahk_id " . ActiveInputDialog.Gui.Hwnd)
    Critical "Off"
    Sleep(30)
    Critical
}

InspectVoicePlaybackInput()
{
    global ActiveInputDialog, TestVoiceScenario, TestVoiceSession, TestInputError
    global SpeechSession, TestPlaybackCount, TestNotifications, CONFIG
    try
    {
        dialog := ActiveInputDialog
        if TestVoiceScenario = "start"
        {
            AssertVoiceInputControls(dialog, false, false)
            dialog.Edit.Value := " "
            DispatchInputButton(dialog.SubmitButton)
            AssertVoiceInputControls(dialog, false, false)
            dialog.Edit.Value := "first text"
            DispatchInputButton(dialog.SubmitButton)
            AssertVoiceInputControls(dialog)
            Assert(dialog.Edit.Value == "first text" && !dialog.State.Confirmed, "Starting speech keeps input without submitting on later close")
            voice := SpeechSession.Voice
            rate := SpeechSession.Rate
            CompleteTestChunk()
            count := TestPlaybackCount
            dialog.Edit.Value := ""
            HandleInputKeyDown(0x0D, 0, 0x0100, dialog.Edit.Hwnd)
            AssertVoiceInputControls(dialog, true)
            dialog.Edit.Value := "  next text  "
            SetSpeechVoice("en-US-JennyNeural")
            SetSpeechSpeed(1.25)
            Assert(SpeechSession.Chunks[1] = "first text" && SpeechSession.Voice = voice && SpeechSession.Rate = rate,
                "Edits, voice and rate changes do not alter running speech")
            DispatchInputButton(dialog.SubmitButton)
            AssertVoiceInputControls(dialog)
            Assert(TestPlaybackCount = count, "Input resume does not restart playback")
            DispatchSpeechMenu("暂停朗读")
            AssertVoiceInputControls(dialog, true)
            DispatchSpeechMenu("停止朗读")
            AssertVoiceInputControls(dialog, false, false)
            Assert(dialog.Edit.Value == "  next text  ", "Tray stop preserves editable text")
            DispatchInputButton(dialog.SubmitButton)
            Assert(SpeechSession.Chunks[1] = "next text" && SpeechSession.Voice = CONFIG.SpeechVoice
                && SpeechSession.Rate = "+25%", "Next reading uses edited text, voice and speed")
            CompleteTestChunk()
            FinishTestPlayback()
            AssertVoiceInputControls(dialog, false, false)
            Assert(dialog.Edit.Value == "  next text  ", "Natural completion preserves text")

            DispatchInputButton(dialog.SubmitButton)
            TestNotifications := []
            CompleteTestChunk("", "synthetic failure")
            AssertVoiceInputControls(dialog, false, false)
            Assert(TestNotifications.Length = 1 && dialog.Edit.Value == "  next text  ", "Synthesis failure permits retry without losing text")
            DispatchInputButton(dialog.SubmitButton)
            CompleteTestChunk()
            TestVoiceSession := SpeechSession
            SendMessage(0x00B1, 3, 7, , "ahk_id " . dialog.Edit.Hwnd)
            PostMessage(0x0010, , , , "ahk_id " . dialog.Gui.Hwnd)
            Critical "Off"
            Sleep(30)
            Critical
        }
        else
        {
            paused := TestVoiceScenario = "reopen-paused"
            AssertVoiceInputControls(dialog, paused)
            Assert(dialog.Edit.Value == "  next text  " && SpeechSession = TestVoiceSession,
                "Reopening restores text and controls existing session")
            selection := Buffer(8, 0)
            SendMessage(0x00B0, selection.Ptr, selection.Ptr + 4, , "ahk_id " . dialog.Edit.Hwnd)
            Assert(NumGet(selection, 0, "UInt") = 3 && NumGet(selection, 4, "UInt") = 7, "Reopening restores selection")
            if paused
            {
                DispatchInputButton(dialog.SubmitButton)
                AssertVoiceInputControls(dialog)
                DispatchInputButton(dialog.CancelButton)
                AssertVoiceInputControls(dialog, false, false)
                DispatchInputButton(dialog.SubmitButton)
                CompleteTestChunk()
                FinishTestPlayback()
                AssertVoiceInputControls(dialog, false, false)
                DispatchInputButton(dialog.CancelButton)
            }
            else
                CloseInactiveInputWindow(dialog.Gui.Hwnd)
        }
        Assert(!IsObject(ActiveInputDialog), "Dismissal closes speech input only")
    }
    catch Error as inputError
        TestInputError := inputError.Message
    finally
    {
        if IsObject(ActiveInputDialog)
            CancelTranslationInput(ActiveInputDialog.Gui)
    }
}

GetSelectedText()
{
    global TestSelectedText
    return TestSelectedText
}

RunDraftInput(mode, scenario)
{
    global TestDraftScenario, TestInputError
    TestDraftScenario := scenario
    TestInputError := ""
    Critical "Off"
    result := PromptForText("Draft test", "提交", mode)
    Critical
    TestDraftScenario := 0
    Assert(TestInputError = "", TestInputError)
    return result
}

InspectDraftInput(mode)
{
    global ActiveInputDialog, TestDraftScenario, TestInputError
    try
    {
        dialog := ActiveInputDialog
        scenario := TestDraftScenario
        Assert(dialog.Edit.Value == scenario.Expected, "Draft text restored for " . mode)
        if scenario.HasOwnProp("ExpectedSelection")
        {
            selection := Buffer(8, 0)
            SendMessage(0x00B0, selection.Ptr, selection.Ptr + 4, , "ahk_id " . dialog.Edit.Hwnd)
            expectedEnd := scenario.HasOwnProp("ExpectedSelectionEnd") ? scenario.ExpectedSelectionEnd : scenario.ExpectedSelection
            Assert(NumGet(selection, 0, "UInt") = scenario.ExpectedSelection
                && NumGet(selection, 4, "UInt") = expectedEnd, "Caret and selection restored")
        }
        if scenario.HasOwnProp("Text")
        {
            dialog.Edit.Value := scenario.Text
            selectionEnd := scenario.HasOwnProp("SelectionEnd") ? scenario.SelectionEnd : scenario.Selection
            SendMessage(0x00B1, scenario.Selection, selectionEnd, , "ahk_id " . dialog.Edit.Hwnd)
        }
        if scenario.Action = "pinned"
        {
            ToggleInputPinned(dialog.State, dialog.Gui, dialog.PinButton)
            CloseInactiveInputWindow(dialog.Gui.Hwnd)
            Assert(IsObject(ActiveInputDialog), "Pinned input survives blur")
            ToggleInputPinned(dialog.State, dialog.Gui, dialog.PinButton)
            CloseInactiveInputWindow(dialog.Gui.Hwnd + 1)
            Assert(IsObject(ActiveInputDialog), "Stale blur callback does not close a different window")
            HandleWindowActivation(1, 0, 0x0006, dialog.Gui.Hwnd)
            Assert(IsObject(ActiveInputDialog), "Activation does not close input")
        }
        if scenario.Action = "blur" || scenario.Action = "pinned"
            CloseInactiveInputWindow(dialog.Gui.Hwnd)
        else if scenario.Action = "submit"
            SubmitTextInput(dialog.State, dialog.Edit, dialog.Gui)
        else if scenario.Action = "cancel"
        {
            buttonId := DllCall("GetDlgCtrlID", "Ptr", dialog.CancelButton.Hwnd, "Int")
            PostMessage(0x0111, buttonId, dialog.CancelButton.Hwnd, , "ahk_id " . dialog.Gui.Hwnd)
        }
        else if scenario.Action = "close"
            PostMessage(0x0010, , , , "ahk_id " . dialog.Gui.Hwnd)
        else if scenario.Action = "escape"
        {
            ControlSend("{Escape}", dialog.Edit, "ahk_id " . dialog.Gui.Hwnd)
        }
        if IsObject(ActiveInputDialog)
        {
            Critical "Off"
            Sleep(40)
            Critical
        }
        Assert(!IsObject(ActiveInputDialog), "Input dismissed through " . scenario.Action)
    }
    catch Error as inputError
        TestInputError := inputError.Message
    finally
    {
        if IsObject(ActiveInputDialog)
            CancelTranslationInput(ActiveInputDialog.Gui)
    }
}

TestTranslationCancellation()
{
    global CONFIG, ActiveTranslationRequest, TranslationBusy, ResultGui
    global TestTranslationTransport, TestTranslationResults, TestTranslationErrors
    global SpeechBusy, SpeechSession
    savedService := CONFIG.TranslationService
    savedInterval := CONFIG.RequestPollIntervalMs
    CONFIG.RequestPollIntervalMs := 10
    ResultGui := TestResultWindow()
    try
    {
        for service in ["google", "youdao"]
        {
            CONFIG.TranslationService := service
            for abortThrows in [false, true]
            {
                TestTranslationTransport := TestTranslationHttp(abortThrows)
                TranslationBusy := true
                StartTranslationRequest("pending", "en")
                Assert(IsObject(ActiveTranslationRequest) && !ResultGui.Hidden, "Pending translation shown")
                TestTranslationTransport.Completed := true
                resultCount := TestTranslationResults.Length
                HideResultWindow()
                Assert(!TranslationBusy && !IsObject(ActiveTranslationRequest), "Cancellation clears request and busy state")
                Assert(TestTranslationTransport.Aborts = 1 && ResultGui.Hidden, "Close aborts transport and hides result")
                Assert(TestTranslationTransport.DetachedOnAbort, "State detached before transport abort")
                CheckTranslationRequest()
                Critical "Off"
                Sleep(40)
                Critical
                Assert(TestTranslationTransport.Reads = 0, "Cancelled transport no longer polled")
                Assert(TestTranslationResults.Length = resultCount && TestTranslationErrors.Length = 0
                    && ResultGui.Hidden, "Late completion cannot reopen result or error")
            }
        }

        TestTranslationTransport := TestTranslationHttp()
        TranslationBusy := true
        StartTranslationRequest("new request", "en")
        Assert(IsObject(ActiveTranslationRequest), "New request starts after cancellation")
        TestTranslationTransport.Completed := true
        CheckTranslationRequest()
        Assert(!TranslationBusy && !IsObject(ActiveTranslationRequest), "New request finishes normally")
        Assert(TestTranslationResults[-1] = "translated", "New result delivered")
        StartTestSpeech()
        session := SpeechSession
        HideResultWindow()
        Assert(ResultGui.Hidden && TestTranslationTransport.Aborts = 0, "Closing completed result only hides it")
        Assert(SpeechBusy && SpeechSession = session, "Closing result preserves speech session")
        StopSpeech()
    }
    finally
    {
        CancelTranslationRequest()
        CONFIG.TranslationService := savedService
        CONFIG.RequestPollIntervalMs := savedInterval
        ResultGui := 0
    }
}

class TestTranslationHttp
{
    Aborts := 0
    Reads := 0
    Completed := false
    DetachedOnAbort := false
    __New(abortThrows := false)
    {
        this.AbortThrows := abortThrows
    }
    readyState
    {
        get
        {
            this.Reads++
            return this.Completed ? 4 : 1
        }
    }
    WaitForResponse(*)
    {
        this.Reads++
        return this.Completed
    }
    Abort()
    {
        global ActiveTranslationRequest, TranslationBusy
        this.Aborts++
        this.DetachedOnAbort := !IsObject(ActiveTranslationRequest) && !TranslationBusy
        if this.AbortThrows
            throw Error("Synthetic abort failure")
    }
}

class TestResultWindow
{
    Hidden := true
    Hide()
    {
        this.Hidden := true
    }
}

SplitTranslationText(text)
{
    return [text]
}

StartNextTranslationChunk(retryCurrent := false)
{
    global ActiveTranslationRequest, TestTranslationTransport, CONFIG
    ActiveTranslationRequest.ChunkIndex++
    ActiveTranslationRequest.Http := TestTranslationTransport
    ActiveTranslationRequest.StartedAt := A_TickCount
    SetTimer(CheckTranslationRequest, CONFIG.RequestPollIntervalMs)
}

ParseTranslationResponse(*)
{
    return "translated"
}

JoinTranslationResults(results)
{
    return results[1]
}

IsTimeoutError(*)
{
    return false
}

ShowTranslationResult(text, pending := false)
{
    global TestTranslationResults, ResultGui, ResultEdit, ResultSpeakButton, ResultCopyButton
    TestTranslationResults.Push(text)
    if ResultGui is Gui
        RenderTranslationResult(text, pending)
    else
        ResultGui.Hidden := false
}


TestTranslationLanguages()
{
    for service in ["tencent", "google", "youdao"]
    {
        request := BuildTranslationRequest(service, "hello & 世界", "zh", 1, 1, "ja")
        if service = "youdao"
            Assert(InStr(request.Body, "&from=ja&to=zh-CHS"), "Youdao uses explicit language pair")
        else if service = "google"
            Assert(InStr(request.Url, "&sl=ja&tl=zh-CN"), "Google uses explicit language pair")
        else
            Assert(InStr(request.Url, "source=ja&target=zh"), "Tencent uses explicit language pair")
        Assert(InStr(request.Body . request.Url, "hello%20%26%20"), "Source text encoded safely")
        request := BuildTranslationRequest(service, "hello", "en", 1, 1)
        Assert(InStr(request.Body . request.Url, service = "youdao" ? "from=Auto&to=en"
            : (service = "google" ? "sl=auto&tl=en" : "source=auto&target=en")), "Automatic source retains explicit target")
    }
    Assert(GetTranslationTargetLanguage("hello world") = "zh", "English defaults to Chinese")
    Assert(GetTranslationTargetLanguage("你好世界") = "en", "Chinese defaults to English")
}

ShowTranslationError(message)
{
    global TestTranslationErrors, ResultGui
    TestTranslationErrors.Push(message)
    if ResultGui is Gui
        RenderTranslationResult("翻译失败：`r`n" . message)
    else
        ResultGui.Hidden := false
}

AssertInputLayout(dialog, width, height)
{
    dialog.Edit.GetPos(, &editY, , &editHeight)
    controls := [dialog.PinButton]
    if IsObject(dialog.SelectorList)
        controls.Push(dialog.SelectorList)
    if IsObject(dialog.SpeedButton)
        controls.Push(dialog.SpeedButton)
    controls.Push(dialog.SubmitButton, dialog.CancelButton)
    previousRight := 0
    for control in controls
    {
        control.GetPos(&controlX, &controlY, &controlWidth, &controlHeight)
        Assert(controlX >= previousRight + 6,
            "Input row controls overlap: x=" . controlX . ", previousRight=" . previousRight . ", width=" . width)
        Assert(controlX + controlWidth <= width - 10, "Input row fits window width")
        Assert(controlY >= editY + editHeight + 6, "Input row overlaps text box")
        Assert(controlY + controlHeight <= height - 8, "Input row fits window height")
        previousRight := controlX + controlWidth
    }
}

RepeatText(text, count)
{
    result := ""
    Loop count
        result .= text
    return result
}

TestSplitting()
{
    Assert(SplitSpeechText("").Length = 0, "Empty text")
    Assert(SplitSpeechText(" `r`n`t ").Length = 0, "Whitespace text")
    for text in ["Short text.", RepeatText("字", 3000),
        RepeatText("English words. ", 200), RepeatText("字", 199) . Chr(0x1F600) . RepeatText("字", 499) . Chr(0x1F600)]
    {
        chunks := SplitSpeechText(text)
        joined := ""
        for index, chunk in chunks
        {
            Assert(StrLen(chunk) <= (index = 1 ? 200 : 500), "Chunk size limit")
            codeUnit := Ord(SubStr(chunk, 1, 1))
            Assert(codeUnit < 0xDC00 || codeUnit > 0xDFFF, "Split surrogate pair")
            joined .= chunk
        }
        Assert(joined == text, "Text lost or duplicated")
    }

    sentence := RepeatText("字", 139) . "。”"
    paragraph := RepeatText("字", 349) . "`r`n"
    chunks := SplitSpeechText(sentence . paragraph . RepeatText("字", 700))
    Assert(chunks[1] == sentence, "First chunk sentence boundary")
    Assert(chunks[2] == paragraph, "Following chunk paragraph boundary")
    chunks := SplitSpeechText(RepeatText("word ", 200))
    Assert(SubStr(chunks[1], -1) = " ", "English word boundary")
}

StartTestSpeech(length := 1000)
{
    global TestNotifications, TestPlaybackError
    StopSpeech()
    TestPlaybackError := false
    TestNotifications := []
    StartEdgeSpeech(RepeatText("字", length), "zh-CN-XiaoyiNeural")
    Assert(!(MenuItemState(A_TrayMenu, "停止朗读") & 3), "Stop item enabled during synthesis")
}

CompleteTestChunk(audio := "audio", errorMessage := "")
{
    global SpeechAudioPath, SpeechErrorPath, SpeechDonePath, SpeechWorkerRequestPath
    if FileExist(SpeechWorkerRequestPath)
        FileDelete(SpeechWorkerRequestPath)
    if audio != ""
        FileAppend(audio, SpeechAudioPath)
    if errorMessage != ""
        FileAppend(errorMessage, SpeechErrorPath, "UTF-8")
    FileAppend("1", SpeechDonePath)
    CheckSpeechSynthesis()
}

FinishTestPlayback()
{
    global TestPlaybackMode
    TestPlaybackMode := "stopped"
    CheckSpeechPlayback()
}

TestPlaybackQueue()
{
    global SpeechSession, SpeechBusy, SpeechSynthesisPending, SpeechStartedAt
    global SpeechWorkerRequestPath, TestPlaybackCount, ResultSpeakButton
    TestPlaybackCount := 0
    SetSpeechSpeed(1.5)
    StartTestSpeech()
    request := StrSplit(Trim(FileRead(SpeechWorkerRequestPath, "UTF-8")), "`n", "`r")
    Assert(request.Length = 6, "Worker request protocol")
    Assert(request[1] = Base64EncodeUtf8(SpeechSession.Chunks[1]), "First chunk payload")
    Assert(request[6] = Base64EncodeUtf8("+50%"), "First chunk uses selected speed")
    SetSpeechSpeed(2)
    Assert(SpeechSession.Rate = "+50%", "Active session keeps its starting speed")
    Assert(TestPlaybackCount = 0, "Playback before synthesis")
    CompleteTestChunk()
    firstPath := SpeechSession.PlayingChunk.AudioPath
    Assert(TestPlaybackCount = 1 && SpeechSynthesisPending, "First playback and prefetch")
    request := StrSplit(Trim(FileRead(SpeechWorkerRequestPath, "UTF-8")), "`n", "`r")
    Assert(request[6] = Base64EncodeUtf8("+50%"), "Prefetched chunk keeps session speed")
    Assert(SpeechSession.NextIndex = 3, "Exactly one prefetched chunk")
    Assert(A_TickCount - SpeechStartedAt < 1000, "Per-chunk timeout reset")
    CompleteTestChunk()
    Assert(TestPlaybackCount = 1 && IsObject(SpeechSession.ReadyChunk), "Prefetch waits for playback")
    Assert(!SpeechSynthesisPending && SpeechSession.NextIndex = 3, "Bounded prefetch")
    FinishTestPlayback()
    Assert(!FileExist(firstPath), "Played audio removed")
    Assert(TestPlaybackCount = 2 && SpeechSynthesisPending, "Second playback and third synthesis")
    FinishTestPlayback()
    Assert(SpeechBusy && !IsObject(SpeechSession.PlayingChunk), "Wait for slow synthesis")
    CompleteTestChunk()
    Assert(TestPlaybackCount = 3 && !SpeechSynthesisPending, "Resume after slow synthesis")
    FinishTestPlayback()
    Assert(!SpeechBusy && !IsObject(SpeechSession), "Final playback finishes session")
    Assert(ResultSpeakButton.Text = "朗读", "Button reset")
    Assert(MenuItemState(A_TrayMenu, "停止朗读") & 3, "Stop item disabled after completion")
    StartTestSpeech(20)
    Assert(SpeechSession.Rate = "+100%", "Next session uses changed speed")
    StopSpeech()
}

AssertSpeechControls(paused := false, busy := true)
{
    global ResultPauseButton, ResultSpeakButton, SpeechBusy, SpeechSession
    global ResultGui, ResultIconButtons
    pauseLabel := paused ? "继续朗读" : "暂停朗读"
    Assert(SpeechBusy = busy, "Speech busy state")
    Assert(!!(MenuItemState(A_TrayMenu, pauseLabel) & 3) = !busy, "Pause menu availability")
    Assert(!!(MenuItemState(A_TrayMenu, "停止朗读") & 3) = !busy, "Stop menu availability")
    Assert(ResultPauseButton.Text = (paused ? "继续" : "暂停") && ResultPauseButton.Enabled = busy, "Result pause state")
    Assert(ResultSpeakButton.Text = (busy ? "停止" : "朗读"), "Result stop state")
    if ResultIconButtons.Count
    {
        resultDialog := {Gui: ResultGui, IconButtons: ResultIconButtons}
        AssertInputIcon(resultDialog, ResultSpeakButton, busy ? 0xE71A : 0xE995, busy ? "停止" : "朗读")
        AssertInputIcon(resultDialog, ResultPauseButton, paused ? 0xE768 : 0xE769, paused ? "继续" : "暂停")
    }
    if busy
        Assert(SpeechSession.Paused = paused, "Session pause state")
}

TestSpeechPause()
{
    global SpeechSession, SpeechMciAlias, SpeechSynthesisPending, TestPlaybackCount
    global TestPlaybackMode, TestMciErrorCommand, TestNotifications

    StopSpeech()
    ToggleSpeechPause()
    AssertSpeechControls(false, false)
    StartTestSpeech()
    ToggleSpeechPause()
    AssertSpeechControls(true)
    count := TestPlaybackCount
    CompleteTestChunk()
    readyPath := SpeechSession.ReadyChunk.AudioPath
    CheckSpeechPlayback()
    QueueNextSpeechChunk()
    Assert(TestPlaybackCount = count && SpeechMciAlias = "" && FileExist(readyPath), "Pause before first audio prevents playback")
    Assert(!SpeechSynthesisPending && SpeechSession.NextIndex = 2, "Paused synthesis keeps one ready segment")
    ToggleSpeechPause()
    AssertSpeechControls()
    Assert(TestPlaybackCount = count + 1 && SpeechSynthesisPending, "Resume starts ready segment and prefetch")
    playingPath := SpeechSession.PlayingChunk.AudioPath
    alias := SpeechMciAlias
    rate := SpeechSession.Rate
    ToggleSpeechPause()
    AssertSpeechControls(true)
    Assert(TestPlaybackMode = "paused", "MCI pause sent")
    CompleteTestChunk()
    readyPath := SpeechSession.ReadyChunk.AudioPath
    CheckSpeechPlayback()
    StartReadySpeechChunk()
    Assert(FileExist(playingPath) && FileExist(readyPath) && SpeechMciAlias = alias, "Paused playback retains audio and device")
    Assert(TestPlaybackCount = count + 1 && SpeechSession.NextIndex = 3, "Prefetch cannot advance during pause")
    SetSpeechSpeed(0.75)
    for attempt in [1, 2, 3]
    {
        ToggleSpeechPause()
        AssertSpeechControls()
        Assert(TestPlaybackMode = "playing" && SpeechMciAlias = alias
            && SpeechSession.PlayingChunk.AudioPath = playingPath, "Resume keeps current segment and device")
        Assert(TestPlaybackCount = count + 1 && SpeechSession.Rate = rate, "Resume does not restart or change session rate")
        ToggleSpeechPause()
    }
    StopSpeech()
    AssertSpeechControls(false, false)
    Assert(!FileExist(playingPath) && !FileExist(readyPath), "Stop while paused cleans current and prefetched audio")

    StartTestSpeech()
    CompleteTestChunk()
    FinishTestPlayback()
    Assert(SpeechMciAlias = "" && SpeechSynthesisPending, "Waiting at segment boundary")
    ToggleSpeechPause()
    count := TestPlaybackCount
    CompleteTestChunk()
    AssertSpeechControls(true)
    Assert(TestPlaybackCount = count, "Boundary pause holds next segment")
    ToggleSpeechPause()
    Assert(TestPlaybackCount = count + 1 && SpeechSynthesisPending, "Boundary resume starts next segment")
    StopSpeech()

    StartTestSpeech()
    CompleteTestChunk()
    CompleteTestChunk()
    playingPath := SpeechSession.PlayingChunk.AudioPath
    TestPlaybackMode := "stopped"
    count := TestPlaybackCount
    ToggleSpeechPause()
    CheckSpeechPlayback()
    AssertSpeechControls(true)
    Assert(FileExist(playingPath), "Pause at completed segment retains queue until resumed")
    ToggleSpeechPause()
    Assert(!FileExist(playingPath) && TestPlaybackCount = count + 1, "Resume advances completed segment exactly once")
    StopSpeech()

    StartTestSpeech(20)
    ToggleSpeechPause()
    ToggleSpeechPause()
    CompleteTestChunk()
    ToggleSpeechPause()
    ToggleSpeechPause()
    FinishTestPlayback()
    AssertSpeechControls(false, false)

    StartTestSpeech(20)
    ToggleSpeechPause()
    CompleteTestChunk()
    readyPath := SpeechSession.ReadyChunk.AudioPath
    StartEdgeSpeech("replacement", "en-US-JennyNeural")
    AssertSpeechControls()
    Assert(!FileExist(readyPath), "Replacement clears paused audio")
    StopSpeech()

    for failedCommand in ["pause ", "resume "]
    {
        StartTestSpeech()
        CompleteTestChunk()
        playingPath := SpeechSession.PlayingChunk.AudioPath
        if failedCommand = "resume "
            ToggleSpeechPause()
        TestMciErrorCommand := failedCommand
        ToggleSpeechPause()
        TestMciErrorCommand := ""
        AssertSpeechControls(false, false)
        Assert(TestNotifications.Length = 1 && !FileExist(playingPath), "Pause or resume failure reports error and cleans audio")
    }
}

DispatchSpeechMenu(label)
{
    commandId := DllCall("GetMenuItemID", "Ptr", A_TrayMenu.Handle,
        "Int", MenuItemPosition(A_TrayMenu, label), "UInt")
    PostMessage(0x0111, commandId, 0, , "ahk_id " . A_ScriptHwnd)
    Critical "Off"
    Sleep(30)
    Critical
}

DispatchResultButton(button)
{
    global ResultGui
    buttonId := DllCall("GetDlgCtrlID", "Ptr", button.Hwnd, "Int")
    PostMessage(0x0111, buttonId, button.Hwnd, , "ahk_id " . ResultGui.Hwnd)
    Critical "Off"
    Sleep(30)
    Critical
}

TestResultSpeechControls()
{
    global ResultGui, ResultEdit, ResultPinButton, ResultPauseButton, ResultSpeakButton
    global ResultCopyButton, ResultCloseButton, SpeechSession, SpeechMciAlias
    global ResultIconButtons, ResultPinned, ResultView, TestResultPositionCalls

    savedClipboard := ClipboardAll()
    tooltipWindows := []
    A_Clipboard := "initial original"
    TranslateFromTray()
    try
    {
        Assert(ResultView.SourceEdit.Value = "initial original" && ResultView.Expanded,
            "First opening creates unified window and prefills clipboard")
        Assert(TestResultPositionCalls = 0, "First tray opening uses the default position instead of the mouse")
        Assert(!ResultCopyButton.Enabled && !ResultSpeakButton.Enabled, "New window has no result actions")
        Assert(!ResultEdit.Visible && !ResultView.ResultLabel.Visible && !ResultCopyButton.Visible
            && !ResultSpeakButton.Visible && !ResultPauseButton.Visible, "New window hides empty result and related actions")
        ResultGui.GetClientPos(, , , &emptyHeight)
        Assert(emptyHeight = 192, "New window has no unused result area")
        TestTranslationEmptyLayout()
        TestSettingsOpening()
        TestAppearanceSwitching()
        FileAppend("PASS: dark/light preview, native title bars, readable checkbox painting and settings rollback`n", "*")
        TestTranslationWindowActivation()
        FileAppend("PASS: translation blur hiding, pinning, owned popups and retained drafts; settings ready before showing`n", "*")
        ResultGui.Show("Hide w560 h480")
        TestUnifiedTranslationWindow()
        resultDialog := {Gui: ResultGui, IconButtons: ResultIconButtons}
        for hwnd, button in ResultIconButtons
            tooltipWindows.Push(button.Tooltip.Hwnd)
        if ResultIconButtons.Count
        {
            Assert(ResultIconButtons.Count = 10, "Translation window initializes all ten icons")
            AssertInputIcon(resultDialog, ResultView.SwapButton, 0xE8AB, "交换语言")
            AssertInputIcon(resultDialog, ResultView.PasteButton, 0xE77F, "粘贴")
            AssertInputIcon(resultDialog, ResultView.ClearButton, 0xE74D, "清空")
            AssertInputIcon(resultDialog, ResultView.TranslateButton, 0xE72C, "翻译")
            AssertInputIcon(resultDialog, ResultPinButton, 0xE718, "钉住")
            AssertInputIcon(resultDialog, ResultCopyButton, 0xE8C8, "复制结果")
            AssertInputIcon(resultDialog, ResultCloseButton, 0xE711, "关闭")
        }
        ToggleResultPinned()
        Assert(ResultPinned, "Result pin enabled")
        if ResultIconButtons.Count
        {
            AssertInputIcon(resultDialog, ResultPinButton, 0xE77A, "取消钉住")
            Assert(ResultIconButtons[ResultPinButton.Hwnd].Selected, "Result pin highlights selected state")
        }
        ToggleResultPinned()
        Assert(!ResultPinned, "Result pin disabled")
        for size in [{Width: 520, Height: 290}, {Width: 800, Height: 600}]
        {
            ResizeResultWindow(ResultEdit, ResultPinButton, ResultPauseButton, ResultSpeakButton,
                ResultCopyButton, ResultCloseButton, ResultGui, 0, size.Width, size.Height)
            AssertInputLayout({Edit: ResultEdit, PinButton: ResultPinButton,
                SelectorList: 0, SpeedButton: ResultPauseButton,
                SubmitButton: ResultSpeakButton, CancelButton: ResultCopyButton}, size.Width, size.Height)
            ResultCopyButton.GetPos(&copyX, , &copyWidth)
            ResultCloseButton.GetPos(&closeX, &closeY, &closeWidth, &closeHeight)
            Assert(closeX >= copyX + copyWidth + 6 && closeX + closeWidth <= size.Width - 10
                && closeY + closeHeight <= size.Height - 8, "Result close button fits row")
        }
        AssertSpeechControls(false, false)
        ResultEdit.Value := "result text"
        DispatchResultButton(ResultCopyButton)
        Assert(A_Clipboard = "result text" && ResultCopyButton.Text = "已复制", "Result copy writes clipboard and confirms success")
        if ResultIconButtons.Count
            AssertInputIcon(resultDialog, ResultCopyButton, 0xE73E, "已复制")
        RestoreCopyButtonFeedback()
        Assert(ResultCopyButton.Text = "复制结果", "Result copy feedback restores caption")
        if ResultIconButtons.Count
            AssertInputIcon(resultDialog, ResultCopyButton, 0xE8C8, "复制结果")
        DispatchResultButton(ResultSpeakButton)
        AssertSpeechControls()
        CompleteTestChunk()
        alias := SpeechMciAlias
        DispatchSpeechMenu("暂停朗读")
        AssertSpeechControls(true)
        DispatchResultButton(ResultPauseButton)
        AssertSpeechControls()
        Assert(SpeechMciAlias = alias, "Result resume uses same playback device")
        DispatchResultButton(ResultPauseButton)
        AssertSpeechControls(true)
        SetupTrayMenu()
        AssertSpeechControls(true)
        DispatchSpeechMenu("继续朗读")
        AssertSpeechControls()
        DispatchResultButton(ResultPauseButton)
        DispatchResultButton(ResultSpeakButton)
        AssertSpeechControls(false, false)
        DispatchResultButton(ResultCloseButton)
        Assert(!DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd), "Result icon close hides window")
    }
    finally
    {
        StopSpeech()
        SetTimer(RestoreCopyButtonFeedback, 0)
        A_Clipboard := savedClipboard
        ResultGui.Destroy()
        for tooltipHwnd in tooltipWindows
            Assert(!DllCall("IsWindow", "Ptr", tooltipHwnd), "Result icon tooltips destroyed with window")
        ResultIconButtons := Map()
        ResultGui := 0
        ResultView := 0
        ResultEdit := 0
        ResultPinButton := 0
        ResultPauseButton := {Text: "暂停", Enabled: false}
        ResultSpeakButton := {Text: "朗读"}
        ResultCopyButton := 0
        ResultCloseButton := 0
    }
}

TestUnifiedTranslationWindow()
{
    global ResultGui, ResultView, ResultEdit, ResultSpeakButton, ResultCopyButton
    global ResultPinButton, ResultPauseButton, ResultCloseButton
    global ActiveTranslationRequest, TranslationBusy, TestTranslationTransport, CONFIG
    global TestResultPositionCalls, ShowResultAtMouse, TestSelectedText
    global ResultPinned
    savedService := CONFIG.TranslationService
    savedPosition := ShowResultAtMouse
    savedSelection := TestSelectedText
    try
    {
        ShowResultAtMouse := true
        TestTranslationAutoHeight()
        TestTranslationWidthOnlyResize()
        TestTranslationMaximizedLayout()
        TestTranslationActionAndSwap()
        for size in [{Width: 520, Height: 290}, {Width: 800, Height: 600}]
        {
            for expanded in [true, false]
            {
                ResultView.Expanded := expanded
                ResizeResultWindow(ResultEdit, ResultPinButton, ResultPauseButton, ResultSpeakButton,
                    ResultCopyButton, ResultCloseButton, ResultGui, 0, size.Width, size.Height)
                previousRight := 0
                for control in [ResultView.SourceList, ResultView.SwapButton,
                    ResultView.TargetList, ResultView.ServiceLabel, ResultView.ServiceList]
                {
                    control.GetPos(&x, , &w)
                    Assert(x >= previousRight + 4 && x + w <= size.Width - 10,
                        "Language selectors, swap and service fit without overlap")
                    previousRight := x + w
                }
                ResultView.SourceEdit.GetPos(, &sourceY, , &sourceHeight)
                ResultEdit.GetPos(, &resultY, , &resultHeight)
                Assert(resultY >= (expanded ? sourceY + sourceHeight + 30 : 100), "Original text above translation")
                Assert(resultHeight >= 60 && resultY + resultHeight <= size.Height - 46, "Translation fits above footer")
                previousRight := 0
                for control in [ResultView.ToggleButton, ResultView.ClearButton, ResultView.PasteButton, ResultView.TranslateButton]
                {
                    control.GetPos(&x, , &w)
                    Assert(x >= previousRight + 6 && x + w <= size.Width - 10, "Source action buttons fit without overlap")
                    previousRight := x + w
                }
            }
        }
        SetTranslationSourceExpanded(false)
        Assert(!ResultView.Expanded && !ResultView.SourceEdit.Visible, "Original text collapses")
        if ResultIconButtons.Count
            AssertInputIcon({Gui: ResultGui, IconButtons: ResultIconButtons}, ResultView.ToggleButton, 0xE70D, "展开原文")
        A_Clipboard := "new original`r`n第二行"
        PasteTranslationSource()
        Assert(StrReplace(ResultView.SourceEdit.Value, "`r") = StrReplace(A_Clipboard, "`r")
            && ResultView.Expanded, "Paste replaces and expands source")
        ResultView.SourceList.Choose(4) ; Japanese
        ResultView.TargetList.Choose(2) ; Chinese
        ResultView.ServiceList.Choose(2) ; Youdao
        TestTranslationTransport := TestTranslationHttp()
        ChangeTranslationOptions(ResultView.ServiceList)
        oldRequest := ActiveTranslationRequest
        Assert(oldRequest.SourceLanguage = "ja" && oldRequest.TargetLanguage = "zh"
            && oldRequest.Service = "youdao", "Window options reach request")
        ResultView.TargetList.Choose(3) ; English
        replacement := TestTranslationHttp()
        oldTransport := TestTranslationTransport
        TestTranslationTransport := replacement
        ChangeTranslationOptions(ResultView.TargetList)
        Assert(oldTransport.Aborts = 1 && ActiveTranslationRequest != oldRequest
            && ActiveTranslationRequest.TargetLanguage = "en", "Option changes replace pending request")
        ClearTranslationSource()
        Assert(replacement.Aborts = 1 && !TranslationBusy && !IsObject(ActiveTranslationRequest), "Clear cancels pending translation")
        Assert(ResultView.SourceEdit.Value = "" && ResultEdit.Value = "" && ResultView.Expanded, "Clear empties source and result")
        Assert(!ResultSpeakButton.Enabled && !ResultCopyButton.Enabled, "Empty result has no copy or speech action")
        before := replacement.Aborts
        RetranslateFromWindow()
        Assert(!IsObject(ActiveTranslationRequest) && replacement.Aborts = before, "Empty source does not submit")
        ResultView.SourceEdit.Value := "保留的原文"
        HideResultWindow()
        Assert(ResultView.SourceEdit.Value = "保留的原文", "Closing retains source draft")
        originalHwnd := ResultGui.Hwnd
        SetTranslationSourceExpanded(false)
        positionCalls := TestResultPositionCalls
        WinMove(30, 40, , , "ahk_id " . ResultGui.Hwnd)
        TranslateFromTray()
        ResultGui.GetPos(&openedX, &openedY)
        Assert(TestResultPositionCalls = positionCalls && (openedX != 30 || openedY != 40),
            "Unpinned tray reopening recenters instead of restoring dragged position or following mouse")
        HideResultWindow()
        ToggleResultPinned()
        try
        {
            WinMove(50, 60, , , "ahk_id " . ResultGui.Hwnd)
            TranslateFromTray()
            ResultGui.GetPos(&pinnedX, &pinnedY)
            Assert(pinnedX = 50 && pinnedY = 60 && TestResultPositionCalls = positionCalls,
                "Pinned tray reopening preserves the pinned position")
        }
        finally ToggleResultPinned()
        HideResultWindow()
        TranslateFromTray()
        ResultGui.GetPos(&reopenedX, &reopenedY)
        Assert(reopenedX = openedX && reopenedY = openedY,
            "Unpinning restores consistent centered tray placement")
        Assert(ResultGui.Hwnd = originalHwnd && ResultView.SourceEdit.Value = "保留的原文"
            && !ResultView.Expanded, "Reopening reuses unified window and collapsed draft")
        SetTranslationSourceExpanded(true)
        HideResultWindow()
        TestTranslationTransport := TestTranslationHttp()
        TestSelectedText := "new selection"
        TranslateText(true)
        Assert(TestResultPositionCalls = positionCalls + 1, "Selected-text translation still follows mouse positioning setting")
        Assert(ResultGui.Hwnd = originalHwnd && ResultView.SourceEdit.Value = "new selection"
            && !ResultView.Expanded && IsObject(ActiveTranslationRequest), "Selected text replaces source and translates with source collapsed")
        HideResultWindow()
        Assert(InStr(ResultEdit.Value, "翻译已取消") && !TranslationBusy, "Closing pending window replaces stale progress with cancellation status")
    }
    finally
    {
        CancelTranslationRequest()
        ShowResultAtMouse := savedPosition
        TestSelectedText := savedSelection
        SetTranslationService(savedService)
        ResultView.SourceList.Choose(1)
        ResultView.TargetList.Choose(1)
        ResultView.ServiceList.Choose(GetTranslationServiceIndex(savedService))
    }
}

TestTranslationEmptyLayout()
{
    global ResultGui, ResultView, ResultEdit, ResultPinButton, ResultCloseButton
    ResultView.SourceEdit.Value := RepeatText("Only source text is visible.`n", 100)
    FitTranslationWindow()
    ResultGui.GetClientPos(, , , &height)
    ResultView.SourceEdit.GetPos(, &sourceY, , &sourceHeight)
    Assert(height = 348 && sourceHeight = ResultView.SourceMaxHeight,
        "Source-only window grows to its content height limit")
    ResultPinButton.GetPos(, &footerY)
    Assert(footerY = sourceY + sourceHeight + 10 && !ResultEdit.Visible,
        "Source-only layout places footer immediately below original text")
    SetTranslationSourceExpanded(false)
    ResultGui.GetClientPos(, , , &height)
    Assert(height = 118 && !ResultEdit.Visible && ResultPinButton.Visible && ResultCloseButton.Visible,
        "Collapsing an empty result leaves a compact window with pin and close actions")
    ClearTranslationSource()
    ResultGui.GetClientPos(, , , &height)
    Assert(height = 192 && ResultView.SourceEdit.Visible && !ResultEdit.Visible,
        "Clearing restores the compact source editor")
    HideResultWindow()
    TranslateFromTray()
    Assert(!ResultEdit.Visible && !ResultView.ResultLabel.Visible, "Reopening blank window keeps result hidden")
    ResultView.SourceEdit.Value := "initial original"
    FitTranslationWindow()
}


TestTranslationAutoHeight()
{
    global ResultView, ResultGui, ResultEdit
    ResultView.Expanded := true
    ResultView.SourceEdit.Visible := true
    ResultView.SourceEdit.Value := "short source"
    ResultEdit.Value := "short result"
    FitTranslationWindow()
    ResultView.SourceEdit.GetPos(, , , &sourceHeight)
    ResultEdit.GetPos(, , , &resultHeight)
    ResultGui.GetClientPos(, , , &shortHeight)
    Assert(sourceHeight = ResultView.SourceMinHeight && resultHeight = ResultView.ResultMinHeight,
        "Short content uses minimum pane heights")
    Assert(shortHeight = 290, "Short content shrinks window to expanded minimum")

    ResultView.SourceEdit.Value := RepeatText("原文很长，需要换行显示。`n", 100)
    ResultEdit.Value := RepeatText("Translated content with explicit line breaks.`n", 100)
    FitTranslationWindow()
    ResultView.SourceEdit.GetPos(, , , &sourceHeight)
    ResultEdit.GetPos(, &resultY, , &resultHeight)
    ResultGui.GetClientPos(, , , &longHeight)
    preferred := GetTranslationPaneHeights(560)
    Assert(preferred.Source = ResultView.SourceMaxHeight && preferred.Result = ResultView.ResultMaxHeight,
        "Long content is capped independently for both panes")
    Assert(sourceHeight >= ResultView.SourceMinHeight && sourceHeight <= ResultView.SourceMaxHeight
        && resultHeight >= ResultView.ResultMinHeight && resultHeight <= ResultView.ResultMaxHeight,
        "Rendered pane heights respect minimum and maximum")
    Assert(longHeight > shortHeight && longHeight <= 742 && resultY + resultHeight <= longHeight - 46,
        "Window grows for content within height limit")
    SetTranslationSourceExpanded(false)
    ResultGui.GetClientPos(, , , &collapsedHeight)
    Assert(collapsedHeight < longHeight && collapsedHeight <= 514, "Collapsing source shrinks window")
    SetTranslationSourceExpanded(true)

    ResultView.SourceEdit.Value := RepeatText("Words wrap naturally. ", 18)
    narrow := MeasureTranslationEditHeight(ResultView.SourceEdit, 500, 64, 220)
    wide := MeasureTranslationEditHeight(ResultView.SourceEdit, 780, 64, 220)
    Assert(narrow > wide, "Text measurement responds to wrapping at different widths")
    ResultView.SourceEdit.Value := RepeatText("W", 500)
    Assert(MeasureTranslationEditHeight(ResultView.SourceEdit, 500, 64, 220) > 64,
        "Unbroken text contributes wrapped lines")
    ResultView.SourceEdit.Value := "short"
    ResultEdit.Value := "short"
    FitTranslationWindow()
    ResultGui.GetClientPos(, , , &height)
    Assert(height = shortHeight, "Deleting content returns window to minimum height")
}

TestSettingsOpening()
{
    global SettingsDialog, TestSettingsShows
    OnMessage(0x0018, ObserveSettingsShow)
    try
    {
        for page in [1, 2, 3]
        {
            TestSettingsShows := []
            ShowSettings(page)
            try
            {
                Assert(TestSettingsShows.Length = 1, "Settings opens with one visibility transition")
                firstShow := TestSettingsShows[1]
                Assert(firstShow.Ready, "Settings layout and appearance finish before the first visible frame")
                SettingsDialog.Gui.GetClientPos(, , &width, &height)
                Assert(firstShow.Width = width && firstShow.Height = height,
                    "Settings has its final page size before becoming visible")
            }
            finally CloseSettings(SettingsDialog)
        }
    }
    finally OnMessage(0x0018, ObserveSettingsShow, 0)
}


ObserveSettingsShow(wParam, lParam, message, hwnd)
{
    global SettingsDialog, TestSettingsShows
    if !wParam || !IsObject(SettingsDialog) || hwnd != SettingsDialog.Gui.Hwnd
        return
    SettingsDialog.Gui.GetClientPos(, , &width, &height)
    TestSettingsShows.Push({Ready: !SettingsDialog.Initializing, Width: width, Height: height})
}


TestTranslationWindowActivation()
{
    global ResultGui, ResultView, ResultEdit, ResultPinned, TranslationBusy, TestTranslationTransport
    other := Gui(, "Translation focus test")
    popup := Gui("+Owner" . ResultGui.Hwnd, "Translation owned popup test")
    OnMessage(0x0006, HandleWindowActivation)
    try
    {
        Assert(!(WinGetExStyle("ahk_id " . ResultGui.Hwnd) & 0x80),
            "Translation keeps a normal title bar and close button")
        ResultView.SourceEdit.Value := "retained source draft"
        ResultEdit.Value := "retained translation"
        OpenTranslationWindow()
        WinWaitActive("ahk_id " . ResultGui.Hwnd, , 2)
        CloseInactiveResultWindow(ResultGui.Hwnd)
        Assert(DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd), "Active translation remains visible")

        ToggleResultPinned()
        other.Show("w200 h80")
        WinWaitActive("ahk_id " . other.Hwnd, , 2)
        Critical "Off"
        Sleep(40)
        Critical
        Assert(DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd), "Pinned translation survives real focus loss")
        ToggleResultPinned()
        CloseInactiveResultWindow(ResultGui.Hwnd + 1)
        Assert(DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd), "Stale focus callbacks leave the window alone")

        OpenTranslationWindow()
        popup.Show("w200 h80")
        WinWaitActive("ahk_id " . popup.Hwnd, , 2)
        Critical "Off"
        Sleep(40)
        Critical
        Assert(DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd), "Owned popup does not dismiss translation")
        popup.Hide()

        OpenTranslationWindow()
        other.Show()
        WinWaitActive("ahk_id " . other.Hwnd, , 2)
        Critical "Off"
        Sleep(40)
        Critical
        Assert(!DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd), "Unpinned translation hides after real focus loss")
        Assert(ResultView.SourceEdit.Value = "retained source draft" && ResultEdit.Value = "retained translation",
            "Focus loss preserves source draft and completed translation")
        OpenTranslationWindow()
        Assert(ResultView.SourceEdit.Value = "retained source draft" && ResultEdit.Value = "retained translation",
            "Reopening restores both text panes")

        TestTranslationTransport := TestTranslationHttp()
        RetranslateFromWindow()
        other.Show()
        WinWaitActive("ahk_id " . other.Hwnd, , 2)
        Critical "Off"
        Sleep(40)
        Critical
        Assert(!TranslationBusy && TestTranslationTransport.Aborts = 1
            && !DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd),
            "Focus loss cancels pending translation so callbacks cannot reopen it")
    }
    finally
    {
        OnMessage(0x0006, HandleWindowActivation, 0)
        SetTimer(FitTranslationWindow, 0)
        CancelTranslationRequest()
        if ResultPinned
            ToggleResultPinned()
        popup.Destroy()
        other.Destroy()
        ResultView.SourceEdit.Value := "initial original"
        ResultEdit.Value := ""
    }
}


TestAppearanceSwitching()
{
    global CONFIG, CONFIG_PATH, SettingsDialog, ResultGui, ResultView, ResultEdit
    preferenceBefore := FileRead(CONFIG_PATH)
    ShowSettings()
    dialog := SettingsDialog
    try
    {
        for index in [2, 3, 2]
        {
            dialog.ThemeList.Choose(index)
            PreviewSettingsAppearance(dialog)
            dark := index = 2
            palette := GetAppearancePalette()
            Assert(GetUxThemeFunction(133) && GetUxThemeFunction(135), "Dark mode ordinal exports resolve")
            shouldUseDark := GetUxThemeFunction(132)
            if shouldUseDark
                Assert(!!DllCall(shouldUseDark, "UChar") = dark, "Native app theme follows explicit preview")
            allowedForWindow := GetUxThemeFunction(137)
            if allowedForWindow
                Assert(!!DllCall(allowedForWindow, "Ptr", ResultGui.Hwnd, "UChar") = dark,
                    "Existing translation window follows preview")
            for window in [dialog.Gui, ResultGui]
            {
                enabled := -1
                hr := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", window.Hwnd, "Int", 20,
                    "Int*", &enabled, "Int", 4, "Int")
                if hr = 0
                    Assert(!!enabled = dark, "Title bar follows dark and light preview")
            }
            Assert(ControlGetStyle(ResultEdit) & 0x800, "Theme preview preserves result read-only state")
            for checkbox in [dialog.Transparency, dialog.ResultPosition, dialog.Autostart, dialog.Admin]
            {
                original := checkbox.Value
                if dark
                {
                    pixels := InspectCheckboxPainting(checkbox)
                    Assert(pixels.Background = RgbToColorRef(palette.WindowBackground),
                        "Dark checkbox paints the window background")
                    Assert(pixels.LightText > 4, "Dark checkbox paints readable light text")
                }
                Assert(checkbox.Type = "CheckBox" && checkbox.Value = original,
                    "Theme switch preserves native checkbox semantics and value")
            }
            SelectSettingsPage(dialog, 2)
            if dark
                Assert(InspectCheckboxPainting(dialog.Consent).LightText > 4,
                    "Service consent checkbox has readable dark theme text")
            SelectSettingsPage(dialog, 1)
            Assert(FileRead(CONFIG_PATH) == preferenceBefore, "Theme preview does not persist settings")
        }
    }
    finally CloseSettings(dialog)
    Assert(FileRead(CONFIG_PATH) == preferenceBefore, "Closing theme preview preserves saved preferences")
}


InspectCheckboxPainting(control)
{
    ; Render the real native control into a bitmap, including its NM_CUSTOMDRAW callback.
    rect := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", control.Hwnd, "Ptr", rect)
    width := NumGet(rect, 8, "Int"), height := NumGet(rect, 12, "Int")
    dc := DllCall("user32\GetDC", "Ptr", control.Hwnd, "Ptr")
    memoryDc := DllCall("gdi32\CreateCompatibleDC", "Ptr", dc, "Ptr")
    bitmap := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", dc, "Int", width, "Int", height, "Ptr")
    oldBitmap := DllCall("gdi32\SelectObject", "Ptr", memoryDc, "Ptr", bitmap, "Ptr")
    try
    {
        DllCall("gdi32\PatBlt", "Ptr", memoryDc, "Int", 0, "Int", 0,
            "Int", width, "Int", height, "UInt", 0x00000042) ; BLACKNESS
        SendMessage(0x0318, memoryDc, 12, , "ahk_id " . control.Hwnd) ; WM_PRINTCLIENT
        lightText := 0
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", control.Hwnd, "UInt")
        startX := Round(22 * dpi / 96)
        Loop Ceil(height / 2)
        {
            y := (A_Index - 1) * 2
            Loop Floor((width - startX) / 2)
            {
                x := startX + (A_Index - 1) * 2
                color := DllCall("gdi32\GetPixel", "Ptr", memoryDc, "Int", x, "Int", y, "UInt")
                if (color & 255) > 190 && ((color >> 8) & 255) > 190 && ((color >> 16) & 255) > 190
                    lightText++
            }
        }
        return {LightText: lightText,
            Background: DllCall("gdi32\GetPixel", "Ptr", memoryDc, "Int", width - 2,
                "Int", Floor(height / 2), "UInt")}
    }
    finally
    {
        DllCall("gdi32\SelectObject", "Ptr", memoryDc, "Ptr", oldBitmap)
        DllCall("gdi32\DeleteObject", "Ptr", bitmap)
        DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
        DllCall("user32\ReleaseDC", "Ptr", control.Hwnd, "Ptr", dc)
    }
}


TestTranslationWidthOnlyResize()
{
    global ResultGui
    rect := Buffer(16, 0)
    DllCall("user32\GetWindowRect", "Ptr", ResultGui.Hwnd, "Ptr", rect)
    left := NumGet(rect, 0, "Int"), top := NumGet(rect, 4, "Int")
    right := NumGet(rect, 8, "Int"), bottom := NumGet(rect, 12, "Int")
    midX := Floor((left + right) / 2), midY := Floor((top + bottom) / 2)
    for point in [{X: midX, Y: top + 1, Hit: 18}, {X: midX, Y: bottom - 1, Hit: 18},
        {X: left + 1, Y: midY, Hit: 10}, {X: right - 1, Y: midY, Hit: 11},
        {X: left + 1, Y: top + 1, Hit: 10}, {X: left + 1, Y: bottom - 1, Hit: 10},
        {X: right - 1, Y: top + 1, Hit: 11}, {X: right - 1, Y: bottom - 1, Hit: 11}]
    {
        coordinates := (point.X & 0xFFFF) | ((point.Y & 0xFFFF) << 16)
        hit := SendMessage(0x0084, 0, coordinates, , "ahk_id " . ResultGui.Hwnd)
        Assert(hit = point.Hit, "Native window borders expose horizontal resizing only")
    }
    Loop 8
    {
        proposed := Buffer(16, 0)
        NumPut("Int", left - 20, "Int", top - 30, "Int", right + 40, "Int", bottom + 50, proposed)
        SendMessage(0x0214, A_Index, proposed.Ptr, , "ahk_id " . ResultGui.Hwnd)
        Assert(NumGet(proposed, 4, "Int") = top && NumGet(proposed, 12, "Int") = bottom,
            "Interactive sizing keeps height and vertical position")
        Assert(NumGet(proposed, 0, "Int") = left - 20 && NumGet(proposed, 8, "Int") = right + 40,
            "Interactive sizing permits width changes")
    }
}


TestTranslationMaximizedLayout()
{
    global ResultGui, ResultView, ResultEdit, ResultPinButton, ResultPauseButton
    global ResultSpeakButton, ResultCopyButton, ResultCloseButton
    ResultView.SourceEdit.Value := "short source"
    ResultEdit.Value := "short result"
    SetTranslationSourceExpanded(true)
    try
    {
        ResultGui.Show("NA Maximize")
        Assert(DllCall("user32\IsZoomed", "Ptr", ResultGui.Hwnd), "Window maximizes")
        FitTranslationWindow()
        ResultGui.GetClientPos(, , &width, &height)
        ResultView.SourceEdit.GetPos(, &sourceY, , &sourceHeight)
        ResultEdit.GetPos(, &resultY, , &resultHeight)
        Assert(Abs(sourceHeight - resultHeight) <= 1, "Maximized panes share available height equally")
        Assert(sourceY + sourceHeight + 34 = resultY && resultY + resultHeight = height - 46,
            "Maximized panes fill content area down to footer")
        if height > 882
            Assert(sourceHeight > ResultView.SourceMaxHeight && resultHeight > ResultView.ResultMaxHeight,
                "Maximized panes can exceed automatic content height caps")

        monitor := DllCall("user32\MonitorFromWindow", "Ptr", ResultGui.Hwnd, "UInt", 2, "Ptr")
        info := Buffer(40, 0)
        NumPut("UInt", 40, info)
        DllCall("user32\GetMonitorInfoW", "Ptr", monitor, "Ptr", info.Ptr)
        GetPhysicalWindowRect(ResultGui.Hwnd, , , , &outerHeight)
        Assert(outerHeight >= NumGet(info, 32, "Int") - NumGet(info, 24, "Int"),
            "Maximization fills monitor work area without automatic window height cap")

        SetTranslationSourceExpanded(false)
        ResultEdit.GetPos(, &resultY, , &resultHeight)
        ResultGui.GetClientPos(, , , &height)
        Assert(DllCall("user32\IsZoomed", "Ptr", ResultGui.Hwnd)
            && resultY = 108 && resultY + resultHeight = height - 46,
            "Collapsed maximized result uses all available space")
        SetTranslationSourceExpanded(true)
        ResultView.SourceEdit.GetPos(, , , &sourceHeight)
        ResultEdit.GetPos(, , , &resultHeight)
        Assert(Abs(sourceHeight - resultHeight) <= 1, "Expanding maximized source redistributes height")
        ClearTranslationSource()
        ResultView.SourceEdit.GetPos(, &sourceY, , &sourceHeight)
        Assert(!ResultEdit.Visible && !ResultView.ResultLabel.Visible
            && sourceY + sourceHeight = height - 46,
            "Clearing maximized window hides result and lets source fill the content area")
        ResultView.SourceEdit.Value := "short source"
        ResultEdit.Value := "short result"
        FitTranslationWindow()
    }
    finally
    {
        WinRestore("ahk_id " . ResultGui.Hwnd)
        FitTranslationWindow()
    }
    ResultGui.GetClientPos(, , , &height)
    Assert(height = 290, "Restoring window returns to automatic content height")
}

TestTranslationActionAndSwap()
{
    global ResultGui, ResultView, ResultEdit, ResultIconButtons, TranslationBusy
    global ActiveTranslationRequest, TestTranslationTransport, TestTranslationErrors
    ResultView.SourceEdit.Value := "hello world"
    ResultView.SourceList.Choose(4) ; Japanese
    ResultView.TargetList.Choose(3) ; English
    TestTranslationTransport := TestTranslationHttp()
    try
    {
        ClearTranslationSource()
        ResultView.SourceEdit.Value := "hello world"
        Assert(!ResultEdit.Visible, "Original input alone keeps result hidden before submission")
        Assert(ControlGetStyle(ResultEdit) & 0x800, "Translation is read-only before submitting")
        Assert(!(ControlGetStyle(ResultView.SourceEdit) & 0x800), "Original remains editable")
        SwapTranslationLanguages()
        Assert(ResultView.SourceList.Value = 3 && ResultView.TargetList.Value = 4,
            "Swap exchanges explicit languages")
        Assert(ActiveTranslationRequest.SourceLanguage = "en" && ActiveTranslationRequest.TargetLanguage = "ja",
            "Swap submits reversed language pair")
        Assert(ResultView.TranslateButton.Enabled && ResultView.TranslateButton.Text = "取消翻译",
            "Pending translation replaces action with cancel button")
        Assert(ControlGetStyle(ResultEdit) & 0x800, "Pending translation stays read-only")
        Assert(ResultEdit.Visible && ResultView.ResultLabel.Visible && ResultCopyButton.Visible
            && ResultSpeakButton.Visible && !ResultCopyButton.Enabled && !ResultSpeakButton.Enabled,
            "Submitting reveals result area and disables unfinished result actions")
        if ResultIconButtons.Count
            AssertInputIcon({Gui: ResultGui, IconButtons: ResultIconButtons}, ResultView.TranslateButton,
                0xE71A, "取消翻译")
        TestTranslationTransport.Completed := true
        CheckTranslationRequest()
        Assert(!TranslationBusy && ResultView.TranslateButton.Enabled && ResultView.TranslateButton.Text = "翻译",
            "Completion restores translation action")
        if ResultIconButtons.Count
            AssertInputIcon({Gui: ResultGui, IconButtons: ResultIconButtons}, ResultView.TranslateButton,
                0xE72C, "翻译")
        Assert(ControlGetStyle(ResultEdit) & 0x800, "Completed translation stays read-only")
        result := ResultEdit.Value
        SendMessage(0x0102, Ord("x"), 1, , "ahk_id " . ResultEdit.Hwnd)
        Assert(ResultEdit.Value = result, "Character input cannot modify translation")

        ResultEdit.Value := RepeatText("A long previous translation.`n", 50)
        FitTranslationWindow()
        ResultEdit.GetPos(, , , &previousResultHeight)
        ResultGui.GetClientPos(, , , &previousWindowHeight)
        TestTranslationTransport := TestTranslationHttp()
        RetranslateFromWindow()
        ResultEdit.GetPos(, , , &pendingResultHeight)
        ResultGui.GetClientPos(, , , &pendingWindowHeight)
        Assert(ResultEdit.Visible && pendingResultHeight = previousResultHeight
            && pendingWindowHeight = previousWindowHeight,
            "Retranslating keeps the previous result area and window height steady")
        TestTranslationTransport.Completed := true
        CheckTranslationRequest()

        ResultView.SourceList.Choose(1)
        ResultView.TargetList.Choose(2)
        TestTranslationTransport := TestTranslationHttp()
        SwapTranslationLanguages()
        Assert(ResultView.SourceList.Value = 2 && ResultView.TargetList.Value = 3,
            "Swap resolves automatic English source to Chinese-English pair")
        oldTransport := TestTranslationTransport
        TestTranslationTransport := TestTranslationHttp()
        SwapTranslationLanguages()
        Assert(oldTransport.Aborts = 1 && ResultView.TranslateButton.Text = "取消翻译",
            "Swapping pending request cancels old transport and preserves cancel action")
        cancelledTransport := TestTranslationTransport
        DispatchResultButton(ResultView.TranslateButton)
        Assert(cancelledTransport.Aborts = 1 && !TranslationBusy && !IsObject(ActiveTranslationRequest),
            "Clicking cancel aborts active translation")
        Assert(ResultView.TranslateButton.Text = "翻译" && InStr(ResultEdit.Value, "翻译已取消")
            && DllCall("IsWindowVisible", "Ptr", ResultGui.Hwnd), "Cancel restores action and keeps window open")
        cancelledTransport.Completed := true
        CheckTranslationRequest()
        Assert(InStr(ResultEdit.Value, "翻译已取消"), "Cancelled result cannot overwrite cancellation status")
        TestTranslationTransport := TestTranslationHttp()
        DispatchResultButton(ResultView.TranslateButton)
        Assert(TranslationBusy && ResultView.TranslateButton.Text = "取消翻译",
            "Same button starts a fresh translation after cancellation")
        ClearTranslationSource()
        Assert(!TranslationBusy && ResultView.TranslateButton.Text = "翻译", "Clear restores translate action")
        Assert(ControlGetStyle(ResultEdit) & 0x800, "Clear retains read-only result")
        Assert(!ResultEdit.Visible && !ResultView.ResultLabel.Visible && !ResultCopyButton.Visible
            && !ResultSpeakButton.Visible, "Clear hides result and its actions again")

        ResultView.SourceEdit.Value := "你好世界"
        ResultView.SourceList.Choose(1)
        ResultView.TargetList.Choose(1)
        TestTranslationTransport := TestTranslationHttp()
        SwapTranslationLanguages()
        Assert(ResultView.SourceList.Value = 3 && ResultView.TargetList.Value = 2,
            "Swap resolves automatic Chinese-English direction")
        HideResultWindow()
        Assert(ResultView.TranslateButton.Enabled && ResultView.TranslateButton.Text = "翻译",
            "Closing cancels and restores action")
        Assert(ControlGetStyle(ResultEdit) & 0x800, "Cancelled translation stays read-only")

        TestTranslationTransport := TestTranslationHttp()
        RetranslateFromWindow()
        ActiveTranslationRequest.MaximumAttempts := 1
        ActiveTranslationRequest.Attempt := 1
        ActiveTranslationRequest.StartedAt := 0
        CheckTranslationRequest()
        Assert(!TranslationBusy && ResultView.TranslateButton.Enabled
            && InStr(ResultEdit.Value, "翻译失败"), "Timeout restores action and read-only error")
        Assert(ControlGetStyle(ResultEdit) & 0x800, "Failed translation stays read-only")
        TestTranslationErrors.Pop()
    }
    finally
    {
        CancelTranslationRequest()
        ResultView.SourceList.Choose(1)
        ResultView.TargetList.Choose(1)
        ResultGui.Hide()
    }
}

TestFailuresAndCancellation()
{
    global SpeechSession, SpeechBusy, SpeechSynthesisPending, SpeechStartedAt
    global SpeechWorkerProcessId, SpeechWorkerRequestPath, SpeechAudioPath
    global TestWorkerStops, TestPlaybackError, TestNotifications, TestConsent
    StartTestSpeech()
    CompleteTestChunk()
    playingPath := SpeechSession.PlayingChunk.AudioPath
    pendingPath := SpeechAudioPath
    FileAppend("partial", pendingPath)
    stopsBefore := TestWorkerStops
    StartEdgeSpeech("Replacement.", "en-US-JennyNeural")
    Assert(TestWorkerStops = stopsBefore + 1, "Replacement cancels pending worker")
    Assert(!FileExist(playingPath) && !FileExist(pendingPath), "Replacement cleanup")
    CompleteTestChunk()
    Assert(SpeechSession.Chunks.Length = 1, "Single short utterance")
    FinishTestPlayback()

    StartTestSpeech()
    CompleteTestChunk()
    playingPath := SpeechSession.PlayingChunk.AudioPath
    CompleteTestChunk()
    readyPath := SpeechSession.ReadyChunk.AudioPath
    StopSpeech()
    Assert(!FileExist(playingPath) && !FileExist(readyPath), "Stop clears ready and playing audio")

    StartTestSpeech()
    CompleteTestChunk()
    playingPath := SpeechSession.PlayingChunk.AudioPath
    CompleteTestChunk("partial", "Synthetic failure")
    Assert(!SpeechBusy && !FileExist(playingPath), "Prefetch failure stops playback")
    Assert(TestNotifications.Length = 1, "Synthesis failure notification")

    StartTestSpeech()
    SpeechStartedAt := A_TickCount - 60001
    CheckSpeechSynthesis()
    Assert(!SpeechBusy && TestNotifications.Length = 1, "Timeout cleanup")

    StartTestSpeech()
    SpeechWorkerProcessId := 0
    CheckSpeechSynthesis()
    Assert(!SpeechBusy && TestNotifications.Length = 1, "Worker exit cleanup")

    StartTestSpeech()
    CompleteTestChunk("")
    Assert(!SpeechBusy && TestNotifications.Length = 1, "Missing audio cleanup")

    StartTestSpeech()
    TestPlaybackError := true
    CompleteTestChunk()
    Assert(!SpeechBusy && TestNotifications.Length = 1, "MCI failure cleanup")

    StartTestSpeech()
    CompleteTestChunk()
    CompleteTestChunk()
    TestPlaybackError := true
    FinishTestPlayback()
    Assert(!SpeechBusy && TestNotifications.Length = 1, "Later MCI failure cleanup")

    StartTestSpeech()
    CompleteTestChunk()
    CompleteTestChunk()
    SpeechWorkerRequestPath := TestDirectory . "\missing\request"
    FinishTestPlayback()
    Assert(!SpeechBusy && TestNotifications.Length = 1, "Request submission failure cleanup")

    TestConsent := false
    StartEdgeSpeech("No consent.", "en-US-JennyNeural")
    Assert(!SpeechBusy && !SpeechSynthesisPending, "Consent respected")
    TestConsent := true

    StartTestSpeech()
    CompleteTestChunk()
    playingPath := SpeechSession.PlayingChunk.AudioPath
    commandId := DllCall("GetMenuItemID", "Ptr", A_TrayMenu.Handle,
        "Int", MenuItemPosition(A_TrayMenu, "停止朗读"), "UInt")
    Assert(DllCall("PostMessageW", "Ptr", A_ScriptHwnd, "UInt", 0x111,
        "UPtr", commandId, "Ptr", 0), "Dispatch tray stop command")
    Critical "Off"
    Sleep(50)
    Critical
    Assert(!SpeechBusy && !FileExist(playingPath), "Tray stop callback cancels playback and prefetch")
    Assert(MenuItemState(A_TrayMenu, "停止朗读") & 3, "Tray stop callback disables item")
}

QuoteCommandArgument(value)
{
    return Chr(34) . value . Chr(34)
}

SpeakFromTray(*)
{
}

IsAutostartEnabled()
{
    global AUTOSTART_SHORTCUT, IS_PACKAGED, TestPackagedAutostart
    global TestDuringAutostart
    if IsObject(TestDuringAutostart)
    {
        callback := TestDuringAutostart
        TestDuringAutostart := 0
        SetTimer(callback, -1)
        Sleep(50)
    }
    return IS_PACKAGED ? TestPackagedAutostart : FileExist(AUTOSTART_SHORTCUT) != ""
}

CreateAutostartShortcut()
{
    global AUTOSTART_SHORTCUT
    FileAppend("test", AUTOSTART_SHORTCUT)
}

SetPackagedAutostart(enabled)
{
    global TestPackagedAutostart
    TestPackagedAutostart := enabled
}

TestSettingsMessage(message, *)
{
    global TestSettingsErrors
    TestSettingsErrors.Push(message)
}

OfferSettingsRestart(runAsAdmin)
{
    global TestRestartOffers
    TestRestartOffers += 1
}

CancelActiveOnlineOperations()
{
    global TestPrivacyCancellations
    TestPrivacyCancellations += 1
}


PositionResultWindowAtMouse()
{
    global TestResultPositionCalls
    TestResultPositionCalls += 1
}

MoveWindowPhysical(*)
{
}

ShowAboutDialog(*)
{
    global TestHelpCalls
    TestHelpCalls.Push("about")
}

OpenOnlineServicesPrivacyDialog(firstRun)
{
    global TestFirstRunCount
    Assert(firstRun, "First-run dialog argument")
    TestFirstRunCount += 1
}

ApplyAppearanceToOpenWindows()
{
    global TestAppearanceUpdates
    TestAppearanceUpdates += 1
    RenderAppearanceToOpenWindows()
}

EnsureOnlineServicesConsent()
{
    global TestConsent
    return TestConsent
}

EnsureSpeechWorker(*)
{
    global SpeechWorkerProcessId, SpeechWorkerRequestPath, TestDirectory
    SpeechWorkerProcessId := DllCall("GetCurrentProcessId", "UInt")
    SpeechWorkerRequestPath := TestDirectory . "\request"
    return true
}

StopSpeechWorker(*)
{
    global SpeechWorkerProcessId, SpeechWorkerRequestPath, TestWorkerStops
    TestWorkerStops += 1
    SpeechWorkerProcessId := 0
    for path in [SpeechWorkerRequestPath, SpeechWorkerRequestPath . ".tmp"]
    {
        if FileExist(path)
            FileDelete(path)
    }
}

MciSend(command)
{
    global TestPlaybackMode, TestPlaybackCount, TestPlaybackError
    global TestMciErrorCommand
    if TestMciErrorCommand != "" && SubStr(command, 1, StrLen(TestMciErrorCommand)) = TestMciErrorCommand
        return 1
    if SubStr(command, 1, 5) = "open " && TestPlaybackError
        return 1
    if SubStr(command, 1, 5) = "play "
    {
        TestPlaybackMode := "playing"
        TestPlaybackCount += 1
    }
    if SubStr(command, 1, 6) = "pause "
        TestPlaybackMode := "paused"
    if SubStr(command, 1, 7) = "resume "
        TestPlaybackMode := "playing"
    if SubStr(command, 1, 6) = "close " || SubStr(command, 1, 5) = "stop "
        TestPlaybackMode := "stopped"
    return 0
}

MciGetMode(alias)
{
    global TestPlaybackMode
    return TestPlaybackMode
}

GetMciErrorMessage(code)
{
    return "Synthetic MCI failure"
}

TestTrayTip(message, *)
{
    global TestNotifications
    TestNotifications.Push(message)
}
