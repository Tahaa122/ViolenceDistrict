-- Violence District | Simple Menu (ESP Player) by jeysar

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local connections = {}
local espData = {}
local espEnabled = false
local minimized = false

local COLOR_SURVIVOR = Color3.fromRGB(255, 255, 255)
local COLOR_KILLER = Color3.fromRGB(255, 50, 50)
local TOGGLE_KEY = Enum.KeyCode.RightShift

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
if parentGui:FindFirstChild("ViolenceDistrict") then
    parentGui.ViolenceDistrict:Destroy()
end

----------------------------------------------------------------
-- Deteksi killer (heuristik: Team / Attribute "Role")
----------------------------------------------------------------
local function isKiller(plr)
    if plr.Team and string.find(string.lower(plr.Team.Name), "killer") then
        return true
    end
    local role = plr:GetAttribute("Role") or (plr.Character and plr.Character:GetAttribute("Role"))
    if role and string.find(string.lower(tostring(role)), "killer") then
        return true
    end
    return false
end

----------------------------------------------------------------
-- ESP
----------------------------------------------------------------
local function removeESP(plr)
    local d = espData[plr]
    if d then
        if d.highlight then d.highlight:Destroy() end
        if d.billboard then d.billboard:Destroy() end
        espData[plr] = nil
    end
end

local function applyESP(plr)
    if plr == LocalPlayer or not espEnabled then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    removeESP(plr)
    local color = isKiller(plr) and COLOR_KILLER or COLOR_SURVIVOR

    local hl = Instance.new("Highlight")
    hl.Name = "VD_ESP"
    hl.FillColor = color
    hl.FillTransparency = 0.75
    hl.OutlineColor = color
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char

    local bb = Instance.new("BillboardGui")
    bb.Name = "VD_Name"
    bb.Size = UDim2.new(0, 120, 0, 20)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = hrp
    bb.Parent = char

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = plr.DisplayName
    lbl.TextColor3 = color
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.Parent = bb

    espData[plr] = {highlight = hl, billboard = bb, killer = isKiller(plr), label = lbl}
end

local function setupPlayer(plr)
    if plr == LocalPlayer then return end
    table.insert(connections, plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        applyESP(plr)
    end))
    table.insert(connections, plr.CharacterRemoving:Connect(function()
        removeESP(plr)
    end))
    applyESP(plr)
end

local function setESP(state)
    espEnabled = state
    if state then
        for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
    else
        for p in pairs(espData) do removeESP(p) end
    end
end

for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
table.insert(connections, Players.PlayerAdded:Connect(setupPlayer))
table.insert(connections, Players.PlayerRemoving:Connect(removeESP))

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ViolenceDistrict"
gui.ResetOnSpawn = false
gui.Parent = parentGui

-- Refresh warna kalau role berubah
task.spawn(function()
    while gui.Parent do
        task.wait(1)
        if espEnabled then
            for plr, d in pairs(espData) do
                local k = isKiller(plr)
                if d.killer ~= k then
                    applyESP(plr)
                end
            end
        end
    end
end)

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 260, 0, 160)
main.Position = UDim2.new(0.5, -130, 0.5, -80)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local glow = Instance.new("UIStroke")
glow.Color = Color3.fromRGB(255, 255, 255)
glow.Thickness = 1.5
glow.Transparency = 0.2
glow.Parent = main

task.spawn(function()
    while gui.Parent do
        TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Transparency = 0.7}):Play()
        task.wait(1.2)
        if not gui.Parent then break end
        TweenService:Create(glow, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Transparency = 0.1}):Play()
        task.wait(1.2)
    end
end)

-- Title bar
local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 34)
top.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
top.BorderSizePixel = 0
top.Parent = main

-- Holder judul + watermark (sejajar)
local titleHolder = Instance.new("Frame")
titleHolder.Size = UDim2.new(1, -80, 1, 0)
titleHolder.Position = UDim2.new(0, 12, 0, 0)
titleHolder.BackgroundTransparency = 1
titleHolder.Parent = top

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = titleHolder

