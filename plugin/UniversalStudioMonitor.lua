-- Universal Roblox Studio Output Monitor plugin.
-- Independent of Smart NPC System; monitors Studio logs for any project.
-- Input is limited to display controls and safe local text filters; it never runs Lua.
local LogService = game:GetService("LogService")
local Selection = game:GetService("Selection")

local toolbar = plugin:CreateToolbar("Studio Monitor")
local toggle = toolbar:CreateButton("UniversalStudioMonitor", "Open universal Studio output monitor", "")
toggle.ClickableWhenViewportHidden = true
local widget = plugin:CreateDockWidgetPluginGui(
	"UniversalStudioOutputMonitor",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 700, 500, 460, 300)
)
widget.Title = "Universal Studio Monitor"

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(1, 1)
frame.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
frame.Parent = widget

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(10, 7)
title.Size = UDim2.new(1, -20, 0, 24)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Universal Studio Output Monitor"
title.Parent = frame

local filterBox = Instance.new("TextBox")
filterBox.Position = UDim2.fromOffset(10, 38)
filterBox.Size = UDim2.new(1, -300, 0, 30)
filterBox.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
filterBox.TextColor3 = Color3.new(1, 1, 1)
filterBox.PlaceholderText = "Filter logs by text (not a command executor)"
filterBox.ClearTextOnFocus = false
filterBox.Font = Enum.Font.Code
filterBox.TextSize = 12
filterBox.Text = ""
filterBox.Parent = frame

local function makeButton(text, position, width)
	local button = Instance.new("TextButton")
	button.Position = position
	button.Size = UDim2.fromOffset(width, 30)
	button.BackgroundColor3 = Color3.fromRGB(54, 65, 81)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 12
	button.Text = text
	button.Parent = frame
	return button
end

local pauseButton = makeButton("Pause", UDim2.new(1, -282, 0, 38), 62)
local clearButton = makeButton("Clear", UDim2.new(1, -212, 0, 38), 58)
local copyButton = makeButton("Copy visible", UDim2.new(1, -146, 0, 38), 94)
local helpButton = makeButton("Help", UDim2.new(1, -44, 0, 38), 34)

local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(10, 73)
status.Size = UDim2.new(1, -20, 0, 20)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.fromRGB(185, 195, 210)
status.Text = "Capturing Studio logs. Filter input only searches displayed messages."
status.Parent = frame

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(10, 98)
list.Size = UDim2.new(1, -20, 1, -108)
list.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
list.BorderSizePixel = 0
list.ScrollBarThickness = 7
list.CanvasSize = UDim2.fromOffset(0, 0)
list.Parent = frame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 2)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 5)
padding.PaddingLeft = UDim.new(0, 5)
padding.PaddingRight = UDim.new(0, 5)
padding.Parent = list

local entries = {}
local maxEntries = 500
local paused = false
local types = {
	[Enum.MessageType.MessageError] = "ERROR",
	[Enum.MessageType.MessageWarning] = "WARN",
	[Enum.MessageType.MessageInfo] = "INFO",
	[Enum.MessageType.MessageOutput] = "LOG",
}

local function matches(entry, query)
	if query == "" then return true end
	return string.find(string.lower(entry.text), string.lower(query), 1, true) ~= nil
end

local function render()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	local query = filterBox.Text
	local shown = 0
	for index, entry in ipairs(entries) do
		if matches(entry, query) then
			shown += 1
			local row = Instance.new("TextLabel")
			row.Name = "LogEntry"
			row.LayoutOrder = index
			row.Size = UDim2.new(1, -8, 0, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.BackgroundTransparency = 1
			row.Font = Enum.Font.Code
			row.TextSize = 12
			row.TextWrapped = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextYAlignment = Enum.TextYAlignment.Top
			row.TextColor3 = entry.kind == "ERROR" and Color3.fromRGB(255, 120, 120)
				or entry.kind == "WARN" and Color3.fromRGB(255, 205, 105)
				or Color3.fromRGB(218, 225, 235)
			row.Text = string.format("[%s] %s", entry.kind, entry.text)
			row.Parent = list
		end
	end
	status.Text = string.format("%d captured • %d shown • %s", #entries, shown, paused and "paused" or "live")
	task.defer(function()
		list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
		list.CanvasPosition = Vector2.new(0, math.max(0, list.CanvasSize.Y.Offset))
	end)
end

local function addEntry(message, messageType)
	if paused then return end
	table.insert(entries, { kind = types[messageType] or "LOG", text = tostring(message), time = os.date("%H:%M:%S") })
	while #entries > maxEntries do table.remove(entries, 1) end
	render()
end

LogService.MessageOut:Connect(addEntry)
filterBox:GetPropertyChangedSignal("Text"):Connect(render)
pauseButton.Activated:Connect(function()
	paused = not paused
	pauseButton.Text = paused and "Resume" or "Pause"
	render()
end)
clearButton.Activated:Connect(function()
	table.clear(entries)
	render()
end)
copyButton.Activated:Connect(function()
	local visible = {}
	for _, entry in ipairs(entries) do
		if matches(entry, filterBox.Text) then
			table.insert(visible, string.format("[%s] %s", entry.kind, entry.text))
		end
	end
	local copied = pcall(function() setclipboard(table.concat(visible, "\n")) end)
	status.Text = copied and ("Copied " .. #visible .. " visible log entries.") or "Clipboard API unavailable in this Studio version."
end)
helpButton.Activated:Connect(function()
	status.Text = "Universal monitor: captures Studio Output across projects. Filter searches text; no code execution. Click an error row to select nothing (use Output for full traceback)."
end)
toggle.Click:Connect(function() widget.Enabled = not widget.Enabled end)

print("Universal Studio Monitor loaded. It monitors Studio Output for any place and does not execute input.")
