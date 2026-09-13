local MacroUI = {}
MacroUI.__index = MacroUI

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local Theme = ModuleLoader:Require("ui.Theme")
local State = ModuleLoader:Require("core.State")
local Logger = ModuleLoader:Require("core.Logger")
local MacroManager = ModuleLoader:Require("macros.MacroManager")
local Recorder = ModuleLoader:Require("macros.Recorder")
local Player = ModuleLoader:Require("macros.Player")
local Exporter = ModuleLoader:Require("macros.Exporter")
local Importer = ModuleLoader:Require("macros.Importer")
local Dropdown = ModuleLoader:Require("ui.components.Dropdown")

local function createButton(parent, labelText, widthFraction)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(widthFraction, 0, 0, 30)
    button.BackgroundColor3 = Theme.Blue
    button.BorderSizePixel = 1
    button.BorderColor3 = Theme.Border
    button.Text = labelText
    button.TextColor3 = Theme.Text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    return button
end

local function getMacroNames()
    local all = MacroManager and MacroManager:GetAll() or {}
    local names = {}
    for _, macro in ipairs(all) do
        if type(macro.name) == "string" and macro.name ~= "" then
            table.insert(names, macro.name)
        end
    end

    table.sort(names)
    return names
end

local function setTextInputValue(input, value)
    if input and input:IsA("TextBox") then
        input.Text = value or ""
    end
end

local function refreshSelector(module)
    if not module then
        return
    end

    local names = getMacroNames()
    local selected = State:Get("SelectedMacro") or ""
    local visible = selected
    if visible == "" and #names > 0 then
        visible = names[1]
    end

    if module.SelectorDropdown then
        module.SelectorDropdown:SetOptions(names)
        module.SelectorDropdown:SetSelected(visible ~= "" and visible or nil, true)
    end

    if module.NameInput and module.NameInput:IsA("TextBox") then
        module.NameInput.Text = visible ~= "" and visible or module.NameInput.Text or ""
    end
end

local function updateStatusDisplay(module)
    if not module or not module.StatusLabel then
        return
    end

    local status = State:Get("MacroStatus") or "Idle"
    local macroName = State:Get("SelectedMacro") or ""
    local actions = State:Get("Actions") or 0
    local cash = State:Get("Cash") or 0
    local wave = State:Get("Wave") or 0
    local time = State:Get("Time") or "00:00"

    module.StatusLabel.Text = string.format(
        "Status: %s\nMacro: %s\nActions: %d\nCash: %d\nWave: %d\nTime: %s",
        tostring(status),
        tostring(macroName),
        tonumber(actions) or 0,
        tonumber(cash) or 0,
        tonumber(wave) or 0,
        tostring(time)
    )
end

