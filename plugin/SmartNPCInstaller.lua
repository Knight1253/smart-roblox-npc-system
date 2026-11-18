-- Smart NPC System local Studio plugin.
-- Downloads every maintained source file from the GitHub repository.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local ServerScriptService = game:GetService("ServerScriptService")
local REPO, BRANCH = "Knight1253/smart-roblox-npc-system", "main"
local RAW = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local FILES = {
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCConfig.lua", name = "NPCConfig", class = "ModuleScript" },
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCController.server.lua", name = "NPCController", class = "Script" },
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCInteractions.server.lua", name = "NPCInteractions", class = "Script" },
}
local toolbar = plugin:CreateToolbar("Smart NPC System")
local button = toolbar:CreateButton("InstallSmartNPCSystem", "Fetch and install the Smart NPC framework", "")
button.ClickableWhenViewportHidden = true

local function setSource(instance, source)
	local ok, err = pcall(function() ScriptEditorService:UpdateSourceAsync(instance, function() return source end) end)
	return ok, err
end

button.Click:Connect(function()
	local ok, err = pcall(function()
		-- Fetch every file first, so a failed network request doesn't partially update the place.
		local sources = {}
		for _, file in ipairs(FILES) do sources[file.name] = HttpService:GetAsync(RAW .. "/" .. file.path) end
		local root = ServerScriptService:FindFirstChild("SmartNPCSystem")
		if not root then root = Instance.new("Folder"); root.Name = "SmartNPCSystem"; root.Parent = ServerScriptService end
		for _, file in ipairs(FILES) do
			local object = root:FindFirstChild(file.name)
			if object and not object:IsA(file.class) then object:Destroy(); object = nil end
			if not object then object = Instance.new(file.class); object.Name = file.name; object.Parent = root end
			local saved, sourceErr = setSource(object, sources[file.name])
			if not saved then error("Unable to update " .. file.name .. ": " .. tostring(sourceErr)) end
		end
		pcall(function() ChangeHistoryService:SetWaypoint("Installed Smart NPC Framework") end)
		print("Installed scripts from " .. REPO .. ". Add ServerStorage.NPC and Workspace.NPCSpawnRegion.")
	end)
	if not ok then
		warn("Smart NPC install failed: " .. tostring(err))
		warn("The repository must be publicly readable for raw GitHub downloads, and Studio HTTP requests must be enabled.")
	end
end)
print("Smart NPC plugin loaded. Click the toolbar button to fetch the repository package.")
