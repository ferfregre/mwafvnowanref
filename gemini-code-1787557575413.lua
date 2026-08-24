-- ============================================
-- @set9p | SILENT AIM (360°) + AUTO TRIGGER + ESP + ANTI-AIM (DOWN)
-- ============================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Stats = game:GetService("Stats")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local CanHook = type(hookfunction) == "function" or hookfunction ~= nil

-- ============================
-- НАСТРОЙКИ
-- ============================
local Settings = {
    SilentAim = false,
    HitPart = "Head", -- "Head" или "Torso"
    AimFOV = 200,
    Aim360 = false, -- Режим 360 градусов
    DrawFOV = false,
    
    -- Auto Trigger
    AutoTrigger = false,
    TriggerDelay = 0.01,

    -- Анти-аим (взгляд в пол в 3-м лице)
    AntiAimDown = false,

    -- ESP
    ESP = false,
    ESPBoxes = true,
    ESPNames = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPLine = false,
    ESPLineOrigin = "Bottom",
    ESPFill = false,
    ESPFillTransparency = 0.5,
    ESPRGB = false,
    ESPRGBSpeed = 1
}

local espColor = Color3.fromRGB(255, 0, 80)
local target = nil
local shotFiredTime = 0
local ESPObjects = {}
local espHighlights = {}
local fovCircle = nil
local lastTriggerTick = 0

-- HUD ИНФОРМЕР
local hudEnabled = false
local hudFPS = false
local hudSpeed = false
local hudPing = false
local cachedFPS = 0
local lastFPSTick = 0

local hudText = Drawing.new("Text")
hudText.Visible = false
hudText.Size = 16
hudText.Position = Vector2.new(15, 15)
hudText.Color = Color3.fromRGB(255, 255, 255)
hudText.Outline = true
hudText.Center = false

-- NIGHTMODE & WORLD COLOR
local nightModeEnabled = false
local nightBrightness = 0.5
local worldColorEnabled = false
local customWorldColor = Color3.fromRGB(150, 50, 255)
local activeAtmosphere = nil
local originalLightingProps = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    ColorShift_Top = Lighting.ColorShift_Top
}

-- MISC
local bhopEnabled = false
local spaceHeld = false
local spinEnabled = false
local SPIN_SPEED = 25
local spinConnection = nil
local zoomEnabled = false
local DESIRED_ZOOM = 30
local zoomConnection = nil
local cameraFOV = 70

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
local function playKillSound()
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://6729922069"
        sound.Volume = 1
        sound.Parent = SoundService
        sound:Play()
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
    end)
end

local function getRainbowColor()
    local hue = (tick() * Settings.ESPRGBSpeed) % 1
    return Color3.fromHSV(hue, 1, 1)
end

local function isVisible(targetPart)
    if not targetPart or typeof(targetPart) ~= "Instance" or targetPart.Parent == nil then return false end
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local origin = cam.CFrame

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}
    params.IgnoreWater = true

    if not targetPart:IsA("BasePart") then return false end

    local direction = (targetPart.Position - origin.Position)
    local result = Workspace:Raycast(origin.Position, direction, params)

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
    local Character = player.Character
    if not Character then return false end
    
    local hum = Character:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    if LocalPlayer.Team and player.Team then
        if player.Team == LocalPlayer.Team then
            return false
        end
    end
    return true
end

