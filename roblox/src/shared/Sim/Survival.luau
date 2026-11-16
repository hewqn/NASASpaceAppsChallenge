local function sibling(name: string)
	if script ~= nil and script.Parent ~= nil then
		local child = script.Parent:FindFirstChild(name)
		if child ~= nil then
			return require(child)
		end
	end
	return require("./" .. name)
end

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
local planetById = Catalog.planetById
local materialById = Catalog.materialById
local Design = sibling("Design")
local isSealed = Design.isSealed
local Human = sibling("Human")
local HUMAN = Human.HUMAN
local STEFAN_BOLTZMANN = Human.STEFAN_BOLTZMANN
local celsius = Human.celsius

local MISSION_SECONDS = 20 * 60
local VACUUM_FAIL_S = 90

local function outsidePressurePa(planet): number
	if planet.referencePressure.value ~= nil then
		return planet.referencePressure.value
	end
	if planet.referencePressure.max ~= nil then
		return planet.referencePressure.max
	end
	return 0
end

local function oxygenFraction(planet): number
	local text = string.lower(planet.atmosphereComposition)
	local match = string.match(text, "(%d+%.?%d*)%% oxygen")
	if match == nil then
		return 0
	end
	return tonumber(match) / 100
end

local function extreme(reading, side: string): number?
	if side == "hot" then
		return reading.maxK or reading.kelvin
	end
	return reading.minK or reading.kelvin
end

local function exposure(planet, side: string)
	local best = nil
	for _, reading in planet.temperatures do
		local kelvin = extreme(reading, side)
		if kelvin ~= nil and (best == nil or (side == "hot" and kelvin > best.kelvin) or (side ~= "hot" and kelvin < best.kelvin)) then
			best = { kelvin = kelvin, transcribedFrom = reading.transcribedFrom }
		end
	end
	if best == nil then
		return { kelvin = HUMAN.coreK, transcribedFrom = "This sheet does not list a temperature." }
	end
	return best
end

local function shellSafetyFactor(design, outsidePa: number): number?
	if not isSealed(design) or design.shellMaterialId == nil then
		return nil
	end
	local material = materialById(design.shellMaterialId)
	local earthPa = planetById("earth").referencePressure.value or 101400
	local deltaPa = math.abs(outsidePa - earthPa)
	local radius = design.shellRadiusM - design.shellThicknessM
	local stress = (deltaPa * radius) / (2 * design.shellThicknessM)
	if stress <= 0 then
		return math.huge
	end
	return material.yieldPa / stress
end

local function breathableAir(planet, outsidePa: number): boolean
	return oxygenFraction(planet) * outsidePa >= HUMAN.minOxygenPartialPa
end

local function earthlikeComfort(planet, outsidePa: number, ambientK: number): boolean
	return breathableAir(planet, outsidePa)
		and outsidePa >= HUMAN.armstrongPa
		and ambientK >= HUMAN.comfortMinK
		and ambientK <= HUMAN.comfortMaxK
end

local function heatFlowW(design, sealed: boolean, outsidePa: number, bodyK: number, ambientK: number): number
	local area = HUMAN.areaM2
	if not sealed and outsidePa < 100 then
		return HUMAN.emissivity * STEFAN_BOLTZMANN * area * (ambientK ^ 4 - bodyK ^ 4)
	end
	local wrap = nil
	if design.insulationMaterialId ~= nil and design.insulationThicknessM > 0 then
		wrap = materialById(design.insulationMaterialId)
	end
	if sealed and wrap ~= nil and ambientK < wrap.meltingK then
		return (wrap.conductivity * area * (ambientK - bodyK)) / design.insulationThicknessM
	end
	if sealed and design.shellMaterialId ~= nil and design.shellThicknessM > 0 then
		local shell = materialById(design.shellMaterialId)
		return (shell.conductivity * area * (ambientK - bodyK)) / design.shellThicknessM
	end
	return 10 * area * (ambientK - bodyK)
end

local function initialVitals(design)
	return {
		bodyTempK = HUMAN.coreK,
		oxygenKg = design.oxygenKg + HUMAN.lungOxygenKg,
		elapsedS = 0,
		alive = true,
		cause = nil,
	}
end

