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

-- ═══════════════════════════════════════════════════════════════
-- WEAPON CACHE (original, untouched)
-- ═══════════════════════════════════════════════════════════════
esp.weapons_list = {
    "M9","Taser","MP5","M4A1","AK-47","FAL","Remington 870","EBR","M700","Revolver",
    "Crude Knife","Hammer","Breakfast","C4","Explosive","Dinner","Handcuffs","Key card","Lunch","Riot Shield","Pickaxe",
}

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
-- DRAWING POOL
-- ═══════════════════════════════════════════════════════════════
local clamp = math.clamp
local V2    = Vector2.new
local C3    = Color3.new

local function _newSquare(filled)
    local s = Drawing.new("Square")
    s.Filled = filled or false; s.Thickness = 1; s.Visible = false
    return s
end
local function _newLine()
    local l = Drawing.new("Line")
    l.Thickness = 1; l.Visible = false
    return l
end
local function _newText()
    local t = Drawing.new("Text")
    t.Size = 13; t.Center = true; t.Outline = true; t.Visible = false; t.Text = ""
    return t
end

local function _createPool()
    local p = {}
    p.BoxOutline      = _newSquare(false)
    p.BoxInnerOutline = _newSquare(false)
    p.Box             = _newSquare(false)
    p.CornerOutlines  = {}
    p.Corners         = {}
    for i = 1, 16 do p.CornerOutlines[i] = _newLine() end
    for i = 1,  8 do p.Corners[i]        = _newLine() end
    p.HealthOutline = _newSquare(false)
    p.HealthBg      = _newSquare(true)
    p.HealthFill    = _newSquare(true)
    p.Name          = _newText()
    p.Distance      = _newText()
    p.Weapon        = _newText()
    p.HealthRatio   = 1
    return p
end

local function _hidePool(p)
    p.BoxOutline.Visible = false; p.BoxInnerOutline.Visible = false; p.Box.Visible = false
    for i = 1, 16 do p.CornerOutlines[i].Visible = false end
    for i = 1,  8 do p.Corners[i].Visible        = false end
    p.HealthOutline.Visible = false; p.HealthBg.Visible = false; p.HealthFill.Visible = false
    p.Name.Visible = false; p.Distance.Visible = false; p.Weapon.Visible = false
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

-- ESP drawings keyed by player, живут в framework.players[player].drawings.esp
-- но для простоты держим отдельно — framework не трогает наши drawings
local _espPools = {}  -- [player] = pool

-- ═══════════════════════════════════════════════════════════════
-- BOX DRAWERS
-- ═══════════════════════════════════════════════════════════════
local function _drawFullBox(p, x0, y0, x1, y1, color, outlineOn)
    local w, h = x1-x0, y1-y0
    if outlineOn then
        p.BoxOutline.Position = V2(x0-1,y0-1); p.BoxOutline.Size = V2(w+2,h+2)
        p.BoxOutline.Color = C3(0,0,0); p.BoxOutline.Thickness = 1; p.BoxOutline.Filled = false; p.BoxOutline.Visible = true
        if w > 2 and h > 2 then
            p.BoxInnerOutline.Position = V2(x0+1,y0+1); p.BoxInnerOutline.Size = V2(w-2,h-2)
            p.BoxInnerOutline.Color = C3(0,0,0); p.BoxInnerOutline.Thickness = 1; p.BoxInnerOutline.Filled = false; p.BoxInnerOutline.Visible = true
        else p.BoxInnerOutline.Visible = false end
    else
        p.BoxOutline.Visible = false; p.BoxInnerOutline.Visible = false
    end
    p.Box.Position = V2(x0,y0); p.Box.Size = V2(w,h)
    p.Box.Color = color; p.Box.Thickness = 1; p.Box.Filled = false; p.Box.Visible = true
    for i = 1,8 do p.Corners[i].Visible = false end
    for i = 1,16 do p.CornerOutlines[i].Visible = false end
end

