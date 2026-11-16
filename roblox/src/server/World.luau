local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("CODAG").Data.Catalog)

local LOOK = {
	earth = { ground = Color3.fromRGB(111, 143, 98), sky = Color3.fromRGB(158, 182, 201), clock = 14 },
	moon = { ground = Color3.fromRGB(194, 187, 178), sky = Color3.fromRGB(28, 26, 23), clock = 0 },
	mercury = { ground = Color3.fromRGB(177, 151, 122), sky = Color3.fromRGB(58, 42, 34), clock = 0 },
	venus = { ground = Color3.fromRGB(198, 161, 90), sky = Color3.fromRGB(196, 138, 58), clock = 12 },
	mars = { ground = Color3.fromRGB(181, 101, 69), sky = Color3.fromRGB(196, 122, 85), clock = 10 },
	jupiter = { ground = Color3.fromRGB(201, 176, 137), sky = Color3.fromRGB(138, 106, 69), clock = 9 },
	saturn = { ground = Color3.fromRGB(210, 192, 147), sky = Color3.fromRGB(194, 163, 106), clock = 9 },
	uranus = { ground = Color3.fromRGB(127, 154, 168), sky = Color3.fromRGB(110, 143, 152), clock = 6 },
	neptune = { ground = Color3.fromRGB(63, 111, 152), sky = Color3.fromRGB(29, 53, 80), clock = 2 },
}

local function hexColor(value: string): Color3
	local r = tonumber(string.sub(value, 2, 3), 16) or 200
	local g = tonumber(string.sub(value, 4, 5), 16) or 200
	local b = tonumber(string.sub(value, 6, 7), 16) or 200
	return Color3.fromRGB(r, g, b)
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Anchored = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function label(adornee: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(180, 48)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = adornee
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(244, 239, 230)
	title.TextStrokeTransparency = 0.4
	title.TextScaled = true
	title.Text = text
	title.Parent = billboard
end

local function prompt(adornee: BasePart, action: string, objectText: string): ProximityPrompt
	local use = Instance.new("ProximityPrompt")
	use.ActionText = action
	use.ObjectText = objectText
	use.HoldDuration = 0
	use.MaxActivationDistance = 12
	use.RequiresLineOfSight = false
	use.Parent = adornee
	return use
end

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "CODAGWorld"
	folder.Parent = workspace

	local earth = Instance.new("Folder")
	earth.Name = "Earth"
	earth.Parent = folder

	part(earth, "Ground", Vector3.new(240, 2, 240), CFrame.new(0, -1, 0), LOOK.earth.ground)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "EarthSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 1, 18)
	spawn.Color = Color3.fromRGB(224, 160, 69)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = earth
	label(spawn, "Earth")

	local shed = part(earth, "Shed", Vector3.new(14, 8, 10), CFrame.new(0, 4, -30), Color3.fromRGB(90, 62, 40))
	label(shed, "Workshop yard")

	local caches = {}
	for _, material in Catalog.MATERIALS do
		local x = material.position[1] * 8
		local z = material.position[3] * 8
		local pile = part(earth, material.id, Vector3.new(4, 3, 4), CFrame.new(x, 2.5, z), hexColor(material.color))
		pile:SetAttribute("MaterialId", material.id)
		label(pile, material.name)
		local use = prompt(pile, "Pick up", material.name)
		caches[material.id] = { part = pile, prompt = use }
	end

	local padsFolder = Instance.new("Folder")
	padsFolder.Name = "Pads"
	padsFolder.Parent = earth
	local slotNames = { "shell", "wrap", "air" }
	local slotTitles = { shell = "Shell", wrap = "Wrap", air = "Air" }
	local pads = {}
	for index, slot in slotNames do
		local pad = part(padsFolder, slot, Vector3.new(8, 1, 8), CFrame.new(-28 + (index - 1) * 12, 1, -18), Color3.fromRGB(34, 28, 22))
		pad:SetAttribute("Slot", slot)
		label(pad, slotTitles[slot])
		pads[slot] = pad
	end

	local bench = part(earth, "Bench", Vector3.new(28, 1, 8), CFrame.new(-16, 1, -8), Color3.fromRGB(58, 49, 40))
	local buildPrompt = prompt(bench, "Build", "Suit")
	label(bench, "Drag materials onto the pads")

	local destinations = Instance.new("Folder")
	destinations.Name = "Destinations"
	destinations.Parent = folder
	local planetPads = {}
	for index, planet in Catalog.PLANETS do
		if planet.id ~= "earth" then
			local look = LOOK[planet.id] or LOOK.moon
			local pad = part(
				destinations,
				planet.id,
				Vector3.new(80, 2, 80),
				CFrame.new((index - 1) * 120, -1, -280),
				look.ground
			)
			pad:SetAttribute("PlanetId", planet.id)
			label(pad, planet.name)
			planetPads[planet.id] = pad
		end
	end

	return {
		look = LOOK,
		spawn = spawn,
		caches = caches,
		pads = pads,
		bench = bench,
		buildPrompt = buildPrompt,
		planetPads = planetPads,
		hexColor = hexColor,
	}
end

return {
	build = build,
}
