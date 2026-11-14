local function sibling(name: string)
	if script ~= nil and script.Parent ~= nil then
		local child = script.Parent:FindFirstChild(name)
		if child ~= nil then
			return require(child)
		end
	end
	return require("./" .. name)
end

local PLANETS = sibling("Planets")
local MATERIALS = sibling("Materials")
local DIFFICULTIES = sibling("Difficulty")

local FACT_SHEET_HOST = "https://nssdc.gsfc.nasa.gov/planetary/factsheet/"

local function planetById(id: string)
	for _, planet in PLANETS do
		if planet.id == id then
			return planet
		end
	end
	error("Unknown body: " .. id)
end

local function materialById(id: string)
	for _, material in MATERIALS do
		if material.id == id then
			return material
		end
	end
	error("Unknown material: " .. id)
end

local function difficultyById(id: string)
	for _, profile in DIFFICULTIES do
		if profile.id == id then
			return profile
		end
	end
	error("Unknown difficulty: " .. id)
end

local function assertFactSheetRecords(planets)
	local seen = {}
	for _, planet in planets do
		if seen[planet.id] then
			error("Duplicate body id: " .. planet.id)
		end
		seen[planet.id] = true
		if string.sub(planet.sourceUrl, 1, #FACT_SHEET_HOST) ~= FACT_SHEET_HOST then
			error(planet.id .. " source is not an NSSDC fact sheet")
		end
		if not (planet.gravityMs2 > 0) then
			error(planet.id .. " is missing gravity")
		end
		if not (planet.solarIrradianceWm2 > 0) then
			error(planet.id .. " is missing solar irradiance")
		end
		if planet.gravityDatum == "1bar" and planet.referencePressure.value ~= 100000 then
			error(planet.id .. " 1-bar datum must start at 100000 Pa")
		end
		if planet.texture ~= nil then
			error(planet.id .. " texture is not loaded yet")
		end
	end
end

return {
	PLANETS = PLANETS,
	MATERIALS = MATERIALS,
	DIFFICULTIES = DIFFICULTIES,
	planetById = planetById,
	materialById = materialById,
	difficultyById = difficultyById,
	assertFactSheetRecords = assertFactSheetRecords,
}
