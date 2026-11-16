local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("CODAG")
local Catalog = require(shared.Data.Catalog)
local Sources = require(shared.Data.Sources)
local Survival = require(shared.Sim.Survival)
local player = Players.LocalPlayer
local remotes = shared:WaitForChild("Remotes")

local function event(name: string): RemoteEvent
	return remotes:WaitForChild(name)
end

local Place = event("Place")
local ClearSlot = event("ClearSlot")
local SetSize = event("SetSize")
local Depart = event("Depart")
local Abort = event("Abort")
local State = event("State")
local Debrief = event("Debrief")

local INK = Color3.fromRGB(20, 17, 14)
local PAPER = Color3.fromRGB(244, 239, 230)
local AMBER = Color3.fromRGB(224, 160, 69)
local PANEL = Color3.fromRGB(34, 28, 22)

local gui = Instance.new("ScreenGui")
gui.Name = "CODAG"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Mobile detection
local camera = workspace.CurrentCamera
local function isMobile(): boolean
	return camera.ViewportSize.X < 600 or UserInputService.TouchEnabled
end

local function panelWidth(): number
	if isMobile() then
		return math.min(camera.ViewportSize.X - 24, 320)
	end
	return 420
end

local function panelHeight(): number
	if isMobile() then
		return math.min(camera.ViewportSize.Y - 60, 420)
	end
	return 560
end

local COLLAPSE_BAR = 38

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.Gotham
	item.TextSize = if isMobile() then math.max(size - 2, 12) else size
	item.TextColor3 = color
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextWrapped = true
	item.Text = text
	item.Size = UDim2.new(1, 0, 0, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.Parent = parent
	return item
end

local function button(parent: Instance, text: string, primary: boolean): TextButton
	local item = Instance.new("TextButton")
	item.Size = UDim2.new(1, 0, 0, if isMobile() then 38 else 44)
	item.BackgroundColor3 = if primary then AMBER else PANEL
	item.TextColor3 = if primary then INK else PAPER
	item.Font = Enum.Font.GothamBold
	item.TextSize = if isMobile() then 14 else 16
	item.Text = text
	item.AutoButtonColor = true
	item.Parent = parent
	corner(item, 10)
	return item
end

-- Collapsible page: outer Frame with a title bar + inner ScrollingFrame
local collapsedState = {} -- name -> bool

local function page(name: string, title: string): (Frame, ScrollingFrame)
	local w = panelWidth()
	local h = panelHeight()

	local outer = Instance.new("Frame")
	outer.Name = name
	outer.Visible = false
	outer.Size = UDim2.fromOffset(w, h)
	outer.Position = UDim2.new(0, 12, 1, -h - 12)
	outer.BackgroundColor3 = INK
	outer.BorderSizePixel = 0
	outer.ClipsDescendants = true
	outer.Parent = gui
	corner(outer, 16)

	-- Title / collapse bar
	local bar = Instance.new("TextButton")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, 0, 0, COLLAPSE_BAR)
	bar.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
	bar.BorderSizePixel = 0
	bar.Font = Enum.Font.GothamBold
	bar.TextSize = 13
	bar.TextColor3 = AMBER
	bar.Text = "  " .. string.upper(title) .. "  [-]"
	bar.TextXAlignment = Enum.TextXAlignment.Left
	bar.AutoButtonColor = true
	bar.ZIndex = 5
	bar.Parent = outer
	corner(bar, 16)

	-- Scroll area below bar
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Size = UDim2.new(1, 0, 1, -COLLAPSE_BAR)
	scroll.Position = UDim2.new(0, 0, 0, COLLAPSE_BAR)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = outer

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = scroll

	collapsedState[name] = false

	bar.MouseButton1Click:Connect(function()
		collapsedState[name] = not collapsedState[name]
		if collapsedState[name] then
			outer.Size = UDim2.fromOffset(w, COLLAPSE_BAR)
			outer.Position = UDim2.new(0, 12, 1, -COLLAPSE_BAR - 12)
			scroll.Visible = false
			bar.Text = "  " .. string.upper(title) .. "  [+]"
		else
			outer.Size = UDim2.fromOffset(w, h)
			outer.Position = UDim2.new(0, 12, 1, -h - 12)
			scroll.Visible = true
			bar.Text = "  " .. string.upper(title) .. "  [-]"
		end
	end)

	return outer, scroll
end

