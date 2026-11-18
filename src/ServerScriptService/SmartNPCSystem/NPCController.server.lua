-- Smart NPC System sandbox framework controller.
-- ServerStorage.NPC: Humanoid + HumanoidRootPart; Workspace.NPCSpawnRegion: BasePart.
-- Optional: ServerStorage.NPCGear Tools, ServerStorage.NPCLoot Tools,
-- Workspace.NPCPatrols/<route name> BaseParts, Workspace.NPCNoise BindableEvent.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent:WaitForChild("NPCConfig"))
local Template = ServerStorage:WaitForChild(Config.TemplateName)
local Region = Workspace:WaitForChild(Config.RegionName)
local rng = Random.new()
local folder = Workspace:FindFirstChild(Config.SpawnedFolderName) or Instance.new("Folder")
folder.Name = Config.SpawnedFolderName
folder.Parent = Workspace

local alertEvent = ServerStorage:FindFirstChild("SmartNPCGroupAlert") or Instance.new("BindableEvent")
alertEvent.Name = "SmartNPCGroupAlert"
alertEvent.Parent = ServerStorage
local noiseEvent = Workspace:FindFirstChild("NPCNoise")
local lastAlerts = {}

local function groundAt(point, excluded)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded or { folder, Region }
	local hit = Workspace:Raycast(point + Vector3.new(0, 500, 0), Vector3.new(0, -1200, 0), params)
	return hit and hit.Position
end

local function randomPoint(center, minRadius, maxRadius)
	for _ = 1, 20 do
		local angle, radius = rng:NextNumber(0, math.pi * 2), rng:NextNumber(minRadius, maxRadius)
		local point = groundAt(center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
		if point then return point end
	end
	return center
end

local function findSpawnPoint()
	local half = Region.Size / 2
	for _ = 1, Config.SpawnAttempts do
		local localPoint = Vector3.new(rng:NextNumber(-half.X, half.X), 0, rng:NextNumber(-half.Z, half.Z))
		local ground = groundAt(Region.CFrame:PointToWorldSpace(localPoint))
		if ground then
			local clear = true
			for _, model in folder:GetChildren() do
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - ground).Magnitude < Config.MinimumSpawnSpacing then clear = false; break end
			end
			if clear then return ground end
		end
	end
end

local function factionFriendly(a, b)
	local fa = a:GetAttribute("Faction") or Config.DefaultFaction
	local fb = b:GetAttribute("Faction") or Config.DefaultFaction
	return fa == fb and fa ~= "Neutral"
end

