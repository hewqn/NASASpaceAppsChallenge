local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

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
local DebriefEvent = event("Debrief")

-- ── Design tokens ────────────────────────────────────────────────────────

local BG         = Color3.fromRGB(12, 12, 16)
local BG_PANEL   = Color3.fromRGB(18, 18, 24)
local BG_CARD    = Color3.fromRGB(26, 26, 34)
local BG_CARD_HI = Color3.fromRGB(36, 36, 46)
local TEXT_WHITE  = Color3.fromRGB(230, 230, 235)
local TEXT_DIM    = Color3.fromRGB(140, 140, 150)
local TEXT_FAINT  = Color3.fromRGB(90, 90, 100)
local ACCENT      = Color3.fromRGB(255, 180, 60)   -- warm amber
local ACCENT_DIM  = Color3.fromRGB(180, 120, 40)
local DANGER       = Color3.fromRGB(220, 70, 60)
local SUCCESS      = Color3.fromRGB(70, 200, 110)
local COOL         = Color3.fromRGB(100, 170, 230)

local FONT_DISPLAY = Enum.Font.GothamBlack
local FONT_TITLE   = Enum.Font.GothamBold
local FONT_BODY    = Enum.Font.Gotham
local FONT_MONO    = Enum.Font.Code

-- ── ScreenGui ────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "CODAG"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- ── UI helpers ───────────────────────────────────────────────────────────

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	local ui = Instance.new("UIStroke")
	ui.Color = color
	ui.Thickness = thickness
	ui.Transparency = transparency or 0.7
	ui.Parent = parent
end

local function pad(parent: Instance, top: number, bottom: number, left: number, right: number)
	local ui = Instance.new("UIPadding")
	ui.PaddingTop = UDim.new(0, top)
	ui.PaddingBottom = UDim.new(0, bottom)
	ui.PaddingLeft = UDim.new(0, left)
	ui.PaddingRight = UDim.new(0, right)
	ui.Parent = parent
end

local function listLayout(parent: Instance, gap: number, dir: Enum.FillDirection?)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = dir or Enum.FillDirection.Vertical
	layout.Parent = parent
	return layout
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
	line.BackgroundColor3 = TEXT_FAINT
	line.BackgroundTransparency = 0.85
	line.BorderSizePixel = 0
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Parent = parent
end

local function btn(parent: Instance, text: string, primary: boolean): TextButton
	local item = Instance.new("TextButton")
	item.Size = UDim2.new(1, 0, 0, 50)
	item.BackgroundColor3 = if primary then ACCENT else BG_CARD
	item.TextColor3 = if primary then BG else TEXT_WHITE
	item.Font = FONT_TITLE
	item.TextSize = 16
	item.Text = text
	item.AutoButtonColor = true
	item.Parent = parent
	corner(item, 12)
	if not primary then
		stroke(item, TEXT_FAINT, 1)
	end
	return item
end

local function card(parent: Instance, highlight: boolean?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = if highlight then BG_CARD_HI else BG_CARD
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	corner(frame, 12)
	pad(frame, 14, 14, 14, 14)
	listLayout(frame, 6)
	return frame
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

-- ── Meter bar ────────────────────────────────────────────────────────────

local function meter(parent: Instance, labelText: string, pct: number, barColor: Color3): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 30)
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Font = FONT_MONO
	lbl.TextSize = 12
	lbl.TextColor3 = TEXT_DIM
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText
	lbl.Size = UDim2.new(1, 0, 0, 14)
	lbl.Parent = row

	local track = Instance.new("Frame")
	track.BackgroundColor3 = BG_PANEL
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0, 20)
	track.Parent = row
	corner(track, 3)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = barColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(math.clamp(pct / 100, 0, 1), 0, 1, 0)
	fill.Parent = track
	corner(fill, 3)

	return row
end

-- ── Panels ───────────────────────────────────────────────────────────────

local function page(name: string): ScrollingFrame
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Visible = false
	frame.Size = UDim2.fromOffset(420, 600)
	frame.Position = UDim2.new(0, 20, 0, 60)
	frame.BackgroundColor3 = BG_PANEL
	frame.BackgroundTransparency = 0.02
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 3
	frame.ScrollBarImageColor3 = ACCENT_DIM
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = gui
	corner(frame, 16)
	stroke(frame, ACCENT_DIM, 1, 0.8)
	listLayout(frame, 10)
	pad(frame, 20, 20, 20, 20)
	return frame
