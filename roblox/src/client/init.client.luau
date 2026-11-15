local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- ── Design tokens ────────────────────────────────────────────────────────

local INK      = Color3.fromRGB(18, 15, 12)
local INK_MID  = Color3.fromRGB(30, 26, 21)
local PAPER    = Color3.fromRGB(244, 239, 230)
local PAPER_DIM= Color3.fromRGB(190, 180, 165)
local AMBER    = Color3.fromRGB(224, 160, 69)
local AMBER_DIM= Color3.fromRGB(180, 130, 55)
local RED      = Color3.fromRGB(210, 90, 70)
local GREEN    = Color3.fromRGB(90, 180, 100)
local PANEL    = Color3.fromRGB(38, 32, 26)
local PANEL_HI = Color3.fromRGB(52, 44, 36)

local FONT_TITLE = Enum.Font.GothamBlack
local FONT_BOLD  = Enum.Font.GothamBold
local FONT_BODY  = Enum.Font.Gotham
local FONT_MONO  = Enum.Font.Code

-- ── ScreenGui ────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "CODAG"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- ── UI helpers ───────────────────────────────────────────────────────────

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local ui = Instance.new("UIStroke")
	ui.Color = color
	ui.Thickness = thickness
	ui.Transparency = 0.6
	ui.Parent = parent
end

local function padding(parent: Instance, top: number, bottom: number, left: number, right: number)
	local ui = Instance.new("UIPadding")
	ui.PaddingTop = UDim.new(0, top)
	ui.PaddingBottom = UDim.new(0, bottom)
	ui.PaddingLeft = UDim.new(0, left)
	ui.PaddingRight = UDim.new(0, right)
	ui.Parent = parent
end

local function listLayout(parent: Instance, gap: number, order: Enum.SortOrder?)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = order or Enum.SortOrder.LayoutOrder
	layout.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = font or FONT_BODY
	item.TextSize = size
	item.TextColor3 = color
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextWrapped = true
	item.Text = text
	item.Size = UDim2.new(1, 0, 0, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.Parent = parent
	return item
end

local function divider(parent: Instance)
	local line = Instance.new("Frame")
	line.BackgroundColor3 = PAPER_DIM
	line.BackgroundTransparency = 0.8
	line.BorderSizePixel = 0
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Parent = parent
end

local function button(parent: Instance, text: string, primary: boolean): TextButton
	local item = Instance.new("TextButton")
	item.Size = UDim2.new(1, 0, 0, 48)
	item.BackgroundColor3 = if primary then AMBER else PANEL
	item.TextColor3 = if primary then INK else PAPER
	item.Font = FONT_BOLD
	item.TextSize = 16
	item.Text = text
	item.AutoButtonColor = true
	item.Parent = parent
	corner(item, 12)
	if not primary then
		stroke(item, PAPER_DIM, 1)
	end
	return item
end

local function smallButton(parent: Instance, text: string, color: Color3): TextButton
	local item = Instance.new("TextButton")
	item.Size = UDim2.new(0.48, 0, 0, 38)
	item.BackgroundColor3 = color
	item.TextColor3 = INK
	item.Font = FONT_BOLD
	item.TextSize = 14
	item.Text = text
	item.AutoButtonColor = true
	item.Parent = parent
	corner(item, 10)
	return item
end

local function card(parent: Instance, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color or INK_MID
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	corner(frame, 10)
	padding(frame, 10, 10, 10, 10)
	listLayout(frame, 4)
	return frame
end

-- ── Meter bar ────────────────────────────────────────────────────────────

local function meter(parent: Instance, labelText: string, pct: number, barColor: Color3): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 32)
	row.Parent = parent

	label(row, labelText, 13, PAPER_DIM, FONT_MONO).Position = UDim2.new(0, 0, 0, 0)

	local track = Instance.new("Frame")
	track.BackgroundColor3 = PANEL
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, 8)
	track.Position = UDim2.new(0, 0, 0, 22)
	track.Parent = row
	corner(track, 4)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = barColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(math.clamp(pct / 100, 0, 1), 0, 1, 0)
	fill.Parent = track
	corner(fill, 4)

	return row
end

-- ── Panels ───────────────────────────────────────────────────────────────

local function page(name: string): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Visible = false
	frame.Size = UDim2.fromOffset(440, 580)
	frame.Position = UDim2.new(0, 16, 0, 16)
	frame.BackgroundColor3 = INK
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = AMBER_DIM
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = gui
	corner(frame, 18)
	stroke(frame, AMBER_DIM, 1)
	listLayout(frame, 10)
	padding(frame, 16, 16, 16, 16)
	return frame