-- Note panel (intro hint)
local note = Instance.new("Frame")
note.Name = "Note"
local noteW = if isMobile() then math.min(camera.ViewportSize.X - 24, 300) else 360
note.Size = UDim2.fromOffset(noteW, 120)
note.Position = UDim2.new(0, 12, 1, -132)
note.BackgroundColor3 = INK
note.Parent = gui
corner(note, 16)
local noteLayout = Instance.new("UIListLayout")
noteLayout.Padding = UDim.new(0, 6)
noteLayout.Parent = note
local notePad = Instance.new("UIPadding")
notePad.PaddingTop = UDim.new(0, 12)
notePad.PaddingLeft = UDim.new(0, 12)
notePad.PaddingRight = UDim.new(0, 12)
notePad.Parent = note
label(note, "CODAG.0", 14, AMBER)
label(note, "Pick up a colored pile. Then drag it onto Shell, Wrap, or Air.", 16, PAPER)
local openBuild = button(note, "Build the suit", true)

-- Main panels (outer Frame + inner ScrollingFrame)
local workshopOuter, workshop = page("Workshop", "Suit Workshop")
local planetsOuter, planets = page("Planets", "Choose Planet")
local difficultyOuter, difficulty = page("Difficulty", "Difficulty")
local debriefOuter, debrief = page("Debrief", "Mission Report")

-- HUD
local hudW = if isMobile() then math.min(camera.ViewportSize.X - 24, 280) else 320
local hudFullH = if isMobile() then 180 else 220

local hud = Instance.new("Frame")
hud.Name = "Hud"
hud.Visible = false
hud.Size = UDim2.fromOffset(hudW, hudFullH)
hud.Position = UDim2.new(0, 12, 0, 12)
hud.BackgroundColor3 = INK
hud.ClipsDescendants = true
hud.Parent = gui
corner(hud, 16)

-- HUD collapse button (top-right corner)
local hudToggle = Instance.new("TextButton")
hudToggle.Name = "HudToggle"
hudToggle.Size = UDim2.fromOffset(36, 28)
hudToggle.Position = UDim2.new(1, -42, 0, 6)
hudToggle.BackgroundTransparency = 1
hudToggle.Font = Enum.Font.GothamBold
hudToggle.TextSize = 16
hudToggle.TextColor3 = AMBER
hudToggle.Text = "-"
hudToggle.ZIndex = 5
hudToggle.Parent = hud

local hudCollapsed = false
hudToggle.MouseButton1Click:Connect(function()
	hudCollapsed = not hudCollapsed
	if hudCollapsed then
		hud.Size = UDim2.fromOffset(hudW, 34)
		hudToggle.Text = "+"
	else
		hud.Size = UDim2.fromOffset(hudW, hudFullH)
		hudToggle.Text = "-"
	end
end)

local hudLayout = Instance.new("UIListLayout")
hudLayout.Padding = UDim.new(0, 6)
hudLayout.Parent = hud
local hudPad = Instance.new("UIPadding")
hudPad.PaddingTop = UDim.new(0, 12)
hudPad.PaddingLeft = UDim.new(0, 12)
hudPad.PaddingRight = UDim.new(0, 12)
hudPad.Parent = hud

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function show(which: Frame?)
	workshopOuter.Visible = which == workshopOuter
	planetsOuter.Visible = which == planetsOuter
	difficultyOuter.Visible = which == difficultyOuter
	debriefOuter.Visible = which == debriefOuter
	note.Visible = which == nil and hud.Visible == false
end

local state = nil
local chosenPlanet = nil
local picked = nil

local function designFrom(public)
	return {
		shellMaterialId = if public.shellMaterialId ~= "" then public.shellMaterialId else nil,
		shellRadiusM = public.shellRadiusM,
		shellThicknessM = public.shellThicknessM,
		insulationMaterialId = if public.insulationMaterialId ~= "" then public.insulationMaterialId else nil,
		insulationThicknessM = public.insulationThicknessM,
		oxygenKg = public.oxygenKg,
	}
end

local function materialName(id: string): string
	if id == nil or id == "" then
		return "Empty"
	end
	return Catalog.materialById(id).name
end