end

-- ── Intro screen ─────────────────────────────────────────────────────────

local introFrame = Instance.new("Frame")
introFrame.Name = "Intro"
introFrame.Size = UDim2.fromScale(1, 1)
introFrame.BackgroundColor3 = BG
introFrame.BackgroundTransparency = 0
introFrame.BorderSizePixel = 0
introFrame.ZIndex = 10
introFrame.Parent = gui

local introContent = Instance.new("Frame")
introContent.BackgroundTransparency = 1
introContent.Size = UDim2.fromOffset(500, 400)
introContent.Position = UDim2.new(0.5, -250, 0.5, -200)
introContent.Parent = introFrame
listLayout(introContent, 16)

local introTitle = label(introContent, "PLANETFALL", 42, ACCENT, FONT_DISPLAY)
introTitle.TextXAlignment = Enum.TextXAlignment.Center
local introSub = label(introContent, "A CODAG.0 MISSION", 14, TEXT_FAINT, FONT_TITLE)
introSub.TextXAlignment = Enum.TextXAlignment.Center

local introLine1 = label(introContent, "", 17, TEXT_DIM, FONT_BODY)
introLine1.TextXAlignment = Enum.TextXAlignment.Center
local introLine2 = label(introContent, "", 17, TEXT_DIM, FONT_BODY)
introLine2.TextXAlignment = Enum.TextXAlignment.Center
local introLine3 = label(introContent, "", 17, TEXT_DIM, FONT_BODY)
introLine3.TextXAlignment = Enum.TextXAlignment.Center
local introLine4 = label(introContent, "", 15, ACCENT, FONT_TITLE)
introLine4.TextXAlignment = Enum.TextXAlignment.Center

local introDismiss = Instance.new("TextButton")
introDismiss.Size = UDim2.new(0, 200, 0, 50)
introDismiss.BackgroundColor3 = ACCENT
introDismiss.TextColor3 = BG
introDismiss.Font = FONT_TITLE
introDismiss.TextSize = 16
introDismiss.Text = "BEGIN"
introDismiss.Visible = false
introDismiss.Parent = introContent
corner(introDismiss, 12)
-- center the button
introDismiss.AnchorPoint = Vector2.new(0.5, 0)
introDismiss.Position = UDim2.new(0.5, 0, 0, 0)

local introShown = false

local function typewrite(lbl: TextLabel, text: string, speed: number?)
	local delay = speed or 0.03
	lbl.Text = ""
	for i = 1, #text do
		lbl.Text = string.sub(text, 1, i)
		task.wait(delay)
	end
end

local function showIntro()
	if introShown then return end
	introShown = true
	introFrame.Visible = true

	task.spawn(function()
		task.wait(1)
		typewrite(introLine1, "Every planet in our solar system is real.")
		task.wait(0.5)
		typewrite(introLine2, "The gravity, the pressure, the temperature. All from NASA.")
		task.wait(0.5)
		typewrite(introLine3, "Build a suit from raw materials. Survive 20 minutes.")
		task.wait(0.8)
		typewrite(introLine4, "The physics decides if you live or die.", 0.04)
		task.wait(0.5)
		introDismiss.Visible = true
		-- fade in button
		introDismiss.BackgroundTransparency = 1
		introDismiss.TextTransparency = 1
		TweenService:Create(introDismiss, TweenInfo.new(0.5), {
			BackgroundTransparency = 0,
			TextTransparency = 0,
		}):Play()
	end)
end

introDismiss.MouseButton1Click:Connect(function()
	-- fade out intro
	TweenService:Create(introFrame, TweenInfo.new(0.6), {
		BackgroundTransparency = 1,
	}):Play()
	for _, child in introContent:GetChildren() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end
	TweenService:Create(introDismiss, TweenInfo.new(0.3), {
		BackgroundTransparency = 1,
		TextTransparency = 1,
	}):Play()
	task.wait(0.7)
	introFrame.Visible = false
end)