local function equipGear(npc, humanoid)
	local gearFolder = ServerStorage:FindFirstChild(Config.GearFolderName)
	local choices = {}
	if gearFolder then
		for _, item in gearFolder:GetChildren() do if item:IsA("Tool") then table.insert(choices, item) end end
	end
	local tool = choices[ rng:NextInteger(1, #choices) ]
	if not tool then
		npc:SetAttribute("GearName", "Unarmed")
		npc:SetAttribute("WeaponType", "Melee")
		npc:SetAttribute("AttackDamage", Config.AttackDamage)
		npc:SetAttribute("AttackRange", Config.AttackRange)
		npc:SetAttribute("AttackCooldown", Config.AttackCooldown)
		return
	end
	tool = tool:Clone()
	npc:SetAttribute("GearName", tool.Name)
	npc:SetAttribute("WeaponType", tool:GetAttribute("WeaponType") or "Melee")
	npc:SetAttribute("AttackDamage", tool:GetAttribute("Damage") or Config.AttackDamage)
	npc:SetAttribute("AttackRange", tool:GetAttribute("Range") or Config.AttackRange)
	npc:SetAttribute("AttackCooldown", tool:GetAttribute("Cooldown") or Config.AttackCooldown)
	npc:SetAttribute("MagazineSize", tool:GetAttribute("MagazineSize") or 8)
	npc:SetAttribute("Ammo", tool:GetAttribute("MagazineSize") or 8)
	npc:SetAttribute("ReloadTime", tool:GetAttribute("ReloadTime") or 2)
	tool.Parent = npc
	humanoid:EquipTool(tool)
end

local function visible(npc, character, from, to)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc }
	local hit = Workspace:Raycast(from, to - from, params)
	return not hit or hit.Instance:IsDescendantOf(character)
end

local function targetCandidates(npc, root)
	local best, bestHumanoid, bestRoot, bestDistance
	bestDistance = Config.DetectionRange
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
		local friendly = Config.UseFactions and factionFriendly(npc, player)
		if not friendly and hum and targetRoot and hum.Health > 0 then
			local dist = (targetRoot.Position - root.Position).Magnitude
			local stealth = char:GetAttribute("Stealth") == true
			local range = Config.DetectionRange * (stealth and Config.StealthDetectionMultiplier or 1)
			if dist <= range and dist < bestDistance and visible(npc, char, root.Position, targetRoot.Position) then
				best, bestHumanoid, bestRoot, bestDistance = char, hum, targetRoot, dist
			end
		end
	end
	return best, bestHumanoid, bestRoot, bestDistance
end

local function pathMove(humanoid, root, goal)
	local path = PathfindingService:CreatePath({ AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 5 })
	local ok = pcall(function() path:ComputeAsync(root.Position, goal) end)
	if ok and path.Status == Enum.PathStatus.Success then
		local points = path:GetWaypoints()
		local point = points[2] or points[1]
		if point then
			if point.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
			humanoid:MoveTo(point.Position)
			return
		end
	end
	humanoid:MoveTo(goal)
end

local function patrolPoints(npc)
	local patrols = Workspace:FindFirstChild(Config.PatrolFolderName)
	if not patrols then return {} end
	local route = patrols:FindFirstChild(npc:GetAttribute("PatrolRoute") or npc:GetAttribute("Faction") or "Default")
	if not route then return {} end
	local points = {}
	for _, p in route:GetChildren() do if p:IsA("BasePart") then table.insert(points, p) end end
	table.sort(points, function(a, b) return a.Name < b.Name end)
	return points
end

local function chooseEmotion(npc, humanoid, state, hurtUntil)
	if humanoid.Health / math.max(humanoid.MaxHealth, 1) <= Config.FearHealthPercent then return "Fearful" end
	if os.clock() < hurtUntil then return "Hurt" end
	local emotions = { Idle = "Calm", Roaming = "Curious", Investigating = "Curious", Searching = "Suspicious", Chasing = "Alert", Attacking = "Angry", Returning = "Worried", Fleeing = "Fearful", Reloading = "Anxious", Guarding = "Calm", Stuck = "Confused" }
	return emotions[state] or "Calm"
end

local function alertGroup(npc, position, character)
	alertEvent:Fire(npc, position, character)
end
alertEvent.Event:Connect(function(source, position, character)
	for _, ally in folder:GetChildren() do
		if ally ~= source and ally:GetAttribute("Faction") == source:GetAttribute("Faction") then
			local root = ally:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - position).Magnitude <= Config.GroupAlertRange then
				ally:SetAttribute("HeardAlertPosition", position)
				ally:SetAttribute("HeardAlertUntil", os.clock() + Config.InvestigateSeconds)
				if character then ally:SetAttribute("AlertTargetUserId", character:GetAttribute("UserId") or 0) end
			end
		end
	end
end)
if noiseEvent and noiseEvent:IsA("BindableEvent") then
	noiseEvent.Event:Connect(function(position, radius, source)
		if typeof(position) ~= "Vector3" then return end
		for _, npc in folder:GetChildren() do
			local root = npc:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - position).Magnitude <= (radius or Config.HearingRange) then
				npc:SetAttribute("HeardNoisePosition", position)
				npc:SetAttribute("HeardNoiseUntil", os.clock() + Config.InvestigateSeconds)
			end
		end
	end)
end