local function _drawCornerBox(p, x0, y0, x1, y1, color, outlineOn)
    p.Box.Visible = false; p.BoxOutline.Visible = false; p.BoxInnerOutline.Visible = false
    local w, h = x1-x0, y1-y0
    local len   = clamp(math.min(w,h)*0.28, 3, 14)
    local pts = {
        {V2(x0,y0), V2(x0+len,y0)}, {V2(x0,y0), V2(x0,y0+len)},
        {V2(x1,y0), V2(x1-len,y0)}, {V2(x1,y0), V2(x1,y0+len)},
        {V2(x0,y1), V2(x0+len,y1)}, {V2(x0,y1), V2(x0,y1-len)},
        {V2(x1,y1), V2(x1-len,y1)}, {V2(x1,y1), V2(x1,y1-len)},
    }
    for i = 1, 8 do
        local seg = pts[i]
        local line = p.Corners[i]
        local o1 = p.CornerOutlines[i*2-1]; local o2 = p.CornerOutlines[i*2]
        if outlineOn then
            if i % 2 == 1 then
                o1.From=V2(seg[1].X,seg[1].Y-1); o1.To=V2(seg[2].X,seg[2].Y-1)
                o2.From=V2(seg[1].X,seg[1].Y+1); o2.To=V2(seg[2].X,seg[2].Y+1)
            else
                o1.From=V2(seg[1].X-1,seg[1].Y); o1.To=V2(seg[2].X-1,seg[2].Y)
                o2.From=V2(seg[1].X+1,seg[1].Y); o2.To=V2(seg[2].X+1,seg[2].Y)
            end
            o1.Color=C3(0,0,0); o1.Thickness=1; o1.Visible=true
            o2.Color=C3(0,0,0); o2.Thickness=1; o2.Visible=true
        else o1.Visible=false; o2.Visible=false end
        line.From=seg[1]; line.To=seg[2]; line.Color=color; line.Thickness=1; line.Visible=true
    end
end

-- ═══════════════════════════════════════════════════════════════
-- HEALTH BAR
-- ═══════════════════════════════════════════════════════════════
local function _drawHealthBar(p, x0, y0, x1, y1, ratio, bw, outlineOn)
    local h  = y1 - y0
    local fh = h * ratio
    local x  = x0 - (bw + 3)
    local r  = clamp(1-ratio, 0, 1); local g = clamp(ratio, 0, 1)

    p.HealthBg.Position=V2(x,y0); p.HealthBg.Size=V2(bw,h)
    p.HealthBg.Color=C3(0,0,0); p.HealthBg.Filled=true; p.HealthBg.Transparency=0.4; p.HealthBg.Visible=true

    p.HealthFill.Position=V2(x, y0+(h-fh)); p.HealthFill.Size=V2(bw,fh)
    p.HealthFill.Color=C3(r,g,0); p.HealthFill.Filled=true; p.HealthFill.Transparency=0; p.HealthFill.Visible=true

    if outlineOn then
        p.HealthOutline.Position=V2(x-1,y0-1); p.HealthOutline.Size=V2(bw+2,h+2)
        p.HealthOutline.Color=C3(0,0,0); p.HealthOutline.Filled=false; p.HealthOutline.Thickness=1; p.HealthOutline.Visible=true
    else p.HealthOutline.Visible=false end
end

-- ═══════════════════════════════════════════════════════════════
-- BOUNDING BOX (juanita per-corner projection)
-- ═══════════════════════════════════════════════════════════════
local BODY_PARTS = {"Head","HumanoidRootPart","Left Arm","Left Leg","Right Arm","Right Leg","Torso"}

local function _getBounds(char, cam)
    local minX, minY =  math.huge,  math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyOn = false

    for _, name in ipairs(BODY_PARTS) do
        local part = char:FindFirstChild(name)
        if not part or not part:IsA("BasePart") then continue end
        local cf, sz = part.CFrame, part.Size
        local hx, hy, hz = sz.X/2, sz.Y/2, sz.Z/2
        for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz2 = -1, 1, 2 do
            local corner = (cf * CFrame.new(hx*sx, hy*sy, hz*sz2)).Position
            local s = cam:WorldToViewportPoint(corner)
            -- s это Vector3: X,Y = экран, Z = глубина (>0 = перед камерой)
            if s.Z > 0 then
                anyOn = true
                if s.X < minX then minX = s.X end
                if s.Y < minY then minY = s.Y end
                if s.X > maxX then maxX = s.X end
                if s.Y > maxY then maxY = s.Y end
            end
        end end end
    end

    return anyOn, minX, minY, maxX, maxY
end