-- ── Objective tracker ────────────────────────────────────────────────────

local objective = Instance.new("Frame")
objective.Name = "Objective"
objective.Size = UDim2.fromOffset(350, 0)
objective.AutomaticSize = Enum.AutomaticSize.Y
objective.Position = UDim2.new(1, -370, 0, 60)
objective.BackgroundColor3 = BG_PANEL
objective.BackgroundTransparency = 0.15
objective.BorderSizePixel = 0
objective.Parent = gui
corner(objective, 12)
pad(objective, 12, 12, 14, 14)
listLayout(objective, 6)

local objTag = label(objective, "OBJECTIVE", 10, ACCENT, FONT_TITLE)
local objText = label(objective, "Pick up materials from the yard. Build a survival suit.", 15, TEXT_WHITE, FONT_BODY)
local objHint = label(objective, "", 13, TEXT_DIM, FONT_BODY)

local function setObjective(text: string, hint: string?)
	objText.Text = text
	objHint.Text = hint or ""
	objHint.Visible = hint ~= nil and hint ~= ""
end

-- ── Note (home panel) ────────────────────────────────────────────────────

local note = Instance.new("Frame")
note.Name = "Note"
note.Size = UDim2.fromOffset(420, 0)
note.AutomaticSize = Enum.AutomaticSize.Y
note.Position = UDim2.new(0, 20, 0, 60)
note.BackgroundColor3 = BG_PANEL
note.BackgroundTransparency = 0.02
note.Parent = gui
corner(note, 16)
stroke(note, ACCENT_DIM, 1, 0.8)
listLayout(note, 10)
pad(note, 20, 20, 20, 20)
label(note, "MISSION PREP", 11, ACCENT, FONT_TITLE)
label(note, "Build a survival suit", 24, TEXT_WHITE, FONT_DISPLAY)
label(note, "Collect materials from the yard, then assemble shell, insulation, and oxygen on the build pads.", 14, TEXT_DIM)
divider(note)
local noteHint = label(note, "Walk to the glowing pads to collect materials.", 14, ACCENT)
local openBuild = btn(note, "Open the workshop", true)

local workshop = page("Workshop")
local planets = page("Planets")
local difficulty = page("Difficulty")
local debrief = page("Debrief")

-- HUD (mission overlay)
local hud = Instance.new("Frame")
hud.Name = "Hud"
hud.Visible = false
hud.Size = UDim2.fromOffset(300, 0)
hud.AutomaticSize = Enum.AutomaticSize.Y
hud.Position = UDim2.new(0, 20, 0, 60)
hud.BackgroundColor3 = BG_PANEL
hud.BackgroundTransparency = 0.05
hud.Parent = gui
corner(hud, 14)
stroke(hud, DANGER, 1, 0.7)
listLayout(hud, 8)
pad(hud, 16, 16, 16, 16)

-- ── Clear / show ─────────────────────────────────────────────────────────

local function show(which: ScrollingFrame?)
	workshop.Visible = which == workshop
	planets.Visible = which == planets
	difficulty.Visible = which == difficulty
	debrief.Visible = which == debrief
	note.Visible = which == nil and hud.Visible == false
	objective.Visible = which == nil or which == workshop
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
		return "empty"
	end
	return Catalog.materialById(id).name
end

-- ── Workshop ─────────────────────────────────────────────────────────────