-- ============================
-- SILENT AIM & AUTO TRIGGER (360°)
-- ============================
local function GetClosestPlayer()
    local closestDistance = math.huge
    local closest = nil
    local camera = Workspace.CurrentCamera
    local center = camera.ViewportSize / 2
    local plrs = Players:GetPlayers()
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, v in pairs(plrs) do
        if not isEnemy(v) then continue end
        local char = v.Character
        if not char then continue end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp or not hrp:IsA("BasePart") then continue end

        local targetHitPart = nil
        if Settings.HitPart == "Head" then
            targetHitPart = char:FindFirstChild("Head") or hrp
        else
            targetHitPart = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or hrp
        end

        if not targetHitPart or not targetHitPart:IsA("BasePart") then continue end

        if Settings.Aim360 then
            if myHRP then
                local worldDist = (hrp.Position - myHRP.Position).Magnitude
                if worldDist < closestDistance then
                    closestDistance = worldDist
                    closest = targetHitPart
                end
            end
        else
            local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if distance <= Settings.AimFOV and distance < closestDistance then
                    if not isVisible(targetHitPart) then continue end
                    closestDistance = distance
                    closest = targetHitPart
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if Settings.SilentAim or Settings.AutoTrigger then
        target = GetClosestPlayer()
    else
        target = nil
    end

    if Settings.AutoTrigger and target then
        local now = tick()
        if now - lastTriggerTick >= Settings.TriggerDelay then
            lastTriggerTick = now
            task.spawn(function()
                pcall(function()
                    mouse1press()
                    task.wait(0.02)
                    mouse1release()
                end)
            end)
        end
    end
end)

local old
if CanHook then
    pcall(function()
        old = hookfunction(Ray.new, newcclosure(function(origin, direction)
            local trace = debug.traceback()
            
            if trace:find("Client") and not trace:find("10420") and not trace:find("10595") then
                if Settings.SilentAim and target and target:IsA("BasePart") then
                    shotFiredTime = tick()
                    direction = target.Position - origin
                end
            end
            
            return old(origin, direction)
        end))
    end)
end

-- ============================
-- FOV КРУГ
-- ============================
local function createFOVCircle()
    if fovCircle then pcall(function() fovCircle:Remove() end) fovCircle = nil end
    if Drawing and Drawing.new then
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 2
        fovCircle.Filled = false
        fovCircle.Transparency = 1
        fovCircle.Visible = true
    end
end

RunService.RenderStepped:Connect(function()
    local activeColor = Settings.ESPRGB and getRainbowColor() or espColor
    if Settings.DrawFOV and not Settings.Aim360 then
        if not fovCircle then createFOVCircle() end
        if fovCircle then
            local center = Camera.ViewportSize / 2
            fovCircle.Position = Vector2.new(center.X, center.Y)
            fovCircle.Radius = Settings.AimFOV
            fovCircle.Color = activeColor
            fovCircle.Visible = true
        end
    elseif fovCircle then
        fovCircle.Visible = false
    end
end)

-- ============================
-- ОТСЛЕЖИВАНИЕ УБИЙСТВ
-- ============================
local function monitorPlayer(player)
    if player == LocalPlayer then return end
    local function setupChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                if tick() - shotFiredTime < 1.5 then
                    playKillSound()
                end
            end)
        end
    end
    player.CharacterAdded:Connect(setupChar)
    if player.Character then setupChar(player.Character) end
end
for _, p in ipairs(Players:GetPlayers()) do monitorPlayer(p) end
Players.PlayerAdded:Connect(monitorPlayer)

-- ============================
-- ESP СИСТЕМА
-- ============================
local function RemoveESP(player)
    local data = ESPObjects[player]
    if data then
        for _, v in pairs(data) do
            pcall(function() v:Remove() end)
        end
        ESPObjects[player] = nil
    end
    if espHighlights[player] then
        pcall(function() espHighlights[player]:Destroy() end)
        espHighlights[player] = nil
    end
end

local function CreateESP(player)
    if ESPObjects[player] then return end
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
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

    local hbBg = Drawing.new("Square")
    hbBg.Thickness = 1
    hbBg.Filled = true
    hbBg.Color = Color3.fromRGB(0, 0, 0)
    hbBg.Transparency = 0.7
    hbBg.Visible = false

    local hb = Drawing.new("Square")
    hb.Thickness = 1
    hb.Filled = true
    hb.Visible = false

    local line = Drawing.new("Line")
    line.Thickness = 1
    line.Visible = false

    ESPObjects[player] = {Box = box, Outline = outline, Name = name, Dist = dist, HealthBarBg = hbBg, HealthBar = hb, Line = line}
end

