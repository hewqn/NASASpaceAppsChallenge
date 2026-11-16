-- CODAG.0 Client UI
-- NASA-inspired space aesthetic. Freeform layered suit builder.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

print("[CODAG Client] Script started")

local shared = ReplicatedStorage:WaitForChild("CODAG", 10)
if shared == nil then
	warn("[CODAG Client] CODAG folder not found in ReplicatedStorage after 10s.")
	return
end

local ok, Catalog = pcall(require, shared.Data.Catalog)
if not ok then warn("[CODAG Client] Failed to require Catalog:", Catalog); return end
local ok2, Sources = pcall(require, shared.Data.Sources)
if not ok2 then warn("[CODAG Client] Failed to require Sources:", Sources); return end
local ok3, Survival = pcall(require, shared.Sim.Survival)
if not ok3 then warn("[CODAG Client] Failed to require Survival:", Survival); return end
local ok4, Design = pcall(require, shared.Sim.Design)
if not ok4 then warn("[CODAG Client] Failed to require Design:", Design); return end

print("[CODAG Client] Modules loaded")

local player = Players.LocalPlayer
local remotes = shared:WaitForChild("Remotes", 10)
if remotes == nil then
	warn("[CODAG Client] Remotes folder not found after 10s.")
	return
end

local function event(name: string): RemoteEvent
	local e = remotes:WaitForChild(name, 5)
	if e == nil then
		warn("[CODAG Client] RemoteEvent '" .. name .. "' not found after 5s")
	end
	return e
end

local Ready = event("Ready")
local StateEvent = event("State")
local DebriefEvent = event("Debrief")
local AddLayer = event("AddLayer")
local RemoveLayer = event("RemoveLayer")
local SetOxygen = event("SetOxygen")
local DepartEvent = event("Depart")
local AbortEvent = event("Abort")

-- ── Design Tokens (NASA / Space) ────────────────────────────────────────
local BG          = Color3.fromRGB(8, 12, 20)
local BG_PANEL    = Color3.fromRGB(12, 18, 30)
local BG_CARD     = Color3.fromRGB(18, 26, 42)
local BG_CARD_HOV = Color3.fromRGB(24, 34, 56)
local ACCENT      = Color3.fromRGB(60, 145, 255)   -- NASA blue
local ACCENT_DIM  = Color3.fromRGB(40, 100, 190)
local DANGER      = Color3.fromRGB(220, 60, 60)
local SUCCESS     = Color3.fromRGB(40, 200, 120)
local WARNING     = Color3.fromRGB(240, 180, 40)
local COOL        = Color3.fromRGB(120, 200, 255)
local TEXT_WHITE   = Color3.fromRGB(230, 235, 245)
local TEXT_DIM     = Color3.fromRGB(150, 160, 180)
local TEXT_FAINT   = Color3.fromRGB(80, 90, 110)
local BORDER       = Color3.fromRGB(40, 55, 80)

local FONT_BODY    = Font.fromEnum(Enum.Font.GothamMedium)
local FONT_TITLE   = Font.fromEnum(Enum.Font.GothamBold)
local FONT_DISPLAY = Font.fromEnum(Enum.Font.GothamBlack)
local FONT_MONO    = Font.fromEnum(Enum.Font.RobotoMono)

-- ── State ───────────────────────────────────────────────────────────────
local state = nil
local chosenPlanet = nil
local chosenDifficulty = nil
local chosenSide = nil

local gui = Instance.new("ScreenGui")
gui.Name = "CODAG"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player.PlayerGui

-- ── Mobile detection ────────────────────────────────────────────────────
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local camera = workspace.CurrentCamera
local screenWidth = camera and camera.ViewportSize.X or 1920
-- Only mobile if touch-only device with a small screen (not Studio, not tablet)
local IS_MOBILE = UserInputService.TouchEnabled
	and not UserInputService.KeyboardEnabled
	and not UserInputService.MouseEnabled
	and not GuiService:IsTenFootInterface()
	and screenWidth < 700

-- ── Helpers ─────────────────────────────────────────────────────────────
local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = color or BORDER
	s.Thickness = thick or 1
	s.Transparency = trans or 0
	s.Parent = parent
	return s
end

local function pad(parent, t, r, b, l)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, t or 12)
	p.PaddingRight = UDim.new(0, r or 12)
	p.PaddingBottom = UDim.new(0, b or 12)
	p.PaddingLeft = UDim.new(0, l or 12)
	p.Parent = parent
	return p
end

local function listLayout(parent, gap, dir)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 6)
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

local function label(parent, text, size, color, font)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, (size or 14) + 6)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.FontFace = font or FONT_BODY
	t.TextSize = size or 14
	t.TextColor3 = color or TEXT_DIM
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Text = text or ""
	t.Parent = parent
	return t
end

local function divider(parent)
	local d = Instance.new("Frame")
	d.BackgroundColor3 = BORDER
	d.BackgroundTransparency = 0.5
	d.Size = UDim2.new(1, 0, 0, 1)
	d.BorderSizePixel = 0
	d.Parent = parent
	return d
end