local function renderWorkshop()
	clear(workshop)

	label(workshop, "MISSION PREP", 11, ACCENT, FONT_TITLE)
	label(workshop, "Suit assembly", 26, TEXT_WHITE, FONT_DISPLAY)
	label(workshop, "Shell holds pressure. Wrap slows heat transfer. Air is your oxygen supply. The mass and thermal properties come from real physics.", 14, TEXT_DIM)

	divider(workshop)

	-- Status
	if state.hint ~= "" then
		local hintCard = card(workshop)
		label(hintCard, state.hint, 14, ACCENT)
	end
	if state.problem ~= "" then
		local probCard = card(workshop, true)
		label(probCard, "WARNING", 10, DANGER, FONT_TITLE)
		label(probCard, state.problem, 14, DANGER)
	end

	-- Inventory
	label(workshop, "COLLECTED MATERIALS", 10, TEXT_FAINT, FONT_TITLE)
	local hasAny = false
	for _, material in Catalog.MATERIALS do
		if (state.inventory[material.id] or 0) > 0 then
			hasAny = true
			local isPicked = picked == material.id
			local matCard = card(workshop, isPicked)
			if isPicked then
				stroke(matCard, ACCENT, 1, 0.4)
			end
			local matRow = Instance.new("Frame")
			matRow.BackgroundTransparency = 1
			matRow.Size = UDim2.new(1, 0, 0, 0)
			matRow.AutomaticSize = Enum.AutomaticSize.Y
			matRow.Parent = matCard
			listLayout(matRow, 2)
			label(matRow, material.name, 16, if isPicked then ACCENT else TEXT_WHITE, FONT_TITLE)
			label(matRow, material.blurb, 12, TEXT_DIM)
			label(matRow, string.format("%.0f kg collected", material.foundKg), 11, TEXT_FAINT, FONT_MONO)

			local selectBtn = Instance.new("TextButton")
			selectBtn.Size = UDim2.new(1, 0, 0, 36)
			selectBtn.BackgroundColor3 = if isPicked then ACCENT else BG_CARD_HI
			selectBtn.TextColor3 = if isPicked then BG else TEXT_WHITE
			selectBtn.Font = FONT_TITLE
			selectBtn.TextSize = 14
			selectBtn.Text = if isPicked then "SELECTED" else "Select"
			selectBtn.AutoButtonColor = true
			selectBtn.Parent = matCard
			corner(selectBtn, 8)
			selectBtn.MouseButton1Click:Connect(function()
				picked = material.id
				renderWorkshop()
			end)
		end
	end
	if not hasAny then
		local emptyCard = card(workshop)
		label(emptyCard, "No materials collected yet", 14, TEXT_DIM)
		label(emptyCard, "Walk to the glowing pads in the yard and interact with them.", 13, TEXT_FAINT)
	end

	divider(workshop)

	-- Slots
	label(workshop, "SUIT CONFIGURATION", 10, TEXT_FAINT, FONT_TITLE)
	local design = designFrom(state.design)
	local slots = {
		{ id = "shell", title = "Shell", subtitle = "Pressure containment", filled = materialName(design.shellMaterialId) },
		{ id = "wrap",  title = "Insulation", subtitle = "Thermal barrier", filled = materialName(design.insulationMaterialId) },
		{ id = "air",   title = "Oxygen", subtitle = "Breathing supply", filled = if design.oxygenKg > 0 then string.format("%.1f kg loaded", design.oxygenKg) else "empty" },
	}
	for _, slot in slots do
		local slotCard = card(workshop, slot.filled ~= "empty")
		local isEmpty = slot.filled == "empty"

		label(slotCard, slot.title, 16, if isEmpty then TEXT_DIM else TEXT_WHITE, FONT_TITLE)
		label(slotCard, slot.subtitle, 11, TEXT_FAINT)
		label(slotCard, if isEmpty then "Nothing assigned" else slot.filled, 13, if isEmpty then TEXT_FAINT else ACCENT, FONT_MONO)

		if picked ~= nil then
			local placeBtn = btn(slotCard, "Place " .. Catalog.materialById(picked).name .. " here", true)
			placeBtn.Size = UDim2.new(1, 0, 0, 40)
			placeBtn.TextSize = 14
			placeBtn.MouseButton1Click:Connect(function()
				Place:FireServer(picked, slot.id)
				picked = nil
			end)
		end

		if not isEmpty then
			local removeBtn = Instance.new("TextButton")
			removeBtn.Size = UDim2.new(1, 0, 0, 28)
			removeBtn.BackgroundTransparency = 1
			removeBtn.TextColor3 = DANGER
			removeBtn.Font = FONT_BODY
			removeBtn.TextSize = 12
			removeBtn.Text = "Remove"
			removeBtn.Parent = slotCard
			removeBtn.MouseButton1Click:Connect(function()
				ClearSlot:FireServer(slot.id)
			end)
		end
	end

	divider(workshop)

	-- Suit size
	label(workshop, "SUIT SIZE", 10, TEXT_FAINT, FONT_TITLE)
	local sizeRow = Instance.new("Frame")
	sizeRow.BackgroundTransparency = 1
	sizeRow.Size = UDim2.new(1, 0, 0, 42)
	sizeRow.Parent = workshop
	local sizeLayout = Instance.new("UIListLayout")
	sizeLayout.FillDirection = Enum.FillDirection.Horizontal
	sizeLayout.Padding = UDim.new(0, 6)
	sizeLayout.Parent = sizeRow
	for _, size in { { "fits", "Standard" }, { "bigger", "Large" }, { "bulky", "Heavy" } } do
		local sizeButton = Instance.new("TextButton")
		sizeButton.Size = UDim2.new(0.32, 0, 1, 0)
		sizeButton.BackgroundColor3 = BG_CARD
		sizeButton.TextColor3 = TEXT_WHITE
		sizeButton.Font = FONT_TITLE
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
	label(workshop, "SURVIVAL PREVIEW", 10, TEXT_FAINT, FONT_TITLE)
	local check = Catalog.difficultyById("normal").minSafetyFactor
	local moon = Catalog.planetById("moon")
	local previewCard = card(workshop)
	label(previewCard, "Moon (Normal difficulty)", 14, TEXT_WHITE, FONT_TITLE)
	label(previewCard, Survival.kidResult(design, moon, check, "hot"), 12, TEXT_DIM, FONT_MONO)
	label(previewCard, Survival.kidResult(design, moon, check, "cold"), 12, TEXT_DIM, FONT_MONO)

	-- Launch
	local ready = state.problem == ""
	local go = btn(workshop, if ready then "SELECT MISSION" else "Fix warnings first", ready)
	if not ready then
		go.BackgroundColor3 = BG_CARD
		go.TextColor3 = TEXT_FAINT
		go.Active = false
		go.AutoButtonColor = false
	end
	go.MouseButton1Click:Connect(function()
		if ready then
			show(planets)
			renderPlanets()
		end
	end)

	-- Update objective
	if not hasAny then
		setObjective("Collect materials from the yard.", "Walk to the glowing pads nearby.")
	elseif state.problem ~= "" then
		setObjective("Complete your suit build.", state.problem)
	else
		setObjective("Suit ready. Select a mission.", "Open the workshop and choose SELECT MISSION.")
	end
