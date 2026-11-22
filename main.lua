-- Violence District | by jeysar

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local connections = {}
local espData = {}
local auraOn, nameOn = false, false
local minimized = false

local COLOR_SURVIVOR = Color3.fromRGB(255, 255, 255)
local COLOR_KILLER = Color3.fromRGB(255, 50, 50)
local TOGGLE_KEY = Enum.KeyCode.RightShift

local BLACK = Color3.fromRGB(10, 10, 10)
local DARK = Color3.fromRGB(25, 25, 25)
local WHITE = Color3.fromRGB(255, 255, 255)
local GRAY = Color3.fromRGB(150, 150, 150)

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
if parentGui:FindFirstChild("ViolenceDistrict") then
    parentGui.ViolenceDistrict:Destroy()
end

----------------------------------------------------------------
-- ESP
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

local function clearESP(plr)
    local d = espData[plr]
    if d then
        if d.highlight then d.highlight:Destroy() end
        if d.billboard then d.billboard:Destroy() end
        espData[plr] = nil
    end
end

local function refreshESP(plr)
    clearESP(plr)
    if plr == LocalPlayer then return end
    if not auraOn and not nameOn then return end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local killer = isKiller(plr)
    local color = killer and COLOR_KILLER or COLOR_SURVIVOR
    local d = {killer = killer}

    if auraOn then
        local hl = Instance.new("Highlight")
        hl.Name = "VD_Aura"
        hl.FillColor = color
        hl.FillTransparency = 0.75
        hl.OutlineColor = color
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = char
        hl.Parent = char
        d.highlight = hl
    end

    if nameOn then
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
        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        lbl.TextStrokeTransparency = 0
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.Parent = bb
        d.billboard = bb
    end

    espData[plr] = d
end

local function refreshAll()
    for _, p in ipairs(Players:GetPlayers()) do refreshESP(p) end
end

local function setupPlayer(plr)
    if plr == LocalPlayer then return end
    table.insert(connections, plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        refreshESP(plr)
    end))
    table.insert(connections, plr.CharacterRemoving:Connect(function()
        clearESP(plr)
    end))
    refreshESP(plr)
end

for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
table.insert(connections, Players.PlayerAdded:Connect(setupPlayer))
table.insert(connections, Players.PlayerRemoving:Connect(clearESP))

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
        if auraOn or nameOn then
            for plr, d in pairs(espData) do
                if d.killer ~= isKiller(plr) then refreshESP(plr) end
            end
        end
    end
end)

local FULL_H = 190

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 280, 0, FULL_H)
main.Position = UDim2.new(0.5, -140, 0.5, -FULL_H / 2)
main.BackgroundColor3 = BLACK
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui

local border = Instance.new("UIStroke")
border.Color = WHITE
border.Thickness = 1
border.Parent = main

-- Title bar
local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 32)
top.BackgroundColor3 = DARK
top.BorderSizePixel = 0
top.Parent = main

local titleHolder = Instance.new("Frame")
titleHolder.Size = UDim2.new(1, -70, 1, 0)
titleHolder.Position = UDim2.new(0, 10, 0, 0)
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
title.TextColor3 = WHITE
title.Font = Enum.Font.GothamBold
title.TextSize = 13
title.Parent = titleHolder

local watermark = Instance.new("TextLabel")
watermark.AutomaticSize = Enum.AutomaticSize.X
watermark.Size = UDim2.new(0, 0, 1, 0)
watermark.BackgroundTransparency = 1
watermark.Text = "by jeysar"
watermark.TextColor3 = GRAY
watermark.Font = Enum.Font.Gotham
watermark.TextSize = 8
watermark.Parent = titleHolder

local function makeTopBtn(text, xOffset)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 26, 0, 22)
    b.Position = UDim2.new(1, xOffset, 0, 5)
    b.BackgroundColor3 = BLACK
    b.BorderSizePixel = 1
    b.BorderColor3 = WHITE
    b.Text = text
    b.TextColor3 = WHITE
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = false
    b.Parent = top
    return b
end