local function refreshLog(module)
    if not module or not module.LogPanel then
        return
    end

    local entries = Logger:GetEntries() or {}
    local lines = {}
    for i = math.max(1, #entries - 7), #entries do
        local entry = entries[i]
        if entry then
            table.insert(lines, string.format("[%s] %s: %s", entry.timestamp or "--:--:--", entry.level or "INFO", entry.message or ""))
        end
    end

    module.LogPanel.Text = table.concat(lines, "\n")
end

function MacroUI:Build(parent)
    if not parent then
        return nil
    end

    local module = Instance.new("ScrollingFrame")
    module.Name = "MacroTab"
    module.Size = UDim2.new(1, 0, 1, 0)
    module.BackgroundTransparency = 1
    module.BorderSizePixel = 0
    module.AutomaticCanvasSize = Enum.AutomaticSize.Y
    module.CanvasSize = UDim2.new(0, 0, 0, 0)
    module.ScrollBarThickness = 4
    module.Parent = parent
    module.Connections = {}
    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(module.Connections, connection)
        return connection
    end

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = module

    local statusLabel = Instance.new("TextLabel")
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(1, 0, 0, 110)
    statusLabel.Text = "Status: Idle\nMacro: \nActions: 0\nCash: 0\nWave: 0\nTime: 00:00"
    statusLabel.TextColor3 = Theme.Text
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 12
    statusLabel.TextWrapped = true
    statusLabel.Parent = module

    local selectorFrame = Instance.new("Frame")
    selectorFrame.BackgroundTransparency = 1
    selectorFrame.Size = UDim2.new(1, 0, 0, 30)
    selectorFrame.Parent = module

    local selectorDropdown = Dropdown.new(selectorFrame, getMacroNames())
    local selectorButton = selectorDropdown.Button

    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(1, 0, 0, 32)
    nameInput.BackgroundColor3 = Theme.PanelSecondary
    nameInput.BorderSizePixel = 1
    nameInput.BorderColor3 = Theme.Border
    nameInput.Text = ""
    nameInput.PlaceholderText = "Macro Name"
    nameInput.TextColor3 = Theme.Text
    nameInput.PlaceholderColor3 = Theme.TextSecondary
    nameInput.Font = Enum.Font.Gotham
    nameInput.TextSize = 12
    nameInput.Parent = module

    local actionRow = Instance.new("Frame")
    actionRow.Size = UDim2.new(1, 0, 0, 32)
    actionRow.BackgroundTransparency = 1
    actionRow.Parent = module

    local actionLayout = Instance.new("UIListLayout")
    actionLayout.FillDirection = Enum.FillDirection.Horizontal
    actionLayout.Padding = UDim.new(0, 6)
    actionLayout.Parent = actionRow

    local createButton = createButton(actionRow, "Create", 0.18)
    local saveButton = createButton(actionRow, "Save", 0.18)
    local loadButton = createButton(actionRow, "Load", 0.18)
    local deleteButton = createButton(actionRow, "Delete", 0.18)
    local duplicateButton = createButton(actionRow, "Duplicate", 0.18)

    local recorderRow = Instance.new("Frame")
    recorderRow.Size = UDim2.new(1, 0, 0, 32)
    recorderRow.BackgroundTransparency = 1
    recorderRow.Parent = module

    local recorderLayout = Instance.new("UIListLayout")
    recorderLayout.FillDirection = Enum.FillDirection.Horizontal
    recorderLayout.Padding = UDim.new(0, 6)
    recorderLayout.Parent = recorderRow

    local startRecordButton = createButton(recorderRow, "Start Record", 0.22)
    local pauseRecordButton = createButton(recorderRow, "Pause Record", 0.22)
    local resumeRecordButton = createButton(recorderRow, "Resume Record", 0.22)
    local stopSaveButton = createButton(recorderRow, "Stop & Save", 0.22)

    local playbackRow = Instance.new("Frame")
    playbackRow.Size = UDim2.new(1, 0, 0, 32)
    playbackRow.BackgroundTransparency = 1
    playbackRow.Parent = module

    local playbackLayout = Instance.new("UIListLayout")
    playbackLayout.FillDirection = Enum.FillDirection.Horizontal
    playbackLayout.Padding = UDim.new(0, 6)
    playbackLayout.Parent = playbackRow

    local playButton = createButton(playbackRow, "Play", 0.22)
    local pausePlaybackButton = createButton(playbackRow, "Pause", 0.22)
    local resumePlaybackButton = createButton(playbackRow, "Resume", 0.22)
    local stopPlaybackButton = createButton(playbackRow, "Stop", 0.22)

    local replayFrame = Instance.new("Frame")
    replayFrame.BackgroundTransparency = 1
    replayFrame.Size = UDim2.new(1, 0, 0, 32)
    replayFrame.Parent = module

    local replayMode = Instance.new("TextButton")
    replayMode.Size = UDim2.new(0.5, 0, 1, 0)
    replayMode.BackgroundColor3 = Theme.PanelSecondary
    replayMode.BorderSizePixel = 1
    replayMode.BorderColor3 = Theme.Border
    replayMode.Text = "Replay Mode: Once"
    replayMode.TextColor3 = Theme.Text
    replayMode.Font = Enum.Font.GothamBold
    replayMode.TextSize = 11
    replayMode.Parent = replayFrame

    local autoPlayToggle = Instance.new("TextButton")
    autoPlayToggle.Size = UDim2.new(0.5, -6, 1, 0)
    autoPlayToggle.Position = UDim2.new(0.5, 6, 0, 0)
    autoPlayToggle.BackgroundColor3 = Theme.Disabled
    autoPlayToggle.BorderSizePixel = 1
    autoPlayToggle.BorderColor3 = Theme.Border
    autoPlayToggle.Text = "Auto Play Macro: Off"
    autoPlayToggle.TextColor3 = Theme.Text
    autoPlayToggle.Font = Enum.Font.GothamBold
    autoPlayToggle.TextSize = 11
    autoPlayToggle.Parent = replayFrame

    local shareRow = Instance.new("Frame")
    shareRow.Size = UDim2.new(1, 0, 0, 32)
    shareRow.BackgroundTransparency = 1
    shareRow.Parent = module

    local shareLayout = Instance.new("UIListLayout")
    shareLayout.FillDirection = Enum.FillDirection.Horizontal
    shareLayout.Padding = UDim.new(0, 6)
    shareLayout.Parent = shareRow

    local exportMacroButton = createButton(shareRow, "Export Macro", 0.30)
    local exportAllButton = createButton(shareRow, "Export All", 0.30)
    local importButton = createButton(shareRow, "Import", 0.30)

    local shareBox = Instance.new("TextBox")
    shareBox.Size = UDim2.new(1, 0, 0, 120)
    shareBox.BackgroundColor3 = Theme.PanelSecondary
    shareBox.BorderSizePixel = 1
    shareBox.BorderColor3 = Theme.Border
    shareBox.Text = "GHM1:"
    shareBox.TextColor3 = Theme.TextSecondary
    shareBox.TextWrapped = true
    shareBox.MultiLine = true
    shareBox.Font = Enum.Font.Gotham
    shareBox.TextSize = 11
    shareBox.Parent = module

    local shareCorner = Instance.new("UICorner")
    shareCorner.CornerRadius = UDim.new(0, 10)
    shareCorner.Parent = shareBox

    local logPanel = Instance.new("TextBox")
    logPanel.Size = UDim2.new(1, 0, 0, 110)
    logPanel.BackgroundColor3 = Theme.PanelSecondary
    logPanel.BorderSizePixel = 1
    logPanel.BorderColor3 = Theme.Border
    logPanel.Text = "Macro log ready"
    logPanel.TextColor3 = Theme.TextSecondary
    logPanel.Font = Enum.Font.Gotham
    logPanel.TextSize = 11
    logPanel.TextWrapped = true
    logPanel.MultiLine = true
    logPanel.TextEditable = false
    logPanel.ClearTextOnFocus = false
    logPanel.Parent = module

    local logCorner = Instance.new("UICorner")
    logCorner.CornerRadius = UDim.new(0, 10)
    logCorner.Parent = logPanel

    local function refreshAll()
        refreshSelector(module)
        updateStatusDisplay(module)
        refreshLog(module)
    end

    connect(createButton.MouseButton1Click, function()
        local name = nameInput.Text or ""
        local ok, message = MacroManager:Create(name)
        if ok then
            State:Set("SelectedMacro", name)
            MacroManager:SetSelected(name)
            refreshAll()
            Logger:Success("Macro created: " .. tostring(name))
        else
            Logger:Error(message or "Failed to create macro.")
        end
    end)

    connect(saveButton.MouseButton1Click, function()
        local selected = MacroManager:GetSelected()
        if not selected then
            Logger:Error("No macro selected to save.")
            return
        end

        local ok, message = MacroManager:Save(selected)
        if ok then
            refreshAll()
            Logger:Success("Macro saved: " .. tostring(selected.name))
        else
            Logger:Error(message or "Save failed.")
        end
    end)

    connect(loadButton.MouseButton1Click, function()
        local name = State:Get("SelectedMacro") or nameInput.Text or ""
        if name == "" then
            Logger:Error("Select a macro to load.")
            return
        end

        local macro = MacroManager:Load(name)
        if macro then
            setTextInputValue(nameInput, macro.name)
            State:Set("SelectedMacro", macro.name)
            State:Set("Actions", #(macro.actions or {}))
            refreshAll()
            Logger:Info("Macro loaded: " .. tostring(macro.name))
        else
            Logger:Error("Macro not found: " .. tostring(name))
        end
    end)

    connect(deleteButton.MouseButton1Click, function()
        local selected = State:Get("SelectedMacro") or ""
        if selected == "" then
            Logger:Warning("No macro selected to delete.")
            return
        end

        local ok = MacroManager:Delete(selected)
        if ok then
            State:Set("SelectedMacro", "")
            setTextInputValue(nameInput, "")
            refreshAll()
            Logger:Warning("Macro deleted: " .. tostring(selected))
        end
    end)

    connect(duplicateButton.MouseButton1Click, function()
        local selected = State:Get("SelectedMacro") or ""
        if selected == "" then
            Logger:Warning("No macro selected to duplicate.")
            return
        end

        local copy = MacroManager:Duplicate(selected)
        if copy then
            State:Set("SelectedMacro", copy.name)
            setTextInputValue(nameInput, copy.name)
            refreshAll()
            Logger:Success("Macro duplicated: " .. tostring(copy.name))
        end
    end)

    connect(startRecordButton.MouseButton1Click, function()
        local selected = State:Get("SelectedMacro") or ""
        if selected == "" then
            Logger:Warning("Select a macro before recording.")
            return
        end

        Recorder:Start(selected)
        State:Set("SelectedMacro", selected)
        refreshAll()
    end)

    connect(pauseRecordButton.MouseButton1Click, function()
        Recorder:Pause()
        refreshAll()
    end)

    connect(resumeRecordButton.MouseButton1Click, function()
        Recorder:Resume()
        refreshAll()
    end)

    connect(stopSaveButton.MouseButton1Click, function()
        local macro = Recorder:Stop()
        if type(macro) == "table" then
            local selected = State:Get("SelectedMacro") or macro.name or ""
            macro.name = selected ~= "" and selected or macro.name
            local ok = MacroManager:Save(macro)
            if ok then
                State:Set("MacroStatus", "Saved")
                refreshAll()
                Logger:Success("Recording stopped and macro saved.")
            else
                Logger:Error("Failed to save recorded macro.")
            end
        end
    end)

    connect(playButton.MouseButton1Click, function()
        local selected = State:Get("SelectedMacro") or ""
        if selected == "" then
            Logger:Warning("Select a macro to play.")
            return
        end

        local macro = MacroManager:Load(selected)
        if macro then
            Player:Load(macro)
            Player:Start()
            refreshAll()
        end
    end)

    connect(pausePlaybackButton.MouseButton1Click, function()
        Player:Pause()
        refreshAll()
    end)

    connect(resumePlaybackButton.MouseButton1Click, function()
        Player:Resume()
        refreshAll()
    end)

    connect(stopPlaybackButton.MouseButton1Click, function()
        Player:Stop()
        refreshAll()
    end)

    connect(replayMode.MouseButton1Click, function()
        if Player.RepeatEnabled then
            Player:SetRepeat(false)
            replayMode.Text = "Replay Mode: Once"
        else
            Player:SetRepeat(true)
            replayMode.Text = "Replay Mode: Repeat"
        end

        State:Set("ReplayMode", Player.RepeatEnabled and "Repeat" or "Once")
        refreshAll()
    end)

    connect(autoPlayToggle.MouseButton1Click, function()
        local enabled = State:Get("AutoPlayMacro") == true
        enabled = not enabled
        State:Set("AutoPlayMacro", enabled)
        autoPlayToggle.Text = enabled and "Auto Play Macro: On" or "Auto Play Macro: Off"
        autoPlayToggle.BackgroundColor3 = enabled and Theme.Blue or Theme.Disabled
        refreshAll()
    end)

    connect(exportMacroButton.MouseButton1Click, function()
        local selected = State:Get("SelectedMacro") or ""
        if selected == "" then
            Logger:Warning("Select a macro to export.")
            return
        end

        local code, err = Exporter:ExportMacro(selected)
        if code then
            shareBox.Text = code
            refreshAll()
        else
            Logger:Error(err or "Export failed.")
        end
    end)

    connect(exportAllButton.MouseButton1Click, function()
        local results = Exporter:ExportAllMacros() or {}
        local values = {}
        for _, item in ipairs(results) do
            table.insert(values, string.format("%s: %s", item.name or "Macro", item.code or ""))
        end

        shareBox.Text = table.concat(values, "\n")
        refreshAll()
    end)

    connect(importButton.MouseButton1Click, function()
        local code = shareBox.Text or ""
        local macro, err = Importer:Import(code, "rename")
        if macro then
            State:Set("SelectedMacro", macro.name)
            MacroManager:SetSelected(macro.name)
            refreshAll()
            Logger:Success("Macro imported: " .. tostring(macro.name))
        else
            Logger:Error(err or "Import failed.")
        end
    end)

    selectorDropdown:OnChanged(function(selectedName)
        if not selectedName or selectedName == "" then return end
        State:Set("SelectedMacro", selectedName)
        MacroManager:SetSelected(selectedName)
        setTextInputValue(nameInput, selectedName)
        refreshAll()
    end)

    local subscriptions = {}
    local function subscribe(key, callback)
        State:Subscribe(key, callback)
        table.insert(subscriptions, { key, callback })
    end
    subscribe("SelectedMacro", function()
        refreshAll()
    end)
    subscribe("MacroStatus", function()
        refreshAll()
    end)
    subscribe("Actions", function()
        refreshAll()
    end)
    subscribe("Cash", function()
        refreshAll()
    end)
    subscribe("Wave", function()
        refreshAll()
    end)
    subscribe("Time", function()
        refreshAll()
    end)

    local loggerSubscription = Logger:Subscribe(function()
        refreshLog(module)
    end)

    module.StatusLabel = statusLabel
    module.LogPanel = logPanel
    module.NameInput = nameInput
    module.SelectorDropdown = selectorDropdown
    module.Cleanup = function()
        for _, subscription in ipairs(subscriptions) do
            State:Unsubscribe(subscription[1], subscription[2])
        end
        selectorDropdown:Destroy()
        Logger:Unsubscribe(loggerSubscription)
        loggerSubscription = nil
        for _, connection in ipairs(module.Connections or {}) do
            if connection.Connected then connection:Disconnect() end
        end
        module.Connections = {}
    end

    refreshAll()
    return module
end

return MacroUI
