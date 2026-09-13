local MainUI = {}
MainUI.__index = MainUI

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local Theme = ModuleLoader:Require("ui.Theme")
local State = ModuleLoader:Require("core.State")
local Logger = ModuleLoader:Require("core.Logger")
local Automation = ModuleLoader:Require("ui.Automation")
local MacroUI = ModuleLoader:Require("ui.MacroUI")

local function createInstance(className, properties)
    local instance = Instance.new(className)
    for key, value in pairs(properties or {}) do
        instance[key] = value
    end
    return instance
end

function MainUI:Track(connection)
    if connection then table.insert(self.Connections, connection) end
    return connection
end

function MainUI:SubscribeState(key, callback)
    State:Subscribe(key, callback)
    table.insert(self.StateSubscriptions, { key, callback })
end

function MainUI:RefreshStatus()
    if self.StatusLabel then self.StatusLabel.Text = string.format("Location: %s | Mode: %s | Speed: %s", tostring(State:Get("Location", "Lobby")), tostring(State:Get("Mode", "OFF")), tostring(State:Get("Speed", "x1"))) end
end

function MainUI:BuildTabs()
    if not self.Frame or not self.Content then
        return
    end

    if self.TabContent then
        return
    end

    local tabContent = createInstance("Frame", {
        Name = "TabContent",
        Position = UDim2.new(0, 0, 0, 52),
        Size = UDim2.new(1, 0, 1, -52),
        BackgroundTransparency = 1,
    })
    tabContent.Parent = self.Content
    self.TabContent = tabContent

    local tabButtons = createInstance("Frame", {
        Name = "TabButtons",
        Size = UDim2.new(1, -12, 0, 30),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundTransparency = 1,
    })
    tabButtons.Parent = self.TabContainer

    local tabLayout = createInstance("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    tabLayout.Parent = tabButtons

    local tabData = {
        { label = "Automation", build = function(parent)
            return Automation:Build(parent)
        end },
        { label = "Macros", build = function(parent)
            return MacroUI:Build(parent)
        end },
    }

    self.Tabs = {}
    for index, tab in ipairs(tabData) do
        local button = createInstance("TextButton", {
            Name = tab.label,
            Size = UDim2.new(0, 110, 1, 0),
            BackgroundColor3 = index == 1 and Theme.Blue or Theme.Panel,
            BorderSizePixel = 1,
            BorderColor3 = Theme.Border,
            Text = tab.label,
            TextColor3 = Theme.Text,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
        })
        local buttonCorner = createInstance("UICorner", { CornerRadius = UDim.new(0, 8) })
        buttonCorner.Parent = button
        button.Parent = tabButtons

        local contentPanel = tab.build(tabContent)
        contentPanel.Visible = index == 1
        self.Tabs[tab.label] = {
            button = button,
            panel = contentPanel,
        }

        self:Track(button.MouseButton1Click:Connect(function()
            self:SelectTab(tab.label)
        end))
    end

    self:SelectTab("Automation")
end

function MainUI:SelectTab(tabName)
    if type(self.Tabs) ~= "table" then
        return
    end

    for name, tab in pairs(self.Tabs) do
        if tab.button and tab.panel then
            local isActive = name == tabName
            tab.button.BackgroundColor3 = isActive and Theme.Blue or Theme.Panel
            tab.button.BorderColor3 = isActive and Theme.Border or Theme.Border
            tab.panel.Visible = isActive
        end
    end
end

function MainUI:Create()
    if self.Frame and self.Frame.Parent then
        self:BuildTabs()
        return self.Frame
    end

    local screenGui = createInstance("ScreenGui", {
        Name = "GardenHubGui",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

    local frame = createInstance("Frame", {
        Name = "MainFrame",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 440, 0, 540),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Border,
    })
    frame.Parent = screenGui

    local restoreButton = createInstance("TextButton", {
        Name = "RestoreButton",
        Size = UDim2.new(0, 48, 0, 30),
        Position = UDim2.new(0, 12, 0.5, 0),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Blue,
        Text = "SKL",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        Visible = false,
    })
    restoreButton.Parent = screenGui

    local corner = createInstance("UICorner", { CornerRadius = UDim.new(0, 12) })
    corner.Parent = frame

    local shadow = createInstance("ImageLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        Image = "rbxassetid://131604521",
        ImageColor3 = Theme.Shadow,
        ImageTransparency = 0.7,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(10, 10, 118, 118),
    })
    shadow.Parent = frame

    local titleBar = createInstance("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.PanelSecondary,
        BorderSizePixel = 0,
    })
    titleBar.Parent = frame

    local titleLabel = createInstance("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Garden Hub",
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold,
        TextSize = 15,
    })
    titleLabel.Parent = titleBar

    local closeButton = createInstance("TextButton", {
        Name = "Close",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -30, 0.5, -12),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Border,
        Text = "X",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
    })
    closeButton.Parent = titleBar
    local closeCorner = createInstance("UICorner", { CornerRadius = UDim.new(0, 8) })
    closeCorner.Parent = closeButton

    local minimizeButton = createInstance("TextButton", {
        Name = "Minimize",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -58, 0.5, -12),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Border,
        Text = "_",
        TextColor3 = Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
    })
    minimizeButton.Parent = titleBar
    local minimizeCorner = createInstance("UICorner", { CornerRadius = UDim.new(0, 8) })
    minimizeCorner.Parent = minimizeButton

    local content = createInstance("Frame", {
        Name = "Content",
        Position = UDim2.new(0, 0, 0, 32),
        Size = UDim2.new(1, 0, 1, -32),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
    })
    content.Parent = frame

    local tabContainer = createInstance("Frame", {
        Name = "TabContainer",
        Size = UDim2.new(1, -12, 0, 38),
        Position = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = Theme.PanelSecondary,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Border,
    })
    tabContainer.Parent = content
    local tabCorner = createInstance("UICorner", { CornerRadius = UDim.new(0, 10) })
    tabCorner.Parent = tabContainer

    local tabFolder = createInstance("Folder", { Name = "Tabs" })
    tabFolder.Parent = content

    self.Frame = frame
    self.ScreenGui = screenGui
    self.CloseButton = closeButton
    self.MinimizeButton = minimizeButton
    self.RestoreButton = restoreButton
    self.Connections = {}
    self.StateSubscriptions = {}
    self.Content = content
    self.TabContainer = tabContainer
    self.TabFolder = tabFolder

    self:Track(closeButton.MouseButton1Click:Connect(function()
        self:Destroy()
    end))

    self:Track(minimizeButton.MouseButton1Click:Connect(function() frame.Visible = false; restoreButton.Visible = true end))
    self:Track(restoreButton.MouseButton1Click:Connect(function() frame.Visible = true; restoreButton.Visible = false end))

    local dragging = false
    local dragStart
    local startPosition
    self:Track(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragStart = input.Position
            startPosition = frame.Position
            dragging = true
        end
    end))
    self:Track(titleBar.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement and dragStart and startPosition then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end))
    self:Track(titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false; dragStart = nil; startPosition = nil end
    end))

    self:SubscribeState("Location", function() self:RefreshStatus() end)

    self:SubscribeState("Mode", function() self:RefreshStatus() end)

    self:SubscribeState("Speed", function() self:RefreshStatus() end)

    self.StatusLabel = createInstance("TextLabel", {
        Name = "StatusLabel",
        Position = UDim2.new(0, 12, 0, 48),
        Size = UDim2.new(1, -24, 0, 30),
        BackgroundTransparency = 1,
        TextColor3 = Theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        Text = "Location: Lobby | Mode: OFF | Speed: x1",
    })
    self.StatusLabel.Parent = content

    self.LoggerSubscription = Logger:Subscribe(function(entry)
        if self.LogPreview then
            local nextText = string.format("[%s] %s %s", entry.timestamp, entry.level, entry.message)
            self.LogLines = self.LogLines or {}
            table.insert(self.LogLines, nextText)
            while #self.LogLines > 50 do table.remove(self.LogLines, 1) end
            self.LogPreview.Text = table.concat(self.LogLines, "\n")
        end
    end)

    self.LogPreview = createInstance("TextBox", {
        Name = "LogPreview",
        Position = UDim2.new(0, 12, 1, -100),
        Size = UDim2.new(1, -24, 0, 72),
        BackgroundColor3 = Theme.PanelSecondary,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Border,
        TextColor3 = Theme.TextSecondary,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        ClearTextOnFocus = false,
        MultiLine = true,
        Text = "",
        TextEditable = false,
        TextWrapped = true,
        PlaceholderText = "Garden Hub log preview",
    })
    self.LogPreview.Parent = content
    local previewCorner = createInstance("UICorner", { CornerRadius = UDim.new(0, 10) })
    previewCorner.Parent = self.LogPreview

    self:BuildTabs()

    return frame
end

function MainUI:ToggleMinimize()
    if not self.Frame then
        return
    end

    local isVisible = self.Frame.Visible ~= false
    self.Frame.Visible = not isVisible
    self.MinimizeButton.Text = isVisible and "▢" or "_"
end

function MainUI:Destroy()
    if self.Tabs then
        for _, tab in pairs(self.Tabs) do
            if tab.panel and tab.panel.Cleanup then tab.panel.Cleanup() end
        end
    end
    for _, connection in ipairs(self.Connections or {}) do
        if connection.Connected then connection:Disconnect() end
    end
    self.Connections = {}
    for _, subscription in ipairs(self.StateSubscriptions or {}) do
        State:Unsubscribe(subscription[1], subscription[2])
    end
    self.StateSubscriptions = {}
    if self.LoggerSubscription then Logger:Unsubscribe(self.LoggerSubscription); self.LoggerSubscription = nil end
    if self.ScreenGui then
        self.ScreenGui:Destroy()
    end
    self.Frame = nil
    self.ScreenGui = nil
end

return MainUI
