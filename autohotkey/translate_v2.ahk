#Requires AutoHotkey v2.0
#SingleInstance Force

SendMode "Input"

global CONFIG := {
    Hotkey: "^F1",
    RequestTimeoutMs: 3000,
    RequestPollIntervalMs: 50,
    SelectionTimeoutSeconds: 0.5,
    ApiUrl: "https://wxapp.translator.qq.com/api/translate",
    Referer: "https://servicewechat.com/wxb1070eabc6f9107e/117/page-frame.html",
    UserAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 16_3_1 like Mac OS X) "
        . "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 "
        . "MicroMessenger/8.0.32(0x18002035) NetType/WIFI Language/zh_TW"
}

global TranslationBusy := false
global ResultGui := 0
global ResultEdit := 0
global ResultPinButton := 0
global ResultCopyButton := 0
global ResultCloseButton := 0
global ResultPinned := false
global ActiveInputDialog := 0
global ActiveTranslationRequest := 0

Hotkey CONFIG.Hotkey, TranslateFromHotkey
OnMessage(0x0100, HandleInputKeyDown)
OnMessage(0x0201, HandleWindowBackgroundDrag)
OnMessage(0x0006, HandleWindowActivation)
SetupTrayMenu()


SetupTrayMenu()
{
    A_TrayMenu.Delete()
    A_TrayMenu.Add("翻译`tCtrl+F1", TranslateFromHotkey)
    A_TrayMenu.Add()
    A_TrayMenu.Add("退出", (*) => ExitApp())
    A_TrayMenu.Default := "翻译`tCtrl+F1"
    A_TrayMenu.ClickCount := 1
    A_IconTip := "微信翻译 (Ctrl+F1)"
}


