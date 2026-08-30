-- ============================================
-- @set9p | MM2 ULTIMATE SCRIPT HUB (FULL CUSTOM + GRAB GUN)
-- ============================================

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

-- ============================
-- НАСТРОЙКИ (SETTINGS)
-- ============================
local Settings = {
    -- Настройки ESP ролей
    RoleESP = false,
    ShowMurderer = true,
    ShowSheriff = true,
    ShowInnocent = true,
    
    -- Кастомизация визуары ESP
    ESPText = true,      -- Показывать текст с именем и ролью
    ESPBox = true,       -- Рисовать рамку (бокс)
    ESPLine = false,     -- Линии до целей
    
    -- ESP для упавшего пистолета
    DropGunESP = true,
    AutoGrabGun = false, -- Авто-телепорт к упавшему пистолету
    
    -- Остальные функции
    BhopEnabled = false,
    JumpSpeedEnabled = true,
    TargetJumpSpeed = 25,
    SpinEnabled = false,
    SpinSpeed = 25,
}

local spaceHeld = false
local spinConnection = nil
local roleESPObjects = {}
local droppedGunESPObject = nil

-- ============================
-- ОПРЕДЕЛЕНИЕ РОЛЕЙ MM2
-- ============================
local function getPlayerRole(player)
    if player == LocalPlayer then return "Local" end
    
    local character = player.Character
    if not character then return "Innocent" end
    
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then
            local name = item.Name:lower()
            if name:find("knife") or name:find("dagger") or name == "cutter" or item:FindFirstChild("KnifeScript") then
                return "Marder"
            elseif name:find("gun") or name:find("revolver") or name == "sheriff" or item:FindFirstChild("GunScript") then
                return "Sherif"
            end
        end
    end
    
    for _, child in ipairs(player:GetChildren()) do
        if child:IsA("StringValue") or child:IsA("IntValue") then
            local valName = child.Name:lower()
            local valContent = tostring(child.Value):lower()
            if valName:find("role") or valContent:find("murderer") or valContent:find("marder") then
                return "Marder"
            elseif valContent:find("sheriff") then
                return "Sherif"
            end
        end
    end
    
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local name = item.Name:lower()
                if name:find("knife") or name:find("dagger") or item:FindFirstChild("KnifeScript") then
                    return "Marder"
                elseif name:find("gun") or name:find("revolver") or item:FindFirstChild("GunScript") then
                    return "Sherif"
                end
            end
        end
    end
    
    return "Innocent"
end

-- ============================
-- ПОИСК УПАВШЕГО ПИСТОЛЕТА НА КАРТЕ
-- ============================
local function findDroppedGun()
    -- В MM2 упавший пистолет обычно называется "Gun" или "Revolver" в Workspace и лежит на земле (не в персонаже)
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Tool") then
            local name = obj.Name:lower()
            if name == "gun" or name == "revolver" or name:find("gun") then
                -- Проверяем, что у него нет владельца (что он лежит на карте)
                if not obj.Parent or obj.Parent == Workspace then
                    return obj
                end
            end
        end
    end
    return nil
end

-- ============================
-- ESP РОЛЕЙ (С УЧЕТОМ НАСТРОЕК)
-- ============================
local function removeRoleESP(player)
    if roleESPObjects[player] then
        for _, obj in pairs(roleESPObjects[player]) do
            pcall(function() obj:Destroy() end)
        end
        roleESPObjects[player] = nil
    end
end

