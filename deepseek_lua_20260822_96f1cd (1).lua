-- ============================================
-- SWILL | FULL SCRIPT
-- DDD (RAY HOOK) + AUTOFIRE + TRIGGERBOT (VISIBLE + FOV) + ESP + BHOP + SPIN + ZOOM + FOV SLIDER (1-200) + WALLCAM (ALL PLAYERS)
-- ============================================

if not hookfunction then return end

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- ============================
-- НАСТРОЙКИ
-- ============================
local dddEnabled = false
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
local espObjects = {}

-- BHOP
local bhopEnabled = false
local spaceHeld = false
local humanoid = nil

-- SPIN
local spinEnabled = false
local SPIN_SPEED = 25
local spinAngle = 0
local spinConnection = nil

-- ZOOM
local zoomEnabled = false
local DESIRED_ZOOM = 30
local zoomConnection = nil

-- FOV КАМЕРЫ
local cameraFOV = 70

-- WALLCAM (для всех игроков)
local wallCamEnabled = false
local targetPlayer = nil
local targetHumanoidDiedConnection = nil
local cameraRotationX = 0
local cameraRotationY = 0
local SKY_HEIGHT = 1000
local CAMERA_DISTANCE = 5
local MOUSE_SENSITIVITY = 0.5
local wallCamConnection = nil

-- ============================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================
local function isEnemy(player)
    if not player or player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return false end
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
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not head then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
        if onScreen then
            local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            if dist < closestDistance and dist <= aimFOV then
                if isVisible(head) then
                    closestDistance = dist
                    closest = head
                    target = head
                end
            end
        end
    end
    return closest
end

-- ============================
-- DDD (SILENT AIM) ЧЕРЕЗ ПЕРЕХВАТ RAY
-- ============================
local oldRay
local raySuccess, rayError = pcall(function()
    oldRay = hookfunction(Ray.new, function(origin, direction)
        local trace = debug.traceback()
        if dddEnabled and target and target:IsA("BasePart") then
            if trace:find("Client") and not trace:find("10420") and not trace:find("10595") then
                direction = target.Position - origin
            end
        end
        return oldRay(origin, direction)
    end)
end)

if raySuccess then
    print("DDD (Silent Aim) hook ready")
else
    print("DDD error: " .. tostring(rayError))
end

-- ============================
-- FOV КРУГ
-- ============================
local function createFOVCircle()
    if fovCircle then pcall(function() fovCircle:Remove() end) fovCircle = nil end
    if not drawFOV then return end
    if typeof(Drawing) == "table" and Drawing.new then
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
    if drawFOV then
        if not fovCircle then createFOVCircle() else
            local center = Camera.ViewportSize / 2
            fovCircle.Position = Vector2.new(center.X, center.Y)
            fovCircle.Radius = aimFOV
            fovCircle.Color = espColor
        end
    elseif fovCircle then
        pcall(function() fovCircle:Remove() end)
        fovCircle = nil
    end
end)

-- ============================
-- ФУНКЦИЯ СТРЕЛЬБЫ (ИМИТАЦИЯ ЛКМ)
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

-- ============================
-- AUTOFIRE
-- ============================
RunService.RenderStepped:Connect(function()
    if not autofireEnabled then return end
    local targetHead = getClosestPlayerInFOV()
    if targetHead then
        shoot()
    end
end)

-- ============================
-- TRIGGERBOT (ВИДИМОСТЬ + FOV)
-- ============================
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
-- ESP
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

        if hrp and hum and hum.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

            if onScreen then
                if not espObjects[player] then
                    local box = Drawing.new("Square")
                    box.Thickness = 2
                    box.Filled = espShowFill
                    box.Transparency = espFillTransparency
                    box.Color = espColor

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
                box.Color = espColor
                box.Filled = espShowFill
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
Players.PlayerRemoving:Connect(removeESP)

-- ============================
-- BHOP
-- ============================
local function setupBhop()
    local char = LocalPlayer.Character
    if not char then return end
    humanoid = char:FindFirstChildOfClass("Humanoid")
end

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
-- SPIN
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
                    spinAngle = (spinAngle + SPIN_SPEED) % 360
                    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(spinAngle), 0)
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

-- ============================
-- ZOOM
-- ============================
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

-- ============================
-- КАМЕРА FOV
-- ============================
local function updateCameraFOV()
    Camera.FieldOfView = cameraFOV
end

-- ============================
-- WALLCAM (ДЛЯ ВСЕХ ИГРОКОВ)
-- ============================
local function getAllPlayers()
    local players = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local char = p.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                table.insert(players, p)
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

            if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") or targetPlayer.Character.Humanoid.Health <= 0 then
                selectNewTarget()
            end

            if not targetPlayer then return end

            local targetHeadPosition = nil
            local targetChar = targetPlayer.Character
            if targetChar then
                local head = targetChar:FindFirstChild("Head")
                local hrp = targetChar:FindFirstChild("HumanoidRootPart")
                if head then
                    targetHeadPosition = head.Position
                elseif hrp then
                    targetHeadPosition = hrp.Position + Vector3.new(0, 1.5, 0)
                end
            end

            if not targetHeadPosition then return end

            makeOriginalInvisible()

            local cameraFocusPoint = targetHeadPosition
            local rotationCFrame = CFrame.Angles(0, math.rad(cameraRotationX), 0) * CFrame.Angles(math.rad(cameraRotationY), 0, 0)
            local cameraRelativeOffset = Vector3.new(0, 0, CAMERA_DISTANCE)
            local targetCameraPosition = cameraFocusPoint + (rotationCFrame * cameraRelativeOffset)

            local cam = workspace.CurrentCamera
            cam.CFrame = CFrame.new(targetCameraPosition, cameraFocusPoint)

            rootPart.CFrame = CFrame.new(targetHeadPosition) + Vector3.new(0, SKY_HEIGHT, 0)
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
    Name = "DDD (Silent Aim)",
    CurrentValue = false,
    Flag = "DDDToggle",
    Callback = function(v) dddEnabled = v end
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
        if fovCircle then fovCircle.Color = v end
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
    Callback = function(v) espShowFill = v end
})

ESPTab:CreateSlider({
    Name = "Прозрачность заливки",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.5,
    Flag = "ESPFillTransparency",
    Callback = function(v) espFillTransparency = v end
})

ESPTab:CreateColorPicker({
    Name = "Цвет ESP",
    Color = Color3.fromRGB(255, 0, 80),
    Flag = "ESPColorPicker",
    Callback = function(v)
        espColor = v
        if fovCircle then fovCircle.Color = v end
    end
})

-- TAB: РАЗНОЕ
local MiscTab = Window:CreateTab("Разное", 4483362458)

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
        updateCameraFOV()
    end
})

-- TAB: WALLCAM
local WallCamTab = Window:CreateTab("WallCam", 4483362458)

WallCamTab:CreateToggle({
    Name = "Включить WallCam (All Players)",
    CurrentValue = false,
    Flag = "WallCamToggle",
    Callback = function(v)
        if v then
            toggleWallCam()
        else
            if wallCamEnabled then toggleWallCam() end
        end
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
    Content = "DDD + Autofire + Triggerbot + ESP + Bhop + Spin + Zoom + FOV Slider (1-200) + WallCam (All Players)",
    Duration = 3,
    Image = 4483362458,
})