-- Portions of CODAG.0 were written with Cursor AI.
-- Planet numbers are the NSSDC fact sheets. Roblox gravity is those values scaled to the avatar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local shared = ReplicatedStorage:WaitForChild("CODAG")
local Catalog = require(shared.Data.Catalog)
local Sources = require(shared.Data.Sources)
local Design = require(shared.Sim.Design)
local Survival = require(shared.Sim.Survival)
local Retrieve = require(shared.Sim.Retrieve)
local Physics = require(shared.Sim.Physics)
local World = require(script.World)

Catalog.assertFactSheetRecords(Catalog.PLANETS)

warn("[CODAG Server] Script starting")
local world = World.build()
warn("[CODAG Server] World built")
local earthG = Catalog.planetById("earth").gravityMs2
local TIME_SCALE = 30

local function remote(name: string): RemoteEvent
	local folder = shared:FindFirstChild("Remotes")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = shared
	end
	-- Reuse existing event so client references survive server restart (Rojo sync)
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		warn("[CODAG Server] Reusing event:", name)
		return existing
	end
	warn("[CODAG Server] Creating event:", name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

local State = remote("State")
local Ready = remote("Ready")
local Debrief = remote("Debrief")
local AddLayer = remote("AddLayer")
local RemoveLayer = remote("RemoveLayer")
local SetOxygen = remote("SetOxygen")
local Depart = remote("Depart")
local Abort = remote("Abort")

local sessions = {}

local function emptyInventory()
	local inventory = {}
	for _, material in Catalog.MATERIALS do
		inventory[material.id] = 0
	end
	return inventory
end

local function applyLook(planetId: string)
	local look = world.look[planetId] or world.look.earth
	Lighting.ClockTime = look.clock
	Lighting.Ambient = look.sky
	Lighting.OutdoorAmbient = look.sky
	Lighting.FogColor = look.sky
	Lighting.FogStart = if planetId == "earth" then 9999 else 40
	Lighting.FogEnd = if planetId == "earth" then 10000 else 180

	local atmoConfig = world.atmo[planetId] or world.atmo.earth
	local atmoInst = world.atmoInstance
	if atmoInst then
		atmoInst.Density = atmoConfig.density
		atmoInst.Offset = atmoConfig.offset
		atmoInst.Haze = atmoConfig.haze
		atmoInst.Glare = atmoConfig.glare
		atmoInst.Color = atmoConfig.color
		atmoInst.Decay = atmoConfig.decay
	end

	local bloom = Lighting:FindFirstChild("CODAGBloom")
	if bloom then
		local airless = planetId == "moon" or planetId == "mercury"
		bloom.Intensity = if airless then 0.6 else 0.4
		bloom.Threshold = if airless then 0.8 else 0.9
	end

	local cc = Lighting:FindFirstChild("CODAGColor")
	if cc then
		if planetId == "venus" then
			cc.TintColor = Color3.fromRGB(255, 230, 180)
			cc.Saturation = 0.15
		elseif planetId == "mars" then
			cc.TintColor = Color3.fromRGB(255, 220, 200)
			cc.Saturation = 0.1
		elseif planetId == "neptune" or planetId == "uranus" then
			cc.TintColor = Color3.fromRGB(220, 235, 255)
			cc.Saturation = 0.05
		else
			cc.TintColor = Color3.fromRGB(255, 248, 240)
			cc.Saturation = 0.08
		end
	end
end

local function gravityFor(planetId: string): number
	return Physics.gravityStuds(Catalog.planetById(planetId).gravityMs2, earthG)
end

local DEMO_MODE = true -- hackathon: all planets open

local function unlocked(session, planetId: string): boolean
	if DEMO_MODE then return true end
	local previous = nil
	for _, id in Sources.DESTINATION_ORDER do
		if id == planetId then
			return previous == nil or session.clears[previous] == true
		end
		previous = id
	end
	return false
end

-- Send layer-based design to client
local function publicDesign(design)
	local layers = {}
	for _, layer in design.layers do
		table.insert(layers, {
			materialId = layer.materialId,
			thicknessM = layer.thicknessM,
		})
	end
	-- Also send legacy fields for backward compat
	return {
		layers = layers,
		oxygenKg = design.oxygenKg,
		shellMaterialId = Design.shellMaterialId(design) or "",
		shellRadiusM = Design.outerRadiusM(design),
		shellThicknessM = Design.shellThicknessM(design),
		insulationMaterialId = "",
		insulationThicknessM = 0,
	}
end

local function sendState(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	local clears = {}
	for id, did in session.clears do
		if did then
			table.insert(clears, id)
		end
	end
	State:FireClient(player, {
		inventory = session.inventory,
		design = publicDesign(session.design),
		hint = session.hint,
		problem = session.problem or "",
		clears = clears,
	})
end

local function wear(player: Player)
	local session = sessions[player]
	local character = player.Character
	if session == nil or character == nil then
		return
	end
	local old = character:FindFirstChild("CODAGSuit")
	if old then
		old:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = "CODAGSuit"
	model.Parent = character

	-- Render each layer as a concentric sphere
	local radius = Design.BASE_RADIUS_M
	local baseScale = 4.2 -- studs for base radius
	for i, layer in session.design.layers do
		local mat = Catalog.materialById(layer.materialId)
		radius += layer.thicknessM
		local scale = radius / Design.BASE_RADIUS_M
		local piece = Instance.new("Part")
		piece.Name = mat.id .. "_" .. tostring(i)
		piece.Shape = Enum.PartType.Ball
		piece.Size = Vector3.new(baseScale, 5.4, baseScale) * scale
		piece.Color = world.hexColor(mat.color)
		piece.Transparency = 0.3 + (i * 0.08)
		piece.CanCollide = false
		piece.Massless = true
		piece.CFrame = root.CFrame
		piece.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = piece
		weld.Parent = piece
	end

	-- Oxygen tank
	if session.design.oxygenKg > 0 then
		local bottle = Instance.new("Part")
		bottle.Name = "Oxygen"
		bottle.Shape = Enum.PartType.Cylinder
		bottle.Size = Vector3.new(1.4, 0.5, 0.5)
		bottle.Color = Color3.fromRGB(196, 71, 58)
		bottle.CanCollide = false
		bottle.Massless = true
		bottle.CFrame = root.CFrame * CFrame.new(1.6, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		bottle.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = bottle
		weld.Parent = bottle
	end
end

local function tuneJump(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
	end
end

local function home(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	session.mission = nil
	workspace.Gravity = gravityFor("earth")
	applyLook("earth")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = world.spawn.CFrame + Vector3.new(0, 4, 0)
	end
	player:SetAttribute("InMission", false)
end

local function finishMission(player: Player)
	local session = sessions[player]
	if session == nil or session.mission == nil then
		return
	end
	local mission = session.mission
	session.mission = nil
	player:SetAttribute("InMission", false)
	local madeIt = Survival.survived(mission.vitals) or mission.vitals.reachedBeacon == true
	if madeIt then
		session.clears[mission.planetId] = true
	end
	local cause = if madeIt then "survive" else (mission.vitals.cause or "oxygen")
	local planet = Catalog.planetById(mission.planetId)
	local facts = Retrieve.retrieve(planet, cause)
	local lines = {}
	for _, fact in facts do
		table.insert(lines, {
			text = fact.text,
			sourceUrl = fact.sourceUrl,
			body = Catalog.planetById(fact.planetId).name,
		})
	end
	Debrief:FireClient(player, {
		planetId = mission.planetId,
		planetName = planet.name,
		difficultyId = mission.difficultyId,
		side = mission.side,
		survived = madeIt,
		title = if madeIt then "You made it across " .. planet.name .. "." else Survival.deathTitle(cause),
		detail = if madeIt
			then "You reached the beacon. Your suit held."
			else Survival.deathDetail(planet, mission.side, cause),
		facts = lines,
	})
	-- Return player to earth station after mission ends
	home(player)
	sendState(player)
end

local function stepMission(player: Player, realDt: number)
	local session = sessions[player]
	local mission = session and session.mission
	if mission == nil or not mission.vitals.alive then
		return
	end
	local dt = math.clamp(realDt, 0, 0.05) * TIME_SCALE
	mission.vitals = Survival.stepVitals(
		mission.vitals,
		session.design,
		Catalog.planetById(mission.planetId),
		mission.minSafetyFactor,
		mission.side,
		dt
	)
	local vitals = mission.vitals
	local sealed = Design.isSealed(session.design)
	local held = if sealed then 100 else math.max(0, 100 * (1 - vitals.elapsedS / Survival.VACUUM_FAIL_S))
	player:SetAttribute("InMission", true)
	player:SetAttribute("MissionClock", vitals.elapsedS)
	player:SetAttribute("CoreC", Survival.celsius(vitals.bodyTempK))
	player:SetAttribute("OxygenKg", vitals.oxygenKg)
	player:SetAttribute("AirHeld", held)
	player:SetAttribute("Alive", vitals.alive)
	player:SetAttribute("CauseTitle", if vitals.cause then Survival.deathTitle(vitals.cause) else "")
	if not vitals.alive or vitals.reachedBeacon or Survival.survived(vitals) then
		finishMission(player)
	end
end

local function depart(player: Player, planetId: string, difficultyId: string, side: string)
	local session = sessions[player]
	if session == nil or session.mission ~= nil then
		return
	end
	if side ~= "hot" and side ~= "cold" then
		return
	end
	if not unlocked(session, planetId) then
		session.hint = "That planet is still locked."
		sendState(player)
		return
	end
	-- Stock check removed: AddLayer already gates undiscovered materials
	local profile = Catalog.difficultyById(difficultyId)
	local planet = Catalog.planetById(planetId)
	local pad = world.planetPads[planetId]
	session.mission = {
		planetId = planetId,
		difficultyId = difficultyId,
		side = side,
		minSafetyFactor = profile.minSafetyFactor,
		vitals = Survival.initialVitals(session.design),
		lastCheckpoint = if pad then pad.CFrame + Vector3.new(0, 5, 0) else nil,
	}
	workspace.Gravity = gravityFor(planetId)
	applyLook(planetId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and pad then
		root.CFrame = pad.CFrame + Vector3.new(0, 5, 0)
	end
	player:SetAttribute("MissionPlanet", planet.name)
	player:SetAttribute("MissionSide", side)
	player:SetAttribute("MissionDifficulty", profile.label)
	stepMission(player, 0)
end

local function collect(player: Player, materialId: string)
	local session = sessions[player]
	local cache = world.caches[materialId]
	if session == nil or cache == nil then
		return
	end
	if (session.inventory[materialId] or 0) > 0 then
		return
	end
	local material = Catalog.materialById(materialId)
	session.inventory[materialId] = material.foundKg
	cache.prompt.Enabled = false
	cache.part.Transparency = 0.75
	session.hint = "Picked up " .. material.name .. "."
	sendState(player)
end

local function startSession(player: Player)
	sessions[player] = {
		inventory = emptyInventory(),
		design = Design.emptyDesign(),
		clears = {},
		hint = "Collect materials, then build your suit layer by layer.",
		problem = nil,
		mission = nil,
	}
	player:SetAttribute("InMission", false)
	sendState(player)
end

for _, cache in world.caches do
	cache.prompt.Triggered:Connect(function(player)
		collect(player, cache.part:GetAttribute("MaterialId"))
	end)
end

-- Beacon touch = mission complete
for planetId, beacon in world.beacons do
	beacon.Touched:Connect(function(hit)
		local character = hit.Parent
		if character == nil then return end
		local player = Players:GetPlayerFromCharacter(character)
		if player == nil then return end
		local session = sessions[player]
		if session == nil or session.mission == nil then return end
		if session.mission.planetId ~= planetId then return end
		if session.mission.vitals.alive then
			session.mission.vitals.reachedBeacon = true
		end
	end)
end

-- Kill zone touch = die and respawn at checkpoint
for _, descendant in world.destinations:GetDescendants() do
	if descendant:IsA("BasePart") and descendant:GetAttribute("KillZone") then
		descendant.Touched:Connect(function(hit)
			local character = hit.Parent
			if character == nil then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end)
	end
end

-- Checkpoint touch = save respawn point
for _, descendant in world.destinations:GetDescendants() do
	if descendant:IsA("BasePart") and descendant:GetAttribute("Checkpoint") then
		descendant.Touched:Connect(function(hit)
			local character = hit.Parent
			if character == nil then return end
			local player = Players:GetPlayerFromCharacter(character)
			if player == nil then return end
			local session = sessions[player]
			if session == nil or session.mission == nil then return end
			local cpPlanet = descendant:GetAttribute("PlanetId")
			if cpPlanet == session.mission.planetId then
				session.mission.lastCheckpoint = descendant.CFrame + Vector3.new(0, 3, 0)
			end
		end)
	end
end

-- Add a layer to the suit
AddLayer.OnServerEvent:Connect(function(player, materialId, thicknessId)
	local session = sessions[player]
	if session == nil or typeof(materialId) ~= "string" or typeof(thicknessId) ~= "string" then
		return
	end
	if materialId == "oxygen" then
		session.hint = "Use the oxygen control to add air tanks."
		sendState(player)
		return
	end
	if (session.inventory[materialId] or 0) <= 0 then
		session.hint = "You have not found that yet."
		sendState(player)
		return
	end
	-- Find thickness
	local thickness = nil
	for _, opt in Design.THICKNESS_OPTIONS do
		if opt.id == thicknessId then
			thickness = opt.meters
			break
		end
	end
	if thickness == nil then
		return
	end
	-- No layer cap: free-form engineering
	table.insert(session.design.layers, {
		materialId = materialId,
		thicknessM = thickness,
	})
	Design.syncLegacy(session.design)
	local mat = Catalog.materialById(materialId)
	session.hint = "Added " .. mat.name .. " layer."
	session.problem = nil
	wear(player)
	sendState(player)
end)

-- Remove a layer by index
RemoveLayer.OnServerEvent:Connect(function(player, layerIndex)
	local session = sessions[player]
	if session == nil or typeof(layerIndex) ~= "number" then
		return
	end
	layerIndex = math.floor(layerIndex)
	if layerIndex < 1 or layerIndex > #session.design.layers then
		return
	end
	table.remove(session.design.layers, layerIndex)
	Design.syncLegacy(session.design)
	session.hint = "Removed layer."
	session.problem = nil
	wear(player)
	sendState(player)
end)

-- Set oxygen amount
SetOxygen.OnServerEvent:Connect(function(player, kg)
	local session = sessions[player]
	if session == nil or typeof(kg) ~= "number" then
		return
	end
	local available = session.inventory.oxygen or 0
	session.design.oxygenKg = math.clamp(kg, 0, available)
	session.hint = string.format("Packed %.1f kg of oxygen.", session.design.oxygenKg)
	session.problem = nil
	sendState(player)
end)

Depart.OnServerEvent:Connect(function(player, planetId, difficultyId, side)
	warn("[CODAG Server] Depart event received:", planetId, difficultyId, side)
	if typeof(planetId) ~= "string" or typeof(difficultyId) ~= "string" or typeof(side) ~= "string" then
		warn("[CODAG Server] Depart: bad types")
		return
	end
	local session = sessions[player]
	warn("[CODAG Server] Depart: session exists =", session ~= nil, "mission =", session and session.mission ~= nil)
	depart(player, planetId, difficultyId, side)
end)

Abort.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if session then
		session.mission = nil
	end
	player:SetAttribute("InMission", false)
	home(player)
	sendState(player)
end)

local function bind(player: Player)
	startSession(player)
	player.CharacterAdded:Connect(function(character)
		tuneJump(character)
		wear(player)
		local session = sessions[player]
		if session and session.mission then
			-- Respawn at last checkpoint instead of ending the mission
			local checkpoint = session.mission.lastCheckpoint
			if checkpoint then
				local root = character:WaitForChild("HumanoidRootPart", 5)
				if root then
					workspace.Gravity = gravityFor(session.mission.planetId)
					applyLook(session.mission.planetId)
					root.CFrame = checkpoint
				end
			else
				home(player)
			end
		end
	end)
	if player.Character then
		tuneJump(player.Character)
	end
end

Ready.OnServerEvent:Connect(function(player)
	if sessions[player] == nil then
		bind(player)
	end
	sendState(player)
end)

Players.PlayerAdded:Connect(bind)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	workspace.Gravity = gravityFor("earth")
	applyLook("earth")
end)

for _, player in Players:GetPlayers() do
	bind(player)
end

workspace.Gravity = gravityFor("earth")
applyLook("earth")

RunService.Heartbeat:Connect(function(dt)
	for player, session in pairs(sessions) do
		if session.mission ~= nil then
			stepMission(player, dt)
		end
	end
end)