end

-- Note (home panel)
local note = Instance.new("Frame")
note.Name = "Note"
note.Size = UDim2.fromOffset(380, 140)
note.Position = UDim2.new(0, 16, 0, 16)
note.BackgroundColor3 = INK
note.BackgroundTransparency = 0.05
note.Parent = gui
corner(note, 18)
stroke(note, AMBER_DIM, 1)
listLayout(note, 8)
padding(note, 14, 14, 14, 14)
label(note, "CODAG.0", 13, AMBER, FONT_TITLE)
label(note, "Pick up a colored pile, then drag it onto Shell, Wrap, or Air.", 17, PAPER, FONT_BOLD)
local openBuild = button(note, "Build the suit", true)

local workshop = page("Workshop")
local planets = page("Planets")
local difficulty = page("Difficulty")
local debrief = page("Debrief")

-- HUD (mission overlay)
local hud = Instance.new("Frame")
hud.Name = "Hud"
hud.Visible = false
hud.Size = UDim2.fromOffset(340, 0)
hud.AutomaticSize = Enum.AutomaticSize.Y
hud.Position = UDim2.new(0, 16, 0, 16)
hud.BackgroundColor3 = INK
hud.BackgroundTransparency = 0.1
hud.Parent = gui
corner(hud, 18)
stroke(hud, AMBER_DIM, 1)
listLayout(hud, 6)
padding(hud, 14, 14, 14, 14)

-- ── Clear / show ─────────────────────────────────────────────────────────

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

local function show(which: ScrollingFrame?)
	workshop.Visible = which == workshop
	planets.Visible = which == planets
	difficulty.Visible = which == difficulty
	debrief.Visible = which == debrief
	note.Visible = which == nil and hud.Visible == false
end

-- ── State ────────────────────────────────────────────────────────────────

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

-- ── Workshop ─────────────────────────────────────────────────────────────