end

openBuild.MouseButton1Click:Connect(function()
	show(workshop)
	if state ~= nil then
		renderWorkshop()
	end
end)

-- ── Planets (mission select) ────────────────────────────────────────────

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

	label(planets, "MISSION SELECT", 11, ACCENT, FONT_TITLE)
	label(planets, "Choose your planet", 26, TEXT_WHITE, FONT_DISPLAY)
	label(planets, "All planet data comes from NASA NSSDC fact sheets. The numbers below are real. Your suit either handles them or it doesn't.", 14, TEXT_DIM)

	divider(planets)

	local design = designFrom(state.design)
	local check = Catalog.difficultyById("normal").minSafetyFactor
	for _, planetId in Sources.DESTINATION_ORDER do
		local planet = Catalog.planetById(planetId)
		local open = isOpen(planetId)
		local cleared = false
		for _, id in state.clears do
			if id == planetId then cleared = true end
		end

		local planetCard = card(planets, open)
		if cleared then
			stroke(planetCard, SUCCESS, 1, 0.5)
		end

		-- Planet header
		local header = Instance.new("Frame")
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0, 0)
		header.AutomaticSize = Enum.AutomaticSize.Y
		header.Parent = planetCard
		listLayout(header, 2)

		local nameRow = Instance.new("Frame")
		nameRow.BackgroundTransparency = 1
		nameRow.Size = UDim2.new(1, 0, 0, 28)
		nameRow.Parent = header

		local planetName = Instance.new("TextLabel")
		planetName.BackgroundTransparency = 1
		planetName.Font = FONT_TITLE
		planetName.TextSize = 20
		planetName.TextColor3 = if open then TEXT_WHITE else TEXT_FAINT
		planetName.TextXAlignment = Enum.TextXAlignment.Left
		planetName.Text = planet.name
		planetName.Size = UDim2.new(0.7, 0, 1, 0)
		planetName.Parent = nameRow

		if cleared then
			local badge = Instance.new("TextLabel")
			badge.BackgroundTransparency = 1
			badge.Font = FONT_TITLE
			badge.TextSize = 12
			badge.TextColor3 = SUCCESS
			badge.TextXAlignment = Enum.TextXAlignment.Right
			badge.Text = "SURVIVED"
			badge.Size = UDim2.new(0.3, 0, 1, 0)
			badge.Parent = nameRow
		end

		-- Key stats
		if open then
			label(header, string.format("Gravity: %.2f m/s\u{00B2}  |  %s", planet.gravityMs2, planet.role), 12, ACCENT, FONT_MONO)

			-- Quick survival check
			local hotResult = Survival.kidResult(design, planet, check, "hot")
			local coldResult = Survival.kidResult(design, planet, check, "cold")
			label(header, hotResult, 11, TEXT_DIM, FONT_MONO)

			local choose = btn(planetCard, "BRIEFING", true)
			choose.Size = UDim2.new(1, 0, 0, 42)
			choose.MouseButton1Click:Connect(function()
				chosenPlanet = planetId
				show(difficulty)
				renderDifficulty()
			end)
		else
			label(header, "LOCKED", 12, TEXT_FAINT, FONT_TITLE)
			label(header, "Clear the previous planet to unlock.", 12, TEXT_FAINT)
		end
	end

	divider(planets)

	local back = btn(planets, "Back to workshop", false)
	back.MouseButton1Click:Connect(function()
		show(workshop)
		renderWorkshop()
	end)
