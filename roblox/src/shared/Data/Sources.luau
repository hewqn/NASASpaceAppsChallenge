-- Pages this build actually reads. Submission lists should match this file.

local NASA_FACT_SHEET_INDEX = "https://nssdc.gsfc.nasa.gov/planetary/planetfact.html"
local NASA_FACT_SHEET_NOTES = "https://nssdc.gsfc.nasa.gov/planetary/factsheet/planetfact_notes.html"
local NASA_PARAMETER_NOTES = "https://nssdc.gsfc.nasa.gov/planetary/factsheet/fact_notes.html"

local DESTINATION_ORDER = {
	"moon",
	"mars",
	"mercury",
	"venus",
	"jupiter",
	"saturn",
	"uranus",
	"neptune",
}

return {
	NASA_FACT_SHEET_INDEX = NASA_FACT_SHEET_INDEX,
	NASA_FACT_SHEET_NOTES = NASA_FACT_SHEET_NOTES,
	NASA_PARAMETER_NOTES = NASA_PARAMETER_NOTES,
	DESTINATION_ORDER = DESTINATION_ORDER,
}
