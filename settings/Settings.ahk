ShowSettings(page := 1, *)
{
    global CONFIG, IS_PACKAGED, SettingsDialog
    global TRANSLATION_SERVICES, SPEECH_VOICES, SPEECH_SPEEDS

    if IsObject(SettingsDialog)
    {
        SelectSettingsPage(SettingsDialog, page)
        WinActivate("ahk_id " . SettingsDialog.Gui.Hwnd)
        return
    }

    palette := GetAppearancePalette()
    window := Gui("-MinimizeBox -MaximizeBox", "译读设置")
    window.MarginX := 10
    window.MarginY := 10
    window.BackColor := palette.WindowBackground
    window.SetFont("s10 c" . palette.Text, "Microsoft YaHei UI")
    ; Native buttons retain keyboard access and accessible names; draw the flat header ourselves.
    headers := []
    knownControls := Map()
    headerX := 10
    for index, item in [{Label: "常规", Width: 56}, {Label: "翻译与朗读", Width: 104}, {Label: "快捷键", Width: 72}]
    {
        button := window.AddButton("x" . headerX . " y10 w" . item.Width . " h28", item.Label)
        headers.Push(button)
        knownControls[button.Hwnd] := true
        button.GetPos(, , &headerWidth)
        headerX += headerWidth + 8
    }
    pages := []
    window.AddText("x10 y48 w56 h26 +0x200", "主题")
    themeList := window.AddDropDownList("x74 y48 w336 +0x210", ["跟随系统", "深色", "浅色"])
    themeList.Choose(CONFIG.ColorTheme = "dark" ? 2 : CONFIG.ColorTheme = "light" ? 3 : 1)
    transparency := window.AddCheckbox("x10 y82 w400 h26", "窗口半透明")
    transparency.Value := CONFIG.WindowTransparency
    resultPosition := window.AddCheckbox("x10 y116 w400 h26", "翻译结果显示在鼠标旁")
    resultPosition.Value := CONFIG.ShowResultAtMouse
    autostart := window.AddCheckbox("x10 y150 w400 h26", "开机自启")
    autostart.Value := IsAutostartEnabled()
    admin := 0
    if !IS_PACKAGED
    {
        admin := window.AddCheckbox("x10 y184 w400 h26", "以管理员身份启动（重启后生效）")
        admin.Value := CONFIG.RunAsAdmin
    }

    pages.Push(CaptureSettingsPage(window, knownControls))
    serviceLabels := [], voiceLabels := [], speedLabels := []
    for item in TRANSLATION_SERVICES
        serviceLabels.Push(item.Label)
    for item in SPEECH_VOICES
        voiceLabels.Push(item.Label)
    for item in SPEECH_SPEEDS
        speedLabels.Push(item.Label)
    window.AddText("x10 y48 w56 h26 +0x200", "翻译服务")
    serviceList := window.AddDropDownList("x74 y48 w336 +0x210", serviceLabels)
    serviceList.Choose(GetTranslationServiceIndex(CONFIG.TranslationService))
    window.AddText("x10 y82 w56 h26 +0x200", "朗读音色")
    voiceList := window.AddDropDownList("x74 y82 w336 +0x210", voiceLabels)
    voiceList.Choose(GetSpeechVoiceIndex(CONFIG.SpeechVoice))
    window.AddText("x10 y116 w56 h26 +0x200", "朗读速度")
    speedList := window.AddDropDownList("x74 y116 w336 +0x210", speedLabels)
    speedList.Choose(GetSpeechSpeedIndex(CONFIG.SpeechSpeed))
    consent := window.AddCheckbox("x10 y150 w400 h26", "同意使用在线翻译和在线朗读")
    consent.Value := CONFIG.OnlineServicesConsent
    window.SetFont("s9 c" . palette.MutedText)
    disclosure := window.AddText("x10 y184 w400 h40", "翻译文本会发送到所选翻译服务，朗读文本会发送到 Microsoft 在线语音服务。请勿提交敏感内容。")
    privacyLink := window.AddLink("x10 y232 w400 h24", '<a href="https://yidu.iapp.run/privacy.html">查看完整隐私政策</a>')
    window.SetFont("s10 c" . palette.Text)

    pages.Push(CaptureSettingsPage(window, knownControls))
    window.AddText("x10 y48 w56 h26 +0x200", "翻译")
    translationButton := window.AddButton("x74 y48 w336 h26", FormatHotkey(CONFIG.Hotkey))
    window.AddText("x10 y82 w56 h26 +0x200", "朗读")
    speechButton := window.AddButton("x74 y82 w336 h26", FormatHotkey(CONFIG.SpeakHotkey))
    window.SetFont("s9 c" . palette.MutedText)
    hint := window.AddText("x10 y116 w400 h36", "点击按键录入；Esc 取消，Backspace 清除。`n支持 Ctrl、Alt、Shift、Win 组合键或功能键。")
    window.SetFont("s10 c" . palette.Text)
    pages.Push(CaptureSettingsPage(window, knownControls))
    errorText := window.AddText("x10 y284 w400 h40 Hidden cD84A4A", "")
    restoreButton := window.AddButton("x10 y284 w72 h26", "恢复默认")
    saveButton := window.AddButton("x274 yp w72 h26 Default", "保存")
    cancelButton := window.AddButton("x354 yp w56 h26", "取消")
    dialog := {
        Gui: window, Page: page, HeaderButtons: headers, PageControls: pages, ThemeList: themeList, Transparency: transparency,
        ResultPosition: resultPosition, Autostart: autostart, Admin: admin,
        ServiceList: serviceList, VoiceList: voiceList, SpeedList: speedList, Consent: consent,
        TranslationButton: translationButton, SpeechButton: speechButton,
        TranslationHotkey: CONFIG.Hotkey, SpeechHotkey: CONFIG.SpeakHotkey,
        ErrorText: errorText, Hint: hint, Disclosure: disclosure, RestoreButton: restoreButton,
        SaveButton: saveButton, CancelButton: cancelButton, Width: 420,
        PageBottoms: [IS_PACKAGED ? 176 : 210, 256, 152], Hook: 0, Recording: ""
    }
    translationButton.OnEvent("Click", StartHotkeyRecording.Bind(dialog, "Translation"))
    speechButton.OnEvent("Click", StartHotkeyRecording.Bind(dialog, "Speech"))
    for index, button in headers
        button.OnEvent("Click", SelectSettingsPage.Bind(dialog, index))
    themeList.OnEvent("Change", PreviewSettingsAppearance.Bind(dialog))
    transparency.OnEvent("Click", PreviewSettingsAppearance.Bind(dialog))
    restoreButton.OnEvent("Click", RestoreSettingsDefaults.Bind(dialog))
    saveButton.OnEvent("Click", SaveSettings.Bind(dialog))
    cancelButton.OnEvent("Click", CloseSettings.Bind(dialog))
    window.OnEvent("Close", CloseSettings.Bind(dialog))
    window.OnEvent("Escape", CloseSettings.Bind(dialog))
    ApplyWindowTheme(window, transparency, resultPosition, autostart, privacyLink,
        translationButton, speechButton, restoreButton, saveButton, cancelButton)
    if IsObject(admin)
        ApplyWindowTheme(window, admin)
    SettingsDialog := dialog
    ; AddButton normalizes the button type, so apply BS_OWNERDRAW after creation.
    ; Keep the native button for accessible captions, focus and keyboard activation.
    for button in headers
        DllCall(A_PtrSize = 8 ? "user32\SetWindowLongPtrW" : "user32\SetWindowLongW",
            "Ptr", button.Hwnd, "Int", -16, "Ptr", (ControlGetStyle(button) & ~0xF) | 0xB, "Ptr")
    try
    {
        SetConfiguredHotkeysEnabled(false)
        OnMessage(0x0006, HandleSettingsActivation)
        OnMessage(0x0100, HandleSettingsPageKeyDown)
        SelectSettingsPage(dialog, page)
        LayoutSettings(dialog, true)
        ApplySettingsAppearance(dialog)
    }
    catch
    {
        CloseSettings(dialog)
        throw
    }
}


