-- Violence District | Menu v1.2 by jeysar
-- Tab: Main, ESP, Visual, Settings

local VERSION = "v1.2"

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

if not game:IsLoaded() then game.Loaded:Wait() end

local LocalPlayer = Players.LocalPlayer

-- Kalau script dijalankan ulang, matikan instance lama dulu
-- (biar koneksi lama nggak numpuk dan nggak dobel jalan)
local env = (getgenv and getgenv()) or _G
if env.VD_Unload then pcall(env.VD_Unload) end

print("[Violence District " .. VERSION .. "] Loading...")

----------------------------------------------------------------
-- Konstanta & Config
----------------------------------------------------------------
local COLOR_SURVIVOR = Color3.fromRGB(255, 255, 255)
local COLOR_KILLER = Color3.fromRGB(255, 50, 50)
local COLOR_PALLET = Color3.fromRGB(255, 200, 0)
local COLOR_GENERATOR = Color3.fromRGB(170, 70, 255)

local TOGGLE_KEY = Enum.KeyCode.RightShift
local FULL_SIZE = UDim2.new(0, 440, 0, 290)
local MINI_SIZE = UDim2.new(0, 440, 0, 34)
local DISTANCE_PRESETS = {100, 150, 250, 0} -- 0 = tanpa batas
local VAULT_PRESETS = {1.5, 1.7, 2.0, 2.5, 3.0}
-- batas atas speed animasi window (ikut preset tertinggi: 3.0x)
local WINDOW_MAX_SPEED = 3.0
local CONFIG_FILE = "ViolenceDistrict_config.json"

local DEFAULTS = {
    aura = false,
    name = false,
    eyes = false,
    generator = false,
    genProgress = true,
    fullbright = false,
    nofog = false,
    fastVault = false,
    autoPerfect = false,
    vaultSpeed = 2.0,
    vaultInfo = true,
    walkOn = false,
    walkSpeed = 17,
    distance = 150,
    antiAfk = true,
    notifications = true,
}

local config = {}
for k, v in pairs(DEFAULTS) do config[k] = v end

local function loadConfig()
    if not (isfile and readfile) then return end
    local ok, data = pcall(function()
        if not isfile(CONFIG_FILE) then return nil end
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do
            -- key lama (misal "moonwalk") otomatis diabaikan
            if config[k] ~= nil and type(v) == type(config[k]) then
                config[k] = v
            end
        end
    end
end

local function saveConfig()
    if not writefile then return false end
    return (pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(config))
    end))
end

loadConfig()

----------------------------------------------------------------
-- State & helper umum
----------------------------------------------------------------
local connections = {}
local espData = {}
local objESP = {}
local playerConns = {}
local syncers = {} -- sinkronisasi UI <- config (dipakai buat Reset Config)
local minimized = false

local function track(conn)
    table.insert(connections, conn)
    return conn
end

local function disconnectAll(list)
    for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
    table.clear(list)
end

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
local oldGui = parentGui:FindFirstChild("ViolenceDistrict")
if oldGui then oldGui:Destroy() end

local gui = make("ScreenGui", {Name = "ViolenceDistrict", ResetOnSpawn = false}, parentGui)

