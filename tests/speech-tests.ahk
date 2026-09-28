global ResultSpeakButton := {Text: ""}
global ResultPauseButton := {Text: "", Enabled: false}
global ResultEdit := 0
global ResultPinButton := 0
global ResultCopyButton := 0
global ResultCloseButton := 0
global ResultPinned := false
global TestDirectory := A_Args[1]
global CONFIG_DIRECTORY := TestDirectory
global CONFIG_PATH := TestDirectory . "\YiDu.ini"
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
global ActiveInputDialog := 0
global InputDrafts := Map()
global TestInputClipboard := "Alpha"
global TestDraftScenario := 0
global TranslationBusy := false
global ActiveTranslationRequest := 0
global TestTranslationResults := []
global TestTranslationErrors := []
global TestTranslationTransport := 0
global ResultGui := 0
global TestInputError := ""
global TestTooltipHwnd := 0

DetectHiddenWindows(true)
OnMessage(0x002B, DrawDropDownItem)

; Keep timer callbacks out of deterministic state-transition checks.
Critical
try
{
    TestTraySettings()
    FileAppend("PASS: tray menus, saved settings and quiet startup`n", "*")
    TestInputWindows()
    FileAppend("PASS: linked voice selectors, saved selection and input layout`n", "*")
    TestInputDrafts()
    FileAppend("PASS: input drafts, selection restoration and explicit dismissal`n", "*")
    TestTranslationCancellation()
    FileAppend("PASS: translation cancellation, late callbacks and subsequent requests`n", "*")
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
    global CONFIG, CONFIG_PATH, SPEECH_VOICES, SpeechVoiceTrayMenu, SpeechVoiceTrayMenus
    global AppearanceTrayMenu, ColorThemeTrayMenu, TestAppearanceUpdates
    global TestFirstRunCount, TestNotifications
    global SPEECH_SPEEDS, SpeechSpeedTrayMenu
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
    Assert(MenuItemPosition(A_TrayMenu, "窗口半透明") = -1, "Transparency moved into appearance")
    Assert(MenuItemPosition(A_TrayMenu, "朗读音色") >= 0, "Voice root menu")
    Assert(MenuItemPosition(A_TrayMenu, "朗读速度") >= 0, "Speed root menu")
    for item in SPEECH_SPEEDS
        Assert(!!(MenuItemState(SpeechSpeedTrayMenu, item.Label) & 8) = (item.Value = CONFIG.SpeechSpeed), "Speed menu selection")
    Assert(SpeechVoiceTrayMenus.Count = 5, "Five voice groups")
    for item in SPEECH_VOICES
        Assert(MenuItemPosition(SpeechVoiceTrayMenus[item.Group], item.Label) >= 0, "Voice assigned to group")
    Assert(MenuItemState(SpeechVoiceTrayMenu, "粤语") & 8, "Saved voice group checked")
    SetSpeechVoice("en-US-GuyNeural")
    Assert(!(MenuItemState(SpeechVoiceTrayMenu, "粤语") & 8), "Old group unchecked")
    Assert(MenuItemState(SpeechVoiceTrayMenu, "英语") & 8, "New group checked")
    Assert(MenuItemState(SpeechVoiceTrayMenus["英语"], "Guy · 英语男声") & 8, "New voice checked")
    Assert(IniRead(CONFIG_PATH, "Settings", "SpeechVoice") = "en-US-GuyNeural", "Voice choice persisted")
    Assert(MenuItemState(ColorThemeTrayMenu, "深色") & 8, "Saved theme checked")
    SetColorTheme("light")
    Assert(MenuItemState(ColorThemeTrayMenu, "浅色") & 8, "Theme selection checked")
    Assert(!(MenuItemState(ColorThemeTrayMenu, "深色") & 8), "Previous theme unchecked")
    Assert(MenuItemState(AppearanceTrayMenu, "窗口半透明") & 8, "Saved transparency checked")
    ToggleWindowTransparency()
    Assert(!CONFIG.WindowTransparency && !(MenuItemState(AppearanceTrayMenu, "窗口半透明") & 8), "Transparency toggle")
    Assert(IniRead(CONFIG_PATH, "Settings", "WindowTransparency") = "0", "Transparency persisted")
    Assert(TestAppearanceUpdates = 2, "Appearance applied to open windows")
    CONFIG.PrivacyChoiceMade := false
    TestStartup()
    Critical "Off"
    Sleep(30)
    Critical
    Assert(TestFirstRunCount = 1, "First-run consent window retained")
    CONFIG.PrivacyChoiceMade := true
    TestStartup()
    Assert(TestFirstRunCount = 1 && TestNotifications.Length = 0, "Later startup remains quiet")
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
    global ActiveInputDialog, CONFIG, CONFIG_PATH, SPEECH_VOICES, SPEECH_VOICE_GROUPS
    global TestInputError, TestTooltipHwnd, SPEECH_SPEEDS, SpeechSpeedTrayMenu
    global TestDraftScenario
    Critical
    if !IsObject(ActiveInputDialog)
        return
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
        if mode = "voice"
        {
            Assert(dialog.SpeedButton.Text = GetSpeechSpeedLabel(), "Saved speed restored on button")
            dialog.SelectorList.GetPos(, , &voiceWidth)
            Assert(voiceWidth = 150, "Voice selector narrowed")
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
                Assert(MenuItemState(SpeechSpeedTrayMenu, GetSpeechSpeedLabel()) & 8, "Speed button syncs tray")
                Assert(IniRead(CONFIG_PATH, "Settings", "SpeechSpeed") + 0 = speed, "Speed choice persisted")
                dialog.SpeedButton.GetPos(, , &buttonWidth)
                Assert(buttonWidth = 56, "Speed button width stays fixed")
            }
            speedCommand := DllCall("GetMenuItemID", "Ptr", SpeechSpeedTrayMenu.Handle,
                "Int", MenuItemPosition(SpeechSpeedTrayMenu, "2×"), "UInt")
            DllCall("PostMessageW", "Ptr", A_ScriptHwnd, "UInt", 0x111, "UPtr", speedCommand, "Ptr", 0)
            Critical "Off"
            Sleep(30)
            Critical
            Assert(CONFIG.SpeechSpeed = 2 && dialog.SpeedButton.Text = "2×", "Tray speed syncs input button")
            savedIndex := GetSpeechVoiceIndex(CONFIG.SpeechVoice)
            Assert(dialog.CategoryList.Text = SPEECH_VOICES[savedIndex].Group, "Saved category restored")
            Assert(dialog.State.VoiceOptions[dialog.SelectorList.Value].Voice = CONFIG.SpeechVoice, "Saved voice restored")
            for group in SPEECH_VOICE_GROUPS
            {
                dialog.CategoryList.Choose(group)
                ChangeSpeechVoiceGroup(dialog.State, dialog.SelectorList, dialog.CategoryList)
                Assert(dialog.State.VoiceOptions.Length > 0, "Category has voices")
                count := SendMessage(0x0146, , , , "ahk_id " . dialog.SelectorList.Hwnd)
                Assert(count = dialog.State.VoiceOptions.Length, "Filtered list count")
                for index, item in dialog.State.VoiceOptions
                {
                    Assert(item.Group = group, "Only selected category voices shown")
                    dialog.SelectorList.Choose(index)
                    ChangeSpeechVoice(dialog.State, dialog.SelectorList)
                    Assert(CONFIG.SpeechVoice = item.Voice, "Filtered selection maps to correct voice")
                    Assert(IniRead(CONFIG_PATH, "Settings", "SpeechVoice") = item.Voice, "Filtered choice persisted")
                }
            }
        }
        else
        {
            Assert(!IsObject(dialog.CategoryList), "Other modes have no category selector")
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

        minimumWidth := mode = "voice" ? 560 : (mode = "translation" ? 300 : 360)
        for size in [{Width: minimumWidth, Height: 200}, {Width: 800, Height: 380}]
        {
            ResizeInputWindow(dialog.Edit, dialog.PinButton, dialog.SelectorList,
                dialog.CategoryList, dialog.SpeedButton, dialog.SubmitButton, dialog.CancelButton,
                dialog.Gui, 0, size.Width, size.Height)
            AssertInputLayout(dialog, size.Width, size.Height)
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
    RunDraftInput("voice", {Expected: "Alpha", Action: "blur"})
    Assert(!InputDrafts.Has("voice"), "Unedited clipboard does not become a draft")

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
    Assert(!InputDrafts.Has("voice") && InputDrafts.Has("translation"), "Cancel clears only its own draft")

    result := RunDraftInput("translation", {Expected: translationText, ExpectedSelection: 4, ExpectedSelectionEnd: 10, Action: "submit"})
    Assert(result == Trim(translationText) && !InputDrafts.Has("translation"), "Submission clears restored draft")

    for action in ["cancel", "close", "escape"]
    {
        RunDraftInput("voice", {Expected: "Alpha", Text: "saved text", Selection: 3, Action: "blur"})
        RunDraftInput("voice", {Expected: "saved text", ExpectedSelection: 3, Action: action})
        Assert(!InputDrafts.Has("voice"), "Explicit dismissal clears draft: " . action)
    }
    RunDraftInput("voice", {Expected: "Alpha", Text: "pinned draft", Selection: 5, Action: "pinned"})
    Assert(InputDrafts["voice"].Text == "pinned draft", "Pinned draft retained after unpinning and blur")
    InputDrafts.Clear()
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
    global TestTranslationResults, ResultGui
    TestTranslationResults.Push(text)
    ResultGui.Hidden := false
}

ShowTranslationError(message)
{
    global TestTranslationErrors, ResultGui
    TestTranslationErrors.Push(message)
    ResultGui.Hidden := false
}

AssertInputLayout(dialog, width, height)
{
    dialog.Edit.GetPos(, &editY, , &editHeight)
    controls := [dialog.PinButton]
    if IsObject(dialog.CategoryList)
        controls.Push(dialog.CategoryList)
    if IsObject(dialog.SelectorList)
        controls.Push(dialog.SelectorList)
    if IsObject(dialog.SpeedButton)
        controls.Push(dialog.SpeedButton)
    controls.Push(dialog.SubmitButton, dialog.CancelButton)
    previousRight := 0
    for control in controls
    {
        control.GetPos(&controlX, &controlY, &controlWidth, &controlHeight)
        Assert(controlX >= previousRight + 6, "Input row controls overlap")
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
    pauseLabel := paused ? "继续朗读" : "暂停朗读"
    Assert(SpeechBusy = busy, "Speech busy state")
    Assert(!!(MenuItemState(A_TrayMenu, pauseLabel) & 3) = !busy, "Pause menu availability")
    Assert(!!(MenuItemState(A_TrayMenu, "停止朗读") & 3) = !busy, "Stop menu availability")
    Assert(ResultPauseButton.Text = (paused ? "继续" : "暂停") && ResultPauseButton.Enabled = busy, "Result pause state")
    Assert(ResultSpeakButton.Text = (busy ? "停止" : "朗读"), "Result stop state")
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

    CreateResultWindow()
    try
    {
        ResultGui.Show("Hide w400 h200")
        for size in [{Width: 400, Height: 128}, {Width: 800, Height: 380}]
        {
            ResizeResultWindow(ResultEdit, ResultPinButton, ResultPauseButton, ResultSpeakButton,
                ResultCopyButton, ResultCloseButton, ResultGui, 0, size.Width, size.Height)
            AssertInputLayout({Edit: ResultEdit, PinButton: ResultPinButton,
                CategoryList: 0, SelectorList: 0, SpeedButton: ResultPauseButton,
                SubmitButton: ResultSpeakButton, CancelButton: ResultCopyButton}, size.Width, size.Height)
            ResultCopyButton.GetPos(&copyX, , &copyWidth)
            ResultCloseButton.GetPos(&closeX, &closeY, &closeWidth, &closeHeight)
            Assert(closeX >= copyX + copyWidth + 6 && closeX + closeWidth <= size.Width - 10
                && closeY + closeHeight <= size.Height - 8, "Result close button fits row")
        }
        AssertSpeechControls(false, false)
        ResultEdit.Value := "result text"
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
    }
    finally
    {
        StopSpeech()
        ResultGui.Destroy()
        ResultGui := 0
        ResultEdit := 0
        ResultPinButton := 0
        ResultPauseButton := {Text: "暂停", Enabled: false}
        ResultSpeakButton := {Text: "朗读"}
        ResultCopyButton := 0
        ResultCloseButton := 0
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

TranslateFromTray(*)
{
}

QuoteCommandArgument(value)
{
    return Chr(34) . value . Chr(34)
}

SpeakFromTray(*)
{
}

ToggleResultAtMouse(*)
{
}

ToggleAutostart(*)
{
}

ToggleRunAsAdmin(*)
{
}

IsAutostartEnabled()
{
    return false
}

ShowOnlineServicesPrivacyDialog(*)
{
}

ShowAboutDialog(*)
{
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