PreviewSettingsAppearance(dialog, *)
{
    ApplyAppearanceToOpenWindows()
}


CaptureSettingsPage(window, knownControls)
{
    controls := []
    for control in window
    {
        if !knownControls.Has(control.Hwnd)
        {
            controls.Push(control)
            knownControls[control.Hwnd] := true
        }
    }
    return controls
}


SelectSettingsPage(dialog, page, *)
{
    StopHotkeyRecording(dialog)
    dialog.Page := page
    for index, controls in dialog.PageControls
    {
        for control in controls
            control.Visible := index = page
    }
    palette := GetAppearancePalette()
    for index, button in dialog.HeaderButtons
        button.SetFont("w" . (index = page ? 600 : 400) . " c" . palette.Text)
    LayoutSettings(dialog)
    RedrawGuiWindow(dialog.Gui)
}


HandleSettingsPageKeyDown(wParam, lParam, message, hwnd)
{
    global SettingsDialog
    if !IsObject(SettingsDialog)
        return
    dialog := SettingsDialog
    if hwnd != dialog.Gui.Hwnd && !DllCall("IsChild", "Ptr", dialog.Gui.Hwnd, "Ptr", hwnd)
        return
    page := dialog.Page
    if wParam = 0x09 && GetKeyState("Ctrl")
        page := Mod(page - 1 + (GetKeyState("Shift") ? 2 : 1), 3) + 1
    else
    {
        headerIndex := 0
        for index, button in dialog.HeaderButtons
        {
            if button.Hwnd = hwnd
                headerIndex := index
        }
        if !headerIndex
            return
        switch wParam
        {
            case 0x25: page := Mod(headerIndex + 1, 3) + 1
            case 0x27: page := Mod(headerIndex, 3) + 1
            case 0x24: page := 1
            case 0x23: page := 3
            default: return
        }
    }
    SelectSettingsPage(dialog, page)
    dialog.HeaderButtons[page].Focus()
    return 0
}


