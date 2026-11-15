local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Catalog = require(ReplicatedStorage:WaitForChild("CODAG").Data.Catalog)

-- ── Palette ──────────────────────────────────────────────────────────────

local LOOK = {
	earth   = { ground = Color3.fromRGB(111, 143,  98), sky = Color3.fromRGB(158, 182, 201), clock = 14 },
	moon    = { ground = Color3.fromRGB(194, 187, 178), sky = Color3.fromRGB( 28,  26,  23), clock =  0 },
	mercury = { ground = Color3.fromRGB(177, 151, 122), sky = Color3.fromRGB( 58,  42,  34), clock =  0 },
	venus   = { ground = Color3.fromRGB(198, 161,  90), sky = Color3.fromRGB(196, 138,  58), clock = 12 },
	mars    = { ground = Color3.fromRGB(181, 101,  69), sky = Color3.fromRGB(196, 122,  85), clock = 10 },
	jupiter = { ground = Color3.fromRGB(201, 176, 137), sky = Color3.fromRGB(138, 106,  69), clock =  9 },
	saturn  = { ground = Color3.fromRGB(210, 192, 147), sky = Color3.fromRGB(194, 163, 106), clock =  9 },
	uranus  = { ground = Color3.fromRGB(127, 154, 168), sky = Color3.fromRGB(110, 143, 152), clock =  6 },
	neptune = { ground = Color3.fromRGB( 63, 111, 152), sky = Color3.fromRGB( 29,  53,  80), clock =  2 },
}

-- Per-planet Atmosphere config (Roblox Atmosphere instance properties)
local ATMO = {
	earth   = { density = 0.35, offset = 0.25, haze = 1.8, glare = 0.6,  color = Color3.fromRGB(170, 196, 220), decay = Color3.fromRGB(105, 135, 180) },
	moon    = { density = 0,    offset = 0,    haze = 0,   glare = 0,    color = Color3.fromRGB(0, 0, 0),       decay = Color3.fromRGB(0, 0, 0) },
	mercury = { density = 0,    offset = 0,    haze = 0,   glare = 0.1,  color = Color3.fromRGB(20, 15, 10),    decay = Color3.fromRGB(10, 8, 5) },
	venus   = { density = 0.8,  offset = 0.6,  haze = 2.5, glare = 1.0,  color = Color3.fromRGB(210, 170, 80), decay = Color3.fromRGB(180, 130, 50) },
	mars    = { density = 0.15, offset = 0.1,  haze = 2.2, glare = 0.4,  color = Color3.fromRGB(200, 140, 100),decay = Color3.fromRGB(160, 100, 70) },
	jupiter = { density = 0.7,  offset = 0.5,  haze = 2.8, glare = 0.5,  color = Color3.fromRGB(180, 150, 100),decay = Color3.fromRGB(140, 110, 70) },
	saturn  = { density = 0.5,  offset = 0.4,  haze = 2.4, glare = 0.4,  color = Color3.fromRGB(200, 180, 130),decay = Color3.fromRGB(160, 140, 90) },
	uranus  = { density = 0.6,  offset = 0.5,  haze = 3.0, glare = 0.3,  color = Color3.fromRGB(130, 170, 190),decay = Color3.fromRGB(80, 120, 150) },
	neptune = { density = 0.65, offset = 0.5,  haze = 3.2, glare = 0.2,  color = Color3.fromRGB(50, 90, 140),  decay = Color3.fromRGB(20, 50, 100) },
}

-- Particle configs per planet (nil = no particles)
local PARTICLES = {
	mars    = { color = Color3.fromRGB(181, 101, 69), rate = 40,  speed = 8,  lifetime = 4, size = 0.3, spread = 30, name = "Dust" },
	venus   = { color = Color3.fromRGB(220, 180, 80), rate = 25,  speed = 3,  lifetime = 6, size = 1.5, spread = 60, name = "Haze" },
	jupiter = { color = Color3.fromRGB(180, 150, 100),rate = 20,  speed = 12, lifetime = 3, size = 0.5, spread = 40, name = "Wind" },
	saturn  = { color = Color3.fromRGB(210, 192, 147),rate = 15,  speed = 10, lifetime = 3, size = 0.4, spread = 35, name = "Wind" },
	uranus  = { color = Color3.fromRGB(180, 210, 230),rate = 30,  speed = 5,  lifetime = 5, size = 0.6, spread = 50, name = "Ice" },
	neptune = { color = Color3.fromRGB(100, 150, 200),rate = 35,  speed = 14, lifetime = 3, size = 0.4, spread = 45, name = "Storm" },
}

