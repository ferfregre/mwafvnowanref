-- ============================================
-- @set9p | SILENT AIM + SMART WALLBANG + PRIORITY VISIBLE + AUTO TRIGGER + ESP + BHOP
-- ============================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Stats = game:GetService("Stats")
local CollectionService = game:GetService("CollectionService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local CanHook = type(hookfunction) == "function" or hookfunction ~= nil

-- ============================
-- АНТИКИК (МЕТАМЕТОДЫ)
-- ============================
pcall(function()
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, method)
        if self == LocalPlayer and typeof(method) == "string" and method:lower() == "kick" then
            return error("Expected ':' not '.' calling member function Kick", 2)
        end
        return oldIndex(self, method)
    end)

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if self == LocalPlayer then
            local method = getnamecallmethod()
            if typeof(method) == "string" and method:lower() == "kick" then
                return
            end
        end
        return oldNamecall(self, ...)
    end)
end)

-- ============================
-- НАСТРОЙКИ
-- ============================
local Settings = {
    SilentAim = false,
    AimPart = "Head",
    AimFOV = 200,
    Aim360 = false,
    DrawFOV = false,
    
    -- Auto Trigger & Wallbang Visible Check
    AutoTrigger = false,
    VisibleCheck = true,
    MaxWallbangDistance = 100, -- Максимальная дистанция прострела
    MaxWallThickness = 6,      -- Максимальная толщина преграды (в студах), которую можно пробить

    -- Трейл пули и КД
    BulletTrailEnabled = false,
    BulletTrailColor = Color3.fromRGB(255, 0, 80),
    BulletTrailLifetime = 0.3,
    BulletTrailWidth = 0.2,
    BulletTrailCooldown = 0.3,

    -- Звуки триггера и КД
    TriggerSoundEnabled = false,
    TriggerSoundId = "140325083438865",
    TriggerSoundVolume = 1,
    TriggerSoundCooldown = 0.3,

    -- Анти-аим
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
local lastSoundPlayTime = 0
local lastTrailPlayTime = 0
local ESPObjects = {}
local espHighlights = {}
local fovCircle = nil

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

-- MISC & BHOP & JUMP SPEED
local bhopEnabled = false
local spaceHeld = false
local jumpSpeedEnabled = true 
local TARGET_JUMP_SPEED = 25

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
local function playSound(id)
    local currentTime = tick()
    if currentTime - lastSoundPlayTime < Settings.TriggerSoundCooldown then
        return
    end
    lastSoundPlayTime = currentTime

    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://" .. tostring(id)
        sound.Volume = Settings.TriggerSoundVolume
        sound.Parent = SoundService
        sound:Play()
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
    end)
end

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

-- Проверка простреливаемости материала/атрибута
local function isPenetrable(hitPart)
    if not hitPart then return false end
    
    if hitPart:GetAttribute("Penetrable") == true or hitPart:GetAttribute("Wallbang") == true then
        return true
    end
    
    if CollectionService:HasTag(hitPart, "PenetrableWall") then
        return true
    end
    
    if hitPart.Material == Enum.Material.Glass or hitPart.Transparency > 0.1 then
        return true
    end
    
    return false
end

-- Проверка преграды с контролем толщины стены
local function canPenetrateShoot(targetPart)
    if not targetPart or typeof(targetPart) ~= "Instance" or targetPart.Parent == nil then return false end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end

    local origin = char.HumanoidRootPart.Position
    local targetPos = targetPart.Position
    
    if (origin - targetPos).Magnitude > Settings.MaxWallbangDistance then
        return false
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
    raycastParams.FilterDescendantsInstances = {char, targetPart.Parent}
    
    local currentOrigin = origin
    local maxAttempts = 3
    
    for i = 1, maxAttempts do
        local direction = (targetPos - currentOrigin)
        local result = Workspace:Raycast(currentOrigin, direction, raycastParams)
        
        if not result or result.Instance == targetPart or result.Instance:IsDescendantOf(targetPart.Parent) then
            return true
        end

        local hitPart = result.Instance
        local model = hitPart:FindFirstAncestorOfClass("Model")
        if model and Players:GetPlayerFromCharacter(model) then
            return true
        end

        if isPenetrable(hitPart) then
            local entryPoint = result.Position
            local exitRayParams = RaycastParams.new()
            exitRayParams.FilterType = Enum.RaycastFilterType.Exclude
            exitRayParams.IgnoreWater = true
            exitRayParams.FilterDescendantsInstances = {char, targetPart.Parent, hitPart}
            
            local exitResult = Workspace:Raycast(targetPos, (entryPoint - targetPos), exitRayParams)
            local wallThickness = Settings.MaxWallThickness + 1
            
            if exitResult then
                wallThickness = (exitResult.Position - entryPoint).Magnitude
            end
            
            -- Если стена слишком толстая — прострел отменяется
            if wallThickness > Settings.MaxWallThickness then
                return false
            end

            currentOrigin = entryPoint + (direction.Unit * 2)
            table.insert(raycastParams.FilterDescendantsInstances, hitPart)
        else
            return false
        end
    end
    
    return false
