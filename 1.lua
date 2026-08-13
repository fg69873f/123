-- ps
local Tabs         = _G.ZoltTabs
local Library      = _G.ZoltLibrary
local Options      = _G.ZoltOptions
local Toggles      = _G.ZoltToggles
local RunService   = _G.ZoltRunService    or game:GetService("RunService")
local TweenService = _G.ZoltTweenService  or game:GetService("TweenService")
local Debris       = _G.ZoltDebris        or game:GetService("Debris")
local _teams       = _G.ZoltTeams         or {}
local criminalsTeam = _teams.criminals
local guardsTeam    = _teams.guards
local inmatesTeam   = _teams.inmates

local framework = loadstring(request({
    Url = "https://raw.githubusercontent.com/412343214/.rip/refs/heads/main/framework.lua",
    Method = "Get"
}).Body)()({debug = false})

-- ═══════════════════════════════════════════════════════════════
-- MOBILE FIX: GUI inset компенсация
-- На мобиле Roblox рендерит Drawing поверх ViewportPoint-координат,
-- но сам ViewportPoint НЕ учитывает верхнюю панель (GuiInset).
-- Поэтому все Drawing-элементы смещаются вниз на inset.Y пикселей.
-- ═══════════════════════════════════════════════════════════════
local GuiService = game:GetService("GuiService")
local _insetTop = 0
local function _updateInset()
    local topLeft, _ = GuiService:GetGuiInset()
    _insetTop = topLeft.Y or 0
