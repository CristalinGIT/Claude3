local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local enemies = workspace:WaitForChild("Enemies")
local camera = workspace.CurrentCamera
local BS = Config.BlockSize

local state = { inv = {}, pick = 0, sword = 0 }
local selected = 1

---------------------------------------------------------------- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "TerrariaGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local hotbar = Instance.new("Frame")
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -10)
hotbar.Size = UDim2.new(0, #Config.Items * 66, 0, 66)
hotbar.BackgroundTransparency = 1
hotbar.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 4)
layout.Parent = hotbar

local slots = {}
for i, item in Config.Items do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 62, 0, 62)
	b.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	b.BackgroundTransparency = 0.2
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 13
	b.Font = Enum.Font.GothamBold
	b.AutoButtonColor = false
	b.Parent = hotbar
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(80, 80, 90)
	stroke.Parent = b
	b.MouseButton1Click:Connect(function()
		selected = i
	end)
	slots[i] = { button = b, stroke = stroke }
end

local info = Instance.new("TextLabel")
info.AnchorPoint = Vector2.new(0.5, 1)
info.Position = UDim2.new(0.5, 0, 1, -82)
info.Size = UDim2.new(0, 500, 0, 22)
info.BackgroundTransparency = 1
info.TextColor3 = Color3.new(1, 1, 1)
info.TextStrokeTransparency = 0.4
info.Font = Enum.Font.GothamMedium
info.TextSize = 15
info.Parent = gui

local help = Instance.new("TextLabel")
help.Position = UDim2.new(0, 10, 0, 10)
help.Size = UDim2.new(0, 360, 0, 70)
help.BackgroundTransparency = 1
help.TextXAlignment = Enum.TextXAlignment.Left
help.TextYAlignment = Enum.TextYAlignment.Top
help.TextColor3 = Color3.new(1, 1, 1)
help.TextStrokeTransparency = 0.4
help.Font = Enum.Font.Gotham
help.TextSize = 14
help.Text = "ЛКМ (удерживать) — копать / бить\nПКМ — поставить блок\n1-8 — выбор предмета, C — крафт"
help.Parent = gui

local craft = Instance.new("Frame")
craft.AnchorPoint = Vector2.new(1, 0.5)
craft.Position = UDim2.new(1, -10, 0.5, 0)
craft.Size = UDim2.new(0, 250, 0, #Config.Recipes * 46 + 34)
craft.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
craft.BackgroundTransparency = 0.2
craft.Parent = gui

local craftTitle = Instance.new("TextLabel")
craftTitle.Size = UDim2.new(1, 0, 0, 30)
craftTitle.BackgroundTransparency = 1
craftTitle.Text = "Крафт (C)"
craftTitle.TextColor3 = Color3.new(1, 1, 1)
craftTitle.Font = Enum.Font.GothamBold
craftTitle.TextSize = 16
craftTitle.Parent = craft

local craftButtons = {}
for i, recipe in Config.Recipes do
	local parts = {}
	for item, n in recipe.cost do
		table.insert(parts, item .. " " .. n)
	end
	table.sort(parts)
	local b = Instance.new("TextButton")
	b.Position = UDim2.new(0, 6, 0, 32 + (i - 1) * 46)
	b.Size = UDim2.new(1, -12, 0, 42)
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = recipe.name .. "\n" .. table.concat(parts, ", ")
	b.Parent = craft
	b.MouseButton1Click:Connect(function()
		Remotes.Craft:FireServer(i)
	end)
	craftButtons[i] = b
end

local function canCraft(recipe)
	if recipe.pick and state.pick >= recipe.pick then
		return false
	end
	if recipe.sword and state.sword >= recipe.sword then
		return false
	end
	for item, n in recipe.cost do
		if (state.inv[item] or 0) < n then
			return false
		end
	end
	return true
end

local function refreshUI()
	for i, item in Config.Items do
		local slot = slots[i]
		slot.button.Text = ("%d\n%s\n%d"):format(i, item.name, state.inv[item.name] or 0)
		slot.stroke.Color = (i == selected) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(80, 80, 90)
	end
	info.Text = ("Кирка: ур. %d   Меч: ур. %d"):format(state.pick, state.sword)
	for i, recipe in Config.Recipes do
		craftButtons[i].BackgroundColor3 = canCraft(recipe) and Color3.fromRGB(50, 130, 60) or Color3.fromRGB(70, 70, 75)
	end
end

Remotes.State.OnClientEvent:Connect(function(s)
	state = s
	refreshUI()
end)
refreshUI()

---------------------------------------------------------------- Ввод
local holdL, holdR = false, false

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
		holdL = true
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
		holdR = true
	elseif input.UserInputType == Enum.UserInputType.Keyboard and not processed then
		if input.KeyCode == Enum.KeyCode.C then
			craft.Visible = not craft.Visible
		else
			local n = tonumber(input.KeyCode.Name:match("^%a+(%d)$") or input.KeyCode.Name:match("^(%d)$"))
			if n == nil then
				local words = { One = 1, Two = 2, Three = 3, Four = 4, Five = 5, Six = 6, Seven = 7, Eight = 8 }
				n = words[input.KeyCode.Name]
			end
			if n and Config.Items[n] then
				selected = n
				refreshUI()
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holdL = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		holdR = false
	end
end)

