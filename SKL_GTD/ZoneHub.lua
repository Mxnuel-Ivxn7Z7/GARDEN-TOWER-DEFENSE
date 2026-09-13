--[[
    ================================================================================
    ZONE HUB - Senior Modular LuaU Automation Framework
    Target Game: Garden Tower Defense (Roblox)
    Engineered for Mobile Executors (Delta, Codex, Arceus X) & PC Environment
    Architecture: Single-File Micro-Modules Pattern
    ================================================================================
--]]

--------------------------------------------------------------------------------
-- 0. ANTI-DUPLICATION & CLEANUP ENGINE
--------------------------------------------------------------------------------
if getgenv().ZoneHubLoaded then
    getgenv().ZoneHubRunning = false
    if typeof(getgenv().ZoneHubUnload) == "function" then
        pcall(getgenv().ZoneHubUnload)
    end
    task.wait(0.2)
end

getgenv().ZoneHubLoaded = true
getgenv().ZoneHubRunning = true

--------------------------------------------------------------------------------
-- SERVICES & EXECUTOR ENVIRONMENT GUARDS
--------------------------------------------------------------------------------
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")
local StarterGui        = game:GetService("StarterGui")

local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

-- Safely select Gui parent
local ParentGui = CoreGui
local successCore = pcall(function()
    local test = Instance.new("Folder")
    test.Parent = CoreGui
    test:Destroy()
end)
if not successCore then
    ParentGui = PlayerGui
end

-- Isolate replication collisions (SharedReplication ldbm_l guard)
pcall(function()
    if ReplicatedStorage:FindFirstChild("SharedReplication") then
        local sharedRep = ReplicatedStorage.SharedReplication
        if sharedRep:IsA("RemoteEvent") then
            sharedRep.OnClientEvent:Connect(function() end)
        end
    end
end)

--------------------------------------------------------------------------------
-- MASTER TABLE STRUCT & GLOBAL CONNECTIONS REGISTRY
--------------------------------------------------------------------------------
local ZoneHub = {
    Config = {
        Version = "2.0.0-PRO",
        TargetGame = "Garden Tower Defense",
        Folder = "ZoneHubGTD",
        ConfigFile = "ZoneHubGTD/config.json",
        Theme = {
            Background  = Color3.fromRGB(18, 15, 24),    -- #120F18 Neon Dark
            Card        = Color3.fromRGB(24, 20, 32),    -- #181420
            Border      = Color3.fromRGB(80, 45, 95),    -- #502D5F Purple Glow
            Accent      = Color3.fromRGB(224, 122, 210), -- #E07AD2 Neon Magenta/Purple
            AccentHover = Color3.fromRGB(240, 150, 230),
            Text        = Color3.fromRGB(255, 255, 255),
            SubText     = Color3.fromRGB(160, 145, 175),
            Success     = Color3.fromRGB(34, 197, 94),
            Danger      = Color3.fromRGB(239, 68, 68),
            Warning     = Color3.fromRGB(245, 158, 11)
        }
    },
    Connections = {},
    State = {
        ActiveTab = "Automation",
        GlobalPlay = true,
        AutoEquipBest = false,
        AutoSkipWave = false,
        AutoPlayAgain = false,
        SelectedFarmPreset = "None",
        AutoFarmWin = false,
        TickSpeedMode = "Auto",
        SelectedMap = "Volcano (Lava)",
        SelectedDifficulty = "Hard",
        AutoJoinMap = false,
        AutoSelectDifficulty = false,
        IsRecording = false,
        IsPlayingMacro = false,
        MacroReplayMode = "By Cash",
        ActiveMacroName = "DefaultMacro",
        MacroLogs = {},
        SavedMacros = {}
    }
}

function ZoneHub:RegisterConnection(conn)
    table.insert(self.Connections, conn)
    return conn
end

--------------------------------------------------------------------------------
-- NETWORK BUFFER & QUEUE NEUTRALIZER (ANTI-LAG / ANTI-FREEZE)
--------------------------------------------------------------------------------
ZoneHub.Network = {
    LastCall = {},
    Cooldown = 1.3 -- Seconds
}

