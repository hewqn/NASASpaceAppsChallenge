-- Limits of an unprotected human used to Earth. These are not planet-sheet numbers.

local HUMAN = {
	massKg = 70,
	metabolicW = 100,
	specificHeatJPerKgK = 3470,
	areaM2 = 1.8,
	emissivity = 0.97,
	coreK = 310.15,
	freezeK = 308.15,
	burnK = 313.15,
	comfortMinK = 282,
	comfortMaxK = 303.15,
	armstrongPa = 6300,
	minOxygenPartialPa = 16000,
	oxygenKgPerDay = 0.84,
	lungOxygenKg = 0.002,
}

local STEFAN_BOLTZMANN = 5.670374419e-8

local function celsius(kelvin: number): number
	return kelvin - 273.15
end

return {
	HUMAN = HUMAN,
	STEFAN_BOLTZMANN = STEFAN_BOLTZMANN,
	celsius = celsius,
}
