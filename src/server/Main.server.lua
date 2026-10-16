local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local World = require(script.Parent.World)
local BS = Config.BlockSize

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, n in { "Mine", "Place", "Craft", "Attack", "State" } do
	local r = Instance.new("RemoteEvent")
	r.Name = n
	r.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local enemies = Instance.new("Folder")
enemies.Name = "Enemies"
enemies.Parent = workspace

World.generate()

Lighting.ClockTime = 8
RunService.Heartbeat:Connect(function(dt)
	Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / Config.DayLength) % 24
end)

local states = {}

local function sendState(player)
	local s = states[player]
	if s then
		remotes.State:FireClient(player, { inv = s.inv, pick = s.pick, sword = s.sword })
	end
end

local function hrpOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function validCell(x, y)
	return typeof(x) == "number" and typeof(y) == "number" and x == x and y == y and World.inBounds(math.floor(x), math.floor(y))
end

local function inRange(player, x, y)
	local hrp = hrpOf(player)
	return hrp ~= nil and (hrp.Position - World.cellToPos(x, y)).Magnitude <= Config.Reach * BS
end

local function spawnCharacter(char)
	local hrp = char:WaitForChild("HumanoidRootPart")
	local x = math.floor(Config.Width / 2) + math.random(-8, 8)
	local y = World.surfaceY(x)
	char:PivotTo(CFrame.new((x - 0.5) * BS, (y + 3) * BS, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
end

local function setupPlayer(player)
	if states[player] then
		return
	end
	states[player] = { inv = {}, pick = 0, sword = 0, mineKey = nil, progress = 0, lastMine = 0, lastAttack = 0 }
	player.CharacterAdded:Connect(spawnCharacter)
	if player.Character then
		task.spawn(spawnCharacter, player.Character)
	end
	sendState(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(p)
	states[p] = nil
end)
for _, p in Players:GetPlayers() do
	setupPlayer(p)
end

remotes.Mine.OnServerEvent:Connect(function(player, x, y)
	local s = states[player]
	if not s or not validCell(x, y) then
		return
	end
	x, y = math.floor(x), math.floor(y)
	if not inRange(player, x, y) then
		return
	end
	local name = World.get(x, y)
	local def = name and Config.Blocks[name]
	if not def or def.unbreakable or def.tier > s.pick then
		return
	end

	local now = os.clock()
	local k = x * 1000 + y
	local dt = math.clamp(now - s.lastMine, 0, 0.25)
	s.lastMine = now
	if s.mineKey ~= k then
		s.mineKey = k
		s.progress = 0
		dt = 0.1
	end
	s.progress += dt * Config.PickSpeed[s.pick]

	if s.progress >= def.hardness then
		s.mineKey = nil
		s.progress = 0
		World.set(x, y, nil)
		local drop = def.drop
		if drop == nil then
			drop = name
		end
		if drop then
			s.inv[drop] = (s.inv[drop] or 0) + 1
			sendState(player)
		end
	end
end)

remotes.Place.OnServerEvent:Connect(function(player, x, y, item)
	local s = states[player]
	if not s or not validCell(x, y) or typeof(item) ~= "string" then
		return
	end
	x, y = math.floor(x), math.floor(y)
	local itemDef = Config.ItemByName[item]
	local blockName = itemDef and itemDef.place
	if not blockName or (s.inv[item] or 0) < 1 or y < 2 then
		return
	end
	if World.get(x, y) or not inRange(player, x, y) then
		return
	end
	if not (World.get(x - 1, y) or World.get(x + 1, y) or World.get(x, y - 1) or World.get(x, y + 1)) then
		return
	end
	if not Config.Blocks[blockName].passable then
		local c = World.cellToPos(x, y)
		for _, other in Players:GetPlayers() do
			local hrp = hrpOf(other)
			if hrp and math.abs(hrp.Position.X - c.X) < BS / 2 + 1.5 and math.abs(hrp.Position.Y - c.Y) < BS / 2 + 3 then
				return
			end
		end
	end
	s.inv[item] -= 1
	World.set(x, y, blockName)
	sendState(player)
end)

remotes.Craft.OnServerEvent:Connect(function(player, index)
	local s = states[player]
	local recipe = typeof(index) == "number" and Config.Recipes[index]
	if not s or not recipe then
		return
	end
	if recipe.pick and s.pick >= recipe.pick then
		return
	end
	if recipe.sword and s.sword >= recipe.sword then
		return
	end
	for item, n in recipe.cost do
		if (s.inv[item] or 0) < n then
			return
		end
	end
	for item, n in recipe.cost do
		s.inv[item] -= n
	end
	for item, n in recipe.give or {} do
		s.inv[item] = (s.inv[item] or 0) + n
	end
	s.pick = recipe.pick or s.pick
	s.sword = recipe.sword or s.sword
	sendState(player)
end)

remotes.Attack.OnServerEvent:Connect(function(player, model)
	local s = states[player]
	if not s or typeof(model) ~= "Instance" or not model:IsDescendantOf(enemies) then
		return
	end
	local now = os.clock()
	if now - s.lastAttack < 0.4 then
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local hrp = hrpOf(player)
	local root = model.PrimaryPart
	if not hum or not hrp or not root or hum.Health <= 0 then
		return
	end
	if (hrp.Position - root.Position).Magnitude > 14 then
		return
	end
	s.lastAttack = now
	hum:TakeDamage(Config.SwordDamage[s.sword])
	local dir = Vector3.new(math.sign(root.Position.X - hrp.Position.X), 0.6, 0)
	root.AssemblyLinearVelocity = dir * 40
end)