end

-- Проверка прямой видимости (без стен) для приоритета
local function isDirectlyVisible(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end

    local origin = char.HumanoidRootPart.Position
    local targetPos = targetPart.Position

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
    raycastParams.FilterDescendantsInstances = {char, targetPart.Parent}

    local result = Workspace:Raycast(origin, targetPos - origin, raycastParams)
    if not result or result.Instance == targetPart or result.Instance:IsDescendantOf(targetPart.Parent) then
        return true
    end
    
    local model = result.Instance:FindFirstAncestorOfClass("Model")
    if model and Players:GetPlayerFromCharacter(model) then
        return true
    end

    return false
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
-- СОЗДАНИЕ ТРЕЙЛА ПУЛИ
-- ============================
local function createBulletTrail(originPos, hitPos)
    if not Settings.BulletTrailEnabled then return end
    
    local currentTime = tick()
    if currentTime - lastTrailPlayTime < Settings.BulletTrailCooldown then
        return
    end
    lastTrailPlayTime = currentTime

    pcall(function()
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.1, 0.1, 0.1)
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = false
        part.CFrame = CFrame.new(originPos)
        part.Parent = Workspace

        local endPart = Instance.new("Part")
        endPart.Size = Vector3.new(0.1, 0.1, 0.1)
        endPart.Transparency = 1
        endPart.Anchored = true
        endPart.CanCollide = false
        endPart.CFrame = CFrame.new(hitPos)
        endPart.Parent = Workspace

        local att0 = Instance.new("Attachment", part)
        local att1 = Instance.new("Attachment", endPart)

        local beam = Instance.new("Beam")
        beam.Attachment0 = att0
        beam.Attachment1 = att1
        beam.Color = ColorSequence.new(Settings.BulletTrailColor)
        beam.Width0 = Settings.BulletTrailWidth
        beam.Width1 = Settings.BulletTrailWidth
        beam.Transparency = NumberSequence.new(0)
        beam.FaceCamera = true
        beam.Parent = part

        task.delay(Settings.BulletTrailLifetime, function()
            pcall(function()
                part:Destroy()
                endPart:Destroy()
            end)
        end)
    end)
end

-- ============================
-- SILENT AIM & AUTO TRIGGER (С ПРИОРИТЕТОМ ВИДИМЫХ)
-- ============================
local function GetClosestPlayer()
    local closestVisibleDistance = math.huge
    local closestVisibleTarget = nil
    
    local closestWallbangDistance = math.huge
    local closestWallbangTarget = nil

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
        if Settings.AimPart == "Head" then
            targetHitPart = char:FindFirstChild("Head") or hrp
        else
            targetHitPart = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or hrp
        end

        if not targetHitPart or not targetHitPart:IsA("BasePart") then continue end

        if Settings.Aim360 then
            if myHRP then
                local worldDist = (hrp.Position - myHRP.Position).Magnitude
                if isDirectlyVisible(targetHitPart) then
                    if worldDist < closestVisibleDistance then
                        closestVisibleDistance = worldDist
                        closestVisibleTarget = targetHitPart
                    end
                elseif Settings.VisibleCheck and canPenetrateShoot(targetHitPart) then
                    if worldDist < closestWallbangDistance then
                        closestWallbangDistance = worldDist
                        closestWallbangTarget = targetHitPart
                    end
                end
            end
        else
            local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if distance <= Settings.AimFOV then
                    if isDirectlyVisible(targetHitPart) then
                        if distance < closestVisibleDistance then
                            closestVisibleDistance = distance
                            closestVisibleTarget = targetHitPart
                        end
                    elseif Settings.VisibleCheck and canPenetrateShoot(targetHitPart) then
                        if distance < closestWallbangDistance then
                            closestWallbangDistance = distance
                            closestWallbangTarget = targetHitPart
                        end
                    end
                end
            end
        end
    end

    -- Приоритет: сначала выбираем того, кто виден напрямую, иначе простреливаемого
    if closestVisibleTarget then
        return closestVisibleTarget
    end
    return closestWallbangTarget