TranslateFromHotkey(*)
{
    global TranslationBusy

    if TranslationBusy
        return

    TranslationBusy := true

    try
    {
        sourceText := GetSelectedText()

        if sourceText = ""
        {
            sourceText := PromptForTranslationText()

            if sourceText = ""
            {
                TranslationBusy := false
                return
            }
        }

        targetLanguage := ContainsChinese(sourceText) ? "en" : "zh"
        StartTranslationRequest(sourceText, targetLanguage)
    }
    catch Error as err
    {
        TranslationBusy := false
        ShowTranslationError(err.Message)
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


PromptForTranslationText()
{
    global ActiveInputDialog

    state := {
        Confirmed: false,
        Text: "",
        Pinned: false
    }

    inputGui := Gui(
        "+Resize -MinimizeBox -MaximizeBox +MinSize360x200",
        "输入翻译内容"
    )
    inputGui.MarginX := 16
    inputGui.MarginY := 14
    inputGui.BackColor := "171A1F"
    inputGui.SetFont("s10 cF1F3F5", "Microsoft YaHei UI")

    inputEdit := inputGui.AddEdit(
        "xm ym w428 h188 +Multi +WantReturn Background20242B cF1F3F5"
    )
    pinButton := inputGui.AddButton("xm y+14 w96 h30", "钉住")
    translateButton := inputGui.AddButton("x258 yp w96 h30 Default", "翻译")
    cancelButton := inputGui.AddButton("x+10 yp w80 h30", "取消")

    ActiveInputDialog := {
        Gui: inputGui,
        Edit: inputEdit,
        State: state
    }

    pinButton.OnEvent(
        "Click",
        ToggleInputPinned.Bind(state, inputGui, pinButton)
    )
    translateButton.OnEvent(
        "Click",
        SubmitTranslationInput.Bind(state, inputEdit, inputGui)
    )
    cancelButton.OnEvent("Click", CancelTranslationInput.Bind(inputGui))
    inputGui.OnEvent("Close", CancelTranslationInput.Bind(inputGui))
    inputGui.OnEvent("Escape", CancelTranslationInput.Bind(inputGui))
    inputGui.OnEvent(
        "Size",
        ResizeInputWindow.Bind(inputEdit, pinButton, translateButton, cancelButton)
    )

    inputGui.Show("w460 h260")
    ApplyDarkTheme(inputGui, inputEdit, pinButton, translateButton, cancelButton)
    WinSetTransparent(245, "ahk_id " . inputGui.Hwnd)
    inputEdit.Focus()

    WinWaitClose("ahk_id " . inputGui.Hwnd)
    ActiveInputDialog := 0
    return state.Confirmed ? state.Text : ""
}


ToggleInputPinned(state, inputGui, pinButton, *)
{
    state.Pinned := !state.Pinned
    WinSetAlwaysOnTop(state.Pinned, "ahk_id " . inputGui.Hwnd)
    pinButton.Text := state.Pinned ? "取消钉住" : "钉住"
}


SubmitTranslationInput(state, inputEdit, inputGui, *)
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

    if GetKeyState("Ctrl")
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
        SubmitTranslationInput(
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
    translateButton,
    cancelButton,
    guiObject,
    minMax,
    width,
    height
)
{
    if minMax = -1
        return

    inputEdit.Move(16, 14, Max(200, width - 32), Max(100, height - 72))
    pinButton.Move(16, height - 44)
    translateButton.Move(width - 202, height - 44)
    cancelButton.Move(width - 96, height - 44)
}


ContainsChinese(text)
{
    return RegExMatch(text, "[\x{3400}-\x{4DBF}\x{4E00}-\x{9FFF}\x{F900}-\x{FAFF}]")
}


StartTranslationRequest(sourceText, targetLanguage)
{
    global CONFIG, ActiveTranslationRequest

    params := "source=auto"
        . "&target=" . UrlEncode(targetLanguage)
        . "&sourceText=" . UrlEncode(sourceText)
        . "&platform=WeChat_APP"
        . "&candidateLangs=en%7Czh"
        . "&guid=ahk_v2_user"

    request := ComObject("WinHttp.WinHttpRequest.5.1")
    request.SetTimeouts(
        CONFIG.RequestTimeoutMs,
        CONFIG.RequestTimeoutMs,
        CONFIG.RequestTimeoutMs,
        CONFIG.RequestTimeoutMs
    )
    request.Open("GET", CONFIG.ApiUrl . "?" . params, true)
    request.SetRequestHeader("Content-Type", "application/json")
    request.SetRequestHeader("Referer", CONFIG.Referer)
    request.SetRequestHeader("User-Agent", CONFIG.UserAgent)

    try
    {
        request.Send()
    }
    catch Error as err
    {
        if IsTimeoutError(err)
            throw Error("翻译请求超时，请稍后重试。")

        throw Error("翻译请求失败，请检查网络连接后重试。")
    }

    ActiveTranslationRequest := {
        Http: request,
        StartedAt: A_TickCount
    }

    ShowTranslationResult("翻译中...", true)
    SetTimer(CheckTranslationRequest, CONFIG.RequestPollIntervalMs)
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
        FinishTranslationRequest()
        ShowTranslationError("翻译请求超时，请稍后重试。")
        return
    }

    try
    {
        if !requestState.Http.WaitForResponse(0)
            return
    }
    catch Error as err
    {
        FinishTranslationRequest()

        if IsTimeoutError(err)
            ShowTranslationError("翻译请求超时，请稍后重试。")
        else
            ShowTranslationError("翻译请求失败，请检查网络连接后重试。")

        return
    }

    FinishTranslationRequest()

    try
    {
        translatedText := ParseTranslationResponse(requestState.Http)
        ShowTranslationResult(translatedText)
    }
    catch Error as err
    {
        ShowTranslationError(err.Message)
    }
}


FinishTranslationRequest()
{
    global TranslationBusy, ActiveTranslationRequest

    SetTimer(CheckTranslationRequest, 0)
    ActiveTranslationRequest := 0
    TranslationBusy := false
}


ParseTranslationResponse(request)
{
    status := request.Status

    if status < 200 || status >= 300
        throw Error("微信翻译返回 HTTP " . status . "。")

    try
    {
        response := JsonParser.Parse(request.ResponseText)
    }
    catch Error
    {
        throw Error("微信翻译响应解析失败。")
    }

    if !(response is Map)
        || !response.Has("targetText")
        || Type(response["targetText"]) != "String"
        || Trim(response["targetText"]) = ""
    {
        throw Error("微信翻译接口返回异常。")
    }

    return response["targetText"]
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
    global ResultGui, ResultEdit, ResultPinButton, ResultCopyButton, ResultCloseButton

    isNewWindow := !IsObject(ResultGui)

    if isNewWindow
        CreateResultWindow()

    ResultEdit.Value := translatedText
    ResultEdit.Opt(pending ? "+ReadOnly" : "-ReadOnly")
    ResultCopyButton.Enabled := !pending

    if isNewWindow
    {
        ResultGui.Show("w460 h250")
        ApplyDarkTheme(
            ResultGui,
            ResultEdit,
            ResultPinButton,
            ResultCopyButton,
            ResultCloseButton
        )
        WinSetTransparent(235, "ahk_id " . ResultGui.Hwnd)
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

    WinActivate("ahk_id " . ResultGui.Hwnd)
}


ShowTranslationError(message)
{
    ShowTranslationResult("翻译失败：`r`n" . message)
}


CreateResultWindow()
{
    global ResultGui, ResultEdit, ResultPinButton, ResultCopyButton, ResultCloseButton

    ResultGui := Gui("+Resize +MinSize360x200", "翻译结果")
    ResultGui.MarginX := 16
    ResultGui.MarginY := 14
    ResultGui.BackColor := "171A1F"
    ResultGui.SetFont("s10 cF1F3F5", "Microsoft YaHei UI")

    ResultEdit := ResultGui.AddEdit(
        "xm ym w428 h178 +Multi +WantReturn Background20242B cF1F3F5"
    )
    ResultPinButton := ResultGui.AddButton("xm y+14 w96 h30", "钉住")
    ResultCopyButton := ResultGui.AddButton("x258 yp w96 h30 Default", "复制结果")
    ResultCloseButton := ResultGui.AddButton("x+10 yp w80 h30", "关闭")

    ResultPinButton.OnEvent("Click", ToggleResultPinned)
    ResultCopyButton.OnEvent("Click", CopyCurrentTranslation)
    ResultCloseButton.OnEvent("Click", HideResultWindow)
    ResultGui.OnEvent("Close", HideResultWindow)
    ResultGui.OnEvent("Escape", HideResultWindow)
    ResultGui.OnEvent(
        "Size",
        ResizeResultWindow.Bind(
            ResultEdit,
            ResultPinButton,
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
    global ResultEdit

    if IsObject(ResultEdit)
        CopyTranslation(ResultEdit.Value)
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


ResizeResultWindow(
    resultEdit,
    pinButton,
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

    resultEdit.Move(16, 14, Max(200, width - 32), Max(100, height - 72))
    pinButton.Move(16, height - 44)
    copyButton.Move(width - 202, height - 44)
    closeButton.Move(width - 96, height - 44)
}


CopyTranslation(text)
{
    A_Clipboard := text
    TrayTip("译文已复制到剪贴板。", "微信翻译", 1)
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
