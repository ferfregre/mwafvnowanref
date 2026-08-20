if not hookfunction then return end

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if not LocalPlayer then return end

local target = nil
local aimEnabled = false
local autofireEnabled = false
local lastFire = 0
local fireDelay = 0.03
local bhopEnabled = false
local spaceHeld = false
local humanoid = nil
local jumpTrailEnabled = false
local jumpSpeedEnabled = false
local normalSpeed = 16
local jumpSpeedMultiplier = 3.5

Settings = {
    ESP = false,
    HP = false,
    Boxes = false,
    Names = false,
    Distance = false,
    Night = false,
    Aim = false,
    Autofire = false,
    Bhop = false,
    JumpTrail = false,
    JumpSpeed = false,
    VisibleCheck = false
}

local original = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient
}

local highlights = {}
local ESPObjects = {}
local Camera = Workspace.CurrentCamera

-- ============================
-- VISIBLE CHECK
-- ============================
local function isVisible(targetPart)
    if not targetPart or not targetPart:IsA("BasePart") then return false end
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local origin = cam.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    params.IgnoreWater = true
    local direction = (targetPart.Position - origin).Unit * 500
    local result = Workspace:Raycast(origin, direction, params)
    if result then
        local model = result.Instance:FindFirstAncestorOfClass("Model")
        if model and Players:GetPlayerFromCharacter(model) then
            return true
        end
        return false
    else
        return true
    end
end

-- ============================
-- ESP HIGHLIGHT
-- ============================
local function updateESPColor(character, player)
    if not Settings.ESP then return end
    local h = highlights[player]
    if not h then return end
    if Settings.VisibleCheck then
        local head = character:FindFirstChild("Head")
        if head and isVisible(head) then
            h.OutlineColor = Color3.fromRGB(0, 255, 0)
        else
            h.OutlineColor = Color3.fromRGB(255, 0, 0)
        end
    else
        h.OutlineColor = Color3.fromRGB(255, 60, 60)
    end
end

local function removeESP(player)
    local h = highlights[player]
    if h then
        h:Destroy()
        highlights[player] = nil
    end
    if player.Character then
        local old = player.Character:FindFirstChild("ESPHighlight")
        if old then old:Destroy() end
        local hp = player.Character:FindFirstChild("ESP_HP")
        if hp then hp:Destroy() end
    end
    removeESPObjects(player)
end

local function addHP(character)
    if not Settings.HP then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local old = character:FindFirstChild("ESP_HP")
    if old then old:Destroy() end
    local hp = Instance.new("Highlight")
    hp.Name = "ESP_HP"
    hp.Adornee = character
    hp.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hp.OutlineTransparency = 1
    hp.FillTransparency = 0.35
    hp.Parent = character
    task.spawn(function()
        while hp.Parent and humanoid.Parent do
            local health = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
            if health > 0.6 then
                hp.FillColor = Color3.fromRGB(50, 220, 80)
            elseif health > 0.3 then
                hp.FillColor = Color3.fromRGB(255, 190, 50)
            else
                hp.FillColor = Color3.fromRGB(235, 60, 60)
            end
            task.wait(0.1)
        end
    end)
end

local function addESP(player)
    if player == LocalPlayer then return end
    if not Settings.ESP then return end
    local character = player.Character
    if not character then return end
    removeESP(player)
    local h = Instance.new("Highlight")
    h.Name = "ESPHighlight"
    h.Adornee = character
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillTransparency = 1
    h.OutlineTransparency = 0
    h.OutlineColor = Color3.fromRGB(255, 60, 60)
    h.Parent = character
    highlights[player] = h
    addHP(character)
    task.spawn(function()
        while h and h.Parent do
            updateESPColor(character, player)
            task.wait(0.2)
        end
    end)
end

