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

local _espBillboards = {}

local function _espCleanBillboard(player)
    local bb = _espBillboards[player]
    if bb then
        pcall(function() bb:Destroy() end)
        _espBillboards[player] = nil
    end
end

local function _espMakeBillboard(player)
    if not player or player == esp.localPlayer then return end
    _espCleanBillboard(player)

    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "ZoltESP_" .. player.Name
    bb.Adornee = head
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 200, 0, 60)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.ResetOnSpawn = false
    bb.Enabled = false
    bb.Parent = game:GetService("CoreGui")

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0, 18)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Text = player.Name
    nameLabel.Visible = false
    nameLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(1, 0, 0, 16)
    distLabel.Position = UDim2.new(0, 0, 0, 20)
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 12
    distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.Text = ""
    distLabel.Visible = false
    distLabel.Parent = bb

    local weapLabel = Instance.new("TextLabel")
    weapLabel.Name = "WeapLabel"
    weapLabel.BackgroundTransparency = 1
    weapLabel.Size = UDim2.new(1, 0, 0, 16)
    weapLabel.Position = UDim2.new(0, 0, 0, 38)
    weapLabel.Font = Enum.Font.Gotham
    weapLabel.TextSize = 12
    weapLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    weapLabel.TextStrokeTransparency = 0
    weapLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    weapLabel.Text = ""
    weapLabel.Visible = false
    weapLabel.Parent = bb

    local hpFrame = Instance.new("Frame")
    hpFrame.Name = "HPFrame"
    hpFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    hpFrame.BorderSizePixel = 0
    hpFrame.Size = UDim2.new(0, 4, 1, 0)
    hpFrame.Position = UDim2.new(0, -14, 0, 0)
    hpFrame.Visible = false
    hpFrame.Parent = bb

    local hpFill = Instance.new("Frame")
    hpFill.Name = "HPFill"
    hpFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    hpFill.BorderSizePixel = 0
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.AnchorPoint = Vector2.new(0, 1)
    hpFill.Position = UDim2.new(0, 0, 1, 0)
    hpFill.Parent = hpFrame

    local boxFrame = Instance.new("Frame")
    boxFrame.Name = "BoxFrame"
    boxFrame.BackgroundTransparency = 1
    boxFrame.Size = UDim2.new(1, 0, 1, 0)
    boxFrame.Position = UDim2.new(0, 0, 0, 0)
    boxFrame.BorderSizePixel = 2
    boxFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
    boxFrame.Visible = false
    boxFrame.Parent = bb

    _espBillboards[player] = bb
end

local function _espHideBillboard(player)
    local bb = _espBillboards[player]
    if bb then bb.Enabled = false end
end

for _, p in pairs(game:GetService("Players"):GetPlayers()) do
    if p ~= esp.localPlayer then
        task.spawn(function()
            repeat task.wait(0.1) until p.Character and p.Character:FindFirstChild("Head")
            _espMakeBillboard(p)
            _espHookWeaponCache(p)
        end)
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            _espMakeBillboard(p)
        end)
    end
end

game:GetService("Players").PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        _espMakeBillboard(p)
    end)
end)

game:GetService("RunService").Heartbeat:Connect(function()
    pcall(function()
        if not esp.settings.enabled then
            for player in pairs(_espBillboards) do _espHideBillboard(player) end
            return
        end

        local lp = esp.localPlayer
        local localChar = lp.Character
        local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
        if not localRoot then
            for player in pairs(_espBillboards) do _espHideBillboard(player) end
            return
        end

        for player, bb in pairs(_espBillboards) do
            if not player or not player.Parent then _espHideBillboard(player); continue end
            if esp.settings.teamcheck and player.Team == lp.Team then _espHideBillboard(player); continue end

            local char = player.Character
            if not char then _espHideBillboard(player); continue end
            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local hum  = char:FindFirstChildOfClass("Humanoid")
            if not root or not head or not hum then _espHideBillboard(player); continue end
            if hum.Health <= 0 then _espHideBillboard(player); continue end

            if bb.Adornee ~= head then bb.Adornee = head end

            local dist = (root.Position - localRoot.Position).Magnitude / 3
            if esp.settings.maxdis == 0 or dist > esp.settings.maxdis then _espHideBillboard(player); continue end

            if not _espWeaponConns[player] then _espHookWeaponCache(player) end

            bb.Enabled = true

            local nameLabel = bb:FindFirstChild("NameLabel")
            if nameLabel then
                nameLabel.Visible = esp.settings.name.enabled
                if esp.settings.name.enabled then
                    nameLabel.Text = player.Name
                    nameLabel.TextColor3 = esp.settings.name.color
                    nameLabel.TextSize = esp.settings.name.size
                    nameLabel.TextStrokeTransparency = esp.settings.name.outline and 0 or 1
                end
            end

            local distLabel = bb:FindFirstChild("DistLabel")
            if distLabel then
                distLabel.Visible = esp.settings.distance.enabled
                if esp.settings.distance.enabled then
                    distLabel.Text = tostring(math.round(dist)) .. "m"
                    distLabel.TextColor3 = esp.settings.distance.color
                    distLabel.TextSize = esp.settings.distance.size
                    distLabel.TextStrokeTransparency = esp.settings.distance.outline and 0 or 1
                end
            end

            local weapLabel = bb:FindFirstChild("WeapLabel")
            if weapLabel then
                weapLabel.Visible = esp.settings.weapon.enabled
                if esp.settings.weapon.enabled then
                    weapLabel.Text = esp:getPlayerWeapon(player)
                    weapLabel.TextColor3 = esp.settings.weapon.color
                    weapLabel.TextSize = esp.settings.weapon.size
                    weapLabel.TextStrokeTransparency = esp.settings.weapon.outline and 0 or 1
                end
            end

            local hpFrame = bb:FindFirstChild("HPFrame")
            local hpFill  = hpFrame and hpFrame:FindFirstChild("HPFill")
            if hpFrame and hpFill then
                hpFrame.Visible = esp.settings.healthbar.enabled
                if esp.settings.healthbar.enabled then
                    local pct = hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
                    hpFill.Size = UDim2.new(1, 0, pct, 0)
                    hpFill.BackgroundColor3 = Color3.new(math.clamp(1 - pct, 0, 1), math.clamp(pct, 0, 1), 0)
                end
            end

            local boxFrame = bb:FindFirstChild("BoxFrame")
            if boxFrame then
                boxFrame.Visible = esp.settings.box.enabled
                if esp.settings.box.enabled then
                    boxFrame.BorderColor3 = esp.settings.box.color
                end
            end
        end
    end)
end)

table.insert(framework.connec_funcs["playeradded"], function(player)
    task.wait(1)
    _espMakeBillboard(player)
    _espHookWeaponCache(player)
end)
table.insert(framework.connec_funcs["playerremoving"], function(player)
    _espCleanBillboard(player)
    _espWeaponCache[player] = nil
    if _espWeaponConns[player] then
        for _, c in pairs(_espWeaponConns[player]) do pcall(function() c:Disconnect() end) end
        _espWeaponConns[player] = nil
    end
end)

local EspMainGroup   = Tabs.Visuals:AddLeftGroupbox("ESP", "eye", {Collapsible=true})
local EspBoxGroup    = Tabs.Visuals:AddRightGroupbox("Box", "square", {Collapsible=true})

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

local HpToggle=EspMainGroup:AddToggle("HealthbarEnabled",{Text="Health bar",Default=false,
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
-- CHAMS
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