end
_updateInset()
-- обновляем каждые 5 секунд (топбар может грузиться с задержкой)
task.spawn(function()
    while true do
        task.wait(5)
        _updateInset()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ESP SETTINGS
-- ═══════════════════════════════════════════════════════════════
local esp = {}
esp.settings = {
    enabled   = false,
    maxdis    = 1000,
    teamcheck = false,
    box       = { enabled = false, outline = false, mode = "corner", color = Color3.fromRGB(255,255,255) },
    healthbar = { enabled = false, width = 3, outline = false },
    name      = { enabled = false, size = 13, outline = true, color = Color3.fromRGB(255,255,255) },
    distance  = { enabled = false, size = 13, outline = true, color = Color3.fromRGB(255,255,255) },
    weapon    = { enabled = false, size = 12, outline = true, color = Color3.fromRGB(255,0,0) },
}

esp.weapons_list = {
    "M9","Taser","MP5","M4A1","AK-47","FAL","Remington 870","EBR","M700","Revolver",
    "Crude Knife","Hammer","Breakfast","C4","Explosive","Dinner","Handcuffs","Key card","Lunch","Riot Shield","Pickaxe",
}
esp.localPlayer = game:GetService("Players").LocalPlayer

-- ═══════════════════════════════════════════════════════════════
-- WEAPON CACHE
-- ═══════════════════════════════════════════════════════════════
local _espWeaponCache = {}
local function _espUpdateWeapon(player)
    if not player or not player.Parent then _espWeaponCache[player] = "[none]"; return end
    local char = workspace:FindFirstChild(player.Name)
    if not char then _espWeaponCache[player] = "[none]"; return end
    for _, wn in ipairs(esp.weapons_list) do
        if char:FindFirstChild(wn) then _espWeaponCache[player] = "[" .. wn .. "]"; return end
        for _, item in ipairs(char:GetChildren()) do
            if string.find(item.Name:lower(), wn:lower()) then _espWeaponCache[player] = "[" .. wn .. "]"; return end
        end
    end
    _espWeaponCache[player] = "[none]"
end
local _espWeaponConns = {}
local function _espHookWeaponCache(player)
    if _espWeaponConns[player] then return end
    local char = workspace:FindFirstChild(player.Name); if not char then return end
    _espUpdateWeapon(player)
    _espWeaponConns[player] = {
        char.ChildAdded:Connect(function() _espUpdateWeapon(player) end),
        char.ChildRemoved:Connect(function() _espUpdateWeapon(player) end),
    }
end
function esp:getPlayerWeapon(player)
    if not _espWeaponCache[player] then _espUpdateWeapon(player) end
    return _espWeaponCache[player] or "[none]"
end

-- ═══════════════════════════════════════════════════════════════
-- DRAWING HELPERS
-- Используем только Square + Line + Text — они работают на всех
-- мобильных инжекторах (Delta, Arceus X). Quad не всегда есть.
-- ═══════════════════════════════════════════════════════════════
local function _newSquare(filled, color, thickness)
    local s = Drawing.new("Square")
    s.Visible   = false
    s.Filled    = filled or false
    s.Color     = color or Color3.fromRGB(255,255,255)
    s.Thickness = thickness or 1
    s.Transparency = 1
    return s
end

local function _newLine(color, thickness)
    local l = Drawing.new("Line")
    l.Visible   = false
    l.Color     = color or Color3.fromRGB(255,255,255)
    l.Thickness = thickness or 1
    l.Transparency = 1
    return l
end

local function _newText(color, size)
    local t = Drawing.new("Text")
    t.Visible      = false
    t.Color        = color or Color3.fromRGB(255,255,255)
    t.Size         = size or 13
    t.Center       = true
    t.Outline      = true
    t.OutlineColor = Color3.fromRGB(0,0,0)
    t.Text         = ""
    t.Transparency = 1
    return t
end

-- ═══════════════════════════════════════════════════════════════
-- DRAWING POOL
-- ═══════════════════════════════════════════════════════════════
local function _espInit(player)
    local d = {}
    -- Name / Distance / Weapon
    d.name     = _newText(Color3.fromRGB(255,255,255), 13)
    d.distance = _newText(Color3.fromRGB(255,255,255), 13)
    d.weapon   = _newText(Color3.fromRGB(255,0,0), 12)

    -- Full box (Square = 4 стороны)
    d.full_box         = _newSquare(false, Color3.fromRGB(255,255,255), 1)
    d.full_box_outline = _newSquare(false, Color3.fromRGB(0,0,0), 3)

    -- Corner box: 8 линий + 8 outline линий
    d.corner_box = {}
    for i = 1, 8  do d.corner_box[i] = _newLine(Color3.fromRGB(0,0,0), 3)   end  -- outline
    for i = 9, 16 do d.corner_box[i] = _newLine(Color3.fromRGB(255,255,255), 1) end  -- inner

    -- Health bar: bg (square filled) + fill (square filled) + outline
    d.hbar_bg      = _newSquare(true,  Color3.fromRGB(0,0,0),   1)
    d.hbar_fill    = _newSquare(true,  Color3.fromRGB(0,255,0), 1)
    d.hbar_outline = _newSquare(false, Color3.fromRGB(0,0,0),   1)
    return d
end

local function _espHide(d)
    if not d then return end
    d.name.Visible=false; d.distance.Visible=false; d.weapon.Visible=false
    d.full_box.Visible=false; d.full_box_outline.Visible=false
    d.hbar_bg.Visible=false; d.hbar_fill.Visible=false; d.hbar_outline.Visible=false
    for _, l in ipairs(d.corner_box) do l.Visible=false end
end

local function _espCleanDrawings(d)
    if not d then return end
    local function sr(o) pcall(function() o:Remove() end) end
    sr(d.name); sr(d.distance); sr(d.weapon)
    sr(d.full_box); sr(d.full_box_outline)
    sr(d.hbar_bg); sr(d.hbar_fill); sr(d.hbar_outline)
    for _, l in ipairs(d.corner_box) do sr(l) end
end

local _espPools = {}  -- [player] = drawing table

-- ═══════════════════════════════════════════════════════════════
-- BOUNDING BOX
-- ═══════════════════════════════════════════════════════════════
local BODY_PARTS = {"Head","HumanoidRootPart","Left Arm","Left Leg","Right Arm","Right Leg","Torso"}

local function _getBounds(char, cam, insetY)
    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOn = false

    for _, name in ipairs(BODY_PARTS) do
        local part = char:FindFirstChild(name)
        if not part or not part:IsA("BasePart") then continue end
        local cf, sz = part.CFrame, part.Size
        local hx, hy, hz = sz.X/2, sz.Y/2, sz.Z/2
        for sx = -1, 1, 2 do
            for sy = -1, 1, 2 do
                for sz2 = -1, 1, 2 do
                    local corner = (cf * CFrame.new(hx*sx, hy*sy, hz*sz2)).Position
                    local s = cam:WorldToViewportPoint(corner)
                    if s.Z > 0 then
                        anyOn = true
                        -- MOBILE FIX: добавляем insetY чтобы компенсировать топбар
                        local sy_fixed = s.Y + insetY
                        if s.X  < minX then minX = s.X        end
                        if sy_fixed < minY then minY = sy_fixed end
                        if s.X  > maxX then maxX = s.X        end
                        if sy_fixed > maxY then maxY = sy_fixed end
                    end
                end
            end
        end
    end

    return anyOn, minX, minY, maxX, maxY
end

-- ═══════════════════════════════════════════════════════════════
-- DRAW HELPERS (Square-based)
-- ═══════════════════════════════════════════════════════════════
local V2 = Vector2.new

local function _drawFullBox(d, x0, y0, x1, y1, color, outlineOn)
    local w, h = x1-x0, y1-y0
    if outlineOn then
        local ob = d.full_box_outline
        ob.Position = V2(x0-1, y0-1); ob.Size = V2(w+2, h+2)
        ob.Color = Color3.fromRGB(0,0,0); ob.Thickness = 3
        ob.Filled = false; ob.Visible = true
    else d.full_box_outline.Visible = false end

    local fb = d.full_box
    fb.Position = V2(x0, y0); fb.Size = V2(w, h)
    fb.Color = color; fb.Thickness = 1
    fb.Filled = false; fb.Visible = true

    for _, l in ipairs(d.corner_box) do l.Visible = false end
end

local function _drawCornerBox(d, x0, y0, x1, y1, color, outlineOn)
    d.full_box.Visible = false; d.full_box_outline.Visible = false
    local w, h = x1-x0, y1-y0
    local len = math.clamp(math.min(w,h)*0.25, 3, 14)
    local cb  = d.corner_box

    -- сегменты: [From, To, isHorizontal]
    local segs = {
        {V2(x0,y0),       V2(x0+len, y0),   true},   -- TL horiz
        {V2(x0,y0),       V2(x0, y0+len),   false},  -- TL vert
        {V2(x1,y0),       V2(x1-len, y0),   true},   -- TR horiz
        {V2(x1,y0),       V2(x1, y0+len),   false},  -- TR vert
        {V2(x0,y1),       V2(x0+len, y1),   true},   -- BL horiz
        {V2(x0,y1),       V2(x0, y1-len),   false},  -- BL vert
        {V2(x1,y1),       V2(x1-len, y1),   true},   -- BR horiz
        {V2(x1,y1),       V2(x1, y1-len),   false},  -- BR vert
    }

    for i = 1, 8 do
        local seg = segs[i]
        local isH = seg[3]
        -- outline линия
        local ol = cb[i]
        if outlineOn then
            if isH then
                ol.From = V2(seg[1].X, seg[1].Y-1); ol.To = V2(seg[2].X, seg[2].Y-1)
            else
                ol.From = V2(seg[1].X-1, seg[1].Y); ol.To = V2(seg[2].X-1, seg[2].Y)
            end
            ol.Color = Color3.fromRGB(0,0,0); ol.Thickness = 3; ol.Visible = true
        else ol.Visible = false end
        -- inner линия
        local il = cb[i+8]
        il.From = seg[1]; il.To = seg[2]
        il.Color = color; il.Thickness = 1; il.Visible = true
    end
end

local function _drawHealthBar(d, x0, y0, x1, y1, hum, bw, outlineOn)
    local pct = hum.MaxHealth > 0 and math.clamp(hum.Health/hum.MaxHealth,0,1) or 0
    local h   = y1 - y0
    local fh  = h * pct
    local x   = x0 - (bw + 3)
    local r   = math.clamp(1-pct,0,1); local g = math.clamp(pct,0,1)

    local bg = d.hbar_bg
    bg.Position = V2(x, y0); bg.Size = V2(bw, h)
    bg.Color = Color3.fromRGB(0,0,0); bg.Filled = true; bg.Visible = true

    local fi = d.hbar_fill
    fi.Position = V2(x, y0 + (h-fh)); fi.Size = V2(bw, math.max(fh,1))
    fi.Color = Color3.new(r,g,0); fi.Filled = true; fi.Visible = true

    local ol = d.hbar_outline
    if outlineOn then
        ol.Position = V2(x-1, y0-1); ol.Size = V2(bw+2, h+2)
        ol.Color = Color3.fromRGB(0,0,0); ol.Filled = false; ol.Thickness = 1; ol.Visible = true
    else ol.Visible = false end
end

-- ═══════════════════════════════════════════════════════════════
-- RENDER LOOP
-- ═══════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    pcall(function()
        local insetY = _insetTop   -- GUI inset для мобилы

        if not esp.settings.enabled then
            for _, d in pairs(_espPools) do _espHide(d) end
            return
        end

        local cam       = workspace.CurrentCamera
        local lp        = esp.localPlayer
        local localChar = framework.character
        local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

        if not localRoot then
            for _, d in pairs(_espPools) do _espHide(d) end
            return
        end

        -- инициализируем пулы для новых игроков
        for player, _ in pairs(framework.players) do
            if player ~= lp and not _espPools[player] then
                _espPools[player] = _espInit(player)
            end
        end

        for player, data in pairs(framework.players) do
            if player == lp then continue end

            local d = _espPools[player]
            if not d then d = _espInit(player); _espPools[player] = d end

            if not data.spawned or not data.character or not data.root then
                _espHide(d); continue
            end

            if esp.settings.teamcheck and player.Team == lp.Team then _espHide(d); continue end

            local char = data.character
            local root = data.root
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then _espHide(d); continue end

            local dist = (root.Position - localRoot.Position).Magnitude / 3
            if esp.settings.maxdis == 0 or dist > esp.settings.maxdis then _espHide(d); continue end

            if not _espWeaponConns[player] then _espHookWeaponCache(player) end

            local anyOn, x0, y0, x1, y1 = _getBounds(char, cam, insetY)
            if not anyOn then _espHide(d); continue end

            local w, h = x1-x0, y1-y0
            if h <= 1 then _espHide(d); continue end

            x0 = math.floor(x0); y0 = math.floor(y0)
            x1 = math.floor(x1); y1 = math.floor(y1)
            local cx = math.floor((x0+x1)*0.5)

            -- BOX
            if esp.settings.box.enabled then
                if esp.settings.box.mode == "full" then
                    _drawFullBox(d, x0, y0, x1, y1, esp.settings.box.color, esp.settings.box.outline)
                else
                    _drawCornerBox(d, x0, y0, x1, y1, esp.settings.box.color, esp.settings.box.outline)
                end
            else
                d.full_box.Visible=false; d.full_box_outline.Visible=false
                for _, l in ipairs(d.corner_box) do l.Visible=false end
            end

            -- HEALTH BAR
            if esp.settings.healthbar.enabled then
                _drawHealthBar(d, x0, y0, x1, y1, hum, esp.settings.healthbar.width, esp.settings.healthbar.outline)
            else
                d.hbar_bg.Visible=false; d.hbar_fill.Visible=false; d.hbar_outline.Visible=false
            end

            -- NAME (над боксом)
            if esp.settings.name.enabled then
                local t = d.name
                t.Text    = player.Name
                t.Size    = esp.settings.name.size
                t.Color   = esp.settings.name.color
                t.Outline = esp.settings.name.outline
                t.Position = V2(cx, y0 - esp.settings.name.size - 2)
                t.Visible = true
            else d.name.Visible = false end

            -- DISTANCE (справа от бокса)
            if esp.settings.distance.enabled then
                local t = d.distance
                t.Text    = math.round(dist) .. "m"
                t.Size    = esp.settings.distance.size
                t.Color   = esp.settings.distance.color
                t.Outline = esp.settings.distance.outline
                t.Position = V2(x1 + 4, y0)
                t.Visible = true
            else d.distance.Visible = false end

            -- WEAPON (под боксом)
            if esp.settings.weapon.enabled then
                local t = d.weapon
                t.Text    = esp:getPlayerWeapon(player)
                t.Size    = esp.settings.weapon.size
                t.Color   = esp.settings.weapon.color
                t.Outline = esp.settings.weapon.outline
                t.Position = V2(cx, y1 + 2)
                t.Visible = true
            else d.weapon.Visible = false end
        end

        -- чистим ушедших игроков
        for player, d in pairs(_espPools) do
            if not framework.players[player] then
                _espCleanDrawings(d); _espPools[player] = nil
            end
        end
    end)
end)