local function renderWorkshop()
	clear(workshop)

	-- Header
	label(workshop, "CODAG.0", 13, AMBER, FONT_TITLE)
	label(workshop, "Build the suit.", 26, PAPER, FONT_BOLD)
	label(workshop, "Shell holds air in. Wrap slows the heat. Air is the bottles.\nYou never type a number. The mass comes from the physics.", 14, PAPER_DIM)

	divider(workshop)

	-- Status hint
	if state.hint ~= "" then
		local hintCard = card(workshop, PANEL)
		label(hintCard, state.hint, 15, AMBER)
	end
	if state.problem ~= "" then
		local probCard = card(workshop, Color3.fromRGB(50, 25, 20))
		label(probCard, state.problem, 15, RED)
	end

	-- Inventory
	label(workshop, "YOUR MATERIALS", 11, PAPER_DIM, FONT_BOLD)
	local hasAny = false
	for _, material in Catalog.MATERIALS do
		if (state.inventory[material.id] or 0) > 0 then
			hasAny = true
			local isPicked = picked == material.id
			local matBtn = button(workshop, (if isPicked then "> " else "") .. material.name, isPicked)
			matBtn.MouseButton1Click:Connect(function()
				picked = material.id
				renderWorkshop()
			end)
		end
	end
	if not hasAny then
		label(workshop, "Walk around and pick up the piles first.", 14, PAPER_DIM)
	end

	divider(workshop)

	-- Slots
	label(workshop, "SUIT SLOTS", 11, PAPER_DIM, FONT_BOLD)
	local design = designFrom(state.design)
	local slots = {
		{ id = "shell", title = "Shell", filled = materialName(design.shellMaterialId), icon = "[=]" },
		{ id = "wrap",  title = "Wrap",  filled = materialName(design.insulationMaterialId), icon = "{ }" },
		{ id = "air",   title = "Air",   filled = if design.oxygenKg > 0 then string.format("%.1f kg packed", design.oxygenKg) else "Empty", icon = "(O)" },
	}
	for _, slot in slots do
		local slotCard = card(workshop)
		label(slotCard, slot.icon .. "  " .. slot.title, 16, PAPER, FONT_BOLD)
		label(slotCard, slot.filled, 14, if slot.filled == "Empty" then PAPER_DIM else AMBER)
		local slotBtn = button(slotCard, if picked then "Place here" else "Pick a material first", picked ~= nil)
		slotBtn.Active = picked ~= nil
		slotBtn.MouseButton1Click:Connect(function()
			if picked ~= nil then
				Place:FireServer(picked, slot.id)
				picked = nil
			end
		end)
		if slot.filled ~= "Empty" then
			local off = Instance.new("TextButton")
			off.Size = UDim2.new(1, 0, 0, 30)
			off.BackgroundTransparency = 1
			off.TextColor3 = RED
			off.Font = FONT_BODY
			off.TextSize = 13
			off.Text = "Remove"
			off.Parent = slotCard
			off.MouseButton1Click:Connect(function()
				ClearSlot:FireServer(slot.id)
			end)
		end
	end

	divider(workshop)

	-- Suit size
	label(workshop, "SUIT SIZE", 11, PAPER_DIM, FONT_BOLD)
	local sizeRow = Instance.new("Frame")
	sizeRow.BackgroundTransparency = 1
	sizeRow.Size = UDim2.new(1, 0, 0, 42)
	sizeRow.Parent = workshop
	local sizeLayout = Instance.new("UIListLayout")
	sizeLayout.FillDirection = Enum.FillDirection.Horizontal
	sizeLayout.Padding = UDim.new(0, 6)
	sizeLayout.Parent = sizeRow
	for _, size in { { "fits", "Fits me" }, { "bigger", "Bigger" }, { "bulky", "Heavy" } } do
		local sizeButton = Instance.new("TextButton")
		sizeButton.Size = UDim2.new(0.32, 0, 1, 0)
		sizeButton.BackgroundColor3 = PANEL_HI
		sizeButton.TextColor3 = PAPER
		sizeButton.Font = FONT_BOLD
		sizeButton.TextSize = 14
		sizeButton.Text = size[2]
		sizeButton.AutoButtonColor = true
		sizeButton.Parent = sizeRow
		corner(sizeButton, 8)
		sizeButton.MouseButton1Click:Connect(function()
			SetSize:FireServer(size[1])
		end)
	end

	divider(workshop)

	-- Preview
	label(workshop, "PREVIEW", 11, PAPER_DIM, FONT_BOLD)
	local check = Catalog.difficultyById("normal").minSafetyFactor
	local moon = Catalog.planetById("moon")
	local previewCard = card(workshop)
	label(previewCard, "Moon test (Normal)", 14, PAPER, FONT_BOLD)
	label(previewCard, Survival.kidResult(design, moon, check, "hot"), 13, PAPER_DIM)
	label(previewCard, Survival.kidResult(design, moon, check, "cold"), 13, PAPER_DIM)

	-- Go button
	local go = button(workshop, "Try this suit on a planet", true)
	go.Active = state.problem == ""
	go.AutoButtonColor = state.problem == ""
	if state.problem ~= "" then
		go.BackgroundColor3 = PANEL
		go.TextColor3 = PAPER_DIM
	end
	go.MouseButton1Click:Connect(function()
		if state.problem == "" then
			show(planets)
			renderPlanets()
		end
	end)
end

openBuild.MouseButton1Click:Connect(function()
	show(workshop)
	if state ~= nil then
		renderWorkshop()
	end
end)

-- ── Planets ──────────────────────────────────────────────────────────────

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

	label(planets, "CODAG.0", 13, AMBER, FONT_TITLE)
	label(planets, "Same suit.\nDifferent planet.", 26, PAPER, FONT_BOLD)
	label(planets, "The planet numbers are from NASA fact sheets. They do not change.", 14, PAPER_DIM)

	divider(planets)

	local design = designFrom(state.design)
	local check = Catalog.difficultyById("normal").minSafetyFactor
	for _, planetId in Sources.DESTINATION_ORDER do
		local planet = Catalog.planetById(planetId)
		local open = isOpen(planetId)

		local planetCard = card(planets, if open then INK_MID else PANEL)
		label(planetCard, planet.name, 20, if open then PAPER else PAPER_DIM, FONT_BOLD)
		label(planetCard, string.format("g = %.2f m/s²", planet.gravityMs2), 12, AMBER, FONT_MONO)
		label(planetCard, Survival.kidResult(design, planet, check, "hot"), 13, PAPER_DIM)

		if open then
			local choose = button(planetCard, "Select", true)
			choose.MouseButton1Click:Connect(function()
				chosenPlanet = planetId
				show(difficulty)
				renderDifficulty()
			end)
		else
			label(planetCard, "Locked. Clear the previous planet first.", 12, PAPER_DIM)
		end
	end

	divider(planets)

	local back = button(planets, "Back to the suit", false)
	back.MouseButton1Click:Connect(function()
		show(workshop)
		renderWorkshop()
	end)
