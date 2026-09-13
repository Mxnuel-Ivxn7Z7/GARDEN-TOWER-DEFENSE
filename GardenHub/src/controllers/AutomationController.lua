local AutomationController = {}
AutomationController.__index = AutomationController
AutomationController.Bound = false
AutomationController.Subscriptions = {}
local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local State = ModuleLoader:Require("core.State")
local Logger = ModuleLoader:Require("core.Logger")
local GameAdapter = ModuleLoader:Require("game.GameAdapter")
local function setDefault(key,value) if State:Get(key)==nil then State:Set(key,value) end end
local function bindStateDefaults()
 setDefault("AutomationMode","OFF");setDefault("AutoTickSpeed",false);setDefault("TickSpeed",1);setDefault("AutoEquipUnits",false);setDefault("AutoSkipWave",false);setDefault("AutoPlayAgain",false);setDefault("TurnOffGlobalPlay",false);setDefault("AutoJoinMap",false);setDefault("AutoSelectDifficulty",false)
end
function AutomationController:Subscribe(key,callback) State:Subscribe(key,callback);table.insert(self.Subscriptions,{key=key,callback=callback}) end
function AutomationController:Bind()
 if self.Bound then return true end;bindStateDefaults()
 self:Subscribe("TickSpeed",function(value) local numeric=tonumber(value) or 1;if numeric~=1 and numeric~=2 and numeric~=3 then numeric=1 end;State:Set("Speed", "x"..tostring(numeric)) end)
 local numeric=tonumber(State:Get("TickSpeed",1)) or 1;if numeric~=1 and numeric~=2 and numeric~=3 then numeric=1 end;State:Set("Speed", "x"..tostring(numeric))
 self.Bound=true;Logger:Info("Automation controller bound.");return true
end
function AutomationController:Unbind() for _,sub in ipairs(self.Subscriptions or {}) do State:Unsubscribe(sub.key,sub.callback) end;self.Subscriptions={};self.Bound=false;return true end
function AutomationController:JoinOnce()
 local map,difficulty=State:Get("SelectedMap"),State:Get("SelectedDifficulty")
 if not map then return false,"Select a map before Join Once." end
 if not difficulty then return false,"Select a difficulty before Join Once." end
 if not GameAdapter.ConcreteBridge then return false,"Join Once requires ConcreteBridge" end
 return GameAdapter:Execute({type="JOIN_MAP",data={map=map,difficulty=difficulty}})
end
function AutomationController:ApplySettings(settings) if type(settings)~="table" then return false,"Settings must be a table." end;for key,value in pairs(settings) do if type(key)=="string" then State:Set(key,value) end end;return true end
function AutomationController:GetSnapshot() return State:Snapshot() end
return AutomationController
