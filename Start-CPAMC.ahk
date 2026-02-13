#SingleInstance Force
Persistent()

; 路径配置（从配置文件读取）
configFilePath := A_ScriptDir "\\Start-CPAMC.ini"
exePath := ""
exeDir  := ""
pid := 0

LoadConfig()

; 使用脚本同目录下的托盘图标
TraySetIcon(A_ScriptDir "\\CPAMC-logo.ico")

A_TrayMenu.Delete()
A_TrayMenu.Add("启动服务", StartService)
A_TrayMenu.Add("停止服务", StopService)
A_TrayMenu.Add("管理中心", OpenManagement)
A_TrayMenu.Add()
A_TrayMenu.Add("显示窗口", ShowMainWindow)
A_TrayMenu.Add("退出", ExitTray)

A_IconTip := "CLIProxyAPI"

; 监听托盘图标点击事件
OnMessage(0x404, TrayClick)  ; WM_USER + 4 = 鼠标点击托盘图标

TrayClick(wParam, lParam, msg, hwnd) {
    if (lParam = 0x202)  ; WM_LBUTTONUP 左键释放
        ShowMainWindow()
}

LoadConfig() {
    global configFilePath, exePath, exeDir

    savedPath := IniRead(configFilePath, "Service", "ExePath", "")
    if FileExist(savedPath) {
        exePath := savedPath
        SplitPath(exePath, &fileName, &dir)
        exeDir := dir
    } else {
        exePath := ""
        exeDir := ""
    }
}

SaveConfig() {
    global configFilePath, exePath
    IniWrite(exePath, configFilePath, "Service", "ExePath")
}

OpenManagement(*) {
    Run("http://localhost:8317/management.html#/")
}

StartService(*) {
    global exePath, exeDir, pid
    if (pid != 0)
        return

    if (exePath = "" || !FileExist(exePath)) {
        MsgBox("请先在窗口中选择有效的可执行文件路径。", "提示", "OK Icon!")
        return
    }

    ; 启动服务 (隐藏模式)
    Run(exePath, exeDir, "Hide", &pid)
}

StopService(*) {
    global pid
    if (pid != 0) {
        ProcessClose(pid)
        pid := 0
    }
}

ShowMainWindow(*) {
    static myGui := ""
    static pathDisplay := ""
    static statusLabel := ""
    static btnStart := ""
    static btnStop := ""

    if (myGui != "" && myGui.Hwnd) {
        myGui.Show()
        UpdateAllStatus(statusLabel, pathDisplay, btnStart, btnStop)
        return
    }

    myGui := Gui("+AlwaysOnTop", "CLIProxy 管理器")
    myGui.BackColor := "0xFFFFFF"
    myGui.SetFont("s10", "Segoe UI")

    ; 标题区
    myGui.SetFont("s16 bold", "Microsoft YaHei")
    myGui.Add("Text", "x30 y25 w300 h35 c0x202124", "CLIProxy 服务")

    ; 状态指示
    global pid
    isRunning := (pid != 0)
    statusText := isRunning ? "● 正在运行" : "○ 已停止"
    statusColor := isRunning ? "0x0F9D58" : "0xDB4437"

    myGui.SetFont("s11", "Microsoft YaHei")
    statusLabel := myGui.Add("Text", "x30 y70 w200 h25 c" statusColor, statusText)

    ; 操作按钮
    myGui.SetFont("s10", "Microsoft YaHei")
    btnStart := myGui.Add("Button", "x30 y110 w120 h40", "启动服务")
    btnStart.OnEvent("Click", (*) => (StartService(), UpdateAllStatus(statusLabel, pathDisplay, btnStart, btnStop)))

    btnStop := myGui.Add("Button", "x160 y110 w120 h40", "停止服务")
    btnStop.OnEvent("Click", (*) => (StopService(), UpdateAllStatus(statusLabel, pathDisplay, btnStart, btnStop)))

    myGui.Add("Button", "x290 y110 w120 h40", "管理中心").OnEvent("Click", OpenManagement)

    ; 路径配置
    myGui.SetFont("s9", "Segoe UI")
    myGui.Add("Text", "x30 y170 w300 h20 c0x5F6368", "可执行文件路径")

    global exePath
    myGui.SetFont("s9", "Consolas")
    pathDisplay := myGui.Add("Edit", "x30 y195 w320 h36 ReadOnly -E0x200 Background0xF1F3F4", exePath)

    ; 浏览按钮
    myGui.SetFont("s9", "Microsoft YaHei")
    myGui.Add("Button", "x360 y195 w60 h36", "浏览").OnEvent("Click", (*) => ChangePath(pathDisplay))

    myGui.OnEvent("Close", (*) => myGui.Hide())
    myGui.Show("w450 h260")

    UpdateAllStatus(statusLabel, pathDisplay, btnStart, btnStop)
}

UpdateAllStatus(statusLabel, pathDisplay, btnStart, btnStop) {
    global pid, exePath
    isRunning := (pid != 0)

    ; 更新状态文本和颜色
    statusText := isRunning ? "● 正在运行" : "○ 已停止"
    statusColor := isRunning ? "0x0F9D58" : "0xDB4437"
    statusLabel.Value := statusText
    statusLabel.SetFont("c" statusColor)

    ; 更新按钮可用性
    if (btnStart && btnStop) {
        btnStart.Enabled := !isRunning
        btnStop.Enabled := isRunning
    }

    ; 更新路径显示
    pathDisplay.Value := exePath
}

ChangePath(pathDisplay) {
    global exePath, exeDir, pid

    ; 检查服务是否运行
    if (pid != 0) {
        MsgBox("服务正在运行中，请先停止服务后再修改路径！", "提示", "T3 OK Icon?")
        return
    }

    ; 打开文件选择对话框
    selectedFile := FileSelect(1, "", "选择 CLIProxyAPI 程序", "可执行文件 (*.exe)")

    if (selectedFile = "")
        return

    ; 更新路径
    SplitPath(selectedFile, &fileName, &dir)
    exePath := selectedFile
    exeDir := dir
    SaveConfig()

    ; 更新显示
    pathDisplay.Value := exePath
}

ExitTray(*) {
    global pid
    if (pid != 0)
        ProcessClose(pid)
    ExitApp
}