DrawSettingsPageButton(lParam)
{
    global SettingsDialog
    if !IsObject(SettingsDialog)
        return false
    hwndOffset := A_PtrSize = 8 ? 24 : 20
    controlHwnd := NumGet(lParam, hwndOffset, "Ptr")
    page := 0
    for index, control in SettingsDialog.HeaderButtons
    {
        if control.Hwnd = controlHwnd
            page := index
    }
    if !page
        return false
    control := SettingsDialog.HeaderButtons[page]
    selected := SettingsDialog.Page = page
    palette := GetAppearancePalette()
    accent := palette.DarkTitleBar ? "60A5FA" : "2563EB"
    dc := NumGet(lParam, hwndOffset + A_PtrSize, "Ptr")
    state := NumGet(lParam, 16, "UInt")
    rect := Buffer(16, 0)
    DllCall("RtlMoveMemory", "Ptr", rect, "Ptr", lParam + hwndOffset + 2 * A_PtrSize, "UPtr", 16)
    savedDC := DllCall("gdi32\SaveDC", "Ptr", dc, "Int")
    try
    {
        brush := DllCall("gdi32\CreateSolidBrush", "UInt",
            RgbToColorRef(state & 1 ? palette.SelectionBackground : palette.WindowBackground), "Ptr")
        DllCall("user32\FillRect", "Ptr", dc, "Ptr", rect, "Ptr", brush)
        DllCall("gdi32\DeleteObject", "Ptr", brush)
        font := SendMessage(0x0031, , , , "ahk_id " . controlHwnd)
        if font
            DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", font)
        DllCall("gdi32\SetBkMode", "Ptr", dc, "Int", 1)
        DllCall("gdi32\SetTextColor", "Ptr", dc, "UInt",
            RgbToColorRef(selected ? accent : palette.MutedText))
        DllCall("user32\DrawTextW", "Ptr", dc, "Str", control.Text, "Int", -1, "Ptr", rect, "UInt", 0x825)
        dpi := 96
        try dpi := DllCall("user32\GetDpiForWindow", "Ptr", controlHwnd, "UInt")
        focused := state & 0x10 && !(state & 0x200)
        if selected || focused
        {
            ; Indicate keyboard focus with the underline as well, without a button frame.
            thickness := selected ? (focused ? 3 : 2) : 1
            NumPut("Int", NumGet(rect, 12, "Int") - Max(1, Round(thickness * dpi / 96)), rect, 4)
            brush := DllCall("gdi32\CreateSolidBrush", "UInt", RgbToColorRef(accent), "Ptr")
            DllCall("user32\FillRect", "Ptr", dc, "Ptr", rect, "Ptr", brush)
            DllCall("gdi32\DeleteObject", "Ptr", brush)
        }
    }
    finally DllCall("gdi32\RestoreDC", "Ptr", dc, "Int", savedDC)
    return true
}



