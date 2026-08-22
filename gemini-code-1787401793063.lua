-- ============================================
-- SWILL | FULL SCRIPT (FIXED VERSION)
-- DDD + ESP (Box, Fill, Tracers, RGB) + Jump Puddle + NightMode + WallCam + Bhop + Spin + Zoom
-- ============================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local CanHook = type(hookfunction) == "function" or hookfunction ~= nil

-- ============================
-- НАСТРОЙКИ
-- ============================
local dddEnabled = false
local aimPartOption = "Head" -- "Head" или "Torso"
local autofireEnabled = false
local triggerbotEnabled = false
local aimFOV = 200
local drawFOV = false
local fovCircle = nil
local target = nil
local lastFire = 0
local fireDelay = 0.03
local espColor = Color3.fromRGB(255, 0, 80)

-- ESP
local espEnabled = false
local espShowBox = true
local espShowName = true
local espShowDist = true
local espShowFill = false
local espFillTransparency = 0.5
local espRGB = false
local espRGBspeed = 1
local espObjects = {}
local espHighlights = {}

-- TRACERS (СЛЕДЫ ОТ ПУЛЬ)
local tracersEnabled = false
local tracerThickness = 2
local tracerLifetime = 0.35

-- JUMP PUDDLE (ЛУЖА ПРИ ПРЫЖКЕ)
local jumpPuddleEnabled = false
local puddleMaxSize = 8 -- Максимальный размер (радиус)
local puddleDuration = 0.8 -- Время жизни лужи в секундах

-- NIGHTMODE
local nightModeEnabled = false
local nightBrightness = 0.5

-- BHOP
local bhopEnabled = false
local spaceHeld = false
local humanoid = nil

-- SPIN
local spinEnabled = false
local SPIN_SPEED = 25
local spinConnection = nil

-- ZOOM
local zoomEnabled = false
local DESIRED_ZOOM = 30
local zoomConnection = nil

-- FOV КАМЕРЫ
local cameraFOV = 70

-- WALLCAM
local wallCamEnabled = false
local targetPlayer = nil
local targetHumanoidDiedConnection = nil
local cameraRotationX = 0
local cameraRotationY = 0
local SKY_HEIGHT = 1000
local CAMERA_DISTANCE = 5
local MOUSE_SENSITIVITY = 0.5
local wallCamConnection = nil
local savedCFrame = nil

-- ============================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================
local function getRainbowColor()
    local hue = (tick() * espRGBspeed) % 1
    return Color3.fromHSV(hue, 1, 1)
end

local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    
    if LocalPlayer.Team and player.Team then
        if player.Team == LocalPlayer.Team then
            return false
        end
    end
    return true
end

local function isVisible(targetPart)
    if not targetPart or not targetPart:IsA("BasePart") then return false end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true
    local result = Workspace:Raycast(origin, direction, params)
    if result then
        local model = result.Instance:FindFirstAncestorOfClass("Model")
        if model and Players:GetPlayerFromCharacter(model) then return true end
        return false
    end
    return true
end

local function getClosestPlayerInFOV()
    local closestDistance = math.huge
    local closest = nil
    local center = Camera.ViewportSize / 2

    for _, player in ipairs(Players:GetPlayers()) do
        if not isEnemy(player) then continue end
        local char = player.Character
        if not char then continue end
        
        local hitPart = nil
        if aimPartOption == "Head" then
            hitPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        else
            hitPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        end
        
        if not hitPart then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(hitPart.Position)
        if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            if dist < closestDistance and dist <= aimFOV then
                if isVisible(hitPart) then
                    closestDistance = dist
                    closest = hitPart
                    target = hitPart
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if dddEnabled then getClosestPlayerInFOV() end
end)

