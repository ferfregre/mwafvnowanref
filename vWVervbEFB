--[[
    MM2 - X Hub (Mobile Edition) – FIXED
    Полностью переработанный скрипт для мобильных устройств.
    Кнопка в правом верхнем углу открывает/закрывает меню.
    Все элементы адаптированы под касания.
--]]

-- Проверка игры
if game.PlaceId ~= 142823291 then
    warn("Этот скрипт только для Murder Mystery 2!")
    return
end

-- ==================== СЕРВИСЫ ====================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Персонаж
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ==================== ПЕРЕМЕННЫЕ ====================
local ESPEnabled = {
    Murderer = false,
    Sheriff = false,
    DroppedGun = false
}
local FarmCoinsEnabled = false
local farmCooldown = 0.1
local loopMovement = false
local killAllEnabled = false
local noclipEnabled = false
local WalkspeedValue = 16
local JumpPowerValue = 50
local aimMurdererEnabled = false
local menuOpen = false

-- ==================== УТИЛИТЫ ====================
local function notify(text)
    game.StarterGui:SetCore("SendNotification", {
        Title = "MM2 - X Hub",
        Text = text,
        Duration = 3
    })
end

-- ==================== ФУНКЦИИ ESP ====================
local function addHighlight(part, color, text)
    if not part then return end
    -- Удаляем старые
    for _, obj in pairs(part:GetChildren()) do
        if obj:IsA("Highlight") or obj:IsA("BillboardGui") then
            obj:Destroy()
        end
    end
    local highlight = Instance.new("Highlight", part)
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    if part:IsA("Model") and part:FindFirstChild("Head") then
        local billboard = Instance.new("BillboardGui", part)
        billboard.Adornee = part.Head
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        local label = Instance.new("TextLabel", billboard)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color
        label.TextScaled = true
        label.Font = Enum.Font.SourceSansBold
    end
end

local function removeESP(part)
    if not part then return end
    for _, obj in pairs(part:GetChildren()) do
        if obj:IsA("Highlight") or obj:IsA("BillboardGui") then
            obj:Destroy()
        end
    end
end

local function updateESP()
    -- Убийца
    if ESPEnabled.Murderer then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Backpack:FindFirstChild("Knife") then
                addHighlight(plr.Character, Color3.new(1, 0, 0), "Murderer - " .. plr.Name)
            end
        end
    else
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                removeESP(plr.Character)
            end
        end
    end
    -- Шериф
    if ESPEnabled.Sheriff then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Backpack:FindFirstChild("Gun") then
                addHighlight(plr.Character, Color3.new(0, 0, 1), "Sheriff - " .. plr.Name)
            end
        end
    else
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                removeESP(plr.Character)
            end
        end
    end
    -- Выпавшее оружие
    if ESPEnabled.DroppedGun then
        local gunDrop = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("GunDrop")
        if gunDrop then
            addHighlight(gunDrop, Color3.new(0, 1, 0), "Dropped Gun")
        end
    else
        local gunDrop = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("GunDrop")
        if gunDrop then removeESP(gunDrop) end
    end
end

-- Цикл обновления ESP
RunService.RenderStepped:Connect(updateESP)

-- ==================== ФУНКЦИИ ДЕЙСТВИЙ ====================
local function teleportTo(target)
    if target and target.Character and target.Character.PrimaryPart then
        LocalPlayer.Character:SetPrimaryPartCFrame(target.Character.PrimaryPart.CFrame * CFrame.new(0, 0, 3))
        notify("Teleported to " .. target.Name)
    end
end

