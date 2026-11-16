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

local function emptyDesign()
	return {
		shellMaterialId = nil,
		shellRadiusM = 0.48,
		shellThicknessM = 0.0016,
		insulationMaterialId = nil,
		insulationThicknessM = 0.012,
		oxygenKg = 0,
	}
end

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

local function stockProblem(design, inventory): string?
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
	SIZES = SIZES,
	emptyDesign = emptyDesign,
	shellMassKg = shellMassKg,
	insulationMassKg = insulationMassKg,
	designMassKg = designMassKg,
	stockProblem = stockProblem,
	isSealed = isSealed,
}