-- Roblox material enums per planet ground
local GROUND_MATERIAL = {
	earth   = Enum.Material.Grass,
	moon    = Enum.Material.Slate,
	mercury = Enum.Material.Slate,
	venus   = Enum.Material.CrackedLava,
	mars    = Enum.Material.Sand,
	jupiter = Enum.Material.Sandstone,
	saturn  = Enum.Material.Sandstone,
	uranus  = Enum.Material.Glacier,
	neptune = Enum.Material.Glacier,
}

-- ── Helpers ──────────────────────────────────────────────────────────────

local function hexColor(value: string): Color3
	local r = tonumber(string.sub(value, 2, 3), 16) or 200
	local g = tonumber(string.sub(value, 4, 5), 16) or 200
	local b = tonumber(string.sub(value, 6, 7), 16) or 200
	return Color3.fromRGB(r, g, b)
end

-- Seeded RNG so planet terrain is deterministic
local function mulberry32(seed: number): () -> number
	local s = seed
	return function(): number
		s = (s + 1831565813) % 2^32
		local t = bit32.bxor(s, bit32.rshift(s, 15))
		t = (t * (bit32.bor(t, 1))) % 2^32
		t = bit32.bxor(t, t + bit32.bxor(t, bit32.rshift(t, 7)) * (bit32.bor(t, 61)) % 2^32)
		return (bit32.bxor(t, bit32.rshift(t, 14)) % 2^32) / 2^32
	end
end

