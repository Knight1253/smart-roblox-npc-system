-- Smart NPC System controller.
-- Requirements: ServerStorage.NPC model with Humanoid + HumanoidRootPart,
-- and Workspace.NPCSpawnRegion BasePart.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")

local Config = require(script.Parent:WaitForChild("NPCConfig"))
local Template = ServerStorage:WaitForChild("NPC")
local Region = Workspace:WaitForChild("NPCSpawnRegion")
local rng = Random.new()

local folder = Workspace:FindFirstChild("SpawnedNPCs")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "SpawnedNPCs"
	folder.Parent = Workspace
end

local function groundAt(point)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, Region }
	local hit = Workspace:Raycast(point + Vector3.new(0, 500, 0), Vector3.new(0, -1200, 0), params)
	return hit and hit.Position
end

local function randomPoint(center, minRadius, maxRadius)
	for _ = 1, 20 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(minRadius, maxRadius)
		local point = groundAt(center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
		if point then return point end
	end
	return center
end

local function spawnPoint()
	local half = Region.Size / 2
	for _ = 1, Config.SpawnAttempts do
		local localPoint = Vector3.new(rng:NextNumber(-half.X, half.X), 0, rng:NextNumber(-half.Z, half.Z))
		local worldPoint = Region.CFrame:PointToWorldSpace(localPoint)
		local ground = groundAt(worldPoint)
		if ground then
			local farEnough = true
			for _, model in folder:GetChildren() do
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - ground).Magnitude < Config.MinimumSpawnSpacing then
					farEnough = false
					break
				end
			end
			if farEnough then return ground end
		end
	end
	return nil
end