-- ============================
-- ESP BOXES + NAMES + DISTANCE
-- ============================
local function createESPObjects(player)
    if ESPObjects[player] then return end
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Color = Color3.fromRGB(0, 195, 255)
    box.Visible = false
    box.ZIndex = 2

    local outline = Drawing.new("Square")
    outline.Thickness = 2
    outline.Filled = false
    outline.Color = Color3.new(0, 0, 0)
    outline.Visible = false
    outline.ZIndex = 1

    local name = Drawing.new("Text")
    name.Size = 13
    name.Center = true
    name.Outline = true
    name.Color = Color3.fromRGB(255, 255, 255)
    name.Visible = false

    local dist = Drawing.new("Text")
    dist.Size = 12
    dist.Center = true
    dist.Outline = true
    dist.Color = Color3.fromRGB(200, 200, 200)
    dist.Visible = false

    ESPObjects[player] = {Box = box, Outline = outline, Name = name, Dist = dist}
end

local function removeESPObjects(player)
    local data = ESPObjects[player]
    if data then
        for _, v in pairs(data) do
            if v and v.Remove then pcall(v.Remove, v) end
        end
        ESPObjects[player] = nil
    end
end

local function updateESPObjects()
    for player, data in pairs(ESPObjects) do
        local char = player.Character
        if not Settings.ESP or not char then
            data.Box.Visible = false
            data.Outline.Visible = false
            data.Name.Visible = false
            data.Dist.Visible = false
            goto continue
        end

        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        local head = char:FindFirstChild("Head")
        if not hrp or not head then
            data.Box.Visible = false
            data.Outline.Visible = false
            data.Name.Visible = false
            data.Dist.Visible = false
            goto continue
        end

        local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then
            data.Box.Visible = false
            data.Outline.Visible = false
            data.Name.Visible = false
            data.Dist.Visible = false
            goto continue
        end

        local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
        local height = math.abs(headPos.Y - legPos.Y)
        local width = height / 2

        local boxColor = Color3.fromRGB(0, 195, 255)
        if Settings.VisibleCheck then
            if isVisible(head) then
                boxColor = Color3.fromRGB(0, 255, 0)
            else
                boxColor = Color3.fromRGB(255, 0, 0)
            end
        end

        if Settings.Boxes then
            data.Box.Size = Vector2.new(width, height)
            data.Box.Position = Vector2.new(pos.X - width / 2, pos.Y - height / 2)
            data.Box.Color = boxColor
            data.Box.Visible = true
            data.Outline.Size = data.Box.Size
            data.Outline.Position = data.Box.Position
            data.Outline.Visible = true
        else
            data.Box.Visible = false
            data.Outline.Visible = false
        end

        if Settings.Names then
            data.Name.Text = player.Name
            data.Name.Position = Vector2.new(pos.X, headPos.Y - 16)
            data.Name.Visible = true
        else
            data.Name.Visible = false
        end

        if Settings.Distance then
            local distance = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
            data.Dist.Text = distance .. "m"
            data.Dist.Position = Vector2.new(pos.X, legPos.Y + 4)
            data.Dist.Visible = true
        else
            data.Dist.Visible = false
        end
        
        ::continue::
    end
end

-- ============================
-- AIM
-- ============================
local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not hrp then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health and hum.Health <= 0 then return false end
    local team1 = LocalPlayer.Team
    local team2 = player.Team
    if team1 and team2 and team1 == team2 then return false end
    return true
end

local function getClosestPlayer()
    local closestDistance = math.huge
    local closest = nil
    local camera = Workspace.CurrentCamera
    if not camera then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not isEnemy(player) then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if not hrp or not hrp:IsA("BasePart") then continue end
        local head = char:FindFirstChild("Head")
        if not head or not head:IsA("BasePart") then continue end
        local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
        if onScreen then
            local distance = (Vector2.new(screenPos.X, screenPos.Y) - camera.ViewportSize / 2).Magnitude
            if distance < closestDistance then
                if not isVisible(head) then continue end
                closestDistance = distance
                closest = head
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if aimEnabled then
        target = getClosestPlayer()
    else
        target = nil
    end
    doAutofire()
    updateESPObjects()
end)

local oldRay
pcall(function()
    oldRay = hookfunction(Ray.new, function(origin, direction)
        if target and target:IsA("BasePart") then
            direction = (target.Position - origin).Unit * 500
        end
        return oldRay(origin, direction)
    end)
end)

-- ============================
-- AUTOFIRE
-- ============================
local function doAutofire()
    if not target or not autofireEnabled then return end
    local now = tick()
    if now - lastFire < fireDelay then return end
    lastFire = now
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
    end
    if VIM then
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.015)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end

