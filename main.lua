--[[
	Violence District - versi rapi (layout sidebar + tab, UI Obsidian)
	Belum diuji di game: dibuat tanpa bisa menjalankan Roblox.
	Tab: Survivor, ESP, Settings, Config.
	Kalau ada fitur yang error, kirim pesan error dari console executor.
]]

----------------------------------------------------------------
-- Library
----------------------------------------------------------------
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local Options, Toggles = Library.Options, Library.Toggles

----------------------------------------------------------------
-- Services & state
----------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local connections = {}

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function getChar()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return char, hum, root
end

----------------------------------------------------------------
-- Window & tabs
----------------------------------------------------------------
local Window = Library:CreateWindow({
	Title = "Violence District",
	Footer = "clean build",
	ToggleKeybind = Enum.KeyCode.RightControl,
	Center = true,
	AutoShow = true,
})

local Tabs = {
	Survivor = Window:AddTab("Survivor", "user"),
	ESP = Window:AddTab("ESP", "eye"),
	Settings = Window:AddTab("Settings", "settings"),
	Config = Window:AddTab("Config", "save"),
}

----------------------------------------------------------------
-- SURVIVOR: Auto Perfect Skill Check
----------------------------------------------------------------
local GenBox = Tabs.Survivor:AddLeftGroupbox("Generators")

GenBox:AddToggle("autoPerfectSkillCheck", {
	Text = "Auto Perfect Skill Check",
	Default = false,
	Tooltip = "Menekan Space otomatis saat jarum ada di zona perfect.",
})
GenBox:AddSlider("skillTolerance", {
	Text = "Tolerance (derajat)",
	Default = 0, Min = 0, Max = 6, Rounding = 1,
	Tooltip = "Perlebar zona jika sering meleset.",
})
GenBox:AddToggle("skillDebug", {
	Text = "Debug skill check",
	Default = false,
	Tooltip = "Print rotasi Line/Goal ke console (F9). Kirim hasilnya kalau masih gagal.",
})

local pressing, lastDebug = false, 0
connect(RunService.Heartbeat, function()
	if not Toggles.autoPerfectSkillCheck.Value or pressing then return end

	local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("SkillCheckPromptGui")
	local check = gui and gui:FindFirstChild("Check")
	if not (check and check.Visible) then return end

	local line, goal = check:FindFirstChild("Line"), check:FindFirstChild("Goal")
	if not (line and goal) then return end

	-- selisih sudut dinormalisasi 0..360 supaya tidak meleset saat rotasi wrap
	local diff = (line.Rotation - goal.Rotation) % 360
	local tol = Options.skillTolerance.Value

	if Toggles.skillDebug.Value and tick() - lastDebug > 0.2 then
		lastDebug = tick()
		print(("[SkillCheck] line=%.1f goal=%.1f diff=%.1f"):format(line.Rotation, goal.Rotation, diff))
	end

	if diff >= 104 - tol and diff <= 114 + tol then
		pressing = true
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
		task.wait(0.01)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
		task.wait(0.15) -- jeda supaya tidak menekan dua kali di zona yang sama
		pressing = false
	end
end)

----------------------------------------------------------------
-- SURVIVOR: Movement
----------------------------------------------------------------
local MoveBox = Tabs.Survivor:AddRightGroupbox("Movement")

MoveBox:AddToggle("noclip", { Text = "No Clip", Default = false })
connect(RunService.Stepped, function()
	if not Toggles.noclip.Value then return end
	local char = getChar()
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end)

MoveBox:AddInput("speedValue", {
	Text = "Speed Boost Value",
	Default = "18", Numeric = true, Finished = true,
	Placeholder = "mis. 18",
})
MoveBox:AddToggle("speedBoost", {
	Text = "Speed Boost",
	Default = false,
	Tooltip = "Menambah kecepatan lewat CFrame (WalkSpeed sering di-reset game).",
})
connect(RunService.Heartbeat, function(dt)
	if not Toggles.speedBoost.Value then return end
	local _, hum, root = getChar()
	if not (hum and root) then return end
	local target = tonumber(Options.speedValue.Value) or 16
	local extra = target - hum.WalkSpeed
	if extra > 0 and hum.MoveDirection.Magnitude > 0 then
		root.CFrame = root.CFrame + hum.MoveDirection * extra * dt
	end
end)