local function btn(parent, text, primary)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 40)
	b.AutoButtonColor = false
	b.FontFace = FONT_TITLE
	b.TextSize = 13
	b.TextColor3 = if primary then BG else TEXT_WHITE
	b.Text = string.upper(text)
	b.BackgroundColor3 = if primary then ACCENT else BG_CARD
	b.BorderSizePixel = 0
	corner(b, 6)
	if not primary then
		stroke(b, BORDER, 1, 0.3)
	end
	b.Parent = parent

	-- Hover
	local baseColor = b.BackgroundColor3
	local hoverColor = if primary then ACCENT_DIM else BG_CARD_HOV
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = baseColor}):Play()
	end)
	return b
end

local function card(parent, active)
	local c = Instance.new("Frame")
	c.Size = UDim2.new(1, 0, 0, 0)
	c.AutomaticSize = Enum.AutomaticSize.Y
	c.BackgroundColor3 = if active then BG_CARD else BG_PANEL
	c.BackgroundTransparency = if active then 0 else 0.3
	c.BorderSizePixel = 0
	corner(c, 8)
	stroke(c, if active then ACCENT else BORDER, 1, if active then 0.5 else 0.7)
	pad(c, 12, 12, 12, 12)
	listLayout(c, 6)
	c.Parent = parent
	return c
end

local function meter(parent, labelText, value, max, color)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.4, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.FontFace = FONT_MONO
	lbl.TextSize = 11
	lbl.TextColor3 = TEXT_DIM
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText
	lbl.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0.6, 0, 0, 6)
	track.Position = UDim2.new(0.4, 0, 0.5, -3)
	track.BackgroundColor3 = BG
	track.BorderSizePixel = 0
	corner(track, 3)
	track.Parent = row

	local fill = Instance.new("Frame")
	local pct = if max > 0 then math.clamp(value / max, 0, 1) else 0
	fill.Size = UDim2.new(pct, 0, 1, 0)
	fill.BackgroundColor3 = color or ACCENT
	fill.BorderSizePixel = 0
	corner(fill, 3)
	fill.Parent = track

	return row, fill
end

local function clear(frame)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke")
			and child.Name ~= "CollapseHeader" then
			child:Destroy()
		end
	end
end

-- ── Pages ───────────────────────────────────────────────────────────────
local function page(name, isPanel)
	local p = Instance.new("ScrollingFrame")
	p.Name = name
	if isPanel then
		if IS_MOBILE then
			-- Mobile: full-width panel with small margin
			p.Size = UDim2.new(1, -16, 1, -20)
			p.Position = UDim2.new(0, 8, 0, 10)
		else
			-- Desktop: side panel on the right
			p.Size = UDim2.new(0, 340, 1, -20)
			p.Position = UDim2.new(1, -350, 0, 10)
		end
	else
		p.Size = UDim2.new(1, 0, 1, 0)
	end
	p.CanvasSize = UDim2.new(0, 0, 0, 0)
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	p.ScrollBarThickness = 3
	p.ScrollBarImageColor3 = ACCENT
	p.BackgroundColor3 = BG
	p.BackgroundTransparency = if isPanel then 0.05 else 0
	p.BorderSizePixel = 0
	p.Visible = false
	pad(p, 12, 12, 12, 12)
	listLayout(p, 10)
	if isPanel then
		corner(p, 10)
		stroke(p, BORDER, 1, 0.3)
	end
	p.Parent = gui
	return p
end

local current = nil
local function show(target)
	if current then current.Visible = false end
	if target then target.Visible = true end
	current = target
end

-- ── Collapsible toggle ─────────────────────────────────────────────────
-- Adds a small collapse/expand button that sits inside the top of a panel.
-- Collapsed = panel shrinks to 36px tall, content hidden by ClipsDescendants.
-- Expanded = panel returns to its original size.
-- Nothing about page(), show(), clear(), or render functions changes.

local collapseStates = {} -- tracks which panels are collapsed