local function stepVitals(vitals, design, planet, minSafetyFactor: number, side: string, dt: number)
	if not vitals.alive or dt <= 0 then
		return vitals
	end
	local outsidePa = outsidePressurePa(planet)
	local ambientK = exposure(planet, side).kelvin
	local sealed = isSealed(design)
	local cause = nil
	local bodyTempK = vitals.bodyTempK
	local oxygenKg = vitals.oxygenKg

	if not sealed and outsidePa < HUMAN.armstrongPa then
		if vitals.elapsedS + dt >= VACUUM_FAIL_S then
			cause = "pressure"
		end
	elseif sealed and design.shellMaterialId ~= nil and ambientK >= materialById(design.shellMaterialId).meltingK then
		cause = "burn"
	elseif sealed then
		local factor = shellSafetyFactor(design, outsidePa)
		if factor ~= nil and factor < minSafetyFactor then
			cause = "crush"
		end
	end

	if cause == nil then
		local regulating = (not sealed) and earthlikeComfort(planet, outsidePa, ambientK)
		if not regulating then
			local flow = heatFlowW(design, sealed, outsidePa, bodyTempK, ambientK) + HUMAN.metabolicW
			bodyTempK += (flow * dt) / (HUMAN.massKg * HUMAN.specificHeatJPerKgK)
		end
		if not (breathableAir(planet, outsidePa) and not sealed) then
			oxygenKg -= (HUMAN.oxygenKgPerDay / 86400) * dt
			if oxygenKg <= 0 then
				oxygenKg = 0
				cause = "oxygen"
			end
		end
		if bodyTempK >= HUMAN.burnK and cause == nil then
			cause = "burn"
		end
		if bodyTempK <= HUMAN.freezeK and cause == nil then
			cause = "freeze"
		end
	end

	return {
		bodyTempK = bodyTempK,
		oxygenKg = math.max(0, oxygenKg),
		elapsedS = vitals.elapsedS + dt,
		alive = cause == nil,
		cause = cause,
	}
end

local function runMission(design, planet, minSafetyFactor: number, side: string)
	local state = initialVitals(design)
	while state.alive and state.elapsedS < MISSION_SECONDS do
		local dt = math.min(5, MISSION_SECONDS - state.elapsedS)
		state = stepVitals(state, design, planet, minSafetyFactor, side, dt)
	end
	return state
end

local function deathTitle(cause: string): string
	if cause == "pressure" then
		return "The air pressure gave out."
	elseif cause == "oxygen" then
		return "You ran out of oxygen."
	elseif cause == "burn" then
		return "You burned."
	elseif cause == "freeze" then
		return "You froze."
	end
	return "The shell was crushed."
end

local function deathDetail(planet, side: string, cause: string): string
	local earth = planetById("earth")
	local stay = exposure(planet, side)
	local earthAverage = nil
	for _, reading in earth.temperatures do
		if reading.kelvin ~= nil then
			earthAverage = reading.kelvin
			break
		end
	end
	if earthAverage == nil then
		earthAverage = exposure(earth, "hot").kelvin
	end
	local earthAir = "Your body is used to Earth: about "
		.. string.format("%.0f", celsius(earthAverage))
		.. " °C, "
		.. earth.referencePressure.transcribedFrom
		.. ", and air that is "
		.. string.format("%d", math.floor(oxygenFraction(earth) * 100 + 0.5))
		.. "% oxygen."
	if cause == "pressure" then
		return earthAir
			.. " Here the pressure is too low to keep a human body intact (the Armstrong limit is about 6.3 kPa). "
			.. planet.referencePressure.transcribedFrom
	elseif cause == "oxygen" then
		return earthAir
			.. " This stay does not give you that oxygen, and the bottles you packed ran out. A person needs about "
			.. tostring(HUMAN.oxygenKgPerDay)
			.. " kg per day."
	elseif cause == "burn" then
		return earthAir
			.. " Your core climbed through "
			.. string.format("%.0f", celsius(HUMAN.burnK))
			.. " °C. The place you stood was "
			.. tostring(stay.kelvin)
			.. " K. "
			.. stay.transcribedFrom
	elseif cause == "freeze" then
		return earthAir
			.. " Your core fell through "
			.. string.format("%.0f", celsius(HUMAN.freezeK))
			.. " °C. The place you stood was "
			.. tostring(stay.kelvin)
			.. " K. "
			.. stay.transcribedFrom
	end
	return earthAir .. " Outside pressure overcame the shell. " .. planet.referencePressure.transcribedFrom
end

local function survived(vitals): boolean
	return vitals.alive and vitals.elapsedS >= MISSION_SECONDS - 1e-6
end

local function kidResult(design, planet, minSafetyFactor: number, side: string): string
	local where = if side == "hot" then "Hot side" else "Cold side"
	local result = runMission(design, planet, minSafetyFactor, side)
	if survived(result) then
		return where .. ": you would last."
	elseif result.cause == "pressure" then
		return where .. ": the air would vanish."
	elseif result.cause == "oxygen" then
		return where .. ": you would run out of air."
	elseif result.cause == "burn" then
		return where .. ": you would get too hot."
	elseif result.cause == "freeze" then
		return where .. ": you would freeze."
	end
	return where .. ": the shell would be crushed."
end

return {
	MISSION_SECONDS = MISSION_SECONDS,
	VACUUM_FAIL_S = VACUUM_FAIL_S,
	outsidePressurePa = outsidePressurePa,
	oxygenFraction = oxygenFraction,
	exposure = exposure,
	shellSafetyFactor = shellSafetyFactor,
	initialVitals = initialVitals,
	stepVitals = stepVitals,
	runMission = runMission,
	deathTitle = deathTitle,
	deathDetail = deathDetail,
	survived = survived,
	kidResult = kidResult,
	celsius = celsius,
}