-- ============================
-- ЭФФЕКТ ЛУЖИ ПРИ ПРЫЖКЕ
-- ============================
local function spawnJumpPuddle(pos)
    if not jumpPuddleEnabled then return end
    
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Position = pos - Vector3.new(0, 2.5, 0) -- Чуть ниже ног
    part.Parent = Workspace

    local att = Instance.new("Attachment", part)
    local pui = Instance.new("Highlight")
    pui.Parent = part

    -- Создаем круглую декаль-лужу или кольцо через ParticleEmitter / Cylinder
    local cylinder = Instance.new("Part")
    cylinder.Anchored = true
    cylinder.CanCollide = false
    cylinder.Shape = Enum.PartType.Cylinder
    cylinder.Size = Vector3.new(0.05, 0.1, 0.1)
    cylinder.CFrame = CFrame.new(pos - Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, 0, math.rad(90))
    cylinder.Material = Enum.Material.Neon
    cylinder.Color = espRGB and getRainbowColor() or espColor
    cylinder.Parent = Workspace

    task.spawn(function()
        local startTime = tick()
        while tick() - startTime < puddleDuration do
            local elapsed = tick() - startTime
            local progress = elapsed / puddleDuration
            
            local currentSize = math.lerp(0.5, puddleMaxSize, progress)
            cylinder.Size = Vector3.new(0.05, currentSize, currentSize)
            cylinder.Transparency = math.clamp(progress, 0, 1)
            cylinder.Color = espRGB and getRainbowColor() or espColor
            
            RunService.RenderStepped:Wait()
        end
        cylinder:Destroy()
        part:Destroy()
    end)
end

-- Отслеживание приземления игроков для лужи
local trackedHumanoids = {}

local function monitorCharacter(char, player)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local wasInAir = false
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not char or not char.Parent or hum.Health <= 0 then
            if conn then conn:Disconnect() end
            return
        end

        local isInAir = (hum.FloorMaterial == Enum.Material.Air)
        if wasInAir and not isInAir then
            -- Приземлился!
            spawnJumpPuddle(hrp.Position)
        end
        wasInAir = isInAir
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then monitorCharacter(p.Character, p) end
    p.CharacterAdded:Connect(function(c) monitorCharacter(c, p) end)
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c) monitorCharacter(c, p) end)
end)

-- ============================
-- СОЗДАНИЕ ТРЕЙСЕРОВ ПУЛЬ
-- ============================
local function createBulletTracer(fromPos, toPos)
    if not tracersEnabled or not Drawing or not Drawing.new then return end
    
    local line = Drawing.new("Line")
    line.Thickness = tracerThickness
    line.Color = espRGB and getRainbowColor() or espColor
    line.Transparency = 1
    line.Visible = true

    task.spawn(function()
        local startTime = tick()
        while tick() - startTime < tracerLifetime do
            local activeColor = espRGB and getRainbowColor() or espColor
            line.Color = activeColor
            line.Thickness = tracerThickness

            local p1, onScreen1 = Camera:WorldToViewportPoint(fromPos)
            local p2, onScreen2 = Camera:WorldToViewportPoint(toPos)

            if onScreen1 or onScreen2 then
                line.From = Vector2.new(p1.X, p1.Y)
                line.To = Vector2.new(p2.X, p2.Y)
                line.Visible = true
            else
                line.Visible = false
            end
            RunService.RenderStepped:Wait()
        end
        line:Remove()
    end)
end

-- ============================
-- DDD (SILENT AIM)
-- ============================
local oldRay
if CanHook then
    local raySuccess, rayError = pcall(function()
        oldRay = hookfunction(Ray.new, function(origin, direction)
            local trace = debug.traceback()
            if dddEnabled and target and target:IsA("BasePart") then
                if trace:find("Client") and not trace:find("10420") and not trace:find("10595") then
                    local newDir = (target.Position - origin).Unit * direction.Magnitude
                    createBulletTracer(origin, origin + newDir)
                    return oldRay(origin, newDir)
                end
            end
            return oldRay(origin, direction)
        end)
    end)
    if not raySuccess then warn("DDD error: " .. tostring(rayError)) end
else
    warn("Внимание: hookfunction не поддерживается.")
end

-- ============================
-- FOV КРУГ
-- ============================
local function createFOVCircle()
    if fovCircle then pcall(function() fovCircle:Remove() end) fovCircle = nil end
    if not drawFOV then return end
    
    if Drawing and Drawing.new then
        fovCircle = Drawing.new("Circle")
        fovCircle.Radius = aimFOV
        fovCircle.Thickness = 2
        fovCircle.Color = espColor
        fovCircle.Transparency = 1
        fovCircle.Filled = false
        fovCircle.Visible = true
    end
end

RunService.RenderStepped:Connect(function()
    local activeColor = espRGB and getRainbowColor() or espColor
    if drawFOV then
        if not fovCircle then createFOVCircle() else
            local center = Camera.ViewportSize / 2
            fovCircle.Position = Vector2.new(center.X, center.Y)
            fovCircle.Radius = aimFOV
            fovCircle.Color = activeColor
        end
    elseif fovCircle then
        pcall(function() fovCircle:Remove() end)
        fovCircle = nil
    end
end)