local function runAI(npc, home)
	local humanoid, root = npc:FindFirstChildOfClass("Humanoid"), npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end
	local lastKnown, lastSeen, lastAttack, lastPath = nil, 0, 0, 0
	local idleUntil = os.clock() + rng:NextNumber(Config.IdleMin, Config.IdleMax)
	local wanderGoal, patrolIndex, hurtUntil, fleeingUntil = nil, 1, 0, 0
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(h)
		if h < lastHealth then
			hurtUntil = os.clock() + 3
			alertGroup(npc, root.Position, nil)
		end
		lastHealth = h
	end)
	while npc.Parent and humanoid.Health > 0 do
		local now = os.clock()
		local target, targetHumanoid, targetRoot, distance = targetCandidates(npc, root)
		if targetRoot then
			lastKnown, lastSeen = targetRoot.Position, now
			target:SetAttribute("UserId", Players:GetPlayerFromCharacter(target) and Players:GetPlayerFromCharacter(target).UserId or 0)
			alertGroup(npc, targetRoot.Position, target)
		end
		local lowHealth = humanoid.Health / math.max(humanoid.MaxHealth, 1) <= Config.FearHealthPercent
		local state
		if lowHealth and targetRoot and now >= fleeingUntil then fleeingUntil = now + Config.FleeSeconds end
		if lowHealth and targetRoot and now < fleeingUntil then
			state = "Fleeing"
			local away = (root.Position - targetRoot.Position).Unit
			local goal = randomPoint(root.Position + away * 20, 5, 15)
			if now - lastPath >= 1 then lastPath = now; pathMove(humanoid, root, goal) end
		elseif targetRoot and distance <= (npc:GetAttribute("AttackRange") or Config.AttackRange) then
			local weaponType = npc:GetAttribute("WeaponType") or "Melee"
			if weaponType == "Ranged" then
				local ammo = npc:GetAttribute("Ammo") or 0
				if ammo <= 0 then
					state = "Reloading"
					task.wait(npc:GetAttribute("ReloadTime") or 2)
					npc:SetAttribute("Ammo", npc:GetAttribute("MagazineSize") or 8)
				else
					state = "Attacking"
					if now - lastAttack >= (npc:GetAttribute("AttackCooldown") or Config.AttackCooldown) then
						lastAttack = now
						npc:SetAttribute("Ammo", ammo - 1)
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = { npc }
						local hit = Workspace:Raycast(root.Position, targetRoot.Position - root.Position, params)
						if hit and hit.Instance:IsDescendantOf(target) then targetHumanoid:TakeDamage(npc:GetAttribute("AttackDamage") or Config.AttackDamage) end
					end
				end
			else
				state = "Attacking"
				if now - lastAttack >= (npc:GetAttribute("AttackCooldown") or Config.AttackCooldown) then
					lastAttack = now
					if visible(npc, target, root.Position, targetRoot.Position) then targetHumanoid:TakeDamage(npc:GetAttribute("AttackDamage") or Config.AttackDamage) end
				end
			end
		elseif targetRoot then
			state = "Chasing"
			if (targetRoot.Position - home).Magnitude <= Config.MaxChaseDistance and now - lastPath >= Config.PathRefreshInterval then
				lastPath = now
				pathMove(humanoid, root, targetRoot.Position)
			end
		elseif lastKnown and now - lastSeen <= Config.InvestigateSeconds + Config.SearchSeconds then
			state = (root.Position - lastKnown).Magnitude > 5 and "Investigating" or "Searching"
			if now - lastPath >= (state == "Searching" and 2.5 or Config.PathRefreshInterval) then
				lastPath = now
				pathMove(humanoid, root, state == "Investigating" and lastKnown or randomPoint(lastKnown, 4, Config.SearchRadius))
			end
		else
			lastKnown = nil
			local heard = npc:GetAttribute("HeardNoiseUntil") or 0
			local alertUntil = npc:GetAttribute("HeardAlertUntil") or 0
			local soundPos = now < heard and npc:GetAttribute("HeardNoisePosition") or (now < alertUntil and npc:GetAttribute("HeardAlertPosition"))
			if soundPos then
				state = "Investigating"
				if now - lastPath >= Config.PathRefreshInterval then lastPath = now; pathMove(humanoid, root, soundPos) end
			elseif (root.Position - home).Magnitude > Config.WanderRadius then
				state = "Returning"
				if now - lastPath >= Config.PathRefreshInterval then lastPath = now; pathMove(humanoid, root, home) end
			else
				local patrol = patrolPoints(npc)
				if #patrol > 0 then
					state = "Guarding"
					local point = patrol[patrolIndex]
					if (root.Position - point.Position).Magnitude <= 5 then patrolIndex = patrolIndex % #patrol + 1; point = patrol[patrolIndex] end
					if now - lastPath >= Config.PathRefreshInterval then lastPath = now; pathMove(humanoid, root, point.Position) end
				elseif wanderGoal and (root.Position - wanderGoal).Magnitude > 5 then
					state = "Roaming"
					if now - lastPath >= Config.PathRefreshInterval then lastPath = now; pathMove(humanoid, root, wanderGoal) end
				elseif now >= idleUntil then
					wanderGoal = randomPoint(home, Config.WanderMinDistance, Config.WanderRadius)
					idleUntil = now + rng:NextNumber(Config.IdleMin, Config.IdleMax)
					state = "Roaming"
				else state = "Idle" end
			end
		end
		npc:SetAttribute("AIState", state)
		npc:SetAttribute("Emotion", chooseEmotion(npc, humanoid, state, hurtUntil))
		task.wait(Config.ThinkInterval)
	end