-- ==================== СОЗДАНИЕ МОБИЛЬНОГО GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "MM2_XHub_Mobile"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- ==================== КНОПКА ОТКРЫТИЯ МЕНЮ (УСИЛЕННАЯ) ====================
local toggleButton = Instance.new("ImageButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 70, 0, 70)
toggleButton.Position = UDim2.new(1, -85, 0, 15)
toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
toggleButton.BackgroundTransparency = 0.2
toggleButton.BorderSizePixel = 0
toggleButton.Image = "rbxassetid://6031091079"
toggleButton.ImageColor3 = Color3.new(1, 1, 1)
toggleButton.ScaleType = Enum.ScaleType.Fit
toggleButton.Parent = gui

local cornerBtn = Instance.new("UICorner", toggleButton)
cornerBtn.CornerRadius = UDim.new(0.5, 0)
local shadowBtn = Instance.new("UIShadow", toggleButton)
shadowBtn.Color = Color3.new(0, 0, 0)
shadowBtn.Offset = Vector2.new(0, 2)
shadowBtn.Blur = 4

-- ==================== МЕНЮ ====================
local menuFrame = Instance.new("Frame")
menuFrame.Name = "MenuFrame"
menuFrame.Size = UDim2.new(0, 350, 0, 500)
menuFrame.Position = UDim2.new(0.5, -175, 0.5, -250)
menuFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
menuFrame.BackgroundTransparency = 0.05
menuFrame.BorderSizePixel = 0
menuFrame.Visible = false
menuFrame.Parent = gui

local cornerMenu = Instance.new("UICorner", menuFrame)
cornerMenu.CornerRadius = UDim.new(0, 16)
local shadowMenu = Instance.new("UIShadow", menuFrame)
shadowMenu.Color = Color3.new(0, 0, 0)
shadowMenu.Offset = Vector2.new(0, 8)
shadowMenu.Blur = 16

-- Заголовок
local titleBar = Instance.new("Frame", menuFrame)
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
titleBar.BackgroundTransparency = 0.2
titleBar.BorderSizePixel = 0
local cornerTitle = Instance.new("UICorner", titleBar)
cornerTitle.CornerRadius = UDim.new(0, 12)

local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Size = UDim2.new(1, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "⚙️ MM2 X Hub"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
closeBtn.BackgroundTransparency = 0.3
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
local cornerClose = Instance.new("UICorner", closeBtn)
cornerClose.CornerRadius = UDim.new(0.5, 0)
closeBtn.MouseButton1Click:Connect(function()
    menuOpen = false
    menuFrame.Visible = false
end)
closeBtn.TouchTap:Connect(function()
    menuOpen = false
    menuFrame.Visible = false
end)

-- Область для вкладок (скроллинг)
local scrollContainer = Instance.new("ScrollingFrame", menuFrame)
scrollContainer.Size = UDim2.new(1, -20, 1, -50)
scrollContainer.Position = UDim2.new(0, 10, 0, 45)
scrollContainer.BackgroundTransparency = 1
scrollContainer.BorderSizePixel = 0
scrollContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollContainer.ScrollBarThickness = 6

-- ==================== ФУНКЦИИ ДЛЯ СОЗДАНИЯ UI ====================
local elements = {}

local function createTab(title)
    local frame = Instance.new("Frame", scrollContainer)
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = #elements + 1

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Color3.fromRGB(200, 200, 220)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left

    local content = Instance.new("Frame", frame)
    content.Size = UDim2.new(1, 0, 0, 0)
    content.BackgroundTransparency = 1

    local elementsTab = {frame = frame, content = content, uiElements = {}}
    table.insert(elements, elementsTab)
    return elementsTab
end

local function addToggle(tab, text, default, callback)
    local toggleFrame = Instance.new("Frame", tab.content)
    toggleFrame.Size = UDim2.new(1, 0, 0, 35)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    toggleFrame.BackgroundTransparency = 0.2
    toggleFrame.BorderSizePixel = 0
    local corner = Instance.new("UICorner", toggleFrame)
    corner.CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel", toggleFrame)
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBtn = Instance.new("TextButton", toggleFrame)
    toggleBtn.Size = UDim2.new(0, 60, 0, 25)
    toggleBtn.Position = UDim2.new(1, -70, 0.5, -12.5)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(80, 80, 80)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = default and "ON" or "OFF"
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.TextScaled = true
    toggleBtn.Font = Enum.Font.GothamBold
    local cornerToggle = Instance.new("UICorner", toggleBtn)
    cornerToggle.CornerRadius = UDim.new(0, 12)

    local state = default
    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(80, 80, 80)
        toggleBtn.Text = state and "ON" or "OFF"
        if callback then callback(state) end
    end)
    toggleBtn.TouchTap:Connect(function()
        state = not state
        toggleBtn.BackgroundColor3 = state and Color3.fromRGB(0, 200, 80) or Color3.fromRGB(80, 80, 80)
        toggleBtn.Text = state and "ON" or "OFF"
        if callback then callback(state) end
    end)

    tab.uiElements[#tab.uiElements+1] = toggleBtn
    tab.content.Size = UDim2.new(1, 0, 0, #tab.uiElements * 40)
    tab.frame.Size = UDim2.new(1, 0, 0, #tab.uiElements * 40 + 30)
    local totalHeight = 0
    for _, t in pairs(elements) do
        totalHeight = totalHeight + t.frame.Size.Y.Offset + 10
    end
    scrollContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
end

local function addSlider(tab, text, min, max, default, callback)
    local sliderFrame = Instance.new("Frame", tab.content)
    sliderFrame.Size = UDim2.new(1, 0, 0, 60)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    sliderFrame.BackgroundTransparency = 0.2
    sliderFrame.BorderSizePixel = 0
    local corner = Instance.new("UICorner", sliderFrame)
    corner.CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel", sliderFrame)
    label.Size = UDim2.new(0.7, 0, 0.4, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(default)
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.SourceSansBold
    label.TextXAlignment = Enum.TextXAlignment.Left

    local slider = Instance.new("Frame", sliderFrame)
    slider.Size = UDim2.new(0.8, 0, 0, 8)
    slider.Position = UDim2.new(0.1, 0, 0.6, 0)
    slider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    slider.BorderSizePixel = 0
    local cornerSlider = Instance.new("UICorner", slider)
    cornerSlider.CornerRadius = UDim.new(0, 4)

    local fill = Instance.new("Frame", slider)
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    fill.BorderSizePixel = 0
    local cornerFill = Instance.new("UICorner", fill)
    cornerFill.CornerRadius = UDim.new(0, 4)

    local valueLabel = Instance.new("TextLabel", sliderFrame)
    valueLabel.Size = UDim2.new(0.2, 0, 0.4, 0)
    valueLabel.Position = UDim2.new(0.8, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Color3.new(1, 1, 1)
    valueLabel.TextScaled = true
    valueLabel.Font = Enum.Font.SourceSansBold

    local dragging = false
    local function updateSlider(input)
        local pos = input.Position.X - slider.AbsolutePosition.X
        local width = slider.AbsoluteSize.X
        local percent = math.clamp(pos / width, 0, 1)
        local value = math.round(min + percent * (max - min))
        fill.Size = UDim2.new(percent, 0, 1, 0)
        valueLabel.Text = tostring(value)
        label.Text = text .. ": " .. tostring(value)
        if callback then callback(value) end
    end

    slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSlider(input)
        end
    end)
    slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    slider.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            updateSlider(input)
        end
    end)

    tab.uiElements[#tab.uiElements+1] = slider
    tab.content.Size = UDim2.new(1, 0, 0, #tab.uiElements * 70)
    tab.frame.Size = UDim2.new(1, 0, 0, #tab.uiElements * 70 + 30)
    local totalHeight = 0
    for _, t in pairs(elements) do
        totalHeight = totalHeight + t.frame.Size.Y.Offset + 10
    end
    scrollContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
end

local function addButton(tab, text, callback)
    local btnFrame = Instance.new("Frame", tab.content)
    btnFrame.Size = UDim2.new(1, 0, 0, 40)
    btnFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    btnFrame.BackgroundTransparency = 0.2
    btnFrame.BorderSizePixel = 0
    local corner = Instance.new("UICorner", btnFrame)
    corner.CornerRadius = UDim.new(0, 8)

    local btn = Instance.new("TextButton", btnFrame)
    btn.Size = UDim2.new(1, -20, 1, -10)
    btn.Position = UDim2.new(0, 10, 0, 5)
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    local cornerBtn2 = Instance.new("UICorner", btn)
    cornerBtn2.CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
    btn.TouchTap:Connect(function()
        if callback then callback() end
    end)

    tab.uiElements[#tab.uiElements+1] = btn
    tab.content.Size = UDim2.new(1, 0, 0, #tab.uiElements * 45)
    tab.frame.Size = UDim2.new(1, 0, 0, #tab.uiElements * 45 + 30)
    local totalHeight = 0
    for _, t in pairs(elements) do
        totalHeight = totalHeight + t.frame.Size.Y.Offset + 10
    end
    scrollContainer.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
end

-- ==================== СОЗДАНИЕ ВКЛАДОК И ЭЛЕМЕНТОВ ====================
local espTab = createTab("👁️ ESP")
addToggle(espTab, "ESP Убийца", false, function(v)
    ESPEnabled.Murderer = v
    if not v then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                removeESP(plr.Character)
            end
        end
    end
    updateESP()
end)
addToggle(espTab, "ESP Шериф", false, function(v)
    ESPEnabled.Sheriff = v
    if not v then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                removeESP(plr.Character)
            end
        end
    end
    updateESP()
end)
addToggle(espTab, "ESP Оружие", false, function(v)
    ESPEnabled.DroppedGun = v
    updateESP()
end)

local moveTab = createTab("🏃 Движение")
addSlider(moveTab, "Скорость", 16, 200, 16, function(v)
    WalkspeedValue = v
    humanoid.WalkSpeed = v
end)
addSlider(moveTab, "Прыжок", 50, 890, 50, function(v)
    JumpPowerValue = v
    humanoid.JumpPower = v
end)
addToggle(moveTab, "Циклическое сохранение", false, function(v)
    loopMovement = v
end)
addToggle(moveTab, "Noclip", false, function(v)
    noclipEnabled = v
end)

local utilTab = createTab("⚡ Утилиты")
addButton(utilTab, "Телепорт к убийце", function()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Backpack:FindFirstChild("Knife") then
            teleportTo(plr)
            break
        end
    end
end)
addButton(utilTab, "Телепорт к шерифу", function()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Backpack:FindFirstChild("Gun") then
            teleportTo(plr)
            break
        end
    end
end)
addButton(utilTab, "Телепорт к оружию", function()
    local gunDrop = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("GunDrop")
    if gunDrop then
        LocalPlayer.Character:SetPrimaryPartCFrame(gunDrop.CFrame * CFrame.new(0, 0, 3))
        notify("Телепорт к оружию")
    else
        notify("Оружие не найдено")
    end
end)
addToggle(utilTab, "Фарм монет", false, function(v)
    FarmCoinsEnabled = v
end)
addToggle(utilTab, "Kill All", false, function(v)
    killAllEnabled = v
end)
addToggle(utilTab, "Прицел на убийцу", false, function(v)
    aimMurdererEnabled = v
end)

local settingsTab = createTab("⚙️ Настройки")
addButton(settingsTab, "Загрузить Infinite Yield", function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
    notify("Infinite Yield загружен!")
end)
addButton(settingsTab, "Закрыть меню", function()
    menuOpen = false
    menuFrame.Visible = false
end)

-- ==================== ЦИКЛЫ ДЛЯ ФУНКЦИЙ ====================
RunService.RenderStepped:Connect(function()
    if loopMovement then
        humanoid.WalkSpeed = WalkspeedValue
        humanoid.JumpPower = JumpPowerValue
    end
end)

RunService.Stepped:Connect(function()
    if noclipEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

local function farmCoins()
    if not FarmCoinsEnabled then return end
    local container = Workspace:FindFirstChild("Normal") and Workspace.Normal:FindFirstChild("CoinContainer")
    if container then
        for _, coin in pairs(container:GetChildren()) do
            if coin:IsA("BasePart") then
                LocalPlayer.Character:SetPrimaryPartCFrame(coin.CFrame)
                task.wait(farmCooldown)
            end
        end
    end
end
RunService.Heartbeat:Connect(farmCoins)

local function killAllLoop()
    if not killAllEnabled then return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr:GetAttribute("Alive") == true then
            LocalPlayer.Character:SetPrimaryPartCFrame(plr.Character.PrimaryPart.CFrame)
            task.wait(0.5)
        end
    end
end
RunService.Heartbeat:Connect(killAllLoop)

local function aimAtMurderer()
    if not aimMurdererEnabled then return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and plr.Backpack:FindFirstChild("Knife") and LocalPlayer.Backpack:FindFirstChild("Gun") then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local camera = workspace.CurrentCamera
                camera.CFrame = CFrame.new(camera.CFrame.Position, head.Position)
            end
        end
    end
end
RunService.RenderStepped:Connect(aimAtMurderer)

-- ==================== ОТКРЫТИЕ/ЗАКРЫТИЕ МЕНЮ ====================
local function toggleMenu()
    print("toggleMenu вызвана!") -- Отладочное сообщение
    menuOpen = not menuOpen
    menuFrame.Visible = menuOpen
    print("menuOpen =", menuOpen, "visible =", menuFrame.Visible)
end

-- Усиленные обработчики нажатий
toggleButton.MouseButton1Click:Connect(toggleMenu)
toggleButton.TouchTap:Connect(toggleMenu)
toggleButton.TouchEnded:Connect(function(input)
    if input and input.UserInputType == Enum.UserInputType.Touch then
        toggleMenu()
    end
end)
toggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        toggleMenu()
    end
end)

-- ==================== АДАПТАЦИЯ ПОД МОБИЛЬНЫЕ ЭКРАНЫ ====================
local function resizeElements()
    local screenSize = game:GetService("GuiService"):GetScreenResolution()
    if screenSize.X < 600 then
        menuFrame.Size = UDim2.new(0, screenSize.X - 40, 0, screenSize.Y - 100)
        menuFrame.Position = UDim2.new(0.5, -(screenSize.X - 40)/2, 0.5, -(screenSize.Y - 100)/2)
        toggleButton.Size = UDim2.new(0, 70, 0, 70)
        toggleButton.Position = UDim2.new(1, -85, 0, 15)
    end
end
resizeElements()
game:GetService("GuiService").ScreenResolutionChanged:Connect(resizeElements)

print("✅ MM2 X Hub Mobile успешно загружен!")
notify("MM2 X Hub Mobile загружен! Нажмите на шестерёнку для открытия меню.")