-- ============================
-- ФУНКЦИЯ СТРЕЛЬБЫ
-- ============================
local function shoot()
    local now = tick()
    if now - lastFire >= fireDelay then
        lastFire = now
        local char = LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end
        end
        if VIM then
            VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait(0.015)
            VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end
    end
end

RunService.RenderStepped:Connect(function()
    if not autofireEnabled then return end
    local targetHead = getClosestPlayerInFOV()
    if targetHead then shoot() end
end)

RunService.RenderStepped:Connect(function()
    if not triggerbotEnabled then return end
    local targetHead = getClosestPlayerInFOV()
    if not targetHead then return end
    
    local center = Camera.ViewportSize / 2
    local screenPos, onScreen = Camera:WorldToViewportPoint(targetHead.Position)
    if not onScreen then return end
    
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    if dist > aimFOV then return end
    if not isVisible(targetHead) then return end
    
    shoot()
end)

-- ============================
-- ESP (RGB + HIGHLIGHT)
-- ============================
local function removeESP(player)
    if espObjects[player] then
        pcall(function()
            espObjects[player].Box:Remove()
            espObjects[player].Text:Remove()
        end)
        espObjects[player] = nil
    end
end

local function updateESP()
    local activeColor = espRGB and getRainbowColor() or espColor

    if not espEnabled then
        for player in pairs(espObjects) do removeESP(player) end
        for player, h in pairs(espHighlights) do h:Destroy() end
        espHighlights = {}
        return
    end

    local myChar = LocalPlayer.Character
    local myHRP = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Head"))

    for _, player in ipairs(Players:GetPlayers()) do
        if not isEnemy(player) then
            removeESP(player)
            if espHighlights[player] then espHighlights[player]:Destroy() espHighlights[player] = nil end
            continue
        end

        local char = player.Character
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if char then
            if espShowFill then
                if not espHighlights[player] then
                    local h = Instance.new("Highlight")
                    h.Parent = char
                    h.FillColor = activeColor
                    h.OutlineColor = Color3.new(1, 1, 1)
                    h.FillTransparency = espFillTransparency
                    espHighlights[player] = h
                else
                    espHighlights[player].FillColor = activeColor
                    espHighlights[player].FillTransparency = espFillTransparency
                end
            else
                if espHighlights[player] then
                    espHighlights[player]:Destroy()
                    espHighlights[player] = nil
                end
            end
        else
            if espHighlights[player] then
                espHighlights[player]:Destroy()
                espHighlights[player] = nil
            end
        end

        if hrp and hum and hum.Health > 0 and Drawing and Drawing.new then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

            if onScreen then
                if not espObjects[player] then
                    local box = Drawing.new("Square")
                    box.Thickness = 2
                    box.Filled = false
                    box.Transparency = 1
                    box.Color = activeColor

                    local text = Drawing.new("Text")
                    text.Size = 13
                    text.Center = true
                    text.Outline = true
                    text.Color = Color3.fromRGB(255, 255, 255)
                    text.Transparency = 1

                    espObjects[player] = {Box = box, Text = text}
                end

                local scale = 1000 / pos.Z
                local width = math.clamp(scale, 15, 200)
                local height = width * 1.5

                local box = espObjects[player].Box
                box.Visible = espShowBox
                box.Color = activeColor
                box.Size = Vector2.new(width, height)
                box.Position = Vector2.new(pos.X - width / 2, pos.Y - height / 2)

                local textStr = ""
                if espShowName then textStr = textStr .. (player.DisplayName or player.Name) .. "\n" end
                if espShowDist and myHRP then
                    local dist = math.floor((myHRP.Position - hrp.Position).Magnitude)
                    textStr = textStr .. string.format("[%d m]", dist)
                end

                local text = espObjects[player].Text
                text.Visible = (textStr ~= "")
                text.Text = textStr
                text.Position = Vector2.new(pos.X, pos.Y + height / 2 + 2)
            else
                if espObjects[player] then
                    espObjects[player].Box.Visible = false
                    espObjects[player].Text.Visible = false
                end
            end
        else
            removeESP(player)
        end
    end
end

RunService.RenderStepped:Connect(updateESP)
Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    if espHighlights[player] then
        espHighlights[player]:Destroy()
        espHighlights[player] = nil
    end
end)

-- ============================
-- NIGHTMODE
-- ============================
RunService.RenderStepped:Connect(function()
    if nightModeEnabled then
        Lighting.Brightness = nightBrightness
        Lighting.ClockTime = 0
        Lighting.FogEnd = 999999
    else
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
    end
end)

