-- Violence District | Tabbed Menu by jeysar
-- Tab: ESP (Aura / Name / Pallet / Window / Generator), Misc

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

if not game:IsLoaded() then game.Loaded:Wait() end

local LocalPlayer = Players.LocalPlayer
local connections = {}
local espData = {}
local auraOn, nameOn = false, false
local minimized = false

local COLOR_SURVIVOR = Color3.fromRGB(255, 255, 255)
local COLOR_KILLER = Color3.fromRGB(255, 50, 50)
local COLOR_PALLET = Color3.fromRGB(255, 200, 0)
local COLOR_WINDOW = Color3.fromRGB(0, 170, 255)
local COLOR_GENERATOR = Color3.fromRGB(80, 255, 120)
local TOGGLE_KEY = Enum.KeyCode.RightShift
local FULL_SIZE = UDim2.new(0, 400, 0, 250)
local MINI_SIZE = UDim2.new(0, 400, 0, 34)

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
if parentGui:FindFirstChild("ViolenceDistrict") then
    parentGui.ViolenceDistrict:Destroy()
end

----------------------------------------------------------------
-- ESP Player
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

local function removeESP(plr)
    local d = espData[plr]
    if d then
        if d.highlight then d.highlight:Destroy() end
        if d.billboard then d.billboard:Destroy() end
        espData[plr] = nil
    end
end

local function applyESP(plr)
    removeESP(plr)
    if plr == LocalPlayer or not (auraOn or nameOn) then return end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local killer = isKiller(plr)
    local color = killer and COLOR_KILLER or COLOR_SURVIVOR
    local data = {killer = killer}

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
        data.highlight = hl
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
        data.billboard = bb
    end

    espData[plr] = data
end

local function refreshAll()
    for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
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

for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
table.insert(connections, Players.PlayerAdded:Connect(setupPlayer))
table.insert(connections, Players.PlayerRemoving:Connect(removeESP))

----------------------------------------------------------------
-- Misc: Fullbright
----------------------------------------------------------------
local fbOn = false
local fbOriginal = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows,
}

local function setFullbright(state)
    fbOn = state
    if not state then
        for k, v in pairs(fbOriginal) do Lighting[k] = v end
    end
end

table.insert(connections, RunService.RenderStepped:Connect(function()
    if fbOn then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.GlobalShadows = false
    end
end))

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ViolenceDistrict"
gui.ResetOnSpawn = false
gui.Parent = parentGui

----------------------------------------------------------------
-- ESP Object: Pallet & Window
-- (harus di bawah pembuatan `gui` karena label ditaruh di sana)
----------------------------------------------------------------
local palletOn, windowOn, genOn = false, false, false
local objESP = {}
local OBJ_COLORS = {pallet = COLOR_PALLET, window = COLOR_WINDOW, generator = COLOR_GENERATOR}

local function getKind(inst)
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return nil end
    local n = string.lower(inst.Name)
    if string.find(n, "pallet") then return "pallet" end
    if string.find(n, "window") then return "window" end
    if string.find(n, "generator") then return "generator" end
    return nil
end

local function removeObj(inst)
    local d = objESP[inst]
    if d then
        if d.conn then d.conn:Disconnect() end
        if d.highlight then d.highlight:Destroy() end
        objESP[inst] = nil
    end
end

local function applyObj(inst)
    if objESP[inst] then return end
    local kind = getKind(inst)
    if not kind then return end
    if (kind == "pallet" and not palletOn) or (kind == "window" and not windowOn) or (kind == "generator" and not genOn) then return end

    -- skip kalau induknya udah ke-track (biar nggak dobel)
    local p = inst.Parent
    while p and p ~= workspace do
        if objESP[p] then return end
        p = p.Parent
    end

    local color = OBJ_COLORS[kind]

    local hl = Instance.new("Highlight")
    hl.Name = "VD_Obj"
    hl.FillColor = color
    hl.FillTransparency = 0.6
    hl.OutlineColor = color
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = inst
    hl.Parent = gui -- taruh di gui lu biar map nggak ke-modif

    local conn = inst.AncestryChanged:Connect(function()
        if not inst:IsDescendantOf(workspace) then removeObj(inst) end
    end)

    objESP[inst] = {highlight = hl, conn = conn}
end

local function refreshObjs()
    for inst in pairs(objESP) do removeObj(inst) end
    if not (palletOn or windowOn or genOn) then return end
    for _, d in ipairs(workspace:GetDescendants()) do applyObj(d) end
end

table.insert(connections, workspace.DescendantAdded:Connect(function(d)
    if palletOn or windowOn or genOn then
        task.defer(applyObj, d)
    end
end))

----------------------------------------------------------------
-- Main window
----------------------------------------------------------------
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = FULL_SIZE
main.Position = UDim2.new(0.5, -200, 0.5, -125)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local glow = Instance.new("UIStroke")
glow.Color = Color3.new(1, 1, 1)
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

-- Refresh warna kalau role berubah
task.spawn(function()
    while gui.Parent do
        task.wait(1)
        if auraOn or nameOn then
            for plr, d in pairs(espData) do
                if d.killer ~= isKiller(plr) then applyESP(plr) end
            end
        end
    end
end)

-- Title bar
local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 34)
top.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
top.BorderSizePixel = 0
top.Parent = main

local titleHolder = Instance.new("Frame")
titleHolder.Size = UDim2.new(1, -80, 1, 0)
titleHolder.Position = UDim2.new(0, 12, 0, 0)
titleHolder.BackgroundTransparency = 1
titleHolder.Parent = top