MoveBox:AddToggle("infJump", { Text = "Infinite Jump", Default = false })
connect(UserInputService.JumpRequest, function()
	if not Toggles.infJump.Value then return end
	local _, hum = getChar()
	if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

----------------------------------------------------------------
-- ESP (Highlight)
----------------------------------------------------------------
local EspBox = Tabs.ESP:AddLeftGroupbox("Objects")
local PlayerBox = Tabs.ESP:AddRightGroupbox("Players")

local espTypes = {
	{ id = "generatorEsp", label = "Generator ESP", name = "Generator", color = Color3.fromRGB(255, 200, 0) },
	{ id = "hookEsp", label = "Hook ESP", name = "Hook", color = Color3.fromRGB(255, 60, 60) },
	{ id = "palletEsp", label = "Pallet ESP", name = "Pallet", color = Color3.fromRGB(180, 120, 60), prefix = true },
	{ id = "gateEsp", label = "Gate ESP", name = "Gate", color = Color3.fromRGB(80, 200, 255) },
	{ id = "vaultEsp", label = "Window/Vault ESP", name = "Window", alt = "Vault", color = Color3.fromRGB(120, 255, 120) },
}

for _, t in ipairs(espTypes) do
	EspBox:AddToggle(t.id, { Text = t.label, Default = false })
		:AddColorPicker(t.id .. "Color", { Default = t.color })
end
PlayerBox:AddToggle("playerEsp", { Text = "Player ESP", Default = false })
	:AddColorPicker("playerEspColor", { Default = Color3.fromRGB(255, 255, 255) })
PlayerBox:AddSlider("espBudget", {
	Text = "Max Highlights",
	Default = 25, Min = 5, Max = 30, Rounding = 0,
	Tooltip = "Roblox hanya mengizinkan sekitar 31 highlight sekaligus.",
})

local highlights = {} -- [instance] = Highlight

local function setHighlight(target, color)
	local h = highlights[target]
	if not h or not h.Parent then
		h = Instance.new("Highlight")
		h.FillTransparency = 0.6
		h.OutlineTransparency = 0
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = target
		highlights[target] = h
	end
	h.FillColor, h.OutlineColor = color, color
end

local function clearHighlights()
	for target, h in pairs(highlights) do
		h:Destroy()
		highlights[target] = nil
	end
end

task.spawn(function()
	while not Library.Unloaded do
		local wanted, count = {}, 0
		local budget = Options.espBudget.Value

		local map = workspace:FindFirstChild("Map")
		if map then
			for _, obj in ipairs(map:GetDescendants()) do
				if obj:IsA("Model") then
					for _, t in ipairs(espTypes) do
						local hit = obj.Name == t.name or obj.Name == t.alt or (t.prefix and obj.Name:match("^" .. t.name))
						if hit and Toggles[t.id].Value and count < budget then
							wanted[obj] = Options[t.id .. "Color"].Value
							count += 1
						end
					end
				end
			end
		end

		if Toggles.playerEsp.Value then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player and p.Character and count < budget then
					wanted[p.Character] = Options.playerEspColor.Value
					count += 1
				end
			end
		end

		for target, color in pairs(wanted) do
			setHighlight(target, color)
		end
		for target, h in pairs(highlights) do
			if not wanted[target] then
				h:Destroy()
				highlights[target] = nil
			end
		end
		task.wait(1)
	end
end)

----------------------------------------------------------------
-- SETTINGS (sesuai layout screenshot)
----------------------------------------------------------------
local VisualBox = Tabs.Settings:AddLeftGroupbox("Visuals")
local PerfBox = Tabs.Settings:AddLeftGroupbox("Performance")
local MiscBox = Tabs.Settings:AddRightGroupbox("Misc")
local ServerBox = Tabs.Settings:AddRightGroupbox("Server")

-- Full Bright & No Fog (nilai asli disimpan untuk dikembalikan)
local origLight = {
	Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
	Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
	FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
}

VisualBox:AddToggle("fullBright", {
	Text = "Full Bright", Default = false,
	Callback = function(on)
		if on then
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.Ambient = Color3.new(1, 1, 1)
			Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		else
			Lighting.Brightness = origLight.Brightness
			Lighting.ClockTime = origLight.ClockTime
			Lighting.Ambient = origLight.Ambient
			Lighting.OutdoorAmbient = origLight.OutdoorAmbient
		end
	end,
})
VisualBox:AddToggle("noFog", {
	Text = "No Fog", Default = false,
	Callback = function(on)
		if on then
			Lighting.FogStart, Lighting.FogEnd = 0, 1e6
		else
			Lighting.FogStart, Lighting.FogEnd = origLight.FogStart, origLight.FogEnd
		end
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if atm then atm.Density = on and 0 or 0.3 end
	end,
})
VisualBox:AddToggle("unlimitedZoom", {
	Text = "Unlimited Zoom", Default = false,
	Callback = function(on)
		player.CameraMaxZoomDistance = on and 1e5 or 128
	end,
})

-- Performance
local particleState = {}
PerfBox:AddToggle("disableParticles", {
	Text = "Disable Particles", Default = false,
	Callback = function(on)
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ParticleEmitter") then
				if on then
					particleState[d] = d.Enabled
					d.Enabled = false
				elseif particleState[d] ~= nil then
					d.Enabled = particleState[d]
				end
			end
		end
	end,
})
PerfBox:AddToggle("lowerGraphics", {
	Text = "Lower Graphics", Default = false,
	Callback = function(on)
		pcall(function()
			settings().Rendering.QualityLevel = on and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
		end)
	end,
})
PerfBox:AddToggle("disableShadows", {
	Text = "Disable Shadows", Default = false,
	Callback = function(on) Lighting.GlobalShadows = not on end,
})
PerfBox:AddToggle("fpsUnlocker", {
	Text = "FPS Unlocker", Default = false,
	Callback = function(on)
		if setfpscap then
			local cap = Options.fpsCap.Value
			setfpscap(on and (cap == "Unlimited" and 0 or tonumber(cap)) or 60)
		else
			Library:Notify({ Title = "FPS Unlocker", Description = "Executor tidak mendukung setfpscap.", Time = 4 })
		end
	end,
})
PerfBox:AddDropdown("fpsCap", {
	Text = "FPS Cap Value",
	Values = { "30", "60", "120", "144", "240", "Unlimited" },
	Default = "Unlimited",
	Callback = function(v)
		if setfpscap and Toggles.fpsUnlocker.Value then
			setfpscap(v == "Unlimited" and 0 or tonumber(v))
		end
	end,
})

-- FPS counter
local fpsGui = Instance.new("ScreenGui")
fpsGui.Name = "VD_FPS"
fpsGui.ResetOnSpawn = false
fpsGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.fromOffset(90, 22)
fpsLabel.Position = UDim2.new(1, -100, 0, 8)
fpsLabel.BackgroundTransparency = 0.5
fpsLabel.BackgroundColor3 = Color3.new(0, 0, 0)
fpsLabel.TextColor3 = Color3.new(1, 1, 1)
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 13
fpsLabel.Visible = false
fpsLabel.Parent = fpsGui

PerfBox:AddToggle("fpsCounter", {
	Text = "FPS Counter", Default = false,
	Callback = function(on) fpsLabel.Visible = on end,
})
local frames, lastT = 0, tick()
connect(RunService.RenderStepped, function()
	frames += 1
	if tick() - lastT >= 1 then
		fpsLabel.Text = "FPS: " .. frames
		frames, lastT = 0, tick()
	end
end)

-- Anti AFK
MiscBox:AddToggle("antiAfk", { Text = "Stay Active (Anti AFK)", Default = true })
connect(player.Idled, function()
	if Toggles.antiAfk.Value then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

-- Server
ServerBox:AddButton({
	Text = "Rejoin Server",
	Func = function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end,
})
ServerBox:AddButton({
	Text = "Serverhop (Find Small Server)",
	Func = function()
		local ok, result = pcall(function()
			local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
			return HttpService:JSONDecode(game:HttpGet(url))
		end)
		if not ok then
			Library:Notify({ Title = "Serverhop", Description = "Gagal mengambil daftar server.", Time = 4 })
			return
		end
		for _, s in ipairs(result.data or {}) do
			if s.id ~= game.JobId and s.playing < s.maxPlayers then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, player)
				return
			end
		end
		Library:Notify({ Title = "Serverhop", Description = "Tidak ada server yang cocok.", Time = 4 })
	end,
})

MiscBox:AddButton({
	Text = "Unload Script",
	Func = function() Library:Unload() end,
})

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("ViolenceDistrictClean")
SaveManager:SetFolder("ViolenceDistrictClean/config")
SaveManager:BuildConfigSection(Tabs.Config)
ThemeManager:ApplyToTab(Tabs.Config)
SaveManager:LoadAutoloadConfig()

Library:OnUnload(function()
	for _, c in ipairs(connections) do c:Disconnect() end
	clearHighlights()
	fpsGui:Destroy()
	Lighting.Brightness = origLight.Brightness
	Lighting.ClockTime = origLight.ClockTime
	Lighting.Ambient = origLight.Ambient
	Lighting.OutdoorAmbient = origLight.OutdoorAmbient
	Lighting.FogStart, Lighting.FogEnd = origLight.FogStart, origLight.FogEnd
end)

Library:Notify({ Title = "Violence District", Description = "Script dimuat. Menu: RightControl.", Time = 4 })
