if not hookfunction then return end

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local Stats = game:GetService("Stats")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local target = nil
local dddEnabled = false
local aimFOV = 200
local autofireEnabled = false
local lastFire = 0
local fireDelay = 0.03
local spaceHeld = false
local humanoid = nil
local trailEnabled = false
local trailColor = Color3.fromRGB(200, 0, 255)
local trailDuration = 0.5
local DESIRED_ZOOM = 30
local SPIN_SPEED = 25
local spinAngle = 0
local spinConnection = nil

local Settings = {
    -- ESP Настройки
    ESP = false,
    FillESP = false,
    HPBar = false,
    Distance = false,
    
    -- HUD Информер
    HUD_Enabled = false,
    HUD_FPS = false,
    HUD_Speed = false,
    HUD_Ping = false,
    
    -- Остальной функционал
    Night = false,
    Darkness = 0.7,
    Ddd = false,
    Autofire = false,
    Bhop = false,
    Trail = false,
    Zoom = false,
    Spin = false,
    WallCam = false
}

local original = {
    ClockTime = Lighting.ClockTime,
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    CameraMaxZoomDistance = LocalPlayer.CameraMaxZoomDistance
}

local espDrawings = {}

-- ============================
-- HUD ИНФОРМЕР (FPS, Скорость, Пинг)
-- ============================
local hudText = Drawing.new("Text")
hudText.Visible = false
hudText.Size = 16
hudText.Position = Vector2.new(15, 15)
hudText.Color = Color3.fromRGB(255, 255, 255)
hudText.Outline = true
hudText.Center = false

RunService.RenderStepped:Connect(function()
    if not Settings.HUD_Enabled or not (Settings.HUD_FPS or Settings.HUD_Speed or Settings.HUD_Ping) then
        hudText.Visible = false
        return
    end

    local infoLines = {}

    -- FPS
    if Settings.HUD_FPS then
        local fps = math.round(1 / RunService.RenderStepped:Wait())
        table.insert(infoLines, "FPS: " .. fps)
    end

    -- Скорость игрока
    if Settings.HUD_Speed and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local speed = math.round(Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude)
            table.insert(infoLines, "Speed: " .. speed)
        end
    end

    -- Пинг (MS)
    if Settings.HUD_Ping then
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
-- ZOOM
-- ============================
local function applyZoom()
    if Settings.Zoom then
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMinZoomDistance = DESIRED_ZOOM
        LocalPlayer.CameraMaxZoomDistance = DESIRED_ZOOM
    else
        LocalPlayer.CameraMinZoomDistance = 0.5
        LocalPlayer.CameraMaxZoomDistance = original.CameraMaxZoomDistance
    end
end

task.wait(0.5)
applyZoom()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.1)
    applyZoom()
end)

-- ============================
-- WALLCAM
-- ============================
local function updateWallCam()
    local cam = Workspace.CurrentCamera
    if Settings.WallCam then
        cam.CFrame = cam.CFrame
        LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
    else
        LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
    end
end

-- ============================
-- SPIN
-- ============================
local function updateSpin()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if Settings.Spin then
        hum.AutoRotate = false
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

        if not spinConnection then
            spinConnection = RunService.RenderStepped:Connect(function()
                if hrp and hum then
                    spinAngle = (spinAngle + SPIN_SPEED) % 360
                    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(spinAngle), 0)
                    
                    local state = hum:GetState()
                    if state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Ragdoll then
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                    end
                end
            end)
        end
    else
        if spinConnection then
            spinConnection:Disconnect()
            spinConnection = nil
        end
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        hum.AutoRotate = true
    end
end

local function setupCharacter(char)
    task.wait(0.2)
    applyZoom()
    updateSpin()
    humanoid = char:FindFirstChildOfClass("Humanoid")
end

