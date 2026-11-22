-- Violence District | Menu v1.2 by jeysar
-- Tab: Main, ESP, Visual, Settings

local VERSION = "v1.3"

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

if not game:IsLoaded() then game.Loaded:Wait() end

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- Konstanta & Config
----------------------------------------------------------------
local COLOR_SURVIVOR = Color3.fromRGB(255, 255, 255)
local COLOR_KILLER = Color3.fromRGB(255, 50, 50)
local COLOR_PALLET = Color3.fromRGB(255, 200, 0)
local COLOR_GENERATOR = Color3.fromRGB(170, 70, 255) -- ungu
local TOGGLE_KEY = Enum.KeyCode.RightShift
local FULL_SIZE = UDim2.new(0, 440, 0, 290)
local MINI_SIZE = UDim2.new(0, 440, 0, 34)
local DISTANCE_PRESETS = {100, 150, 250, 0} -- 0 = tanpa batas
local VAULT_PRESETS = {1.5, 1.7, 2.0, 2.5, 3.0}
local CONFIG_FILE = "ViolenceDistrict_config.json"

local config = {
    aura = false,
    name = false,
    eyes = false,
    generator = false,
    genProgress = true,
    fullbright = false,
    fastVault = false,
    vaultSpeed = 2.0,
    nofog = false,
    distance = 150,
}

local function loadConfig()
    if not (isfile and readfile) then return end
    local ok, data = pcall(function()
        if not isfile(CONFIG_FILE) then return nil end
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            if config[k] ~= nil and type(v) == type(config[k]) then
                config[k] = v
            end
        end
    end
end

local function saveConfig()
    if not writefile then return false end
    local ok = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(config))
    end)
    return ok
end

loadConfig()

----------------------------------------------------------------
-- State & helper umum
----------------------------------------------------------------
local connections = {}
local espData = {}
local objESP = {}
local playerConns = {}
local minimized = false

local function make(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(inst, radius)
    return make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, inst)
end

local function stroke(inst, transparency, color)
    return make("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Transparency = transparency or 0.85,
    }, inst)
end

local orderCounter = setmetatable({}, {__mode = "k"})
local function nextOrder(parent)
    orderCounter[parent] = (orderCounter[parent] or 0) + 1
    return orderCounter[parent]
end

local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
if parentGui:FindFirstChild("ViolenceDistrict") then
    parentGui.ViolenceDistrict:Destroy()
end

local gui = make("ScreenGui", {Name = "ViolenceDistrict", ResetOnSpawn = false}, parentGui)

-- Toast notifikasi kecil
local toast = make("TextLabel", {
    Size = UDim2.new(0, 190, 0, 26),
    Position = UDim2.new(0.5, -95, 1, -60),
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BackgroundTransparency = 1,
    TextColor3 = Color3.new(1, 1, 1),
    TextTransparency = 1,
    Font = Enum.Font.GothamMedium,
    TextSize = 12,
    Text = "",
    ZIndex = 10,
}, gui)
corner(toast, 8)

local toastSeq = 0
local function notify(text)
    toastSeq += 1
    local id = toastSeq
    toast.Text = text
    toast.BackgroundTransparency = 0.1
    toast.TextTransparency = 0
    task.delay(1.6, function()
        if id ~= toastSeq or not toast.Parent then return end
        TweenService:Create(toast, TweenInfo.new(0.3), {
            BackgroundTransparency = 1,
            TextTransparency = 1,
        }):Play()
    end)
end

----------------------------------------------------------------
-- ESP Player (aura + nama + jarak)
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
    if plr == LocalPlayer or not (config.aura or config.name) then return end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local color = isKiller(plr) and COLOR_KILLER or COLOR_SURVIVOR
    local data = {hrp = hrp}

    if config.aura then
        data.highlight = make("Highlight", {
            Name = "VD_Aura",
            FillColor = color,
            FillTransparency = 0.75,
            OutlineColor = color,
            OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            Adornee = char,
        }, char)
    end

    if config.name then
        local bb = make("BillboardGui", {
            Name = "VD_Name",
            Size = UDim2.new(0, 140, 0, 20),
            StudsOffset = Vector3.new(0, 3.2, 0),
            AlwaysOnTop = true,
            Adornee = hrp,
        }, char)
        data.label = make("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = plr.DisplayName,
            TextColor3 = color,
            TextStrokeColor3 = Color3.new(0, 0, 0),
            TextStrokeTransparency = 0,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
        }, bb)
        data.billboard = bb
    end

    espData[plr] = data
end

local function refreshAll()
    for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
end