-- playeradded/removing
table.insert(framework.connec_funcs["playeradded"], function(player)
    task.wait(0.5)
    if player ~= esp.localPlayer then
        _espPools[player] = _espInit(player)
        _espHookWeaponCache(player)
    end
end)
table.insert(framework.connec_funcs["playerremoving"], function(player)
    if _espPools[player] then _espCleanDrawings(_espPools[player]); _espPools[player] = nil end
    _espWeaponCache[player] = nil
    if _espWeaponConns[player] then
        for _, c in pairs(_espWeaponConns[player]) do pcall(function() c:Disconnect() end) end
        _espWeaponConns[player] = nil
    end
end)

-- инит для уже существующих игроков
for _, p in pairs(game:GetService("Players"):GetPlayers()) do
    if p ~= esp.localPlayer then _espPools[p] = _espInit(p) end
end

-- ═══════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════
local EspMainGroup = Tabs.Visuals:AddLeftGroupbox("ESP", "eye", {Collapsible=true})
local EspBoxGroup  = Tabs.Visuals:AddRightGroupbox("Box", "square", {Collapsible=true})

EspMainGroup:AddToggle("EnableESP",{Text="Enable ESP",Default=false,
    Callback=function(v)
        esp.settings.enabled=v
        if not v then _chamsEnabled=false; _chamsCleanAll() end
    end})
