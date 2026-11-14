local ONE_BAR_PA = 100000

-- Roblox tunes the avatar for 196.2. Scale every fact-sheet gravity by Earth,
-- so the Moon is 1.62/9.82 of a normal Roblox jump, not 1.62 studs/s².
local ROBLOX_EARTH_GRAVITY = 196.2

local function weightNewtons(massKg: number, gravityMs2: number): number
	return massKg * gravityMs2
end

local function pressureAtAltitude(referencePa: number, scaleHeightM: number, altitudeM: number): number
	return referencePa * math.exp(-altitudeM / scaleHeightM)
end

local function solarPanelPowerW(irradianceWm2: number, areaM2: number, efficiency: number): number
	return irradianceWm2 * areaM2 * efficiency
end

local function safetyFactor(yieldPa: number, stressPa: number): number
	return yieldPa / stressPa
end

local function passesSafetyFactor(yieldPa: number, stressPa: number, minSafetyFactor: number): boolean
	return safetyFactor(yieldPa, stressPa) >= minSafetyFactor
end

local function freeFallTimeS(heightM: number, gravityMs2: number): number
	return math.sqrt((2 * heightM) / gravityMs2)
end

local function gravityStuds(gravityMs2: number, earthGravityMs2: number): number
	return ROBLOX_EARTH_GRAVITY * (gravityMs2 / earthGravityMs2)
end

return {
	ONE_BAR_PA = ONE_BAR_PA,
	ROBLOX_EARTH_GRAVITY = ROBLOX_EARTH_GRAVITY,
	weightNewtons = weightNewtons,
	pressureAtAltitude = pressureAtAltitude,
	solarPanelPowerW = solarPanelPowerW,
	safetyFactor = safetyFactor,
	passesSafetyFactor = passesSafetyFactor,
	freeFallTimeS = freeFallTimeS,
	gravityStuds = gravityStuds,
}