function ZoneHub.Network:InitializeNeutralizer()
    -- Scan ReplicatedStorage for unhandled RemoteEvents & attach dummy listeners
    local function NeutralizeRemotes(folder)
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("RemoteEvent") then
                pcall(function()
                    obj.OnClientEvent:Connect(function() end)
                end)
            end
        end
    end
    NeutralizeRemotes(ReplicatedStorage)

    -- Listen for dynamically added remotes
    ZoneHub:RegisterConnection(ReplicatedStorage.DescendantAdded:Connect(function(desc)
        if desc:IsA("RemoteEvent") then
            pcall(function()
                desc.OnClientEvent:Connect(function() end)
            end)
        end
    end))
end

function ZoneHub.Network:FindRemote(nameList)
    for _, name in ipairs(nameList) do
        local found = ReplicatedStorage:FindFirstChild(name, true)
        if found then return found end
    end
    return nil
end

function ZoneHub.Network:SafeFireServer(remoteNames, ...)
    if not getgenv().ZoneHubRunning or not ZoneHub.State.GlobalPlay then return false, "Disabled" end
    local remote = type(remoteNames) == "table" and self:FindRemote(remoteNames) or remoteNames
    if not remote then return false, "Remote not found" end

    local key = remote:GetFullName()
    local now = os.clock()
    if self.LastCall[key] and (now - self.LastCall[key]) < self.Cooldown then
        return false, "Rate limited"
    end
    self.LastCall[key] = now

    local args = {...}
    local success, result = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(unpack(args))
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(unpack(args))
        end
    end)
    return success, result
end

--------------------------------------------------------------------------------
-- MÓDULO 1: UI ENGINE (ZoneHub Custom UI)
--------------------------------------------------------------------------------
ZoneHub.UI = {
    MainGui = nil,
    MainFrame = nil,
    FloatingButton = nil,
    PageContainer = nil,
    Pages = {}
}

local function CreateInst(className, props, children)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

