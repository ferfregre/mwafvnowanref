-- ============================================
-- SWILL | RAYFIELD UI + ALL FUNCTIONS
-- ============================================
if not hookfunction then return end

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if not LocalPlayer then return end

-- ============================
-- ОСНОВНЫЕ НАСТРОЙКИ
-- ============================
local target = nil
local dddEnabled = false
local aimFOV = 200
local jumpTrailEnabled = false
local autofireEnabled = false
local lastFire = 0
local fireDelay = 0.03
local bhopEnabled = false
local spaceHeld = false
local humanoid = nil
local trailEnabled = false
local trailColor = Color3.fromRGB(200, 0, 255)
local trailDuration = 0.5
local DESIRED_ZOOM = 30
local SPIN_SPEED = 25
local spinAngle = 0
local spinConnection = nil
local espEnabled = false
local hpEnabled = false
local cameraFOV = 70

-- WallCam переменные
local wallCamEnabled = false
local targetEnemyPlayer = nil
local targetHumanoidDiedConnection = nil
local cameraRotationX = 0
local cameraRotationY = 0
local SKY_HEIGHT = 1000
local CAMERA_DISTANCE = 5
local MOUSE_SENSITIVITY = 0.5
local wallCamConnection = nil

local original = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient
}

local highlights = {}

-- ============================
-- КАМЕРА FOV
-- ============================
local function updateCameraFOV()
    Camera.FieldOfView = cameraFOV
end

-- ============================
-- ZOOM
-- ============================
local function applyZoom()
    if Settings.Zoom then
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMinZoomDistance = DESIRED_ZOOM
        LocalPlayer.CameraMaxZoomDistance = DESIRED_ZOOM
    else
        LocalPlayer.CameraMinZoomDistance = 0.5
        LocalPlayer.CameraMaxZoomDistance = 400
    end
end

-- ============================
-- SPIN
-- ============================
local function updateSpin()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    if Settings.Spin then
        humanoid.AutoRotate = false
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

        if not spinConnection then
            spinConnection = RunService.RenderStepped:Connect(function()
                if hrp and humanoid then
                    spinAngle = (spinAngle + SPIN_SPEED) % 360
                    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(spinAngle), 0)
                    
                    local state = humanoid:GetState()
                    if state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Ragdoll then
                        humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end)
        end
    else
        if spinConnection then
            spinConnection:Disconnect()
            spinConnection = nil
        end
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        humanoid.AutoRotate = true
    end
end

-- ============================
-- WALLCAM
-- ============================
local function getEnemyPlayers()
    local enemies = {}
    local myTeam = LocalPlayer.Team
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        
        if myTeam and p.Team and p.Team == myTeam then 
            continue 
        end
        
        local char = p.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                table.insert(enemies, p)
            end
        end
    end
    return enemies
end

