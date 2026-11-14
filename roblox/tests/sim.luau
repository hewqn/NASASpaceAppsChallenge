local Catalog = require("../src/shared/Data/Catalog")
local Physics = require("../src/shared/Sim/Physics")
local Design = require("../src/shared/Sim/Design")
local Survival = require("../src/shared/Sim/Survival")
local Retrieve = require("../src/shared/Sim/Retrieve")
local Sources = require("../src/shared/Data/Sources")

local failures = 0

local function check(name: string, ok: boolean, detail: string?)
	if ok then
		print("ok  " .. name)
	else
		failures += 1
		print("FAIL " .. name .. (if detail then "  " .. detail else ""))
	end
end

local function close(actual: number, expected: number): boolean
	return math.abs(actual - expected) <= 0.001 * math.max(1, math.abs(expected))
end

Catalog.assertFactSheetRecords(Catalog.PLANETS)
local ids = {}
for _, planet in Catalog.PLANETS do
	table.insert(ids, planet.id)
end
check("nine fact sheets", table.concat(ids, ",") == "earth,moon,mercury,venus,mars,jupiter,saturn,uranus,neptune")

local moon = Catalog.planetById("moon")
local venus = Catalog.planetById("venus")
local jupiter = Catalog.planetById("jupiter")
local neptune = Catalog.planetById("neptune")
local mercury = Catalog.planetById("mercury")
check("moon gravity", moon.gravityMs2 == 1.62)
check("venus pressure", venus.referencePressure.value == 92 * Physics.ONE_BAR_PA)
check("jupiter 1 bar", jupiter.gravityDatum == "1bar" and jupiter.gravityMs2 == 25.92 and jupiter.referencePressure.value == Physics.ONE_BAR_PA)
check("jupiter temperature", jupiter.temperatures[1].kelvin == 165 and jupiter.scaleHeightM.value == 27000)
check("neptune range", neptune.scaleHeightM.value == nil and neptune.scaleHeightM.min == 19100 and neptune.scaleHeightM.max == 20300)
check("mercury pressure bound", mercury.referencePressure.value == nil and mercury.referencePressure.max == 5e-10)
check("solar panel", close(Physics.solarPanelPowerW(moon.solarIrradianceWm2, 1, 0.2), 272.2))
check("moon fall is longer", Physics.freeFallTimeS(6, 1.62) > Physics.freeFallTimeS(6, 9.82))
check("weight", close(Physics.weightNewtons(10, 1.62), 16.2))
check("destinations", #Sources.DESTINATION_ORDER == 8)

local function suited(extra)
	local design = {
		shellMaterialId = "aluminum",
		shellRadiusM = 0.55,
		shellThicknessM = 0.004,
		insulationMaterialId = "aerogel",
		insulationThicknessM = 0.02,
		oxygenKg = 1,
	}
	if extra then
		for key, value in pairs(extra) do
			design[key] = value
		end
	end
	return design
end

local earthStay = Survival.runMission(Design.emptyDesign(), Catalog.planetById("earth"), 1.5, "hot")
check("earth stand", Survival.survived(earthStay) and close(Survival.celsius(earthStay.bodyTempK), 37))

local bareMoon = Survival.runMission(Design.emptyDesign(), moon, 1.5, "hot")
check("moon vacuum", bareMoon.cause == "pressure" and Survival.outsidePressurePa(moon) < 6300)

local bare = suited(nil)
bare.insulationMaterialId = nil
local bareShell = Survival.runMission(bare, moon, 1.5, "hot")
local wrapped = Survival.runMission(suited(nil), moon, 1.5, "hot")
check("moon heat", bareShell.cause == "burn" and Survival.survived(wrapped))
check("moon range", Survival.exposure(moon, "hot").kelvin == 390 and Survival.exposure(moon, "cold").kelvin == 95)

local noAir = Survival.runMission(suited({ oxygenKg = 0 }), moon, 1.5, "cold")
check("oxygen", noAir.cause == "oxygen")

local crushed = Survival.runMission(suited(nil), venus, 1.5, "hot")
local openSuit = suited(nil)
openSuit.shellMaterialId = nil
openSuit.insulationMaterialId = nil
local frozen = Survival.runMission(openSuit, jupiter, 1.5, "hot")
check("venus crush", crushed.cause == "crush")
check("jupiter freeze", frozen.cause == "freeze" and Survival.exposure(jupiter, "hot").kelvin == 165)

local facts = Retrieve.retrieve(moon, "pressure")
local sawMoon = false
local sawEarth = false
for _, fact in facts do
	if string.find(fact.text, "3 x 10^-15 bar", 1, true) then
		sawMoon = true
	end
	if string.sub(fact.sourceUrl, -#"earthfact.html") == "earthfact.html" then
		sawEarth = true
	end
end
check("retrieve pressure", sawMoon and sawEarth)

local heat = Retrieve.retrieve(moon, "burn")
local sawHeat = false
for _, fact in heat do
	if string.find(fact.text, "95 K to 390 K", 1, true) then
		sawHeat = true
	end
end
check("retrieve heat", sawHeat)

if failures > 0 then
	error(tostring(failures) .. " failed")
end
print("all checks passed")