if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

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
-- ТРИГГЕРБОТ / ХУКИ[cite: 1]
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
    if not char then return end
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
-- ESP (ДЕШИФРАЦИЯ РИСОВАНИЯ)
-- ============================
local function createESPDrawing()
    local esp = {}
    
    esp.Box = Drawing.new("Square")
    esp.Box.Visible = false
    esp.Box.Thickness = 1.5
    esp.Box.Color = Color3.fromRGB(255, 60, 60)
    esp.Box.Filled = false

    esp.Fill = Drawing.new("Square")
    esp.Fill.Visible = false
    esp.Fill.Thickness = 1
    esp.Fill.Color = Color3.fromRGB(255, 60, 60)
    esp.Fill.Filled = true
    esp.Fill.Transparency = 0.3

    esp.HPBackground = Drawing.new("Line")
    esp.HPBackground.Visible = false
    esp.HPBackground.Thickness = 2.5
    esp.HPBackground.Color = Color3.fromRGB(30, 30, 30)

    esp.HPBar = Drawing.new("Line")
    esp.HPBar.Visible = false
    esp.HPBar.Thickness = 1.5
    esp.HPBar.Color = Color3.fromRGB(0, 255, 100)

    esp.Distance = Drawing.new("Text")
    esp.Distance.Visible = false
    esp.Distance.Size = 13
    esp.Distance.Center = true
    esp.Distance.Outline = true
    esp.Distance.Color = Color3.fromRGB(255, 255, 255)

    return esp
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        espDrawings[player] = createESPDrawing()
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        espDrawings[player] = createESPDrawing()
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if espDrawings[player] then
        for _, drawing in pairs(espDrawings[player]) do
            pcall(function() drawing:Remove() end)
        end
        espDrawings[player] = nil
    end
end)

RunService.RenderStepped:Connect(function()
    for player, esp in pairs(espDrawings) do
        local showBox = false
        local char = player.Character
        local localChar = LocalPlayer.Character

        if char and localChar then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            if hrp and hum and hum.Health > 0 then
                local isTeamMate = false
                pcall(function()
                    if player.Team == LocalPlayer.Team then isTeamMate = true end
                end)

                if not isTeamMate then
                    local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        showBox = true
                        
                        local head = char:FindFirstChild("Head")
                        local topPoint = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or vector
                        local bottomPoint = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        
                        local height = math.abs(topPoint.Y - bottomPoint.Y)
                        local width = height / 2
                        local pos = Vector2.new(vector.X - width / 2, topPoint.Y)

                        -- 1. Box ESP
                        if Settings.ESP then
                            esp.Box.Visible = true
                            esp.Box.Size = Vector2.new(width, height)
                            esp.Box.Position = pos
                        else
                            esp.Box.Visible = false
                        end

                        -- 2. Fill ESP
                        if Settings.FillESP and Settings.ESP then
                            esp.Fill.Visible = true
                            esp.Fill.Size = Vector2.new(width, height)
                            esp.Fill.Position = pos
                        else
                            esp.Fill.Visible = false
                        end

                        -- 3. HP Bar
                        if Settings.HPBar and Settings.ESP then
                            local healthPercent = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                            local lineStart = Vector2.new(pos.X - 6, pos.Y + height)
                            local lineEnd = Vector2.new(pos.X - 6, pos.Y)
                            local currentHpEnd = lineStart:Lerp(lineEnd, healthPercent)

                            esp.HPBackground.Visible = true
                            esp.HPBackground.From = lineStart
                            esp.HPBackground.To = lineEnd

                            esp.HPBar.Visible = true
                            esp.HPBar.From = lineStart
                            esp.HPBar.To = currentHpEnd
                            
                            if healthPercent > 0.6 then
                                esp.HPBar.Color = Color3.fromRGB(50, 220, 80)
                            elseif healthPercent > 0.3 then
                                esp.HPBar.Color = Color3.fromRGB(255, 190, 50)
                            else
                                esp.HPBar.Color = Color3.fromRGB(235, 60, 60)
                            end
                        else
                            esp.HPBackground.Visible = false
                            esp.HPBar.Visible = false
                        end

                        -- 4. Distance
                        if Settings.Distance and Settings.ESP then
                            local localHrp = localChar:FindFirstChild("HumanoidRootPart")
                            if localHrp then
                                local dist = math.round((localHrp.Position - hrp.Position).Magnitude)
                                esp.Distance.Visible = true
                                esp.Distance.Text = "[" .. dist .. "m]"
                                esp.Distance.Position = Vector2.new(pos.X + width / 2, pos.Y + height + 2)
                            else
                                esp.Distance.Visible = false
                            end
                        else
                            esp.Distance.Visible = false
                        end
                    end
                end
            end
        end

        if not showBox then
            esp.Box.Visible = false
            esp.Fill.Visible = false
            esp.HPBackground.Visible = false
            esp.HPBar.Visible = false
            esp.Distance.Visible = false
        end
    end
end)