-- ═══════════════════════════════════════════════════════════════
-- RENDER LOOP — читаем framework.players, как chams
-- ═══════════════════════════════════════════════════════════════
RunService.Heartbeat:Connect(function(dt)
    pcall(function()
        local cam       = framework.services.camera
        local lp        = framework.player
        local localRoot = framework.character and framework.character:FindFirstChild("HumanoidRootPart")

        if not esp.settings.enabled then
            for _, pool in pairs(_espPools) do _hidePool(pool) end
            return
        end

        for player, data in pairs(framework.players) do
            if player == lp then continue end

            if not _espPools[player] then
                _espPools[player] = _createPool()
            end
            local pool = _espPools[player]

            if not data.spawned or not data.character or not data.root then
                _hidePool(pool); continue
            end

            local char = data.character
            local root = data.root
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then _hidePool(pool); continue end

            if esp.settings.teamcheck and player.Team == lp.Team then _hidePool(pool); continue end

            if not localRoot then _hidePool(pool); continue end
            local dist = (root.Position - localRoot.Position).Magnitude / 3
            if esp.settings.maxdis == 0 or dist > esp.settings.maxdis then _hidePool(pool); continue end

            if not _espWeaponConns[player] then _espHookWeaponCache(player) end

            local anyOn, x0, y0, x1, y1 = _getBounds(char, cam)
            if not anyOn then _hidePool(pool); continue end

            local w, h = x1-x0, y1-y0
            if h <= 1 then _hidePool(pool); continue end

            local cx        = math.floor((x0+x1)*0.5)
            local outlineOn = esp.settings.box.outline
            local boxColor  = esp.settings.box.color

            if esp.settings.box.enabled then
                if esp.settings.box.mode == "full" then
                    _drawFullBox(pool, x0, y0, x1, y1, boxColor, outlineOn)
                else
                    _drawCornerBox(pool, x0, y0, x1, y1, boxColor, outlineOn)
                end
            else
                pool.Box.Visible=false; pool.BoxOutline.Visible=false; pool.BoxInnerOutline.Visible=false
                for i=1,8 do pool.Corners[i].Visible=false end
                for i=1,16 do pool.CornerOutlines[i].Visible=false end
            end

            if esp.settings.healthbar.enabled then
                local real = clamp(hum.Health / hum.MaxHealth, 0, 1)
                pool.HealthRatio = pool.HealthRatio + (real - pool.HealthRatio) * clamp(dt*10, 0, 1)
                if pool.HealthRatio ~= pool.HealthRatio then pool.HealthRatio = real end
                _drawHealthBar(pool, x0, y0, x1, y1, pool.HealthRatio, esp.settings.healthbar.width, outlineOn)
            else
                pool.HealthFill.Visible=false; pool.HealthBg.Visible=false; pool.HealthOutline.Visible=false
            end

            local topY = y0 - 2
            local botY = y1 + 2

            if esp.settings.name.enabled then
                local t = pool.Name
                t.Text=player.Name; t.Size=esp.settings.name.size
                t.Color=esp.settings.name.color; t.Outline=esp.settings.name.outline
                t.Position=V2(cx, topY - esp.settings.name.size)
                t.Visible=true
                topY = topY - esp.settings.name.size - 1
            else pool.Name.Visible=false end

            if esp.settings.distance.enabled then
                local t = pool.Distance
                t.Text=math.round(dist).."m"; t.Size=esp.settings.distance.size
                t.Color=esp.settings.distance.color; t.Outline=esp.settings.distance.outline
                t.Position=V2(cx, botY); t.Visible=true
                botY = botY + esp.settings.distance.size + 1
            else pool.Distance.Visible=false end

            if esp.settings.weapon.enabled then
                local t = pool.Weapon
                t.Text=esp:getPlayerWeapon(player); t.Size=esp.settings.weapon.size
                t.Color=esp.settings.weapon.color; t.Outline=esp.settings.weapon.outline
                t.Position=V2(cx, botY); t.Visible=true
            else pool.Weapon.Visible=false end
        end

        for player, pool in pairs(_espPools) do
            if not framework.players[player] then
                _removePool(pool); _espPools[player] = nil
            end
        end
    end)
end)

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
-- CHAMS (original, без изменений)
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

for _, plr in pairs(game.Players:GetPlayers()) do
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
        -- chams использует framework.players как источник истины
        for player, data in pairs(framework.players) do
            if player == lp then continue end
            local char = data.character
            if not char then continue end
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
