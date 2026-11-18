-- Smart NPC Studio Diagnostics & Setup plugin.
-- Watches Studio output, runs safe structural checks, and creates the NPC system's
-- required containers, spawn region, and a simple unrigged-placeholder R6 NPC rig.
-- It never evaluates user-entered Lua or rewrites arbitrary project scripts.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local InsertService = game:GetService("InsertService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local TOPBAR_ASSET_ID = 92368439343389
local toolbar = plugin:CreateToolbar("Smart NPC System")
local toggleButton = toolbar:CreateButton("SmartNPCDiagnostics", "Open diagnostics, safe setup, and Studio log monitor", "")
toggleButton.ClickableWhenViewportHidden = true
local widget = plugin:CreateDockWidgetPluginGui("SmartNPCDiagnosticsWidget", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 560, 520, 430, 360))
widget.Title = "Smart NPC Diagnostics"

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(28, 31, 38)
root.Parent = widget
local heading = Instance.new("TextLabel")
heading.Position = UDim2.fromOffset(12, 8)
heading.Size = UDim2.new(1, -24, 0, 28)
heading.BackgroundTransparency = 1
heading.Font = Enum.Font.GothamBold
heading.TextSize = 17
heading.TextColor3 = Color3.new(1, 1, 1)
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Text = "Diagnostics • safe fixes • Output monitor"
heading.Parent = root
local commandBox = Instance.new("TextBox")
commandBox.Position = UDim2.fromOffset(12, 42)
commandBox.Size = UDim2.new(1, -132, 0, 32)
commandBox.BackgroundColor3 = Color3.fromRGB(18, 21, 27)
commandBox.TextColor3 = Color3.new(1, 1, 1)
commandBox.PlaceholderText = "Commands: scan | fix npc | topbar | help"
commandBox.ClearTextOnFocus = false
commandBox.Font = Enum.Font.Code
commandBox.TextSize = 13
commandBox.Text = ""
commandBox.Parent = root
local runButton = Instance.new("TextButton")
runButton.Position = UDim2.new(1, -112, 0, 42)
runButton.Size = UDim2.fromOffset(100, 32)
runButton.BackgroundColor3 = Color3.fromRGB(45, 122, 85)
runButton.TextColor3 = Color3.new(1, 1, 1)
runButton.Font = Enum.Font.GothamBold
runButton.TextSize = 13
runButton.Text = "Run command"
runButton.Parent = root
local quickFix = Instance.new("TextButton")
quickFix.Position = UDim2.fromOffset(12, 82)
quickFix.Size = UDim2.new(0.5, -18, 0, 32)
quickFix.BackgroundColor3 = Color3.fromRGB(56, 68, 84)
quickFix.TextColor3 = Color3.new(1, 1, 1)
quickFix.Font = Enum.Font.GothamBold
quickFix.TextSize = 13
quickFix.Text = "Create required NPC setup"
quickFix.Parent = root
local topbarButton = Instance.new("TextButton")
topbarButton.Position = UDim2.new(0.5, 6, 0, 82)
topbarButton.Size = UDim2.new(0.5, -18, 0, 32)
topbarButton.BackgroundColor3 = Color3.fromRGB(56, 68, 84)
topbarButton.TextColor3 = Color3.new(1, 1, 1)
topbarButton.Font = Enum.Font.GothamBold
topbarButton.TextSize = 13
topbarButton.Text = "Install TopbarPlus asset"
topbarButton.Parent = root
local output = Instance.new("ScrollingFrame")
output.Position = UDim2.fromOffset(12, 124)
output.Size = UDim2.new(1, -24, 1, -136)
output.BackgroundColor3 = Color3.fromRGB(18, 21, 27)
output.BorderSizePixel = 0
output.ScrollBarThickness = 7
output.CanvasSize = UDim2.fromOffset(0, 0)
output.Parent = root
local text = Instance.new("TextLabel")
text.Position = UDim2.fromOffset(8, 8)
text.Size = UDim2.new(1, -16, 0, 0)
text.AutomaticSize = Enum.AutomaticSize.Y
text.BackgroundTransparency = 1
text.Font = Enum.Font.Code
text.TextSize = 12
text.TextColor3 = Color3.fromRGB(220, 225, 235)
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.TextWrapped = true
text.Text = "Ready. This plugin can inspect Studio logs and run its listed safe setup actions. It cannot safely diagnose or repair arbitrary third-party code automatically.\n"
text.Parent = output
local lines = {}
local MAX_LINES = 150
local function writeLine(message)
	table.insert(lines, tostring(message))
	while #lines > MAX_LINES do table.remove(lines, 1) end
	text.Text = table.concat(lines, "\n")
	task.defer(function() output.CanvasSize = UDim2.fromOffset(0, text.AbsoluteSize.Y + 20); output.CanvasPosition = Vector2.new(0, math.max(0, output.CanvasSize.Y.Offset)) end)
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("Folder") then writeLine("OK: " .. parent:GetFullName() .. "." .. name) else writeLine("WARNING: " .. existing:GetFullName() .. " exists but isn't a Folder; left unchanged.") end
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	writeLine("Created folder: " .. folder:GetFullName())
	return folder
