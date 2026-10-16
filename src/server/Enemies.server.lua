-- Слизни: появляются ночью, охотятся на игроков, днём исчезают.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local World = require(script.Parent.World)
local BS = Config.BlockSize

local folder = workspace:WaitForChild("Enemies")
while not World.ready do
	task.wait(0.5)
end

local MAX_PER_PLAYER = 5
local lastHit = {}

local function spawnSlime(position)
	local m = Instance.new("Model")
	m.Name = "Slime"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(4, 3, 3)
	root.Color = Color3.fromRGB(70, 200, 90)
	root.Material = Enum.Material.SmoothPlastic
	root.Transparency = 0.2
	root.Position = position
	root.Parent = m

	for _, ex in { -0.8, 0.8 } do
		local eye = Instance.new("Part")
		eye.Size = Vector3.new(0.6, 0.6, 0.3)
		eye.Color = Color3.new(0, 0, 0)
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = root.CFrame * CFrame.new(ex, 0.4, 1.6)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = eye
		weld.Parent = eye
		eye.Parent = m
	end

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 50
	hum.Health = 50
	hum.WalkSpeed = 9
	hum.UseJumpPower = true
	hum.JumpPower = 48
	hum.HipHeight = 0.5
	hum.AutoRotate = false
	hum.Parent = m

	m.PrimaryPart = root
	m.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	hum.Died:Connect(function()
		lastHit[m] = nil
		task.delay(1, function()
			m:Destroy()
		end)
	end)
end

local function nearestPlayerRoot(pos)
	local best, bestDist = nil, math.huge
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = hrp, d
			end
		end
	end
	return best, bestDist
end

-- Спавн
task.spawn(function()
	while true do
		task.wait(3)
		if Config.isNight(Lighting.ClockTime) then
			local limit = MAX_PER_PLAYER * #Players:GetPlayers()
			if #folder:GetChildren() < limit then
				local list = Players:GetPlayers()
				local p = list[math.random(1, #list)]
				local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local side = math.random() < 0.5 and -1 or 1
					local cx = World.posToCell(hrp.Position + Vector3.new(side * math.random(30, 60), 0, 0))
					if cx > 2 and cx < Config.Width - 1 then
						local sy = World.surfaceY(cx)
						spawnSlime(Vector3.new((cx - 0.5) * BS, (sy + 2) * BS, 0))
					end
				end
			end
		end
	end
end)

-- ИИ
task.spawn(function()
	while true do
		task.wait(0.25)
		local night = Config.isNight(Lighting.ClockTime)
		for _, m in folder:GetChildren() do
			local hum = m:FindFirstChildOfClass("Humanoid")
			local root = m.PrimaryPart
			if hum and root and hum.Health > 0 then
				local pos = root.Position
				if math.abs(pos.Z) > 0.1 then
					root.CFrame = CFrame.new(pos.X, pos.Y, 0)
				end
				if pos.Y < -50 or (not night and math.random() < 0.08) then
					hum.Health = 0
				else
					local target, dist = nearestPlayerRoot(pos)
					if target and dist < 70 then
						hum:MoveTo(Vector3.new(target.Position.X, pos.Y, 0))
						if math.abs(root.AssemblyLinearVelocity.X) < 1.5 and hum.FloorMaterial ~= Enum.Material.Air then
							hum.Jump = true
						end
						if dist < 4.5 and os.clock() - (lastHit[m] or 0) > 1 then
							lastHit[m] = os.clock()
							local ph = target.Parent:FindFirstChildOfClass("Humanoid")
							if ph then
								ph:TakeDamage(10)
								target.AssemblyLinearVelocity = Vector3.new(math.sign(target.Position.X - pos.X) * 35, 40, 0)
							end
						end
					end
				end
			end
		end
	end
end)