end

-- ── Difficulty (mission briefing) ────────────────────────────────────────

function renderDifficulty()
	clear(difficulty)
	local planet = Catalog.planetById(chosenPlanet)

	label(difficulty, "MISSION BRIEFING", 11, ACCENT, FONT_TITLE)
	label(difficulty, planet.name, 32, TEXT_WHITE, FONT_DISPLAY)

	-- Planet facts
	local factsCard = card(difficulty)
	label(factsCard, "PLANET DATA (NASA NSSDC)", 10, ACCENT, FONT_TITLE)
	label(factsCard, string.format("Surface gravity: %.2f m/s\u{00B2}", planet.gravityMs2), 13, TEXT_WHITE, FONT_MONO)
	label(factsCard, string.format("Surface pressure: %s", planet.referencePressure.transcribedFrom), 13, TEXT_WHITE, FONT_MONO)
	if planet.escapeVelocityMs then
		label(factsCard, string.format("Escape velocity: %.0f m/s", planet.escapeVelocityMs), 13, TEXT_DIM, FONT_MONO)
	end
	label(factsCard, planet.sourceUrl, 10, ACCENT_DIM, FONT_MONO)

	divider(difficulty)

	label(difficulty, "DIFFICULTY", 10, TEXT_FAINT, FONT_TITLE)
	label(difficulty, "Changes the rules, not the planet.", 13, TEXT_DIM)

	for _, profile in Catalog.DIFFICULTIES do
		local diffCard = card(difficulty)
		label(diffCard, profile.label, 18, TEXT_WHITE, FONT_TITLE)
		label(diffCard, profile.summary, 12, TEXT_DIM)
		local pick = btn(diffCard, "Select " .. profile.label, profile.id == "normal")
		pick.Size = UDim2.new(1, 0, 0, 42)
		pick.MouseButton1Click:Connect(function()
			clear(difficulty)
			label(difficulty, "LAUNCH", 11, DANGER, FONT_TITLE)
			label(difficulty, planet.name, 32, TEXT_WHITE, FONT_DISPLAY)
			label(difficulty, profile.label .. " difficulty", 14, ACCENT)

			divider(difficulty)

			local hot = Survival.exposure(planet, "hot")
			local cold = Survival.exposure(planet, "cold")

			label(difficulty, "LANDING ZONE", 10, TEXT_FAINT, FONT_TITLE)
			label(difficulty, "Each planet has a hot side (facing the sun) and a cold side. The temperature difference can be hundreds of degrees.", 13, TEXT_DIM)

			local hotCard = card(difficulty, true)
			stroke(hotCard, ACCENT, 1, 0.5)
			label(hotCard, "HOT SIDE", 10, ACCENT, FONT_TITLE)
			label(hotCard, string.format("%.0f \u{00B0}C", Survival.celsius(hot.kelvin)), 28, ACCENT, FONT_DISPLAY)
			label(hotCard, hot.transcribedFrom, 11, TEXT_DIM, FONT_MONO)
			local hotBtn = btn(hotCard, "DEPLOY TO HOT SIDE", true)
			hotBtn.Size = UDim2.new(1, 0, 0, 46)
			hotBtn.MouseButton1Click:Connect(function()
				Depart:FireServer(planet.id, profile.id, "hot")
				show(nil)
				setObjective("Survive 20 minutes on " .. planet.name .. ".", "Hot side. " .. profile.label .. " difficulty.")
			end)

			local coldCard = card(difficulty, true)
			stroke(coldCard, COOL, 1, 0.5)
			label(coldCard, "COLD SIDE", 10, COOL, FONT_TITLE)
			label(coldCard, string.format("%.0f \u{00B0}C", Survival.celsius(cold.kelvin)), 28, COOL, FONT_DISPLAY)
			label(coldCard, cold.transcribedFrom, 11, TEXT_DIM, FONT_MONO)
			local coldBtn = btn(coldCard, "DEPLOY TO COLD SIDE", true)
			coldBtn.BackgroundColor3 = COOL
			coldBtn.Size = UDim2.new(1, 0, 0, 46)
			coldBtn.MouseButton1Click:Connect(function()
				Depart:FireServer(planet.id, profile.id, "cold")
				show(nil)
				setObjective("Survive 20 minutes on " .. planet.name .. ".", "Cold side. " .. profile.label .. " difficulty.")
			end)
		end)
	end

	divider(difficulty)

	local back = btn(difficulty, "Back to mission select", false)
	back.MouseButton1Click:Connect(function()
		show(planets)
		renderPlanets()
	end)