local function UpdateESP()
    local activeColor = Settings.ESPRGB and getRainbowColor() or espColor
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local viewportSize = Camera.ViewportSize

    for player, data in pairs(ESPObjects) do
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if not Settings.ESP or not char or not isEnemy(player) or not hum or hum.Health <= 0 then
            data.Box.Visible = false
            data.Outline.Visible = false
            data.Name.Visible = false
            data.Dist.Visible = false
            data.HealthBarBg.Visible = false
            data.HealthBar.Visible = false
            data.Line.Visible = false
            if espHighlights[player] then espHighlights[player]:Destroy() espHighlights[player] = nil end
            continue
        end

        if Settings.ESPFill then
            if not espHighlights[player] or espHighlights[player].Parent ~= char then
                if espHighlights[player] then espHighlights[player]:Destroy() end
                local h = Instance.new("Highlight")
                h.Parent = char
                h.FillColor = activeColor
                h.OutlineColor = Color3.new(1, 1, 1)
                h.FillTransparency = Settings.ESPFillTransparency
                espHighlights[player] = h
            else
                espHighlights[player].FillColor = activeColor
                espHighlights[player].FillTransparency = Settings.ESPFillTransparency
            end
        else
            if espHighlights[player] then espHighlights[player]:Destroy() espHighlights[player] = nil end
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not hrp or not head then continue end

        local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then
            data.Box.Visible = false
            data.Outline.Visible = false
            data.Name.Visible = false
            data.Dist.Visible = false
            data.HealthBarBg.Visible = false
            data.HealthBar.Visible = false
            data.Line.Visible = false
            continue
        end

        local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

        local height = math.abs(headPos.Y - legPos.Y)
        local width = height / 2
        local boxPos = Vector2.new(vector.X - width / 2, headPos.Y)

        if Settings.ESPBoxes then
            data.Box.Size = Vector2.new(width, height)
            data.Box.Position = boxPos
            data.Box.Color = activeColor
            data.Box.Visible = true
            data.Outline.Size = data.Box.Size
            data.Outline.Position = data.Box.Position
            data.Outline.Visible = true
        else
            data.Box.Visible = false
            data.Outline.Visible = false
        end

        if Settings.ESPHealth then
            data.HealthBarBg.Visible = true
            data.HealthBarBg.Size = Vector2.new(3, height + 2)
            data.HealthBarBg.Position = Vector2.new(boxPos.X - 6, boxPos.Y - 1)

            local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local hbHeight = height * healthPercent
            data.HealthBar.Visible = true
            data.HealthBar.Size = Vector2.new(1, hbHeight)
            data.HealthBar.Position = Vector2.new(boxPos.X - 5, boxPos.Y + (height - hbHeight))
            data.HealthBar.Color = Color3.fromHSV(healthPercent * 0.3, 1, 1)
        else
            data.HealthBarBg.Visible = false
            data.HealthBar.Visible = false
        end

        if Settings.ESPNames then
            data.Name.Text = player.DisplayName or player.Name
            data.Name.Position = Vector2.new(vector.X, boxPos.Y - 16)
            data.Name.Visible = true
        else
            data.Name.Visible = false
        end

        if Settings.ESPDistance and myHRP then
            local distance = math.floor((hrp.Position - myHRP.Position).Magnitude)
            data.Dist.Text = distance .. "m"
            data.Dist.Position = Vector2.new(vector.X, boxPos.Y + height + 4)
            data.Dist.Visible = true
        else
            data.Dist.Visible = false
        end

        if Settings.ESPLine then
            data.Line.Visible = true
            data.Line.Color = activeColor
            local originPos = Vector2.new(viewportSize.X / 2, viewportSize.Y)
            if Settings.ESPLineOrigin == "Center" then
                originPos = viewportSize / 2
            elseif Settings.ESPLineOrigin == "Top" then
                originPos = Vector2.new(viewportSize.X / 2, 0)
            end
            data.Line.From = originPos
            data.Line.To = Vector2.new(vector.X, boxPos.Y + height / 2)
        else
            data.Line.Visible = false
        end
    end
end

Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(RemoveESP)
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESP(p) end
end
RunService.RenderStepped:Connect(UpdateESP)