-- ============================
-- BHOP
-- ============================
local function setupBhop()
    local char = LocalPlayer.Character
    if not char then return end
    humanoid = char:FindFirstChildOfClass("Humanoid")
end

UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then spaceHeld = true end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then spaceHeld = false end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.3)
    setupBhop()
end)
setupBhop()

task.spawn(function()
    while true do
        task.wait()
        if bhopEnabled and spaceHeld and humanoid and humanoid.Health > 0 then
            if humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

-- ============================
-- SPIN & ZOOM & FOV
-- ============================
local function updateSpin()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if spinEnabled then
        hum.AutoRotate = false
        if not spinConnection then
            spinConnection = RunService.RenderStepped:Connect(function()
                if hrp and hum then
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(SPIN_SPEED), 0)
                end
            end)
        end
    else
        if spinConnection then
            spinConnection:Disconnect()
            spinConnection = nil
        end
        hum.AutoRotate = true
    end
end

local function updateZoom()
    if zoomEnabled then
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMinZoomDistance = DESIRED_ZOOM
        LocalPlayer.CameraMaxZoomDistance = DESIRED_ZOOM
        if not zoomConnection then
            zoomConnection = RunService.RenderStepped:Connect(function()
                if zoomEnabled then
                    LocalPlayer.CameraMode = Enum.CameraMode.Classic
                    LocalPlayer.CameraMinZoomDistance = DESIRED_ZOOM
                    LocalPlayer.CameraMaxZoomDistance = DESIRED_ZOOM
                end
            end)
        end
    else
        if zoomConnection then
            zoomConnection:Disconnect()
            zoomConnection = nil
        end
        LocalPlayer.CameraMinZoomDistance = 0.5
        LocalPlayer.CameraMaxZoomDistance = 400
    end
end

RunService.RenderStepped:Connect(function()
    if cameraFOV ~= 70 then Camera.FieldOfView = cameraFOV end
end)

-- ============================
-- WALLCAM
-- ============================
local function getAllPlayers()
    local players = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local char = p.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then table.insert(players, p) end
            end
        end
    end
    return players
end

