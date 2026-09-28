global ResultSpeakButton := {Text: ""}
global TestDirectory := A_Args[1]
global TestPlaybackMode := "stopped"
global TestPlaybackCount := 0
global TestPlaybackError := false
global TestNotifications := []
global TestWorkerStops := 0
global TestConsent := true

; Keep timer callbacks out of deterministic state-transition checks.
Critical
try
{
    TestSplitting()
    FileAppend("PASS: splitting`n", "*")
    TestPlaybackQueue()
    FileAppend("PASS: playback queue`n", "*")
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
    StartTestSpeech()
    request := StrSplit(Trim(FileRead(SpeechWorkerRequestPath, "UTF-8")), "`n", "`r")
    Assert(request.Length = 5, "Worker request protocol")
    Assert(request[1] = Base64EncodeUtf8(SpeechSession.Chunks[1]), "First chunk payload")
    Assert(TestPlaybackCount = 0, "Playback before synthesis")
    CompleteTestChunk()
    firstPath := SpeechSession.PlayingChunk.AudioPath
    Assert(TestPlaybackCount = 1 && SpeechSynthesisPending, "First playback and prefetch")
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
    if SubStr(command, 1, 5) = "open " && TestPlaybackError
        return 1
    if SubStr(command, 1, 5) = "play "
    {
        TestPlaybackMode := "playing"
        TestPlaybackCount += 1
    }
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