end

local function dropLoot(npc, position)
	if rng:NextNumber() > Config.LootDropChance then return end
	local loot = ServerStorage:FindFirstChild(Config.LootFolderName)
	if not loot then return end
	local items = {}
	for _, item in loot:GetChildren() do if item:IsA("Tool") then table.insert(items, item) end end
	if #items == 0 then return end
	local tool = items[rng:NextInteger(1, #items)]:Clone()
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		local drop = Instance.new("Part")
		drop.Name = "NPCLootDrop"
		drop.Size = Vector3.new(1, 1, 1)
		drop.Position = position + Vector3.new(0, 2, 0)
		drop.Anchored = false
		drop.Parent = Workspace
		tool.Parent = drop
		Debris:AddItem(drop, 60)
	else tool:Destroy() end
end

local function spawnOne(id)
	local ground = findSpawnPoint()
	if not ground then task.delay(3, function() spawnOne(id) end); return end
	local npc = Template:Clone()
	local hum, root = npc:FindFirstChildOfClass("Humanoid"), npc:FindFirstChild("HumanoidRootPart")
	if not hum or not root then warn("NPC model needs Humanoid and HumanoidRootPart"); npc:Destroy(); return end
	local pivotOffset = root.CFrame:ToObjectSpace(npc:GetPivot())
	local spawnCF = CFrame.new(ground + Vector3.new(0, hum.HipHeight + root.Size.Y / 2 + 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	npc:PivotTo(spawnCF * pivotOffset)
	npc.Name = string.format("NPC_%02d", id)
	npc:SetAttribute("Faction", npc:GetAttribute("Faction") or Config.DefaultFaction)
	npc:SetAttribute("HomePosition", ground)
	npc.Parent = folder
	equipGear(npc, hum)
	if Config.ShowEmotionLabel then
		local head = npc:FindFirstChild("Head")
		if head then
			local gui = Instance.new("BillboardGui")
			gui.Name, gui.Adornee, gui.Size, gui.StudsOffset, gui.AlwaysOnTop = "NPCEmotionLabel", head, UDim2.fromOffset(130, 28), Vector3.new(0, 2.7, 0), true
			gui.Parent = head
			local label = Instance.new("TextLabel")
			label.Size, label.BackgroundTransparency, label.TextScaled = UDim2.fromScale(1, 1), 1, true
			label.Font, label.TextColor3, label.TextStrokeTransparency = Enum.Font.GothamBold, Color3.new(1, 1, 1), 0.35
			label.Parent = gui
			local function update() label.Text = npc:GetAttribute("Emotion") or "Calm" end
			npc:GetAttributeChangedSignal("Emotion"):Connect(update)
			update()
		end
	end
	task.spawn(runAI, npc, ground)
	hum.Died:Connect(function()
		dropLoot(npc, root.Position)
		Debris:AddItem(npc, 8)
		task.delay(Config.RespawnDelay, function() spawnOne(id) end)
	end)
end

for id = 1, Config.NPCCount do task.spawn(spawnOne, id) end

for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(function(character)
		character:SetAttribute("Stealth", false)
	end)
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character) character:SetAttribute("Stealth", false) end)
end)

for _, player in Players:GetPlayers() do
	player.Chatted:Connect(function(message)
		if not table.find(Config.AdminUserIds, player.UserId) then return end
		local command = string.lower(message)
		if command == "/npc recall" then
			for _, npc in folder:GetChildren() do
				local root = npc:FindFirstChild("HumanoidRootPart")
				local home = npc:GetAttribute("HomePosition")
				if root and typeof(home) == "Vector3" then root.AssemblyLinearVelocity = Vector3.zero; root.CFrame = CFrame.new(home + Vector3.new(0, 3, 0)) end
			end
		elseif command == "/npc debug" then
			for _, npc in folder:GetChildren() do npc:SetAttribute("DebugEnabled", not npc:GetAttribute("DebugEnabled")) end
		end
	end)
end)