local function renderWorkshop()
	clear(workshop)
	label(workshop, "CODAG.0", 14, AMBER)
	label(workshop, "Drag what you found onto the suit.", 28, PAPER).Font = Enum.Font.GothamBold
	label(workshop, "Shell holds your air in. Wrap slows the heat. Air is the bottles. You never type a size.", 16, Color3.fromRGB(217, 203, 182))
	label(workshop, state.hint, 16, AMBER)
	if state.problem ~= "" then
		label(workshop, state.problem, 16, Color3.fromRGB(224, 122, 74))
	end
	for _, material in Catalog.MATERIALS do
		if (state.inventory[material.id] or 0) > 0 then
			local card = button(workshop, material.name, picked == material.id)
			card.MouseButton1Click:Connect(function()
				picked = material.id
				renderWorkshop()
			end)
		end
	end
	local design = designFrom(state.design)
	local slots = {
		{ id = "shell", title = "Shell", filled = materialName(design.shellMaterialId) },
		{ id = "wrap", title = "Wrap", filled = materialName(design.insulationMaterialId) },
		{ id = "air", title = "Air", filled = if design.oxygenKg > 0 then "Bottles packed" else "Empty" },
	}
	for _, slot in slots do
		local slotButton = button(workshop, slot.title .. "  ·  " .. slot.filled, false)
		slotButton.MouseButton1Click:Connect(function()
			if picked ~= nil then
				Place:FireServer(picked, slot.id)
				picked = nil
			end
		end)
		if slot.filled ~= "Empty" then
			local off = button(workshop, "Take off " .. slot.title, false)
			off.MouseButton1Click:Connect(function()
				ClearSlot:FireServer(slot.id)
			end)
		end
	end
	for _, size in { { "fits", "Fits me" }, { "bigger", "A bit bigger" }, { "bulky", "Big and heavy" } } do
		local sizeButton = button(workshop, size[2], false)
		sizeButton.MouseButton1Click:Connect(function()
			SetSize:FireServer(size[1])
		end)
	end
	local check = Catalog.difficultyById("normal").minSafetyFactor
	local moon = Catalog.planetById("moon")
	label(workshop, "Same suit, Moon:", 16, PAPER)
	label(workshop, Survival.kidResult(design, moon, check, "hot"), 16, PAPER)
	label(workshop, Survival.kidResult(design, moon, check, "cold"), 16, PAPER)
	local go = button(workshop, "Try this suit on a planet", true)
	go.Active = state.problem == ""
	go.AutoButtonColor = state.problem == ""
	go.MouseButton1Click:Connect(function()
		if state.problem == "" then
			show(planetsOuter)
			renderPlanets()
		end
	end)
end

openBuild.MouseButton1Click:Connect(function()
	show(workshopOuter)
	if state ~= nil then
		renderWorkshop()
	end
end)

local function isOpen(planetId: string): boolean
	local previous = nil
	local cleared = {}
	for _, id in state.clears do
		cleared[id] = true
	end
	for _, id in Sources.DESTINATION_ORDER do
		if id == planetId then
			return previous == nil or cleared[previous] == true
		end
		previous = id
	end
	return false
end

function renderPlanets()
	clear(planets)
	label(planets, "Same suit. Different planet.", 28, PAPER).Font = Enum.Font.GothamBold
	label(planets, "The line under each name is what this suit would do there. The planet numbers do not change.", 16, Color3.fromRGB(217, 203, 182))
	local design = designFrom(state.design)
	local check = Catalog.difficultyById("normal").minSafetyFactor
	for _, planetId in Sources.DESTINATION_ORDER do
		local planet = Catalog.planetById(planetId)
		local open = isOpen(planetId)
		label(planets, planet.name, 20, PAPER).Font = Enum.Font.GothamBold
		label(planets, Survival.kidResult(design, planet, check, "hot"), 16, PAPER)
		local choose = button(planets, if open then "Select" else "Locked", open)
		choose.Active = open
		choose.MouseButton1Click:Connect(function()
			if open then
				chosenPlanet = planetId
				show(difficultyOuter)
				renderDifficulty()
			end
		end)
	end
	local back = button(planets, "Back to the suit", false)
	back.MouseButton1Click:Connect(function()
		show(workshopOuter)
	end)
end

function renderDifficulty()
	clear(difficulty)
	local planet = Catalog.planetById(chosenPlanet)
	label(difficulty, planet.name, 28, PAPER).Font = Enum.Font.GothamBold
	label(difficulty, planet.referencePressure.transcribedFrom, 16, Color3.fromRGB(217, 203, 182))
	label(difficulty, "Difficulty changes the rules, not the planet.", 16, PAPER)
	for _, profile in Catalog.DIFFICULTIES do
		local pick = button(difficulty, profile.label, profile.id == "normal")
		pick.MouseButton1Click:Connect(function()
			clear(difficulty)
			label(difficulty, planet.name .. " · " .. profile.label, 28, PAPER).Font = Enum.Font.GothamBold
			local hot = Survival.exposure(planet, "hot")
			local cold = Survival.exposure(planet, "cold")
			local hotButton = button(difficulty, string.format("Hot side, %.0f °C", Survival.celsius(hot.kelvin)), true)
			local coldButton = button(difficulty, string.format("Cold side, %.0f °C", Survival.celsius(cold.kelvin)), true)
			hotButton.MouseButton1Click:Connect(function()
				Depart:FireServer(planet.id, profile.id, "hot")
				show(nil)
			end)
			coldButton.MouseButton1Click:Connect(function()
				Depart:FireServer(planet.id, profile.id, "cold")
				show(nil)
			end)
			label(difficulty, hot.transcribedFrom, 14, Color3.fromRGB(217, 203, 182))
		end)
	end
	local back = button(difficulty, "Back", false)
	back.MouseButton1Click:Connect(function()
		show(planetsOuter)
		renderPlanets()
	end)