EspMainGroup:AddToggle("ESPTeamCheck",{Text="Team Check",Default=false,
    Callback=function(v) esp.settings.teamcheck=v end})
EspMainGroup:AddDivider()
EspMainGroup:AddSlider("MaxDistance",{Text="Max Distance",Default=1000,Min=0,Max=1000,Rounding=0,Suffix=" m",
    Callback=function(v) esp.settings.maxdis=v end})
EspMainGroup:AddSlider("HealthbarWidth",{Text="Bar Width",Default=3,Min=1,Max=10,Rounding=1,
    Callback=function(v) esp.settings.healthbar.width=v end})
EspMainGroup:AddDivider()

local NameToggle=EspMainGroup:AddToggle("NameEnabled",{Text="Name",Default=false,
    Callback=function(v) esp.settings.name.enabled=v end})
NameToggle:AddColorPicker("NameColor",{Default=Color3.fromRGB(255,255,255),Title="Name Color",
    Callback=function(v) esp.settings.name.color=v end})

local DistToggle=EspMainGroup:AddToggle("DistanceEnabled",{Text="Distance",Default=false,
    Callback=function(v) esp.settings.distance.enabled=v end})
DistToggle:AddColorPicker("DistanceColor",{Default=Color3.fromRGB(255,255,255),Title="Distance Color",
    Callback=function(v) esp.settings.distance.color=v end})

