-- Smart NPC setup checker only. Universal Output monitoring is a separate plugin.
-- Provides allowlisted setup actions and never executes arbitrary entered code.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local TOPBAR_ASSET_ID = 92368439343389
local toolbar = plugin:CreateToolbar("Smart NPC Setup")
local toggleButton = toolbar:CreateButton("SmartNPCSetup", "Check/create Smart NPC required objects", "")
toggleButton.ClickableWhenViewportHidden = true
local widget = plugin:CreateDockWidgetPluginGui("SmartNPCSetupWidget", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 520, 460, 420, 320))
widget.Title = "Smart NPC Setup"
local frame = Instance.new("Frame"); frame.Size = UDim2.fromScale(1,1); frame.BackgroundColor3 = Color3.fromRGB(28,31,38); frame.Parent = widget
local title = Instance.new("TextLabel"); title.Position=UDim2.fromOffset(12,8); title.Size=UDim2.new(1,-24,0,26); title.BackgroundTransparency=1; title.Font=Enum.Font.GothamBold; title.TextSize=16; title.TextColor3=Color3.new(1,1,1); title.TextXAlignment=Enum.TextXAlignment.Left; title.Text="Smart NPC Setup Helper"; title.Parent=frame
local command = Instance.new("TextBox"); command.Position=UDim2.fromOffset(12,40); command.Size=UDim2.new(1,-120,0,32); command.BackgroundColor3=Color3.fromRGB(18,21,27); command.TextColor3=Color3.new(1,1,1); command.PlaceholderText="scan | fix npc | topbar | help"; command.ClearTextOnFocus=false; command.Parent=frame
local run = Instance.new("TextButton"); run.Position=UDim2.new(1,-98,0,40); run.Size=UDim2.fromOffset(86,32); run.Text="Run"; run.Parent=frame
local fix = Instance.new("TextButton"); fix.Position=UDim2.fromOffset(12,80); fix.Size=UDim2.new(.5,-18,0,32); fix.Text="Create required NPC setup"; fix.Parent=frame
local topbar = Instance.new("TextButton"); topbar.Position=UDim2.new(.5,6,0,80); topbar.Size=UDim2.new(.5,-18,0,32); topbar.Text="Install TopbarPlus asset"; topbar.Parent=frame
local output = Instance.new("ScrollingFrame"); output.Position=UDim2.fromOffset(12,122); output.Size=UDim2.new(1,-24,1,-134); output.BackgroundColor3=Color3.fromRGB(18,21,27); output.BorderSizePixel=0; output.ScrollBarThickness=7; output.CanvasSize=UDim2.fromOffset(0,0); output.Parent=frame
local label = Instance.new("TextLabel"); label.Position=UDim2.fromOffset(8,8); label.Size=UDim2.new(1,-16,0,0); label.AutomaticSize=Enum.AutomaticSize.Y; label.BackgroundTransparency=1; label.Font=Enum.Font.Code; label.TextSize=12; label.TextColor3=Color3.fromRGB(220,225,235); label.TextXAlignment=Enum.TextXAlignment.Left; label.TextYAlignment=Enum.TextYAlignment.Top; label.TextWrapped=true; label.Text="Ready. This helper only handles Smart NPC setup; use Universal Studio Monitor for Studio Output."; label.Parent=output
local lines={}
local function log(message) table.insert(lines,tostring(message)); label.Text=table.concat(lines,"\n"); task.defer(function() output.CanvasSize=UDim2.fromOffset(0,label.AbsoluteSize.Y+20) end) end
local function folder(parent,name) local x=parent:FindFirstChild(name); if x then log("Exists: "..x:GetFullName()); return x end; x=Instance.new("Folder"); x.Name=name; x.Parent=parent; log("Created: "..x:GetFullName()); return x end
local function basicRig()
 if ServerStorage:FindFirstChild("NPC") then log("Preserved existing ServerStorage.NPC; inspect it with scan."); return end
 local model=Instance.new("Model"); model.Name="NPC"
 local function part(name,size,pos,transparency)
  local x=Instance.new("Part"); x.Name=name; x.Size=size; x.CFrame=CFrame.new(pos); x.Transparency=transparency or 0; x.Anchored=false; x.CanCollide=name~="HumanoidRootPart"; x.Parent=model; return x
 end
 local root=part("HumanoidRootPart",Vector3.new(2,2,1),Vector3.new(0,0,0),1)
 local torso=part("Torso",Vector3.new(2,2,1),Vector3.new(0,0,0)); local head=part("Head",Vector3.new(2,1,1),Vector3.new(0,1.5,0))
 local la=part("Left Arm",Vector3.new(1,2,1),Vector3.new(-1.5,0,0)); local ra=part("Right Arm",Vector3.new(1,2,1),Vector3.new(1.5,0,0)); local ll=part("Left Leg",Vector3.new(1,2,1),Vector3.new(-.5,-2,0)); local rl=part("Right Leg",Vector3.new(1,2,1),Vector3.new(.5,-2,0))
 local function motor(name,p0,p1,c0) local m=Instance.new("Motor6D"); m.Name=name; m.Part0=p0; m.Part1=p1; m.C0=c0; m.Parent=p0 end
 motor("RootJoint",root,torso,CFrame.new()); motor("Neck",torso,head,CFrame.new(0,1,0)); motor("Left Shoulder",torso,la,CFrame.new(-1,.5,0)); motor("Right Shoulder",torso,ra,CFrame.new(1,.5,0)); motor("Left Hip",torso,ll,CFrame.new(-.5,-1,0)); motor("Right Hip",torso,rl,CFrame.new(.5,-1,0))
 local h=Instance.new("Humanoid"); h.RigType=Enum.HumanoidRigType.R6; h.Parent=model; model.PrimaryPart=root; model:SetAttribute("DisplayName","Sandbox NPC"); model.Parent=ServerStorage; log("Created basic R6 ServerStorage.NPC template; replace it with a production rig when ready.")