end

-- ── HUD (mission) ────────────────────────────────────────────────────────

local hudTag = label(hud, "MISSION ACTIVE", 10, DANGER, FONT_TITLE)
local hudPlanet = label(hud, "", 22, TEXT_WHITE, FONT_DISPLAY)
local hudSide = label(hud, "", 12, ACCENT, FONT_TITLE)
local hudClock = label(hud, "0:00 / 20:00", 20, TEXT_WHITE, FONT_MONO)

divider(hud)

local hudAirHolder = Instance.new("Frame")
hudAirHolder.BackgroundTransparency = 1
hudAirHolder.Size = UDim2.new(1, 0, 0, 30)
hudAirHolder.Parent = hud

local hudCoreHolder = Instance.new("Frame")
hudCoreHolder.BackgroundTransparency = 1
hudCoreHolder.Size = UDim2.new(1, 0, 0, 30)
hudCoreHolder.Parent = hud

local hudOxygenHolder = Instance.new("Frame")
hudOxygenHolder.BackgroundTransparency = 1
hudOxygenHolder.Size = UDim2.new(1, 0, 0, 30)
hudOxygenHolder.Parent = hud

divider(hud)

local hudDeath = label(hud, "", 15, DANGER, FONT_TITLE)
local diedBtn = btn(hud, "VIEW DEBRIEF", true)
diedBtn.Visible = false
diedBtn.BackgroundColor3 = DANGER
diedBtn.Size = UDim2.new(1, 0, 0, 42)
diedBtn.MouseButton1Click:Connect(function()
	hud.Visible = false
	debrief.Visible = true
end)

