
-- table.insert(ScavengerBlueprintsT0,FunctionName)
-- table.insert(ScavengerBlueprintsT1,FunctionName)
-- table.insert(ScavengerBlueprintsT2,FunctionName)
-- table.insert(ScavengerBlueprintsT3,FunctionName)
-- table.insert(ScavengerBlueprintsT0Sea,FunctionName)
-- table.insert(ScavengerBlueprintsT1Sea,FunctionName)
-- table.insert(ScavengerBlueprintsT2Sea,FunctionName)
-- table.insert(ScavengerBlueprintsT3Sea,FunctionName)

-- example blueprint:
-- local function a(posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 120
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.CreateUnit("corrad", posx, posy, posz, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("corllt", posx-100, posy, posz, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("corllt", posx+100, posy, posz, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("corllt", posx, posy, posz-100, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("corllt", posx, posy, posz+100, math_random(0,3),GaiaTeamID)
	-- end
-- end
-- table.insert(ScavengerBlueprintsT1,a)

-- Lonely Buildings

local nameSuffix = '_scav'

local function cloakedfus(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armckfus"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, false, false)

	end
end
table.insert(ScavengerBlueprintsT2,cloakedfus)
table.insert(ScavengerBlueprintsT3,cloakedfus)

local function underwaterfus(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("coruwfus"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, false, false)

	end
end
table.insert(ScavengerBlueprintsT3Sea,underwaterfus)
table.insert(ScavengerBlueprintsT2Sea,underwaterfus)

local function fakefusblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armdf"..nameSuffix, posx, posy, posz, "north",GaiaTeamID)

	end
end
table.insert(ScavengerBlueprintsT2,fakefusblue)

local function targblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armtarg"..nameSuffix, posx, posy, posz, "north",GaiaTeamID)

	end
end
table.insert(ScavengerBlueprintsT3,targblue)