local function updateRoleESP()
    -- Логика для упавшего пистолета
    local droppedGun = findDroppedGun()
    if Settings.DropGunESP and droppedGun then
        local handle = droppedGun:FindFirstChild("Handle") or droppedGun:FindFirstChildOfClass("BasePart")
        if handle then
            if not droppedGunESPObject then
                local bb = Instance.new("BillboardGui")
                bb.Name = "DroppedGun_ESP"
                bb.Size = UDim2.new(0, 150, 0, 40)
                bb.StudsOffset = Vector3.new(0, 2, 0)
                bb.AlwaysOnTop = true
                
                local txt = Instance.new("TextLabel", bb)
                txt.Size = UDim2.new(1, 0, 1, 0)
                txt.BackgroundTransparency = 1
                txt.TextColor3 = Color3.fromRGB(255, 255, 0) -- Желтый
                txt.TextSize = 14
                txt.Font = Enum.Font.SourceSansBold
                txt.TextStrokeTransparency = 0
                txt.Text = "🔫 [DROPPED GUN]"
                
                bb.Parent = handle
                droppedGunESPObject = bb
            end
            
            -- Авто-подбор (телепорт к пистолету и обратно)
            if Settings.AutoGrabGun then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local originalCFrame = hrp.CFrame
                    hrp.CFrame = handle.CFrame + Vector3.new(0, 3, 0)
                    task.wait(0.1)
                    -- Возвращаемся на место
                    hrp.CFrame = originalCFrame
                    Settings.AutoGrabGun = false -- Отключаем тумблер после срабатывания, чтобы не спамило
                end
            end
        end
    else
        if droppedGunESPObject then
            pcall(function() droppedGunESPObject:Destroy() end)
            droppedGunESPObject = nil
        end
    end

    -- Логика для игроков
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            
            if Settings.RoleESP and char and hrp and hum and hum.Health > 0 then
                local role = getPlayerRole(player)
                local shouldShow = false
                local color = Color3.fromRGB(255, 255, 255)
                local textStr = player.Name
                
                if role == "Marder" and Settings.ShowMurderer then
                    shouldShow = true
                    color = Color3.fromRGB(255, 50, 50)
                    textStr = "🔪 " .. player.Name .. " [MURDERER]"
                elseif role == "Sherif" and Settings.ShowSheriff then
                    shouldShow = true
                    color = Color3.fromRGB(50, 150, 255)
                    textStr = "🔫 " .. player.Name .. " [SHERIFF]"
                elseif role == "Innocent" and Settings.ShowInnocent then
                    shouldShow = true
                    color = Color3.fromRGB(50, 255, 50)
                    textStr = "👤 " .. player.Name .. " [Innocent]"
                end
                
                if shouldShow then
                    if not roleESPObjects[player] then
                        local billboard = Instance.new("BillboardGui")
                        billboard.Name = "MM2_ESP"
                        billboard.Size = UDim2.new(0, 200, 0, 50)
                        billboard.StudsOffset = Vector3.new(0, 3, 0)
                        billboard.AlwaysOnTop = true
                        
                        local textLabel = Instance.new("TextLabel", billboard)
                        textLabel.Name = "ESPText"
                        textLabel.Size = UDim2.new(1, 0, 1, 0)
                        textLabel.BackgroundTransparency = 1
                        textLabel.TextScaled = false
                        textLabel.TextSize = 14
                        textLabel.TextColor3 = color
                        textLabel.Font = Enum.Font.SourceSansBold
                        textLabel.TextStrokeTransparency = 0
                        
                        billboard.Parent = hrp
                        roleESPObjects[player] = {Billboard = billboard, Text = textLabel}
                    else
                        local data = roleESPObjects[player]
                        data.Text.Text = textStr
                        data.Text.TextColor3 = color
                        data.Text.Visible = Settings.ESPText
                        data.Billboard.Enabled = true
                    end
                else
                    if roleESPObjects[player] and roleESPObjects[player].Billboard then
                        roleESPObjects[player].Billboard.Enabled = false
                    end
                end
            else
                removeRoleESP(player)
            end
        end
    end
end

RunService.RenderStepped:Connect(updateRoleESP)
Players.PlayerRemoving:Connect(removeRoleESP)

-- ============================
-- INVISIBLE (КЛОН ВНИЗУ / ТЕЛО НАВЕРХУ)
-- ============================
local invisibleEnabled = false
local invisibleConnection = nil
local savedCFrame = nil
local fakeClone = nil
local SCRIPT_SKY_HEIGHT = 1000