-- ============================
-- RAYFIELD UI
-- ============================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Hook & Combat Menu",
    LoadingTitle = "Загрузка скрипта...",
    LoadingSubtitle = "by Rayfield",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "HookConfig"
    },
    KeySystem = false,
})

local TabCombat = Window:CreateTab("Combat & Hooks", 4483362458)
local TabVisuals = Window:CreateTab("Visuals & ESP", 4483345998)
local TabPlayer = Window:CreateTab("Player", 4483362458)

-- Вкладка Combat
TabCombat:CreateToggle({
    Name = "Ddd (Триггербот / Хук на цели)",
    CurrentValue = false,
    Callback = function(v) 
        Settings.Ddd = v 
        dddEnabled = v 
    end,
})

TabCombat:CreateToggle({
    Name = "Autofire (Автовыстрел)",
    CurrentValue = false,
    Callback = function(v) 
        Settings.Autofire = v 
        autofireEnabled = v 
    end,
})

TabCombat:CreateToggle({
    Name = "Trail (Трейл пуль)",
    CurrentValue = false,
    Callback = function(v) 
        Settings.Trail = v 
        trailEnabled = v 
    end,
})

-- Вкладка Visuals (ESP + HUD)
TabVisuals:CreateSection("ESP Настройки")

TabVisuals:CreateToggle({
    Name = "ESP Box (Контур)",
    CurrentValue = false,
    Callback = function(v) Settings.ESP = v end,
})

TabVisuals:CreateToggle({
    Name = "Fill (Заливка бокса)",
    CurrentValue = false,
    Callback = function(v) Settings.FillESP = v end,
})

TabVisuals:CreateToggle({
    Name = "HP Bar (Линия здоровья)",
    CurrentValue = false,
    Callback = function(v) Settings.HPBar = v end,
})

TabVisuals:CreateToggle({
    Name = "Distance (Дистанция)",
    CurrentValue = false,
    Callback = function(v) Settings.Distance = v end,
})

TabVisuals:CreateSection("HUD Информер (Экран)")

TabVisuals:CreateToggle({
    Name = "Включить HUD Информер",
    CurrentValue = false,
    Callback = function(v) Settings.HUD_Enabled = v end,
})

TabVisuals:CreateToggle({
    Name = "Показывать FPS",
    CurrentValue = false,
    Callback = function(v) Settings.HUD_FPS = v end,
})

TabVisuals:CreateToggle({
    Name = "Показывать Скорость (Speed)",
    CurrentValue = false,
    Callback = function(v) Settings.HUD_Speed = v end,
})

TabVisuals:CreateToggle({
    Name = "Показывать Пинг (MS)",
    CurrentValue = false,
    Callback = function(v) Settings.HUD_Ping = v end,
})

TabVisuals:CreateSection("Окружение")

TabVisuals:CreateToggle({
    Name = "Night Mode",
    CurrentValue = false,
    Callback = function(v) 
        Settings.Night = v 
        updateNight() 
    end,
})

TabVisuals:CreateSlider({
    Name = "Darkness Intensity",
    Range = {0.1, 1},
    Increment = 0.05,
    CurrentValue = 0.7,
    Callback = function(v) 
        Settings.Darkness = v 
        if Settings.Night then updateNight() end 
    end,
})

-- Вкладка Player
TabPlayer:CreateToggle({
    Name = "Bhop (Автопрыжок)",
    CurrentValue = false,
    Callback = function(v) Settings.Bhop = v end,
})

TabPlayer:CreateToggle({
    Name = "Spinbot (Крутилка)",
    CurrentValue = false,
    Callback = function(v) 
        Settings.Spin = v 
        updateSpin() 
    end,
})

TabPlayer:CreateToggle({
    Name = "WallCam (Обход стен камерой)",
    CurrentValue = false,
    Callback = function(v) 
        Settings.WallCam = v 
        updateWallCam() 
    end,
})

TabPlayer:CreateToggle({
    Name = "Custom Zoom",
    CurrentValue = false,
    Callback = function(v) 
        Settings.Zoom = v 
        applyZoom() 
    end,
})

TabPlayer:CreateSlider({
    Name = "Zoom Distance",
    Range = {5, 150},
    Increment = 5,
    CurrentValue = 30,
    Callback = function(v) 
        DESIRED_ZOOM = v 
        if Settings.Zoom then applyZoom() end 
    end,
})

Rayfield:LoadConfiguration()

-- ============================
-- INIT
-- ============================
task.wait(0.5)
applyZoom()
updateSpin()