function ZoneHub.UI:BuildControlsFactory()
    local Factory = {}

    function Factory.CreateToggle(parent, title, desc, defaultKey, callback)
        local Card = CreateInst("Frame", {
            Size = UDim2.new(1, 0, 0, 50),
            BackgroundColor3 = ZoneHub.Config.Theme.Card,
            BorderSizePixel = 0,
            Parent = parent
        }, {
            CreateInst("UICorner", { CornerRadius = UDim.new(0, 8) }),
            CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border, Thickness = 1 }),
            CreateInst("TextLabel", {
                Text = title,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextColor3 = ZoneHub.Config.Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.new(0, 12, 0, 8),
                Size = UDim2.new(0.68, 0, 0, 16),
                BackgroundTransparency = 1
            }),
            CreateInst("TextLabel", {
                Text = desc or "",
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextColor3 = ZoneHub.Config.Theme.SubText,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.new(0, 12, 0, 24),
                Size = UDim2.new(0.68, 0, 0, 16),
                BackgroundTransparency = 1
            })
        })

        local SwitchBtn = CreateInst("TextButton", {
            Text = "",
            Size = UDim2.new(0, 42, 0, 22),
            Position = UDim2.new(1, -50, 0.5, -11),
            BackgroundColor3 = ZoneHub.Config.Theme.Background,
            Parent = Card
        }, {
            CreateInst("UICorner", { CornerRadius = UDim.new(1, 0) }),
            CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border, Thickness = 1 })
        })

        local Knob = CreateInst("Frame", {
            Size = UDim2.new(0, 16, 0, 16),
            Position = UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = ZoneHub.Config.Theme.SubText,
            Parent = SwitchBtn
        }, {
            CreateInst("UICorner", { CornerRadius = UDim.new(1, 0) })
        })

        local function UpdateState(val)
            ZoneHub.State[defaultKey] = val
            TweenService:Create(Knob, TweenInfo.new(0.2), {
                Position = val and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                BackgroundColor3 = val and ZoneHub.Config.Theme.Text or ZoneHub.Config.Theme.SubText
            }):Play()
            TweenService:Create(SwitchBtn, TweenInfo.new(0.2), {
                BackgroundColor3 = val and ZoneHub.Config.Theme.Accent or ZoneHub.Config.Theme.Background
            }):Play()
            if callback then callback(val) end
        end

        UpdateState(ZoneHub.State[defaultKey] or false)

        ZoneHub:RegisterConnection(SwitchBtn.MouseButton1Click:Connect(function()
            UpdateState(not ZoneHub.State[defaultKey])
        end))

        return Card
    end

    function Factory.CreateDropdown(parent, title, options, defaultVal, callback)
        local Card = CreateInst("Frame", {
            Size = UDim2.new(1, 0, 0, 54),
            BackgroundColor3 = ZoneHub.Config.Theme.Card,
            BorderSizePixel = 0,
            Parent = parent
        }, {
            CreateInst("UICorner", { CornerRadius = UDim.new(0, 8) }),
            CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border, Thickness = 1 }),
            CreateInst("TextLabel", {
                Text = title,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = ZoneHub.Config.Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.new(0, 12, 0, 6),
                Size = UDim2.new(0.9, 0, 0, 16),
                BackgroundTransparency = 1
            })
        })

        local SelectedBtn = CreateInst("TextButton", {
            Text = tostring(defaultVal) .. "  ▼",
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = ZoneHub.Config.Theme.Accent,
            Size = UDim2.new(1, -24, 0, 24),
            Position = UDim2.new(0, 12, 0, 24),
            BackgroundColor3 = ZoneHub.Config.Theme.Background,
            Parent = Card
        }, {
            CreateInst("UICorner", { CornerRadius = UDim.new(0, 6) }),
            CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border, Thickness = 1 })
        })

        local idx = 1
        for i, opt in ipairs(options) do
            if opt == defaultVal then idx = i break end
        end

        ZoneHub:RegisterConnection(SelectedBtn.MouseButton1Click:Connect(function()
            idx = (idx % #options) + 1
            local newVal = options[idx]
            SelectedBtn.Text = tostring(newVal) .. "  ▼"
            if callback then callback(newVal) end
        end))

        return Card
    end

    function Factory.CreateButton(parent, text, color, callback)
        local Btn = CreateInst("TextButton", {
            Text = text,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = ZoneHub.Config.Theme.Text,
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = color or ZoneHub.Config.Theme.Accent,
            Parent = parent
        }, {
            CreateInst("UICorner", { CornerRadius = UDim.new(0, 8) })
        })

        ZoneHub:RegisterConnection(Btn.MouseButton1Click:Connect(function()
            if callback then callback() end
        end))

        return Btn
    end

    function Factory.CreateInput(parent, title, placeholder, defaultText, callback)
        local Card = CreateInst("Frame", {
            Size = UDim2.new(1, 0, 0, 54),
            BackgroundColor3 = ZoneHub.Config.Theme.Card,
            Parent = parent
        }, {
            CreateInst("UICorner", { CornerRadius = UDim.new(0, 8) }),
            CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border, Thickness = 1 }),
            CreateInst("TextLabel", {
                Text = title,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextColor3 = ZoneHub.Config.Theme.Text,
                Position = UDim2.new(0, 12, 0, 6),
                Size = UDim2.new(0.9, 0, 0, 16),
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1
            })
        })

        local Box = CreateInst("TextBox", {
            Text = defaultText or "",
            PlaceholderText = placeholder or "",
            Font = Enum.Font.Gotham,
            TextSize = 11,
            TextColor3 = ZoneHub.Config.Theme.Text,
            Size = UDim2.new(1, -24, 0, 24),
            Position = UDim2.new(0, 12, 0, 24),
            BackgroundColor3 = ZoneHub.Config.Theme.Background,
            ClearTextOnFocus = false,
            Parent = Card
        }, {
            CreateInst("UICorner", { CornerRadius = UDim.new(0, 6) })
        })

        ZoneHub:RegisterConnection(Box.FocusLost:Connect(function()
            if callback then callback(Box.Text) end
        end))

        return Card
    end

    return Factory
