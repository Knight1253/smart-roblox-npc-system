-- Smart NPC System local Studio plugin.
-- Adds a server-side NPC package to the currently open place.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local ServerScriptService = game:GetService("ServerScriptService")

local toolbar = plugin:CreateToolbar("Smart NPC System")
local installButton = toolbar:CreateButton(
	"InstallSmartNPCSystem",
	"Install or update the Smart NPC server scripts in this place",
	""
)
installButton.ClickableWhenViewportHidden = true

local configSource = [=[
return {
	NPCCount = 15,
	RespawnDelay = 5,
	DetectionRange = 80,
	AttackDamage = 15,
	AttackRange = 5,
	AttackCooldown = 1.2,
	WanderRadius = 45,
	IdleMin = 2,
	IdleMax = 6,
	InvestigateSeconds = 12,
	SearchSeconds = 15,
	SearchRadius = 18,
	ThinkInterval = 0.3,
	PathRefreshInterval = 1.25,
	MinimumSpawnSpacing = 12,
	UseFactions = false,
	FearHealthPercent = 0.3,
	GearFolderName = "NPCGear",
}
]=]

local controllerSource = [=[
-- Smart NPC System. Requirements: ServerStorage.NPC model, Workspace.NPCSpawnRegion part.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")
local Config = require(script.Parent:WaitForChild("NPCConfig"))
local Template = ServerStorage:WaitForChild("NPC")
local Region = Workspace:WaitForChild("NPCSpawnRegion")
local rng = Random.new()
local folder = Workspace:FindFirstChild("SpawnedNPCs") or Instance.new("Folder")
folder.Name = "SpawnedNPCs"
folder.Parent = Workspace

local function groundAt(point)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {folder, Region}
	local hit = Workspace:Raycast(point + Vector3.new(0, 500, 0), Vector3.new(0, -1200, 0), params)
	return hit and hit.Position
end

local function randomPoint(center, minRadius, maxRadius)
	for _ = 1, 20 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(minRadius, maxRadius)
		local p = groundAt(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		if p then return p end
	end
	return center
end

local function spawnPoint()
	local half = Region.Size / 2
	for _ = 1, 50 do
		local localPos = Vector3.new(rng:NextNumber(-half.X, half.X), 0, rng:NextNumber(-half.Z, half.Z))
		local p = Region.CFrame:PointToWorldSpace(localPos)
		local ground = groundAt(p)
		if ground then
			local far = true
			for _, model in folder:GetChildren() do
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - ground).Magnitude < Config.MinimumSpawnSpacing then far = false; break end
			end
			if far then return ground end
		end
	end
	return nil
end

local function equipGear(npc, humanoid)
	local gearFolder = ServerStorage:FindFirstChild(Config.GearFolderName)
	if not gearFolder then return end
	local tools = {}
	for _, item in gearFolder:GetChildren() do if item:IsA("Tool") then table.insert(tools, item) end end
	if #tools == 0 then return end
	local tool = tools[rng:NextInteger(1, #tools)]:Clone()
	npc:SetAttribute("GearName", tool.Name)
	npc:SetAttribute("AttackDamage", tool:GetAttribute("Damage") or Config.AttackDamage)
	npc:SetAttribute("AttackRange", tool:GetAttribute("Range") or Config.AttackRange)
	npc:SetAttribute("AttackCooldown", tool:GetAttribute("Cooldown") or Config.AttackCooldown)
	tool.Parent = npc
	humanoid:EquipTool(tool)
end

local function visible(npc, character, from, to)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {npc}
	local hit = Workspace:Raycast(from, to - from, params)
	return not hit or hit.Instance:IsDescendantOf(character)
end

local function runAI(npc, home)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	local state, targetLast, lastSeen = "Idle", nil, 0
	local nextWander, idleUntil = nil, os.clock() + rng:NextNumber(Config.IdleMin, Config.IdleMax)
	local lastAttack, lastPath = 0, 0
	local function setState(value, emotion)
		state = value; npc:SetAttribute("AIState", value); npc:SetAttribute("Emotion", emotion)
	end
	local function moveTo(goal)
		local path = PathfindingService:CreatePath({AgentCanJump = true, AgentCanClimb = true})
		local ok = pcall(function() path:ComputeAsync(root.Position, goal) end)
		if ok and path.Status == Enum.PathStatus.Success then
			local points = path:GetWaypoints()
			local point = points[2] or points[1]
			if point then if point.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end; hum:MoveTo(point.Position) end
		else hum:MoveTo(goal) end
	end
	while npc.Parent and hum.Health > 0 do
		local now, target, targetHum, targetRoot, distance = os.clock(), nil, nil, nil, Config.DetectionRange
		for _, player in Players:GetPlayers() do
			local char = player.Character
			local th = char and char:FindFirstChildOfClass("Humanoid")
			local tr = char and char:FindFirstChild("HumanoidRootPart")
			local factionOK = not Config.UseFactions or npc:GetAttribute("Faction") == nil or player:GetAttribute("Faction") == nil or npc:GetAttribute("Faction") ~= player:GetAttribute("Faction")
			if factionOK and th and tr and th.Health > 0 then
				local d = (tr.Position - root.Position).Magnitude
				if d < distance and visible(npc, char, root.Position, tr.Position) then target, targetHum, targetRoot, distance = char, th, tr, d end
			end
		end
		if targetRoot then targetLast, lastSeen = targetRoot.Position, now end
		if targetRoot and distance <= (npc:GetAttribute("AttackRange") or Config.AttackRange) then
			setState("Attacking", "Angry")
			hum:MoveTo(root.Position)
			local cooldown = npc:GetAttribute("AttackCooldown") or Config.AttackCooldown
			if now - lastAttack >= cooldown then lastAttack = now; targetHum:TakeDamage(npc:GetAttribute("AttackDamage") or Config.AttackDamage) end
		elseif targetRoot then
			setState("Chasing", "Alert")
			if now - lastPath >= Config.PathRefreshInterval then lastPath = now; moveTo(targetRoot.Position) end
		elseif targetLast and now - lastSeen <= Config.InvestigateSeconds then
			if (root.Position - targetLast).Magnitude > 5 then
				setState("Investigating", "Curious")
				if now - lastPath >= Config.PathRefreshInterval then lastPath = now; moveTo(targetLast) end
			else
				setState("Searching", "Suspicious")
				if now - lastPath >= 2.5 then lastPath = now; moveTo(randomPoint(targetLast, 4, Config.SearchRadius)) end
			end
		elseif targetLast and now - lastSeen <= Config.InvestigateSeconds + Config.SearchSeconds then
			setState("Searching", "Suspicious")
			if now - lastPath >= 2.5 then lastPath = now; moveTo(randomPoint(targetLast, 4, Config.SearchRadius)) end
		else
			targetLast = nil
			if (root.Position - home).Magnitude > Config.WanderRadius then
				setState("Returning", "Worried")
				if now - lastPath >= Config.PathRefreshInterval then lastPath = now; moveTo(home) end
			elseif nextWander and (root.Position - nextWander).Magnitude > 5 then
				setState("Roaming", "Curious")
				if now - lastPath >= Config.PathRefreshInterval then lastPath = now; moveTo(nextWander) end
			elseif now >= idleUntil then
				nextWander = randomPoint(home, 8, Config.WanderRadius)
				idleUntil = now + rng:NextNumber(Config.IdleMin, Config.IdleMax)
				setState("Roaming", "Curious")
			else setState("Idle", "Calm") end
		end
		if hum.Health / math.max(hum.MaxHealth, 1) <= Config.FearHealthPercent and not targetRoot then npc:SetAttribute("Emotion", "Fearful") end
		task.wait(Config.ThinkInterval)
	end
end

local function spawnOne(id)
	local ground = spawnPoint()
	if not ground then task.delay(3, function() spawnOne(id) end); return end
	local npc = Template:Clone()
	local hum = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not hum or not root then warn("NPC model needs Humanoid and HumanoidRootPart"); npc:Destroy(); return end
	local y = hum.HipHeight + root.Size.Y / 2 + 0.1
	local pivotOffset = root.CFrame:ToObjectSpace(npc:GetPivot())
	npc:PivotTo((CFrame.new(ground + Vector3.new(0, y, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)) * pivotOffset)
	npc.Name = string.format("NPC_%02d", id)
	npc:SetAttribute("HomePosition", ground)
	npc.Parent = folder
	equipGear(npc, hum)
	task.spawn(runAI, npc, ground)
	hum.Died:Connect(function()
		Debris:AddItem(npc, 8)
		task.delay(Config.RespawnDelay, function() spawnOne(id) end)
	end)
end

for id = 1, Config.NPCCount do task.spawn(spawnOne, id) end
]=]

local function setSource(instance, source)
	local ok, err = pcall(function()
		ScriptEditorService:UpdateSourceAsync(instance, function()
			return source
		end)
	end)
	if not ok then
		instance:Destroy()
		return false, err
	end
	return true
end

installButton.Click:Connect(function()
	local existing = ServerScriptService:FindFirstChild("SmartNPCSystem")
	local root = existing
	if not root then
		root = Instance.new("Folder")
		root.Name = "SmartNPCSystem"
		root.Parent = ServerScriptService
	end

	local config = root:FindFirstChild("NPCConfig")
	if not config or not config:IsA("ModuleScript") then
		if config then config:Destroy() end
		config = Instance.new("ModuleScript")
		config.Name = "NPCConfig"
		config.Parent = root
	end

	local controller = root:FindFirstChild("NPCController")
	if not controller or not controller:IsA("Script") then
		if controller then controller:Destroy() end
		controller = Instance.new("Script")
		controller.Name = "NPCController"
		controller.Parent = root
	end

	local okConfig, errConfig = setSource(config, configSource)
	local okController, errController = setSource(controller, controllerSource)
	if not okConfig or not okController then
		warn("Smart NPC System source setup failed:", errConfig or errController)
		return
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("Installed Smart NPC System")
	end)
	print("Smart NPC System installed. Add ServerStorage.NPC and Workspace.NPCSpawnRegion, then test with Start Server.")
end)

print("Smart NPC System plugin loaded. Use its toolbar button to install the scripts into this place.")