end

local lockedTarget = nil
local isTriggerActive = false

RunService.RenderStepped:Connect(function()
    if not Settings.SilentAim and not Settings.AutoTrigger then
        target = nil
        lockedTarget = nil
        return
    end

    if lockedTarget and lockedTarget.Parent then
        local char = lockedTarget.Parent
        local hum = char:FindFirstChildOfClass("Humanoid")
        local isStillValid = false
        if hum and hum.Health > 0 then
            if isDirectlyVisible(lockedTarget) or (Settings.VisibleCheck and canPenetrateShoot(lockedTarget)) then
                isStillValid = true
            end
        end
        if not isStillValid then
            lockedTarget = nil
        end
    else
        lockedTarget = nil
    end

    if not lockedTarget then
        lockedTarget = GetClosestPlayer()
    end

    target = lockedTarget

    if Settings.AutoTrigger and target and not isTriggerActive then
        isTriggerActive = true
        task.spawn(function()
            pcall(function()
                mouse1press()
                if Settings.TriggerSoundEnabled then
                    playSound(Settings.TriggerSoundId)
                end
                task.wait(0.03)
                mouse1release()
            end)
            task.wait(0.05)
            isTriggerActive = false
        end)
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
                    local realOrigin = origin
                    local targetPos = target.Position
                    direction = targetPos - realOrigin
                    createBulletTrail(realOrigin, targetPos)
                    if Settings.TriggerSoundEnabled then
                        playSound(Settings.TriggerSoundId)
                    end
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
-- ОБРАБОТЧИК ПЕРСОНАЖА (СКОРОСТЬ ПРЫЖКА)
-- ============================
local function applyCharacterFeatures(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    
    if humanoid and hrp then
        humanoid.StateChanged:Connect(function(oldState, newState)
            if jumpSpeedEnabled and newState == Enum.HumanoidStateType.Jumping then
                local currentVelocity = hrp.AssemblyLinearVelocity
                local moveDir = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
                
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit * TARGET_JUMP_SPEED
                else
                    moveDir = hrp.CFrame.LookVector * TARGET_JUMP_SPEED
                end
                
                hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X, currentVelocity.Y, moveDir.Z)
            end
        end)
    end
end

if LocalPlayer.Character then
    applyCharacterFeatures(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(applyCharacterFeatures)

-- ============================
-- ОБНОВЛЕНИЕ СПИНА (КРУТИЛКИ) С УЧЕТОМ СМЕРТИ
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
                local c = LocalPlayer.Character
                if not c then return end
                local root = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChildOfClass("Humanoid")
                if root and h then
                    h.AutoRotate = false
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(SPIN_SPEED), 0)
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

LocalPlayer.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    if spinEnabled then
        updateSpin()
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
-- BHOP + МИСК
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
    Name = "Auto Trigger (Спам выстрелами)",
    CurrentValue = false,
    Flag = "AutoTriggerToggle",
    Callback = function(v) Settings.AutoTrigger = v end
})

CombatTab:CreateToggle({
    Name = "Visible Check (С прострелом стен)",
    CurrentValue = true,
    Flag = "VisibleCheckToggle",
    Callback = function(v) Settings.VisibleCheck = v end
})

CombatTab:CreateSlider({
    Name = "Макс. дистанция прострела",
    Range = {10, 300},
    Increment = 10,
    Suffix = " studs",
    CurrentValue = 100,
    Flag = "MaxWallbangDistSlider",
    Callback = function(v) Settings.MaxWallbangDistance = v end
})

CombatTab:CreateSlider({
    Name = "Макс. толщина стены",
    Range = {1, 20},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 6,
    Flag = "MaxWallThicknessSlider",
    Callback = function(v) Settings.MaxWallThickness = v end
})

CombatTab:CreateSection("Трейл пули (Bullet Trail)")

