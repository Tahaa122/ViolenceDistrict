-- Violence District | Menu v1.3 by jeysar
-- Tab: Main, Player, Survivor, Killer, ESP, Visual, Settings

local VERSION = "v1.3"

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

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
    generator = false,
    genProgress = true,
    fullbright = false,
    nofog = false,
    fastVault = false,
    autoPerfect = false,
    autoLead = 1.5,
    autoDebug = false,
    vaultSpeed = 2.0,
    vaultInfo = true,
    walkOn = false,
    walkSpeed = 17,
    distance = 150,
    antiAfk = true,
    notifications = true,
    -- v1.3: Player
    noclip = false,
    fly = false,
    flySpeed = 60,
    infJump = false,
    jumpOn = false,
    jumpPower = 50,
    freeze = false,
    shiftlock = false,
    -- v1.3: Survivor
    autoEscape = false,
    gateTool = false,
    autoParry = false,
    noFall = false,
    -- v1.3: Killer
    autoSlash = false,
    slashMode = "Legit",
    antiBlind = false,
    antiStun = false,
    -- v1.3: ESP objek
    hook = false,
    gate = false,
    vault = false,
    -- v1.3: Visual
    forceTime = false,
    timeValue = 12,
    saturation = false,
    satValue = 1.5,
    skybox = "Off",
    bodyMod = false,
    bodyMaterial = "SmoothPlastic",
    -- v1.3: Performance
    noShadows = false,
    lowGfx = false,
    zoom = false,
    fpsUnlock = false,
    fpsCap = 0,
    fpsCounter = false,
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
-- fitur yang ngubah karakter nggak boleh nyala sendiri pas script dijalankan
for _, k in ipairs({"noclip", "fly", "freeze", "gateTool"}) do config[k] = false end

----------------------------------------------------------------
-- State & helper umum
----------------------------------------------------------------
local connections = {}
local espData = {}
local objESP = {}
local playerConns = {}
local syncers = {} -- sinkronisasi UI <- config (dipakai buat Reset Config)
local minimized = false
local unloaded = false

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
-- ESP Objek (Generator, Hook, Gate, Vault)
----------------------------------------------------------------
local function progressColor(progress)
    local t = math.clamp((progress or 0) / 100, 0, 1)
    local red = Color3.fromRGB(255, 60, 60)
    local yellow = Color3.fromRGB(255, 220, 60)
    local green = Color3.fromRGB(80, 255, 120)
    if t < 0.5 then return red:Lerp(yellow, t * 2) end
    return yellow:Lerp(green, (t - 0.5) * 2)
end

local OBJ_COLORS = {
    generator = COLOR_GENERATOR,
    hook = Color3.fromRGB(245, 66, 90),
    gate = Color3.fromRGB(44, 194, 27),
    vault = Color3.fromRGB(80, 200, 255),
}
-- nama model di Workspace.Map -> jenis objek
local NAME_KINDS = {Hook = "hook", Gate = "gate", Window = "vault", Vault = "vault"}
-- jenis objek -> field config yang mengaktifkannya
local KIND_FLAG = {generator = "generator", hook = "hook", gate = "gate", vault = "vault"}

local function anyObjEnabled()
    return config.generator or config.hook or config.gate or config.vault
end

-- Filter berdasarkan struktur map:
--   Generator : Model dengan atribut RepairProgress
--   Hook / Gate / Window / Vault : Model bernama itu di Workspace.Map
local function getKind(inst)
    if inst:IsA("Model")
        and (inst:GetAttribute("RepairProgress") ~= nil or inst.Name == "Generator") then
        return "generator"
    end
    local named = NAME_KINDS[inst.Name]
    if named and inst:IsA("Model") then
        local map = workspace:FindFirstChild("Map")
        if map and inst:IsDescendantOf(map) then return named end
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
    stroke(bg, 0.3, COLOR_GENERATOR)
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
    if not config[KIND_FLAG[kind]] then return end

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
    if not anyObjEnabled() then return end
    for _, d in ipairs(workspace:GetDescendants()) do applyObj(d) end
end

