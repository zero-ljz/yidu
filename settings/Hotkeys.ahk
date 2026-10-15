; Keyboard capture and transactional rebinding shared by the settings window.
SetConfiguredHotkeysEnabled(enabled)
{
    global CONFIG

    state := enabled ? "On" : "Off"
    Hotkey(CONFIG.Hotkey, TranslateFromHotkey, state)
    Hotkey(CONFIG.SpeakHotkey, SpeakFromHotkey, state)
}


StartHotkeyRecording(dialog, field, *)
{
    StopHotkeyRecording(dialog)
    SetSettingsMessage(dialog, "")
    dialog.Recording := field
    dialog.Candidate := ""
    dialog.MainKeyDown := false
    dialog.Modifiers := Map()
    for key in ["LCtrl", "RCtrl", "LAlt", "RAlt", "LShift", "RShift", "LWin", "RWin"]
    {
        if GetKeyState(key, "P")
            dialog.Modifiers[GetKeyVK(key)] := HotkeyModifierForVK(GetKeyVK(key))
    }
    dialog.%field . "Button"%.Text := "请按下组合键…"
    hook := InputHook("T15")
    hook.KeyOpt("{All}", "NS")
    hook.OnKeyDown := RecordHotkeyKeyDown.Bind(dialog)
    hook.OnKeyUp := RecordHotkeyKeyUp.Bind(dialog)
    hook.OnEnd := FinishHotkeyRecording.Bind(dialog)
    dialog.Hook := hook
    hook.Start()
}


StopHotkeyRecording(dialog)
{
    field := dialog.Recording
    dialog.Recording := ""
    if IsObject(dialog.Hook)
    {
        hook := dialog.Hook
        dialog.Hook := 0
        hook.Stop()
    }
    if field != ""
    {
        hotkeyText := FormatHotkey(dialog.%field . "Hotkey"%)
        dialog.%field . "Button"%.Text := hotkeyText = "" ? "点击录入" : hotkeyText
    }
}


FinishHotkeyRecording(dialog, hook)
{
    if dialog.Hook = hook
        StopHotkeyRecording(dialog)
}


HotkeyModifierForVK(vk)
{
    switch vk
    {
        case 0x11, 0xA2, 0xA3: return "^"
        case 0x12, 0xA4, 0xA5: return "!"
        case 0x10, 0xA0, 0xA1: return "+"
        case 0x5B, 0x5C: return "#"
    }
    return ""
}


RecordHotkeyKeyDown(dialog, hook, vk, sc)
{
    if dialog.Hook != hook || dialog.Recording = ""
        return
    modifier := HotkeyModifierForVK(vk)
    if modifier != ""
    {
        dialog.Modifiers[vk] := modifier
        return
    }
    if vk = 0x1B
    {
        StopHotkeyRecording(dialog)
        return
    }
    if dialog.Candidate != ""
        return

    modifiers := ""
    for symbol in ["#", "^", "!", "+"]
    {
        for pressedVK, pressedSymbol in dialog.Modifiers
        {
            if pressedSymbol = symbol
            {
                modifiers .= symbol
                break
            }
        }
    }
    if modifiers = "" && (vk = 0x08 || vk = 0x2E)
    {
        dialog.%dialog.Recording . "Hotkey"% := ""
        StopHotkeyRecording(dialog)
        return
    }
    if modifiers = "" && (vk = 0x09 || vk = 0x0D)
    {
        StopHotkeyRecording(dialog)
        dialog.SaveButton.Focus()
        return
    }

    key := GetKeyName(Format("vk{:02X}sc{:03X}", vk, sc))
    candidate := modifiers . key
    try ValidateHotkeySetting(candidate)
    catch Error as err
    {
        SetSettingsMessage(dialog, err.Message)
        return
    }
    SetSettingsMessage(dialog, "")
    dialog.Candidate := candidate
    dialog.MainKey := vk
    dialog.MainKeyDown := true
    dialog.%dialog.Recording . "Button"%.Text := FormatHotkey(candidate)
}


RecordHotkeyKeyUp(dialog, hook, vk, sc)
{
    if dialog.Hook != hook || dialog.Recording = ""
        return
    if dialog.Modifiers.Has(vk)
        dialog.Modifiers.Delete(vk)
    if dialog.Candidate = ""
        return
    if vk = dialog.MainKey
        dialog.MainKeyDown := false
    if !dialog.MainKeyDown && dialog.Modifiers.Count = 0
    {
        dialog.%dialog.Recording . "Hotkey"% := dialog.Candidate
        StopHotkeyRecording(dialog)
    }
}