LayoutSettings(dialog, activate := false)
{
    ; Use the same margins, gaps and measured button sizes as input/result windows.
    margin := dialog.Gui.MarginX
    gap := 8
    actionY := dialog.PageBottoms[dialog.Page] + gap
    hasMessage := dialog.ErrorText.Text != ""
    dialog.ErrorText.Visible := hasMessage
    if hasMessage
    {
        dialog.ErrorText.Move(margin, actionY)
        dialog.ErrorText.GetPos(, , , &messageHeight)
        actionY += messageHeight + gap
    }
    dialog.SaveButton.GetPos(, , &saveWidth, &buttonHeight)
    dialog.CancelButton.GetPos(, , &cancelWidth)
    dialog.RestoreButton.Move(margin, actionY)
    dialog.SaveButton.Move(dialog.Width - margin - cancelWidth - gap - saveWidth, actionY)
    dialog.CancelButton.Move(dialog.Width - margin - cancelWidth, actionY)
    dialog.Gui.Show("w" . dialog.Width . " h" . (actionY + buttonHeight + margin) . (activate ? "" : " NA"))
}


ApplySettingsAppearance(dialog)
{
    ApplyAppearanceToExistingWindow(dialog.Gui)
    for control in [dialog.ThemeList, dialog.ServiceList, dialog.VoiceList, dialog.SpeedList]
    {
        ApplyDropDownTheme(control)
        MatchDropDownHeight(dialog.SaveButton, control)
    }
    palette := GetAppearancePalette()
    dialog.Hint.SetFont("c" . palette.MutedText)
    dialog.Disclosure.SetFont("c" . palette.MutedText)
    dialog.ErrorText.SetFont("cD84A4A")
    RedrawGuiWindow(dialog.Gui)
}


SetSettingsMessage(dialog, message)
{
    dialog.ErrorText.Text := message
    dialog.ErrorText.Move(, , , Max(40, StrSplit(message, "`n").Length * 20))
    LayoutSettings(dialog)
}


CloseSettings(dialog, *)
{
    global SettingsDialog
    if !IsObject(SettingsDialog) || SettingsDialog != dialog
        return
    StopHotkeyRecording(dialog)
    OnMessage(0x0006, HandleSettingsActivation, 0)
    OnMessage(0x0100, HandleSettingsPageKeyDown, 0)
    SettingsDialog := 0
    try dialog.Gui.Destroy()
    SetConfiguredHotkeysEnabled(true)
    ApplyAppearanceToOpenWindows()
}


HandleSettingsActivation(wParam, lParam, message, hwnd)
{
    global SettingsDialog
    if IsObject(SettingsDialog) && hwnd = SettingsDialog.Gui.Hwnd && (wParam & 0xFFFF) = 0
        StopHotkeyRecording(SettingsDialog)
}


RestoreSettingsDefaults(dialog, *)
{
    StopHotkeyRecording(dialog)
    switch dialog.Page
    {
        case 1:
            dialog.ThemeList.Choose(1)
            dialog.Transparency.Value := false
            dialog.ResultPosition.Value := true
            dialog.Autostart.Value := false
            if IsObject(dialog.Admin)
                dialog.Admin.Value := false
        case 2:
            dialog.ServiceList.Choose(GetTranslationServiceIndex("tencent"))
            dialog.VoiceList.Choose(GetSpeechVoiceIndex("zh-CN-XiaoyiNeural"))
            dialog.SpeedList.Choose(GetSpeechSpeedIndex(1))
            dialog.Consent.Value := false
        case 3:
            RestoreHotkeyDefaults(dialog)
    }
    SetSettingsMessage(dialog, "")
    if dialog.Page = 1
        PreviewSettingsAppearance(dialog)
}


SaveSettings(dialog, *)
{
    global SettingsDialog

    previousCritical := A_IsCritical
    Critical
    try
    {
        if !IsObject(SettingsDialog) || SettingsDialog != dialog
            return false
        ; RunWait in the StartupTask helper must not allow Close/Cancel to destroy the draft.
        return SaveSettingsDraft(dialog)
    }
    finally Critical(previousCritical)
}


