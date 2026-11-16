local function dataModule(name: string)
	if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then
		local data = script.Parent.Parent:FindFirstChild("Data")
		if data ~= nil then
			local child = data:FindFirstChild(name)
			if child ~= nil then
				return require(child)
			end
		end
	end
	return require("../Data/" .. name)
end

local Catalog = dataModule("Catalog")
local materialById = Catalog.materialById

local TANK_KG_PER_OXYGEN_KG = 5
local BASE_RADIUS_M = 0.48

local THICKNESS_OPTIONS = {
	{ id = "thin",   label = "Thin",   meters = 0.001 },
	{ id = "medium", label = "Medium", meters = 0.003 },
	{ id = "thick",  label = "Thick",  meters = 0.006 },
	{ id = "heavy",  label = "Heavy",  meters = 0.012 },
}

local function emptyDesign()
	return {
		layers = {},
		oxygenKg = 0,
		-- Legacy fields kept in sync for Survival.luau backward compat
		shellMaterialId = nil,
		shellRadiusM = BASE_RADIUS_M,
		shellThicknessM = 0,
		insulationMaterialId = nil,
		insulationThicknessM = 0,
	}
end

-- Derive legacy fields from layers so Survival.luau keeps working
local function syncLegacy(design)
	local shellMatId = nil
	local shellThick = 0
	local insMatId = nil
	local insThick = 0
	local totalThick = 0
	for _, layer in design.layers do
		local mat = materialById(layer.materialId)
		totalThick += layer.thicknessM
		if mat.structural then
			if shellMatId == nil then
				shellMatId = layer.materialId
			end
			shellThick += layer.thicknessM
		else
			if insMatId == nil then
				insMatId = layer.materialId
			end
			insThick += layer.thicknessM
		end
	end
	design.shellMaterialId = shellMatId
	design.shellThicknessM = shellThick
	design.shellRadiusM = BASE_RADIUS_M + totalThick
	design.insulationMaterialId = insMatId
	design.insulationThicknessM = insThick
end

-- Helper accessors used by the server
local function getShellMaterialId(design): string?
	for _, layer in design.layers do
		local mat = materialById(layer.materialId)
		if mat.structural then
			return layer.materialId
		end
	end
	return nil
end

local function outerRadiusM(design): number
	local total = BASE_RADIUS_M
	for _, layer in design.layers do
		total += layer.thicknessM
	end
	return total
end

local function getShellThicknessM(design): number
	local total = 0
	for _, layer in design.layers do
		local mat = materialById(layer.materialId)
		if mat.structural then
			total += layer.thicknessM
		end
	end
	return total
end

-- Mass calculations using legacy fields (kept for Survival compat)
local function shellVolumeM3(design): number
	if design.shellMaterialId == nil or design.shellThicknessM <= 0 or design.shellRadiusM <= design.shellThicknessM then
		return 0
	end
	local outer = design.shellRadiusM
	local inner = outer - design.shellThicknessM
	return (4 / 3) * math.pi * (outer ^ 3 - inner ^ 3)
end

local function shellAreaM2(design): number
	local radius = if design.shellMaterialId then design.shellRadiusM else 0.45
	return 4 * math.pi * radius * radius
end

local function insulationVolumeM3(design): number
	if design.insulationMaterialId == nil or design.insulationThicknessM <= 0 then
		return 0
	end
	return shellAreaM2(design) * design.insulationThicknessM
end

local function shellMassKg(design): number
	if design.shellMaterialId == nil then
		return 0
	end
	return materialById(design.shellMaterialId).densityKgM3 * shellVolumeM3(design)
end

local function insulationMassKg(design): number
	if design.insulationMaterialId == nil then
		return 0
	end
	return materialById(design.insulationMaterialId).densityKgM3 * insulationVolumeM3(design)
end

local function oxygenHardwareKg(design): number
	return design.oxygenKg * TANK_KG_PER_OXYGEN_KG
end

local function designMassKg(design): number
	return shellMassKg(design) + insulationMassKg(design) + design.oxygenKg + oxygenHardwareKg(design)
end

-- Check if layers use more material than inventory allows
local function stockProblem(design, inventory): string?
	if design.layers and #design.layers > 0 then
		-- Layer-based check: accumulate mass per material across layers
		local usedMass = {}
		local outerR = BASE_RADIUS_M
		for _, layer in design.layers do
			local mat = materialById(layer.materialId)
			outerR += layer.thicknessM
			local area = 4 * math.pi * outerR * outerR
			local mass = mat.densityKgM3 * area * layer.thicknessM
			usedMass[layer.materialId] = (usedMass[layer.materialId] or 0) + mass
		end
		for matId, mass in usedMass do
			local have = inventory[matId] or 0
			if mass > have + 1e-6 then
				local name = string.lower(materialById(matId).name)
				return "You need more " .. name .. " than you found. Try thinner layers."
			end
		end
	else
		-- Legacy fallback
		if design.shellMaterialId ~= nil then
			local have = inventory[design.shellMaterialId] or 0
			if shellMassKg(design) > have + 1e-6 then
				local name = string.lower(materialById(design.shellMaterialId).name)
				return "That shell is heavier than the " .. name .. " you found. Try a smaller suit."
			end
		end
		if design.insulationMaterialId ~= nil then
			local have = inventory[design.insulationMaterialId] or 0
			if insulationMassKg(design) > have + 1e-6 then
				local name = string.lower(materialById(design.insulationMaterialId).name)
				return "That wrap is heavier than the " .. name .. " you found. Try a smaller suit."
			end
		end
	end
	local oxygen = inventory.oxygen or 0
	if design.oxygenKg > oxygen + 1e-6 then
		return "You packed more oxygen than you found."
	end
	return nil
end

local function isSealed(design): boolean
	if design.shellMaterialId == nil or design.shellThicknessM <= 0 then
		return false
	end
	if design.shellRadiusM <= design.shellThicknessM then
		return false
	end
	return materialById(design.shellMaterialId).structural
end

local SIZES = {
	fits = { shellRadiusM = 0.48, shellThicknessM = 0.0016, insulationThicknessM = 0.012 },
	bigger = { shellRadiusM = 0.55, shellThicknessM = 0.002, insulationThicknessM = 0.012 },
	bulky = { shellRadiusM = 0.7, shellThicknessM = 0.004, insulationThicknessM = 0.02 },
}

return {
	TANK_KG_PER_OXYGEN_KG = TANK_KG_PER_OXYGEN_KG,
	BASE_RADIUS_M = BASE_RADIUS_M,
	THICKNESS_OPTIONS = THICKNESS_OPTIONS,
	SIZES = SIZES,
	emptyDesign = emptyDesign,
	syncLegacy = syncLegacy,
	shellMaterialId = getShellMaterialId,
	outerRadiusM = outerRadiusM,
	shellThicknessM = getShellThicknessM,
	shellMassKg = shellMassKg,
	insulationMassKg = insulationMassKg,
	designMassKg = designMassKg,
	stockProblem = stockProblem,
	isSealed = isSealed,
}
