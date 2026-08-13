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
-- ESP SETTINGS
-- ═══════════════════════════════════════════════════════════════
local esp = {}
esp.settings = {
    enabled   = false,
    maxdis    = 1000,
    teamcheck = false,
    box       = { enabled = false, outline = true, mode = "corner", color = Color3.fromRGB(255,255,255) },
    healthbar = { enabled = false, width = 3, outline = true },
    name      = { enabled = false, size = 13, outline = true, color = Color3.fromRGB(255,255,255) },
    distance  = { enabled = false, size = 13, outline = true, color = Color3.fromRGB(200,200,200) },
    weapon    = { enabled = false, size = 12, outline = true, color = Color3.fromRGB(255,0,0) },
}

esp.weapons_list = {
    "M9","Taser","MP5","M4A1","AK-47","FAL","Remington 870","EBR","M700","Revolver",
    "Crude Knife","Hammer","Breakfast","C4","Explosive","Dinner","Handcuffs","Key card","Lunch","Riot Shield","Pickaxe",
}
esp.localPlayer = game:GetService("Players").LocalPlayer

-- ═══════════════════════════════════════════════════════════════
-- WEAPON CACHE (original logic, untouched)
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
-- DRAWING POOL (juanita-style: Square + Line, reuse per player)
-- ═══════════════════════════════════════════════════════════════
local clamp = math.clamp

local function _newSquare(filled)
    local s = Drawing.new("Square")
    s.Filled    = filled or false
    s.Thickness = 1
    s.Visible   = false
    return s
end

local function _newLine()
    local l = Drawing.new("Line")
    l.Thickness = 1
    l.Visible   = false
    return l
end

local function _newText()
    local t = Drawing.new("Text")
    t.Size    = 13
    t.Center  = true
    t.Outline = true
    t.Visible = false
    t.Text    = ""
    return t
end

-- 8 colored corner segments + 16 outline segments (2 per segment)
local function _createPool()
    local p = {}

    -- full box: outer outline / inner outline / colored box
    p.BoxOutline      = _newSquare(false)
    p.BoxInnerOutline = _newSquare(false)
    p.Box             = _newSquare(false)

    -- corner box: 16 outline lines + 8 colored lines
    p.CornerOutlines = {}
    p.Corners        = {}
    for i = 1, 16 do p.CornerOutlines[i] = _newLine() end
    for i = 1,  8 do p.Corners[i]        = _newLine() end

    -- health bar: outline / bg / fill
    p.HealthOutline = _newSquare(false)
    p.HealthBg      = _newSquare(true)
    p.HealthFill    = _newSquare(true)

    -- texts
    p.Name     = _newText()
    p.Distance = _newText()
    p.Weapon   = _newText()

    -- smoothed health for tween effect
    p.HealthRatio = 1

    return p
end

local function _hidePool(p)
    p.BoxOutline.Visible      = false
    p.BoxInnerOutline.Visible = false
    p.Box.Visible             = false
    for i = 1, 16 do p.CornerOutlines[i].Visible = false end
    for i = 1,  8 do p.Corners[i].Visible        = false end
    p.HealthOutline.Visible = false
    p.HealthBg.Visible      = false
    p.HealthFill.Visible    = false
    p.Name.Visible          = false
    p.Distance.Visible      = false
    p.Weapon.Visible        = false
end

local function _removePool(p)
    if not p then return end
    local function sr(o) pcall(function() o:Remove() end) end
    sr(p.BoxOutline); sr(p.BoxInnerOutline); sr(p.Box)
    for i = 1, 16 do sr(p.CornerOutlines[i]) end
    for i = 1,  8 do sr(p.Corners[i]) end
    sr(p.HealthOutline); sr(p.HealthBg); sr(p.HealthFill)
    sr(p.Name); sr(p.Distance); sr(p.Weapon)
end

local _espDrawings = {}

local function _espInit(player)
    if not player or player == esp.localPlayer then return end
    if _espDrawings[player] then _removePool(_espDrawings[player]) end
    _espDrawings[player] = _createPool()
end

local function _espClean(player)
    _removePool(_espDrawings[player])
    _espDrawings[player] = nil
end

-- ═══════════════════════════════════════════════════════════════
-- BOX DRAWERS
-- ═══════════════════════════════════════════════════════════════
local V2 = Vector2.new
local C3 = Color3.new