end

local hudTitle = label(hud, "CODAG.0", 14, AMBER)
local hudClock = label(hud, "0:00 / 20:00", if isMobile() then 22 else 28, PAPER)
hudClock.Font = Enum.Font.GothamBold
local hudAir = label(hud, "Air held in", if isMobile() then 14 else 16, PAPER)
local hudCore = label(hud, "Core 37 °C", if isMobile() then 14 else 16, PAPER)
local hudOxygen = label(hud, "Oxygen", if isMobile() then 14 else 16, PAPER)
local hudDeath = label(hud, "", if isMobile() then 16 else 18, Color3.fromRGB(224, 122, 74))
local died = button(hud, "You died", true)
died.Visible = false
died.MouseButton1Click:Connect(function()
	hud.Visible = false
	debriefOuter.Visible = true
end)

local function clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local function renderHud()
	local inMission = player:GetAttribute("InMission") == true
	hud.Visible = inMission
	if inMission then
		note.Visible = false
	end
	if not inMission then
		return
	end
	show(nil)
	local planetName = player:GetAttribute("MissionPlanet") or ""
	local side = player:GetAttribute("MissionSide") or ""
	local mode = player:GetAttribute("MissionDifficulty") or ""
	hudTitle.Text = string.upper(planetName) .. " · " .. string.upper(side) .. " · " .. string.upper(mode)
	hudClock.Text = clock(player:GetAttribute("MissionClock") or 0) .. " / 20:00"
	local held = player:GetAttribute("AirHeld") or 100
	hudAir.Text = if held >= 100 then "Air held in. The shell is closed." else string.format("Air held in  %.0f%%. No shell. The air is leaving.", held)
	hudCore.Text = string.format("Core  %.1f °C", player:GetAttribute("CoreC") or 37)
	hudOxygen.Text = string.format("Oxygen  %.3f kg", player:GetAttribute("OxygenKg") or 0)
	local alive = player:GetAttribute("Alive") ~= false
	local cause = player:GetAttribute("CauseTitle") or ""
	hudDeath.Text = if alive then "" else cause
	died.Visible = not alive
	died.Text = if alive then "You held on" else "You died"
end

player:GetAttributeChangedSignal("MissionClock"):Connect(renderHud)
player:GetAttributeChangedSignal("InMission"):Connect(renderHud)
player:GetAttributeChangedSignal("Alive"):Connect(renderHud)
player:GetAttributeChangedSignal("CoreC"):Connect(renderHud)
player:GetAttributeChangedSignal("AirHeld"):Connect(renderHud)

State.OnClientEvent:Connect(function(nextState)
	state = nextState
	if debriefOuter.Visible or hud.Visible or planetsOuter.Visible or difficultyOuter.Visible then
		return
	end
	if workshopOuter.Visible then
		renderWorkshop()
	end
end)

Debrief.OnClientEvent:Connect(function(report)
	clear(debrief)
	hud.Visible = false
	show(debriefOuter)
	label(debrief, if report.survived then "You survived" else "You died", 14, AMBER)
	label(debrief, report.title, 28, PAPER).Font = Enum.Font.GothamBold
	label(debrief, report.detail, 16, PAPER)
	label(debrief, "Looked up for this result", 20, PAPER).Font = Enum.Font.GothamBold
	label(debrief, "These lines were retrieved from the fact sheets. The physics check decided pass or fail. No model filled in a number.", 14, Color3.fromRGB(217, 203, 182))
	for _, fact in report.facts do
		label(debrief, fact.text, 15, PAPER)
		label(debrief, fact.body .. " fact sheet", 13, AMBER)
		label(debrief, fact.sourceUrl, 12, Color3.fromRGB(240, 194, 122))
	end
	local again = button(debrief, "Try again", false)
	again.MouseButton1Click:Connect(function()
		show(difficultyOuter)
		renderDifficulty()
	end)
	local suit = button(debrief, "Change the suit", false)
	suit.MouseButton1Click:Connect(function()
		show(workshopOuter)
		renderWorkshop()
	end)
	local earth = button(debrief, "Back to Earth", true)
	earth.MouseButton1Click:Connect(function()
		Abort:FireServer()
		show(workshopOuter)
		renderWorkshop()
	end)
end)

show(nil)
event("Ready"):FireServer()