end

-- ── Difficulty ───────────────────────────────────────────────────────────

function renderDifficulty()
	clear(difficulty)
	local planet = Catalog.planetById(chosenPlanet)

	label(difficulty, "CODAG.0", 13, AMBER, FONT_TITLE)
	label(difficulty, planet.name, 28, PAPER, FONT_BOLD)
	label(difficulty, planet.referencePressure.transcribedFrom, 13, PAPER_DIM)

	divider(difficulty)

	label(difficulty, "Difficulty changes the rules, not the planet.", 15, PAPER)

	for _, profile in Catalog.DIFFICULTIES do
		local diffCard = card(difficulty)
		label(diffCard, profile.label, 18, PAPER, FONT_BOLD)
		local pick = button(diffCard, "Choose " .. profile.label, profile.id == "normal")
		pick.MouseButton1Click:Connect(function()
			clear(difficulty)
			label(difficulty, planet.name, 28, PAPER, FONT_BOLD)
			label(difficulty, profile.label .. " difficulty", 14, AMBER)

			divider(difficulty)

			local hot = Survival.exposure(planet, "hot")
			local cold = Survival.exposure(planet, "cold")

			label(difficulty, "CHOOSE A SIDE", 11, PAPER_DIM, FONT_BOLD)

			local hotCard = card(difficulty, Color3.fromRGB(50, 30, 20))
			label(hotCard, string.format("Hot side   %.0f °C", Survival.celsius(hot.kelvin)), 18, AMBER, FONT_BOLD)
			label(hotCard, hot.transcribedFrom, 12, PAPER_DIM)
			local hotBtn = button(hotCard, "Land on the hot side", true)
			hotBtn.MouseButton1Click:Connect(function()
				Depart:FireServer(planet.id, profile.id, "hot")
				show(nil)
			end)

			local coldCard = card(difficulty, Color3.fromRGB(20, 30, 50))
			label(coldCard, string.format("Cold side   %.0f °C", Survival.celsius(cold.kelvin)), 18, Color3.fromRGB(140, 180, 220), FONT_BOLD)
			label(coldCard, cold.transcribedFrom, 12, PAPER_DIM)
			local coldBtn = button(coldCard, "Land on the cold side", true)
			coldBtn.BackgroundColor3 = Color3.fromRGB(100, 160, 200)
			coldBtn.MouseButton1Click:Connect(function()
				Depart:FireServer(planet.id, profile.id, "cold")
				show(nil)
			end)
		end)
	end

	divider(difficulty)

	local back = button(difficulty, "Back", false)
	back.MouseButton1Click:Connect(function()
		show(planets)
		renderPlanets()
	end)
end

-- ── HUD (mission) ────────────────────────────────────────────────────────

local hudTitle = label(hud, "CODAG.0", 12, AMBER, FONT_TITLE)
local hudPlanet = label(hud, "", 22, PAPER, FONT_BOLD)
local hudClock = label(hud, "0:00 / 20:00", 24, PAPER, FONT_MONO)
local hudAirHolder = Instance.new("Frame")
hudAirHolder.BackgroundTransparency = 1
hudAirHolder.Size = UDim2.new(1, 0, 0, 32)
hudAirHolder.Parent = hud
local hudCoreHolder = Instance.new("Frame")
hudCoreHolder.BackgroundTransparency = 1
hudCoreHolder.Size = UDim2.new(1, 0, 0, 32)
hudCoreHolder.Parent = hud
local hudOxygenHolder = Instance.new("Frame")
hudOxygenHolder.BackgroundTransparency = 1
hudOxygenHolder.Size = UDim2.new(1, 0, 0, 32)
hudOxygenHolder.Parent = hud
local hudDeath = label(hud, "", 16, RED, FONT_BOLD)
local died = button(hud, "You died", true)
died.Visible = false
died.MouseButton1Click:Connect(function()
	hud.Visible = false
	debrief.Visible = true
end)
local abortBtn = button(hud, "Abort mission", false)
abortBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 25)
abortBtn.TextColor3 = RED
abortBtn.MouseButton1Click:Connect(function()
	Abort:FireServer()
	show(workshop)
	if state then renderWorkshop() end
end)