local function _drawFullBox(p, minX, minY, maxX, maxY, color, outlineOn)
    local w = maxX - minX
    local h = maxY - minY

    if outlineOn then
        p.BoxOutline.Position  = V2(minX - 1, minY - 1)
        p.BoxOutline.Size      = V2(w + 2, h + 2)
        p.BoxOutline.Color     = C3(0,0,0)
        p.BoxOutline.Thickness = 1
        p.BoxOutline.Filled    = false
        p.BoxOutline.Visible   = true

        if w > 2 and h > 2 then
            p.BoxInnerOutline.Position  = V2(minX + 1, minY + 1)
            p.BoxInnerOutline.Size      = V2(w - 2, h - 2)
            p.BoxInnerOutline.Color     = C3(0,0,0)
            p.BoxInnerOutline.Thickness = 1
            p.BoxInnerOutline.Filled    = false
            p.BoxInnerOutline.Visible   = true
        else
            p.BoxInnerOutline.Visible = false
        end
    else
        p.BoxOutline.Visible      = false
        p.BoxInnerOutline.Visible = false
    end

    p.Box.Position  = V2(minX, minY)
    p.Box.Size      = V2(w, h)
    p.Box.Color     = color
    p.Box.Thickness = 1
    p.Box.Filled    = false
    p.Box.Visible   = true

    for i = 1, 8  do p.Corners[i].Visible        = false end
    for i = 1, 16 do p.CornerOutlines[i].Visible = false end
end

local function _drawCornerBox(p, minX, minY, maxX, maxY, color, outlineOn)
    p.Box.Visible             = false
    p.BoxOutline.Visible      = false
    p.BoxInnerOutline.Visible = false

    local w   = maxX - minX
    local h   = maxY - minY
    local len = clamp(math.min(w, h) * 0.28, 3, 14)

    local pts = {
        { V2(minX, minY),        V2(minX + len, minY) },
        { V2(minX, minY),        V2(minX, minY + len) },
        { V2(maxX, minY),        V2(maxX - len, minY) },
        { V2(maxX, minY),        V2(maxX, minY + len) },
        { V2(minX, maxY),        V2(minX + len, maxY) },
        { V2(minX, maxY),        V2(minX, maxY - len) },
        { V2(maxX, maxY),        V2(maxX - len, maxY) },
        { V2(maxX, maxY),        V2(maxX, maxY - len) },
    }

    for i = 1, 8 do
        local seg  = pts[i]
        local line = p.Corners[i]
        local out1 = p.CornerOutlines[i * 2 - 1]
        local out2 = p.CornerOutlines[i * 2]

        if outlineOn then
            local isHoriz = (i % 2 == 1)
            if isHoriz then
                out1.From = V2(seg[1].X, seg[1].Y - 1); out1.To = V2(seg[2].X, seg[2].Y - 1)
                out2.From = V2(seg[1].X, seg[1].Y + 1); out2.To = V2(seg[2].X, seg[2].Y + 1)
            else
                out1.From = V2(seg[1].X - 1, seg[1].Y); out1.To = V2(seg[2].X - 1, seg[2].Y)
                out2.From = V2(seg[1].X + 1, seg[1].Y); out2.To = V2(seg[2].X + 1, seg[2].Y)
            end
            out1.Color = C3(0,0,0); out1.Thickness = 1; out1.Visible = true
            out2.Color = C3(0,0,0); out2.Thickness = 1; out2.Visible = true
        else
            out1.Visible = false
            out2.Visible = false
        end

        line.From      = seg[1]
        line.To        = seg[2]
        line.Color     = color
        line.Thickness = 1
        line.Visible   = true
    end
end