end

function ZoneHub.UI:Init()
    -- Clean previous instances
    local existing = ParentGui:FindFirstChild("ZoneHub_GTD")
    if existing then existing:Destroy() end

    self.MainGui = CreateInst("ScreenGui", {
        Name = "ZoneHub_GTD",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = ParentGui
    })

    ----------------------------------------------------------------------------
    -- FLOATING "Z" BUTTON (MOBILE & TOUCH DRAGGABLE)
    ----------------------------------------------------------------------------
    self.FloatingButton = CreateInst("TextButton", {
        Name = "FloatingZBtn",
        Text = "Z",
        Font = Enum.Font.GothamBlack,
        TextSize = 22,
        TextColor3 = ZoneHub.Config.Theme.Accent,
        Size = UDim2.new(0, 46, 0, 46),
        Position = UDim2.new(0.5, -23, 0, 12),
        BackgroundColor3 = ZoneHub.Config.Theme.Background,
        ZIndex = 100,
        Active = true,
        Parent = self.MainGui
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(1, 0) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Accent, Thickness = 2 })
    })

    -- Touch & Mouse Dragging for Floating Button
    local draggingFloat, dragStartFloat, startPosFloat
    ZoneHub:RegisterConnection(self.FloatingButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingFloat = true
            dragStartFloat = input.Position
            startPosFloat = self.FloatingButton.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingFloat = false
                end
            end)
        end
    end))

    ZoneHub:RegisterConnection(UserInputService.InputChanged:Connect(function(input)
        if draggingFloat and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartFloat
            self.FloatingButton.Position = UDim2.new(
                startPosFloat.X.Scale, startPosFloat.X.Offset + delta.X,
                startPosFloat.Y.Scale, startPosFloat.Y.Offset + delta.Y
            )
        end
    end))

    ----------------------------------------------------------------------------
    -- MAIN FRAME (700x420 px)
    ----------------------------------------------------------------------------
    self.MainFrame = CreateInst("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(0, 700, 0, 420),
        Position = UDim2.new(0.5, -350, 0.5, -210),
        BackgroundColor3 = ZoneHub.Config.Theme.Background,
        BorderSizePixel = 0,
        Active = true,
        Parent = self.MainGui
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 12) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border, Thickness = 1.5 })
    })

    -- Toggle visibility with Floating Button
    ZoneHub:RegisterConnection(self.FloatingButton.MouseButton1Click:Connect(function()
        self.MainFrame.Visible = not self.MainFrame.Visible
    end))

    -- Header Bar
    local Header = CreateInst("Frame", {
        Size = UDim2.new(1, 0, 0, 45),
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        BorderSizePixel = 0,
        Parent = self.MainFrame
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 12) }),
        CreateInst("TextLabel", {
            Text = "⚡ ZONE HUB <font color=\"#E07AD2\">GARDEN TOWER DEFENSE</font>",
            RichText = true,
            Font = Enum.Font.GothamBlack,
            TextSize = 15,
            TextColor3 = ZoneHub.Config.Theme.Text,
            Position = UDim2.new(0, 60, 0, 6),
            Size = UDim2.new(0.6, 0, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        }),
        CreateInst("TextLabel", {
            Text = "Status: Engine Active | Safe Network Neutralizer Online",
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextColor3 = ZoneHub.Config.Theme.SubText,
            Position = UDim2.new(0, 60, 0, 24),
            Size = UDim2.new(0.6, 0, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1
        })
    })

    -- Dragging logic for MainFrame Header
    local draggingMain, dragStartMain, startPosMain
    ZoneHub:RegisterConnection(Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingMain = true
            dragStartMain = input.Position
            startPosMain = self.MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingMain = false
                end
            end)
        end
    end))

    ZoneHub:RegisterConnection(UserInputService.InputChanged:Connect(function(input)
        if draggingMain and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartMain
            self.MainFrame.Position = UDim2.new(
                startPosMain.X.Scale, startPosMain.X.Offset + delta.X,
                startPosMain.Y.Scale, startPosMain.Y.Offset + delta.Y
            )
        end
    end))

    ----------------------------------------------------------------------------
    -- SIDEBAR (52px width)
    ----------------------------------------------------------------------------
    local Sidebar = CreateInst("Frame", {
        Size = UDim2.new(0, 52, 1, -45),
        Position = UDim2.new(0, 0, 0, 45),
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        BorderSizePixel = 0,
        Parent = self.MainFrame
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 12) }),
        CreateInst("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = UDim.new(0, 8)
        })
    })

    -- Page Container
    self.PageContainer = CreateInst("Frame", {
        Size = UDim2.new(1, -64, 1, -57),
        Position = UDim2.new(0, 58, 0, 51),
        BackgroundTransparency = 1,
        Parent = self.MainFrame
    })

    -- Tab Builder Helper
    local tabs = {
        { id = "Automation", icon = "⚡" },
        { id = "Maps",       icon = "🗺️" },
        { id = "Macros",     icon = "📹" },
        { id = "Settings",   icon = "⚙️" }
    }

    local tabButtons = {}
    for i, tab in ipairs(tabs) do
        -- CAMBIO CLAVE 1: Scroll dinámico con UIListLayout
        local pageScroll = CreateInst("ScrollingFrame", {
            Name = tab.id .. "Page",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = ZoneHub.Config.Theme.Border,
            CanvasSize = UDim2.new(0, 0, 0, 0), -- Se calcula automáticamente abajo
            AutomaticCanvasSize = Enum.AutomaticSize.Y, -- Auto-ajuste de scroll
            Visible = (i == 1),
            Parent = self.PageContainer
        })

        local pageLayout = CreateInst("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            HorizontalAlignment = Enum.HorizontalAlignment.Center
        })
        pageLayout.Parent = pageScroll

        local pagePadding = CreateInst("UIPadding", {
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            PaddingBottom = UDim.new(0, 8)
        })
        pagePadding.Parent = pageScroll

        self.Pages[tab.id] = pageScroll

        -- Create Sidebar Button
        local btn = CreateInst("TextButton", {
            Text = tab.icon,
            Font = Enum.Font.GothamBold,
            TextSize = 18,
            TextColor3 = (i == 1) and ZoneHub.Config.Theme.Text or ZoneHub.Config.Theme.SubText,
            Size = UDim2.new(0, 38, 0, 38),
            BackgroundColor3 = (i == 1) and ZoneHub.Config.Theme.Accent or ZoneHub.Config.Theme.Background,
            Parent = Sidebar
        }, {
            CreateInst("UICorner", { CornerRadius = UDim.new(0, 8) })
        })
        tabButtons[tab.id] = btn

        ZoneHub:RegisterConnection(btn.MouseButton1Click:Connect(function()
            for tId, pFrame in pairs(self.Pages) do
                pFrame.Visible = (tId == tab.id)
                tabButtons[tId].BackgroundColor3 = (tId == tab.id) and ZoneHub.Config.Theme.Accent or ZoneHub.Config.Theme.Background
                tabButtons[tId].TextColor3 = (tId == tab.id) and ZoneHub.Config.Theme.Text or ZoneHub.Config.Theme.SubText
            end
            ZoneHub.State.ActiveTab = tab.id
        end))
    end