local function selectNewTarget()
    if targetHumanoidDiedConnection then
        targetHumanoidDiedConnection:Disconnect()
        targetHumanoidDiedConnection = nil
    end
    local players = getAllPlayers()
    if #players > 0 then
        targetPlayer = players[math.random(1, #players)]
        local targetHumanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if targetHumanoid then
            targetHumanoidDiedConnection = targetHumanoid.Died:Connect(function()
                task.wait(0.1)
                selectNewTarget()
            end)
        end
    else
        targetPlayer = nil
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

local function toggleWallCam()
    wallCamEnabled = not wallCamEnabled

    if wallCamEnabled then
        selectNewTarget()
        
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Scriptable
        UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
        
        local char = LocalPlayer.Character
        local rootPart = char and char:FindFirstChild("HumanoidRootPart")
        if rootPart then savedCFrame = rootPart.CFrame end

        if wallCamConnection then wallCamConnection:Disconnect() wallCamConnection = nil end

        wallCamConnection = RunService.RenderStepped:Connect(function()
            local c = LocalPlayer.Character
            if not c then return end
            local rp = c:FindFirstChild("HumanoidRootPart")
            local h = c:FindFirstChildOfClass("Humanoid")
            if not rp or not h then return end

            if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") or targetPlayer.Character.Humanoid.Health <= 0 then
                selectNewTarget()
            end
            if not targetPlayer then return end

            local targetHeadPosition = nil
            local targetChar = targetPlayer.Character
            if targetChar then
                local head = targetChar:FindFirstChild("Head")
                local thrrp = targetChar:FindFirstChild("HumanoidRootPart")
                if head then targetHeadPosition = head.Position
                elseif thrrp then targetHeadPosition = thrrp.Position + Vector3.new(0, 1.5, 0) end
            end

            if not targetHeadPosition then return end

            makeOriginalInvisible()

            local cameraFocusPoint = targetHeadPosition
            local rotationCFrame = CFrame.Angles(0, math.rad(cameraRotationX), 0) * CFrame.Angles(math.rad(cameraRotationY), 0, 0)
            local cameraRelativeOffset = Vector3.new(0, 0, CAMERA_DISTANCE)
            local targetCameraPosition = cameraFocusPoint + (rotationCFrame * cameraRelativeOffset)

            workspace.CurrentCamera.CFrame = CFrame.new(targetCameraPosition, cameraFocusPoint)

            rp.CFrame = CFrame.new(targetHeadPosition) + Vector3.new(0, SKY_HEIGHT, 0)
            rp.AssemblyLinearVelocity = Vector3.zero
        end)

    else
        if wallCamConnection then wallCamConnection:Disconnect() wallCamConnection = nil end
        if targetHumanoidDiedConnection then targetHumanoidDiedConnection:Disconnect() targetHumanoidDiedConnection = nil end
        targetPlayer = nil

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
            if savedCFrame then
                local rp = char:FindFirstChild("HumanoidRootPart")
                if rp then rp.CFrame = savedCFrame end
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
    if wallCamEnabled then selectNewTarget() end
end)

-- ============================
-- RAYFIELD UI
-- ============================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then return end

local Window = Rayfield:CreateWindow({
    Name = "SWILL | MENU",
    LoadingTitle = "Загрузка...",
    LoadingSubtitle = "by SWILL",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

-- TAB: БОЙ
local CombatTab = Window:CreateTab("Бой", 4483362458)

CombatTab:CreateToggle({
    Name = CanHook and "DDD (Silent Aim)" or "DDD (Silent Aim) [NO WORK]",
    CurrentValue = false,
    Flag = "DDDToggle",
    Callback = function(v) 
        if not CanHook then dddEnabled = false return end
        dddEnabled = v 
    end
})

CombatTab:CreateDropdown({
    Name = "Цель для DDD (Hitbox)",
    Options = {"Head", "Torso"},
    CurrentOption = "Head",
    Flag = "AimPartDropdown",
    Callback = function(v)
        aimPartOption = v
    end
})

CombatTab:CreateToggle({
    Name = "Autofire",
    CurrentValue = false,
    Flag = "AutofireToggle",
    Callback = function(v) autofireEnabled = v end
})

CombatTab:CreateToggle({
    Name = "Triggerbot (Visible + FOV)",
    CurrentValue = false,
    Flag = "TriggerbotToggle",
    Callback = function(v) triggerbotEnabled = v end
})

CombatTab:CreateSlider({
    Name = "Aim FOV",
    Range = {20, 800},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 200,
    Flag = "AimFOVSlider",
    Callback = function(v)
        aimFOV = v
        if drawFOV and fovCircle then fovCircle.Radius = v end
    end
})

CombatTab:CreateToggle({
    Name = "Показать FOV круг",
    CurrentValue = false,
    Flag = "FOVCircleToggle",
    Callback = function(v)
        drawFOV = v
        if v then createFOVCircle() elseif fovCircle then pcall(function() fovCircle:Remove() end) fovCircle = nil end
    end
})

CombatTab:CreateColorPicker({
    Name = "Цвет FOV круга",
    Color = Color3.fromRGB(255, 0, 80),
    Flag = "FOVColorPicker",
    Callback = function(v)
        espColor = v
    end
})

-- TAB: ESP
local ESPTab = Window:CreateTab("ESP", 4483362458)

ESPTab:CreateToggle({
    Name = "Включить ESP",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(v)
        espEnabled = v
        updateESP()
    end
})

ESPTab:CreateToggle({
    Name = "Box",
    CurrentValue = true,
    Flag = "ESPBoxToggle",
    Callback = function(v) espShowBox = v end
})

ESPTab:CreateToggle({
    Name = "Имя",
    CurrentValue = true,
    Flag = "ESPNameToggle",
    Callback = function(v) espShowName = v end
})

ESPTab:CreateToggle({
    Name = "Дистанция",
    CurrentValue = true,
    Flag = "ESPDistToggle",
    Callback = function(v) espShowDist = v end
})

ESPTab:CreateToggle({
    Name = "Заливка (Fill)",
    CurrentValue = false,
    Flag = "ESPFillToggle",
    Callback = function(v) 
        espShowFill = v 
        updateESP()
    end
})

ESPTab:CreateSlider({
    Name = "Прозрачность заливки",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.5,
    Flag = "ESPFillTransparency",
    Callback = function(v) 
        espFillTransparency = v 
        updateESP()
    end
})

ESPTab:CreateToggle({
    Name = "Трейсеры пуль (Tracers)",
    CurrentValue = false,
    Flag = "TracersToggle",
    Callback = function(v)
        tracersEnabled = v
    end
})

ESPTab:CreateSlider({
    Name = "Толщина трейсеров",
    Range = {1, 10},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 2,
    Flag = "TracerThicknessSlider",
    Callback = function(v)
        tracerThickness = v
    end
})

ESPTab:CreateToggle({
    Name = "RGB Радуга ESP",
    CurrentValue = false,
    Flag = "ESPRGB",
    Callback = function(v)
        espRGB = v
    end
})

ESPTab:CreateSlider({
    Name = "Скорость RGB",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 1,
    Flag = "ESPRGBSpeed",
    Callback = function(v)
        espRGBspeed = v
    end
})

ESPTab:CreateColorPicker({
    Name = "Цвет ESP",
    Color = Color3.fromRGB(255, 0, 80),
    Flag = "ESPColorPicker",
    Callback = function(v)
        espColor = v
    end
})

-- TAB: РАЗНОЕ
local MiscTab = Window:CreateTab("Разное", 4483362458)

MiscTab:CreateToggle({
    Name = "Лужа при прыжке (Puddle)",
    CurrentValue = false,
    Flag = "JumpPuddleToggle",
    Callback = function(v) jumpPuddleEnabled = v end
})

MiscTab:CreateSlider({
    Name = "Размер лужи",
    Range = {2, 20},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 8,
    Flag = "PuddleSizeSlider",
    Callback = function(v) puddleMaxSize = v end
})

MiscTab:CreateSlider({
    Name = "Время жизни лужи",
    Range = {0.2, 3},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 0.8,
    Flag = "PuddleDurationSlider",
    Callback = function(v) puddleDuration = v end
})

MiscTab:CreateToggle({
    Name = "NightMode (Ночь)",
    CurrentValue = false,
    Flag = "NightModeToggle",
    Callback = function(v) nightModeEnabled = v end
})

MiscTab:CreateSlider({
    Name = "Яркость NightMode",
    Range = {0, 2},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = 0.5,
    Flag = "NightBrightnessSlider",
    Callback = function(v) nightBrightness = v end
})

MiscTab:CreateToggle({
    Name = "Bhop",
    CurrentValue = false,
    Flag = "BhopToggle",
    Callback = function(v) bhopEnabled = v end
})

MiscTab:CreateToggle({
    Name = "Spin (Крутилка)",
    CurrentValue = false,
    Flag = "SpinToggle",
    Callback = function(v)
        spinEnabled = v
        updateSpin()
    end
})

MiscTab:CreateSlider({
    Name = "Скорость Spin",
    Range = {1, 50},
    Increment = 1,
    Suffix = "°",
    CurrentValue = 25,
    Flag = "SpinSpeedSlider",
    Callback = function(v) SPIN_SPEED = v end
})

MiscTab:CreateToggle({
    Name = "3-е лицо (Zoom)",
    CurrentValue = false,
    Flag = "ZoomToggle",
    Callback = function(v)
        zoomEnabled = v
        updateZoom()
    end
})

MiscTab:CreateSlider({
    Name = "Дистанция 3-го лица",
    Range = {5, 150},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 30,
    Flag = "ZoomDistanceSlider",
    Callback = function(v)
        DESIRED_ZOOM = v
        updateZoom()
    end
})

MiscTab:CreateSlider({
    Name = "Камера FOV",
    Range = {1, 200},
    Increment = 1,
    Suffix = "°",
    CurrentValue = 70,
    Flag = "CameraFOVSlider",
    Callback = function(v)
        cameraFOV = v
    end
})

-- TAB: WALLCAM
local WallCamTab = Window:CreateTab("WallCam", 4483362458)

WallCamTab:CreateToggle({
    Name = "Включить WallCam (Enemies)",
    CurrentValue = false,
    Flag = "WallCamToggle",
    Callback = function(v)
        if v then toggleWallCam() else if wallCamEnabled then toggleWallCam() end end
    end
})

WallCamTab:CreateSlider({
    Name = "Дистанция камеры",
    Range = {1, 20},
    Increment = 0.5,
    Suffix = " studs",
    CurrentValue = 5,
    Flag = "WallCamDistance",
    Callback = function(v) CAMERA_DISTANCE = v end
})

WallCamTab:CreateSlider({
    Name = "Чувствительность мыши",
    Range = {0.1, 2},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = 0.5,
    Flag = "WallCamSensitivity",
    Callback = function(v) MOUSE_SENSITIVITY = v end
})

Rayfield:Notify({
    Title = "Готово",
    Content = "Скрипт полностью обновлен: добавлена лужа при прыжке!",
    Duration = 3,
    Image = 4483362458,
})