----------------------------------------------------------------
-- Toast notifikasi
----------------------------------------------------------------
local toast = make("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 0, 26),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 1, -60),
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
make("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}, toast)

local toastSeq = 0
local function notify(text, force)
    if not (config.notifications or force) then return end
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
    if plr.Team and string.find(string.lower(plr.Team.Name), "killer", 1, true) then
        return true
    end
    local role = plr:GetAttribute("Role") or (plr.Character and plr.Character:GetAttribute("Role"))
    return role ~= nil and string.find(string.lower(tostring(role)), "killer", 1, true) ~= nil
end

local function removeESP(plr)
    local d = espData[plr]
    if not d then return end
    if d.highlight then d.highlight:Destroy() end
    if d.billboard then d.billboard:Destroy() end
    espData[plr] = nil
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
    local charConn -- koneksi atribut Role di karakter saat ini
    playerConns[plr] = conns
    local function refresh() applyESP(plr) end

    local function onCharacter(char)
        char:WaitForChild("HumanoidRootPart", 10)
        if not char.Parent then return end
        if charConn then charConn:Disconnect() end
        charConn = char:GetAttributeChangedSignal("Role"):Connect(refresh)
        table.insert(conns, charConn)
        applyESP(plr)
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
        disconnectAll(conns)
        playerConns[plr] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
track(Players.PlayerAdded:Connect(setupPlayer))
track(Players.PlayerRemoving:Connect(cleanupPlayer))

----------------------------------------------------------------
-- ESP Objek (Pallet & Generator)
----------------------------------------------------------------
local function progressColor(progress)
    local t = math.clamp((progress or 0) / 100, 0, 1)
    local red = Color3.fromRGB(255, 60, 60)
    local yellow = Color3.fromRGB(255, 220, 60)
    local green = Color3.fromRGB(80, 255, 120)
    if t < 0.5 then return red:Lerp(yellow, t * 2) end
    return yellow:Lerp(green, (t - 0.5) * 2)
end

local OBJ_COLORS = {pallet = COLOR_PALLET, generator = COLOR_GENERATOR}

-- Filter berdasarkan struktur map:
--   Pallet    : Workspace.Map.pallets.<Newpallet>
--   Generator : Model dengan atribut RepairProgress
local function getKind(inst)
    if inst:IsA("Model")
        and (inst:GetAttribute("RepairProgress") ~= nil or inst.Name == "Generator") then
        return "generator"
    end
    local parent = inst.Parent
    if parent and (inst:IsA("Model") or inst:IsA("BasePart"))
        and string.lower(parent.Name) == "pallets" then
        return "pallet"
    end
    return nil
end

local function removeObj(inst)
    local d = objESP[inst]
    if not d then return end
    disconnectAll(d.conns)
    if d.hl then d.hl:Destroy() end
    if d.bb then d.bb:Destroy() end
    objESP[inst] = nil
end

local function refreshGen(inst, d)
    local progress = math.clamp(inst:GetAttribute("RepairProgress") or 0, 0, 100)
    d.done = inst:GetAttribute("Completed") == true or progress >= 100
    if d.done then d.hl.Enabled = false end

    if d.bb then
        d.bb.Enabled = config.genProgress and not d.done
        d.label.Text = math.floor(progress + 0.5) .. "%"
        TweenService:Create(d.fill, TweenInfo.new(0.25), {
            Size = UDim2.new(progress / 100, 0, 1, 0),
            BackgroundColor3 = progressColor(progress),
        }):Play()
    end
end

local function refreshGenAll()
    for inst, d in pairs(objESP) do
        if d.kind == "generator" then refreshGen(inst, d) end
    end
end

local function buildGenBar(d, anchor)
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
        BackgroundColor3 = progressColor(0),
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
    local d = {
        kind = kind,
        conns = {},
        done = false,
        -- Highlight ditaruh di gui biar map nggak ke-modif
        hl = make("Highlight", {
            Name = "VD_Obj",
            FillColor = color,
            FillTransparency = 0.6,
            OutlineColor = color,
            OutlineTransparency = 0,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            Adornee = inst,
        }, gui),
    }
    objESP[inst] = d

    if kind == "generator" then
        local anchor = (inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true))) or inst
        buildGenBar(d, anchor)
    end

    table.insert(d.conns, inst.AncestryChanged:Connect(function()
        if not inst:IsDescendantOf(workspace) then removeObj(inst) end
    end))

    if kind == "generator" then
        local function onChanged() refreshGen(inst, d) end
        table.insert(d.conns, inst:GetAttributeChangedSignal("RepairProgress"):Connect(onChanged))
        table.insert(d.conns, inst:GetAttributeChangedSignal("Completed"):Connect(onChanged))
        onChanged()
    end