local title = Instance.new("TextLabel")
title.AutomaticSize = Enum.AutomaticSize.X
title.Size = UDim2.new(0, 0, 1, 0)
title.BackgroundTransparency = 1
title.Text = "VIOLENCE DISTRICT"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBlack
title.TextSize = 13
title.Parent = titleHolder

local watermark = Instance.new("TextLabel")
watermark.AutomaticSize = Enum.AutomaticSize.X
watermark.Size = UDim2.new(0, 0, 1, 0)
watermark.BackgroundTransparency = 1
watermark.Text = "by jeysar"
watermark.TextColor3 = Color3.fromRGB(140, 140, 140)
watermark.Font = Enum.Font.Gotham
watermark.TextSize = 8
watermark.Parent = titleHolder

local function makeTopBtn(text, xOffset)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 26, 0, 22)
    b.Position = UDim2.new(1, xOffset, 0, 6)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = true
    b.Parent = top
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", b)
    s.Color = Color3.fromRGB(255, 255, 255)
    s.Transparency = 0.6
    return b
end

local minBtn = makeTopBtn("–", -62)
local closeBtn = makeTopBtn("X", -32)

-- Konten
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, 0, 1, -34)
content.Position = UDim2.new(0, 0, 0, 34)
content.BackgroundTransparency = 1
content.Parent = main

local espLabel = Instance.new("TextLabel")
espLabel.Size = UDim2.new(0, 140, 0, 30)
espLabel.Position = UDim2.new(0, 14, 0, 14)
espLabel.BackgroundTransparency = 1
espLabel.Text = "ESP Player"
espLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
espLabel.Font = Enum.Font.GothamMedium
espLabel.TextSize = 14
espLabel.TextXAlignment = Enum.TextXAlignment.Left
espLabel.Parent = content

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0, 50, 0, 24)
toggle.Position = UDim2.new(1, -64, 0, 17)
toggle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggle.Text = ""
toggle.AutoButtonColor = false
toggle.Parent = content
Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)
local tStroke = Instance.new("UIStroke", toggle)
tStroke.Color = Color3.fromRGB(255, 255, 255)
tStroke.Transparency = 0.5

local knob = Instance.new("Frame")
knob.Size = UDim2.new(0, 18, 0, 18)
knob.Position = UDim2.new(0, 3, 0.5, -9)
knob.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
knob.Parent = toggle
Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -28, 0, 36)
hint.Position = UDim2.new(0, 14, 0, 52)
hint.BackgroundTransparency = 1
hint.Text = "Putih = Survivor | Merah = Killer\nRightShift = show/hide panel"
hint.TextColor3 = Color3.fromRGB(150, 150, 150)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top
hint.Parent = content

toggle.MouseButton1Click:Connect(function()
    local state = not espEnabled
    setESP(state)
    TweenService:Create(knob, TweenInfo.new(0.2), {
        Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
        BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 120)
    }):Play()
    TweenService:Create(toggle, TweenInfo.new(0.2), {
        BackgroundColor3 = state and Color3.fromRGB(70, 70, 70) or Color3.fromRGB(30, 30, 30)
    }):Play()
end)

-- Minimize
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
        Size = minimized and UDim2.new(0, 260, 0, 34) or UDim2.new(0, 260, 0, 160)
    }):Play()
    minBtn.Text = minimized and "+" or "–"
end)

-- Unload
closeBtn.MouseButton1Click:Connect(function()
    setESP(false)
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    gui:Destroy()
end)

-- Keybind show/hide
table.insert(connections, UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == TOGGLE_KEY then
        main.Visible = not main.Visible
    end
end))

-- Drag
local dragging, dragStart, startPos
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)
table.insert(connections, UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))
table.insert(connections, UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))
