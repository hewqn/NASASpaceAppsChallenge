local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Catalog = require(ReplicatedStorage:WaitForChild("CODAG").Data.Catalog)

-- ── Palette ──────────────────────────────────────────────────────────────
-- Each planet: ground color, sky color, lighting clock time
-- Colors derived from NASA imagery and real surface observations

local LOOK = {
	earth   = { ground = Color3.fromRGB(111, 143,  98), sky = Color3.fromRGB(135, 175, 210), clock = 14 },
	moon    = { ground = Color3.fromRGB(160, 155, 148), sky = Color3.fromRGB(  4,   4,   8), clock = 14 },
	mercury = { ground = Color3.fromRGB(140, 130, 118), sky = Color3.fromRGB( 10,   8,   6), clock = 14 },
	venus   = { ground = Color3.fromRGB(180, 130,  60), sky = Color3.fromRGB(160, 110,  40), clock = 12 },
	mars    = { ground = Color3.fromRGB(170,  90,  55), sky = Color3.fromRGB(180, 120,  80), clock = 10 },
	jupiter = { ground = Color3.fromRGB(190, 165, 120), sky = Color3.fromRGB(140, 110,  65), clock =  9 },
	saturn  = { ground = Color3.fromRGB(200, 182, 135), sky = Color3.fromRGB(180, 155, 100), clock =  9 },
	uranus  = { ground = Color3.fromRGB(120, 148, 162), sky = Color3.fromRGB( 90, 130, 145), clock =  6 },
	neptune = { ground = Color3.fromRGB( 50, 100, 145), sky = Color3.fromRGB( 22,  45,  72), clock =  2 },
}

-- Per-planet Atmosphere config from NASA observations
-- density/offset/haze scaled to approximate real conditions
local ATMO = {
	earth   = { density = 0.35, offset = 0.25, haze = 1.8, glare = 0.6,  color = Color3.fromRGB(170, 196, 220), decay = Color3.fromRGB(105, 135, 180) },
	moon    = { density = 0,    offset = 0,    haze = 0,   glare = 0,    color = Color3.fromRGB(0, 0, 0),       decay = Color3.fromRGB(0, 0, 0) },
	mercury = { density = 0,    offset = 0,    haze = 0,   glare = 0.1,  color = Color3.fromRGB(20, 15, 10),    decay = Color3.fromRGB(10, 8, 5) },
	venus   = { density = 0.85, offset = 0.7,  haze = 2.8, glare = 1.0,  color = Color3.fromRGB(200, 155, 60), decay = Color3.fromRGB(170, 120, 40) },
	mars    = { density = 0.18, offset = 0.12, haze = 2.4, glare = 0.4,  color = Color3.fromRGB(190, 130, 90), decay = Color3.fromRGB(160, 100, 65) },
	jupiter = { density = 0.75, offset = 0.55, haze = 3.0, glare = 0.5,  color = Color3.fromRGB(175, 145, 95), decay = Color3.fromRGB(135, 105, 65) },
	saturn  = { density = 0.55, offset = 0.45, haze = 2.6, glare = 0.4,  color = Color3.fromRGB(195, 175, 125),decay = Color3.fromRGB(155, 135, 85) },
	uranus  = { density = 0.65, offset = 0.55, haze = 3.2, glare = 0.3,  color = Color3.fromRGB(125, 165, 185),decay = Color3.fromRGB(75, 115, 145) },
	neptune = { density = 0.70, offset = 0.55, haze = 3.4, glare = 0.2,  color = Color3.fromRGB(45, 85, 135),  decay = Color3.fromRGB(18, 45, 95) },
}