-- ============================
-- JUMP SPEED
-- ============================
local function setupJumpSpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    humanoid = hum
    hum.StateChanged:Connect(function(_, newState)
        if not jumpSpeedEnabled then
            if hum.WalkSpeed ~= normalSpeed then
                hum.WalkSpeed = normalSpeed
            end
            return
        end
        if newState == Enum.HumanoidStateType.Jumping then
            hum.WalkSpeed = normalSpeed * jumpSpeedMultiplier
        elseif newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
            hum.WalkSpeed = normalSpeed
        end
    end)
end

-- ============================
-- JUMP TRAIL
-- ============================
local RING_SIZE = 10
local DURATION = 0.8
local COLOR = Color3.fromRGB(255, 255, 255)

local function createJumpRing(position)
    if not jumpTrailEnabled then return end
    local part = Instance.new("Part")
    part.Name = "JumpRing"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1
    part.Size = Vector3.new(1, 0.05, 1)
    part.Position = Vector3.new(position.X, position.Y - 3, position.Z)
    part.Parent = Workspace
    local surface = Instance.new("SurfaceGui")
    surface.Face = Enum.NormalId.Top
    surface.AlwaysOnTop = true
    surface.LightInfluence = 0
    surface.Parent = part
    local image = Instance.new("ImageLabel")
    image.BackgroundTransparency = 1
    image.Size = UDim2.fromScale(1, 1)
    image.Image = "rbxassetid://266543268"
    image.ImageColor3 = COLOR
    image.ImageTransparency = 0.1
    image.Parent = surface
    local grow = TweenService:Create(part, TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(RING_SIZE, 0.05, RING_SIZE)
    })
    local fade = TweenService:Create(image, TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        ImageTransparency = 1
    })
    grow:Play()
    fade:Play()
    task.delay(DURATION + 0.1, function()
        if part then part:Destroy() end
    end)
end

local function setupJumpDetection()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    humanoid = hum
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return end
    hum.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            createJumpRing(root.Position)
        end
    end)
end

-- ============================
-- BHOP
-- ============================
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        spaceHeld = true
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        spaceHeld = false
    end
end)

task.spawn(function()
    while true do
        task.wait()
        if bhopEnabled and spaceHeld and humanoid and humanoid.Health and humanoid.Health > 0 then
            if humanoid.FloorMaterial and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

-- ============================
-- NIGHT
-- ============================
local function updateNight()
    if not Settings.Night then
        Lighting.ClockTime = original.ClockTime
        Lighting.Brightness = original.Brightness
        Lighting.Ambient = original.Ambient
        Lighting.OutdoorAmbient = original.OutdoorAmbient
        return
    end
    local s = math.clamp(0.7, 0, 1)
    Lighting.ClockTime = 0
    Lighting.Brightness = 0.1
    Lighting.Ambient = Color3.fromRGB(8, 8, 18)
    Lighting.OutdoorAmbient = Color3.fromRGB(5, 5, 12)
end

-- ============================
-- ОБНОВЛЕНИЕ ESP
-- ============================
local function updateESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if Settings.ESP then
                addESP(player)
            else
                removeESP(player)
            end
        end
    end
    updateESPObjects()
end

-- ============================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createESPObjects(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    task.wait(0.5)
    createESPObjects(player)
    if Settings.ESP then addESP(player) end
end)

Players.PlayerRemoving:Connect(removeESP)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    setupJumpDetection()
    setupJumpSpeed()
    updateESP()
end)

if LocalPlayer.Character then
    task.wait(0.5)
    humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    setupJumpDetection()
    setupJumpSpeed()
    updateESP()
end

-- ============================
-- UI
-- ============================
local gui = Instance.new("ScreenGui")
gui.Name = "MenuGUI"
gui.ResetOnSpawn = false
gui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(560, 440)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -220)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundTransparency = 1
title.Text = "SWILL MENU"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

-- ============================
-- ВКЛАДКИ
-- ============================
local tabs = {"AIM", "ESP", "COMBAT"}
local currentTab = "AIM"