CombatTab:CreateToggle({
    Name = "Включить трейл пули",
    CurrentValue = false,
    Flag = "BulletTrailToggle",
    Callback = function(v) Settings.BulletTrailEnabled = v end
})

CombatTab:CreateColorPicker({
    Name = "Цвет трейла",
    Color = Color3.fromRGB(255, 0, 80),
    Flag = "BulletTrailColorPicker",
    Callback = function(v) Settings.BulletTrailColor = v end
})

CombatTab:CreateSlider({
    Name = "Толщина трейла",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.2,
    Flag = "BulletTrailWidthSlider",
    Callback = function(v) Settings.BulletTrailWidth = v end
})

CombatTab:CreateSlider({
    Name = "Время жизни трейла",
    Range = {0.1, 2},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 0.3,
    Flag = "BulletTrailLifetimeSlider",
    Callback = function(v) Settings.BulletTrailLifetime = v end
})

CombatTab:CreateSlider({
    Name = "КД трейла (Задержка)",
    Range = {0, 2},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.3,
    Flag = "BulletTrailCD",
    Callback = function(v) Settings.BulletTrailCooldown = v end
})

CombatTab:CreateSection("Звуки выстрела Trigger-бота")

CombatTab:CreateToggle({
    Name = "Включить звук при выстреле",
    CurrentValue = false,
    Flag = "TriggerSoundToggle",
    Callback = function(v) Settings.TriggerSoundEnabled = v end
})

local soundOptions = {
    "140325083438865",
    "73332070629063",
    "71173310238334",
    "114072050006157",
    "133319559387398",
    "8568536678",
    "82900255403344",
    "128418218662188",
    "6837721511",
    "2868331684"
}

CombatTab:CreateDropdown({
    Name = "Выберите звук выстрела",
    Options = soundOptions,
    CurrentOption = {soundOptions[1]},
    MultipleOptions = false,
    Flag = "TriggerSoundDropdown",
    Callback = function(v)
        if type(v) == "table" then
            Settings.TriggerSoundId = tostring(v[1] or soundOptions[1])
        else
            Settings.TriggerSoundId = tostring(v)
        end
    end
})

CombatTab:CreateButton({
    Name = "▶ Прослушать выбранный звук",
    Callback = function()
        playSound(Settings.TriggerSoundId)
        Rayfield:Notify({
            Title = "Звук",
            Content = "Воспроизведение: " .. tostring(Settings.TriggerSoundId),
            Duration = 2,
            Image = 4483362458,
        })
    end
})

CombatTab:CreateSlider({
    Name = "Громкость звука",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "",
    CurrentValue = 1,
    Flag = "TriggerSoundVol",
    Callback = function(v) Settings.TriggerSoundVolume = v end
})

CombatTab:CreateSlider({
    Name = "КД звука (Задержка)",
    Range = {0, 2},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = 0.3,
    Flag = "TriggerSoundCD",
    Callback = function(v) Settings.TriggerSoundCooldown = v end
})

CombatTab:CreateSection("Выбор хитбокса (Цель)")

CombatTab:CreateToggle({
    Name = "Голова (Head)",
    CurrentValue = true,
    Flag = "AimHeadToggle",
    Callback = function(v)
        if v then
            Settings.AimPart = "Head"
        end
    end
})

CombatTab:CreateToggle({
    Name = "Торс (Torso)",
    CurrentValue = false,
    Flag = "AimTorsoToggle",
    Callback = function(v)
        if v then
            Settings.AimPart = "Torso"
        end
    end
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
    CurrentOption = {"Bottom"},
    MultipleOptions = false,
    Flag = "ESPLineOriginDropdown",
    Callback = function(v) 
        if type(v) == "table" then
            Settings.ESPLineOrigin = tostring(v[1] or "Bottom")
        else
            Settings.ESPLineOrigin = tostring(v)
        end
    end
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
    Name = "Bhop (Авто-прыжок)",
    CurrentValue = false,
    Flag = "BhopToggle",
    Callback = function(v) bhopEnabled = v end
})

MiscTab:CreateToggle({
    Name = "Фиксация скорости прыжка (25)",
    CurrentValue = true,
    Flag = "JumpSpeedToggle",
    Callback = function(v) jumpSpeedEnabled = v end
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
    Content = "Скрипт успешно обновлен (Приоритет видимости + Толщина стен)!",
    Duration = 3,
    Image = 4483362458,
})