end

local function makePart(model, name, size, offset, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(offset)
	part.Color = color
	part.Transparency = transparency or 0
	part.Anchored = false
	part.CanCollide = name ~= "HumanoidRootPart"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function makeMotor(parent, name, part0, part1, c0)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = CFrame.new()
	motor.Parent = part0
	return motor
end

local function createBasicNpcTemplate()
	local existing = ServerStorage:FindFirstChild("NPC")
	if existing then
		if existing:IsA("Model") and existing:FindFirstChildOfClass("Humanoid") and existing:FindFirstChild("HumanoidRootPart") then
			writeLine("OK: ServerStorage.NPC has a Humanoid and HumanoidRootPart; preserved your existing rig.")
		else
			writeLine("WARNING: ServerStorage.NPC exists but is not a compatible rig; left unchanged so your asset isn't overwritten.")
		end
		return
	end
	local model = Instance.new("Model")
	model.Name = "NPC"
	local rootPart = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), Color3.fromRGB(80, 80, 80), 1)
	local torso = makePart(model, "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), Color3.fromRGB(55, 120, 190))
	local head = makePart(model, "Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), Color3.fromRGB(235, 190, 150))
	local leftArm = makePart(model, "Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), Color3.fromRGB(55, 120, 190))
	local rightArm = makePart(model, "Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), Color3.fromRGB(55, 120, 190))
	local leftLeg = makePart(model, "Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), Color3.fromRGB(45, 55, 75))
	local rightLeg = makePart(model, "Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), Color3.fromRGB(45, 55, 75))
	makeMotor(model, "RootJoint", rootPart, torso, CFrame.new())
	makeMotor(model, "Neck", torso, head, CFrame.new(0, 1, 0))
	makeMotor(model, "Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0))
	makeMotor(model, "Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0))
	makeMotor(model, "Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0))
	makeMotor(model, "Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	model.PrimaryPart = rootPart
	model:SetAttribute("DisplayName", "Sandbox NPC")
	model:SetAttribute("Faction", "Neutral")
	model.Parent = ServerStorage
	writeLine("Created a basic R6 NPC template at ServerStorage.NPC. Replace/customize it with your own rig when ready.")
end

local function createNpcSetup()
	local sss = ServerScriptService:FindFirstChild("SmartNPCSystem")
	if not sss then writeLine("WARNING: ServerScriptService.SmartNPCSystem missing. Install the framework with the main installer first.") else writeLine("OK: ServerScriptService.SmartNPCSystem exists.") end
	local region = Workspace:FindFirstChild("NPCSpawnRegion")
	if not region then
		region = Instance.new("Part")
		region.Name = "NPCSpawnRegion"
		region.Size = Vector3.new(100, 1, 100)
		region.CFrame = CFrame.new(0, 0.5, 0)
		region.Anchored = true
		region.CanCollide = false
		region.Transparency = 0.8
		region.Color = Color3.fromRGB(50, 220, 100)
		region.Material = Enum.Material.ForceField
		region:SetAttribute("EditMe", true)
		region.Parent = Workspace
		writeLine("Created Workspace.NPCSpawnRegion (100x100 at origin). Move/resize it to cover safe ground before testing.")
	else
		writeLine("OK: Workspace.NPCSpawnRegion exists (" .. region.ClassName .. ").")
	end
	ensureFolder(ServerStorage, "NPCGear")
	ensureFolder(ServerStorage, "NPCLoot")
	ensureFolder(ServerStorage, "NPCShopItems")
	ensureFolder(Workspace, "NPCPatrols")
	createBasicNpcTemplate()
	local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not starterScripts then starterScripts = Instance.new("StarterPlayerScripts"); starterScripts.Parent = StarterPlayer; writeLine("Created StarterPlayer.StarterPlayerScripts.") end
	pcall(function() ChangeHistoryService:SetWaypoint("Created Smart NPC required objects") end)
	writeLine("Setup complete. Verify region placement and test with Studio server mode.")
end

local function scan()
	writeLine("--- Smart NPC setup scan ---")
	local template = ServerStorage:FindFirstChild("NPC")
	if not template then writeLine("MISSING: ServerStorage.NPC (use Create required NPC setup).")
	elseif not template:IsA("Model") then writeLine("ERROR: ServerStorage.NPC is not a Model.")
	else
		if not template:FindFirstChildOfClass("Humanoid") then writeLine("MISSING: NPC Humanoid.") else writeLine("OK: NPC Humanoid.") end
		if not template:FindFirstChild("HumanoidRootPart") then writeLine("MISSING: NPC HumanoidRootPart.") else writeLine("OK: NPC HumanoidRootPart.") end
		for _, d in ipairs(template:GetDescendants()) do if d:IsA("BasePart") and d.Anchored then writeLine("WARNING: anchored NPC part: " .. d:GetFullName()) end end
	end
	local region = Workspace:FindFirstChild("NPCSpawnRegion")
	if not region then writeLine("MISSING: Workspace.NPCSpawnRegion.") elseif not region:IsA("BasePart") then writeLine("ERROR: NPCSpawnRegion is not a BasePart.") else writeLine("OK: NPCSpawnRegion size " .. tostring(region.Size) .. ".") end
	local system = ServerScriptService:FindFirstChild("SmartNPCSystem")
	if not system then writeLine("MISSING: ServerScriptService.SmartNPCSystem; install framework first.") else
		for _, name in ipairs({"NPCConfig", "NPCController", "NPCInteractions", "NPCAdmin"}) do if not system:FindFirstChild(name) then writeLine("MISSING: SmartNPCSystem." .. name) else writeLine("OK: SmartNPCSystem." .. name) end end
	end
	if not ReplicatedStorage:FindFirstChild("SmartNPCControl") then writeLine("NOTE: SmartNPCControl remotes appear after NPCAdmin runs in a server session.") end
	local iconFound = false
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do if d:IsA("ModuleScript") and d.Name == "Icon" then iconFound = true; break end end
	if iconFound then writeLine("OK: TopbarPlus Icon module found.") else writeLine("NOTE: TopbarPlus missing; use Install TopbarPlus asset, Toolbox, or Wally.") end
	writeLine("Scan complete. Check warnings/errors in Studio Output too.")
end

local function installTopbar()
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do if d:IsA("ModuleScript") and d.Name == "Icon" then writeLine("TopbarPlus Icon already exists in ReplicatedStorage."); return end end
	writeLine("Requesting TopbarPlus asset " .. TOPBAR_ASSET_ID .. " from Studio. Review inserted package before publishing.")
	local ok, result = pcall(function() return InsertService:LoadAsset(TOPBAR_ASSET_ID) end)
	if not ok or not result then writeLine("ERROR: Couldn't load TopbarPlus asset. Try Toolbox/Wally. " .. tostring(result)); return end
	local found
	if result:IsA("ModuleScript") and result.Name == "Icon" then found = result end
	if not found then for _, d in ipairs(result:GetDescendants()) do if d:IsA("ModuleScript") and d.Name == "Icon" then found = d; break end end end
	if not found then result:Destroy(); writeLine("ERROR: Asset did not contain an Icon ModuleScript; discarded it."); return end
	local packages = ReplicatedStorage:FindFirstChild("Packages") or Instance.new("Folder")
	packages.Name = "Packages"; packages.Parent = ReplicatedStorage
	result.Name = "TopbarPlusAsset"; result.Parent = packages
	pcall(function() ChangeHistoryService:SetWaypoint("Inserted TopbarPlus " .. TOPBAR_ASSET_ID) end)
	writeLine("TopbarPlus asset added to ReplicatedStorage.Packages. Test in Play mode.")
end

local function runCommand(raw)
	local command = string.lower(string.gsub(raw, "^%s*(.-)%s*$", "%1"))
	if command == "" or command == "help" then
		writeLine("Allowed commands: scan | fix npc | topbar | help")
	elseif command == "scan" or command == "check" then scan()
	elseif command == "fix npc" or command == "setup npc" then createNpcSetup()
	elseif command == "topbar" or command == "install topbar" then installTopbar()
	else writeLine("Unknown command. Only built-in safe commands are accepted; arbitrary Lua is never executed. Type help.") end
end

runButton.Activated:Connect(function() runCommand(commandBox.Text) end)
commandBox.FocusLost:Connect(function(enterPressed) if enterPressed then runCommand(commandBox.Text) end end)
quickFix.Activated:Connect(createNpcSetup)
topbarButton.Activated:Connect(installTopbar)
toggleButton.Click:Connect(function() widget.Enabled = not widget.Enabled end)
LogService.MessageOut:Connect(function(message, messageType)
	local prefix = "[Output] "
	if messageType == Enum.MessageType.MessageError then prefix = "[ERROR] " elseif messageType == Enum.MessageType.MessageWarning then prefix = "[WARN] " end
	writeLine(prefix .. message)
end)

print("Smart NPC Diagnostics loaded. Open its toolbar to scan, create required NPC objects, or inspect Output.")