RestoreHotkeyDefaults(dialog, *)
{
    StopHotkeyRecording(dialog)
    dialog.TranslationHotkey := "^F1"
    dialog.SpeechHotkey := "^F2"
    dialog.TranslationButton.Text := FormatHotkey(dialog.TranslationHotkey)
    dialog.SpeechButton.Text := FormatHotkey(dialog.SpeechHotkey)
    SetSettingsMessage(dialog, "")
}


ValidateHotkeySetting(hotkey)
{
    if hotkey = ""
        throw Error("请分别设置翻译和朗读快捷键。")
    if !RegExMatch(hotkey, "^([#^!+]*)([^#^!+]+)$", &parts)
        || (!GetKeyVK(parts[2]) && !GetKeySC(parts[2]))
        || HotkeyModifierForVK(GetKeyVK(parts[2])) != ""
        throw Error("快捷键无效，请重新录入。")
    if !RegExMatch(parts[1], "[#^!]") && !RegExMatch(parts[2], "i)^F([1-9]|1\d|2[0-4])$")
        throw Error("请使用 Ctrl、Alt 或 Win 组合键，或 F1–F24。")
}


CanonicalHotkey(hotkey)
{
    if !RegExMatch(Trim(hotkey), "^[$~]*([#^!+]*)(.+)$", &parts)
        return StrLower(Trim(hotkey))
    modifiers := ""
    for symbol in ["#", "^", "!", "+"]
    {
        if InStr(parts[1], symbol)
            modifiers .= symbol
    }
    key := parts[2]
    if GetKeyVK(key) || GetKeySC(key)
        return modifiers . ":" . GetKeyVK(key) . ":" . GetKeySC(key)
    return StrLower(Trim(hotkey))
}


ApplyHotkeySettings(translationHotkey, speechHotkey, settings := 0)
{
    global CONFIG, SettingsDialog

    oldTranslation := CONFIG.Hotkey
    oldSpeech := CONFIG.SpeakHotkey
    ; Preserve manually configured advanced bindings unless that field was edited.
    if translationHotkey != oldTranslation
        ValidateHotkeySetting(translationHotkey)
    if speechHotkey != oldSpeech
        ValidateHotkeySetting(speechHotkey)
    if CanonicalHotkey(translationHotkey) = CanonicalHotkey(speechHotkey)
        throw Error("翻译和朗读不能使用相同的快捷键。")

    previousCritical := A_IsCritical
    Critical
    try
    {
        SetConfiguredHotkeysEnabled(false)
        try
        {
            Hotkey(translationHotkey, TranslateFromHotkey, "On")
            Hotkey(speechHotkey, SpeakFromHotkey, "On")
            if !IsObject(settings)
                settings := Map()
            settings["Hotkey"] := translationHotkey
            settings["SpeakHotkey"] := speechHotkey
            WriteSettingsConfig(settings)
        }
        catch Error
        {
            try Hotkey(translationHotkey, "Off")
            try Hotkey(speechHotkey, "Off")
            state := IsObject(SettingsDialog) ? "Off" : "On"
            Hotkey(oldTranslation, TranslateFromHotkey, state)
            Hotkey(oldSpeech, SpeakFromHotkey, state)
            throw Error("无法保存设置，原设置已保留。`n请检查组合键或配置文件是否可写。")
        }
        CONFIG.Hotkey := translationHotkey
        CONFIG.SpeakHotkey := speechHotkey
        A_TrayMenu.Rename("翻译`t" . FormatHotkey(oldTranslation), "翻译`t" . FormatHotkey(translationHotkey))
        A_TrayMenu.Rename("朗读`t" . FormatHotkey(oldSpeech), "朗读`t" . FormatHotkey(speechHotkey))
        A_TrayMenu.Default := "翻译`t" . FormatHotkey(translationHotkey)
        A_IconTip := SubStr("译读 (翻译 " . FormatHotkey(translationHotkey)
            . "，朗读 " . FormatHotkey(speechHotkey) . ")", 1, 127)
    }
    finally Critical(previousCritical)
}


WriteHotkeyConfig(translationHotkey, speechHotkey)
{
    WriteSettingsConfig(Map("Hotkey", translationHotkey, "SpeakHotkey", speechHotkey))
}
