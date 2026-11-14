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

local world = World.build()
local earthG = Catalog.planetById("earth").gravityMs2
local TIME_SCALE = 30

local function remote(name: string): RemoteEvent
	local folder = shared:FindFirstChild("Remotes")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = shared
	end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

local State = remote("State")
local Ready = remote("Ready")
local Debrief = remote("Debrief")
local Place = remote("Place")
local ClearSlot = remote("ClearSlot")
local SetSize = remote("SetSize")
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
	Lighting.FogStart = if planetId == "earth" then 400 else 40
	Lighting.FogEnd = if planetId == "earth" then 900 else 180
end

local function gravityFor(planetId: string): number
	return Physics.gravityStuds(Catalog.planetById(planetId).gravityMs2, earthG)
end

local function unlocked(session, planetId: string): boolean
	local previous = nil
	for _, id in Sources.DESTINATION_ORDER do
		if id == planetId then
			return previous == nil or session.clears[previous] == true
		end
		previous = id
	end
	return false
end

local function publicDesign(design)
	return {
		shellMaterialId = design.shellMaterialId or "",
		shellRadiusM = design.shellRadiusM,
		shellThicknessM = design.shellThicknessM,
		insulationMaterialId = design.insulationMaterialId or "",
		insulationThicknessM = design.insulationThicknessM,
		oxygenKg = design.oxygenKg,
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
	local function shellPart(materialId: string?, scale: number, transparency: number)
		if materialId == nil or materialId == "" then
			return
		end
		local piece = Instance.new("Part")
		piece.Name = materialId
		piece.Shape = Enum.PartType.Ball
		piece.Size = Vector3.new(4.2, 5.4, 4.2) * scale
		piece.Color = world.hexColor(Catalog.materialById(materialId).color)
		piece.Transparency = transparency
		piece.CanCollide = false
		piece.Massless = true
		piece.CFrame = root.CFrame
		piece.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = piece
		weld.Parent = piece
	end
	shellPart(session.design.shellMaterialId, 1, 0.55)
	shellPart(session.design.insulationMaterialId, 1.18, 0.45)
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
	local madeIt = Survival.survived(mission.vitals)
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
		title = if madeIt then "Twenty minutes on " .. planet.name .. "." else Survival.deathTitle(cause),
		detail = if madeIt
			then "Your core stayed near 37 °C and you still had oxygen."
			else Survival.deathDetail(planet, mission.side, cause),
		facts = lines,
	})
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
	if not vitals.alive or Survival.survived(vitals) then
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
	local problem = Design.stockProblem(session.design, session.inventory)
	if problem ~= nil then
		session.problem = problem
		session.hint = problem
		sendState(player)
		return
	end
	local profile = Catalog.difficultyById(difficultyId)
	local planet = Catalog.planetById(planetId)
	session.mission = {
		planetId = planetId,
		difficultyId = difficultyId,
		side = side,
		minSafetyFactor = profile.minSafetyFactor,
		vitals = Survival.initialVitals(session.design),
	}
	workspace.Gravity = gravityFor(planetId)
	applyLook(planetId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local pad = world.planetPads[planetId]
	if root and pad then
		root.CFrame = pad.CFrame + Vector3.new(0, 8, 0)
	end
	player:SetAttribute("MissionPlanet", planet.name)
	player:SetAttribute("MissionSide", side)
	player:SetAttribute("MissionDifficulty", profile.label)
	stepMission(player, 0)
end

local function place(player: Player, materialId: string, slot: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	if (session.inventory[materialId] or 0) <= 0 then
		session.hint = "You have not found that yet."
		sendState(player)
		return
	end
	local material = Catalog.materialById(materialId)
	local design = session.design
	if slot == "air" then
		if materialId ~= "oxygen" then
			session.hint = "Only the red bottles go on Air."
		else
			design.oxygenKg = session.inventory.oxygen or 0
			session.hint = "Bottles packed. That is all the air you found."
		end
	elseif slot == "shell" then
		if materialId == "oxygen" then
			session.hint = "Bottles go on Air."
		elseif not material.structural then
			session.hint = material.name .. " cannot hold air. Put it on the wrap."
		else
			design.shellMaterialId = materialId
			session.hint = material.name .. " is the hard shell. It keeps your air in."
		end
	elseif slot == "wrap" then
		if materialId == "oxygen" or material.structural then
			session.hint = if materialId == "oxygen" then "Bottles go on Air." else material.name .. " is hard. It belongs on the shell."
		else
			design.insulationMaterialId = materialId
			session.hint = material.name .. " is the wrap. It slows the heat."
		end
	end
	session.problem = Design.stockProblem(design, session.inventory)
	wear(player)
	sendState(player)
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
	local token = cache.part:Clone()
	token.Transparency = 0
	token.Size = Vector3.new(3, 2, 3)
	token.CFrame = world.pads.shell.CFrame * CFrame.new(0, 3, 6)
	token.Anchored = true
	token:SetAttribute("MaterialId", materialId)
	local oldPrompt = token:FindFirstChildOfClass("ProximityPrompt")
	if oldPrompt then
		oldPrompt:Destroy()
	end
	token.Parent = world.bench
	local homeCFrame = token.CFrame
	local created, drag = pcall(function()
		return Instance.new("DragDetector")
	end)
	if created and drag ~= nil then
		drag.Parent = token
		drag.DragEnd:Connect(function(who: Player)
			local nearest = nil
			local best = 12
			for _, pad in pairs(world.pads) do
				local distance = (pad.Position - token.Position).Magnitude
				if distance < best then
					nearest = pad
					best = distance
				end
			end
			token.CFrame = homeCFrame
			if nearest ~= nil and typeof(who) == "Instance" then
				place(who, materialId, nearest:GetAttribute("Slot"))
			end
		end)
	end
	session.hint = "Picked up " .. material.name .. ". Drag it onto Shell, Wrap, or Air."
	sendState(player)
end

local function startSession(player: Player)
	sessions[player] = {
		inventory = emptyInventory(),
		design = Design.emptyDesign(),
		clears = {},
		hint = "Pick up a pile, then drag it onto a pad.",
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

Place.OnServerEvent:Connect(function(player, materialId, slot)
	if typeof(materialId) ~= "string" or typeof(slot) ~= "string" then
		return
	end
	place(player, materialId, slot)
end)

ClearSlot.OnServerEvent:Connect(function(player, slot)
	local session = sessions[player]
	if session == nil or typeof(slot) ~= "string" then
		return
	end
	if slot == "shell" then
		session.design.shellMaterialId = nil
	elseif slot == "wrap" then
		session.design.insulationMaterialId = nil
	elseif slot == "air" then
		session.design.oxygenKg = 0
	end
	session.problem = Design.stockProblem(session.design, session.inventory)
	session.hint = "Took it off."
	wear(player)
	sendState(player)
end)

SetSize.OnServerEvent:Connect(function(player, sizeId)
	local session = sessions[player]
	local size = Design.SIZES[sizeId]
	if session == nil or size == nil then
		return
	end
	session.design.shellRadiusM = size.shellRadiusM
	session.design.shellThicknessM = size.shellThicknessM
	session.design.insulationThicknessM = size.insulationThicknessM
	session.problem = Design.stockProblem(session.design, session.inventory)
	session.hint = "Suit size changed. The weight is calculated from that."
	sendState(player)
end)

Depart.OnServerEvent:Connect(function(player, planetId, difficultyId, side)
	if typeof(planetId) ~= "string" or typeof(difficultyId) ~= "string" or typeof(side) ~= "string" then
		return
	end
	depart(player, planetId, difficultyId, side)
end)

Abort.OnServerEvent:Connect(function(player)
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
			home(player)
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
