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

local CAUSE_TAGS = {
	pressure = { "pressure", "oxygen" },
	oxygen = { "oxygen" },
	burn = { "temperature" },
	freeze = { "temperature" },
	crush = { "pressure" },
	survive = { "pressure", "temperature", "oxygen" },
}

local function hasTag(tags, wanted)
	for _, tag in tags do
		for _, need in wanted do
			if tag == need then
				return true
			end
		end
	end
	return false
end

local function chunksFor(planet)
	local chunks = {
		{
			id = planet.id .. "-pressure",
			planetId = planet.id,
			tags = { "pressure" },
			text = planet.referencePressure.transcribedFrom,
			sourceUrl = planet.sourceUrl,
		},
		{
			id = planet.id .. "-air",
			planetId = planet.id,
			tags = { "oxygen", "pressure" },
			text = planet.atmosphereTranscribedFrom,
			sourceUrl = planet.sourceUrl,
		},
	}
	for index, reading in planet.temperatures do
		table.insert(chunks, {
			id = planet.id .. "-temp-" .. tostring(index),
			planetId = planet.id,
			tags = { "temperature" },
			text = reading.transcribedFrom,
			sourceUrl = planet.sourceUrl,
		})
	end
	table.insert(chunks, {
		id = planet.id .. "-gravity",
		planetId = planet.id,
		tags = { "gravity" },
		text = planet.gravityTranscribedFrom,
		sourceUrl = planet.sourceUrl,
	})
	return chunks
end

local function filterChunks(chunks, tags)
	local kept = {}
	for _, chunk in chunks do
		if hasTag(chunk.tags, tags) then
			table.insert(kept, chunk)
		end
	end
	return kept
end

local function take(list, count)
	local out = {}
	for index, item in list do
		if index > count then
			break
		end
		table.insert(out, item)
	end
	return out
end

-- Planet lines for this outcome, then Earth's matching lines. No model invents a number.
local function retrieve(planet, cause: string)
	local tags = CAUSE_TAGS[cause]
	local here = filterChunks(chunksFor(planet), tags)
	if planet.id == "earth" then
		return take(here, 4)
	end
	local home = filterChunks(chunksFor(planetById("earth")), tags)
	local combined = {}
	for _, chunk in here do
		table.insert(combined, chunk)
	end
	for _, chunk in home do
		table.insert(combined, chunk)
	end
	return take(combined, 4)
end

return {
	retrieve = retrieve,
}