local function selectNewEnemyTarget()
    if targetHumanoidDiedConnection then
        targetHumanoidDiedConnection:Disconnect()
        targetHumanoidDiedConnection = nil
    end

    local enemies = getEnemyPlayers()
    if #enemies > 0 then
        targetEnemyPlayer = enemies[math.random(1, #enemies)]
        local enemyHumanoid = targetEnemyPlayer.Character and targetEnemyPlayer.Character:FindFirstChildOfClass("Humanoid")
        if enemyHumanoid then
            targetHumanoidDiedConnection = enemyHumanoid.Died:Connect(function()
                task.wait(0.1)
                selectNewEnemyTarget()
            end)
        end
    else
        targetEnemyPlayer = nil
    end
end

local function makeOriginalInvisible()
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Decal") then
            part.LocalTransparencyModifier = 1
        end
    end
end

local function setWallCam(state)
    wallCamEnabled = state

    if wallCamEnabled then
        selectNewEnemyTarget()
        
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Scriptable
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter

        if wallCamConnection then
            wallCamConnection:Disconnect()
            wallCamConnection = nil
        end

        wallCamConnection = RunService.RenderStepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            local rootPart = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not rootPart or not humanoid then return end

            if not targetEnemyPlayer or not targetEnemyPlayer.Character or not targetEnemyPlayer.Character:FindFirstChild("HumanoidRootPart") or targetEnemyPlayer.Character.Humanoid.Health <= 0 then
                selectNewEnemyTarget()
            end

            if not targetEnemyPlayer then return end

            local enemyHeadPosition = nil
            local enemyChar = targetEnemyPlayer.Character
            if enemyChar then
                local head = enemyChar:FindFirstChild("Head")
                local hrp = enemyChar:FindFirstChild("HumanoidRootPart")
                if head then
                    enemyHeadPosition = head.Position
                elseif hrp then
                    enemyHeadPosition = hrp.Position + Vector3.new(0, 1.5, 0)
                end
            end

            if not enemyHeadPosition then return end

            makeOriginalInvisible()

            local cameraFocusPoint = enemyHeadPosition
            local rotationCFrame = CFrame.Angles(0, math.rad(cameraRotationX), 0) * CFrame.Angles(math.rad(cameraRotationY), 0, 0)
            local cameraRelativeOffset = Vector3.new(0, 0, CAMERA_DISTANCE)
            local targetCameraPosition = cameraFocusPoint + (rotationCFrame * cameraRelativeOffset)

            local cam = workspace.CurrentCamera
            cam.CFrame = CFrame.new(targetCameraPosition, cameraFocusPoint)

            rootPart.CFrame = CFrame.new(enemyHeadPosition) + Vector3.new(0, SKY_HEIGHT, 0)
            rootPart.AssemblyLinearVelocity = Vector3.zero
        end)

    else
        if wallCamConnection then
            wallCamConnection:Disconnect()
            wallCamConnection = nil
        end
        if targetHumanoidDiedConnection then
            targetHumanoidDiedConnection:Disconnect()
            targetHumanoidDiedConnection = nil
        end
        targetEnemyPlayer = nil

        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Custom
        UIS.MouseBehavior = Enum.MouseBehavior.Default

        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") then
                    part.LocalTransparencyModifier = 0
                end
            end
        end
    end
end

UIS.InputChanged:Connect(function(input, processed)
    if processed then return end
    if not wallCamEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        cameraRotationX = cameraRotationX - input.Delta.X * MOUSE_SENSITIVITY
        cameraRotationY = math.clamp(cameraRotationY - input.Delta.Y * MOUSE_SENSITIVITY, -85, 85)
    end
end)

Players.PlayerAdded:Connect(function()
    if wallCamEnabled then selectNewEnemyTarget() end
end)

-- ============================
-- ESP
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

local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local upperTorso = char:FindFirstChild("UpperTorso")
    if not upperTorso then return false end
    local status = player:FindFirstChild("Status")
    if not status then return false end
    local team = status:FindFirstChild("Team")
    if not team or team.Value == "Spectator" then return false end
    local localStatus = LocalPlayer:FindFirstChild("Status")
    if not localStatus then return false end
    local localTeam = localStatus:FindFirstChild("Team")
    if not localTeam then return false end
    if team.Value == localTeam.Value then return false end
    local alive = status:FindFirstChild("Alive")
    if not alive or not alive.Value then return false end
    return true
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
    if player.Team == LocalPlayer.Team then return end
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
end

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
end

local function setupPlayer(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function()
        task.wait(0.2)
        addESP(player)
    end)
    player:GetPropertyChangedSignal("Team"):Connect(function()
        addESP(player)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(removeESP)

-- ============================
-- TRAIL
-- ============================
local function createRayTrail(origin, targetPos, color)
    if not trailEnabled then return end

    local direction = (targetPos - origin)
    local distance = direction.Magnitude

    if distance < 1 then return end

    local part = Instance.new("Part")
    part.Name = "RayTrail"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.Neon
    part.Color = color or trailColor
    part.Transparency = 0
    part.Size = Vector3.new(0.05, 0.05, distance)
    part.CFrame = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -distance / 2)
    part.Parent = Workspace

    local glow = Instance.new("PointLight")
    glow.Color = part.Color
    glow.Range = 4
    glow.Brightness = 1.5
    glow.Parent = part

    task.spawn(function()
        local startTime = tick()
        local duration = trailDuration

        while part.Parent and tick() - startTime < duration do
            local alpha = 1 - (tick() - startTime) / duration
            part.Transparency = 1 - alpha
            if glow then
                glow.Brightness = 1.5 * alpha
                glow.Range = 4 * alpha
            end
            task.wait()
        end

        part:Destroy()
    end)
end

-- ============================
-- ВЫСТРЕЛЫ
-- ============================
local function getAimTarget()
    if dddEnabled and target then
        return target.Position
    else
        local cam = Workspace.CurrentCamera
        if not cam then return nil end

        local origin = cam.CFrame.Position
        local direction = cam.CFrame.LookVector * 500

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LocalPlayer.Character}
        params.IgnoreWater = true

        local result = Workspace:Raycast(origin, direction, params)
        return result and result.Position or (origin + direction)
    end