local function setupPlayer(plr)
    if plr == LocalPlayer then return end
    local conns = {}
    playerConns[plr] = conns
    local function refresh() applyESP(plr) end

    local function onCharacter(char)
        char:WaitForChild("HumanoidRootPart", 10)
        if not char.Parent then return end
        applyESP(plr)
        table.insert(conns, char:GetAttributeChangedSignal("Role"):Connect(refresh))
    end

    table.insert(conns, plr.CharacterAdded:Connect(function(char)
        task.spawn(onCharacter, char)
    end))
    table.insert(conns, plr.CharacterRemoving:Connect(function() removeESP(plr) end))
    table.insert(conns, plr:GetPropertyChangedSignal("Team"):Connect(refresh))
    table.insert(conns, plr:GetAttributeChangedSignal("Role"):Connect(refresh))

    if plr.Character then task.spawn(onCharacter, plr.Character) end
end

local function cleanupPlayer(plr)
    removeESP(plr)
    local conns = playerConns[plr]
    if conns then
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        playerConns[plr] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
table.insert(connections, Players.PlayerAdded:Connect(setupPlayer))
table.insert(connections, Players.PlayerRemoving:Connect(cleanupPlayer))

----------------------------------------------------------------
-- ESP Objek (Pallet & Generator)
----------------------------------------------------------------
local function progressColor(progress)
    local t = math.clamp((progress or 0) / 100, 0, 1)
    local red = Color3.fromRGB(255, 60, 60)
    local yellow = Color3.fromRGB(255, 220, 60)
    local green = Color3.fromRGB(80, 255, 120)
    if t < 0.5 then
        return red:Lerp(yellow, t * 2)
    end
    return yellow:Lerp(green, (t - 0.5) * 2)
end

local OBJ_COLORS = {pallet = COLOR_PALLET, generator = COLOR_GENERATOR}

-- Filter berdasarkan struktur map (dari data perk):
--   Pallet asli  : Workspace.Map.pallets.<Newpallet>
--   Window asli  : part di dalam Workspace.Map.Window
--   Generator    : Model dengan atribut RepairProgress
local function getKind(inst)
    if inst:IsA("Model") then
        if inst:GetAttribute("RepairProgress") ~= nil or inst.Name == "Generator" then
            return "generator"
        end
    end
    local parent = inst.Parent
    if not parent then return nil end
    local parentName = string.lower(parent.Name)
    if (inst:IsA("Model") or inst:IsA("BasePart")) and parentName == "pallets" then
        return "pallet"
    end
    return nil
end

local function removeObj(inst)
    local d = objESP[inst]
    if d then
        for _, c in ipairs(d.conns) do pcall(function() c:Disconnect() end) end
        if d.hl then d.hl:Destroy() end
        if d.bb then d.bb:Destroy() end
        objESP[inst] = nil
    end
end

local function refreshGen(inst, d)
    local progress = math.clamp(inst:GetAttribute("RepairProgress") or 0, 0, 100)
    d.done = inst:GetAttribute("Completed") == true or progress >= 100
    d.hl.FillColor = COLOR_GENERATOR
    d.hl.OutlineColor = COLOR_GENERATOR
    if d.done then d.hl.Enabled = false end

    if d.bb then
        d.bb.Enabled = config.genProgress and not d.done
        d.label.Text = math.floor(progress + 0.5) .. "%"
        TweenService:Create(d.fill, TweenInfo.new(0.25), {
            Size = UDim2.new(progress / 100, 0, 1, 0),
        }):Play()
    end
end

local function refreshGenColors()
    for inst, d in pairs(objESP) do
        if d.kind == "generator" then refreshGen(inst, d) end
    end
end