-- ═══════════════════════════════════════════════════════════════
-- HEALTH BAR (vertical, left of box)
-- ═══════════════════════════════════════════════════════════════
local function _drawHealthBar(p, minX, minY, maxX, maxY, ratio, bw, outlineOn)
    local h  = maxY - minY
    local fh = h * ratio
    local x  = minX - (bw + 3)

    -- background
    p.HealthBg.Position     = V2(x, minY)
    p.HealthBg.Size         = V2(bw, h)
    p.HealthBg.Color        = C3(0,0,0)
    p.HealthBg.Filled       = true
    p.HealthBg.Transparency = 0.4
    p.HealthBg.Visible      = true

    -- fill (bottom-anchored, grows upward)
    local r = clamp(1 - ratio, 0, 1)
    local g = clamp(ratio, 0, 1)
    p.HealthFill.Position     = V2(x, minY + (h - fh))
    p.HealthFill.Size         = V2(bw, fh)
    p.HealthFill.Color        = C3(r, g, 0)
    p.HealthFill.Filled       = true
    p.HealthFill.Transparency = 0
    p.HealthFill.Visible      = true

    -- outline
    if outlineOn then
        p.HealthOutline.Position  = V2(x - 1, minY - 1)
        p.HealthOutline.Size      = V2(bw + 2, h + 2)
        p.HealthOutline.Color     = C3(0,0,0)
        p.HealthOutline.Filled    = false
        p.HealthOutline.Thickness = 1
        p.HealthOutline.Visible   = true
    else
        p.HealthOutline.Visible = false
    end
end

-- ═══════════════════════════════════════════════════════════════
-- BOUNDING BOX CALCULATION (juanita: per-part corner projection)
-- ═══════════════════════════════════════════════════════════════
local BODY_PARTS_R6 = {
    "Head","HumanoidRootPart",
    "Left Arm","Left Leg","Right Arm","Right Leg","Torso"
}

local function _getBounds(char, cam)
    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOn = false

    for _, partName in ipairs(BODY_PARTS_R6) do
        local part = char:FindFirstChild(partName)
        if not part or not part:IsA("BasePart") then continue end
        local cf, sz = part.CFrame, part.Size
        local hx, hy, hz = sz.X/2, sz.Y/2, sz.Z/2
        for sx = -1, 1, 2 do
            for sy = -1, 1, 2 do
                for sz2 = -1, 1, 2 do
                    local corner = (cf * CFrame.new(hx*sx, hy*sy, hz*sz2)).Position
                    local screen, _, on = cam:WorldToViewportPoint(corner)
                    if on then anyOn = true end
                    if screen.X < minX then minX = screen.X end
                    if screen.Y < minY then minY = screen.Y end
                    if screen.X > maxX then maxX = screen.X end
                    if screen.Y > maxY then maxY = screen.Y end
                end
            end
        end
    end

    return anyOn, minX, minY, maxX, maxY
end