local function toggleInvisible()
    invisibleEnabled = not invisibleEnabled
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if invisibleEnabled then
        if hrp then savedCFrame = hrp.CFrame end
        
        pcall(function()
            char.Archivable = true
            fakeClone = char:Clone()
            for _, child in ipairs(fakeClone:GetDescendants()) do
                if child:IsA("Script") or child:IsA("LocalScript") then
                    child:Destroy()
                end
            end
            fakeClone.Parent = Workspace
            for _, part in ipairs(fakeClone:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
        
        if invisibleConnection then invisibleConnection:Disconnect() end
        
        invisibleConnection = RunService.RenderStepped:Connect(function()
            local c = LocalPlayer.Character
            if not c then return end
            local root = c:FindFirstChild("HumanoidRootPart")
            if not root then return end
            
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("Decal") then
                    part.LocalTransparencyModifier = 1
                end
            end
            
            root.CFrame = CFrame.new(Camera.CFrame.Position + Vector3.new(0, SCRIPT_SKY_HEIGHT, 0))
            root.AssemblyLinearVelocity = Vector3.zero
            
            if fakeClone and fakeClone:FindFirstChild("HumanoidRootPart") then
                local cloneHRP = fakeClone.HumanoidRootPart
                cloneHRP.CFrame = CFrame.new(Camera.CFrame.Position - Vector3.new(0, 3, 0), Camera.CFrame.Position + Camera.CFrame.LookVector * 10)
            end
        end)
    else
        if invisibleConnection then
            invisibleConnection:Disconnect()
            invisibleConnection = nil
        end
        
        if fakeClone then
            fakeClone:Destroy()
            fakeClone = nil
        end
        
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.LocalTransparencyModifier = 0
            end
        end
        
        if savedCFrame and hrp then
            hrp.CFrame = savedCFrame
        end
    end
end

-- ============================
-- BHOP & JUMP SPEED
-- ============================
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then spaceHeld = true end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then spaceHeld = false end
end)

local function applyJumpFeatures(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    
    if humanoid and hrp then
        humanoid.StateChanged:Connect(function(oldState, newState)
            if Settings.JumpSpeedEnabled and newState == Enum.HumanoidStateType.Jumping then
                local currentVel = hrp.AssemblyLinearVelocity
                local moveDir = Vector3.new(currentVel.X, 0, currentVel.Z)
                
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit * Settings.TargetJumpSpeed
                else
                    moveDir = hrp.CFrame.LookVector * Settings.TargetJumpSpeed
                end
                
                hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X, currentVel.Y, moveDir.Z)
            end
        end)
    end
end

if LocalPlayer.Character then applyJumpFeatures(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(applyJumpFeatures)

task.spawn(function()
    while true do
        task.wait()
        if Settings.BhopEnabled and spaceHeld then
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

-- ============================
-- SPIN (КРУТИЛКА)
-- ============================
local function updateSpinState()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    if Settings.SpinEnabled then
        hum.AutoRotate = false
        if not spinConnection then
            spinConnection = RunService.RenderStepped:Connect(function()
                local c = LocalPlayer.Character
                if not c then return end
                local root = c:FindFirstChild("HumanoidRootPart")
                local h = c:FindFirstChildOfClass("Humanoid")
                if root and h then
                    h.AutoRotate = false
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(Settings.SpinSpeed), 0)
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

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    if Settings.SpinEnabled then updateSpinState() end
end)

-- ============================
-- МЕНЮ (RAYFIELD UI)
-- ============================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
if not Rayfield then return end

local Window = Rayfield:CreateWindow({
    Name = "MM2 | Ультра Меню v2.0",
    LoadingTitle = "Загрузка Murder Mystery 2...",
    LoadingSubtitle = "by @set9p",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

local ESPTab = Window:CreateTab("Роли & ESP", 4483362458)

ESPTab:CreateToggle({
    Name = "Включить Role ESP",
    CurrentValue = false,
    Flag = "RoleESPToggle",
    Callback = function(v) Settings.RoleESP = v end
})

ESPTab:CreateSection("Фильтры ролей")

ESPTab:CreateToggle({
    Name = "Показывать Murderer (Убийца 🔪)",
    CurrentValue = true,
    Flag = "ShowMarderToggle",
    Callback = function(v) Settings.ShowMurderer = v end
})

ESPTab:CreateToggle({
    Name = "Показывать Sheriff (Шериф 🔫)",
    CurrentValue = true,
    Flag = "ShowSheriffToggle",
    Callback = function(v) Settings.ShowSheriff = v end
})

ESPTab:CreateToggle({
    Name = "Показывать Innocent (Мирные 👤)",
    CurrentValue = true,
    Flag = "ShowInnocentToggle",
    Callback = function(v) Settings.ShowInnocent = v end
})

ESPTab:CreateSection("Настройка отображения ESP")

ESPTab:CreateToggle({
    Name = "Текст с именем/ролью",
    CurrentValue = true,
    Flag = "ESPTextToggle",
    Callback = function(v) Settings.ESPText = v end
})

ESPTab:CreateSection("Упавший пистолет (Drop Gun)")

ESPTab:CreateToggle({
    Name = "ESP на упавший пистолет",
    CurrentValue = true,
    Flag = "DropGunESPToggle",
    Callback = function(v) Settings.DropGunESP = v end
})

ESPTab:CreateToggle({
    Name = "Grab Gun (Авто-подбор с возвратом)",
    CurrentValue = false,
    Flag = "AutoGrabGunToggle",
    Callback = function(v) Settings.AutoGrabGun = v end
})

local MovementTab = Window:CreateTab("Игрок & Функции", 4483362458)

MovementTab:CreateToggle({
    Name = "Invisible (Клон внизу / Тело наверху)",
    CurrentValue = false,
    Flag = "InvisibleToggle",
    Callback = function(v)
        toggleInvisible()
    end
})

MovementTab:CreateToggle({
    Name = "Spin (Крутилка)",
    CurrentValue = false,
    Flag = "SpinToggle",
    Callback = function(v)
        Settings.SpinEnabled = v
        updateSpinState()
    end
})

MovementTab:CreateSlider({
    Name = "Скорость вращения (Spin Speed)",
    Range = {5, 100},
    Increment = 5,
    Suffix = "°",
    CurrentValue = 25,
    Flag = "SpinSpeedSlider",
    Callback = function(v) Settings.SpinSpeed = v end
})

MovementTab:CreateSection("Настройки прыжка и Bhop")

MovementTab:CreateToggle({
    Name = "Bhop (Авто-прыжок)",
    CurrentValue = false,
    Flag = "BhopToggle",
    Callback = function(v) Settings.BhopEnabled = v end
})

MovementTab:CreateToggle({
    Name = "Ускорение в полете (Jump Speed)",
    CurrentValue = true,
    Flag = "JumpSpeedToggle",
    Callback = function(v) Settings.JumpSpeedEnabled = v end
})

MovementTab:CreateSlider({
    Name = "Сила ускорения в полете",
    Range = {10, 80},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 25,
    Flag = "JumpSpeedSliderValue",
    Callback = function(v) Settings.TargetJumpSpeed = v end
})

Rayfield:Notify({
    Title = "Обновление v2.0!",
    Content = "Добавлены настройки ESP и функция Grab Gun для пистолета.",
    Duration = 3,
    Image = 4483362458,
})