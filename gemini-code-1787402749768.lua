-- ============================================
-- SWILL | FULL SCRIPT (TRACERS & ESP FIXED)
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
local aimPartOption = "Head"
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

-- TRACERS (РЕАЛЬНЫЕ ТРЕЙСЕРЫ ПУЛЬ)
local tracersEnabled = false
local tracerThickness = 2
local tracerLifetime = 0.4

-- JUMP PUDDLE (ЛУЖА ПРИ ПРЫЖКЕ)
local jumpPuddleEnabled = false
local puddleMaxSize = 12
local puddleDuration = 0.8

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
-- ТОЧНЫЕ ТРЕЙСЕРЫ ПУЛЬ (ПРИ ВЫСТРЕЛЕ)
-- ============================
local function drawRealTracer(fromPos, toPos)
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
            pcall(function()
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
            end)
            RunService.RenderStepped:Wait()
        end
        pcall(function() line:Remove() end)
    end)
end

-- Отслеживание реальных выстрелов игрока
local function hookTool(tool)
    if not tool:IsA("Tool") then return end
    tool.Activated:Connect(function()
        if not tracersEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        
        local muzzle = tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Handle") or char:FindFirstChild("Head")
        local fromPos = muzzle and muzzle.Position or Camera.CFrame.Position
        
        -- Пускаем луч вперед от камеры/оружия, чтобы найти точку попадания пули
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {char}
        rayParams.IgnoreWater = true
        
        local direction = Camera.CFrame.LookVector * 1000
        local result = Workspace:Raycast(Camera.CFrame.Position, direction, rayParams)
        
        local toPos = result and result.Position or (Camera.CFrame.Position + direction)
        drawRealTracer(fromPos, toPos)
    end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(hookTool)
end)
if LocalPlayer.Character then
    for _, item in ipairs(LocalPlayer.Character:GetChildren()) do hookTool(item) end
    LocalPlayer.Character.ChildAdded:Connect(hookTool)
end

-- ============================
-- ЭФФЕКТ ЛУЖИ ПРИ ПРЫЖКЕ
-- ============================
local function spawnJumpPuddle(hrp)
    if not jumpPuddleEnabled or not hrp then return end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Players.LocalPlayer.Character}
    local result = Workspace:Raycast(hrp.Position, Vector3.new(0, -10, 0), params)
    local pos = result and result.Position or (hrp.Position - Vector3.new(0, 3, 0))

    local circle = Instance.new("Part")
    circle.Anchored = true
    circle.CanCollide = false
    circle.Shape = Enum.PartType.Cylinder
    circle.Size = Vector3.new(0.05, 1, 1)
    circle.CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
    circle.Material = Enum.Material.Neon
    circle.Color = espRGB and getRainbowColor() or espColor
    circle.Parent = Workspace

    task.spawn(function()
        local startTime = tick()
        while tick() - startTime < puddleDuration do
            local elapsed = tick() - startTime
            local progress = elapsed / puddleDuration
            local currentSize = math.lerp(1, puddleMaxSize, progress)
            circle.Size = Vector3.new(0.05, currentSize, currentSize)
            circle.Transparency = progress
            circle.Color = espRGB and getRainbowColor() or espColor
            RunService.RenderStepped:Wait()
        end
        circle:Destroy()
    end)
end

local function monitorCharacter(char, player)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    hum.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            task.delay(0.25, function()
                if hrp and hrp.Parent then
                    spawnJumpPuddle(hrp)
                end
            end)
        end
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
-- ESP (ИСПРАВЛЕНО ДЛЯ ВСЕХ ИГРОКОВ)
-- ============================
local function removeESP(player)
    if espObjects[player] then
        pcall(function()
            espObjects[player].Box:Remove()
            espObjects[player].Text:Remove()
        end)
        espObjects[player] = nil
    end
    if espHighlights[player] then
        pcall(function() espHighlights[player]:Destroy() end)
        espHighlights[player] = nil
    end
end

local function updateESP()
    local activeColor = espRGB and getRainbowColor() or espColor

    if not espEnabled then
        for player in pairs(espObjects) do removeESP(player) end
        return
    end

    local myChar = LocalPlayer.Character
    local myHRP = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Head"))

    for _, player in ipairs(Players:GetPlayers()) do
        if not isEnemy(player) then
            removeESP(player)
            continue
        end

        local char = player.Character
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if char and hum and hum.Health > 0 then
            -- Проверяем и обновляем подсветку (Fill)
            if espShowFill then
                if not espHighlights[player] or espHighlights[player].Parent ~= char then
                    if espHighlights[player] then espHighlights[player]:Destroy() end
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

            -- Отрисовка боксов и текста
            if hrp and Drawing and Drawing.new then
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
        else
            removeESP(player)
        end
    end
end

RunService.RenderStepped:Connect(updateESP)
Players.PlayerRemoving:Connect(removeESP)

-- ============================
-- FOV КРУГ И СТРЕЛЬБА
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
-- NIGHTMODE, BHOP, SPIN, ZOOM
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
    Callback = function(v) aimPartOption = v end
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
    Callback = function(v) espColor = v end
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
    Callback = function(v) tracersEnabled = v end
})

ESPTab:CreateSlider({
    Name = "Толщина трейсеров",
    Range = {1, 10},
    Increment = 1,
    Suffix = "px",
    CurrentValue = 2,
    Flag = "TracerThicknessSlider",
    Callback = function(v) tracerThickness = v end
})

ESPTab:CreateToggle({
    Name = "RGB Радуга ESP",
    CurrentValue = false,
    Flag = "ESPRGB",
    Callback = function(v) espRGB = v end
})

ESPTab:CreateSlider({
    Name = "Скорость RGB",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 1,
    Flag = "ESPRGBSpeed",
    Callback = function(v) espRGBspeed = v end
})

ESPTab:CreateColorPicker({
    Name = "Цвет ESP",
    Color = Color3.fromRGB(255, 0, 80),
    Flag = "ESPColorPicker",
    Callback = function(v) espColor = v end
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
    Range = {2, 25},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 12,
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
    Callback = function(v) cameraFOV = v end
})

Rayfield:Notify({
    Title = "Готово",
    Content = "Трейсеры выстрелов и ESP успешно обновлены!",
    Duration = 3,
    Image = 4483362458,
})