local function darken(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

local function lighten(color: Color3, factor: number): Color3
	return Color3.new(
		math.min(1, color.R + (1 - color.R) * factor),
		math.min(1, color.G + (1 - color.G) * factor),
		math.min(1, color.B + (1 - color.B) * factor)
	)
end

-- ── Part factory ─────────────────────────────────────────────────────────

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function wedge(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local piece = Instance.new("WedgePart")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function ball(parent: Instance, name: string, diameter: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = Enum.PartType.Ball
	piece.Size = Vector3.new(diameter, diameter, diameter)
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function label(adornee: BasePart, text: string, color: Color3?)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 52)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = adornee

	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(20, 17, 14)
	bg.BackgroundTransparency = 0.3
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = bg
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = bg

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = color or Color3.fromRGB(244, 239, 230)
	title.TextStrokeTransparency = 0.5
	title.TextScaled = true
	title.Text = text
	title.Parent = bg
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

-- ── Terrain scatter ──────────────────────────────────────────────────────

local function scatterRocks(parent: Instance, count: number, radius: number, center: Vector3, color: Color3, material: Enum.Material, seed: number)
	local rng = mulberry32(seed)
	local folder = Instance.new("Folder")
	folder.Name = "Rocks"
	folder.Parent = parent
	for i = 1, count do
		local angle = rng() * math.pi * 2
		local dist = 8 + rng() * (radius - 10)
		local x = center.X + math.cos(angle) * dist
		local z = center.Z + math.sin(angle) * dist
		local scale = 1 + rng() * 4
		local shade = 0.7 + rng() * 0.3
		local rockColor = darken(color, shade)
		local rock = ball(folder, "Rock" .. i, scale, CFrame.new(x, center.Y + scale * 0.35, z), rockColor, material)
		rock.CastShadow = true
	end
end

local function scatterCraters(parent: Instance, count: number, radius: number, center: Vector3, color: Color3, material: Enum.Material, seed: number)
	local rng = mulberry32(seed + 999)
	local folder = Instance.new("Folder")
	folder.Name = "Craters"
	folder.Parent = parent
	for i = 1, count do
		local angle = rng() * math.pi * 2
		local dist = 12 + rng() * (radius - 16)
		local x = center.X + math.cos(angle) * dist
		local z = center.Z + math.sin(angle) * dist
		local rimDiameter = 6 + rng() * 12
		local rimHeight = 0.8 + rng() * 1.5
		-- Crater rim (torus approximated by 8 segments)
		for seg = 0, 7 do
			local a = (seg / 8) * math.pi * 2
			local rx = x + math.cos(a) * rimDiameter * 0.5
			local rz = z + math.sin(a) * rimDiameter * 0.5
			local segSize = Vector3.new(rimDiameter * 0.22, rimHeight, rimDiameter * 0.22)
			local shade = 0.75 + rng() * 0.2
			part(folder, "Rim" .. i .. "_" .. seg, segSize,
				CFrame.new(rx, center.Y + rimHeight * 0.5, rz),
				darken(color, shade), material)
		end
		-- Crater floor (slightly darker, sunken)
		local floor = Instance.new("Part")
		floor.Name = "Floor" .. i
		floor.Shape = Enum.PartType.Cylinder
		floor.Size = Vector3.new(0.4, rimDiameter * 0.8, rimDiameter * 0.8)
		floor.CFrame = CFrame.new(x, center.Y + 0.2, z) * CFrame.Angles(0, 0, math.rad(90))
		floor.Color = darken(color, 0.6)
		floor.Material = material
		floor.Anchored = true
		floor.Parent = folder
	end
end

local function scatterHills(parent: Instance, count: number, radius: number, center: Vector3, color: Color3, material: Enum.Material, seed: number)
	local rng = mulberry32(seed + 5555)
	local folder = Instance.new("Folder")
	folder.Name = "Hills"
	folder.Parent = parent
	for i = 1, count do
		local angle = rng() * math.pi * 2
		local dist = 20 + rng() * (radius - 25)
		local x = center.X + math.cos(angle) * dist
		local z = center.Z + math.sin(angle) * dist
		local w = 8 + rng() * 16
		local h = 3 + rng() * 8
		local shade = 0.8 + rng() * 0.2
		wedge(folder, "Hill" .. i, Vector3.new(w, h, w * 1.2),
			CFrame.new(x, center.Y + h * 0.5, z) * CFrame.Angles(0, rng() * math.pi * 2, 0),
			darken(color, shade), material)
	end
end

-- ── Lighting post-effects ────────────────────────────────────────────────

local function setupLighting()
	-- Atmosphere instance (we update properties per planet)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo == nil then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end

	-- Bloom for that indie glow
	local bloom = Lighting:FindFirstChild("CODAGBloom")
	if bloom == nil then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "CODAGBloom"
		bloom.Intensity = 0.4
		bloom.Size = 28
		bloom.Threshold = 0.9
		bloom.Parent = Lighting
	end

	-- Color correction for warmth and contrast
	local cc = Lighting:FindFirstChild("CODAGColor")
	if cc == nil then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CODAGColor"
		cc.Brightness = 0.02
		cc.Contrast = 0.12
		cc.Saturation = 0.08
		cc.TintColor = Color3.fromRGB(255, 248, 240)
		cc.Parent = Lighting
	end

	-- Sun rays
	local rays = Lighting:FindFirstChild("CODAGSunRays")
	if rays == nil then
		rays = Instance.new("SunRaysEffect")
		rays.Name = "CODAGSunRays"
		rays.Intensity = 0.08
		rays.Spread = 0.6
		rays.Parent = Lighting
	end

	return atmo
end

-- ── Particles on planet pad ──────────────────────────────────────────────

local function addParticles(pad: BasePart, config)
	if config == nil then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = config.name
	emitter.Color = ColorSequence.new(config.color)
	emitter.Rate = config.rate
	emitter.Speed = NumberRange.new(config.speed * 0.5, config.speed)
	emitter.Lifetime = NumberRange.new(config.lifetime * 0.6, config.lifetime)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, config.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.SpreadAngle = Vector2.new(config.spread, config.spread)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Parent = pad
end

-- ── Build ────────────────────────────────────────────────────────────────

local function build()
	local atmoInstance = setupLighting()

	local folder = Instance.new("Folder")
	folder.Name = "CODAGWorld"
	folder.Parent = workspace

	-- ── Earth zone ───────────────────────────────────────────────────────

	local earth = Instance.new("Folder")
	earth.Name = "Earth"
	earth.Parent = folder

	-- Ground with real grass material
	local ground = part(earth, "Ground", Vector3.new(240, 2, 240), CFrame.new(0, -1, 0),
		LOOK.earth.ground, Enum.Material.Grass)
	ground.CastShadow = false

	-- Spawn pad
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "EarthSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 1, 18)
	spawn.Color = Color3.fromRGB(224, 160, 69)
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = earth
	label(spawn, "Earth", Color3.fromRGB(224, 160, 69))

	-- Workshop shed (more detailed)
	local shedColor = Color3.fromRGB(90, 62, 40)
	local shed = part(earth, "ShedWalls", Vector3.new(14, 8, 10), CFrame.new(0, 4, -30),
		shedColor, Enum.Material.Wood)
	-- Roof
	wedge(earth, "ShedRoof", Vector3.new(14, 4, 6), CFrame.new(0, 9.5, -27),
		darken(shedColor, 0.6), Enum.Material.Wood)
	wedge(earth, "ShedRoofBack", Vector3.new(14, 4, 6), CFrame.new(0, 9.5, -33) * CFrame.Angles(0, math.rad(180), 0),
		darken(shedColor, 0.6), Enum.Material.Wood)
	-- Door
	part(earth, "ShedDoor", Vector3.new(3.5, 6, 0.3), CFrame.new(0, 3, -24.9),
		Color3.fromRGB(60, 42, 28), Enum.Material.WoodPlanks)
	label(shed, "Workshop", Color3.fromRGB(224, 160, 69))

	-- Scatter trees (simple trunk + foliage ball)
	local treeSeeds = mulberry32(42)
	for i = 1, 12 do
		local angle = treeSeeds() * math.pi * 2
		local dist = 30 + treeSeeds() * 60
		local tx = math.cos(angle) * dist
		local tz = math.sin(angle) * dist
		local trunkH = 4 + treeSeeds() * 5
		part(earth, "Trunk" .. i, Vector3.new(1, trunkH, 1),
			CFrame.new(tx, trunkH / 2, tz),
			Color3.fromRGB(80, 55, 35), Enum.Material.Wood)
		local foliageSize = 4 + treeSeeds() * 4
		ball(earth, "Foliage" .. i, foliageSize,
			CFrame.new(tx, trunkH + foliageSize * 0.3, tz),
			Color3.fromRGB(60 + math.floor(treeSeeds() * 40), 110 + math.floor(treeSeeds() * 40), 50),
			Enum.Material.Grass)
	end

	-- Scatter small rocks on earth too
	scatterRocks(earth, 15, 60, Vector3.new(0, 0, 0), Color3.fromRGB(140, 130, 120), Enum.Material.Slate, 101)

	-- A path from spawn to shed (flat lighter strip)
	for i = 0, 8 do
		part(earth, "Path" .. i, Vector3.new(4, 0.15, 4),
			CFrame.new(0, 0.1, 16 - i * 5.5),
			Color3.fromRGB(160, 145, 120), Enum.Material.Sand)
	end

	-- ── Material caches ──────────────────────────────────────────────────

	local caches = {}
	for _, material in Catalog.MATERIALS do
		local x = material.position[1] * 8
		local z = material.position[3] * 8
		-- Glowing base pad under each cache
		local basePad = part(earth, material.id .. "Pad", Vector3.new(5, 0.2, 5),
			CFrame.new(x, 0.1, z),
			hexColor(material.color), Enum.Material.Neon)
		basePad.Transparency = 0.6
		-- The cache itself
		local pile
		if material.structural then
			pile = part(earth, material.id, Vector3.new(4, 3, 4),
				CFrame.new(x, 2.5, z),
				hexColor(material.color), Enum.Material.DiamondPlate)
		elseif material.id == "oxygen" then
			pile = Instance.new("Part")
			pile.Name = material.id
			pile.Shape = Enum.PartType.Cylinder
			pile.Size = Vector3.new(4, 2.5, 2.5)
			pile.CFrame = CFrame.new(x, 2, z) * CFrame.Angles(0, 0, math.rad(90))
			pile.Color = hexColor(material.color)
			pile.Material = Enum.Material.Metal
			pile.Anchored = true
			pile.Parent = earth
		else
			pile = ball(earth, material.id, 4, CFrame.new(x, 2.5, z),
				hexColor(material.color), Enum.Material.Fabric)
		end
		if pile.Parent == nil then
			pile.Parent = earth
		end
		pile:SetAttribute("MaterialId", material.id)
		pile.CastShadow = true
		label(pile, material.name)
		local use = prompt(pile, "Pick up", material.name)
		caches[material.id] = { part = pile, prompt = use }
	end

	-- ── Build pads ───────────────────────────────────────────────────────

	local padsFolder = Instance.new("Folder")
	padsFolder.Name = "Pads"
	padsFolder.Parent = earth
	local slotNames = { "shell", "wrap", "air" }
	local slotTitles = { shell = "Shell", wrap = "Wrap", air = "Air" }
	local slotColors = {
		shell = Color3.fromRGB(60, 50, 40),
		wrap  = Color3.fromRGB(50, 55, 45),
		air   = Color3.fromRGB(45, 40, 55),
	}
	local pads = {}
	for index, slot in slotNames do
		local pad = part(padsFolder, slot, Vector3.new(8, 1, 8),
			CFrame.new(-28 + (index - 1) * 12, 1, -18),
			slotColors[slot], Enum.Material.Concrete)
		pad:SetAttribute("Slot", slot)
		-- Neon ring around the pad
		local ring = part(padsFolder, slot .. "Ring", Vector3.new(8.4, 0.15, 8.4),
			CFrame.new(-28 + (index - 1) * 12, 1.55, -18),
			Color3.fromRGB(224, 160, 69), Enum.Material.Neon)
		ring.Transparency = 0.4
		label(pad, slotTitles[slot], Color3.fromRGB(224, 160, 69))
		pads[slot] = pad
	end

	local bench = part(earth, "Bench", Vector3.new(28, 1, 8),
		CFrame.new(-16, 1, -8),
		Color3.fromRGB(58, 49, 40), Enum.Material.WoodPlanks)
	local buildPrompt = prompt(bench, "Build", "Suit")
	label(bench, "Drag materials onto the pads")

	-- ── Planet destinations ──────────────────────────────────────────────

	local destinations = Instance.new("Folder")
	destinations.Name = "Destinations"
	destinations.Parent = folder
	local planetPads = {}
	for index, planet in Catalog.PLANETS do
		if planet.id ~= "earth" then
			local look = LOOK[planet.id] or LOOK.moon
			local mat = GROUND_MATERIAL[planet.id] or Enum.Material.Slate
			local cx = (index - 1) * 140
			local cz = -300
			local center = Vector3.new(cx, 0, cz)

			-- Main ground slab
			local pad = part(destinations, planet.id,
				Vector3.new(100, 2, 100),
				CFrame.new(cx, -1, cz),
				look.ground, mat)
			pad:SetAttribute("PlanetId", planet.id)
			pad.CastShadow = false
			label(pad, planet.name)
			planetPads[planet.id] = pad

			-- Terrain features based on planet type
			local airless = planet.id == "moon" or planet.id == "mercury"
			local rocky = planet.id == "moon" or planet.id == "mercury" or planet.id == "mars" or planet.id == "venus"
			local gasIce = planet.id == "jupiter" or planet.id == "saturn" or planet.id == "uranus" or planet.id == "neptune"

			if airless then
				-- Craters and rocks for airless bodies
				scatterCraters(destinations, 5, 45, center, look.ground, mat, index * 137)
				scatterRocks(destinations, 25, 45, center, look.ground, mat, index * 211)
			elseif rocky then
				-- Rocks and hills for rocky planets with atmosphere
				scatterRocks(destinations, 20, 45, center, look.ground, mat, index * 173)
				scatterHills(destinations, 6, 45, center, look.ground, mat, index * 311)
			elseif gasIce then
				-- Swirling cloud-like formations (flat discs at various heights)
				local cloudRng = mulberry32(index * 419)
				for ci = 1, 8 do
					local ca = cloudRng() * math.pi * 2
					local cd = 10 + cloudRng() * 35
					local ch = 3 + cloudRng() * 15
					local cw = 8 + cloudRng() * 14
					local disc = Instance.new("Part")
					disc.Name = "Cloud" .. ci
					disc.Shape = Enum.PartType.Cylinder
					disc.Size = Vector3.new(1 + cloudRng() * 2, cw, cw)
					disc.CFrame = CFrame.new(cx + math.cos(ca) * cd, ch, cz + math.sin(ca) * cd) * CFrame.Angles(0, 0, math.rad(90))
					disc.Color = lighten(look.sky, 0.15 + cloudRng() * 0.2)
					disc.Material = Enum.Material.SmoothPlastic
					disc.Transparency = 0.4 + cloudRng() * 0.3
					disc.Anchored = true
					disc.CanCollide = false
					disc.CastShadow = false
					disc.Parent = destinations
				end
			end

			-- Particles
			addParticles(pad, PARTICLES[planet.id])
		end
	end

	return {
		look = LOOK,
		atmo = ATMO,
		atmoInstance = atmoInstance,
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