-- ═══════════════════════════════════════════════════════════════
-- RENDER LOOP
-- ═══════════════════════════════════════════════════════════════
game:GetService("RunService").Heartbeat:Connect(function(dt)
    pcall(function()
        if not esp.settings.enabled then
            for player in pairs(_espDrawings) do
                local p = _espDrawings[player]
                if p then _hidePool(p) end
            end
            return
        end

        local cam        = workspace.CurrentCamera
        local lp         = esp.localPlayer
        local localChar  = lp.Character
        local localRoot  = localChar and localChar:FindFirstChild("HumanoidRootPart")

        if not localRoot then
            for player in pairs(_espDrawings) do
                local p = _espDrawings[player]
                if p then _hidePool(p) end
            end
            return
        end

        for player, pool in pairs(_espDrawings) do
            if not player or not player.Parent then _hidePool(pool); continue end

            -- TEAM CHECK (original logic, untouched)
            if esp.settings.teamcheck and player.Team == lp.Team then _hidePool(pool); continue end

            local char = player.Character
            if not char then _hidePool(pool); continue end
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not root or not hum or hum.Health <= 0 then _hidePool(pool); continue end

            local dist = (root.Position - localRoot.Position).Magnitude / 3
            if esp.settings.maxdis == 0 or dist > esp.settings.maxdis then _hidePool(pool); continue end

            -- weapon hook (original)
            if not _espWeaponConns[player] then _espHookWeaponCache(player) end

            -- bounding box (juanita per-corner projection)
            local anyOn, minX, minY, maxX, maxY = _getBounds(char, cam)
            if not anyOn then _hidePool(pool); continue end

            local w = maxX - minX
            local h = maxY - minY
            if h <= 1 then _hidePool(pool); continue end

            local cx  = math.floor((minX + maxX) * 0.5)
            local outlineOn = esp.settings.box.outline
            local boxColor  = esp.settings.box.color

            -- ── BOX ──────────────────────────────────────────
            if esp.settings.box.enabled then
                if esp.settings.box.mode == "full" then
                    _drawFullBox(pool, minX, minY, maxX, maxY, boxColor, outlineOn)
                else
                    _drawCornerBox(pool, minX, minY, maxX, maxY, boxColor, outlineOn)
                end
            else
                pool.Box.Visible             = false
                pool.BoxOutline.Visible      = false
                pool.BoxInnerOutline.Visible = false
                for i = 1, 8  do pool.Corners[i].Visible        = false end
                for i = 1, 16 do pool.CornerOutlines[i].Visible = false end
            end

            -- ── HEALTH BAR ───────────────────────────────────
            if esp.settings.healthbar.enabled then
                local realRatio = clamp(hum.Health / hum.MaxHealth, 0, 1)
                pool.HealthRatio = pool.HealthRatio + (realRatio - pool.HealthRatio)
                    * clamp(dt * 10, 0, 1)
                if pool.HealthRatio ~= pool.HealthRatio then pool.HealthRatio = realRatio end
                _drawHealthBar(pool, minX, minY, maxX, maxY,
                    pool.HealthRatio, esp.settings.healthbar.width, outlineOn)
            else
                pool.HealthFill.Visible    = false
                pool.HealthBg.Visible      = false
                pool.HealthOutline.Visible = false
            end

            -- ── TEXTS ────────────────────────────────────────
            local textY_top = minY - 2
            local textY_bot = maxY + 2

            -- Name (above box)
            if esp.settings.name.enabled then
                local t = pool.Name
                t.Text     = player.Name
                t.Size     = esp.settings.name.size
                t.Color    = esp.settings.name.color
                t.Outline  = esp.settings.name.outline
                t.Position = V2(cx, textY_top - esp.settings.name.size)
                t.Visible  = true
                textY_top  = textY_top - esp.settings.name.size - 1
            else
                pool.Name.Visible = false
            end

            -- Distance (below box)
            if esp.settings.distance.enabled then
                local t = pool.Distance
                t.Text     = math.round(dist) .. "m"
                t.Size     = esp.settings.distance.size
                t.Color    = esp.settings.distance.color
                t.Outline  = esp.settings.distance.outline
                t.Position = V2(cx, textY_bot)
                t.Visible  = true
                textY_bot  = textY_bot + esp.settings.distance.size + 1
            else
                pool.Distance.Visible = false
            end

            -- Weapon (below distance)
            if esp.settings.weapon.enabled then
                local t = pool.Weapon
                t.Text     = esp:getPlayerWeapon(player)
                t.Size     = esp.settings.weapon.size
                t.Color    = esp.settings.weapon.color
                t.Outline  = esp.settings.weapon.outline
                t.Position = V2(cx, textY_bot)
                t.Visible  = true
            else
                pool.Weapon.Visible = false
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════
-- PLAYER TRACKING
-- ═══════════════════════════════════════════════════════════════
table.insert(framework.connec_funcs["playeradded"], function(player)
    task.wait(0.5)
    _espInit(player)
    _espHookWeaponCache(player)
end)
table.insert(framework.connec_funcs["playerremoving"], function(player)
    _espClean(player)
    _espWeaponCache[player] = nil
    if _espWeaponConns[player] then
        for _, c in pairs(_espWeaponConns[player]) do pcall(function() c:Disconnect() end) end
        _espWeaponConns[player] = nil
    end
end)

for _, p in pairs(game:GetService("Players"):GetPlayers()) do
    if p ~= esp.localPlayer then _espInit(p) end
end

-- ═══════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════
local EspMainGroup = Tabs.Visuals:AddLeftGroupbox("ESP", "eye", {Collapsible=true})
local EspBoxGroup  = Tabs.Visuals:AddRightGroupbox("Box", "square", {Collapsible=true})

EspMainGroup:AddToggle("EnableESP", {Text="Enable ESP", Default=false,
    Callback=function(v)
        esp.settings.enabled = v
        if not v then _chamsEnabled = false; _chamsCleanAll() end
    end})
EspMainGroup:AddToggle("ESPTeamCheck", {Text="Team Check", Default=false,
    Callback=function(v) esp.settings.teamcheck = v end})
EspMainGroup:AddDivider()
EspMainGroup:AddSlider("MaxDistance", {Text="Max Distance", Default=1000, Min=0, Max=1000, Rounding=0, Suffix=" m",
    Callback=function(v) esp.settings.maxdis = v end})
EspMainGroup:AddSlider("HealthbarWidth", {Text="Bar Width", Default=3, Min=1, Max=10, Rounding=1,
    Callback=function(v) esp.settings.healthbar.width = v end})
EspMainGroup:AddDivider()

local NameToggle = EspMainGroup:AddToggle("NameEnabled", {Text="Name", Default=false,
    Callback=function(v) esp.settings.name.enabled = v end})
NameToggle:AddColorPicker("NameColor", {Default=Color3.fromRGB(255,255,255), Title="Name Color",
    Callback=function(v) esp.settings.name.color = v end})

local DistToggle = EspMainGroup:AddToggle("DistanceEnabled", {Text="Distance", Default=false,
    Callback=function(v) esp.settings.distance.enabled = v end})
DistToggle:AddColorPicker("DistanceColor", {Default=Color3.fromRGB(200,200,200), Title="Distance Color",
    Callback=function(v) esp.settings.distance.color = v end})

local WeaponToggle = EspMainGroup:AddToggle("WeaponEnabled", {Text="Weapon", Default=false,
    Callback=function(v) esp.settings.weapon.enabled = v end})
WeaponToggle:AddColorPicker("WeaponColor", {Default=Color3.fromRGB(255,0,0), Title="Weapon Color",
    Callback=function(v) esp.settings.weapon.color = v end})

EspMainGroup:AddToggle("HealthbarEnabled", {Text="Health bar", Default=false,
    Callback=function(v) esp.settings.healthbar.enabled = v end})
EspMainGroup:AddToggle("HealthbarOutline", {Text="Health Outline", Default=true,
    Callback=function(v) esp.settings.healthbar.outline = v end})

local BoxToggle = EspBoxGroup:AddToggle("BoxEnabled", {Text="Box", Default=false,
    Callback=function(v) esp.settings.box.enabled = v end})
BoxToggle:AddColorPicker("BoxColor", {Default=Color3.fromRGB(255,255,255), Title="Box Color",
    Callback=function(v) esp.settings.box.color = v end})
EspBoxGroup:AddToggle("BoxOutline", {Text="Outline", Default=true,
    Callback=function(v) esp.settings.box.outline = v end})
EspBoxGroup:AddDropdown("BoxMode", {Values={"corner","full"}, Default="corner", Text="Box Mode",
    Callback=function(v) esp.settings.box.mode = v end})

-- ═══════════════════════════════════════════════════════════════
-- CHAMS (original, полностью без изменений)
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
        if tm == criminalsTeam then
            visCol = _chamsCriminals; occCol = _chamsCriminals
        elseif tm == guardsTeam then
            visCol = _chamsGuards; occCol = _chamsGuards
        elseif tm == inmatesTeam then
            visCol = _chamsInmates; occCol = _chamsInmates
        end
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
    hOcc.Name = "ChamsHighlight_Occluded"
    hOcc.FillColor = occludedColor
    hOcc.OutlineColor = _chamsOutlineColor
    hOcc.FillTransparency = _chamsFillTransparency
    hOcc.OutlineTransparency = _chamsOutlineTransparency
    hOcc.DepthMode = Enum.HighlightDepthMode.Occluded
    hOcc.Adornee = char
    hOcc.Parent = char

    local hVis = Instance.new("Highlight")
    hVis.Name = "ChamsHighlight_Visible"
    hVis.FillColor = visibleColor
    hVis.OutlineColor = _chamsOutlineColor
    hVis.FillTransparency = _chamsFillTransparency
    hVis.OutlineTransparency = _chamsOutlineTransparency
    hVis.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hVis.Adornee = char
    hVis.Parent = char
end

local function _chamsRemoveHighlight(char)
    if not char then return end
    local hVis = char:FindFirstChild("ChamsHighlight_Visible")
    if hVis then hVis:Destroy() end
    local hOcc = char:FindFirstChild("ChamsHighlight_Occluded")
    if hOcc then hOcc:Destroy() end
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

for _, plr in pairs(game.Players:GetPlayers()) do
    if plr ~= game.Players.LocalPlayer then pcall(function() _chamsHookPlayer(plr) end) end
end
game.Players.PlayerAdded:Connect(function(plr)
    if plr ~= game.Players.LocalPlayer then pcall(function() _chamsHookPlayer(plr) end) end
end)
game.Players.PlayerRemoving:Connect(function(plr)
    if _chamsCharConns[plr] then _chamsCharConns[plr]:Disconnect(); _chamsCharConns[plr] = nil end
end)

game:GetService("RunService").Heartbeat:Connect(function()
    pcall(function()
        local lp = game.Players.LocalPlayer
        local localChar = lp.Character
        local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr == lp then continue end
            local char = plr.Character; if not char then continue end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then _chamsRemoveHighlight(char); continue end

            local withinRange = false
            if _chamsEnabled and localRoot then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (root.Position - localRoot.Position).Magnitude / 3
                    if esp.settings.maxdis > 0 and dist <= esp.settings.maxdis then withinRange = true end
                end
            end

            if not _chamsEnabled or _chamsSkip(plr) or not withinRange then
                _chamsRemoveHighlight(char)
            else
                local hVis = char:FindFirstChild("ChamsHighlight_Visible")
                local hOcc = char:FindFirstChild("ChamsHighlight_Occluded")
                local visCol, occCol = _chamsGetColors(plr)
                if not hVis or not hOcc then
                    _chamsAddHighlight(char, visCol, occCol)
                else
                    if hVis.FillColor ~= visCol then hVis.FillColor = visCol end
                    if hVis.OutlineColor ~= _chamsOutlineColor then hVis.OutlineColor = _chamsOutlineColor end
                    if hVis.FillTransparency ~= _chamsFillTransparency then hVis.FillTransparency = _chamsFillTransparency end
                    if hVis.OutlineTransparency ~= _chamsOutlineTransparency then hVis.OutlineTransparency = _chamsOutlineTransparency end
                    if hOcc.FillColor ~= occCol then hOcc.FillColor = occCol end
                    if hOcc.OutlineColor ~= _chamsOutlineColor then hOcc.OutlineColor = _chamsOutlineColor end
                    if hOcc.FillTransparency ~= _chamsFillTransparency then hOcc.FillTransparency = _chamsFillTransparency end
                    if hOcc.OutlineTransparency ~= _chamsOutlineTransparency then hOcc.OutlineTransparency = _chamsOutlineTransparency end
                end
            end
        end
    end)
end)

local ChamsGroup = Tabs.Visuals:AddLeftGroupbox("Chams", "layers", {Collapsible=true})
ChamsGroup:AddToggle("ChamsEnabled", {Text="Enable Chams", Default=false,
    Callback=function(v) _chamsEnabled=v; if not v then _chamsCleanAll() end end})

ChamsGroup:AddLabel("Visible Color"):AddColorPicker("ChamsVisibleColor", {Default=Color3.fromRGB(0,200,255), Title="Visible Color",
    Callback=function(v) _chamsVisibleColor=v end})
ChamsGroup:AddLabel("Occluded Color"):AddColorPicker("ChamsOccludedColor", {Default=Color3.fromRGB(255,40,40), Title="Occluded Color",
    Callback=function(v) _chamsOccludedColor=v end})

ChamsGroup:AddSlider("FillTransparency", {Text="Fill Transparency", Default=0.5, Min=0, Max=1, Rounding=2,
    Callback=function(v) _chamsFillTransparency=v end})
ChamsGroup:AddSlider("OutlineTransparency", {Text="Outline Transparency", Default=1, Min=0, Max=1, Rounding=2,
    Callback=function(v) _chamsOutlineTransparency=v end})

ChamsGroup:AddDivider()
ChamsGroup:AddToggle("TeamChamsEnabled", {Text="Team Chams", Default=false,
    Callback=function(v) _teamChamsOn=v end})
ChamsGroup:AddLabel("Criminals"):AddColorPicker("ChamsCriminals", {Default=Color3.fromRGB(255,60,60), Title="Criminals",
    Callback=function(v) _chamsCriminals=v end})
ChamsGroup:AddLabel("Guards"):AddColorPicker("ChamsGuards", {Default=Color3.fromRGB(60,120,255), Title="Guards",
    Callback=function(v) _chamsGuards=v end})
ChamsGroup:AddLabel("Inmates"):AddColorPicker("ChamsInmates", {Default=Color3.fromRGB(255,165,0), Title="Inmates",
    Callback=function(v) _chamsInmates=v end})
