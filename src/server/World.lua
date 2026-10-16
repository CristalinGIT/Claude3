-- Мир: сетка блоков (x вправо, y вверх), генерация и отображение частями.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local BS = Config.BlockSize
local W, H = Config.Width, Config.Height

local World = { ready = false }

local grid = {}
local parts = {}
local folder = Instance.new("Folder")
folder.Name = "Blocks"
folder.Parent = workspace

function World.inBounds(x, y)
	return x >= 1 and x <= W and y >= 1 and y <= H
end

function World.get(x, y)
	local col = grid[x]
	return col and col[y]
end

function World.cellToPos(x, y)
	return Vector3.new((x - 0.5) * BS, (y - 0.5) * BS, 0)
end

function World.posToCell(pos)
	return math.floor(pos.X / BS) + 1, math.floor(pos.Y / BS) + 1
end

function World.surfaceY(x)
	x = math.clamp(x, 1, W)
	for y = H, 1, -1 do
		local name = World.get(x, y)
		if name and not Config.Blocks[name].passable then
			return y
		end
	end
	return 1
end

local function opaque(x, y)
	local name = World.get(x, y)
	if not name then
		return false
	end
	return not Config.Blocks[name].passable
end

local function exposed(x, y)
	return not (opaque(x - 1, y) and opaque(x + 1, y) and opaque(x, y - 1) and opaque(x, y + 1))
end

local function key(x, y)
	return x * 1000 + y
end

local function makePart(x, y, name)
	local def = Config.Blocks[name]
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = def.color
	p.Material = def.material
	if def.torch then
		p.Size = Vector3.new(0.8, 2.4, 0.8)
		p.CanCollide = false
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 190, 90)
		light.Parent = p
	else
		p.Size = Vector3.new(BS, BS, BS)
		p.CanCollide = not def.passable
	end
	p.Position = World.cellToPos(x, y)
	p:SetAttribute("X", x)
	p:SetAttribute("Y", y)
	p.Parent = folder
	return p
end

local function refresh(x, y)
	if not World.inBounds(x, y) then
		return
	end
	local k = key(x, y)
	local name = World.get(x, y)
	local existing = parts[k]
	if existing and (not name or existing.Name ~= name or not exposed(x, y)) then
		existing:Destroy()
		parts[k] = nil
		existing = nil
	end
	if name and not existing and exposed(x, y) then
		parts[k] = makePart(x, y, name)
	end
end

function World.set(x, y, name)
	if not World.inBounds(x, y) then
		return
	end
	grid[x][y] = name
	refresh(x, y)
	refresh(x - 1, y)
	refresh(x + 1, y)
	refresh(x, y - 1)
	refresh(x, y + 1)
end

local function generateTree(x, h, rng)
	local trunk = rng:NextInteger(4, 6)
	for i = 1, trunk do
		grid[x][h + i] = "Wood"
	end
	local top = h + trunk
	for dx = -2, 2 do
		for dy = -1, 2 do
			if not (math.abs(dx) == 2 and dy == 2) and x + dx >= 1 and x + dx <= W and not grid[x + dx][top + dy] then
				grid[x + dx][top + dy] = "Leaves"
			end
		end
	end
end

function World.generate()
	local rng = Random.new()
	local seed = rng:NextInteger(1, 100000) * 0.01

	local heights = {}
	for x = 1, W do
		grid[x] = {}
		local h = Config.SurfaceBase + math.floor(math.noise(x * 0.04, seed) * 12 + math.noise(x * 0.13, seed + 7) * 3)
		heights[x] = h
		for y = 1, h do
			local name
			local depth = h - y
			if y == 1 then
				name = "Bedrock"
			elseif depth == 0 then
				name = "Grass"
			elseif depth <= 3 then
				name = "Dirt"
			else
				name = "Stone"
				if depth > 5 and y > 3 and math.noise(x * 0.09, y * 0.09, seed) > 0.2 then
					name = nil
				elseif depth > 6 and rng:NextNumber() < 0.035 then
					name = "CoalOre"
				elseif depth > 22 and rng:NextNumber() < 0.025 then
					name = "IronOre"
				elseif depth > 38 and rng:NextNumber() < 0.015 then
					name = "GoldOre"
				end
			end
			grid[x][y] = name
		end
	end

	local lastTree = -10
	for x = 6, W - 6 do
		if x - lastTree > 6 and rng:NextNumber() < 0.15 then
			generateTree(x, heights[x], rng)
			lastTree = x
		end
	end

	local count = 0
	for x = 1, W do
		for y = 1, H do
			if grid[x][y] then
				refresh(x, y)
				count += 1
				if count % 600 == 0 then
					task.wait()
				end
			end
		end
	end

	-- Задняя стена, чтобы пещеры не просвечивали небом.
	local back = Instance.new("Part")
	back.Name = "BackWall"
	back.Anchored = true
	back.CanCollide = false
	back.Color = Color3.fromRGB(45, 35, 30)
	back.Material = Enum.Material.Slate
	local wallH = (Config.SurfaceBase - 2) * BS
	back.Size = Vector3.new(W * BS, wallH, 4)
	back.Position = Vector3.new(W * BS / 2, wallH / 2, -4)
	back.Parent = workspace

	-- Невидимые стены по краям мира и в плоскости Z.
	for _, px in { -2, W * BS + 2 } do
		local wall = Instance.new("Part")
		wall.Name = "EdgeWall"
		wall.Anchored = true
		wall.Transparency = 1
		wall.Size = Vector3.new(4, H * BS * 2, 40)
		wall.Position = Vector3.new(px, H * BS, 0)
		wall.Parent = workspace
	end

	World.ready = true
end

return World