track(workspace.DescendantAdded:Connect(function(d)
    if anyObjEnabled() then
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
    if config.forceTime then Lighting.ClockTime = config.timeValue end
    if config.noShadows then Lighting.GlobalShadows = false end
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
-- Zona PERFECT = Line ada di 104..114 derajat di depan Goal. Selisihnya
-- dihitung modulo 360 (logika sama kayak script asli game), jadi aman
-- walaupun Rotation udah muter lewat 360 / negatif.
-- Jarum jalan sekitar 280 derajat/detik, zona perfect cuma ~35 ms, makanya
-- posisi jarum diprediksi 1 frame ke depan (input virtual baru diproses
-- di frame berikutnya). Tiap skill check cuma ditekan SEKALI.
local PERFECT_MIN, PERFECT_MAX, PERFECT_AIM = 104, 114, 109
local HOLD_TIME = 0.01      -- lama tombol ditahan
-- prediksi frame ke depan diatur lewat config.autoLead (input di tab Main)
local MAX_LEAD = 12         -- batas prediksi (derajat) biar nggak kejauhan pas lag
local SKILL_GUIS = {"SkillCheckPromptGui", "SkillCheckPromptGui-con"}
local VIM = game:GetService("VirtualInputManager")
local KeybindsModule
pcall(function()
    KeybindsModule = require(game:GetService("ReplicatedStorage")
        .Modules.Survivors.KeybindsConfig)
end)

local autoState = {lastDiff = nil, lastT = nil, goalRot = nil, pressed = false, didPress = false, frames = 0, warned = false}

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
            task.delay(HOLD_TIME, function()
                VIM:SendMouseButtonEvent(c.X, c.Y, btn, false, game, 0)
            end)
        else
            local key = Enum.KeyCode[raw]
            VIM:SendKeyEvent(true, key, false, game)
            task.delay(HOLD_TIME, function() VIM:SendKeyEvent(false, key, false, game) end)
        end
    end)
end

local function resetAuto()
    if autoState.frames > 0 and not autoState.didPress and config.autoDebug then
        print("[AutoPerfect] skill check selesai tanpa pencet")
    end
    autoState.lastDiff, autoState.lastT, autoState.goalRot = nil, nil, nil
    autoState.pressed, autoState.didPress, autoState.frames = false, false, 0
end

-- Heartbeat (sama kayak script asli): jalan setelah game selesai update Line
track(RunService.Heartbeat:Connect(function()
    if not config.autoPerfect then return resetAuto() end
    local check = findSkillCheck()
    if not check then return resetAuto() end

    -- varian trap punya zona sendiri; jangan disentuh
    local trap = check:FindFirstChild("TrapGoal")
    if trap and trap.Visible then return resetAuto() end

    local line, goal = check:FindFirstChild("Line"), check:FindFirstChild("Goal")
    if not (line and goal) then return end

    local now = os.clock()
    local diff = (line.Rotation - goal.Rotation) % 360
    local last = autoState.lastDiff

    -- skill check baru: Goal pindah, atau jarum muter balik ke awal
    if autoState.goalRot and math.abs(goal.Rotation - autoState.goalRot) > 0.01 then
        autoState.pressed, autoState.didPress = false, false
    end
    if last and diff < last - 180 then autoState.pressed = false end
    autoState.goalRot = goal.Rotation
    autoState.frames += 1

    if last and not autoState.pressed then
        local dt = now - autoState.lastT
        local step = (diff - last) % 360
        if step > 180 then step -= 360 end -- negatif = jarum mundur
        local speed = dt > 0 and step / dt or 0

        if speed > 0 then
            local lead = math.min(speed * dt * config.autoLead, MAX_LEAD)
            if diff <= PERFECT_MAX and diff + lead >= PERFECT_AIM then
                autoState.pressed, autoState.didPress = true, true
                if config.autoDebug then
                    print(string.format("[AutoPerfect] PRESS diff=%.1f speed=%.0f deg/s lead=%.1f", diff, speed, lead))
                end
                if not pressSkillKey() and not autoState.warned then
                    autoState.warned = true
                    notify("Auto Perfect: input virtual nggak didukung executor", true)
                end
            elseif diff > PERFECT_MAX and diff < 180 then
                autoState.pressed = true -- udah kelewat, jangan dipencet
            end
        end
    end
    autoState.lastDiff, autoState.lastT = diff, now
end))

----------------------------------------------------------------
-- Fitur tambahan v1.3 (Player, Survivor, Killer, Visual, Performance)
----------------------------------------------------------------
-- Fitur yang butuh remote game (Auto Parry, Auto Slash, Gate Tool, dll)
-- disusun dari nama remote yang kebaca di script TexRBLX. Kalau ada yang
-- nggak jalan, nyalakan lalu cek console (F9) / kabari errornya.
local function getChar()
    local c = LocalPlayer.Character
    return c, c and c:FindFirstChildOfClass("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

local function isSurvivor(plr)
    if plr.Team and string.find(string.lower(plr.Team.Name), "survivor", 1, true) then
        return true
    end
    local role = plr:GetAttribute("Role") or (plr.Character and plr.Character:GetAttribute("Role"))
    return role ~= nil and string.find(string.lower(tostring(role)), "survivor", 1, true) ~= nil
end

local function findRemote(...)
    local node = game:GetService("ReplicatedStorage")
    for _, name in ipairs({...}) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

-- player lain dalam jarak `range`; wantKiller = true cari killer, false cari survivor
local function inRange(root, range, wantKiller)
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p ~= LocalPlayer and p.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local roleOk = wantKiller and isKiller(p) or (not wantKiller and isSurvivor(p))
        if r and h and h.Health > 0 and roleOk and (r.Position - root.Position).Magnitude <= range then
            table.insert(list, {plr = p, char = c})
        end
    end
    return list
end

----------------------------------------------------------------
-- Player: noclip, fly, infinite jump, jump power, freeze, shift lock
----------------------------------------------------------------
local mods = {flying = false, jumpHum = nil, jumpOrig = nil, bodyOrig = {}}

local function stopFly()
    mods.flying = false
    local _, hum = getChar()
    if hum then hum.PlatformStand = false end
end

local function restoreBody()
    for part, mat in pairs(mods.bodyOrig) do
        if part.Parent then part.Material = mat end
    end
    table.clear(mods.bodyOrig)
end

local function applyFreeze(state)
    local _, _, root = getChar()
    if root and not state then root.Anchored = false end
end

local function applyShiftLock(state)
    pcall(function() LocalPlayer.DevEnableMouseLock = state end)
end

track(RunService.Stepped:Connect(function()
    if not config.noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
    end
end))

track(RunService.Heartbeat:Connect(function()
    local char, hum, root = getChar()
    if not (hum and root) then return end

    -- fly (arah = joystick/WASD, Space naik, Ctrl turun)
    if config.fly then
        local dir = hum.MoveDirection
        if UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump then dir += Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
        mods.flying = true
        hum.PlatformStand = true
        root.AssemblyLinearVelocity = dir.Magnitude > 0 and dir.Unit * config.flySpeed or Vector3.zero
    elseif mods.flying then
        stopFly()
    end

    -- jump power
    if config.jumpOn then
        if mods.jumpHum ~= hum then
            mods.jumpHum = hum
            mods.jumpOrig = {use = hum.UseJumpPower, power = hum.JumpPower}
        end
        hum.UseJumpPower = true
        hum.JumpPower = config.jumpPower
    elseif mods.jumpHum == hum and mods.jumpOrig then
        hum.UseJumpPower = mods.jumpOrig.use
        hum.JumpPower = mods.jumpOrig.power
        mods.jumpHum, mods.jumpOrig = nil, nil
    end

    -- freeze
    if config.freeze then root.Anchored = true end

    -- body modifier (material saja, nilai asli disimpan buat restore)
    if config.bodyMod then
        local mat = Enum.Material[config.bodyMaterial]
        for _, part in ipairs(char:GetChildren()) do
            if mat and part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                if mods.bodyOrig[part] == nil then mods.bodyOrig[part] = part.Material end
                if part.Material ~= mat then part.Material = mat end
            end
        end
    end
end))

track(UIS.JumpRequest:Connect(function()
    if not config.infJump then return end
    local _, hum = getChar()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

----------------------------------------------------------------
-- Survivor: escape, gate tool, sacrifice, auto parry, no fall
----------------------------------------------------------------
local function instantEscape(silent)
    if not isSurvivor(LocalPlayer) then
        if not silent then notify("Instant Escape: kamu bukan survivor", true) end
        return
    end
    local _, _, root = getChar()
    local map = workspace:FindFirstChild("Map")
    local finish
    for _, d in ipairs(map and map:GetDescendants() or {}) do
        if d.Name == "Fininshline" then finish = d break end
    end
    if not (root and finish) then
        if not silent then notify("Garis finish nggak ketemu", true) end
        return
    end
    if not firetouchinterest then
        notify("Executor nggak support firetouchinterest", true)
        return
    end
    local part = finish:IsA("BasePart") and finish or finish:FindFirstChildWhichIsA("BasePart", true)
    if part then
        firetouchinterest(root, part, 0)
        task.wait()
        firetouchinterest(root, part, 1)
        notify("Escape dikirim", true)
    end
end

task.spawn(function()
    while gui.Parent do
        task.wait(10)
        if config.autoEscape then pcall(instantEscape, true) end
    end
end)

local gateTool
local function setGateTool(state)
    if state and not gateTool then
        gateTool = make("Tool", {Name = "Gate Tool", RequiresHandle = false, CanBeDropped = false})
        gateTool.Activated:Connect(function()
            local ev = findRemote("Remotes", "Items", "Gate", "gate")
            if ev then ev:FireServer() else notify("Remote gate nggak ketemu", true) end
        end)
        task.spawn(function()
            local backpack = LocalPlayer:WaitForChild("Backpack", 5)
            if backpack and gateTool then gateTool.Parent = backpack end
        end)
    elseif not state and gateTool then
        gateTool:Destroy()
        gateTool = nil
    end
end

local function sacrificeSelf()
    if not replicatesignal then
        notify("Executor nggak support replicatesignal", true)
        return
    end
    local ok = pcall(function() replicatesignal(LocalPlayer.Kill) end)
    notify(ok and "Sacrifice dikirim" or "Sacrifice gagal", true)
end

local lastParry = 0
track(RunService.Heartbeat:Connect(function()
    if not config.autoParry or os.clock() - lastParry < 0.1 then return end
    local char, _, root = getChar()
    if not root or #inRange(root, 25, true) == 0 then return end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local hasDagger = (backpack and backpack:FindFirstChild("Parrying Dagger"))
        or char:FindFirstChild("Parrying Dagger")
    local ev = findRemote("Remotes", "Items", "Parrying Dagger", "parry")
    if hasDagger and ev then
        lastParry = os.clock()
        ev:FireServer()
    end
end))

-- hook __namecall (dipasang sekali, hanya kalau No Fall / Anti Blind dinyalakan)
local BLOCKED_REMOTES = {Fall = "noFall", GotBlinded = "antiBlind"}
local namecallHooked, oldNamecall = false, nil
local function ensureHook()
    if namecallHooked then return end
    if not (hookmetamethod and getnamecallmethod and newcclosure) then
        notify("Executor nggak support hookmetamethod", true)
        return
    end
    namecallHooked = true
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if not unloaded and getnamecallmethod() == "FireServer"
            and not (checkcaller and checkcaller()) then
            local flag = BLOCKED_REMOTES[self.Name]
            if flag and config[flag] then return end
        end
        return oldNamecall(self, ...)
    end))
end

----------------------------------------------------------------
-- Killer: auto slash, anti stun
----------------------------------------------------------------
local SLASH_MODES = {"Rage", "Legit", "Multi"}

task.spawn(function()
    while gui.Parent do
        task.wait(0.1)
        local char, hum, root = getChar()
        if not (hum and root and isKiller(LocalPlayer)) then continue end

        if config.antiStun then
            hum.AutoRotate = true
            if char:GetAttribute("Immobile") then char:SetAttribute("Immobile", false) end
        end

        if config.autoSlash then
            local targets = {}
            for _, t in ipairs(inRange(root, 10, false)) do
                local c = t.char
                if not (c:GetAttribute("IsCarried") or c:GetAttribute("Knocked") or c:GetAttribute("IsHooked")) then
                    table.insert(targets, t)
                end
            end
            local ev = findRemote("Remotes", "Attacks", "BasicAttack")
            if ev and #targets > 0 then
                if config.slashMode == "Multi" then
                    for _ = 1, #targets do ev:FireServer() end
                else
                    ev:FireServer()
                end
                if config.slashMode == "Legit" then task.wait(2) end
            end
        end
    end
end)

----------------------------------------------------------------
-- Visual: saturation, skybox
----------------------------------------------------------------
local colorCorrection
local function applySaturation()
    if config.saturation then
        if not colorCorrection then
            colorCorrection = make("ColorCorrectionEffect", {Name = "VD_ColorCorrection"}, Lighting)
        end
        colorCorrection.Saturation = config.satValue
    elseif colorCorrection then
        colorCorrection:Destroy()
        colorCorrection = nil
    end
end

local SKYBOXES = {
    ["Purple Nebula"] = {159454299, 159454296, 159454293, 159454286, 159454300, 159454288},
    ["Night Sky"] = {12064107, 12064152, 12064121, 12063984, 12064115, 12064131},
    ["Pink Daylight"] = {271042516, 271077243, 271042556, 271042310, 271042467, 271077958},
    ["Morning Glow"] = {1417494030, 1417494146, 1417494253, 1417494402, 1417494499, 1417494643},
    ["Setting Sun"] = {626460377, 626460216, 626460513, 626473032, 626458639, 626460625},
    ["Fade Blue"] = {153695414, 153695352, 153695452, 153695320, 153695383, 153695471},
    ["Elegant Morning"] = {153767241, 153767216, 153767266, 153767200, 153767231, 153767288},
    ["Neptune"] = {218955819, 218953419, 218954524, 218958493, 218957134, 218950090},
    ["Redshift"] = {401664839, 401664862, 401664960, 401664881, 401664901, 401664936},
}
local SKY_FACES = {"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp"}
local SKY_NAMES = {"Off"}
do
    local names = {}
    for name in pairs(SKYBOXES) do table.insert(names, name) end
    table.sort(names)
    for _, n in ipairs(names) do table.insert(SKY_NAMES, n) end
end

local customSky
local function applySky()
    if customSky then customSky:Destroy() customSky = nil end
    local ids = SKYBOXES[config.skybox]
    if not ids then return end
    customSky = make("Sky", {Name = "VD_Sky", CelestialBodiesShown = false}, Lighting)
    for i, face in ipairs(SKY_FACES) do customSky[face] = "rbxassetid://" .. ids[i] end
end

local BODY_MATERIALS = {"SmoothPlastic", "Neon", "ForceField", "Glass", "Foil"}

----------------------------------------------------------------
-- Performance & server
----------------------------------------------------------------
local FPS_PRESETS = {60, 120, 144, 240, 0} -- 0 = tanpa batas
local zoomOriginal = LocalPlayer.CameraMaxZoomDistance

local function applyZoom(state)
    LocalPlayer.CameraMaxZoomDistance = state and 1e5 or zoomOriginal
end

local function applyLowGfx(state)
    pcall(function()
        settings().Rendering.QualityLevel = state and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
end

local fpsLabel = make("TextLabel", {
    Name = "VD_FPS",
    Size = UDim2.new(0, 80, 0, 20),
    Position = UDim2.new(1, -90, 0, 8),
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BackgroundTransparency = 0.3,
    TextColor3 = Color3.new(1, 1, 1),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    Text = "FPS",
    Visible = false,
}, gui)
corner(fpsLabel, 6)

local fpsFrames, fpsT = 0, os.clock()
track(RunService.RenderStepped:Connect(function()
    if not config.fpsCounter then return end
    fpsFrames += 1
    if os.clock() - fpsT >= 1 then
        fpsLabel.Text = "FPS: " .. fpsFrames
        fpsFrames, fpsT = 0, os.clock()
    end
end))

local function rejoin()
    notify("Rejoin...", true)
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

local function serverhop()
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)))
    end)
    if not (ok and type(res) == "table" and res.data) then
        notify("Gagal ambil daftar server", true)
        return
    end
    for _, s in ipairs(res.data) do
        if s.id ~= game.JobId and s.playing < s.maxPlayers then
            notify("Pindah server...", true)
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
            end)
            return
        end
    end
    notify("Nggak ada server yang cocok", true)