local function makeCollapsible(panel, titleText)
	panel.ClipsDescendants = true

	-- Save the original size so we can restore it
	local expandedSize = panel.Size

	-- Toggle button: lives INSIDE the panel at top-right, high ZIndex so it stays visible when collapsed
	local toggle = Instance.new("TextButton")
	toggle.Name = "CollapseToggle"
	toggle.Size = UDim2.new(0, 36, 0, 24)
	toggle.Position = UDim2.new(1, -36, 0, 0)
	toggle.AnchorPoint = Vector2.new(0, 0)
	toggle.BackgroundColor3 = BG_CARD
	toggle.BackgroundTransparency = 0.3
	toggle.FontFace = FONT_TITLE
	toggle.TextSize = 14
	toggle.TextColor3 = ACCENT
	toggle.Text = "—"
	toggle.ZIndex = 10
	toggle.AutoButtonColor = false
	toggle.BorderSizePixel = 0
	corner(toggle, 4)
	toggle.Parent = panel

	-- Title label shown when collapsed
	local collapseTitle = Instance.new("TextLabel")
	collapseTitle.Name = "CollapseTitle"
	collapseTitle.Size = UDim2.new(1, -44, 0, 24)
	collapseTitle.Position = UDim2.new(0, 0, 0, 0)
	collapseTitle.BackgroundTransparency = 1
	collapseTitle.FontFace = FONT_TITLE
	collapseTitle.TextSize = 11
	collapseTitle.TextColor3 = ACCENT
	collapseTitle.TextXAlignment = Enum.TextXAlignment.Left
	collapseTitle.Text = titleText
	collapseTitle.ZIndex = 10
	collapseTitle.Visible = false
	collapseTitle.Parent = panel

	local collapsed = false
	collapseStates[panel] = false

	toggle.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		collapseStates[panel] = collapsed
		if collapsed then
			panel.Size = UDim2.new(expandedSize.X.Scale, expandedSize.X.Offset, 0, 36)
			panel.AutomaticCanvasSize = Enum.AutomaticSize.None
			panel.CanvasSize = UDim2.new(0, 0, 0, 0)
			panel.ScrollBarThickness = 0
			toggle.Text = "+"
			collapseTitle.Visible = true
		else
			panel.Size = expandedSize
			panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
			panel.ScrollBarThickness = 3
			toggle.Text = "—"
			collapseTitle.Visible = false
		end
	end)

	-- Hover effect
	toggle.MouseEnter:Connect(function()
		TweenService:Create(toggle, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
	end)
	toggle.MouseLeave:Connect(function()
		TweenService:Create(toggle, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
	end)
end

-- Same idea for the HUD Frame (not a ScrollingFrame, uses AutomaticSize instead)
local function makeCollapsibleFrame(frame, titleText)
	frame.ClipsDescendants = true

	local expandedSize = frame.Size
	local expandedAutoSize = frame.AutomaticSize

	local toggle = Instance.new("TextButton")
	toggle.Name = "CollapseToggle"
	toggle.Size = UDim2.new(0, 36, 0, 24)
	toggle.Position = UDim2.new(1, -36, 0, 0)
	toggle.AnchorPoint = Vector2.new(0, 0)
	toggle.BackgroundColor3 = BG_CARD
	toggle.BackgroundTransparency = 0.3
	toggle.FontFace = FONT_TITLE
	toggle.TextSize = 14
	toggle.TextColor3 = ACCENT
	toggle.Text = "—"
	toggle.ZIndex = 10
	toggle.AutoButtonColor = false
	toggle.BorderSizePixel = 0
	corner(toggle, 4)
	toggle.Parent = frame

	local collapseTitle = Instance.new("TextLabel")
	collapseTitle.Name = "CollapseTitle"
	collapseTitle.Size = UDim2.new(1, -44, 0, 24)
	collapseTitle.Position = UDim2.new(0, 0, 0, 0)
	collapseTitle.BackgroundTransparency = 1
	collapseTitle.FontFace = FONT_TITLE
	collapseTitle.TextSize = 11
	collapseTitle.TextColor3 = ACCENT
	collapseTitle.TextXAlignment = Enum.TextXAlignment.Left
	collapseTitle.Text = titleText
	collapseTitle.ZIndex = 10
	collapseTitle.Visible = false
	collapseTitle.Parent = frame

	local collapsed = false

	toggle.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		if collapsed then
			frame.AutomaticSize = Enum.AutomaticSize.None
			frame.Size = UDim2.new(expandedSize.X.Scale, expandedSize.X.Offset, 0, 36)
			toggle.Text = "+"
			collapseTitle.Visible = true
		else
			frame.Size = expandedSize
			frame.AutomaticSize = expandedAutoSize
			toggle.Text = "—"
			collapseTitle.Visible = false
		end
	end)

	toggle.MouseEnter:Connect(function()
		TweenService:Create(toggle, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
	end)
	toggle.MouseLeave:Connect(function()
		TweenService:Create(toggle, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
	end)
end

-- ── Intro ───────────────────────────────────────────────────────────────
local intro = page("Intro")

local introContent = Instance.new("Frame")
introContent.Size = UDim2.new(1, 0, 0, 0)
introContent.AutomaticSize = Enum.AutomaticSize.Y
introContent.BackgroundTransparency = 1
local introListLayout = listLayout(introContent, 16)
introListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
introContent.Parent = intro

local spacer1 = Instance.new("Frame")
spacer1.Size = UDim2.new(1, 0, 0, if IS_MOBILE then 30 else 60)
spacer1.BackgroundTransparency = 1
spacer1.Parent = introContent

local logoSize = if IS_MOBILE then 140 else 200
local introLogo = Instance.new("ImageLabel")
introLogo.Size = UDim2.new(0, logoSize, 0, logoSize)
introLogo.BackgroundTransparency = 1
introLogo.Image = "rbxassetid://135974007304660"
introLogo.ScaleType = Enum.ScaleType.Fit
introLogo.Parent = introContent
local introLogoLayout = Instance.new("UIAspectRatioConstraint")
introLogoLayout.AspectRatio = 1
introLogoLayout.Parent = introLogo

local introSub = label(introContent, "BUILD YOUR SURVIVAL SUIT. FACE THE SOLAR SYSTEM.", if IS_MOBILE then 12 else 14, TEXT_DIM, FONT_TITLE)
introSub.TextXAlignment = Enum.TextXAlignment.Center

local spacer2 = Instance.new("Frame")
spacer2.Size = UDim2.new(1, 0, 0, 20)
spacer2.BackgroundTransparency = 1
spacer2.Parent = introContent

local introCard = card(introContent, true)
label(introCard, "Eight planets. Real NASA surface data. One suit between you and all of it.", 13, TEXT_DIM)
divider(introCard)
label(introCard, "Scavenge materials. Layer them however you want. The physics will tell you if it works.", 13, TEXT_DIM)
divider(introCard)
label(introCard, "Reach the beacon before your suit gives out.", 14, TEXT_WHITE, FONT_TITLE)

local startBtn = btn(introContent, "Start", true)
startBtn.Size = UDim2.new(1, 0, 0, 48)

-- ── Objectives ──────────────────────────────────────────────────────────
local note = page("Note")

local noteContent = Instance.new("Frame")
noteContent.Size = UDim2.new(1, 0, 0, 0)
noteContent.AutomaticSize = Enum.AutomaticSize.Y
noteContent.BackgroundTransparency = 1
listLayout(noteContent, 10)
noteContent.Parent = note

label(noteContent, "OBJECTIVES", 11, ACCENT, FONT_TITLE)
divider(noteContent)

local objCard = card(noteContent, true)
label(objCard, "1. Walk to glowing material piles and press E to collect.", 13, TEXT_WHITE)
label(objCard, "2. Open the workshop to build your suit layer by layer.", 13, TEXT_WHITE)
label(objCard, "3. Pick a planet, choose a side (hot or cold), and deploy.", 13, TEXT_WHITE)
label(objCard, "4. Run the obby and reach the beacon before your suit fails.", 13, TEXT_WHITE)

local hintLabel = label(noteContent, "", 12, WARNING, FONT_MONO)

local openBuild = btn(noteContent, "Open Workshop", true)

-- ── Workshop ────────────────────────────────────────────────────────────
local workshop = page("Workshop", true)
makeCollapsible(workshop, "SUIT WORKSHOP")

local function designFrom(d)
	if d == nil then return Design.emptyDesign() end
	local design = { layers = {}, oxygenKg = d.oxygenKg or 0 }
	if d.layers ~= nil then
		for _, layer in d.layers do
			table.insert(design.layers, { materialId = layer.materialId, thicknessM = layer.thicknessM })
		end
	end
	return design
end

local planets -- forward declaration; assigned after renderWorkshop

function renderWorkshop()
	clear(workshop)

	if state == nil then return end

	local design = designFrom(state.design)

	-- Header
	label(workshop, "SUIT WORKSHOP", 11, ACCENT, FONT_TITLE)
	divider(workshop)

	-- Inventory
	local invCard = card(workshop, false)
	label(invCard, "INVENTORY", 10, TEXT_FAINT, FONT_TITLE)
	for _, material in Catalog.MATERIALS do
		local kg = state.inventory[material.id] or 0
		if kg > 0 then
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 20)
			row.BackgroundTransparency = 1
			row.Parent = invCard

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 8, 0, 8)
			dot.Position = UDim2.new(0, 0, 0.5, -4)
			dot.BackgroundColor3 = Color3.fromHex(material.color)
			dot.BorderSizePixel = 0
			corner(dot, 4)
			dot.Parent = row

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(0.6, -14, 1, 0)
			name.Position = UDim2.new(0, 14, 0, 0)
			name.BackgroundTransparency = 1
			name.FontFace = FONT_BODY
			name.TextSize = 12
			name.TextColor3 = TEXT_WHITE
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Text = material.name
			name.Parent = row

			local qty = Instance.new("TextLabel")
			qty.Size = UDim2.new(0.35, 0, 1, 0)
			qty.Position = UDim2.new(0.65, 0, 0, 0)
			qty.BackgroundTransparency = 1
			qty.FontFace = FONT_MONO
			qty.TextSize = 11
			qty.TextColor3 = TEXT_DIM
			qty.TextXAlignment = Enum.TextXAlignment.Right
			qty.Text = string.format("%.1f kg", kg)
			qty.Parent = row
		end
	end

	divider(workshop)

	-- Current layers
	local layerCard = card(workshop, true)
	label(layerCard, "SUIT LAYERS (inner to outer)", 10, TEXT_FAINT, FONT_TITLE)

	if #design.layers == 0 then
		label(layerCard, "No layers yet. Add materials below.", 12, TEXT_FAINT)
	else
		for i, layer in design.layers do
			local mat = Catalog.materialById(layer.materialId)
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 32)
			row.BackgroundColor3 = BG
			row.BorderSizePixel = 0
			corner(row, 4)
			row.Parent = layerCard

			local num = Instance.new("TextLabel")
			num.Size = UDim2.new(0, 24, 1, 0)
			num.BackgroundTransparency = 1
			num.FontFace = FONT_MONO
			num.TextSize = 11
			num.TextColor3 = ACCENT
			num.Text = tostring(i)
			num.Parent = row

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 8, 0, 8)
			dot.Position = UDim2.new(0, 28, 0.5, -4)
			dot.BackgroundColor3 = Color3.fromHex(mat.color)
			dot.BorderSizePixel = 0
			corner(dot, 4)
			dot.Parent = row

			local info = Instance.new("TextLabel")
			info.Size = UDim2.new(1, -100, 1, 0)
			info.Position = UDim2.new(0, 42, 0, 0)
			info.BackgroundTransparency = 1
			info.FontFace = FONT_BODY
			info.TextSize = 12
			info.TextColor3 = TEXT_WHITE
			info.TextXAlignment = Enum.TextXAlignment.Left
			info.Text = mat.name .. "  " .. string.format("%.0f mm", layer.thicknessM * 1000)
			info.Parent = row

			local tag = Instance.new("TextLabel")
			tag.Size = UDim2.new(0, 40, 0, 16)
			tag.Position = UDim2.new(1, -80, 0.5, -8)
			tag.BackgroundColor3 = if mat.structural then ACCENT else WARNING
			tag.BackgroundTransparency = 0.8
			tag.FontFace = FONT_MONO
			tag.TextSize = 9
			tag.TextColor3 = if mat.structural then ACCENT else WARNING
			tag.Text = if mat.structural then "STRUCT" else "INSUL"
			corner(tag, 3)
			tag.Parent = row

			local removeBtn = Instance.new("TextButton")
			removeBtn.Size = UDim2.new(0, 28, 0, 28)
			removeBtn.Position = UDim2.new(1, -30, 0.5, -14)
			removeBtn.BackgroundColor3 = DANGER
			removeBtn.BackgroundTransparency = 0.8
			removeBtn.FontFace = FONT_TITLE
			removeBtn.TextSize = 14
			removeBtn.TextColor3 = DANGER
			removeBtn.Text = "X"
			removeBtn.AutoButtonColor = false
			corner(removeBtn, 4)
			removeBtn.Parent = row

			local idx = i
			removeBtn.MouseButton1Click:Connect(function()
				RemoveLayer:FireServer(idx)
			end)
		end
	end

	-- Oxygen
	divider(workshop)
	local o2Card = card(workshop, false)
	label(o2Card, "OXYGEN", 10, TEXT_FAINT, FONT_TITLE)
	local oxygenAvail = state.inventory.oxygen or 0
	label(o2Card, string.format("Packed: %.1f kg  /  Available: %.1f kg", design.oxygenKg, oxygenAvail), 12, TEXT_WHITE, FONT_MONO)
	if oxygenAvail > 0 then
		local packAll = btn(o2Card, "Pack all oxygen", false)
		packAll.Size = UDim2.new(1, 0, 0, 32)
		packAll.MouseButton1Click:Connect(function()
			SetOxygen:FireServer(oxygenAvail)
		end)
		local packNone = btn(o2Card, "Remove oxygen", false)
		packNone.Size = UDim2.new(1, 0, 0, 32)
		packNone.MouseButton1Click:Connect(function()
			SetOxygen:FireServer(0)
		end)
	end

	-- Add layer
	divider(workshop)
	label(workshop, "ADD LAYER", 10, TEXT_FAINT, FONT_TITLE)

	for _, material in Catalog.MATERIALS do
		if material.id == "oxygen" then continue end
		local kg = state.inventory[material.id] or 0
		if kg <= 0 then continue end

		local matCard = card(workshop, false)
		local hdr = Instance.new("Frame")
		hdr.Size = UDim2.new(1, 0, 0, 20)
		hdr.BackgroundTransparency = 1
		hdr.Parent = matCard

		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 10, 0, 10)
		dot.Position = UDim2.new(0, 0, 0.5, -5)
		dot.BackgroundColor3 = Color3.fromHex(material.color)
		dot.BorderSizePixel = 0
		corner(dot, 5)
		dot.Parent = hdr

		local matName = Instance.new("TextLabel")
		matName.Size = UDim2.new(1, -16, 1, 0)
		matName.Position = UDim2.new(0, 16, 0, 0)
		matName.BackgroundTransparency = 1
		matName.FontFace = FONT_TITLE
		matName.TextSize = 13
		matName.TextColor3 = TEXT_WHITE
		matName.TextXAlignment = Enum.TextXAlignment.Left
		matName.Text = material.name
		matName.Parent = hdr

		label(matCard, material.blurb, 11, TEXT_DIM)

		-- Stats row
		local stats = string.format("k=%.3f W/mK  |  yield=%s  |  melts=%dK  |  %.0f kg/m3",
			material.conductivity,
			if material.structural then string.format("%.0f MPa", material.yieldPa / 1e6) else "N/A",
			material.meltingK,
			material.densityKgM3
		)
		label(matCard, stats, 10, TEXT_FAINT, FONT_MONO)

		-- Thickness buttons
		local thickRow = Instance.new("Frame")
		thickRow.Size = UDim2.new(1, 0, 0, 32)
		thickRow.BackgroundTransparency = 1
		thickRow.Parent = matCard

		local thickLayout = Instance.new("UIListLayout")
		thickLayout.FillDirection = Enum.FillDirection.Horizontal
		thickLayout.Padding = UDim.new(0, 6)
		thickLayout.Parent = thickRow

		for _, opt in Design.THICKNESS_OPTIONS do
			local tb = Instance.new("TextButton")
			tb.Size = UDim2.new(0.24, -5, 1, 0)
			tb.BackgroundColor3 = BG_CARD
			tb.FontFace = FONT_MONO
			tb.TextSize = 11
			tb.TextColor3 = ACCENT
			tb.Text = opt.label .. "\n" .. string.format("%.0fmm", opt.meters * 1000)
			tb.AutoButtonColor = false
			tb.BorderSizePixel = 0
			corner(tb, 4)
			stroke(tb, ACCENT, 1, 0.7)
			tb.Parent = thickRow

			local matId = material.id
			local thickId = opt.id
			tb.MouseButton1Click:Connect(function()
				AddLayer:FireServer(matId, thickId)
			end)

			tb.MouseEnter:Connect(function()
				TweenService:Create(tb, TweenInfo.new(0.1), {BackgroundColor3 = BG_CARD_HOV}):Play()
			end)
			tb.MouseLeave:Connect(function()
				TweenService:Create(tb, TweenInfo.new(0.1), {BackgroundColor3 = BG_CARD}):Play()
			end)
		end
	end

	-- Suit stats
	divider(workshop)
	local statsCard = card(workshop, true)
	label(statsCard, "SUIT SUMMARY", 10, TEXT_FAINT, FONT_TITLE)
	local totalMass = Design.designMassKg(design)
	local sealed = Design.isSealed(design)
	label(statsCard, string.format("Total mass: %.1f kg", totalMass), 12, TEXT_WHITE, FONT_MONO)
	label(statsCard, "Sealed: " .. (if sealed then "YES" else "NO (need a structural layer)"), 12, if sealed then SUCCESS else DANGER, FONT_MONO)
	label(statsCard, string.format("Layers: %d / 8", #design.layers), 12, TEXT_DIM, FONT_MONO)

	-- Hint / problem
	if state.problem ~= "" and state.problem ~= nil then
		label(statsCard, state.problem, 12, DANGER, FONT_MONO)
	end
	if state.hint ~= nil and state.hint ~= "" then
		label(statsCard, state.hint, 11, WARNING)
	end

	divider(workshop)

	local toPlanets = btn(workshop, "Choose destination", true)
	toPlanets.Size = UDim2.new(1, 0, 0, 44)
	toPlanets.MouseButton1Click:Connect(function()
		show(planets)
		renderPlanets()
	end)
end

openBuild.MouseButton1Click:Connect(function()
	show(workshop)
	if state ~= nil then
		renderWorkshop()
	end
end)

-- ── Planets ─────────────────────────────────────────────────────────────
planets = page("Planets", true)
makeCollapsible(planets, "DESTINATIONS")

local difficulty -- forward declaration; assigned after renderPlanets
local DEMO_MODE = true

local function isOpen(planetId: string): boolean
	if DEMO_MODE then return true end
	if state == nil then return false end
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

	if state == nil then
		return
	end

	local design = designFrom(state.design)
	local check = 1.5

	label(planets, "DESTINATIONS", 11, ACCENT, FONT_TITLE)
	label(planets, "NASA NSSDC Planetary Fact Sheets", 10, TEXT_FAINT, FONT_MONO)
	divider(planets)

	for _, planetId in Sources.DESTINATION_ORDER do
		local planet = Catalog.planetById(planetId)
		local open = isOpen(planetId)
		local wasCleared = false
		if state.clears then
			for _, id in state.clears do
				if id == planetId then wasCleared = true end
			end
		end

		local planetCard = card(planets, open)
		if wasCleared then
			stroke(planetCard, SUCCESS, 1, 0.3)
		end

		-- Header row
		local nameRow = Instance.new("Frame")
		nameRow.Size = UDim2.new(1, 0, 0, 24)
		nameRow.BackgroundTransparency = 1
		nameRow.Parent = planetCard

		local planetName = Instance.new("TextLabel")
		planetName.BackgroundTransparency = 1
		planetName.Size = UDim2.new(0.7, 0, 1, 0)
		planetName.FontFace = FONT_TITLE
		planetName.TextSize = 18
		planetName.TextColor3 = if open then TEXT_WHITE else TEXT_FAINT
		planetName.TextXAlignment = Enum.TextXAlignment.Left
		planetName.Text = planet.name
		planetName.Parent = nameRow

		if wasCleared then
			local badge = Instance.new("TextLabel")
			badge.BackgroundTransparency = 1
			badge.Size = UDim2.new(0.3, 0, 1, 0)
			badge.FontFace = FONT_TITLE
			badge.TextSize = 11
			badge.TextColor3 = SUCCESS
			badge.TextXAlignment = Enum.TextXAlignment.Right
			badge.Text = "SURVIVED"
			badge.Parent = nameRow
		end

		if open then
			label(planetCard, string.format("Gravity: %.2f m/s2  |  %s", planet.gravityMs2, planet.role), 11, ACCENT, FONT_MONO)

			local hotOk, hotResult = pcall(Survival.kidResult, design, planet, check, "hot")
			if not hotOk then hotResult = "Hot side: error" end
			local coldOk, coldResult = pcall(Survival.kidResult, design, planet, check, "cold")
			if not coldOk then coldResult = "Cold side: error" end
			label(planetCard, hotResult, 10, TEXT_DIM, FONT_MONO)
			label(planetCard, coldResult, 10, TEXT_DIM, FONT_MONO)

			local choose = btn(planetCard, "Briefing", true)
			choose.Size = UDim2.new(1, 0, 0, 38)
			choose.MouseButton1Click:Connect(function()
				chosenPlanet = planetId
				show(difficulty)
				renderDifficulty()
			end)
		else
			label(planetCard, "LOCKED", 12, TEXT_FAINT, FONT_TITLE)
			label(planetCard, "Clear the previous planet to unlock.", 11, TEXT_FAINT)
		end
	end

	divider(planets)

	local back = btn(planets, "Back to workshop", false)
	back.MouseButton1Click:Connect(function()
		show(workshop)
		renderWorkshop()
	end)
end

-- ── Difficulty / Briefing ───────────────────────────────────────────────
difficulty = page("Difficulty", true)
makeCollapsible(difficulty, "MISSION BRIEFING")

function renderDifficulty()
	clear(difficulty)

	if chosenPlanet == nil then return end

	local planet = Catalog.planetById(chosenPlanet)

	label(difficulty, "MISSION BRIEFING", 11, ACCENT, FONT_TITLE)
	label(difficulty, planet.name, if IS_MOBILE then 22 else 28, TEXT_WHITE, FONT_DISPLAY)
	label(difficulty, planet.role, 12, ACCENT)

	divider(difficulty)

	-- NASA data card
	local dataCard = card(difficulty, true)
	label(dataCard, "FROM THE NASA FACT SHEET", 9, TEXT_FAINT, FONT_TITLE)
	label(dataCard, string.format("Gravity: %.2f m/s2", planet.gravityMs2), 12, TEXT_WHITE, FONT_MONO)
	label(dataCard, "Pressure: " .. planet.referencePressure.transcribedFrom, 11, TEXT_DIM, FONT_MONO)

	for _, reading in planet.temperatures do
		label(dataCard, reading.transcribedFrom, 11, TEXT_DIM, FONT_MONO)
	end

	label(dataCard, planet.sourceUrl, 10, ACCENT, FONT_MONO)

	divider(difficulty)

	-- Difficulty selection
	label(difficulty, "DIFFICULTY", 11, TEXT_FAINT, FONT_TITLE)

	for _, profile in Catalog.DIFFICULTIES do
		local dc = card(difficulty, false)
		label(dc, profile.label, 16, TEXT_WHITE, FONT_TITLE)
		label(dc, profile.summary, 11, TEXT_DIM)
		label(dc, string.format("Safety factor: %.1fx  |  Score: %.1fx", profile.minSafetyFactor, profile.scoreMultiplier), 10, TEXT_FAINT, FONT_MONO)

		-- Side selection
		divider(dc)
		label(dc, "DEPLOY SIDE", 10, TEXT_FAINT, FONT_TITLE)

		local sideRow = Instance.new("Frame")
		sideRow.Size = UDim2.new(1, 0, 0, 38)
		sideRow.BackgroundTransparency = 1
		sideRow.Parent = dc

		local sideLayout = Instance.new("UIListLayout")
		sideLayout.FillDirection = Enum.FillDirection.Horizontal
		sideLayout.Padding = UDim.new(0, 8)
		sideLayout.Parent = sideRow

		local hotBtn = btn(sideRow, "Hot Side", true)
		hotBtn.Size = UDim2.new(0.48, 0, 1, 0)
		hotBtn.BackgroundColor3 = DANGER
		hotBtn.TextColor3 = TEXT_WHITE

		local coldBtn = btn(sideRow, "Cold Side", true)
		coldBtn.Size = UDim2.new(0.48, 0, 1, 0)
		coldBtn.BackgroundColor3 = COOL
		coldBtn.TextColor3 = BG

		local diffId = profile.id
		hotBtn.MouseButton1Click:Connect(function()
			warn("[CODAG Client] Firing Depart:", chosenPlanet, diffId, "hot")
			DepartEvent:FireServer(chosenPlanet, diffId, "hot")
		end)
		coldBtn.MouseButton1Click:Connect(function()
			warn("[CODAG Client] Firing Depart:", chosenPlanet, diffId, "cold")
			DepartEvent:FireServer(chosenPlanet, diffId, "cold")
		end)
	end

	divider(difficulty)

	local back = btn(difficulty, "Back to planets", false)
	back.MouseButton1Click:Connect(function()
		show(planets)
		renderPlanets()
	end)
end

-- ── HUD ─────────────────────────────────────────────────────────────────
local hud = Instance.new("Frame")
hud.Name = "HUD"
if IS_MOBILE then
	hud.Size = UDim2.new(1, -16, 0, 0)
	hud.Position = UDim2.new(0, 8, 0, 8)
else
	hud.Size = UDim2.new(0, 260, 0, 0)
	hud.Position = UDim2.new(1, -276, 0, 16)
end
hud.AutomaticSize = Enum.AutomaticSize.Y
hud.BackgroundColor3 = BG_PANEL
hud.BackgroundTransparency = 0.15
hud.BorderSizePixel = 0
hud.Visible = false
corner(hud, 8)
stroke(hud, BORDER, 1, 0.5)
pad(hud, 10, 10, 10, 10)
listLayout(hud, 4)
hud.Parent = gui

makeCollapsibleFrame(hud, "MISSION")

local hudTitle = label(hud, "MISSION", 10, ACCENT, FONT_TITLE)
local hudPlanet = label(hud, "", 16, TEXT_WHITE, FONT_TITLE)
local hudSide = label(hud, "", 11, TEXT_DIM, FONT_MONO)
local hudClock = label(hud, "0:00", 18, TEXT_WHITE, FONT_MONO)
hudClock.TextXAlignment = Enum.TextXAlignment.Center

local _, airFill = meter(hud, "AIR SEAL", 100, 100, ACCENT)
local _, tempFill = meter(hud, "CORE TEMP", 37, 50, WARNING)
local _, o2Fill = meter(hud, "OXYGEN", 1, 2, COOL)

local hudDeath = Instance.new("Frame")
hudDeath.Size = UDim2.new(1, 0, 0, 0)
hudDeath.AutomaticSize = Enum.AutomaticSize.Y
hudDeath.BackgroundColor3 = DANGER
hudDeath.BackgroundTransparency = 0.85
hudDeath.BorderSizePixel = 0
hudDeath.Visible = false
corner(hudDeath, 6)
pad(hudDeath, 8, 8, 8, 8)
listLayout(hudDeath, 4)
hudDeath.Parent = hud

local deathLabel = label(hudDeath, "", 13, DANGER, FONT_TITLE)

local abortBtn = btn(hud, "Abort mission", false)
abortBtn.Size = UDim2.new(1, 0, 0, 32)
abortBtn.TextColor3 = DANGER
abortBtn.MouseButton1Click:Connect(function()
	AbortEvent:FireServer()
end)

local function clock(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	return string.format("%d:%02d", m, s)
end

local function renderHud()
	local inMission = player:GetAttribute("InMission")
	hud.Visible = inMission == true

	if not inMission then return end

	hudPlanet.Text = player:GetAttribute("MissionPlanet") or ""
	hudSide.Text = (player:GetAttribute("MissionSide") or "") .. "  |  " .. (player:GetAttribute("MissionDifficulty") or "")
	hudClock.Text = clock(player:GetAttribute("MissionClock") or 0)

	local airHeld = player:GetAttribute("AirHeld") or 100
	airFill.Size = UDim2.new(math.clamp(airHeld / 100, 0, 1), 0, 1, 0)
	airFill.BackgroundColor3 = if airHeld < 30 then DANGER else ACCENT

	local coreC = player:GetAttribute("CoreC") or 37
	local tempPct = math.clamp((coreC + 10) / 60, 0, 1)
	tempFill.Size = UDim2.new(tempPct, 0, 1, 0)
	tempFill.BackgroundColor3 = if coreC > 39 then DANGER elseif coreC < 35 then COOL else SUCCESS

	local oxygenKg = player:GetAttribute("OxygenKg") or 0
	local maxO2 = if state and state.design then (state.design.oxygenKg or 2) else 2
	o2Fill.Size = UDim2.new(math.clamp(oxygenKg / math.max(maxO2, 0.1), 0, 1), 0, 1, 0)
	o2Fill.BackgroundColor3 = if oxygenKg < 0.3 then DANGER else COOL

	local alive = player:GetAttribute("Alive")
	local causeTitle = player:GetAttribute("CauseTitle") or ""
	hudDeath.Visible = alive == false
	deathLabel.Text = causeTitle
end

player:GetAttributeChangedSignal("InMission"):Connect(renderHud)
player:GetAttributeChangedSignal("MissionClock"):Connect(renderHud)
player:GetAttributeChangedSignal("Alive"):Connect(renderHud)

-- ── Debrief ─────────────────────────────────────────────────────────────
local debrief = page("Debrief")

DebriefEvent.OnClientEvent:Connect(function(report)
	clear(debrief)
	show(debrief)

	if report.survived then
		label(debrief, "MISSION COMPLETE", 11, SUCCESS, FONT_TITLE)
		label(debrief, "You survived.", 28, SUCCESS, FONT_DISPLAY)
	else
		label(debrief, "MISSION FAILED", 11, DANGER, FONT_TITLE)
		label(debrief, report.title, 24, TEXT_WHITE, FONT_DISPLAY)
	end

	divider(debrief)

	label(debrief, report.detail, 13, TEXT_DIM)

	divider(debrief)

	-- NASA fact cards
	if report.facts then
		label(debrief, "FROM THE NASA FACT SHEETS", 10, TEXT_FAINT, FONT_TITLE)
		label(debrief, "The physics that decided your fate. Every number below came from NSSDC, not from a model or an estimate.", 11, ACCENT)

		for _, fact in report.facts do
			local fc = card(debrief, false)
			label(fc, fact.text, 12, TEXT_WHITE)
			divider(fc)
			label(fc, fact.body .. " Fact Sheet", 10, TEXT_FAINT, FONT_TITLE)
			label(fc, fact.sourceUrl, 10, ACCENT, FONT_MONO)
		end
	end

	divider(debrief)

	local again = btn(debrief, "Return to workshop", true)
	again.Size = UDim2.new(1, 0, 0, 44)
	again.MouseButton1Click:Connect(function()
		show(workshop)
		renderWorkshop()
	end)
end)

-- ── State sync ──────────────────────────────────────────────────────────
StateEvent.OnClientEvent:Connect(function(s)
	state = s
	if hintLabel then
		hintLabel.Text = s.hint or ""
	end
	if current == workshop then
		renderWorkshop()
	elseif current == planets then
		renderPlanets()
	end
end)

-- ── Init ────────────────────────────────────────────────────────────────
local function showIntro()
	show(intro)
	introLogo.ImageTransparency = 1
	introSub.TextTransparency = 1
	startBtn.Visible = false

	task.delay(0.3, function()
		TweenService:Create(introLogo, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {ImageTransparency = 0}):Play()
	end)
	task.delay(0.8, function()
		TweenService:Create(introSub, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {TextTransparency = 0}):Play()
	end)
	task.delay(1.5, function()
		startBtn.Visible = true
	end)
end

startBtn.MouseButton1Click:Connect(function()
	show(note)
end)

print("[CODAG Client] GUI created, showing intro")
showIntro()
Ready:FireServer()
print("[CODAG Client] Init complete")