local abortBtn = btn(hud, "Abort mission", false)
abortBtn.BackgroundColor3 = BG_CARD
abortBtn.TextColor3 = DANGER
abortBtn.Size = UDim2.new(1, 0, 0, 38)
abortBtn.TextSize = 13
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
	objective.Visible = inMission
	if inMission then
		note.Visible = false
	end
	if not inMission then
		return
	end
	show(nil)
	hud.Visible = true
	objective.Visible = true

	local planetName = player:GetAttribute("MissionPlanet") or ""
	local side = player:GetAttribute("MissionSide") or ""
	local mode = player:GetAttribute("MissionDifficulty") or ""
	hudPlanet.Text = planetName
	hudSide.Text = string.upper(side) .. " SIDE  ·  " .. string.upper(mode)
	hudClock.Text = clock(player:GetAttribute("MissionClock") or 0) .. " / 20:00"

	-- Air held
	local held = player:GetAttribute("AirHeld") or 100
	for _, child in hudAirHolder:GetChildren() do child:Destroy() end
	meter(hudAirHolder,
		if held >= 100 then "AIR  SEALED" else string.format("AIR  LEAKING  %.0f%%", held),
		held,
		if held >= 100 then SUCCESS else ACCENT)

	-- Core temp
	local coreC = player:GetAttribute("CoreC") or 37
	local corePct = math.clamp(((coreC - 30) / 15) * 100, 0, 100)
	for _, child in hudCoreHolder:GetChildren() do child:Destroy() end
	meter(hudCoreHolder,
		string.format("CORE  %.1f \u{00B0}C", coreC),
		corePct,
		if coreC < 35 or coreC > 40 then DANGER else SUCCESS)

	-- Oxygen
	local oxyKg = player:GetAttribute("OxygenKg") or 0
	local oxyPct = math.clamp(oxyKg / 2 * 100, 0, 100)
	for _, child in hudOxygenHolder:GetChildren() do child:Destroy() end
	meter(hudOxygenHolder,
		string.format("O\u{2082}  %.3f kg", oxyKg),
		oxyPct,
		if oxyPct < 20 then DANGER else SUCCESS)

	local alive = player:GetAttribute("Alive") ~= false
	local cause = player:GetAttribute("CauseTitle") or ""
	hudDeath.Text = if alive then "" else cause
	diedBtn.Visible = not alive
	diedBtn.Text = if alive then "" else "VIEW DEBRIEF"
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
	if noteHint and state.hint and state.hint ~= "" then
		noteHint.Text = state.hint
	end
	if debrief.Visible or hud.Visible or planets.Visible or difficulty.Visible then
		return
	end
	if workshop.Visible then
		renderWorkshop()
	end
end)

-- ── Debrief ──────────────────────────────────────────────────────────────

DebriefEvent.OnClientEvent:Connect(function(report)
	clear(debrief)
	hud.Visible = false
	show(debrief)

	if report.survived then
		label(debrief, "MISSION COMPLETE", 11, SUCCESS, FONT_TITLE)
		label(debrief, "You survived.", 32, SUCCESS, FONT_DISPLAY)
	else
		label(debrief, "MISSION FAILED", 11, DANGER, FONT_TITLE)
		label(debrief, "You died.", 32, DANGER, FONT_DISPLAY)
	end

	label(debrief, report.title, 18, TEXT_WHITE, FONT_TITLE)
	label(debrief, report.detail, 14, TEXT_DIM)

	divider(debrief)

	-- NASA data section
	label(debrief, "FROM THE NASA FACT SHEETS", 10, ACCENT, FONT_TITLE)
	label(debrief, "The physics that decided your fate. Every number below came from NSSDC, not from a model or an estimate.", 13, TEXT_DIM)

	for _, fact in report.facts do
		local factCard = card(debrief)
		label(factCard, fact.text, 14, TEXT_WHITE)
		label(factCard, fact.body .. " Fact Sheet", 11, ACCENT, FONT_TITLE)
		label(factCard, fact.sourceUrl, 10, ACCENT_DIM, FONT_MONO)
	end

	divider(debrief)

	local again = btn(debrief, "Try again (same suit)", false)
	again.MouseButton1Click:Connect(function()
		show(difficulty)
		renderDifficulty()
	end)

	local suit = btn(debrief, "Rebuild the suit", false)
	suit.MouseButton1Click:Connect(function()
		show(workshop)
		renderWorkshop()
	end)

	local earth = btn(debrief, "Return to Earth", true)
	earth.MouseButton1Click:Connect(function()
		Abort:FireServer()
		show(workshop)
		renderWorkshop()
	end)
end)

-- ── Init ─────────────────────────────────────────────────────────────────

show(nil)
showIntro()
event("Ready"):FireServer()