local function equipGear(npc, humanoid)
	local gearFolder = ServerStorage:FindFirstChild(Config.GearFolderName)
	local tools = {}
	if gearFolder then
		for _, item in gearFolder:GetChildren() do
			if item:IsA("Tool") then table.insert(tools, item) end
		end
	end
	if #tools == 0 then
		npc:SetAttribute("GearName", "Unarmed")
		npc:SetAttribute("AttackDamage", Config.AttackDamage)
		npc:SetAttribute("AttackRange", Config.AttackRange)
		npc:SetAttribute("AttackCooldown", Config.AttackCooldown)
		return
	end
	local tool = tools[rng:NextInteger(1, #tools)]:Clone()
	npc:SetAttribute("GearName", tool.Name)
	npc:SetAttribute("AttackDamage", tool:GetAttribute("Damage") or Config.AttackDamage)
	npc:SetAttribute("AttackRange", tool:GetAttribute("Range") or Config.AttackRange)
	npc:SetAttribute("AttackCooldown", tool:GetAttribute("Cooldown") or Config.AttackCooldown)
	tool.Parent = npc
	humanoid:EquipTool(tool)
end

local function addEmotionLabel(npc)
	if not Config.ShowEmotionLabel then return end
	local head = npc:FindFirstChild("Head")
	if not head then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NPCEmotionLabel"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(130, 30)
	billboard.StudsOffset = Vector3.new(0, 2.7, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "EmotionText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Calm"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard
	npc:GetAttributeChangedSignal("Emotion"):Connect(function()
		label.Text = npc:GetAttribute("Emotion") or "Calm"
	end)
end

local function isVisible(npc, character, fromPosition, toPosition)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc }
	local hit = Workspace:Raycast(fromPosition, toPosition - fromPosition, params)
	return not hit or hit.Instance:IsDescendantOf(character)
end

local function findTarget(npc, root)
	local bestCharacter, bestHumanoid, bestRoot
	local bestDistance = Config.DetectionRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
		local factionOK = not Config.UseFactions
			or npc:GetAttribute("Faction") == nil
			or player:GetAttribute("Faction") == nil
			or npc:GetAttribute("Faction") ~= player:GetAttribute("Faction")
		if factionOK and humanoid and targetRoot and humanoid.Health > 0 then
			local distance = (targetRoot.Position - root.Position).Magnitude
			if distance < bestDistance and isVisible(npc, character, root.Position, targetRoot.Position) then
				bestCharacter, bestHumanoid, bestRoot, bestDistance = character, humanoid, targetRoot, distance
			end
		end
	end
	return bestCharacter, bestHumanoid, bestRoot, bestDistance
end

local function moveAlongPath(humanoid, root, destination)
	local path = PathfindingService:CreatePath({ AgentCanJump = true, AgentCanClimb = true })
	local ok = pcall(function() path:ComputeAsync(root.Position, destination) end)
	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local waypoint = waypoints[2] or waypoints[1]
		if waypoint then
			if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
			humanoid:MoveTo(waypoint.Position)
			return
		end
	end
	humanoid:MoveTo(destination)
end

local function runAI(npc, home)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	local state = "Idle"
	local lastKnownPosition, lastSeenAt
	local nextWander
	local idleUntil = os.clock() + rng:NextNumber(Config.IdleMin, Config.IdleMax)
	local lastAttack, lastPath = 0, 0
	local hurtUntil = 0
	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then hurtUntil = os.clock() + 3 end
		lastHealth = health
	end)

	local function setState(newState, emotion)
		state = newState
		npc:SetAttribute("AIState", state)
		npc:SetAttribute("Emotion", emotion)
	end

	while npc.Parent and humanoid.Health > 0 do
		local now = os.clock()
		local character, targetHumanoid, targetRoot, distance = findTarget(npc, root)
		if targetRoot then
			lastKnownPosition = targetRoot.Position
			lastSeenAt = now
		end

		if targetRoot and distance <= (npc:GetAttribute("AttackRange") or Config.AttackRange) then
			setState("Attacking", "Angry")
			humanoid:MoveTo(root.Position)
			local cooldown = npc:GetAttribute("AttackCooldown") or Config.AttackCooldown
			if now - lastAttack >= cooldown then
				lastAttack = now
				targetHumanoid:TakeDamage(npc:GetAttribute("AttackDamage") or Config.AttackDamage)
			end
		elseif targetRoot then
			setState("Chasing", "Alert")
			if now - lastPath >= Config.PathRefreshInterval then
				lastPath = now
				moveAlongPath(humanoid, root, targetRoot.Position)
			end
		elseif lastKnownPosition and now - lastSeenAt <= Config.InvestigateSeconds then
			if (root.Position - lastKnownPosition).Magnitude > 5 then
				setState("Investigating", "Curious")
				if now - lastPath >= Config.PathRefreshInterval then
					lastPath = now
					moveAlongPath(humanoid, root, lastKnownPosition)
				end
			else
				setState("Searching", "Suspicious")
				if now - lastPath >= 2.5 then
					lastPath = now
					moveAlongPath(humanoid, root, randomPoint(lastKnownPosition, 4, Config.SearchRadius))
				end
			end
		elseif lastKnownPosition and now - lastSeenAt <= Config.InvestigateSeconds + Config.SearchSeconds then
			setState("Searching", "Suspicious")
			if now - lastPath >= 2.5 then
				lastPath = now
				moveAlongPath(humanoid, root, randomPoint(lastKnownPosition, 4, Config.SearchRadius))
			end
		else
			lastKnownPosition = nil
			if (root.Position - home).Magnitude > Config.WanderRadius then
				setState("Returning", "Worried")
				if now - lastPath >= Config.PathRefreshInterval then
					lastPath = now
					moveAlongPath(humanoid, root, home)
				end
			elseif nextWander and (root.Position - nextWander).Magnitude > 5 then
				setState("Roaming", "Curious")
				if now - lastPath >= Config.PathRefreshInterval then
					lastPath = now
					moveAlongPath(humanoid, root, nextWander)
				end
			elseif now >= idleUntil then
				nextWander = randomPoint(home, Config.WanderMinDistance, Config.WanderRadius)
				idleUntil = now + rng:NextNumber(Config.IdleMin, Config.IdleMax)
				setState("Roaming", "Curious")
			else
				setState("Idle", "Calm")
			end
		end

		if humanoid.Health / math.max(humanoid.MaxHealth, 1) <= Config.FearHealthPercent and not targetRoot then
			npc:SetAttribute("Emotion", "Fearful")
		elseif now < hurtUntil and not targetRoot then
			npc:SetAttribute("Emotion", "Hurt")
		end
		task.wait(Config.ThinkInterval)
	end
end

local function spawnOne(id)
	local ground = spawnPoint()
	if not ground then
		task.delay(3, function() spawnOne(id) end)
		return
	end
	local npc = Template:Clone()
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		warn("NPC model needs a Humanoid and HumanoidRootPart")
		npc:Destroy()
		return
	end
	local rootHeight = humanoid.HipHeight + root.Size.Y / 2 + 0.1
	local pivotOffset = root.CFrame:ToObjectSpace(npc:GetPivot())
	local spawnCFrame = CFrame.new(ground + Vector3.new(0, rootHeight, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	npc:PivotTo(spawnCFrame * pivotOffset)
	npc.Name = string.format("NPC_%02d", id)
	npc:SetAttribute("HomePosition", ground)
	npc.Parent = folder
	equipGear(npc, humanoid)
	addEmotionLabel(npc)
	task.spawn(runAI, npc, ground)
	humanoid.Died:Connect(function()
		Debris:AddItem(npc, 8)
		task.delay(Config.RespawnDelay, function() spawnOne(id) end)
	end)
end

for id = 1, Config.NPCCount do
	task.spawn(spawnOne, id)
end