end

-- dipanggil dari unload(): balikin semua perubahan fitur v1.3
local function cleanupExtras()
    stopFly()
    applyFreeze(false)
    local _, hum = getChar()
    if hum and mods.jumpOrig then
        hum.UseJumpPower = mods.jumpOrig.use
        hum.JumpPower = mods.jumpOrig.power
    end
    restoreBody()
    if customSky then customSky:Destroy() customSky = nil end
    if colorCorrection then colorCorrection:Destroy() colorCorrection = nil end
    if gateTool then gateTool:Destroy() gateTool = nil end
    if config.zoom then applyZoom(false) end
    if config.lowGfx then applyLowGfx(false) end
    if config.fpsUnlock and setfpscap then setfpscap(60) end
end

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

-- ScrollingFrame: tampilan sama, tapi daftar tab bisa digeser (scroll / swipe)
local sidebar = make("ScrollingFrame", {
    Size = UDim2.new(0, 110, 1, 0),
    BackgroundColor3 = Color3.fromRGB(15, 15, 15),
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageTransparency = 0.5,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
}, body)
make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, sidebar)
make("UIPadding", {
    PaddingTop = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 10),
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
local function createCycle(parent, key, presets, labelFn, onChange)
    local btn = createButton(parent, labelFn(), function(b)
        local idx = table.find(presets, config[key]) or 0
        config[key] = presets[idx % #presets + 1]
        b.Text = labelFn()
        saveConfig()
        notify(labelFn())
        if onChange then onChange(config[key]) end
    end)
    syncers[key] = function()
        btn.Text = labelFn()
        if onChange then onChange(config[key]) end
    end
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
-- GUI: Slider (gaya sama kayak komponen lain, bisa digeser)
----------------------------------------------------------------
-- key = field di `config`; step = kelipatan nilai; onChange dipanggil saat geser
local function createSlider(parent, text, key, minV, maxV, step, onChange)
    step = step or 1
    local row = createRow(parent)
    row.Size = UDim2.new(1, 0, 0, 46)

    make("TextLabel", {
        Size = UDim2.new(1, -80, 0, 26),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local valueLabel = make("TextLabel", {
        Size = UDim2.new(0, 60, 0, 26),
        Position = UDim2.new(1, -70, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    local bar = make("Frame", {
        Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.new(0, 12, 0, 32),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderSizePixel = 0,
    }, row)
    corner(bar, 3)
    stroke(bar, 0.5)

    local fill = make("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = KNOB_ON_COLOR,
        BorderSizePixel = 0,
    }, bar)
    corner(fill, 3)

    local knob = make("Frame", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0, -6, 0.5, -6),
        BackgroundColor3 = KNOB_ON_COLOR,
        BorderSizePixel = 0,
    }, bar)
    corner(knob, 6)

    -- area sentuh lebih lebar dari bar-nya
    local hit = make("TextButton", {
        Size = UDim2.new(1, -12, 0, 22),
        Position = UDim2.new(0, 6, 0, 24),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local function paint()
        local t = math.clamp((config[key] - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(t, 0, 1, 0)
        knob.Position = UDim2.new(t, -6, 0.5, -6)
        valueLabel.Text = fmtNum(config[key])
    end

    local dragging = false
    local function setFromX(x)
        local w = bar.AbsoluteSize.X
        if w <= 0 then return end
        local t = math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1)
        local v = minV + (maxV - minV) * t
        v = math.clamp(math.floor(v / step + 0.5) * step, minV, maxV)
        if v ~= config[key] then
            config[key] = v
            paint()
            if onChange then onChange(v) end
        end
    end

    -- matikan scroll halaman selama slider digeser (biar nggak ikut ke-scroll di HP)
    local scroller = parent:IsA("ScrollingFrame") and parent or nil

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            if scroller then scroller.ScrollingEnabled = false end
            setFromX(input.Position.X)
        end
    end)
    track(UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end))
    track(UIS.InputEnded:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if scroller then scroller.ScrollingEnabled = true end
            saveConfig()
        end
    end))

    syncers[key] = function()
        paint()
        if onChange then onChange(config[key]) end
    end
    paint()
end

----------------------------------------------------------------
-- Unload
----------------------------------------------------------------
local function unload()
    unloaded = true
    cleanupExtras()
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

createSection(mainPage, "Generator")
createToggle(mainPage, "Auto Perfect Skill Check", "autoPerfect")
createInput(mainPage, "Lead Perfect (frame)", "autoLead", 0, 4)
createInfo(mainPage, "Otomatis menekan skill check saat jarum di zona perfect (varian trap dilewati). Pakai secukupnya.")

createSection(mainPage, "Vault")
createToggle(mainPage, "Fast Vault (Pallet & Window)", "fastVault")
createCycle(mainPage, "vaultSpeed", VAULT_PRESETS, function()
    return "Speed Vault: " .. string.format("%.1f", config.vaultSpeed) .. "x"
end)
createToggle(mainPage, "Info Vault (tier)", "vaultInfo")
createInfo(mainPage, "Fast Vault cuma mempercepat animasi (maks 3.0x). Vault tier FAST didapat kalau lari kencang dan lurus ke jendela.")

createSection(mainPage, "Karakter")
createToggle(mainPage, "Speed Karakter", "walkOn", walkStep)
createInput(mainPage, "Speed Sprint", "walkSpeed", 10, 30, walkStep)
createInfo(mainPage, "Ketik angka 10 - 30 lalu Enter (bawaan game 17). Aktif cuma saat sprint. Saran 18 - 20 biar aman dari anticheat.")

-- Tab: Player
local playerPage = createTab("Player")
createSection(playerPage, "Gerakan")
createToggle(playerPage, "Noclip", "noclip")
createToggle(playerPage, "Fly", "fly", function(s)
    if not s then stopFly() end
end)
createSlider(playerPage, "Fly Speed", "flySpeed", 20, 200, 5)
createToggle(playerPage, "Infinite Jump", "infJump")
createToggle(playerPage, "Jump Power", "jumpOn")
createSlider(playerPage, "Nilai Jump Power", "jumpPower", 30, 150, 5)
createSection(playerPage, "Karakter")
createToggle(playerPage, "Freeze Diri", "freeze", applyFreeze)
createToggle(playerPage, "Shift Lock", "shiftlock", applyShiftLock)
createInfo(playerPage, "Fly: joystick / WASD buat arah, Space naik, Ctrl turun. Noclip, Fly, Freeze, dan Gate Tool selalu mati lagi tiap script dijalankan ulang. Makin ekstrem makin gampang kena anticheat.")

-- Tab: Survivor
local survivorPage = createTab("Survivor")
createSection(survivorPage, "Escape")
createToggle(survivorPage, "Auto Escape (tiap 10 dtk)", "autoEscape")
createButton(survivorPage, "Instant Escape", function() instantEscape(false) end)
createToggle(survivorPage, "Gate Tool", "gateTool", setGateTool)
createButton(survivorPage, "Sacrifice Self", function() sacrificeSelf() end)
createSection(survivorPage, "Mekanik")
createToggle(survivorPage, "Auto Parry", "autoParry")
createToggle(survivorPage, "No Fall", "noFall", ensureHook)
createInfo(survivorPage, "Auto Parry butuh Parrying Dagger dan killer dalam 25 stud. Fitur di tab ini disusun dari remote game dan belum diuji, jadi kalau ada yang nggak jalan kabari errornya.")

-- Tab: Killer
local killerPage = createTab("Killer")
createSection(killerPage, "Serangan")
createToggle(killerPage, "Auto Slash", "autoSlash")
createCycle(killerPage, "slashMode", SLASH_MODES, function()
    return "Mode Slash: " .. config.slashMode
end)
createSection(killerPage, "Proteksi")
createToggle(killerPage, "Anti Blind", "antiBlind", ensureHook)
createToggle(killerPage, "Anti Stun", "antiStun")
createInfo(killerPage, "Cuma aktif kalau kamu Killer. Rage = serang tiap 0.1 dtk, Legit = sekali lalu jeda 2 dtk, Multi = sekali per target dalam jangkauan.")

-- Tab: ESP
local espPage = createTab("ESP")
createSection(espPage, "Player")
createToggle(espPage, "Aura Player", "aura", refreshAll)
createToggle(espPage, "Nama & Jarak", "name", refreshAll)
createSection(espPage, "Objek")
createToggle(espPage, "Generator", "generator", refreshObjs)
createToggle(espPage, "Progress Gen (%)", "genProgress", refreshGenAll)
createToggle(espPage, "Hook", "hook", refreshObjs)
createToggle(espPage, "Gate", "gate", refreshObjs)
createToggle(espPage, "Window / Vault", "vault", refreshObjs)
createInfo(espPage, "Putih = Survivor | Merah = Killer\nGenerator = ungu + bar progress % (merah > kuning > hijau), hilang kalau sudah beres.\nHook = merah muda | Gate = hijau | Window/Vault = biru muda.")

-- Tab: Visual
local visualPage = createTab("Visual")
createSection(visualPage, "Lingkungan")
createToggle(visualPage, "Fullbright", "fullbright", function(s)
    if not s then restoreKeys(FB_KEYS) end
end)
createToggle(visualPage, "No Fog", "nofog", function(s)
    if not s then restoreFog() end
end)

createSection(visualPage, "Waktu & Langit")
createToggle(visualPage, "Force Time", "forceTime", function(s)
    if not s then Lighting.ClockTime = lightOriginal.ClockTime end
end)
createSlider(visualPage, "Jam", "timeValue", 0, 24, 0.5)
createCycle(visualPage, "skybox", SKY_NAMES, function()
    return "Skybox: " .. config.skybox
end, applySky)
task.defer(applySky)

createSection(visualPage, "Warna")
createToggle(visualPage, "Saturation", "saturation", applySaturation)
createSlider(visualPage, "Nilai Saturation", "satValue", -1, 3, 0.1, applySaturation)

createSection(visualPage, "Body")
createToggle(visualPage, "Body Modifier", "bodyMod", function(s)
    if not s then restoreBody() end
end)
createCycle(visualPage, "bodyMaterial", BODY_MATERIALS, function()
    return "Material: " .. config.bodyMaterial
end)

-- Tab: Settings
local settingsPage = createTab("Settings")
createSection(settingsPage, "Umum")
createToggle(settingsPage, "Anti-AFK", "antiAfk")
createToggle(settingsPage, "Notifikasi", "notifications")
createToggle(settingsPage, "Debug Auto Perfect (console)", "autoDebug")

createSection(settingsPage, "ESP Objek")
createCycle(settingsPage, "distance", DISTANCE_PRESETS, function()
    return "Jarak Objek: " .. (config.distance == 0 and "Tanpa batas" or (config.distance .. " stud"))
end)

createSection(settingsPage, "Performance")
createToggle(settingsPage, "Disable Shadows", "noShadows", function(s)
    if not s then Lighting.GlobalShadows = lightOriginal.GlobalShadows end
end)
createToggle(settingsPage, "Lower Graphics", "lowGfx", applyLowGfx)
createToggle(settingsPage, "Unlimited Zoom", "zoom", applyZoom)
createToggle(settingsPage, "FPS Unlocker", "fpsUnlock", function(s)
    if setfpscap then
        setfpscap(s and config.fpsCap or 60)
    elseif s then
        notify("Executor nggak support setfpscap", true)
    end
end)
createCycle(settingsPage, "fpsCap", FPS_PRESETS, function()
    return "FPS Cap: " .. (config.fpsCap == 0 and "Unlimited" or tostring(config.fpsCap))
end, function()
    if config.fpsUnlock and setfpscap then setfpscap(config.fpsCap) end
end)
createToggle(settingsPage, "FPS Counter", "fpsCounter", function(s)
    fpsLabel.Visible = s
end)

createSection(settingsPage, "Server")
createButton(settingsPage, "Rejoin Server", function() rejoin() end)
createButton(settingsPage, "Serverhop (cari server kecil)", function() serverhop() end)

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
createInfo(settingsPage, "Toggle otomatis tersimpan.\nRightShift = show/hide panel (PC), tombol VD = show/hide (HP). Daftar tab di kiri dan isi tiap tab bisa digeser (scroll / swipe).\nBatas jarak membantu menghindari limit Highlight Roblox (~31).")

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