local minBtn = makeTopBtn("-", -58)
local closeBtn = makeTopBtn("X", -30)

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 28)
tabBar.Position = UDim2.new(0, 0, 0, 32)
tabBar.BackgroundColor3 = BLACK
tabBar.BorderSizePixel = 0
tabBar.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 0)
tabLayout.Parent = tabBar

local content = Instance.new("Frame")
content.Size = UDim2.new(1, 0, 1, -60)
content.Position = UDim2.new(0, 0, 0, 60)
content.BackgroundTransparency = 1
content.Parent = main

local pages, tabButtons = {}, {}

local function selectTab(name)
    for n, page in pairs(pages) do
        page.Visible = (n == name)
        local b = tabButtons[n]
        b.BackgroundColor3 = (n == name) and WHITE or BLACK
        b.TextColor3 = (n == name) and BLACK or WHITE
    end
end

local function makeTab(name, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, width, 1, 0)
    b.BackgroundColor3 = BLACK
    b.BorderSizePixel = 1
    b.BorderColor3 = WHITE
    b.Text = name
    b.TextColor3 = WHITE
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = false
    b.Parent = tabBar
    tabButtons[name] = b

    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = content
    pages[name] = page

    b.MouseButton1Click:Connect(function() selectTab(name) end)
    return page
end

local espPage = makeTab("ESP", 140)
local miscPage = makeTab("Misc", 140)

-- Komponen toggle
local function makeToggle(parent, text, y, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 28)
    row.Position = UDim2.new(0, 10, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = WHITE
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 50, 0, 22)
    btn.Position = UDim2.new(1, -50, 0.5, -11)
    btn.BackgroundColor3 = BLACK
    btn.BorderSizePixel = 1
    btn.BorderColor3 = WHITE
    btn.Text = "OFF"
    btn.TextColor3 = WHITE
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Parent = row

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = state and "ON" or "OFF"
        btn.BackgroundColor3 = state and WHITE or BLACK
        btn.TextColor3 = state and BLACK or WHITE
        callback(state)
    end)
end

-- Tab ESP
makeToggle(espPage, "Aura Player", 12, function(s)
    auraOn = s
    refreshAll()
end)
makeToggle(espPage, "Nama Player", 46, function(s)
    nameOn = s
    refreshAll()
end)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, -20, 0, 30)
hint.Position = UDim2.new(0, 10, 0, 86)
hint.BackgroundTransparency = 1
hint.Text = "Putih = Survivor | Merah = Killer"
hint.TextColor3 = GRAY
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = espPage

-- Tab Misc
local miscInfo = Instance.new("TextLabel")
miscInfo.Size = UDim2.new(1, -20, 0, 30)
miscInfo.Position = UDim2.new(0, 10, 0, 12)
miscInfo.BackgroundTransparency = 1
miscInfo.Text = "RightShift = show/hide panel"
miscInfo.TextColor3 = GRAY
miscInfo.Font = Enum.Font.Gotham
miscInfo.TextSize = 11
miscInfo.TextXAlignment = Enum.TextXAlignment.Left
miscInfo.Parent = miscPage

local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.new(1, -20, 0, 28)
unloadBtn.Position = UDim2.new(0, 10, 0, 50)
unloadBtn.BackgroundColor3 = BLACK
unloadBtn.BorderSizePixel = 1
unloadBtn.BorderColor3 = WHITE
unloadBtn.Text = "UNLOAD"
unloadBtn.TextColor3 = WHITE
unloadBtn.Font = Enum.Font.GothamBold
unloadBtn.TextSize = 12
unloadBtn.AutoButtonColor = false
unloadBtn.Parent = miscPage

selectTab("ESP")

-- Unload
local function unload()
    auraOn, nameOn = false, false
    for p in pairs(espData) do clearESP(p) end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    gui:Destroy()
end
closeBtn.MouseButton1Click:Connect(unload)
unloadBtn.MouseButton1Click:Connect(unload)

-- Minimize
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    content.Visible = not minimized
    tabBar.Visible = not minimized
    main.Size = minimized and UDim2.new(0, 280, 0, 32) or UDim2.new(0, 280, 0, FULL_H)
    minBtn.Text = minimized and "+" or "-"
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