local function clock(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local function renderHud()
	local inMission = player:GetAttribute("InMission") == true
	hud.Visible = inMission
	abortBtn.Visible = inMission
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
	hudPlanet.Text = planetName
	hudTitle.Text = string.upper(side) .. " SIDE  ·  " .. string.upper(mode)
	hudClock.Text = clock(player:GetAttribute("MissionClock") or 0) .. " / 20:00"

	-- Air held meter
	local held = player:GetAttribute("AirHeld") or 100
	for _, child in hudAirHolder:GetChildren() do child:Destroy() end
	meter(hudAirHolder,
		if held >= 100 then "AIR SEALED" else string.format("AIR LEAKING  %.0f%%", held),
		held,
		if held >= 100 then GREEN else AMBER)

	-- Core temp meter
	local coreC = player:GetAttribute("CoreC") or 37
	local corePct = math.clamp(((coreC - 30) / 15) * 100, 0, 100)
	for _, child in hudCoreHolder:GetChildren() do child:Destroy() end
	meter(hudCoreHolder,
		string.format("CORE  %.1f °C", coreC),
		corePct,
		if coreC < 35 or coreC > 40 then RED else GREEN)

	-- Oxygen meter
	local oxyKg = player:GetAttribute("OxygenKg") or 0
	local oxyPct = math.clamp(oxyKg / 2 * 100, 0, 100)
	for _, child in hudOxygenHolder:GetChildren() do child:Destroy() end
	meter(hudOxygenHolder,
		string.format("O₂  %.3f kg", oxyKg),
		oxyPct,
		if oxyPct < 20 then RED else GREEN)

	local alive = player:GetAttribute("Alive") ~= false
	local cause = player:GetAttribute("CauseTitle") or ""
	hudDeath.Text = if alive then "" else cause
	died.Visible = not alive
	died.Text = if alive then "You held on" else "You died"
	abortBtn.Visible = alive
end

player:GetAttributeChangedSignal("MissionClock"):Connect(renderHud)
player:GetAttributeChangedSignal("InMission"):Connect(renderHud)
player:GetAttributeChangedSignal("Alive"):Connect(renderHud)
player:GetAttributeChangedSignal("CoreC"):Connect(renderHud)
player:GetAttributeChangedSignal("AirHeld"):Connect(renderHud)

-- ── State sync ───────────────────────────────────────────────────────────

State.OnClientEvent:Connect(function(nextState)
	state = nextState
	if debrief.Visible or hud.Visible or planets.Visible or difficulty.Visible then
		return
	end
	if workshop.Visible then
		renderWorkshop()
	end
end)

-- ── Debrief ──────────────────────────────────────────────────────────────

Debrief.OnClientEvent:Connect(function(report)
	clear(debrief)
	hud.Visible = false
	show(debrief)

	label(debrief, "CODAG.0", 13, AMBER, FONT_TITLE)

	if report.survived then
		label(debrief, "You survived.", 28, GREEN, FONT_BOLD)
	else
		label(debrief, "You died.", 28, RED, FONT_BOLD)
	end

	label(debrief, report.title, 18, PAPER, FONT_BOLD)
	label(debrief, report.detail, 15, PAPER_DIM)

	divider(debrief)

	label(debrief, "NASA FACT SHEET DATA", 11, AMBER, FONT_BOLD)
	label(debrief, "These lines were retrieved from the fact sheets. The physics decided pass or fail. No model filled in a number.", 13, PAPER_DIM)

	for _, fact in report.facts do
		local factCard = card(debrief)
		label(factCard, fact.text, 14, PAPER)
		label(factCard, fact.body .. " Fact Sheet", 12, AMBER, FONT_BOLD)
		label(factCard, fact.sourceUrl, 11, AMBER_DIM, FONT_MONO)
	end

	divider(debrief)

	local again = button(debrief, "Try again with same suit", false)
	again.MouseButton1Click:Connect(function()
		show(difficulty)
		renderDifficulty()
	end)

	local suit = button(debrief, "Change the suit", false)
	suit.MouseButton1Click:Connect(function()
		show(workshop)
		renderWorkshop()
	end)

	local earth = button(debrief, "Back to Earth", true)
	earth.MouseButton1Click:Connect(function()
		Abort:FireServer()
		show(workshop)
		renderWorkshop()
	end)
end)

-- ── Init ─────────────────────────────────────────────────────────────────

show(nil)
event("Ready"):FireServer()