end

local function onShoot()
    if not trailEnabled then return end

    local cam = Workspace.CurrentCamera
    if not cam then return end

    local origin = cam.CFrame.Position
    local targetPos = getAimTarget()

    if targetPos then
        createRayTrail(origin, targetPos, trailColor)
    end
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        task.spawn(onShoot)
    end
end)

local oldActivate
pcall(function()
    oldActivate = hookfunction(Instance.new("Tool").Activate, function(self)
        if trailEnabled then
            task.spawn(onShoot)
        end
        return oldActivate(self)
    end)
end)

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
    humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            createJumpRing(root.Position)
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.3)
    setupJumpDetection()
end)

setupJumpDetection()

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
        if Settings.Bhop and spaceHeld and humanoid and humanoid.Health > 0 then
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
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
        task.spawn(onShoot)
    end

    if VIM then
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.015)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        task.spawn(onShoot)
    end
end

-- ============================
-- DDD (SILENT AIM)
-- ============================
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
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp or not hrp:IsA("BasePart") then continue end
        local head = char:FindFirstChild("Head")
        if not head or not head:IsA("BasePart") then continue end
        local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
        if onScreen then
            local distance = (Vector2.new(screenPos.X, screenPos.Y) - camera.ViewportSize / 2).Magnitude
            if distance < closestDistance and distance < aimFOV then
                if not isVisible(head) then continue end
                closestDistance = distance
                closest = head
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if dddEnabled then
        target = getClosestPlayer()
    else
        target = nil
    end
    doAutofire()
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
    local s = math.clamp(Settings.Darkness, 0, 1)
    Lighting.ClockTime = 0
    Lighting.Brightness = math.max(0.05, original.Brightness * (1 - 0.9 * s))
    Lighting.Ambient = original.Ambient:Lerp(Color3.fromRGB(8, 8, 18), s)
    Lighting.OutdoorAmbient = original.OutdoorAmbient:Lerp(Color3.fromRGB(5, 5, 12), s)
end

-- ============================
-- НАСТРОЙКИ ДЛЯ RAYFIELD
-- ============================
local Settings = {
    ESP = false,
    HP = false,
    Night = false,
    Darkness = 0.7,
    Ddd = false,
    JumpTrail = false,
    Autofire = false,
    Bhop = false,
    Trail = false,
    Zoom = false,
    Spin = false
}

-- ============================
-- RAYFIELD UI
-- ============================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "SWILL | MENU",
   LoadingTitle = "Загрузка...",
   LoadingSubtitle = "by SWILL",
   ConfigurationSaving = {
      Enabled = false,
   },
   Discord = {
      Enabled = false,
   },
   KeySystem = false
})

-- === TAB: COMBAT ===
local CombatTab = Window:CreateTab("Combat", 4483362458)
local CombatSection = CombatTab:CreateSection("Aim")

CombatTab:CreateToggle({
   Name = "Ddd (Silent Aim)",
   CurrentValue = false,
   Flag = "DddToggle",
   Callback = function(Value)
       dddEnabled = Value
   end,
})

CombatTab:CreateToggle({
   Name = "Autofire",
   CurrentValue = false,
   Flag = "AutofireToggle",
   Callback = function(Value)
       autofireEnabled = Value
   end,
})

CombatTab:CreateSlider({
   Name = "Aim FOV",
   Range = {20, 1000},
   Increment = 25,
   Suffix = "°",
   CurrentValue = 200,
   Flag = "AimFOVSlider",
   Callback = function(Value)
       aimFOV = Value
   end,
})

-- === TAB: VISUALS ===
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local VisualsSection = VisualsTab:CreateSection("ESP")