-- Particle configs per planet (nil = no particles)
local PARTICLES = {
	mars    = { color = Color3.fromRGB(181, 101, 69), rate = 50,  speed = 10, lifetime = 5, size = 0.4, spread = 40, name = "Dust" },
	venus   = { color = Color3.fromRGB(210, 160, 60), rate = 30,  speed = 4,  lifetime = 7, size = 2.0, spread = 70, name = "Haze" },
	jupiter = { color = Color3.fromRGB(175, 145, 95), rate = 25,  speed = 18, lifetime = 3, size = 0.6, spread = 50, name = "Wind" },
	saturn  = { color = Color3.fromRGB(200, 182, 135),rate = 20,  speed = 14, lifetime = 3, size = 0.5, spread = 40, name = "Wind" },
	uranus  = { color = Color3.fromRGB(175, 205, 225),rate = 35,  speed = 6,  lifetime = 6, size = 0.7, spread = 55, name = "Ice" },
	neptune = { color = Color3.fromRGB( 90, 140, 195),rate = 45,  speed = 20, lifetime = 3, size = 0.5, spread = 50, name = "Storm" },
}

-- Roblox Terrain material per planet surface
local TERRAIN_MATERIAL = {
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

-- Secondary terrain material for variation
local TERRAIN_ACCENT = {
	earth   = Enum.Material.Ground,
	moon    = Enum.Material.Rock,
	mercury = Enum.Material.Rock,
	venus   = Enum.Material.Rock,
	mars    = Enum.Material.Rock,
	jupiter = Enum.Material.Sand,
	saturn  = Enum.Material.Sand,
	uranus  = Enum.Material.Snow,
	neptune = Enum.Material.Ice,
}

-- ── Helpers ──────────────────────────────────────────────────────────────

local function hexColor(value: string): Color3
	local r = tonumber(string.sub(value, 2, 3), 16) or 200
	local g = tonumber(string.sub(value, 4, 5), 16) or 200
	local b = tonumber(string.sub(value, 6, 7), 16) or 200
	return Color3.fromRGB(r, g, b)
end

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

-- ── Terrain generation ──────────────────────────────────────────────────
-- Uses Roblox's voxel Terrain system for real-looking landscapes

local terrain = workspace.Terrain

local function generateTerrain(planetId: string, center: Vector3, radius: number, seed: number)
	local rng = mulberry32(seed)
	local mat = TERRAIN_MATERIAL[planetId] or Enum.Material.Slate
	local accent = TERRAIN_ACCENT[planetId] or Enum.Material.Rock
	local airless = planetId == "moon" or planetId == "mercury"
	local rocky = planetId == "mars" or planetId == "venus"
	local gasIce = planetId == "jupiter" or planetId == "saturn" or planetId == "uranus" or planetId == "neptune"

	-- Base terrain layer: flat ground with gentle noise
	local resolution = 4 -- studs per voxel
	local halfR = radius / 2

	-- Fill the base ground slab
	local baseRegion = Region3.new(
		center + Vector3.new(-radius, -20, -radius),
		center + Vector3.new(radius, 0, radius)
	):ExpandToGrid(resolution)
	terrain:FillRegion(baseRegion, resolution, mat)

	-- Add height variation with noise
	for x = -halfR, halfR, resolution * 2 do
		for z = -halfR, halfR, resolution * 2 do
			-- Layered noise for natural-looking terrain
			local nx = (x + center.X) * 0.008
			local nz = (z + center.Z) * 0.008
			local h1 = math.noise(nx, nz, seed) * 12
			local h2 = math.noise(nx * 3, nz * 3, seed + 100) * 4
			local h3 = math.noise(nx * 7, nz * 7, seed + 200) * 1.5
			local height = h1 + h2 + h3

			-- Planet-specific height scaling
			if airless then
				height = height * 2.5 -- more dramatic craters and ridges
			elseif gasIce then
				height = height * 0.5 -- flatter, more uniform
			elseif rocky then
				height = height * 1.8
			end

			if height > 1 then
				local useMat = if rng() > 0.7 then accent else mat
				local pos = center + Vector3.new(x, height / 2, z)
				local size = Vector3.new(resolution * 2, math.abs(height), resolution * 2)
				terrain:FillBlock(CFrame.new(pos), size, useMat)
			end
		end
	end

	-- Planet-specific features
	if airless then
		-- Craters: circular depressions with raised rims
		local craterCount = 8 + math.floor(rng() * 8)
		for i = 1, craterCount do
			local cx = center.X + (rng() - 0.5) * radius * 0.8
			local cz = center.Z + (rng() - 0.5) * radius * 0.8
			local craterRadius = 8 + rng() * 25
			local rimHeight = 3 + rng() * 6

			-- Rim ring
			local segments = 16
			for seg = 0, segments - 1 do
				local angle = (seg / segments) * math.pi * 2
				local rx = cx + math.cos(angle) * craterRadius
				local rz = cz + math.sin(angle) * craterRadius
				local rw = craterRadius * 0.25
				terrain:FillBlock(
					CFrame.new(rx, center.Y + rimHeight / 2, rz),
					Vector3.new(rw, rimHeight, rw),
					accent
				)
			end

			-- Hollow out the crater center
			terrain:FillBlock(
				CFrame.new(cx, center.Y - 2, cz),
				Vector3.new(craterRadius * 1.4, 8, craterRadius * 1.4),
				Enum.Material.Air
			)
		end

	elseif rocky then
		-- Boulder fields and ridges
		local boulderCount = 15 + math.floor(rng() * 15)
		for i = 1, boulderCount do
			local bx = center.X + (rng() - 0.5) * radius * 0.7
			local bz = center.Z + (rng() - 0.5) * radius * 0.7
			local bsize = 4 + rng() * 12
			terrain:FillBall(Vector3.new(bx, center.Y + bsize * 0.3, bz), bsize, accent)
		end

		-- Ridges
		local ridgeCount = 3 + math.floor(rng() * 3)
		for i = 1, ridgeCount do
			local rx = center.X + (rng() - 0.5) * radius * 0.5
			local rz = center.Z + (rng() - 0.5) * radius * 0.5
			local angle = rng() * math.pi
			local length = 30 + rng() * 60
			local height = 6 + rng() * 12
			for step = 0, length, 4 do
				local sx = rx + math.cos(angle) * step
				local sz = rz + math.sin(angle) * step
				local h = height * (1 - math.abs(step / length - 0.5) * 2)
				if h < 1 then continue end
				terrain:FillBlock(
					CFrame.new(sx, center.Y + h / 2, sz),
					Vector3.new(6, h, 6),
					mat
				)
			end
		end

	elseif gasIce then
		-- Layered cloud/ice formations at various heights
		local formCount = 10 + math.floor(rng() * 10)
		for i = 1, formCount do
			local fx = center.X + (rng() - 0.5) * radius * 0.6
			local fz = center.Z + (rng() - 0.5) * radius * 0.6
			local fy = 5 + rng() * 20
			local fsize = 10 + rng() * 20
			terrain:FillBall(Vector3.new(fx, center.Y + fy, fz), fsize, accent)
		end
	end

	-- Earth-specific: hills and gentle slopes
	if planetId == "earth" then
		local hillCount = 5 + math.floor(rng() * 5)
		for i = 1, hillCount do
			local hx = center.X + (rng() - 0.5) * radius * 0.6
			local hz = center.Z + (rng() - 0.5) * radius * 0.6
			local hsize = 15 + rng() * 30
			local hheight = 8 + rng() * 15
			terrain:FillBall(Vector3.new(hx, center.Y - hsize * 0.3, hz), hsize, Enum.Material.Grass)
		end
	end
end

-- ── Particles on planet surface ─────────────────────────────────────────

local function addParticles(parent: Instance, position: Vector3, config)
	if config == nil then return end
	-- Create an invisible anchored part as emitter source
	local emitterPart = Instance.new("Part")
	emitterPart.Name = config.name .. "Emitter"
	emitterPart.Size = Vector3.new(80, 1, 80)
	emitterPart.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Parent = parent

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
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.4, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.SpreadAngle = Vector2.new(config.spread, config.spread)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Parent = emitterPart
end

-- ── Lighting post-effects ────────────────────────────────────────────────

local function setupLighting()
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo == nil then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end

	local bloom = Lighting:FindFirstChild("CODAGBloom")
	if bloom == nil then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "CODAGBloom"
		bloom.Intensity = 0.35
		bloom.Size = 32
		bloom.Threshold = 0.88
		bloom.Parent = Lighting
	end

	local cc = Lighting:FindFirstChild("CODAGColor")
	if cc == nil then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "CODAGColor"
		cc.Brightness = 0.02
		cc.Contrast = 0.15
		cc.Saturation = 0.1
		cc.TintColor = Color3.fromRGB(255, 248, 240)
		cc.Parent = Lighting
	end

	local rays = Lighting:FindFirstChild("CODAGSunRays")
	if rays == nil then
		rays = Instance.new("SunRaysEffect")
		rays.Name = "CODAGSunRays"
		rays.Intensity = 0.06
		rays.Spread = 0.5
		rays.Parent = Lighting
	end

	-- Depth of field for cinematic feel
	local dof = Lighting:FindFirstChild("CODAGDOF")
	if dof == nil then
		dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "CODAGDOF"
		dof.FarIntensity = 0.15
		dof.FocusDistance = 50
		dof.InFocusRadius = 40
		dof.NearIntensity = 0
		dof.Parent = Lighting
	end

	return atmo
end

-- ── Obby generator ──────────────────────────────────────────────────────
-- Procedural obstacle course per planet, scaled by gravity.
-- Lower gravity = bigger gaps (you jump farther). Beacon at the end.

local EARTH_GRAVITY = 9.82

local function generateObby(parent: Instance, planetId: string, center: Vector3, gravityMs2: number, seed: number): Part
	local rng = mulberry32(seed)
	local look = LOOK[planetId] or LOOK.moon
	local gRatio = math.sqrt(EARTH_GRAVITY / gravityMs2) -- jump distance scale

	-- Platform sizing
	local platWidth = 6
	local platDepth = 6
	local platHeight = 1.2

	-- Color from planet ground, slightly varied
	local baseColor = look.ground
	local accentColor = lighten(baseColor, 0.15)

	local obbyFolder = Instance.new("Folder")
	obbyFolder.Name = planetId .. "Obby"
	obbyFolder.Parent = parent

	-- Start near landing pad, extend outward along +X
	local curX = center.X + 15
	local curY = 3
	local curZ = center.Z

	-- Number of platforms
	local count = 15 + math.floor(rng() * 6) -- 15-20

	for i = 1, count do
		-- Gap distance scaled by gravity ratio
		local baseGap = 8 + rng() * 6  -- 8-14 studs base gap
		local gap = baseGap * gRatio

		-- Height change: mostly up, sometimes level, rarely down
		local roll = rng()
		local dy
		if roll < 0.3 then
			dy = 0 -- level
		elseif roll < 0.7 then
			dy = 3 + rng() * 5 -- climb up
		elseif roll < 0.85 then
			dy = 8 + rng() * 6 -- big climb (pillar)
		else
			dy = -(2 + rng() * 3) -- drop down
		end
		dy = dy * gRatio * 0.5 -- scale height changes too

		curX = curX + gap
		curY = math.max(2, curY + dy)
		curZ = curZ + (rng() - 0.5) * 8 * gRatio -- slight lateral wobble

		-- Platform width variation
		local w = platWidth - rng() * 2  -- 4-6 wide
		local d = platDepth - rng() * 2

		-- Alternate colors for visual rhythm
		local col = if i % 3 == 0 then accentColor else baseColor
		local mat = if i % 5 == 0 then Enum.Material.Metal else Enum.Material.Slate

		local plat = part(obbyFolder, "Plat" .. i,
			Vector3.new(w, platHeight, d),
			CFrame.new(curX, curY, curZ),
			col, mat)
		plat.CastShadow = true

		-- Every few platforms, add a tall pillar underneath for visual weight
		if dy > 5 or i % 4 == 0 then
			local pillarH = curY
			if pillarH > 2 then
				part(obbyFolder, "Pillar" .. i,
					Vector3.new(2, pillarH, 2),
					CFrame.new(curX, pillarH / 2, curZ),
					darken(baseColor, 0.6), Enum.Material.Concrete)
			end
		end
	end

	-- Beacon at the end: glowing neon cylinder with a light beam
	local beaconY = curY + 3
	local beacon = Instance.new("Part")
	beacon.Name = planetId .. "Beacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(5, 3, 3)
	beacon.CFrame = CFrame.new(curX, beaconY, curZ) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Color = Color3.fromRGB(60, 255, 120)
	beacon.Material = Enum.Material.Neon
	beacon.Transparency = 0.15
	beacon.Anchored = true
	beacon.CanCollide = true
	beacon.CastShadow = false
	beacon:SetAttribute("PlanetId", planetId)
	beacon.Parent = obbyFolder

	-- Beacon light
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = Color3.fromRGB(60, 255, 120)
	beaconLight.Brightness = 3
	beaconLight.Range = 40
	beaconLight.Parent = beacon

	-- Upward light beam from beacon
	local beam = Instance.new("Part")
	beam.Name = "BeaconBeam"
	beam.Size = Vector3.new(0.5, 80, 0.5)
	beam.CFrame = CFrame.new(curX, beaconY + 40, curZ)
	beam.Color = Color3.fromRGB(60, 255, 120)
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.6
	beam.Anchored = true
	beam.CanCollide = false
	beam.CastShadow = false
	beam.Parent = obbyFolder

	-- Landing platform under the beacon (bigger, so you can land on it)
	part(obbyFolder, "BeaconPad",
		Vector3.new(10, platHeight, 10),
		CFrame.new(curX, curY, curZ),
		Color3.fromRGB(40, 180, 80), Enum.Material.Neon)

	return beacon
end

-- ── Build ────────────────────────────────────────────────────────────────

local function build()
	local atmoInstance = setupLighting()

	local folder = Instance.new("Folder")
	folder.Name = "CODAGWorld"
	folder.Parent = workspace

	-- ── Earth zone (hub) ─────────────────────────────────────────────────
	-- Generate real terrain instead of a flat plate

	local earth = Instance.new("Folder")
	earth.Name = "Earth"
	earth.Parent = folder

	local earthCenter = Vector3.new(0, 0, 0)
	local earthRadius = 200

	-- Generate terrain
	generateTerrain("earth", earthCenter, earthRadius, 42)

	-- Clear a flat area around spawn and workshop
	local clearRegion = Region3.new(
		Vector3.new(-50, -5, -50),
		Vector3.new(50, 15, 50)
	):ExpandToGrid(4)
	terrain:FillRegion(clearRegion, 4, Enum.Material.Air)
	-- Re-fill ground in cleared area
	local flatRegion = Region3.new(
		Vector3.new(-50, -4, -50),
		Vector3.new(50, 0, 50)
	):ExpandToGrid(4)
	terrain:FillRegion(flatRegion, 4, Enum.Material.Grass)

	-- Spawn pad
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "EarthSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 20)
	spawn.Color = Color3.fromRGB(224, 160, 69)
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = earth

	-- Workshop building (more substantial)
	local shedColor = Color3.fromRGB(75, 52, 35)
	local shedFloor = Color3.fromRGB(55, 40, 28)

	-- Floor
	part(earth, "ShedFloor", Vector3.new(18, 0.3, 14), CFrame.new(0, 0.15, -30),
		shedFloor, Enum.Material.WoodPlanks)

	-- Walls
	part(earth, "ShedWallBack", Vector3.new(18, 10, 0.6), CFrame.new(0, 5, -37),
		shedColor, Enum.Material.Wood)
	part(earth, "ShedWallLeft", Vector3.new(0.6, 10, 14), CFrame.new(-9, 5, -30),
		darken(shedColor, 0.85), Enum.Material.Wood)
	part(earth, "ShedWallRight", Vector3.new(0.6, 10, 14), CFrame.new(9, 5, -30),
		darken(shedColor, 0.85), Enum.Material.Wood)
	-- Front wall with door gap
	part(earth, "ShedWallFrontL", Vector3.new(6, 10, 0.6), CFrame.new(-6, 5, -23),
		shedColor, Enum.Material.Wood)
	part(earth, "ShedWallFrontR", Vector3.new(6, 10, 0.6), CFrame.new(6, 5, -23),
		shedColor, Enum.Material.Wood)
	part(earth, "ShedWallFrontTop", Vector3.new(6, 2, 0.6), CFrame.new(0, 9, -23),
		shedColor, Enum.Material.Wood)

	-- Roof
	wedge(earth, "ShedRoofL", Vector3.new(18, 5, 8),
		CFrame.new(0, 12, -26.5),
		darken(shedColor, 0.55), Enum.Material.Slate)
	wedge(earth, "ShedRoofR", Vector3.new(18, 5, 8),
		CFrame.new(0, 12, -33.5) * CFrame.Angles(0, math.rad(180), 0),
		darken(shedColor, 0.55), Enum.Material.Slate)

	-- Workbench inside
	part(earth, "Workbench", Vector3.new(12, 1.2, 3), CFrame.new(0, 3.6, -35),
		Color3.fromRGB(90, 65, 42), Enum.Material.WoodPlanks)

	-- Hanging light inside workshop
	local light = Instance.new("Part")
	light.Name = "ShopLight"
	light.Shape = Enum.PartType.Ball
	light.Size = Vector3.new(1.5, 1.5, 1.5)
	light.CFrame = CFrame.new(0, 9, -30)
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Material = Enum.Material.Neon
	light.Transparency = 0.1
	light.Anchored = true
	light.CanCollide = false
	light.Parent = earth
	local pointLight = Instance.new("PointLight")
	pointLight.Color = Color3.fromRGB(255, 230, 180)
	pointLight.Brightness = 1.5
	pointLight.Range = 30
	pointLight.Parent = light

	-- Trees (using terrain-style placement)
	local treeSeeds = mulberry32(42)
	for i = 1, 18 do
		local angle = treeSeeds() * math.pi * 2
		local dist = 40 + treeSeeds() * 100
		local tx = math.cos(angle) * dist
		local tz = math.sin(angle) * dist

		-- Skip if too close to workshop
		if math.abs(tx) > 20 or math.abs(tz + 30) > 25 then
			local trunkH = 5 + treeSeeds() * 7
			local trunkW = 0.8 + treeSeeds() * 0.6
			part(earth, "Trunk" .. i, Vector3.new(trunkW, trunkH, trunkW),
				CFrame.new(tx, trunkH / 2, tz),
				Color3.fromRGB(70 + math.floor(treeSeeds() * 20), 48, 30), Enum.Material.Wood)

			-- Multi-layer foliage
			local foliageBase = 4 + treeSeeds() * 5
			local greenR = 45 + math.floor(treeSeeds() * 35)
			local greenG = 95 + math.floor(treeSeeds() * 50)
			local greenB = 35 + math.floor(treeSeeds() * 25)
			ball(earth, "Foliage" .. i, foliageBase,
				CFrame.new(tx, trunkH + foliageBase * 0.2, tz),
				Color3.fromRGB(greenR, greenG, greenB), Enum.Material.LeafyGrass)
			-- Upper canopy
			ball(earth, "Canopy" .. i, foliageBase * 0.7,
				CFrame.new(tx + treeSeeds() * 1.5, trunkH + foliageBase * 0.6, tz + treeSeeds() * 1.5),
				Color3.fromRGB(greenR - 10, greenG + 10, greenB), Enum.Material.LeafyGrass)
		end
	end

	-- Stone path from spawn to workshop
	local pathRng = mulberry32(999)
	for i = 0, 14 do
		local wobble = (pathRng() - 0.5) * 2
		local sz = 2.5 + pathRng() * 2
		part(earth, "Path" .. i, Vector3.new(sz, 0.15, sz),
			CFrame.new(wobble, 0.08, 18 - i * 2.8) * CFrame.Angles(0, pathRng() * 0.3, 0),
			Color3.fromRGB(145 + math.floor(pathRng() * 20), 135, 118), Enum.Material.Cobblestone)
	end

	-- ── Material caches ──────────────────────────────────────────────────
	-- Placed around the workshop, each with a glow pad

	local caches = {}
	for _, material in Catalog.MATERIALS do
		local x = material.position[1] * 10
		local z = material.position[3] * 10

		-- Glowing pad
		local basePad = part(earth, material.id .. "Pad", Vector3.new(5, 0.15, 5),
			CFrame.new(x, 0.08, z),
			hexColor(material.color), Enum.Material.Neon)
		basePad.Transparency = 0.5

		-- The cache with appropriate shape
		local pile
		if material.structural then
			pile = part(earth, material.id, Vector3.new(3.5, 3.5, 3.5),
				CFrame.new(x, 2, z) * CFrame.Angles(0, math.rad(45), 0),
				hexColor(material.color), Enum.Material.DiamondPlate)
		elseif material.id == "oxygen" then
			pile = Instance.new("Part")
			pile.Name = material.id
			pile.Shape = Enum.PartType.Cylinder
			pile.Size = Vector3.new(4.5, 2, 2)
			pile.CFrame = CFrame.new(x, 1.5, z) * CFrame.Angles(0, 0, math.rad(90))
			pile.Color = hexColor(material.color)
			pile.Material = Enum.Material.Metal
			pile.Anchored = true
			pile.Parent = earth
		else
			pile = ball(earth, material.id, 3.5, CFrame.new(x, 2, z),
				hexColor(material.color), Enum.Material.Fabric)
		end
		if pile.Parent == nil then
			pile.Parent = earth
		end
		pile:SetAttribute("MaterialId", material.id)
		pile.CastShadow = true

		-- Proximity prompt (no floating billboard labels)
		local use = prompt(pile, "Pick up", material.name)
		caches[material.id] = { part = pile, prompt = use }
	end

	-- ── Build pads ───────────────────────────────────────────────────────
	-- Three pads inside/near the workshop

	local padsFolder = Instance.new("Folder")
	padsFolder.Name = "Pads"
	padsFolder.Parent = earth

	local slotNames = { "shell", "wrap", "air" }
	local slotTitles = { shell = "Shell", wrap = "Wrap", air = "Air" }
	local slotColors = {
		shell = Color3.fromRGB(224, 160, 69),
		wrap  = Color3.fromRGB(69, 180, 224),
		air   = Color3.fromRGB(224, 80, 69),
	}

	local pads = {}
	for index, slot in slotNames do
		local padX = -10 + (index - 1) * 10
		local padZ = -28
		local pad = part(padsFolder, slot, Vector3.new(7, 0.8, 7),
			CFrame.new(padX, 0.4, padZ),
			darken(slotColors[slot], 0.3), Enum.Material.Concrete)
		pad:SetAttribute("Slot", slot)

		-- Neon ring border
		local ring = part(padsFolder, slot .. "Ring", Vector3.new(7.6, 0.12, 7.6),
			CFrame.new(padX, 0.85, padZ),
			slotColors[slot], Enum.Material.Neon)
		ring.Transparency = 0.3

		-- Small label on the pad itself (not floating)
		local surfGui = Instance.new("SurfaceGui")
		surfGui.Face = Enum.NormalId.Top
		surfGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surfGui.PixelsPerStud = 30
		surfGui.Parent = pad
		local padLabel = Instance.new("TextLabel")
		padLabel.Size = UDim2.fromScale(1, 1)
		padLabel.BackgroundTransparency = 1
		padLabel.Font = Enum.Font.GothamBold
		padLabel.TextColor3 = slotColors[slot]
		padLabel.TextScaled = true
		padLabel.Text = slotTitles[slot]
		padLabel.Parent = surfGui

		pads[slot] = pad
	end

	-- Build bench (interaction point)
	local bench = part(earth, "Bench", Vector3.new(24, 1, 6),
		CFrame.new(-5, 0.5, -20),
		Color3.fromRGB(50, 42, 34), Enum.Material.WoodPlanks)
	local buildPrompt = prompt(bench, "Build", "Suit")

	-- ── Planet destinations ──────────────────────────────────────────────
	-- Each planet gets its own terrain zone far from Earth
	-- In Option A (multi-place), these become separate Places
	-- For now, they're distant zones with full terrain

	local destinations = Instance.new("Folder")
	destinations.Name = "Destinations"
	destinations.Parent = folder

	local planetPads = {}
	local beacons = {}
	for index, planet in Catalog.PLANETS do
		if planet.id ~= "earth" then
			local look = LOOK[planet.id] or LOOK.moon
			local cx = (index - 1) * 500  -- spread far apart
			local cz = -800
			local center = Vector3.new(cx, 0, cz)
			local planetRadius = 250 -- bigger terrain zones

			-- Generate real terrain
			generateTerrain(planet.id, center, planetRadius, index * 137)

			-- Landing pad (small, embedded in terrain)
			local pad = part(destinations, planet.id .. "Pad",
				Vector3.new(8, 0.3, 8),
				CFrame.new(cx, 0.15, cz),
				lighten(look.ground, 0.2), Enum.Material.Metal)
			pad:SetAttribute("PlanetId", planet.id)
			pad.CastShadow = false
			planetPads[planet.id] = pad

			-- Scaled sun disc (NASA-accurate apparent size)
			-- Sun angular diameter from Earth ≈ 0.53°
			-- From other planets: 0.53 / semimajorAxisAu
			-- We represent this as a neon ball high in the sky, scaled proportionally
			local earthAu = 1.0
			local sunScale = earthAu / (planet.semimajorAxisAu or 1)
			local sunSize = math.clamp(sunScale * 20, 1, 55) -- 20 studs = Earth baseline
			local sunDisc = Instance.new("Part")
			sunDisc.Name = "SunDisc"
			sunDisc.Shape = Enum.PartType.Ball
			sunDisc.Size = Vector3.new(sunSize, sunSize, sunSize)
			sunDisc.CFrame = CFrame.new(cx + 300, 500, cz - 400)
			sunDisc.Color = Color3.fromRGB(255, 250, 220)
			sunDisc.Material = Enum.Material.Neon
			sunDisc.Transparency = 0
			sunDisc.Anchored = true
			sunDisc.CanCollide = false
			sunDisc.CastShadow = false
			sunDisc.Parent = destinations
			local sunLight = Instance.new("PointLight")
			sunLight.Color = Color3.fromRGB(255, 245, 220)
			sunLight.Brightness = math.clamp(sunScale * 2, 0.3, 5)
			sunLight.Range = 60 + sunSize * 2
			sunLight.Parent = sunDisc

			-- Particle effects
			addParticles(destinations, center, PARTICLES[planet.id])

			-- Obstacle course with beacon goal
			local beacon = generateObby(destinations, planet.id, center, planet.gravityMs2, index * 313)
			beacons[planet.id] = beacon

			-- Ambient point lights for gas/ice giants (bioluminescent-style)
			if planet.archetype == "gas" or planet.archetype == "ice" then
				local lightRng = mulberry32(index * 777)
				for li = 1, 5 do
					local lx = cx + (lightRng() - 0.5) * 80
					local lz = cz + (lightRng() - 0.5) * 80
					local ly = 5 + lightRng() * 15
					local glow = Instance.new("Part")
					glow.Name = "AmbientGlow" .. li
					glow.Shape = Enum.PartType.Ball
					glow.Size = Vector3.new(2, 2, 2)
					glow.CFrame = CFrame.new(lx, ly, lz)
					glow.Color = lighten(look.sky, 0.4)
					glow.Material = Enum.Material.Neon
					glow.Transparency = 0.4
					glow.Anchored = true
					glow.CanCollide = false
					glow.Parent = destinations
					local pl = Instance.new("PointLight")
					pl.Color = lighten(look.sky, 0.3)
					pl.Brightness = 0.8
					pl.Range = 25
					pl.Parent = glow
				end
			end
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
		beacons = beacons,
		hexColor = hexColor,
	}
end

return {
	build = build,
}