local function applyObj(inst)
    if objESP[inst] then return end
    local kind = getKind(inst)
    if not kind then return end
    if (kind == "pallet" and not config.eyes)
        or (kind == "generator" and not config.generator) then
        return
    end

    -- skip kalau induknya sudah ke-track (biar nggak dobel)
    local p = inst.Parent
    while p and p ~= workspace do
        if objESP[p] then return end
        p = p.Parent
    end

    local color = OBJ_COLORS[kind]
    local hl, vizProp
    do
        hl = make("Highlight", {
            Name = "VD_Obj",
            FillColor = color,
            FillTransparency = 0.6,
            OutlineColor = color,
            OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            Adornee = inst,
        }, gui) -- ditaruh di gui biar map nggak ke-modif
        vizProp = "Enabled"
    end

    local d = {hl = hl, vizProp = vizProp, kind = kind, conns = {}, done = false}
    objESP[inst] = d

    if kind == "generator" then
        local anchor = (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true))) or inst
        d.bb = make("BillboardGui", {
            Name = "VD_GenProgress",
            Size = UDim2.new(0, 90, 0, 24),
            StudsOffset = Vector3.new(0, 4, 0),
            AlwaysOnTop = true,
            Adornee = anchor,
        }, gui)
        local bg = make("Frame", {
            Size = UDim2.new(1, 0, 0, 10),
            Position = UDim2.new(0, 0, 0, 12),
            BackgroundColor3 = Color3.fromRGB(20, 20, 20),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
        }, d.bb)
        corner(bg, 4)
        stroke(bg, 0.3, COLOR_PALLET)
        d.fill = make("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = COLOR_PALLET,
            BorderSizePixel = 0,
        }, bg)
        corner(d.fill, 4)
        d.label = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 12),
            BackgroundTransparency = 1,
            Text = "0%",
            TextColor3 = Color3.new(1, 1, 1),
            TextStrokeColor3 = Color3.new(0, 0, 0),
            TextStrokeTransparency = 0.3,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
        }, d.bb)
    end

    table.insert(d.conns, inst.AncestryChanged:Connect(function()
        if not inst:IsDescendantOf(workspace) then removeObj(inst) end
    end))

    if kind == "generator" then
        table.insert(d.conns, inst:GetAttributeChangedSignal("RepairProgress"):Connect(function()
            refreshGen(inst, d)
        end))
        table.insert(d.conns, inst:GetAttributeChangedSignal("Completed"):Connect(function()
            refreshGen(inst, d)
        end))
        refreshGen(inst, d)
    end
end

local function refreshObjs()
    for inst in pairs(objESP) do removeObj(inst) end
    if not (config.eyes or config.generator) then return end
    for _, d in ipairs(workspace:GetDescendants()) do applyObj(d) end
end

table.insert(connections, workspace.DescendantAdded:Connect(function(d)
    if config.eyes or config.generator then
        task.defer(applyObj, d)
    end
end))

----------------------------------------------------------------
-- Visual: Fullbright & No Fog
----------------------------------------------------------------
local FB_KEYS = {"Brightness", "ClockTime", "Ambient", "OutdoorAmbient", "GlobalShadows"}
local FOG_KEYS = {"FogEnd", "FogStart"}
local lightOriginal = {}
for _, k in ipairs(FB_KEYS) do lightOriginal[k] = Lighting[k] end
for _, k in ipairs(FOG_KEYS) do lightOriginal[k] = Lighting[k] end
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local atmosphereDensity = atmosphere and atmosphere.Density

local function restoreKeys(keys)
    for _, k in ipairs(keys) do Lighting[k] = lightOriginal[k] end
end

local function restoreFog()
    restoreKeys(FOG_KEYS)
    if atmosphere and atmosphereDensity then atmosphere.Density = atmosphereDensity end
end

table.insert(connections, RunService.RenderStepped:Connect(function()
    if config.fullbright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.GlobalShadows = false
    end
    if config.nofog then
        Lighting.FogStart = 1e5
        Lighting.FogEnd = 1e6
        if atmosphere then atmosphere.Density = 0 end
    end
end))

----------------------------------------------------------------
-- Update berkala (jarak player + batas jarak objek)
----------------------------------------------------------------
local acc = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 0.25 then return end
    acc = 0

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local rootPos = root and root.Position

    for plr, d in pairs(espData) do
        if d.label and d.hrp and d.hrp.Parent and rootPos then
            local dist = math.floor((d.hrp.Position - rootPos).Magnitude)
            d.label.Text = plr.DisplayName .. " [" .. dist .. "m]"
        end
    end

    local maxD = config.distance
    for inst, d in pairs(objESP) do
        local visible = not d.done
        if visible and maxD > 0 and rootPos then
            visible = (inst:GetPivot().Position - rootPos).Magnitude <= maxD
        end
        d.hl[d.vizProp] = visible
        if d.bb then d.bb.Enabled = visible and config.genProgress end
    end
end))

----------------------------------------------------------------
-- Fast Vault (percepat animasi vault window & pallet, lokal)
----------------------------------------------------------------
-- dari log: animasi vault window = "WalkingVaultAnimation"; game sendiri pakai speed 1.0 (slow) / 1.7 (medium)
-- kecepatan diatur di tab Main (config.vaultSpeed)
local VAULT_KEYWORDS = {"vault", "pallet"}
local seenTracks = {}

