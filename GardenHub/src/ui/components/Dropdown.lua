local Dropdown = {}
Dropdown.__index = Dropdown
local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local Theme = ModuleLoader:Require("ui.Theme")
function Dropdown.new(parent, options)
    local self = setmetatable({ Options = {}, Callbacks = {}, Connections = {} }, Dropdown)
    self.Button = Instance.new("TextButton")
    self.Button.Size = UDim2.new(1, 0, 0, 30); self.Button.BackgroundColor3 = Theme.PanelSecondary; self.Button.BorderSizePixel = 1; self.Button.BorderColor3 = Theme.Border; self.Button.TextColor3 = Theme.Text; self.Button.Font = Enum.Font.GothamBold; self.Button.TextSize = 11; self.Button.Parent = parent
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = self.Button
    table.insert(self.Connections, self.Button.MouseButton1Click:Connect(function() local i=0; for n,v in ipairs(self.Options) do if v==self.Selected then i=n break end end; if #self.Options>0 then self:SetSelected(self.Options[(i % #self.Options)+1]) end end))
    self:SetOptions(options or {}); return self
end
function Dropdown:SetOptions(options, silent)
    local copied = {}
    for _, option in ipairs(options or {}) do table.insert(copied, option) end
    self.Options = copied
    if self.Selected and table.find(self.Options, self.Selected) then
        self.Button.Text = tostring(self.Selected)
        return true
    end
    return self:SetSelected(self.Options[1], silent)
end
function Dropdown:SetSelected(value, silent) if value==self.Selected then return true end; self.Selected=value; self.Button.Text=value and tostring(value) or "Select..."; if silent ~= true then for _,callback in ipairs(self.Callbacks) do callback(value) end end; return true end
function Dropdown:GetSelected() return self.Selected end
function Dropdown:OnChanged(callback) table.insert(self.Callbacks,callback); return callback end
function Dropdown:Destroy() for _,connection in ipairs(self.Connections or {}) do if connection.Connected then connection:Disconnect() end end;self.Connections={};self.Callbacks={};self.Options={};self.Selected=nil;if self.Button then self.Button:Destroy();self.Button=nil end end
return Dropdown