local function mouseCell()
	local loc = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(loc.X, loc.Y)
	if math.abs(ray.Direction.Z) < 1e-4 then
		return nil
	end
	local t = -ray.Origin.Z / ray.Direction.Z
	local p = ray.Origin + ray.Direction * t
	return math.floor(p.X / BS) + 1, math.floor(p.Y / BS) + 1
end

local enemyParams = RaycastParams.new()
enemyParams.FilterType = Enum.RaycastFilterType.Include
enemyParams.FilterDescendantsInstances = { enemies }

local function enemyUnderMouse()
	local loc = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(loc.X, loc.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, enemyParams)
	return hit and hit.Instance:FindFirstAncestorOfClass("Model")
end

-- Подсветка клетки под курсором
local marker = Instance.new("Part")
marker.Anchored = true
marker.CanCollide = false
marker.CanQuery = false
marker.Transparency = 1
marker.Size = Vector3.new(BS, BS, BS)
marker.Parent = workspace
local box = Instance.new("SelectionBox")
box.Adornee = marker
box.LineThickness = 0.04
box.Color3 = Color3.new(1, 1, 1)
box.Parent = marker

---------------------------------------------------------------- Цикл
local mineT, placeT = 0, 0

RunService.RenderStepped:Connect(function(dt)
	camera.CameraType = Enum.CameraType.Scriptable
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local focus = hrp.Position + Vector3.new(0, 3, 0)
	camera.FieldOfView = 70
	camera.CFrame = CFrame.lookAt(Vector3.new(focus.X, focus.Y, 55), Vector3.new(focus.X, focus.Y, 0))

	local cx, cy = mouseCell()
	if cx then
		marker.Position = Vector3.new((cx - 0.5) * BS, (cy - 0.5) * BS, 0)
		box.Visible = true
	else
		box.Visible = false
		return
	end

	mineT += dt
	placeT += dt
	if holdL and mineT >= 0.1 then
		mineT = 0
		local enemy = enemyUnderMouse()
		if enemy then
			Remotes.Attack:FireServer(enemy)
		else
			Remotes.Mine:FireServer(cx, cy)
		end
	end
	if holdR and placeT >= 0.15 then
		placeT = 0
		local item = Config.Items[selected]
		if item and item.place then
			Remotes.Place:FireServer(cx, cy, item.name)
		end
	end
end)

-- Держим персонажа в плоскости Z = 0 (2D-режим)
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and math.abs(hrp.Position.Z) > 0.05 then
		local p = hrp.Position
		hrp.CFrame = CFrame.new(p.X, p.Y, 0) * hrp.CFrame.Rotation
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
	end
end)