-- ============================
-- HUD ИНФОРМЕР
-- ============================
RunService.RenderStepped:Connect(function()
    if not hudEnabled or not (hudFPS or hudSpeed or hudPing) then
        hudText.Visible = false
        return
    end

    local infoLines = {}
    if hudFPS then
        local currentTime = tick()
        if currentTime - lastFPSTick >= 0.5 then
            cachedFPS = math.round(1 / RunService.RenderStepped:Wait())
            lastFPSTick = currentTime
        end
        table.insert(infoLines, "FPS: " .. cachedFPS)
    end

    if hudSpeed and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local speed = math.round(Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude)
            table.insert(infoLines, "Speed: " .. speed)
        end
    end

    if hudPing then
        local ping = 0
        pcall(function()
            ping = math.round(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        table.insert(infoLines, "MS: " .. ping .. "ms")
    end

    if #infoLines > 0 then
        hudText.Visible = true
        hudText.Text = table.concat(infoLines, " | ")
    else
        hudText.Visible = false
    end
end)

-- ============================
-- WORLD COLOR & NIGHTMODE
-- ============================
local function updateWorldColor()
    if worldColorEnabled then
        Lighting.Ambient = customWorldColor
        Lighting.OutdoorAmbient = customWorldColor
        Lighting.ColorShift_Bottom = customWorldColor
        Lighting.ColorShift_Top = customWorldColor
        if not activeAtmosphere then
            activeAtmosphere = Instance.new("Atmosphere")
            activeAtmosphere.Parent = Lighting
        end
        activeAtmosphere.Color = customWorldColor
        activeAtmosphere.Haze = 2
        activeAtmosphere.Density = 0.3
    else
        Lighting.Ambient = originalLightingProps.Ambient
        Lighting.OutdoorAmbient = originalLightingProps.OutdoorAmbient
        Lighting.ColorShift_Bottom = originalLightingProps.ColorShift_Bottom
        Lighting.ColorShift_Top = originalLightingProps.ColorShift_Top
        if activeAtmosphere then
            activeAtmosphere:Destroy()
            activeAtmosphere = nil
        end
    end
end

RunService.RenderStepped:Connect(function()
    if nightModeEnabled then
        Lighting.Brightness = nightBrightness
        Lighting.ClockTime = 0
        Lighting.FogEnd = 999999
    elseif not worldColorEnabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
    end
end)

-- ============================
-- MISC & АНТИ-АИМ (ВЗГЛЯД В ПОЛ В 3-М ЛИЦЕ)
-- ============================
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then spaceHeld = true end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then spaceHeld = false end
end)

task.spawn(function()
    while true do
        task.wait()
        if bhopEnabled and spaceHeld then
            local char = LocalPlayer.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    if humanoid.FloorMaterial ~= Enum.Material.Air then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end
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

-- Безопасный обходной путь для Анти-Аима через манипуляцию суставами (Neck / Waist)
RunService.RenderStepped:Connect(function()
    if cameraFOV then
        Camera.FieldOfView = cameraFOV
    end

    local char = LocalPlayer.Character
    if char then
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        local head = char:FindFirstChild("Head")
        
        if zoomEnabled and Settings.AntiAimDown then
            if torso then
                local waist = torso:FindFirstChild("Waist") or char:FindFirstChild("HumanoidRootPart"):FindFirstChild("RootJoint")
                if waist and waist:IsA("Motor6D") then
                    if not waist.Part0 then return end
                    -- Наклоняем только сустав, не трогая саму физику игрока
                    waist.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(80), 0, 0)
                end
            end
            if head then
                local neck = head:FindFirstChild("Neck")
                if neck and neck:IsA("Motor6D") then
                    neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(30), 0, 0)
                end
            end
        else
            -- Возвращаем стандартные суставы на место при выключении
            if torso then
                local waist = torso:FindFirstChild("Waist")
                if waist and waist:IsA("Motor6D") then
                    waist.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)
                end
            end
            if head then
                local neck = head:FindFirstChild("Neck")
                if neck and neck:IsA("Motor6D") then
                    neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, 0)
                end
            end
        end
    end
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
        Camera.CameraType = Enum.CameraType.Scriptable
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

            Camera.CFrame = CFrame.new(targetCameraPosition, cameraFocusPoint)
            rp.CFrame = CFrame.new(targetHeadPosition) + Vector3.new(0, SKY_HEIGHT, 0)
            rp.AssemblyLinearVelocity = Vector3.zero
        end)
    else
        if wallCamConnection then wallCamConnection:Disconnect() wallCamConnection = nil end
        if targetHumanoidDiedConnection then targetHumanoidDiedConnection:Disconnect() targetHumanoidDiedConnection = nil end
        targetPlayer = nil
        Camera.CameraType = Enum.CameraType.Custom
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
    if processed or not wallCamEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        cameraRotationX = cameraRotationX - input.Delta.X * MOUSE_SENSITIVITY
        cameraRotationY = math.clamp(cameraRotationY - input.Delta.Y * MOUSE_SENSITIVITY, -85, 85)
    end