table.insert(connections, RunService.Heartbeat:Connect(function()
    if not config.fastVault then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return end
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        local name = string.lower(track.Name)
        if not seenTracks[name] then
            seenTracks[name] = true
            print("[VD] animasi terdeteksi:", track.Name) -- cek di F9 buat nyari nama animasi pallet
        end
        for _, kw in ipairs(VAULT_KEYWORDS) do
            if string.find(name, kw, 1, true) then
                if track.Speed ~= config.vaultSpeed then track:AdjustSpeed(config.vaultSpeed) end
                break
            end
        end
    end
end))

----------------------------------------------------------------
-- GUI: Window
----------------------------------------------------------------
local main = make("Frame", {
    Name = "Main",
    Size = FULL_SIZE,
    Position = UDim2.new(0.5, -220, 0.5, -145),
    BackgroundColor3 = Color3.fromRGB(10, 10, 10),
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
corner(main, 10)

local glow = make("UIStroke", {
    Color = Color3.new(1, 1, 1),
    Thickness = 1.5,
    Transparency = 0.2,
}, main)

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
local top = make("Frame", {
    Size = UDim2.new(1, 0, 0, 34),
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BorderSizePixel = 0,
}, main)

local titleHolder = make("Frame", {
    Size = UDim2.new(1, -80, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
}, top)

make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 6),
}, titleHolder)

make("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "VIOLENCE DISTRICT",
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBlack,
    TextSize = 13,
    LayoutOrder = 1,
}, titleHolder)

make("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = VERSION,
    TextColor3 = Color3.fromRGB(200, 200, 200),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    LayoutOrder = 2,
}, titleHolder)

make("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "by jeysar",
    TextColor3 = Color3.fromRGB(140, 140, 140),
    Font = Enum.Font.Gotham,
    TextSize = 8,
    LayoutOrder = 3,
}, titleHolder)

local function makeTopBtn(text, xOffset)
    local b = make("TextButton", {
        Size = UDim2.new(0, 26, 0, 22),
        Position = UDim2.new(1, xOffset, 0, 6),
        BackgroundColor3 = Color3.fromRGB(35, 35, 35),
        Text = text,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
    }, top)
    corner(b, 6)
    stroke(b, 0.6)
    return b
end

local minBtn = makeTopBtn("–", -62)
local closeBtn = makeTopBtn("X", -32)

-- Body
local body = make("Frame", {
    Size = UDim2.new(1, 0, 1, -34),
    Position = UDim2.new(0, 0, 0, 34),
    BackgroundTransparency = 1,
}, main)

local sidebar = make("Frame", {
    Size = UDim2.new(0, 110, 1, 0),
    BackgroundColor3 = Color3.fromRGB(15, 15, 15),
    BorderSizePixel = 0,
}, body)
make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
make("UIPadding", {
    PaddingTop = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
}, sidebar)

local pages = make("Frame", {
    Size = UDim2.new(1, -110, 1, 0),
    Position = UDim2.new(0, 110, 0, 0),
    BackgroundTransparency = 1,
}, body)

----------------------------------------------------------------
-- GUI: Komponen
----------------------------------------------------------------
local tabs = {}

local function createPage()
    local p = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
    }, pages)
    make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, p)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
    }, p)
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
    local b = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28),
        Text = name,
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
        LayoutOrder = nextOrder(sidebar),
    }, sidebar)
    corner(b, 6)
    local page = createPage()
    tabs[name] = {btn = b, page = page}
    b.MouseButton1Click:Connect(function() selectTab(name) end)
    return page
end

local function createSection(parent, text)
    return make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = string.upper(text),
        TextColor3 = Color3.fromRGB(110, 110, 110),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = nextOrder(parent),
    }, parent)
end

local function createInfo(parent, text)
    return make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.fromRGB(140, 140, 140),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = nextOrder(parent),
    }, parent)
end

local KNOB_OFF = UDim2.new(0, 3, 0.5, -7)
local KNOB_ON = UDim2.new(1, -17, 0.5, -7)