local tabButtons = {}
local contentFrames = {}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 180, 0, 30)
    btn.Position = UDim2.new(0, 5 + (i - 1) * 183, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Text = tabName
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = mainFrame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn
    tabButtons[tabName] = btn
    
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -10, 1, -80)
    content.Position = UDim2.new(0, 5, 0, 70)
    content.BackgroundTransparency = 1
    content.Visible = (tabName == "AIM")
    content.Parent = mainFrame
    contentFrames[tabName] = content
    
    btn.MouseButton1Click:Connect(function()
        for _, v in pairs(contentFrames) do
            v.Visible = false
        end
        contentFrames[tabName].Visible = true
        currentTab = tabName
        for _, b in pairs(tabButtons) do
            b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            b.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
end

tabButtons["AIM"].BackgroundColor3 = Color3.fromRGB(60, 60, 70)
tabButtons["AIM"].TextColor3 = Color3.fromRGB(255, 255, 255)

-- ============================
-- ПЕРЕКЛЮЧАТЕЛИ
-- ============================
local function makeSwitch(parent, text, y, get, set)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.5, -5, 0, 28)
    btn.Position = UDim2.new(0, 5, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Text = text .. "  " .. (get() and "ON" or "OFF")
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BorderSizePixel = 0
    btn.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 4)
    c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        set(not get())
        btn.Text = text .. "  " .. (get() and "ON" or "OFF")
        if text == "ESP" then updateESP() end
        if text == "Night" then updateNight() end
    end)
    return btn
end

-- ============================
-- AIM TAB
-- ============================
makeSwitch(contentFrames["AIM"], "Aim", 5, function() return Settings.Aim end, function(v) Settings.Aim = v aimEnabled = v end)
makeSwitch(contentFrames["AIM"], "Autofire", 37, function() return Settings.Autofire end, function(v) Settings.Autofire = v autofireEnabled = v end)

-- ============================
-- ESP TAB
-- ============================
makeSwitch(contentFrames["ESP"], "ESP", 5, function() return Settings.ESP end, function(v) Settings.ESP = v end)
makeSwitch(contentFrames["ESP"], "HP", 37, function() return Settings.HP end, function(v) Settings.HP = v end)
makeSwitch(contentFrames["ESP"], "Boxes", 69, function() return Settings.Boxes end, function(v) Settings.Boxes = v end)
makeSwitch(contentFrames["ESP"], "Names", 101, function() return Settings.Names end, function(v) Settings.Names = v end)
makeSwitch(contentFrames["ESP"], "Distance", 133, function() return Settings.Distance end, function(v) Settings.Distance = v end)
makeSwitch(contentFrames["ESP"], "VisibleCheck", 165, function() return Settings.VisibleCheck end, function(v) Settings.VisibleCheck = v end)
makeSwitch(contentFrames["ESP"], "Night", 197, function() return Settings.Night end, function(v) Settings.Night = v end)

-- ============================
-- COMBAT TAB
-- ============================
local combatY = 5
makeSwitch(contentFrames["COMBAT"], "Bhop", combatY, function() return Settings.Bhop end, function(v) Settings.Bhop = v bhopEnabled = v end)
combatY = combatY + 32
makeSwitch(contentFrames["COMBAT"], "Jump Speed", combatY, function() return Settings.JumpSpeed end, function(v) Settings.JumpSpeed = v jumpSpeedEnabled = v end)
combatY = combatY + 32
makeSwitch(contentFrames["COMBAT"], "Jump Trail", combatY, function() return Settings.JumpTrail end, function(v) Settings.JumpTrail = v jumpTrailEnabled = v end)

-- ============================
-- ЗАКРЫТИЕ
-- ============================
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 60, 0, 25)
closeBtn.Position = UDim2.new(1, -70, 1, -30)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
closeBtn.Text = "Close"
closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
closeBtn.TextSize = 11
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = mainFrame
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 6)
cc.Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(40, 40)
openBtn.Position = UDim2.new(0, 10, 1, -60)
openBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
openBtn.Text = "⚙"
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.TextSize = 20
openBtn.Font = Enum.Font.GothamBold
openBtn.BorderSizePixel = 0
openBtn.Parent = gui
local oc = Instance.new("UICorner")
oc.CornerRadius = UDim.new(0, 10)
oc.Parent = openBtn
openBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.P then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

print("SWILL FULL LOADED | Press P to open menu")