-- Smart NPC System Studio plugin. Includes offline/bundled installers and an optional GitHub updater.
-- The built-in bundle is intentionally self-contained so installation works without a token.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local REPO = "Knight1253/smart-roblox-npc-system"
local BRANCH = "main"
local FILES = {
	{path="src/ServerScriptService/SmartNPCSystem/NPCConfig.lua", name="NPCConfig", class="ModuleScript", where="server"},
	{path="src/ServerScriptService/SmartNPCSystem/NPCController.server.lua", name="NPCController", class="Script", where="server"},
	{path="src/ServerScriptService/SmartNPCSystem/NPCInteractions.server.lua", name="NPCInteractions", class="Script", where="server"},
	{path="src/ServerScriptService/SmartNPCSystem/NPCAdmin.server.lua", name="NPCAdmin", class="Script", where="server"},
	{path="src/StarterPlayer/StarterPlayerScripts/SmartNPCControlPanel.client.lua", name="SmartNPCControlPanel", class="LocalScript", where="client"},
}

-- Built-in fallback sources are shipped inside the .rbxmx plugin. Keep these in sync
-- with src/ServerScriptService/SmartNPCSystem and src/StarterPlayer/StarterPlayerScripts.
local BUNDLE = {
NPCConfig = [==[
return {
 NPCCount=15, RespawnDelay=5, SpawnAttempts=60, MinimumSpawnSpacing=12,
 RegionName="NPCSpawnRegion", TemplateName="NPC", SpawnedFolderName="SpawnedNPCs",
 DetectionRange=80, HearingRange=60, StealthDetectionMultiplier=0.4,
 WanderRadius=45, WanderMinDistance=8, IdleMin=2, IdleMax=6,
 InvestigateSeconds=12, SearchSeconds=15, SearchRadius=18, ThinkInterval=0.3,
 PathRefreshInterval=1.25, MaxChaseDistance=150, AttackDamage=15, AttackRange=5,
 AttackCooldown=1.2, FearHealthPercent=0.3, FleeSeconds=5, UseFactions=true,
 DefaultFaction="Neutral", GroupAlertRange=90, GearFolderName="NPCGear",
 LootFolderName="NPCLoot", LootDropChance=0.25, ShowEmotionLabel=true,
 PatrolFolderName="NPCPatrols", EnablePersistence=true,
 DataStoreName="SmartNPCPlayerData_v1", PersistenceSaveInterval=90,
 StartingCoins=100, StartingReputation=0, MemoryLimit=100, AdminUserIds={},
}
]==],
NPCController = [==[
-- Bundled NPC spawner and sandbox AI. Server-authoritative.
local Players=game:GetService("Players")
local SS=game:GetService("ServerStorage")
local W=workspace
local PF=game:GetService("PathfindingService")
local Debris=game:GetService("Debris")
local C=require(script.Parent.NPCConfig)
local template=SS:WaitForChild(C.TemplateName)
local region=W:WaitForChild(C.RegionName)
local rng=Random.new()
local folder=W:FindFirstChild(C.SpawnedFolderName) or Instance.new("Folder")
folder.Name=C.SpawnedFolderName; folder.Parent=W
local function ground(p)
 local r=W:Raycast(p+Vector3.new(0,500,0),Vector3.new(0,-1200,0))
 return r and r.Position
end
local function point(center,min,max)
 for _=1,16 do
  local a=rng:NextNumber()*math.pi*2; local d=rng:NextNumber(min,max)
  local p=ground(center+Vector3.new(math.cos(a)*d,0,math.sin(a)*d))
  if p then return p end
 end
 return center
end
local function path(h,root,dest)
 local p=PF:CreatePath({AgentCanJump=true,AgentCanClimb=true})
 local ok=pcall(function() p:ComputeAsync(root.Position,dest) end)
 if ok and p.Status==Enum.PathStatus.Success then
  local w=p:GetWaypoints()[2]
  if w then if w.Action==Enum.PathWaypointAction.Jump then h.Jump=true end; h:MoveTo(w.Position); return end
 end
 h:MoveTo(dest)
end
local function spawnPos()
 local half=region.Size/2
 for _=1,C.SpawnAttempts do
  local lp=Vector3.new(rng:NextNumber(-half.X,half.X),0,rng:NextNumber(-half.Z,half.Z))
  local p=ground(region.CFrame:PointToWorldSpace(lp))
  if p then
   local clear=true
   for _,n in ipairs(folder:GetChildren()) do local r=n:FindFirstChild("HumanoidRootPart"); if r and (r.Position-p).Magnitude<C.MinimumSpawnSpacing then clear=false; break end end
   if clear then return p end
  end
 end
end
local function equip(n,h)
 local f=SS:FindFirstChild(C.GearFolderName); local t={}
 if f then for _,x in ipairs(f:GetChildren()) do if x:IsA("Tool") then table.insert(t,x) end end end
 if #t==0 then n:SetAttribute("GearName","Unarmed"); n:SetAttribute("WeaponType","Melee"); n:SetAttribute("AttackDamage",C.AttackDamage); n:SetAttribute("AttackRange",C.AttackRange); n:SetAttribute("AttackCooldown",C.AttackCooldown); return end
 local tool=t[rng:NextInteger(1,#t)]:Clone(); n:SetAttribute("GearName",tool.Name)
 for attr,key,default in pairs({Damage={"AttackDamage",C.AttackDamage},Range={"AttackRange",C.AttackRange},Cooldown={"AttackCooldown",C.AttackCooldown},MagazineSize={"MagazineSize",8},ReloadTime={"ReloadTime",2}}) do n:SetAttribute(key,tool:GetAttribute(attr) or default) end
 n:SetAttribute("WeaponType",tool:GetAttribute("WeaponType") or "Melee"); n:SetAttribute("Ammo",n:GetAttribute("MagazineSize")); tool.Parent=n; h:EquipTool(tool)
end
local function visible(n,char,a,b)
 local q=RaycastParams.new(); q.FilterType=Enum.RaycastFilterType.Exclude; q.FilterDescendantsInstances={n}
 local hit=W:Raycast(a,b-a,q); return not hit or hit.Instance:IsDescendantOf(char)
end
local function ai(n,home)
 local h=n:FindFirstChildOfClass("Humanoid"); local root=n:FindFirstChild("HumanoidRootPart"); if not h or not root then return end
 local known,lastSeen,nextWander=nil,0,nil; local lastPath,lastAttack=0,0; local idle=os.clock()+rng:NextNumber(C.IdleMin,C.IdleMax); local lastHealth=h.Health; local hurtUntil=0
 h.HealthChanged:Connect(function(v) if v<lastHealth then hurtUntil=os.clock()+3 end; lastHealth=v end)
 while n.Parent and h.Health>0 do
  local now=os.clock(); local target,th,tr,dist=nil,nil,nil,C.DetectionRange
  for _,plr in ipairs(Players:GetPlayers()) do
   local ch=plr.Character; local hum=ch and ch:FindFirstChildOfClass("Humanoid"); local r=ch and ch:FindFirstChild("HumanoidRootPart")
   local factionOK=not C.UseFactions or (n:GetAttribute("Faction") or C.DefaultFaction)=="Neutral" or (plr:GetAttribute("Faction") or "Player")~=(n:GetAttribute("Faction") or C.DefaultFaction)
   local range=C.DetectionRange*((ch and ch:GetAttribute("Stealth")) and C.StealthDetectionMultiplier or 1)
   if factionOK and hum and r and hum.Health>0 then local d=(r.Position-root.Position).Magnitude; if d<=range and d<dist and visible(n,ch,root.Position,r.Position) then target,th,tr,dist=ch,hum,r,d end end
  end
  local state,emotion="Idle","Calm"
  if tr then known,lastSeen=tr.Position,now end
  local low=h.Health/math.max(h.MaxHealth,1)<=C.FearHealthPercent
  if low and tr then
   state,emotion="Fleeing","Fearful"; local away=(root.Position-tr.Position); if away.Magnitude<0.1 then away=Vector3.new(1,0,0) end
   if now-lastPath>1 then lastPath=now; path(h,root,point(root.Position+away.Unit*20,5,14)) end
  elseif tr and dist<=(n:GetAttribute("AttackRange") or C.AttackRange) then
   if n:GetAttribute("WeaponType")=="Ranged" then
    local ammo=n:GetAttribute("Ammo") or 0
    if ammo<=0 then state,emotion="Reloading","Anxious"; n:SetAttribute("Ammo",n:GetAttribute("MagazineSize") or 8)
    elseif now-lastAttack>=(n:GetAttribute("AttackCooldown") or C.AttackCooldown) then
     state,emotion="Attacking","Angry"; lastAttack=now; n:SetAttribute("Ammo",ammo-1)
     if visible(n,target,root.Position,tr.Position) then th:TakeDamage(n:GetAttribute("AttackDamage") or C.AttackDamage) end
    end
   elseif now-lastAttack>=(n:GetAttribute("AttackCooldown") or C.AttackCooldown) then state,emotion="Attacking","Angry"; lastAttack=now; th:TakeDamage(n:GetAttribute("AttackDamage") or C.AttackDamage)
   else state,emotion="Attacking","Angry" end
  elseif tr then state,emotion="Chasing","Alert"; if (tr.Position-home).Magnitude<C.MaxChaseDistance and now-lastPath>C.PathRefreshInterval then lastPath=now; path(h,root,tr.Position) end
  elseif known and now-lastSeen<C.InvestigateSeconds+C.SearchSeconds then
   state,emotion=(root.Position-known).Magnitude>5 and "Investigating" or "Searching","Curious"
   if now-lastPath>(state=="Searching" and 2.5 or C.PathRefreshInterval) then lastPath=now; path(h,root,state=="Investigating" and known or point(known,4,C.SearchRadius)) end
  elseif (root.Position-home).Magnitude>C.WanderRadius then state,emotion="Returning","Worried"; if now-lastPath>C.PathRefreshInterval then lastPath=now; path(h,root,home) end
  elseif nextWander and (root.Position-nextWander).Magnitude>5 then state,emotion="Roaming","Curious"; if now-lastPath>C.PathRefreshInterval then lastPath=now; path(h,root,nextWander) end
  elseif now>=idle then nextWander=point(home,C.WanderMinDistance,C.WanderRadius); idle=now+rng:NextNumber(C.IdleMin,C.IdleMax); state,emotion="Roaming","Curious" end
  if now<hurtUntil and not tr then emotion="Hurt" end
  n:SetAttribute("AIState",state); n:SetAttribute("Emotion",emotion); task.wait(C.ThinkInterval)
 end
end
local function spawn(id)
 local p=spawnPos(); if not p then task.delay(3,function() spawn(id) end); return end
 local n=template:Clone(); local h=n:FindFirstChildOfClass("Humanoid"); local root=n:FindFirstChild("HumanoidRootPart")
 if not h or not root then warn("NPC requires Humanoid and HumanoidRootPart"); n:Destroy(); return end
 local offset=root.CFrame:ToObjectSpace(n:GetPivot()); n:PivotTo(CFrame.new(p+Vector3.new(0,h.HipHeight+root.Size.Y/2,0))*offset)
 n.Name=string.format("NPC_%02d",id); n:SetAttribute("HomePosition",p); n:SetAttribute("Faction",n:GetAttribute("Faction") or C.DefaultFaction); n.Parent=folder; equip(n,h)
 if C.ShowEmotionLabel then local head=n:FindFirstChild("Head"); if head then local gui=Instance.new("BillboardGui"); gui.Name="NPCEmotionLabel"; gui.Adornee=head; gui.Size=UDim2.fromOffset(130,28); gui.StudsOffset=Vector3.new(0,2.7,0); gui.AlwaysOnTop=true; gui.Parent=head; local label=Instance.new("TextLabel"); label.Size=UDim2.fromScale(1,1); label.BackgroundTransparency=1; label.TextScaled=true; label.Font=Enum.Font.GothamBold; label.TextColor3=Color3.new(1,1,1); label.TextStrokeTransparency=.3; label.Parent=gui; local function update() label.Text=n:GetAttribute("Emotion") or "Calm" end; n:GetAttributeChangedSignal("Emotion"):Connect(update); update() end end
 task.spawn(ai,n,p); h.Died:Connect(function() Debris:AddItem(n,8); task.delay(C.RespawnDelay,function() spawn(id) end) end)
end
for i=1,C.NPCCount do task.spawn(spawn,i) end
]==],
NPCInteractions = [==[
-- Built-in NPC memory, talk/shop prompts, and player data persistence.
local Players=game:GetService("Players"); local SS=game:GetService("ServerStorage"); local DSS=game:GetService("DataStoreService"); local Http=game:GetService("HttpService")
local C=require(script.Parent.NPCConfig); local folder=workspace:WaitForChild(C.SpawnedFolderName); local db=C.EnablePersistence and DSS:GetDataStore(C.DataStoreName) or nil; local memories={}; local saving={}
local function notify(p,s) p:SetAttribute("NPCNotice",s) end
local function load(p)
 local stats=p:FindFirstChild("leaderstats") or Instance.new("Folder"); stats.Name="leaderstats"; stats.Parent=p
 for _,spec in ipairs({{"Coins",C.StartingCoins},{"Reputation",C.StartingReputation}}) do local v=stats:FindFirstChild(spec[1]) or Instance.new("IntValue"); v.Name=spec[1]; v.Value=spec[2]; v.Parent=stats end
 local data; if db then local ok,res=pcall(function() return db:GetAsync("p_"..p.UserId) end); if ok and type(res)=="table" then data=res end end
 memories[p]=data and data.memories or {}; if data then stats.Coins.Value=tonumber(data.coins) or stats.Coins.Value; stats.Reputation.Value=tonumber(data.rep) or stats.Reputation.Value; p:SetAttribute("NPCQuest",data.quest or "") else p:SetAttribute("NPCQuest","") end
 local ok,json=pcall(function() return Http:JSONEncode(memories[p]) end); if ok then p:SetAttribute("NPCMemories",json) end
end
local function save(p)
 if not db or saving[p] then return end; saving[p]=true; local s=p:FindFirstChild("leaderstats"); local data={coins=s and s.Coins.Value or C.StartingCoins,rep=s and s.Reputation.Value or 0,quest=p:GetAttribute("NPCQuest") or "",memories=memories[p] or {}}
 local ok,e=pcall(function() db:UpdateAsync("p_"..p.UserId,function(old) old=type(old)=="table" and old or {}; for k,v in pairs(data) do old[k]=v end; return old end) end); if not ok then warn("NPC save failed",e) end; saving[p]=nil
end
Players.PlayerAdded:Connect(load); Players.PlayerRemoving:Connect(function(p) save(p); memories[p]=nil end); for _,p in ipairs(Players:GetPlayers()) do task.spawn(load,p) end
if db then task.spawn(function() while true do task.wait(C.PersistenceSaveInterval); for _,p in ipairs(Players:GetPlayers()) do task.spawn(save,p) end end end); game:BindToClose(function() for _,p in ipairs(Players:GetPlayers()) do task.spawn(save,p) end; task.wait(3) end) end
local function interact(p,n)
 local ch=p.Character; local pr=ch and ch:FindFirstChild("HumanoidRootPart"); local nr=n:FindFirstChild("HumanoidRootPart"); if not pr or not nr or (pr.Position-nr.Position).Magnitude>14 then return end
 local key=tostring(n:GetAttribute("MemoryKey") or n.Name); local m=memories[p] or {}; memories[p]=m; local rec=m[key] or {meetings=0,relationship=0}; rec.meetings+=1; rec.relationship=math.clamp(rec.relationship+1,-100,100); rec.lastMet=os.time(); m[key]=rec
 local c=0; for _ in pairs(m) do c+=1 end; while c>(C.MemoryLimit or 100) do local oldKey,oldTime; for k,v in pairs(m) do if not oldTime or (v.lastMet or 0)<oldTime then oldKey,oldTime=k,v.lastMet or 0 end end; if not oldKey then break end; m[oldKey]=nil;c-=1 end
 local ok,json=pcall(function() return Http:JSONEncode(m) end); if ok then p:SetAttribute("NPCMemories",json) end
 local name=n:GetAttribute("DisplayName") or n.Name; local greeting=rec.meetings==1 and "Nice to meet you, " or "Welcome back, "
 notify(p,name..": "..(n:GetAttribute("DialogueText") or (greeting..p.DisplayName.."!")))
 local quest=n:GetAttribute("QuestName"); if quest and quest~="" then p:SetAttribute("NPCQuest",quest); p:SetAttribute("NPCQuestProgress",0); p:SetAttribute("NPCQuestGoal",n:GetAttribute("QuestGoal") or 3); p:SetAttribute("NPCQuestReward",n:GetAttribute("QuestReward") or 25); notify(p,"Quest started: "..quest) end
end
local function attach(n)
 local root=n:FindFirstChild("HumanoidRootPart"); if not root or root:FindFirstChild("NPCPrompts") then return end; local a=Instance.new("Attachment"); a.Name="NPCPrompts"; a.Parent=root
 local prompt=Instance.new("ProximityPrompt"); prompt.ActionText="Talk"; prompt.ObjectText=n:GetAttribute("DisplayName") or n.Name; prompt.MaxActivationDistance=10; prompt.Parent=a; prompt.Triggered:Connect(function(p) interact(p,n) end)
 if n:GetAttribute("ShopEnabled") then local shop=Instance.new("ProximityPrompt"); shop.ActionText="Shop"; shop.ObjectText=n.Name; shop.MaxActivationDistance=10; shop.Parent=a; shop.Triggered:Connect(function(p) local items=SS:FindFirstChild("NPCShopItems"); local s=p:FindFirstChild("leaderstats"); local coins=s and s:FindFirstChild("Coins"); local item=items and items:GetChildren()[1]; if not item or not item:IsA("Tool") or not coins then notify(p,"Shop unavailable."); return end; local price=item:GetAttribute("Price") or 10; local bag=p:FindFirstChildOfClass("Backpack"); if coins.Value<price or not bag then notify(p,"Not enough coins."); return end; coins.Value-=price; item:Clone().Parent=bag; notify(p,"Bought "..item.Name) end) end
end
for _,n in ipairs(folder:GetChildren()) do attach(n) end; folder.ChildAdded:Connect(function(n) task.defer(attach,n) end)
]==],
NPCAdmin = [==[
-- Server-side authorization and commands for control panel.
local Players=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local C=require(script.Parent.NPCConfig); local folder=workspace:WaitForChild(C.SpawnedFolderName)
local rem=RS:FindFirstChild("SmartNPCControl") or Instance.new("Folder"); rem.Name="SmartNPCControl"; rem.Parent=RS
local get=rem:FindFirstChild("GetSnapshot") or Instance.new("RemoteFunction"); get.Name="GetSnapshot"; get.Parent=rem
local cmd=rem:FindFirstChild("Command") or Instance.new("RemoteEvent"); cmd.Name="Command"; cmd.Parent=rem
local function allowed(p)
 if table.find(C.AdminUserIds or {},p.UserId) then return true end
 if game.PrivateServerId~="" and game.PrivateServerOwnerId==p.UserId then return true end
 if game.CreatorType==Enum.CreatorType.User then return p.UserId==game.CreatorId end
 if game.CreatorType==Enum.CreatorType.Group then local ok,rank=pcall(function() return p:GetRankInGroup(game.CreatorId) end); return ok and rank==255 end
 return false
end
get.OnServerInvoke=function(p) if not allowed(p) then return {authorized=false} end; local rows={}; for _,n in ipairs(folder:GetChildren()) do local h=n:FindFirstChildOfClass("Humanoid"); if h then table.insert(rows,{name=n.Name,state=n:GetAttribute("AIState") or "?",emotion=n:GetAttribute("Emotion") or "Calm",health=math.floor(h.Health),maxHealth=math.floor(h.MaxHealth)}) end end; return {authorized=true,npcs=rows,ai=workspace:GetAttribute("SmartNPCAIEnabled")~=false,spawning=workspace:GetAttribute("SmartNPCSpawningEnabled")~=false} end
local last={}; cmd.OnServerEvent:Connect(function(p,action,value) if not allowed(p) or os.clock()-(last[p] or 0)<.5 then return end; last[p]=os.clock(); if action=="AI" and typeof(value)=="boolean" then workspace:SetAttribute("SmartNPCAIEnabled",value) elseif action=="Spawning" and typeof(value)=="boolean" then workspace:SetAttribute("SmartNPCSpawningEnabled",value) elseif action=="Recall" then for _,n in ipairs(folder:GetChildren()) do local r=n:FindFirstChild("HumanoidRootPart"); local home=n:GetAttribute("HomePosition"); if r and typeof(home)=="Vector3" then r.CFrame=CFrame.new(home+Vector3.new(0,3,0)); r.AssemblyLinearVelocity=Vector3.zero end end elseif action=="Heal" then for _,n in ipairs(folder:GetChildren()) do local h=n:FindFirstChildOfClass("Humanoid"); if h then h.Health=h.MaxHealth end end end end)
]==],
SmartNPCControlPanel = [==[
-- TopbarPlus owner control panel. Requires ReplicatedStorage.Icon (TopbarPlus v3).
local RS=game:GetService("ReplicatedStorage"); local Players=game:GetService("Players"); local p=Players.LocalPlayer; local rem=RS:WaitForChild("SmartNPCControl"); local get=rem:WaitForChild("GetSnapshot"); local cmd=rem:WaitForChild("Command")
local iconModule=RS:FindFirstChild("Icon"); local packages=RS:FindFirstChild("Packages"); if not iconModule and packages then local pkg=packages:FindFirstChild("TopbarPlus"); iconModule=pkg and (pkg:FindFirstChild("Icon") or pkg) end
if not iconModule then warn("Install TopbarPlus v3 in ReplicatedStorage to enable NPC panel"); return end
local ok,Icon=pcall(require,iconModule); if not ok then warn("TopbarPlus Icon require failed",Icon); return end
local gui=Instance.new("ScreenGui"); gui.Name="SmartNPCPanel"; gui.ResetOnSpawn=false; gui.Enabled=false; gui.Parent=p:WaitForChild("PlayerGui")
local panel=Instance.new("Frame"); panel.AnchorPoint=Vector2.new(1,0); panel.Position=UDim2.new(1,-20,0,70); panel.Size=UDim2.fromOffset(330,370); panel.BackgroundColor3=Color3.fromRGB(30,34,42); panel.Parent=gui
local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-20,0,32); title.Position=UDim2.fromOffset(10,8); title.BackgroundTransparency=1; title.Text="NPC CONTROL"; title.Font=Enum.Font.GothamBold; title.TextColor3=Color3.new(1,1,1); title.TextSize=18; title.Parent=panel
local status=Instance.new("TextLabel"); status.Position=UDim2.fromOffset(10,42); status.Size=UDim2.new(1,-20,0,32); status.BackgroundTransparency=1; status.TextColor3=Color3.new(1,1,1); status.TextWrapped=true; status.Text="Owner controls"; status.Parent=panel
local list=Instance.new("ScrollingFrame"); list.Position=UDim2.fromOffset(10,78); list.Size=UDim2.new(1,-20,1,-88); list.CanvasSize=UDim2.new(); list.ScrollBarThickness=6; list.Parent=panel
local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,5); layout.Parent=list
local function clear() for _,x in ipairs(list:GetChildren()) do if x:IsA("GuiButton") or x:IsA("TextLabel") then x:Destroy() end end end
local function button(text,fn)
 local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-8,0,32); b.BackgroundColor3=Color3.fromRGB(58,72,92); b.TextColor3=Color3.new(1,1,1); b.Text=text; b.Font=Enum.Font.Gotham; b.TextSize=13; b.Parent=list; b.Activated:Connect(fn)
end
local function refresh()
 local success,d=pcall(function() return get:InvokeServer() end); if not success or not d then status.Text="Server unavailable"; return end; if not d.authorized then gui.Enabled=false; status.Text="Owner access only"; return end
 clear(); button("AI: "..(d.ai and "ON — click to pause" or "PAUSED — click to resume"),function() cmd:FireServer("AI",not d.ai); task.wait(.25); refresh() end)
 button("Spawning: "..(d.spawning and "ON — click to stop" or "STOPPED — click to start"),function() cmd:FireServer("Spawning",not d.spawning); task.wait(.25); refresh() end)
 button("Recall all NPCs",function() cmd:FireServer("Recall") end); button("Heal all NPCs",function() cmd:FireServer("Heal") end)
 for _,n in ipairs(d.npcs or {}) do local row=Instance.new("TextLabel"); row.Size=UDim2.new(1,-8,0,25); row.BackgroundTransparency=1; row.TextColor3=Color3.new(1,1,1); row.TextXAlignment=Enum.TextXAlignment.Left; row.Font=Enum.Font.Gotham; row.TextSize=12; row.Text=n.name.." | "..n.state.." | "..n.health.."/"..n.maxHealth; row.Parent=list end
 task.defer(function() list.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+10) end); status.Text="Server-authorized owner panel"
end
local icon=Icon.new():setLabel("NPCs"):setOrder(8); icon:bindEvent("selected",function() gui.Enabled=true; refresh() end); icon:bindEvent("deselected",function() gui.Enabled=false end)
]==],
}

