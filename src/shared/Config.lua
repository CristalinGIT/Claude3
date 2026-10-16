-- Общие настройки игры: блоки, предметы, рецепты.
local Config = {}

Config.BlockSize = 4 -- студов на блок
Config.Width = 200 -- ширина мира в блоках
Config.Height = 90 -- высота мира в блоках
Config.SurfaceBase = 55 -- средняя высота поверхности
Config.Reach = 7 -- дальность добычи/строительства (в блоках)
Config.DayLength = 300 -- секунд на полные сутки

-- hardness: время добычи (сек) с голыми руками; tier: нужный уровень кирки
-- drop: что выпадает (nil -> сам блок, false -> ничего)
-- passable: можно проходить сквозь блок
Config.Blocks = {
	Grass = { color = Color3.fromRGB(86, 170, 70), material = Enum.Material.Grass, hardness = 0.6, tier = 0, drop = "Dirt" },
	Dirt = { color = Color3.fromRGB(121, 85, 58), material = Enum.Material.Ground, hardness = 0.6, tier = 0 },
	Stone = { color = Color3.fromRGB(125, 125, 130), material = Enum.Material.Slate, hardness = 2, tier = 1 },
	Wood = { color = Color3.fromRGB(110, 75, 40), material = Enum.Material.Wood, hardness = 1.2, tier = 0, passable = true },
	Leaves = { color = Color3.fromRGB(50, 130, 50), material = Enum.Material.Grass, hardness = 0.2, tier = 0, drop = false, passable = true },
	Planks = { color = Color3.fromRGB(190, 140, 80), material = Enum.Material.WoodPlanks, hardness = 1, tier = 0 },
	Torch = { color = Color3.fromRGB(255, 190, 60), material = Enum.Material.Neon, hardness = 0.1, tier = 0, passable = true, torch = true },
	CoalOre = { color = Color3.fromRGB(45, 45, 50), material = Enum.Material.Slate, hardness = 2, tier = 1, drop = "Coal" },
	IronOre = { color = Color3.fromRGB(200, 150, 120), material = Enum.Material.Slate, hardness = 3, tier = 1, drop = "Iron" },
	GoldOre = { color = Color3.fromRGB(240, 200, 40), material = Enum.Material.Slate, hardness = 4, tier = 2, drop = "Gold" },
	Bedrock = { color = Color3.fromRGB(25, 25, 28), material = Enum.Material.Slate, hardness = 1, tier = 99, unbreakable = true },
}

-- Предметы в инвентаре (порядок = порядок на панели). place = какой блок ставится.
Config.Items = {
	{ name = "Dirt", place = "Dirt" },
	{ name = "Stone", place = "Stone" },
	{ name = "Wood", place = "Wood" },
	{ name = "Planks", place = "Planks" },
	{ name = "Torch", place = "Torch" },
	{ name = "Coal" },
	{ name = "Iron" },
	{ name = "Gold" },
}

Config.PickSpeed = { [0] = 1, 2, 4 } -- множитель скорости добычи по уровню кирки
Config.SwordDamage = { [0] = 10, 20, 40 }

Config.Recipes = {
	{ name = "Доски x4", cost = { Wood = 1 }, give = { Planks = 4 } },
	{ name = "Факелы x4", cost = { Wood = 1, Coal = 1 }, give = { Torch = 4 } },
	{ name = "Деревянная кирка", cost = { Planks = 8 }, pick = 1 },
	{ name = "Железная кирка", cost = { Planks = 4, Iron = 10 }, pick = 2 },
	{ name = "Деревянный меч", cost = { Planks = 6 }, sword = 1 },
	{ name = "Железный меч", cost = { Planks = 2, Iron = 8 }, sword = 2 },
}

Config.ItemByName = {}
for _, item in Config.Items do
	Config.ItemByName[item.name] = item
end

function Config.isNight(clockTime)
	return clockTime >= 18.5 or clockTime < 5.5
end

return Config