local WeaponToggle=EspMainGroup:AddToggle("WeaponEnabled",{Text="Weapon",Default=false,
    Callback=function(v) esp.settings.weapon.enabled=v end})
WeaponToggle:AddColorPicker("WeaponColor",{Default=Color3.fromRGB(255,0,0),Title="Weapon Color",
    Callback=function(v) esp.settings.weapon.color=v end})

EspMainGroup:AddToggle("HealthbarEnabled",{Text="Health bar",Default=false,
    Callback=function(v) esp.settings.healthbar.enabled=v end})
EspMainGroup:AddToggle("HealthbarOutline",{Text="Outline",Default=false,
    Callback=function(v) esp.settings.healthbar.outline=v end})

local BoxToggle=EspBoxGroup:AddToggle("BoxEnabled",{Text="Box",Default=false,
    Callback=function(v) esp.settings.box.enabled=v end})
BoxToggle:AddColorPicker("BoxColor",{Default=Color3.fromRGB(255,255,255),Title="Box Color",
    Callback=function(v) esp.settings.box.color=v end})
EspBoxGroup:AddToggle("BoxOutline",{Text="Outline",Default=false,
    Callback=function(v) esp.settings.box.outline=v end})
EspBoxGroup:AddDropdown("BoxMode",{Values={"corner","full"},Default="corner",Text="Box Mode",
    Callback=function(v) esp.settings.box.mode=v end})