VisualsTab:CreateToggle({
   Name = "ESP",
   CurrentValue = false,
   Flag = "ESPToggle",
   Callback = function(Value)
       Settings.ESP = Value
       espEnabled = Value
       updateESP()
   end,
})

VisualsTab:CreateToggle({
   Name = "HP Bar",
   CurrentValue = false,
   Flag = "HPToggle",
   Callback = function(Value)
       Settings.HP = Value
       hpEnabled = Value
       updateESP()
   end,
})

VisualsTab:CreateToggle({
   Name = "Trail (след пули)",
   CurrentValue = false,
   Flag = "TrailToggle",
   Callback = function(Value)
       Settings.Trail = Value
       trailEnabled = Value
   end,
})

VisualsTab:CreateToggle({
   Name = "Jump Trail",
   CurrentValue = false,
   Flag = "JumpTrailToggle",
   Callback = function(Value)
       Settings.JumpTrail = Value
       jumpTrailEnabled = Value
   end,
})

VisualsTab:CreateToggle({
   Name = "Spin",
   CurrentValue = false,
   Flag = "SpinToggle",
   Callback = function(Value)
       Settings.Spin = Value
       updateSpin()
   end,
})

VisualsTab:CreateSlider({
   Name = "Spin Speed",
   Range = {1, 30},
   Increment = 1,
   Suffix = "°",
   CurrentValue = 25,
   Flag = "SpinSpeedSlider",
   Callback = function(Value)
       SPIN_SPEED = Value
   end,
})

-- === TAB: CAMERA ===
local CameraTab = Window:CreateTab("Camera", 4483362458)
local CameraSection = CameraTab:CreateSection("Zoom / FOV")

CameraTab:CreateToggle({
   Name = "Zoom (отдаление)",
   CurrentValue = false,
   Flag = "ZoomToggle",
   Callback = function(Value)
       Settings.Zoom = Value
       applyZoom()
   end,
})

CameraTab:CreateSlider({
   Name = "Zoom Distance",
   Range = {5, 150},
   Increment = 5,
   Suffix = "m",
   CurrentValue = 30,
   Flag = "ZoomSlider",
   Callback = function(Value)
       DESIRED_ZOOM = Value
       if Settings.Zoom then applyZoom() end
   end,
})

CameraTab:CreateSlider({
   Name = "Camera FOV",
   Range = {1, 120},
   Increment = 1,
   Suffix = "°",
   CurrentValue = 70,
   Flag = "CamFOVSlider",
   Callback = function(Value)
       cameraFOV = Value
       updateCameraFOV()
   end,
})

-- === TAB: WALLCAM ===
local WallCamTab = Window:CreateTab("WallCam", 4483362458)
local WallCamSection = WallCamTab:CreateSection("Слежка")

WallCamTab:CreateToggle({
   Name = "WallCam (камера за врагом)",
   CurrentValue = false,
   Flag = "WallCamToggle",
   Callback = function(Value)
       setWallCam(Value)
   end,
})

-- === TAB: MISC ===
local MiscTab = Window:CreateTab("Misc", 4483362458)
local MiscSection = MiscTab:CreateSection("Прочее")

MiscTab:CreateToggle({
   Name = "Bhop",
   CurrentValue = false,
   Flag = "BhopToggle",
   Callback = function(Value)
       Settings.Bhop = Value
       bhopEnabled = Value
   end,
})

MiscTab:CreateToggle({
   Name = "Night Mode",
   CurrentValue = false,
   Flag = "NightToggle",
   Callback = function(Value)
       Settings.Night = Value
       updateNight()
   end,
})

MiscTab:CreateSlider({
   Name = "Night Darkness",
   Range = {0, 1},
   Increment = 0.05,
   Suffix = "",
   CurrentValue = 0.7,
   Flag = "DarknessSlider",
   Callback = function(Value)
       Settings.Darkness = Value
       if Settings.Night then updateNight() end
   end,
})

-- ============================
-- INIT
-- ============================
task.wait(0.5)
updateESP()
applyZoom()
updateSpin()
updateCameraFOV()
updateNight()

Rayfield:Notify({
   Title = "Готово!",
   Content = "Нажми K (английскую), чтобы открыть меню.",
   Duration = 5,
   Image = 4483362458,
})