local function getDestination(file)
	if file.where == "client" then
		local scripts=StarterPlayer:FindFirstChild("StarterPlayerScripts")
		if not scripts then scripts=Instance.new("StarterPlayerScripts"); scripts.Parent=StarterPlayer end
		return scripts
	end
	local root=ServerScriptService:FindFirstChild("SmartNPCSystem")
	if not root then root=Instance.new("Folder"); root.Name="SmartNPCSystem"; root.Parent=ServerScriptService end
	return root
end
local function installSources(sources)
	for _,file in ipairs(FILES) do
		local dest=getDestination(file); local object=dest:FindFirstChild(file.name)
		if object and not object:IsA(file.class) then object:Destroy(); object=nil end
		if not object then object=Instance.new(file.class); object.Name=file.name; object.Parent=dest end
		local ok,err=pcall(function() ScriptEditorService:UpdateSourceAsync(object,function() return sources[file.name] end) end)
		if not ok then error("Couldn't write "..file.name..": "..tostring(err)) end
	end
	pcall(function() ChangeHistoryService:SetWaypoint("Installed Smart NPC System") end)
end

local toolbar=plugin:CreateToolbar("Smart NPC System")
local open=toolbar:CreateButton("SmartNPCInstaller","Install bundled scripts or update from private GitHub repo","rbxassetid://4458901886")
open.ClickableWhenViewportHidden=true
local widget=plugin:CreateDockWidgetPluginGui("SmartNPCInstallerOptions",DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,true,false,420,290,360,240))
widget.Title="Smart NPC System Installer"
local frame=Instance.new("Frame"); frame.Size=UDim2.fromScale(1,1); frame.BackgroundColor3=Color3.fromRGB(34,37,44); frame.Parent=widget
local text=Instance.new("TextLabel"); text.Position=UDim2.fromOffset(12,10); text.Size=UDim2.new(1,-24,0,56); text.BackgroundTransparency=1; text.TextWrapped=true; text.Font=Enum.Font.Gotham; text.TextSize=13; text.TextColor3=Color3.new(1,1,1); text.Text="Bundled mode works offline and needs no GitHub token. The optional update mode fetches latest source from the private repository."; text.Parent=frame
local tokenBox=Instance.new("TextBox"); tokenBox.Position=UDim2.fromOffset(12,76); tokenBox.Size=UDim2.new(1,-24,0,34); tokenBox.PlaceholderText="Optional fine-grained read-only GitHub token"; tokenBox.ClearTextOnFocus=false; tokenBox.Text=""; tokenBox.Parent=frame
local bundled=Instance.new("TextButton"); bundled.Position=UDim2.fromOffset(12,122); bundled.Size=UDim2.new(1,-24,0,38); bundled.Text="Install bundled scripts"; bundled.Font=Enum.Font.GothamBold; bundled.TextSize=14; bundled.Parent=frame
local latest=Instance.new("TextButton"); latest.Position=UDim2.fromOffset(12,168); latest.Size=UDim2.new(1,-24,0,38); latest.Text="Fetch latest from private GitHub"; latest.Font=Enum.Font.GothamBold; latest.TextSize=14; latest.Parent=frame
local status=Instance.new("TextLabel"); status.Position=UDim2.fromOffset(12,214); status.Size=UDim2.new(1,-24,0,54); status.BackgroundTransparency=1; status.TextWrapped=true; status.TextColor3=Color3.new(1,1,1); status.Text=""; status.Parent=frame
open.Click:Connect(function() widget.Enabled=not widget.Enabled end)
bundled.Activated:Connect(function() local ok,err=pcall(function() installSources(BUNDLE) end); status.Text=ok and "Bundled framework installed. Add NPC template and spawn region." or tostring(err) end)
latest.Activated:Connect(function()
 local token=tokenBox.Text; if token=="" then status.Text="Enter a read-only token, or use bundled install."; return end
 local ok,err=pcall(function()
  local sources={}
  for _,file in ipairs(FILES) do
   local response=HttpService:RequestAsync({Url="https://api.github.com/repos/"..REPO.."/contents/"..file.path.."?ref="..BRANCH,Method="GET",Headers={Authorization="Bearer "..token,Accept="application/vnd.github+json",["X-GitHub-Api-Version"]="2022-11-28",["User-Agent"]="SmartNPCStudioPlugin"}})
   if not response.Success then error("GitHub request failed: "..response.StatusCode) end
   local data=HttpService:JSONDecode(response.Body); sources[file.name]=HttpService:Base64Decode(string.gsub(data.content or "","%s",""))
  end
  installSources(sources)
 end)
 tokenBox.Text=""; token=nil; status.Text=ok and "Latest repository scripts installed." or ("Update failed: "..tostring(err))
end)
print("Smart NPC Installer loaded. Choose bundled offline install or authenticated repository update.")