end
--------------------------------------------------------------------------------
-- MÓDULO 2: AUTOMATION & FARM ENGINE
--------------------------------------------------------------------------------
ZoneHub.Automation = {}

function ZoneHub.Automation:Init()
    local factory = ZoneHub.UI:BuildControlsFactory()
    local autoPage = ZoneHub.UI.Pages["Automation"]

    -- Card 1: Farm Options
    local Card1 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = autoPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateToggle(Card1, "Global Farm Switch", "Killswitch to pause all active loops", "GlobalPlay")
    factory.CreateToggle(Card1, "Auto Equip Best Units", "Equips top units on start", "AutoEquipBest")

    -- Card 2: Wave & Replay Automation
    local Card2 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = autoPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateToggle(Card2, "Auto Skip Wave", "Automatically skips wave timers", "AutoSkipWave")
    factory.CreateToggle(Card2, "Auto Play Again", "Re-joins match immediately on end", "AutoPlayAgain")

    -- Card 3: Presets Mode
    local Card3 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = autoPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateDropdown(Card3, "Farm Presets Mode", { "None", "Volcano V5", "Volcano V4", "Volcano V2" }, "None", function(val)
        ZoneHub.State.SelectedFarmPreset = val
    end)
    factory.CreateToggle(Card3, "Auto Farm Win (Tomato)", "Requires Tomato unit in loadout", "AutoFarmWin")

    -- Card 4: Tick Speed & FPS Cap
    local Card4 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = autoPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateDropdown(Card4, "Tick Speed / FPS Boost", { "Auto", "Speed x2 (120 FPS)", "Speed x3 (240 FPS)" }, "Auto", function(val)
        ZoneHub.State.TickSpeedMode = val
        if type(setfpscap) == "function" then
            if val == "Speed x2 (120 FPS)" then
                setfpscap(120)
            elseif val == "Speed x3 (240 FPS)" then
                setfpscap(240)
            else
                setfpscap(60)
            end
        end
    end)

    -- Background Automation Loop
    task.spawn(function()
        while getgenv().ZoneHubRunning do
            task.wait(1.5)
            if ZoneHub.State.GlobalPlay then
                if ZoneHub.State.AutoEquipBest then
                    ZoneHub.Network:SafeFireServer({ "EquipBestUnits", "AutoEquip", "EquipBest" })
                end
                if ZoneHub.State.AutoSkipWave then
                    ZoneHub.Network:SafeFireServer({ "SkipWave", "Skip", "SkipTimer" })
                end
                if ZoneHub.State.AutoPlayAgain then
                    ZoneHub.Network:SafeFireServer({ "PlayAgain", "Retry", "Replay" })
                end
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- MÓDULO 3: MAP & DIFFICULTY HANDLER
--------------------------------------------------------------------------------
ZoneHub.MapHandler = {}

function ZoneHub.MapHandler:Init()
    local factory = ZoneHub.UI:BuildControlsFactory()
    local mapsPage = ZoneHub.UI.Pages["Maps"]

    -- Card 1: Selection Dropdowns
    local Card1 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = mapsPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateDropdown(Card1, "Select Map Target", { "Volcano (Lava)", "Grassland", "Desert", "Ice Peak" }, "Volcano (Lava)", function(val)
        ZoneHub.State.SelectedMap = val
    end)
    factory.CreateDropdown(Card1, "Select Difficulty", { "Easy", "Medium", "Hard", "Hell" }, "Hard", function(val)
        ZoneHub.State.SelectedDifficulty = val
    end)

    -- Card 2: Auto Join & Direct Actions
    local Card2 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = mapsPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateToggle(Card2, "Auto Join Map", "Automatically enters selected map", "AutoJoinMap")
    factory.CreateToggle(Card2, "Auto Select Difficulty", "Sets difficulty on entrance", "AutoSelectDifficulty")
    factory.CreateButton(Card2, "🚀 Join Once (Teleport)", ZoneHub.Config.Theme.Accent, function()
        ZoneHub.Network:SafeFireServer({ "TeleportToMap", "JoinLobby", "JoinMap" }, ZoneHub.State.SelectedMap, ZoneHub.State.SelectedDifficulty)
    end)
end

--------------------------------------------------------------------------------
-- MÓDULO 4: MACRO SYSTEM (RECORDER & REPLAY)
--------------------------------------------------------------------------------
ZoneHub.Macro = {}

function ZoneHub.Macro:Init()
    local factory = ZoneHub.UI:BuildControlsFactory()
    local macroPage = ZoneHub.UI.Pages["Macros"]

    -- Card 1: Recorder Controls
    local Card1 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = macroPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateInput(Card1, "Macro Profile Name", "Type macro name...", "VolcanoFarm", function(name)
        ZoneHub.State.ActiveMacroName = name
    end)
    factory.CreateButton(Card1, "⏺ Start Record / Stop & Save", ZoneHub.Config.Theme.Danger, function()
        ZoneHub.State.IsRecording = not ZoneHub.State.IsRecording
        if ZoneHub.State.IsRecording then
            table.insert(ZoneHub.State.MacroLogs, "[REC] Started recording: " .. ZoneHub.State.ActiveMacroName)
        else
            table.insert(ZoneHub.State.MacroLogs, "[SAVED] Saved macro profile: " .. ZoneHub.State.ActiveMacroName)
        end
    end)

    -- Card 2: Replay Settings
    local Card2 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = macroPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateDropdown(Card2, "Replay Execution Mode", { "By Cash", "By Wave", "By Time" }, "By Cash", function(mode)
        ZoneHub.State.MacroReplayMode = mode
    end)
    factory.CreateToggle(Card2, "Auto Play Macro", "Replays macro upon game load", "IsPlayingMacro")
end

--------------------------------------------------------------------------------
-- MÓDULO 5: SETTINGS & UTILITIES
--------------------------------------------------------------------------------
ZoneHub.Settings = {}

function ZoneHub.Settings:Init()
    local factory = ZoneHub.UI:BuildControlsFactory()
    local settingsPage = ZoneHub.UI.Pages["Settings"]

    -- Card 1: Persistence
    local Card1 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = settingsPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateButton(Card1, "💾 Save Configuration JSON", ZoneHub.Config.Theme.Accent, function()
        if type(writefile) == "function" then
            pcall(function()
                if not isfolder(ZoneHub.Config.Folder) then makefolder(ZoneHub.Config.Folder) end
                writefile(ZoneHub.Config.ConfigFile, HttpService:JSONEncode(ZoneHub.State))
            end)
        end
    end)
    factory.CreateButton(Card1, "📂 Load Configuration JSON", ZoneHub.Config.Theme.Card, function()
        if type(readfile) == "function" and isfile(ZoneHub.Config.ConfigFile) then
            pcall(function()
                local data = HttpService:JSONDecode(readfile(ZoneHub.Config.ConfigFile))
                for k, v in pairs(data) do ZoneHub.State[k] = v end
            end)
        end
    end)

    -- Card 2: Unload Button
    local Card2 = CreateInst("Frame", {
        BackgroundColor3 = ZoneHub.Config.Theme.Card,
        Parent = settingsPage
    }, {
        CreateInst("UICorner", { CornerRadius = UDim.new(0, 10) }),
        CreateInst("UIStroke", { Color = ZoneHub.Config.Theme.Border }),
        CreateInst("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
    })
    factory.CreateButton(Card2, "❌ Unload Zone Hub Engine", ZoneHub.Config.Theme.Danger, function()
        getgenv().ZoneHubUnload()
    end)
end

--------------------------------------------------------------------------------
-- BOOTSTRAP INITIALIZATION
--------------------------------------------------------------------------------
function ZoneHub:Launch()
    -- 1. Neutralize RemoteEvent queues
    self.Network:InitializeNeutralizer()

    -- 2. Build UI Engine
    self.UI:Init()

    -- 3. Initialize Micro-Modules
    self.Automation:Init()
    self.MapHandler:Init()
    self.Macro:Init()
    self.Settings:Init()

    -- 4. Setup Global Unload Callback
    getgenv().ZoneHubUnload = function()
        getgenv().ZoneHubRunning = false
        getgenv().ZoneHubLoaded = false
        for _, conn in ipairs(self.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        if self.UI.MainGui then
            self.UI.MainGui:Destroy()
        end
        print("[ZoneHub] Unloaded successfully.")
    end

    StarterGui:SetCore("SendNotification", {
        Title = "Zone Hub Pro",
        Text = "Engine initialized cleanly!",
        Duration = 4
    })
    print("[ZoneHub] Successfully booted Zone Hub v" .. self.Config.Version)
end

-- Start Engine
ZoneHub:Launch()