end)

-- ============================
-- RAYFIELD UI
-- ============================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then return end

local Window = Rayfield:CreateWindow({
    Name = "@set9p | SCRIPT HUB",
    LoadingTitle = "Загрузка меню...",
    LoadingSubtitle = "by @set9p",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

-- TAB: БОЙ
local CombatTab = Window:CreateTab("Бой", 4483362458)

CombatTab:CreateToggle({
    Name = CanHook and "Silent Aim" or "Silent Aim [NO WORK]",
    CurrentValue = false,
    Flag = "SilentAimToggle",
    Callback = function(v) 
        if not CanHook then Settings.SilentAim = false return end
        Settings.SilentAim = v 
    end
})

CombatTab:CreateToggle({
    Name = "Aim 360° (Везде / Вокруг)",
    CurrentValue = false,
    Flag = "Aim360Toggle",
    Callback = function(v) Settings.Aim360 = v end
})

CombatTab:CreateToggle({
    Name = "Auto Trigger (Автовыстрел)",
    CurrentValue = false,
    Flag = "AutoTriggerToggle",
    Callback = function(v) Settings.AutoTrigger = v end
})

CombatTab:CreateSlider({
    Name = "Задержка Trigger (сек)",
    Range = {0.01, 0.2},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = 0.01,
    Flag = "TriggerDelaySlider",
    Callback = function(v) Settings.TriggerDelay = v end
})

CombatTab:CreateDropdown({
    Name = "Хитбокс (Aim/Trigger Part)",
    Options = {"Head", "Torso"},
    CurrentOption = Settings.HitPart,
    Flag = "HitPartDropdown",
    Callback = function(v) Settings.HitPart = v end
})

CombatTab:CreateSlider({
    Name = "Aim FOV",
    Range = {20, 800},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 200,
    Flag = "AimFOVSlider",
    Callback = function(v) Settings.AimFOV = v end
})

CombatTab:CreateToggle({
    Name = "Показать FOV круг",
    CurrentValue = false,
    Flag = "FOVCircleToggle",
    Callback = function(v) Settings.DrawFOV = v end
})

CombatTab:CreateColorPicker({
    Name = "Цвет FOV круга",
    Color = Color3.fromRGB(255, 0, 80),
    Flag = "FOVColorPicker",
    Callback = function(v) espColor = v end
})

-- TAB: ESP & HUD
local ESPTab = Window:CreateTab("ESP & HUD", 4483362458)

ESPTab:CreateSection("ESP Настройки")

ESPTab:CreateToggle({
    Name = "Включить ESP",
    CurrentValue = false,
    Flag = "ESPToggle",
    Callback = function(v) Settings.ESP = v end
})

ESPTab:CreateToggle({
    Name = "Box (Коробки)",
    CurrentValue = true,
    Flag = "ESPBoxToggle",
    Callback = function(v) Settings.ESPBoxes = v end
})

ESPTab:CreateToggle({
    Name = "Имена",
    CurrentValue = true,
    Flag = "ESPNameToggle",
    Callback = function(v) Settings.ESPNames = v end
})

ESPTab:CreateToggle({
    Name = "Дистанция",
    CurrentValue = true,
    Flag = "ESPDistToggle",
    Callback = function(v) Settings.ESPDistance = v end
})

ESPTab:CreateToggle({
    Name = "Полоса здоровья (HP Bar)",
    CurrentValue = true,
    Flag = "ESPHealthToggle",
    Callback = function(v) Settings.ESPHealth = v end
})

ESPTab:CreateToggle({
    Name = "Линии (Line ESP)",
    CurrentValue = false,
    Flag = "ESPLineToggle",
    Callback = function(v) Settings.ESPLine = v end
})

ESPTab:CreateDropdown({
    Name = "Откуда вести линии",
    Options = {"Bottom", "Center", "Top"},
    CurrentOption = "Bottom",
    Flag = "ESPLineOriginDropdown",
    Callback = function(v) Settings.ESPLineOrigin = v end
})

ESPTab:CreateToggle({
    Name = "Заливка (Fill)",
    CurrentValue = false,
    Flag = "ESPFillToggle",
    Callback = function(v) Settings.ESPFill = v end
})

ESPTab:CreateSlider({
    Name = "Прозрачность заливки",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.5,
    Flag = "ESPFillTransparency",
    Callback = function(v) Settings.ESPFillTransparency = v end
})

ESPTab:CreateToggle({
    Name = "RGB Радуга ESP",
    CurrentValue = false,
    Flag = "ESPRGB",
    Callback = function(v) Settings.ESPRGB = v end
})

ESPTab:CreateSlider({
    Name = "Скорость RGB",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "x",
    CurrentValue = 1,
    Flag = "ESPRGBSpeed",
    Callback = function(v) Settings.ESPRGBSpeed = v end
})

ESPTab:CreateColorPicker({
    Name = "Цвет ESP",
    Color = Color3.fromRGB(255, 0, 80),
    Flag = "ESPColorPicker",
    Callback = function(v) espColor = v end
})

ESPTab:CreateSection("HUD Информер")

ESPTab:CreateToggle({
    Name = "Включить HUD Информер",
    CurrentValue = false,
    Flag = "HUDEnabledToggle",
    Callback = function(v) hudEnabled = v end
})

ESPTab:CreateToggle({
    Name = "Показывать FPS",
    CurrentValue = false,
    Flag = "HUDFPSToggle",
    Callback = function(v) hudFPS = v end
})

ESPTab:CreateToggle({
    Name = "Показывать Скорость",
    CurrentValue = false,
    Flag = "HUDSpeedToggle",
    Callback = function(v) hudSpeed = v end
})

ESPTab:CreateToggle({
    Name = "Показывать Пинг (MS)",
    CurrentValue = false,
    Flag = "HUDPingToggle",
    Callback = function(v) hudPing = v end
})

-- TAB: РАЗНОЕ
local MiscTab = Window:CreateTab("Разное", 4483362458)

MiscTab:CreateToggle({
    Name = "Цветной мир (World Color)",
    CurrentValue = false,
    Flag = "WorldColorToggle",
    Callback = function(v)
        worldColorEnabled = v
        updateWorldColor()
    end
})

MiscTab:CreateColorPicker({
    Name = "Выбрать цвет мира",
    Color = Color3.fromRGB(150, 50, 255),
    Flag = "WorldColorPicker",
    Callback = function(v)
        customWorldColor = v
        if worldColorEnabled then updateWorldColor() end
    end
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

MiscTab:CreateToggle({
    Name = "Анти-Аим (Смотреть в пол в 3-м лице)",
    CurrentValue = false,
    Flag = "AntiAimDownToggle",
    Callback = function(v) Settings.AntiAimDown = v end
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
    Range = {1, 120},
    Increment = 1,
    Suffix = "°",
    CurrentValue = 70,
    Flag = "CameraFOVSlider",
    Callback = function(v) cameraFOV = v end
})

-- TAB: WALLCAM
local WallCamTab = Window:CreateTab("WallCam", 4483362458)

WallCamTab:CreateToggle({
    Name = "Включить WallCam",
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
    Title = "@set9p",
    Content = "Анти-аим исправлен и синхронизирован!",
    Duration = 3,
    Image = 4483362458,
})