SaveSettingsDraft(dialog)
{
    global CONFIG, TRANSLATION_SERVICES, SPEECH_VOICES, SPEECH_SPEEDS, ActiveInputDialog
    global PrivacyGui
    StopHotkeyRecording(dialog)
    settings := Map(
        "ColorTheme", ["system", "dark", "light"][dialog.ThemeList.Value],
        "WindowTransparency", dialog.Transparency.Value,
        "ShowResultAtMouse", dialog.ResultPosition.Value,
        "RunAsAdmin", IsObject(dialog.Admin) ? dialog.Admin.Value : CONFIG.RunAsAdmin,
        "TranslationService", TRANSLATION_SERVICES[dialog.ServiceList.Value].Service,
        "SpeechVoice", SPEECH_VOICES[dialog.VoiceList.Value].Voice,
        "SpeechSpeed", SPEECH_SPEEDS[dialog.SpeedList.Value].Value,
        "OnlineServicesConsent", dialog.Consent.Value,
        "PrivacyChoiceMade", CONFIG.PrivacyChoiceMade || dialog.Consent.Value != CONFIG.OnlineServicesConsent)
    adminChanged := settings["RunAsAdmin"] != CONFIG.RunAsAdmin
    consentChanged := settings["OnlineServicesConsent"] != CONFIG.OnlineServicesConsent
    oldAutostart := IsAutostartEnabled()
    autostartChanged := oldAutostart != dialog.Autostart.Value
    ; Validate before changing any Windows settings.
    try
    {
        if dialog.TranslationHotkey != CONFIG.Hotkey
            ValidateHotkeySetting(dialog.TranslationHotkey)
        if dialog.SpeechHotkey != CONFIG.SpeakHotkey
            ValidateHotkeySetting(dialog.SpeechHotkey)
        if CanonicalHotkey(dialog.TranslationHotkey) = CanonicalHotkey(dialog.SpeechHotkey)
            throw Error("翻译和朗读不能使用相同的快捷键。")
    }
    catch Error as err
    {
        SetSettingsMessage(dialog, err.Message)
        return false
    }
    try
    {
        if autostartChanged
            SetAutostartEnabled(dialog.Autostart.Value)
        ApplyHotkeySettings(dialog.TranslationHotkey, dialog.SpeechHotkey, settings)
    }
    catch Error as err
    {
        message := err.Message
        if autostartChanged
        {
            try SetAutostartEnabled(oldAutostart)
            catch Error as rollbackError
                message .= "`n恢复开机自启失败：" . rollbackError.Message
        }
        SetSettingsMessage(dialog, message)
        return false
    }
    for key, value in settings
        CONFIG.%key% := value
    ApplyResultPositionSetting(CONFIG.ShowResultAtMouse)
    UpdateSpeechSpeedControls()
    if IsObject(ActiveInputDialog) && IsObject(ActiveInputDialog.SelectorList)
    {
        if ActiveInputDialog.State.DraftKey = "voice"
            ActiveInputDialog.SelectorList.Choose(GetSpeechVoiceIndex(CONFIG.SpeechVoice))
        else if ActiveInputDialog.State.DraftKey = "translation"
            ActiveInputDialog.SelectorList.Choose(GetTranslationServiceIndex(CONFIG.TranslationService))
    }
    CloseSettings(dialog)
    if consentChanged
    {
        if IsObject(PrivacyGui)
            CloseOnlineServicesPrivacyDialog(PrivacyGui)
        if CONFIG.OnlineServicesConsent
            SetTimer(EnsureSpeechWorker, -1)
        else
            CancelActiveOnlineOperations()
    }
    if adminChanged
        OfferSettingsRestart(CONFIG.RunAsAdmin)
    return true
}


OfferSettingsRestart(runAsAdmin)
{
    if MsgBox("设置已保存。管理员启动方式将在下次启动时生效。`n现在重启译读？", "译读", "YesNo Icon? Default2") != "Yes"
        return
    try
    {
        ; Starting without elevation from an elevated process would retain its token.
        if A_IsAdmin && !runAsAdmin
        {
            shell := ComObject("Shell.Application")
            shell.ShellExecute(A_IsCompiled ? A_ScriptFullPath : A_AhkPath,
                A_IsCompiled ? "" : QuoteCommandArgument(A_ScriptFullPath), A_ScriptDir, "open", 1)
        }
        else
            Run(GetLaunchCommand(runAsAdmin), A_ScriptDir)
        ExitApp()
    }
    catch Error as err
        MsgBox("设置已保存，但重启失败。请手动重启译读。`n" . err.Message, "译读", "Icon!")
}


WriteSettingsConfig(settings)
{
    global CONFIG_PATH
    EnsureConfigDirectory()
    temporaryPath := CONFIG_PATH . ".settings." . DllCall("GetCurrentProcessId", "UInt") . ".tmp"
    try
    {
        if FileExist(CONFIG_PATH)
            FileCopy(CONFIG_PATH, temporaryPath, true)
        if FileExist(temporaryPath)
            FileSetAttrib("-R", temporaryPath)
        for key, value in settings
            IniWrite(value, temporaryPath, "Settings", key)
        FileMove(temporaryPath, CONFIG_PATH, true)
    }
    finally
    {
        if FileExist(temporaryPath)
            FileDelete(temporaryPath)
    }
}
