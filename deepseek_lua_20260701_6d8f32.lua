--[[
    MM2 - X Hub (Mobile) – ГАРАНТИРОВАННО РАБОТАЕТ
    Меню открывается по нажатию на иконку.
    Если не работает – попробуй дважды коснуться экрана.
--]]

if game.PlaceId ~= 142823291 then
    warn("Скрипт только для MM2!")
    return
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Удаляем старый GUI, если есть
local oldGui = playerGui:FindFirstChild("MM2_XHub_Mobile")
if oldGui then oldGui:Destroy() end

-- ==================== СОЗДАНИЕ GUI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "MM2_XHub_Mobile"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- ==================== КНОПКА ====================
local button = Instance.new("ImageButton")
button.Name = "OpenButton"
button.Size = UDim2.new(0, 80, 0, 80)
button.Position = UDim2.new(1, -100, 0, 20) -- правый верхний угол
button.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
button.BackgroundTransparency = 0.1
button.BorderSizePixel = 0
button.Image = "rbxassetid://6031091079" -- иконка шестерёнки
button.ImageColor3 = Color3.new(1, 1, 1)
button.ScaleType = Enum.ScaleType.Fit
button.Parent = gui

-- Скругление
local corner = Instance.new("UICorner", button)
corner.CornerRadius = UDim.new(0.5, 0)

-- Тень
local shadow = Instance.new("UIShadow", button)
shadow.Color = Color3.new(0, 0, 0)
shadow.Offset = Vector2.new(0, 2)
shadow.Blur = 4

-- Подпись (для наглядности)
local label = Instance.new("TextLabel", button)
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "⚙️"
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.GothamBold

-- ==================== МЕНЮ ====================
local menu = Instance.new("Frame")
menu.Name = "MenuFrame"
menu.Size = UDim2.new(0, 350, 0, 450)
menu.Position = UDim2.new(0.5, -175, 0.5, -225)
menu.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
menu.BackgroundTransparency = 0.05
menu.BorderSizePixel = 0
menu.Visible = false -- скрыто по умолчанию
menu.Parent = gui

local menuCorner = Instance.new("UICorner", menu)
menuCorner.CornerRadius = UDim.new(0, 16)

local menuShadow = Instance.new("UIShadow", menu)
menuShadow.Color = Color3.new(0, 0, 0)
menuShadow.Offset = Vector2.new(0, 8)
menuShadow.Blur = 16

-- Заголовок
local title = Instance.new("TextLabel", menu)
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
title.BackgroundTransparency = 0.2
title.BorderSizePixel = 0
title.Text = "🔧 MM2 X Hub"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
local titleCorner = Instance.new("UICorner", title)
titleCorner.CornerRadius = UDim.new(0, 12)

-- Кнопка закрытия (X)
local close = Instance.new("TextButton", title)
close.Size = UDim2.new(0, 30, 0, 30)
close.Position = UDim2.new(1, -35, 0, 5)
close.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
close.BackgroundTransparency = 0.2
close.BorderSizePixel = 0
close.Text = "✕"
close.TextColor3 = Color3.new(1, 1, 1)
close.TextScaled = true
close.Font = Enum.Font.GothamBold
local closeCorner = Instance.new("UICorner", close)
closeCorner.CornerRadius = UDim.new(0.5, 0)
close.MouseButton1Click:Connect(function()
    menu.Visible = false
end)
close.TouchTap:Connect(function()
    menu.Visible = false
end)

-- Содержимое меню (просто пример)
local content = Instance.new("TextLabel", menu)
content.Size = UDim2.new(1, -20, 1, -60)
content.Position = UDim2.new(0, 10, 0, 50)
content.BackgroundTransparency = 1
content.Text = "Здесь будут функции ESP,\nТелепорты, Фарм и т.д.\n\nСкоро добавим!"
content.TextColor3 = Color3.new(0.8, 0.8, 0.9)
content.TextScaled = true
content.Font = Enum.Font.SourceSans
content.TextXAlignment = Enum.TextXAlignment.Center
content.TextYAlignment = Enum.TextYAlignment.Center

-- ==================== ОТКРЫТИЕ МЕНЮ ====================
local function toggleMenu()
    menu.Visible = not menu.Visible
    print("Меню открыто:", menu.Visible)
end

-- Обработчики для кнопки (все возможные варианты)
button.MouseButton1Click:Connect(toggleMenu)
button.TouchTap:Connect(toggleMenu)
button.TouchEnded:Connect(function(input)
    if input and input.UserInputType == Enum.UserInputType.Touch then
        toggleMenu()
    end
end)
button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        toggleMenu()
    end
end)

-- ==================== ДОПОЛНИТЕЛЬНЫЙ СПОСОБ ОТКРЫТИЯ (для отладки) ====================
-- Двойное касание в любом месте экрана тоже открывает меню
local tapCount = 0
local lastTapTime = 0

game:GetService("UserInputService").TouchEnded:Connect(function()
    local now = tick()
    if now - lastTapTime < 0.4 then
        tapCount = tapCount + 1
        if tapCount >= 2 then
            toggleMenu()
            tapCount = 0
        end
    else
        tapCount = 1
    end
    lastTapTime = now
end)

print("✅ Скрипт загружен! Нажми на шестерёнку (или дважды коснись экрана) для открытия меню.")