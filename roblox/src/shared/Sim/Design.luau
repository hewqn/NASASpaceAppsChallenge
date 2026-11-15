-- Freeform layered suit design for CODAG.0.
-- Players stack layers in any order. Each layer is a material at a thickness.
-- The outermost structural layer bears pressure. Heat flows through every layer.

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
local HUMAN_AREA_M2 = 1.8
local BASE_RADIUS_M = 0.48

-- Layer thickness options (meters)
local THICKNESS_OPTIONS = {
	{ id = "thin",   label = "Thin",   meters = 0.002  },
	{ id = "medium", label = "Medium", meters = 0.006  },
	{ id = "thick",  label = "Thick",  meters = 0.012  },
	{ id = "heavy",  label = "Heavy",  meters = 0.025  },
}

local function emptyDesign()
	return {
		layers = {},       -- array of {materialId, thicknessM}
		oxygenKg = 0,
	}
end

-- Total outer radius: base + sum of layer thicknesses
local function outerRadiusM(design): number
	local r = BASE_RADIUS_M
	for _, layer in design.layers do
		r += layer.thicknessM
	end
	return r
end

-- Surface area at a given radius
local function areaAtRadius(radius: number): number
	return 4 * math.pi * radius * radius
end

-- Mass of a single spherical-shell layer
local function layerMassKg(layer, innerRadius: number): number
	local mat = materialById(layer.materialId)
	local outerR = innerRadius + layer.thicknessM
	local volume = (4 / 3) * math.pi * (outerR ^ 3 - innerRadius ^ 3)
	return mat.densityKgM3 * volume
end

-- Total mass of all layers + oxygen + tank hardware
local function designMassKg(design): number
	local total = 0
	local r = BASE_RADIUS_M
	for _, layer in design.layers do
		total += layerMassKg(layer, r)
		r += layer.thicknessM
	end
	total += design.oxygenKg + design.oxygenKg * TANK_KG_PER_OXYGEN_KG
	return total
end

-- Mass of a single material across all layers that use it
local function materialMassKg(design, materialId: string): number
	local total = 0
	local r = BASE_RADIUS_M
	for _, layer in design.layers do
		if layer.materialId == materialId then
			total += layerMassKg(layer, r)
		end
		r += layer.thicknessM
	end
	return total
end

-- Is the suit sealed? Needs at least one structural layer.
local function isSealed(design): boolean
	for _, layer in design.layers do
		local mat = materialById(layer.materialId)
		if mat.structural and layer.thicknessM > 0 then
			return true
		end
	end
	return false
end

-- Find the outermost structural layer (faces the environment pressure).
local function outerStructuralLayer(design)
	local best = nil
	local bestIndex = 0
	for i, layer in design.layers do
		local mat = materialById(layer.materialId)
		if mat.structural and layer.thicknessM > 0 then
			if i > bestIndex then
				best = layer
				bestIndex = i
			end
		end
	end
	return best
end

-- Radius at which the outer structural layer sits
local function outerStructuralRadius(design): number
	local bestIndex = 0
	for i, layer in design.layers do
		local mat = materialById(layer.materialId)
		if mat.structural and layer.thicknessM > 0 then
			if i > bestIndex then
				bestIndex = i
			end
		end
	end
	local r = BASE_RADIUS_M
	for i, layer in design.layers do
		if i == bestIndex then
			return r
		end
		r += layer.thicknessM
	end
	return r
end

-- Effective thermal resistance through all layers (K/W).
-- Heat flows inward from environment through each layer in series.
local function thermalResistance(design, outsidePa: number): number
	local totalR = 0
	local r = BASE_RADIUS_M
	for _, layer in design.layers do
		local mat = materialById(layer.materialId)
		local k = mat.conductivity
		-- Mylar-type materials are much better insulators in vacuum
		if mat.vacuumConductivity ~= nil and outsidePa < 1000 then
			k = mat.vacuumConductivity
		end
		if k > 0 and layer.thicknessM > 0 then
			local area = areaAtRadius(r + layer.thicknessM / 2)
			totalR += layer.thicknessM / (k * area)
		end
		r += layer.thicknessM
	end
	return totalR
end

-- Check whether you have enough of each material in inventory.
local function stockProblem(design, inventory): string?
	-- Check each material used in layers
	local usedKg = {}
	local r = BASE_RADIUS_M
	for _, layer in design.layers do
		usedKg[layer.materialId] = (usedKg[layer.materialId] or 0) + layerMassKg(layer, r)
		r += layer.thicknessM
	end
	for matId, needed in usedKg do
		local have = inventory[matId] or 0
		if needed > have + 1e-6 then
			local name = materialById(matId).name
			return name .. " needs " .. string.format("%.1f", needed) .. " kg but you only have " .. string.format("%.1f", have) .. " kg."
		end
	end
	-- Check oxygen
	local oxygenHave = inventory.oxygen or 0
	if design.oxygenKg > oxygenHave + 1e-6 then
		return "You packed more oxygen than you found."
	end
	return nil
end

-- For backward compatibility: shell info for the publicDesign format
local function shellMaterialId(design): string?
	local structural = outerStructuralLayer(design)
	if structural then
		return structural.materialId
	end
	return nil
end

local function shellThicknessM(design): number
	local structural = outerStructuralLayer(design)
	if structural then
		return structural.thicknessM
	end
	return 0
end

return {
	TANK_KG_PER_OXYGEN_KG = TANK_KG_PER_OXYGEN_KG,
	BASE_RADIUS_M = BASE_RADIUS_M,
	THICKNESS_OPTIONS = THICKNESS_OPTIONS,
	HUMAN_AREA_M2 = HUMAN_AREA_M2,
	emptyDesign = emptyDesign,
	outerRadiusM = outerRadiusM,
	designMassKg = designMassKg,
	materialMassKg = materialMassKg,
	isSealed = isSealed,
	outerStructuralLayer = outerStructuralLayer,
	outerStructuralRadius = outerStructuralRadius,
	thermalResistance = thermalResistance,
	stockProblem = stockProblem,
	shellMaterialId = shellMaterialId,
	shellThicknessM = shellThicknessM,
	layerMassKg = layerMassKg,
}