local tl = Instance.new("UIListLayout", titleHolder)
tl.FillDirection = Enum.FillDirection.Horizontal
tl.VerticalAlignment = Enum.VerticalAlignment.Center
tl.Padding = UDim.new(0, 6)

local title = Instance.new("TextLabel")
title.AutomaticSize = Enum.AutomaticSize.X
title.Size = UDim2.new(0, 0, 1, 0)
title.BackgroundTransparency = 1
title.Text = "VIOLENCE DISTRICT"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBlack
title.TextSize = 13
title.Parent = titleHolder

local wm = Instance.new("TextLabel")
wm.AutomaticSize = Enum.AutomaticSize.X
wm.Size = UDim2.new(0, 0, 1, 0)
wm.BackgroundTransparency = 1
wm.Text = "by jeysar"
wm.TextColor3 = Color3.fromRGB(140, 140, 140)
wm.Font = Enum.Font.Gotham
wm.TextSize = 8
wm.Parent = titleHolder

local function makeTopBtn(text, xOffset)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 26, 0, 22)
    b.Position = UDim2.new(1, xOffset, 0, 6)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.Parent = top
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", b)
    s.Color = Color3.new(1, 1, 1)
    s.Transparency = 0.6
    return b
end

local minBtn = makeTopBtn("–", -62)
local closeBtn = makeTopBtn("X", -32)

-- Body
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -34)
body.Position = UDim2.new(0, 0, 0, 34)
body.BackgroundTransparency = 1
body.Parent = main

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 100, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
sidebar.BorderSizePixel = 0
sidebar.Parent = body

local sl = Instance.new("UIListLayout", sidebar)
sl.Padding = UDim.new(0, 6)
local sp = Instance.new("UIPadding", sidebar)
sp.PaddingTop = UDim.new(0, 10)
sp.PaddingLeft = UDim.new(0, 8)
sp.PaddingRight = UDim.new(0, 8)

local pages = Instance.new("Frame")
pages.Size = UDim2.new(1, -100, 1, 0)
pages.Position = UDim2.new(0, 100, 0, 0)
pages.BackgroundTransparency = 1
pages.Parent = body

local tabs = {}

local function createPage()
    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 3
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.Visible = false
    p.Parent = pages
    local l = Instance.new("UIListLayout", p)
    l.Padding = UDim.new(0, 8)
    local pad = Instance.new("UIPadding", p)
    pad.PaddingTop = UDim.new(0, 12)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.PaddingBottom = UDim.new(0, 12)
    return p
end

local function selectTab(name)
    for n, t in pairs(tabs) do
        local active = (n == name)
        t.page.Visible = active
        TweenService:Create(t.btn, TweenInfo.new(0.15), {
            BackgroundColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(28, 28, 28),
            TextColor3 = active and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(200, 200, 200),
        }):Play()
    end
end

local function createTab(name)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 30)
    b.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    b.Text = name
    b.TextColor3 = Color3.fromRGB(200, 200, 200)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = false
    b.Parent = sidebar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local page = createPage()
    tabs[name] = {btn = b, page = page}
    b.MouseButton1Click:Connect(function() selectTab(name) end)
    return page
end

local function createToggle(parent, text, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local rs = Instance.new("UIStroke", row)
    rs.Color = Color3.new(1, 1, 1)
    rs.Transparency = 0.85

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local sw = Instance.new("TextButton")
    sw.Size = UDim2.new(0, 44, 0, 20)
    sw.Position = UDim2.new(1, -54, 0.5, -10)
    sw.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.Parent = row
    Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
    local ss = Instance.new("UIStroke", sw)
    ss.Color = Color3.new(1, 1, 1)
    ss.Transparency = 0.5

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    knob.Parent = sw
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = false
    sw.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(knob, TweenInfo.new(0.2), {
            Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
            BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 120),
        }):Play()
        TweenService:Create(sw, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(70, 70, 70) or Color3.fromRGB(30, 30, 30),
        }):Play()
        callback(state)
    end)
end

local function createInfo(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 30)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(140, 140, 140)
    l.Font = Enum.Font.Gotham
    l.TextSize = 11
    l.TextWrapped = true
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.Parent = parent
end

-- Tab: ESP
local espPage = createTab("ESP")
createToggle(espPage, "Aura Player", function(s) auraOn = s; refreshAll() end)
createToggle(espPage, "Nama Player", function(s) nameOn = s; refreshAll() end)
createToggle(espPage, "Pallet", function(s) palletOn = s; refreshObjs() end)
createToggle(espPage, "Window", function(s) windowOn = s; refreshObjs() end)
createToggle(espPage, "Generator", function(s) genOn = s; refreshObjs() end)
createInfo(espPage, "Putih = Survivor | Merah = Killer | Kuning = Pallet | Biru = Window | Hijau = Generator")

-- Tab: Misc
local miscPage = createTab("Misc")
createToggle(miscPage, "Fullbright", setFullbright)
createInfo(miscPage, "RightShift = show/hide panel (PC)")

selectTab("ESP")

----------------------------------------------------------------
-- Minimize / Unload / Keybind / Drag
----------------------------------------------------------------
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
        Size = minimized and MINI_SIZE or FULL_SIZE
    }):Play()
    minBtn.Text = minimized and "+" or "–"
end)

closeBtn.MouseButton1Click:Connect(function()
    auraOn, nameOn = false, false
    palletOn, windowOn, genOn = false, false, false
    for p in pairs(espData) do removeESP(p) end
    for inst in pairs(objESP) do removeObj(inst) end
    setFullbright(false)
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    gui:Destroy()
end)

table.insert(connections, UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == TOGGLE_KEY then
        main.Visible = not main.Visible
    end
end))

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
