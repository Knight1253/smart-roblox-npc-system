-- Smart NPC System local Studio plugin.
-- Fetches the maintained scripts from this GitHub repository and installs them
-- into the currently open place when the user clicks the toolbar button.
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local ServerScriptService = game:GetService("ServerScriptService")

local REPO = "Knight1253/smart-roblox-npc-system"
local BRANCH = "main"
local RAW_BASE = "https://raw.githubusercontent.com/" .. REPO .. "/" .. BRANCH
local FILES = {
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCConfig.lua", name = "NPCConfig", className = "ModuleScript" },
	{ path = "src/ServerScriptService/SmartNPCSystem/NPCController.server.lua", name = "NPCController", className = "Script" },
}

local toolbar = plugin:CreateToolbar("Smart NPC System")
local installButton = toolbar:CreateButton("InstallSmartNPCSystem", "Fetch and install/update Smart NPC scripts from GitHub", "")
installButton.ClickableWhenViewportHidden = true

local function writeSource(instance, source)
	local ok, err = pcall(function()
		ScriptEditorService:UpdateSourceAsync(instance, function()
			return source
		end)
	end)
	return ok, err
end

installButton.Click:Connect(function()
	local ok, err = pcall(function()
		local root = ServerScriptService:FindFirstChild("SmartNPCSystem")
		if not root then
			root = Instance.new("Folder")
			root.Name = "SmartNPCSystem"
			root.Parent = ServerScriptService
		end

		-- Fetch all repository files before changing the place, so network errors
		-- cannot leave a half-updated package.
		local fetched = {}
		for _, file in ipairs(FILES) do
			local url = RAW_BASE .. "/" .. file.path
			fetched[file.name] = HttpService:GetAsync(url)
		end

		for _, file in ipairs(FILES) do
			local instance = root:FindFirstChild(file.name)
			if instance and not instance:IsA(file.className) then
				instance:Destroy()
				instance = nil
			end
			if not instance then
				instance = Instance.new(file.className)
				instance.Name = file.name
				instance.Parent = root
			end
			local saved, sourceError = writeSource(instance, fetched[file.name])
			if not saved then error("Couldn't write " .. file.name .. ": " .. tostring(sourceError)) end
		end

		pcall(function()
			ChangeHistoryService:SetWaypoint("Installed Smart NPC System from GitHub")
		end)
		print("Smart NPC scripts fetched from " .. REPO .. " (" .. BRANCH .. "). Add ServerStorage.NPC and Workspace.NPCSpawnRegion.")
	end)

	if not ok then
		warn("Smart NPC installation failed: " .. tostring(err))
		warn("Check internet access and enable Game Settings > Security > Allow HTTP Requests, then retry.")
	end
end)

print("Smart NPC System plugin ready. Click its toolbar button to fetch the latest package from GitHub.")