end

local function refreshObjs()
    for inst in pairs(objESP) do removeObj(inst) end
    if not (config.eyes or config.generator) then return end
    for _, d in ipairs(workspace:GetDescendants()) do applyObj(d) end
end

track(workspace.DescendantAdded:Connect(function(d)
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

track(RunService.RenderStepped:Connect(function()
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
track(RunService.Heartbeat:Connect(function(dt)
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
        if visible and maxD > 0 and rootPos and inst.Parent then
            visible = (inst:GetPivot().Position - rootPos).Magnitude <= maxD
        end
        d.hl.Enabled = visible
        if d.bb then d.bb.Enabled = visible and config.genProgress end
    end
end))

----------------------------------------------------------------
-- Fast Vault (percepat animasi vault pallet, lokal)
----------------------------------------------------------------
-- Satu toggle untuk pallet/running vault ("RunningVaultAnimation", dll) dan
-- vault window ("WalkingVaultAnimation"). Window cuma dipercepat selama
-- isvaulting = true dan speed-nya dibatasi WINDOW_MAX_SPEED.
-- Catatan: ini cuma animasinya; durasi gerak vault asli diatur timer game.
local VAULT_KEYWORDS = {"vault", "pallet"}
local WINDOW_KEYWORD = "walkingvault"

local function hasWord(name, word)
    return string.find(name, word, 1, true) ~= nil
end

local function hasAnyWord(name, list)
    for _, word in ipairs(list) do
        if hasWord(name, word) then return true end
    end
    return false
end

track(RunService.Heartbeat:Connect(function()
    if not config.fastVault then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
        local name = string.lower(t.Name)
        local target
        if hasWord(name, WINDOW_KEYWORD) then
            if char:GetAttribute("isvaulting") == true then
                target = math.min(config.vaultSpeed, WINDOW_MAX_SPEED)
            end
        elseif hasAnyWord(name, VAULT_KEYWORDS) then
            target = config.vaultSpeed
        end
        if target and t.Speed ~= target then t:AdjustSpeed(target) end
    end
end))

----------------------------------------------------------------
-- Info Vault (tier + alasan, baca-saja)
----------------------------------------------------------------
-- Dari log: tier "fast" (VaultReason = ready) cuma keluar kalau lari kenceng
-- dan lurus ke jendela. "pace" = kurang kenceng, "facing" = kurang lurus.
local REASON_TEXT = {ready = "mantap", pace = "kurang kenceng", facing = "kurang lurus"}
local vaultConn

local function hookVaultInfo(char)
    if vaultConn then vaultConn:Disconnect() vaultConn = nil end
    vaultConn = char:GetAttributeChangedSignal("__VaultFireCount"):Connect(function()
        if not config.vaultInfo then return end
        task.delay(0.1, function()
            local tier = char:GetAttribute("VaultTier")
            local reason = char:GetAttribute("VaultReason")
            if not tier then return end
            notify("Vault " .. string.upper(tostring(tier)) .. " (" .. (REASON_TEXT[reason] or tostring(reason)) .. ")")
        end)
    end)
end

track(LocalPlayer.CharacterAdded:Connect(hookVaultInfo))
if LocalPlayer.Character then hookVaultInfo(LocalPlayer.Character) end

----------------------------------------------------------------
-- Speed Karakter (angka tetap, aktif pas sprint, lokal)
----------------------------------------------------------------
-- Game pakai WalkSpeed 10 (jalan) dan 17 (sprint). Dicek tiap frame
-- (Stepped + Heartbeat) supaya nggak ketimpa script game. Aktif cuma pas
-- sprint; vault, knocked, hooked, carried tetap diatur game.
local walk = {hum = nil, base = nil, ours = nil, disabled = false}
local WALK_BLOCK_ATTRS = {"isvaulting", "Knocked", "IsHooked", "IsCarried"}
local WALK_SPRINT_MIN = 15 -- cadangan kalau atribut Sprinting nggak kebaca

local function walkStep()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum ~= walk.hum then
        walk.hum, walk.base, walk.ours = hum, hum.WalkSpeed, nil
    end

    local cur = hum.WalkSpeed
    if not (walk.ours and math.abs(cur - walk.ours) < 1e-4) then
        walk.base = cur -- nilai terbaru dari game
    end

    local blocked = false
    for _, a in ipairs(WALK_BLOCK_ATTRS) do
        if char:GetAttribute(a) == true then blocked = true break end
    end
    local sprinting = char:GetAttribute("Sprinting") == true or walk.base >= WALK_SPRINT_MIN

    if config.walkOn and not walk.disabled and not blocked and sprinting and walk.base > 0 then
        walk.ours = config.walkSpeed
        if cur ~= walk.ours then hum.WalkSpeed = walk.ours end
    elseif walk.ours then
        walk.ours = nil
        hum.WalkSpeed = walk.base
    end
end

track(RunService.Stepped:Connect(walkStep))
track(RunService.Heartbeat:Connect(walkStep))

----------------------------------------------------------------
-- Anti-AFK
----------------------------------------------------------------
track(LocalPlayer.Idled:Connect(function()
    if not config.antiAfk then return end
    local ok, vu = pcall(game.GetService, game, "VirtualUser")
    if ok and vu then
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end
end))

----------------------------------------------------------------
-- Auto Perfect Skill Check
----------------------------------------------------------------
-- Dari log game: Line.Rotation di 102..116 derajat di atas Goal.Rotation
-- = PERFECT, 116..159 = good (script game: Skillcheck-gen). Jarum jalan
-- sekitar 280 derajat/detik, jadi zona perfect cuma ~50 ms. Kita prediksi
-- posisi jarum di frame berikutnya, lalu tekan tombol skill check lewat
-- input virtual (jalurnya sama kayak pencet beneran: UserInputService).
local PERFECT_MIN, PERFECT_MAX, PERFECT_AIM = 102, 116, 109
local SKILL_GUIS = {"SkillCheckPromptGui", "SkillCheckPromptGui-con"}
local VIM = game:GetService("VirtualInputManager")
local KeybindsModule
pcall(function()
    KeybindsModule = require(game:GetService("ReplicatedStorage")
        .Modules.Survivors.KeybindsConfig)
end)

local autoState = {lastRot = nil, lastT = nil, pressed = false, warned = false}

local function findSkillCheck()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, name in ipairs(SKILL_GUIS) do
        local g = pg:FindFirstChild(name)
        local c = g and g:FindFirstChild("Check")
        if c and c.Visible then return c end
    end
    return nil
end

local function pressSkillKey()
    local raw = "Space"
    if KeybindsModule and KeybindsModule.getRaw then
        local ok, r = pcall(KeybindsModule.getRaw, "skillcheck")
        if ok and type(r) == "string" then raw = r end
    end
    return pcall(function()
        if raw == "MouseButton1" or raw == "MouseButton2" then
            local btn = raw == "MouseButton1" and 0 or 1
            local c = workspace.CurrentCamera.ViewportSize / 2
            VIM:SendMouseButtonEvent(c.X, c.Y, btn, true, game, 0)
            VIM:SendMouseButtonEvent(c.X, c.Y, btn, false, game, 0)
        else
            local key = Enum.KeyCode[raw]
            VIM:SendKeyEvent(true, key, false, game)
            task.delay(0.03, function() VIM:SendKeyEvent(false, key, false, game) end)
        end
    end)
end

local function resetAuto()
    autoState.lastRot, autoState.lastT, autoState.pressed = nil, nil, false
end

track(RunService.RenderStepped:Connect(function()
    if not config.autoPerfect then return resetAuto() end
    local check = findSkillCheck()
    if not check then return resetAuto() end

    -- varian trap punya zona sendiri; jangan disentuh
    local trap = check:FindFirstChild("TrapGoal")
    if trap and trap.Visible then return end

    local line, goal = check:FindFirstChild("Line"), check:FindFirstChild("Goal")
    if not (line and goal) then return end

    local now, rot = os.clock(), line.Rotation
    local last = autoState.lastRot
    if last and rot < last - 10 then autoState.pressed = false end -- skill check baru

    if last and not autoState.pressed then
        local dt = now - autoState.lastT
        local speed = dt > 0 and (rot - last) / dt or 0
        local zoneStart = goal.Rotation + PERFECT_MIN
        local zoneEnd = goal.Rotation + PERFECT_MAX
        local target = goal.Rotation + PERFECT_AIM

        if rot > zoneEnd then
            autoState.pressed = true -- udah kelewat, jangan dipencet
        elseif speed > 0 and rot >= zoneStart - speed * dt
            and rot + speed * dt >= target then
            autoState.pressed = true
            if not pressSkillKey() and not autoState.warned then
                autoState.warned = true
                notify("Auto Perfect: input virtual nggak didukung executor", true)
            end
        end
    end
    autoState.lastRot, autoState.lastT = rot, now
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
    local info = TweenInfo.new(1.2, Enum.EasingStyle.Sine)
    while gui.Parent do
        TweenService:Create(glow, info, {Transparency = 0.7}):Play()
        task.wait(1.2)
        if not gui.Parent then break end
        TweenService:Create(glow, info, {Transparency = 0.1}):Play()
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

local function titleLabel(text, color, font, size, order)
    make("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = color,
        Font = font,
        TextSize = size,
        LayoutOrder = order,
    }, titleHolder)
end

titleLabel("VIOLENCE DISTRICT", Color3.new(1, 1, 1), Enum.Font.GothamBlack, 13, 1)
titleLabel(VERSION, Color3.fromRGB(200, 200, 200), Enum.Font.GothamBold, 10, 2)
titleLabel("by jeysar", Color3.fromRGB(140, 140, 140), Enum.Font.Gotham, 8, 3)

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

-- Tombol melayang buat HP (RightShift nggak ada di mobile)
local floatBtn
if UIS.TouchEnabled then
    floatBtn = make("TextButton", {
        Name = "VD_Float",
        Size = UDim2.new(0, 38, 0, 38),
        Position = UDim2.new(0, 10, 0.5, -19),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BackgroundTransparency = 0.15,
        Text = "VD",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBlack,
        TextSize = 12,
        AutoButtonColor = true,
    }, gui)
    corner(floatBtn, 19)
    stroke(floatBtn, 0.4)
    floatBtn.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
    end)
end

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

local function createRow(parent)
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(parent),
    }, parent)
    corner(row, 8)
    stroke(row, 0.85)
    return row
end

local function rowLabel(row, text, widthOffset)
    make("TextLabel", {
        Size = UDim2.new(1, widthOffset, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
end

local KNOB_OFF = UDim2.new(0, 3, 0.5, -7)
local KNOB_ON = UDim2.new(1, -17, 0.5, -7)
local SW_ON = Color3.fromRGB(70, 70, 70)
local SW_OFF = Color3.fromRGB(30, 30, 30)
local KNOB_ON_COLOR = Color3.new(1, 1, 1)
local KNOB_OFF_COLOR = Color3.fromRGB(120, 120, 120)

-- key = nama field di `config`; onChange(state) dipanggil setelah config diubah
local function createToggle(parent, text, key, onChange)
    local row = createRow(parent)
    rowLabel(row, text, -70)

    local sw = make("TextButton", {
        Size = UDim2.new(0, 44, 0, 20),
        Position = UDim2.new(1, -54, 0.5, -10),
        BackgroundColor3 = SW_OFF,
        Text = "",
        AutoButtonColor = false,
    }, row)
    corner(sw, 10)
    stroke(sw, 0.5)

    local knob = make("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = KNOB_OFF,
        BackgroundColor3 = KNOB_OFF_COLOR,
        BorderSizePixel = 0,
    }, sw)
    corner(knob, 7)

    local function paint(state, animate)
        local knobProps = {
            Position = state and KNOB_ON or KNOB_OFF,
            BackgroundColor3 = state and KNOB_ON_COLOR or KNOB_OFF_COLOR,
        }
        local swProps = {BackgroundColor3 = state and SW_ON or SW_OFF}
        if animate then
            TweenService:Create(knob, TweenInfo.new(0.2), knobProps):Play()
            TweenService:Create(sw, TweenInfo.new(0.2), swProps):Play()
        else
            for k, v in pairs(knobProps) do knob[k] = v end
            for k, v in pairs(swProps) do sw[k] = v end
        end
    end

    paint(config[key] == true, false)

    sw.MouseButton1Click:Connect(function()
        local state = not config[key]
        config[key] = state
        paint(state, true)
        saveConfig()
        notify(text .. (state and " ON" or " OFF"))
        if onChange then onChange(state) end
    end)

    -- dipanggil saat Reset Config
    syncers[key] = function()
        paint(config[key] == true, true)
        if onChange then onChange(config[key]) end
    end

    -- terapkan state tersimpan saat load
    if config[key] == true and onChange then task.defer(onChange, true) end
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

-- tombol yang muter antar preset; labelFn() = teks dari nilai config saat ini
local function createCycle(parent, key, presets, labelFn)
    local btn = createButton(parent, labelFn(), function(b)
        local idx = table.find(presets, config[key]) or 0
        config[key] = presets[idx % #presets + 1]
        b.Text = labelFn()
        saveConfig()
        notify(labelFn())
    end)
    syncers[key] = function() btn.Text = labelFn() end
    return btn
end

local function fmtNum(v) return string.format("%g", math.floor(v * 100 + 0.5) / 100) end

-- input angka: key = field di `config`, dibatasi minV..maxV
local function createInput(parent, text, key, minV, maxV, onChange)
    local row = createRow(parent)
    rowLabel(row, text, -90)

    local box = make("TextBox", {
        Size = UDim2.new(0, 60, 0, 22),
        Position = UDim2.new(1, -70, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        Text = fmtNum(config[key]),
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        ClearTextOnFocus = false,
    }, row)
    corner(box, 6)
    stroke(box, 0.5)

    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            config[key] = math.clamp(n, minV, maxV)
            saveConfig()
            notify(text .. ": " .. fmtNum(config[key]))
            if onChange then onChange(config[key]) end
        end
        box.Text = fmtNum(config[key])
    end)

    syncers[key] = function()
        box.Text = fmtNum(config[key])
        if onChange then onChange(config[key]) end
    end
end

----------------------------------------------------------------
-- Unload
----------------------------------------------------------------
local function unload()
    for plr in pairs(espData) do removeESP(plr) end
    for inst in pairs(objESP) do removeObj(inst) end
    restoreKeys(FB_KEYS)
    restoreFog()

    walk.disabled = true
    walkStep() -- kembalikan WalkSpeed bawaan game

    for _, conns in pairs(playerConns) do disconnectAll(conns) end
    table.clear(playerConns)
    disconnectAll(connections)
    if vaultConn then vaultConn:Disconnect() vaultConn = nil end

    if env.VD_Unload == unload then env.VD_Unload = nil end
    gui:Destroy()
    print("[Violence District " .. VERSION .. "] Unloaded")
end

----------------------------------------------------------------
-- GUI: Isi Tab
----------------------------------------------------------------
-- Tab: Main
local mainPage = createTab("Main")
createSection(mainPage, "Gerakan")
createToggle(mainPage, "Fast Vault (Pallet & Window)", "fastVault")
createCycle(mainPage, "vaultSpeed", VAULT_PRESETS, function()
    return "Speed Vault: " .. string.format("%.1f", config.vaultSpeed) .. "x"
end)
createToggle(mainPage, "Info Vault (tier)", "vaultInfo")
createInfo(mainPage, "Fast Vault cuma mempercepat ANIMASI (window max 3.0x); durasi vault asli diatur game per tier. Vault beneran cepat (tier FAST) didapat kalau lari kenceng + lurus ke jendela. Info Vault nunjukin tier & alasannya tiap vault: kurang kenceng / kurang lurus.")

createSection(mainPage, "Generator")
createToggle(mainPage, "Auto Perfect Skill Check", "autoPerfect")
createInfo(mainPage, "Otomatis nekan tombol skill check pas jarum di zona perfect. Cuma jalan pas skill check biasa muncul (varian trap dilewati). Hasil perfect terus-terusan bisa kelihatan aneh buat player lain, pakai secukupnya.")

createSection(mainPage, "Karakter")
createToggle(mainPage, "Speed Karakter", "walkOn", walkStep)
createInput(mainPage, "Speed Sprint", "walkSpeed", 10, 30, walkStep)
createInfo(mainPage, "Ketik angka lalu Enter (10 - 30), misal 18. Aktif cuma pas sprint; speed bawaan game sprint = 17. Jalan, vault, knocked, hooked, dan carried tetap diatur game. Makin tinggi makin gampang kena anticheat, saran 18 - 20.")

-- Tab: ESP
local espPage = createTab("ESP")
createSection(espPage, "Player")
createToggle(espPage, "Aura Player", "aura", refreshAll)
createToggle(espPage, "Nama & Jarak", "name", refreshAll)
createSection(espPage, "Objek")
createToggle(espPage, "Eyes of Heaven", "eyes", refreshObjs)
createToggle(espPage, "Generator", "generator", refreshObjs)
createToggle(espPage, "Progress Gen (%)", "genProgress", refreshGenAll)
createInfo(espPage, "Putih = Survivor | Merah = Killer\nEyes of Heaven: pallet (kuning), gaya perk tapi lokal.\nGenerator: ungu + bar progress % (merah > kuning > hijau), hilang kalau sudah beres.")

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
createSection(settingsPage, "Umum")
createToggle(settingsPage, "Anti-AFK", "antiAfk")
createToggle(settingsPage, "Notifikasi", "notifications")

createSection(settingsPage, "ESP Objek")
createCycle(settingsPage, "distance", DISTANCE_PRESETS, function()
    return "Jarak Objek: " .. (config.distance == 0 and "Tanpa batas" or (config.distance .. " stud"))
end)

createSection(settingsPage, "Config")
createButton(settingsPage, "Simpan Config", function()
    notify(saveConfig() and "Config tersimpan" or "Executor tidak support writefile", true)
end)
createButton(settingsPage, "Reset Config", function()
    for k, v in pairs(DEFAULTS) do config[k] = v end
    for _, sync in pairs(syncers) do sync() end
    saveConfig()
    notify("Config direset ke default", true)
end)
createButton(settingsPage, "Unload Script", unload)
createInfo(settingsPage, "Toggle otomatis tersimpan.\nRightShift = show/hide panel (PC), tombol VD = show/hide (HP).\nBatas jarak membantu menghindari limit Highlight Roblox (~31).")

selectTab("Main")

----------------------------------------------------------------
-- Minimize / Unload / Keybind / Drag
----------------------------------------------------------------
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    body.Visible = not minimized
    TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
        Size = minimized and MINI_SIZE or FULL_SIZE,
    }):Play()
    minBtn.Text = minimized and "+" or "–"
end)

closeBtn.MouseButton1Click:Connect(unload)
env.VD_Unload = unload

track(UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == TOGGLE_KEY then
        main.Visible = not main.Visible
    end
end))

local dragging, dragStart, startPos
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)
track(UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end))
track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

print("[Violence District " .. VERSION .. "] Loaded - made by jeysar")
notify("Loaded " .. VERSION .. " - made by jeysar", true)