-- ═══════════════════════════════════════════════════════════════
-- CHAMS (без изменений)
-- ═══════════════════════════════════════════════════════════════
local _chamsEnabled             = false
local _teamChamsOn              = false
local _chamsVisibleColor        = Color3.fromRGB(0, 200, 255)
local _chamsOutlineColor        = Color3.fromRGB(255, 255, 255)
local _chamsOccludedColor       = Color3.fromRGB(255, 40, 40)
local _chamsFillTransparency    = 0.5
local _chamsOutlineTransparency = 1
local _chamsCriminals           = Color3.fromRGB(255, 60, 60)
local _chamsGuards              = Color3.fromRGB(60, 120, 255)
local _chamsInmates             = Color3.fromRGB(255, 165, 0)

local function _chamsGetColors(player)
    local visCol = _chamsVisibleColor
    local occCol = _chamsOccludedColor
    if _teamChamsOn then
        local tm = player.Team
        if tm == criminalsTeam then visCol = _chamsCriminals; occCol = _chamsCriminals
        elseif tm == guardsTeam then visCol = _chamsGuards; occCol = _chamsGuards
        elseif tm == inmatesTeam then visCol = _chamsInmates; occCol = _chamsInmates end
    end
    return visCol, occCol
end

local function _chamsSkip(player)
    if esp.settings.teamcheck and player.Team == game.Players.LocalPlayer.Team then return true end
    return false
end

local function _chamsAddHighlight(char, visibleColor, occludedColor)
    if char:FindFirstChild("ChamsHighlight_Visible") then return end
    local hOcc = Instance.new("Highlight")
    hOcc.Name="ChamsHighlight_Occluded"; hOcc.FillColor=occludedColor; hOcc.OutlineColor=_chamsOutlineColor
    hOcc.FillTransparency=_chamsFillTransparency; hOcc.OutlineTransparency=_chamsOutlineTransparency
    hOcc.DepthMode=Enum.HighlightDepthMode.Occluded; hOcc.Adornee=char; hOcc.Parent=char
    local hVis = Instance.new("Highlight")
    hVis.Name="ChamsHighlight_Visible"; hVis.FillColor=visibleColor; hVis.OutlineColor=_chamsOutlineColor
    hVis.FillTransparency=_chamsFillTransparency; hVis.OutlineTransparency=_chamsOutlineTransparency
    hVis.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hVis.Adornee=char; hVis.Parent=char
end

local function _chamsRemoveHighlight(char)
    if not char then return end
    local h = char:FindFirstChild("ChamsHighlight_Visible"); if h then h:Destroy() end
    local h2 = char:FindFirstChild("ChamsHighlight_Occluded"); if h2 then h2:Destroy() end
end

local function _chamsCleanAll()
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr.Character then _chamsRemoveHighlight(plr.Character) end
    end
end

local _chamsCharConns = {}
local function _chamsHookPlayer(plr)
    if _chamsCharConns[plr] then return end
    if plr.Character then
        if _chamsEnabled and not _chamsSkip(plr) then
            local vis, occ = _chamsGetColors(plr)
            _chamsAddHighlight(plr.Character, vis, occ)
        end
    end
    _chamsCharConns[plr] = plr.CharacterAdded:Connect(function(char)
        pcall(function()
            if not _chamsEnabled or _chamsSkip(plr) then return end
            local vis, occ = _chamsGetColors(plr)
            _chamsAddHighlight(char, vis, occ)
        end)
    end)
end

for _, plr in pairs(game:GetService("Players"):GetPlayers()) do
    if plr ~= game.Players.LocalPlayer then pcall(function() _chamsHookPlayer(plr) end) end
end
game.Players.PlayerAdded:Connect(function(plr)
    if plr ~= game.Players.LocalPlayer then pcall(function() _chamsHookPlayer(plr) end) end
end)
game.Players.PlayerRemoving:Connect(function(plr)
    if _chamsCharConns[plr] then _chamsCharConns[plr]:Disconnect(); _chamsCharConns[plr] = nil end
end)