end
local function setup()
 local region=Workspace:FindFirstChild("NPCSpawnRegion")
 if not region then region=Instance.new("Part"); region.Name="NPCSpawnRegion"; region.Size=Vector3.new(100,1,100); region.CFrame=CFrame.new(0,.5,0); region.Anchored=true; region.CanCollide=false; region.Transparency=.8; region.Material=Enum.Material.ForceField; region.Color=Color3.fromRGB(50,220,100); region:SetAttribute("EditMe",true); region.Parent=Workspace; log("Created 100x100 spawn-region placeholder at origin; move/resize to safe ground.") else log("Found Workspace.NPCSpawnRegion: "..region.ClassName) end
 folder(ServerStorage,"NPCGear"); folder(ServerStorage,"NPCLoot"); folder(ServerStorage,"NPCShopItems"); folder(Workspace,"NPCPatrols"); basicRig()
 if not ServerScriptService:FindFirstChild("SmartNPCSystem") then log("Missing SmartNPCSystem scripts: install using SmartNPCInstaller first.") end
 if not StarterPlayer:FindFirstChild("StarterPlayerScripts") then local x=Instance.new("StarterPlayerScripts"); x.Parent=StarterPlayer; log("Created StarterPlayerScripts.") end
 pcall(function() ChangeHistoryService:SetWaypoint("Smart NPC required objects") end); log("Setup done. Test in Studio server mode.")
end
local function scan()
 log("--- NPC scan ---"); local n=ServerStorage:FindFirstChild("NPC"); if not n then log("Missing ServerStorage.NPC") elseif not n:IsA("Model") then log("ERROR NPC is not a Model") else if not n:FindFirstChildOfClass("Humanoid") then log("Missing Humanoid") end; if not n:FindFirstChild("HumanoidRootPart") then log("Missing HumanoidRootPart") end; for _,p in ipairs(n:GetDescendants()) do if p:IsA("BasePart") and p.Anchored then log("Anchored rig part: "..p:GetFullName()) end end end
 local r=Workspace:FindFirstChild("NPCSpawnRegion"); if not r then log("Missing Workspace.NPCSpawnRegion") elseif not r:IsA("BasePart") then log("NPCSpawnRegion must be BasePart") else log("Spawn region OK: "..tostring(r.Size)) end
 local system=ServerScriptService:FindFirstChild("SmartNPCSystem"); if not system then log("Missing ServerScriptService.SmartNPCSystem") else for _,name in ipairs({"NPCConfig","NPCController","NPCInteractions","NPCAdmin"}) do if not system:FindFirstChild(name) then log("Missing script: "..name) else log("Found: "..name) end end end
end
local function topbarAsset()
 for _,x in ipairs(ReplicatedStorage:GetDescendants()) do if x:IsA("ModuleScript") and x.Name=="Icon" then log("TopbarPlus Icon already present."); return end end
 local ok,asset=pcall(function() return InsertService:LoadAsset(TOPBAR_ASSET_ID) end); if not ok or not asset then log("TopbarPlus import failed; use Toolbox/Wally: "..tostring(asset)); return end
 local found=asset:IsA("ModuleScript") and asset.Name=="Icon" and asset or nil; if not found then for _,x in ipairs(asset:GetDescendants()) do if x:IsA("ModuleScript") and x.Name=="Icon" then found=x; break end end end
 if not found then asset:Destroy(); log("Asset has no Icon module; discarded."); return end
 local p=ReplicatedStorage:FindFirstChild("Packages") or Instance.new("Folder"); p.Name="Packages"; p.Parent=ReplicatedStorage; asset.Name="TopbarPlusAsset"; asset.Parent=p; log("TopbarPlus inserted into ReplicatedStorage.Packages.")
end
local function runCommand(raw) local s=string.lower(string.gsub(raw,"^%s*(.-)%s*$","%1")); if s=="scan" then scan() elseif s=="fix npc" or s=="setup npc" then setup() elseif s=="topbar" then topbarAsset() elseif s=="help" or s=="" then log("Commands: scan | fix npc | topbar | help. No arbitrary code execution.") else log("Unknown safe command. Type help.") end end
run.Activated:Connect(function() runCommand(command.Text) end); command.FocusLost:Connect(function(enter) if enter then runCommand(command.Text) end end); fix.Activated:Connect(setup); topbar.Activated:Connect(topbarAsset); toggleButton.Click:Connect(function() widget.Enabled=not widget.Enabled end)
print("Smart NPC Setup helper loaded. Use Universal Studio Monitor for general Output capture.")