-- key = nama field di `config`; onChange(state) dipanggil setelah config diubah
local function createToggle(parent, text, key, onChange)
    local state = config[key] == true

    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(parent),
    }, parent)
    corner(row, 8)
    stroke(row, 0.85)

    make("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local sw = make("TextButton", {
        Size = UDim2.new(0, 44, 0, 20),
        Position = UDim2.new(1, -54, 0.5, -10),
        BackgroundColor3 = state and Color3.fromRGB(70, 70, 70) or Color3.fromRGB(30, 30, 30),
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(sw, 10)
    stroke(sw, 0.5)

    local knob = make("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = state and KNOB_ON or KNOB_OFF,
        BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 120),
        BorderSizePixel = 0,
    }, sw)
    corner(knob, 7)

    sw.MouseButton1Click:Connect(function()
        state = not state
        config[key] = state
        TweenService:Create(knob, TweenInfo.new(0.2), {
            Position = state and KNOB_ON or KNOB_OFF,
            BackgroundColor3 = state and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 120),
        }):Play()
        TweenService:Create(sw, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(70, 70, 70) or Color3.fromRGB(30, 30, 30),
        }):Play()
        saveConfig()
        notify(text .. (state and " ON" or " OFF"))
        if onChange then onChange(state) end
    end)

    -- terapkan state tersimpan saat load
    if state and onChange then task.defer(onChange, true) end
end

local function createButton(parent, text, callback)
    local b = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28),
        Text = text,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(parent),
    }, parent)
    corner(b, 8)
    stroke(b, 0.85)
    b.MouseButton1Click:Connect(function() callback(b) end)
    return b
end

----------------------------------------------------------------
-- GUI: Isi Tab
----------------------------------------------------------------
-- Tab: Main
local mainPage = createTab("Main")
createSection(mainPage, "Gerakan")
createToggle(mainPage, "Fast Vault (Window & Pallet)", "fastVault")

local function vaultSpeedText()
    return "Speed Vault: " .. string.format("%.1f", config.vaultSpeed) .. "x"
end

createButton(mainPage, vaultSpeedText(), function(btn)
    local idx = table.find(VAULT_PRESETS, config.vaultSpeed) or 0
    idx = idx % #VAULT_PRESETS + 1
    config.vaultSpeed = VAULT_PRESETS[idx]
    btn.Text = vaultSpeedText()
    saveConfig()
    notify(vaultSpeedText())
end)
createInfo(mainPage, "Mempercepat animasi vault (lokal). Game sendiri pakai 1.0x (jalan) dan 1.7x (lari). Makin tinggi makin besar risiko kena anticheat.\nKalau pallet nggak ngaruh, cek nama animasinya di F9 console ([VD] animasi terdeteksi).")

-- Tab: ESP
local espPage = createTab("ESP")
createSection(espPage, "Player")
createToggle(espPage, "Aura Player", "aura", refreshAll)
createToggle(espPage, "Nama & Jarak", "name", refreshAll)
createSection(espPage, "Objek")
createToggle(espPage, "Eyes of Heaven", "eyes", refreshObjs)
createToggle(espPage, "Generator", "generator", refreshObjs)
createToggle(espPage, "Progress Gen (%)", "genProgress", refreshGenColors)
createInfo(espPage, "Putih = Survivor | Merah = Killer\nEyes of Heaven: pallet (kuning), gaya perk tapi lokal.\nGenerator: ungu + bar progress % (kuning), hilang kalau sudah beres.")

-- Tab: Visual
local visualPage = createTab("Visual")
createSection(visualPage, "Lingkungan")
createToggle(visualPage, "Fullbright", "fullbright", function(s)
    if not s then restoreKeys(FB_KEYS) end
end)
createToggle(visualPage, "No Fog", "nofog", function(s)
    if not s then restoreFog() end
end)

-- Tab: Settings
local settingsPage = createTab("Settings")
createSection(settingsPage, "ESP Objek")

local function distanceText()
    return "Jarak Objek: " .. (config.distance == 0 and "Tanpa batas" or (config.distance .. " stud"))
end

createButton(settingsPage, distanceText(), function(btn)
    local idx = table.find(DISTANCE_PRESETS, config.distance) or 0
    idx = idx % #DISTANCE_PRESETS + 1
    config.distance = DISTANCE_PRESETS[idx]
    btn.Text = distanceText()
    saveConfig()
    notify(distanceText())
end)

createSection(settingsPage, "Config")
createButton(settingsPage, "Simpan Config", function()
    notify(saveConfig() and "Config tersimpan" or "Executor tidak support writefile")
end)
createInfo(settingsPage, "Toggle otomatis tersimpan.\nRightShift = show/hide panel (PC)\nBatas jarak membantu menghindari limit Highlight Roblox (~31).")

selectTab("Main")

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

local function unload()
    for plr in pairs(espData) do removeESP(plr) end
    for inst in pairs(objESP) do removeObj(inst) end
    restoreKeys(FB_KEYS)
    restoreFog()
    for _, conns in pairs(playerConns) do
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    end
    table.clear(playerConns)
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    table.clear(connections)
    gui:Destroy()
end

closeBtn.MouseButton1Click:Connect(unload)

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