RunService.Heartbeat:Connect(function()
    pcall(function()
        local lp = game.Players.LocalPlayer
        for player, data in pairs(framework.players) do
            if player == lp then continue end
            local char = data.character; if not char then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then _chamsRemoveHighlight(char); continue end
            local withinRange = false
            if _chamsEnabled and framework.character then
                local localRoot = framework.character:FindFirstChild("HumanoidRootPart")
                if localRoot and data.root then
                    local dist = (data.root.Position - localRoot.Position).Magnitude / 3
                    if esp.settings.maxdis > 0 and dist <= esp.settings.maxdis then withinRange = true end
                end
            end
            if not _chamsEnabled or _chamsSkip(player) or not withinRange then
                _chamsRemoveHighlight(char)
            else
                local hVis = char:FindFirstChild("ChamsHighlight_Visible")
                local hOcc = char:FindFirstChild("ChamsHighlight_Occluded")
                local visCol, occCol = _chamsGetColors(player)
                if not hVis or not hOcc then
                    _chamsAddHighlight(char, visCol, occCol)
                else
                    if hVis.FillColor~=visCol then hVis.FillColor=visCol end
                    if hVis.OutlineColor~=_chamsOutlineColor then hVis.OutlineColor=_chamsOutlineColor end
                    if hVis.FillTransparency~=_chamsFillTransparency then hVis.FillTransparency=_chamsFillTransparency end
                    if hVis.OutlineTransparency~=_chamsOutlineTransparency then hVis.OutlineTransparency=_chamsOutlineTransparency end
                    if hOcc.FillColor~=occCol then hOcc.FillColor=occCol end
                    if hOcc.OutlineColor~=_chamsOutlineColor then hOcc.OutlineColor=_chamsOutlineColor end
                    if hOcc.FillTransparency~=_chamsFillTransparency then hOcc.FillTransparency=_chamsFillTransparency end
                    if hOcc.OutlineTransparency~=_chamsOutlineTransparency then hOcc.OutlineTransparency=_chamsOutlineTransparency end
                end
            end
        end
    end)
end)

local ChamsGroup = Tabs.Visuals:AddLeftGroupbox("Chams", "layers", {Collapsible=true})
ChamsGroup:AddToggle("ChamsEnabled",{Text="Enable Chams",Default=false,
    Callback=function(v) _chamsEnabled=v; if not v then _chamsCleanAll() end end})
ChamsGroup:AddLabel("Visible Color"):AddColorPicker("ChamsVisibleColor",{Default=Color3.fromRGB(0,200,255),Title="Visible Color",
    Callback=function(v) _chamsVisibleColor=v end})
ChamsGroup:AddLabel("Occluded Color"):AddColorPicker("ChamsOccludedColor",{Default=Color3.fromRGB(255,40,40),Title="Occluded Color",
    Callback=function(v) _chamsOccludedColor=v end})
ChamsGroup:AddSlider("FillTransparency",{Text="Fill Transparency",Default=0.5,Min=0,Max=1,Rounding=2,
    Callback=function(v) _chamsFillTransparency=v end})
ChamsGroup:AddSlider("OutlineTransparency",{Text="Outline Transparency",Default=1,Min=0,Max=1,Rounding=2,
    Callback=function(v) _chamsOutlineTransparency=v end})
ChamsGroup:AddDivider()
ChamsGroup:AddToggle("TeamChamsEnabled",{Text="Team Chams",Default=false,
    Callback=function(v) _teamChamsOn=v end})
ChamsGroup:AddLabel("Criminals"):AddColorPicker("ChamsCriminals",{Default=Color3.fromRGB(255,60,60),Title="Criminals",
    Callback=function(v) _chamsCriminals=v end})
ChamsGroup:AddLabel("Guards"):AddColorPicker("ChamsGuards",{Default=Color3.fromRGB(60,120,255),Title="Guards",
    Callback=function(v) _chamsGuards=v end})
ChamsGroup:AddLabel("Inmates"):AddColorPicker("ChamsInmates",{Default=Color3.fromRGB(255,165,0),Title="Inmates",
    Callback=function(v) _chamsInmates=v end})
