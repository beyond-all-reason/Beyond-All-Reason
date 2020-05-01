
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

-- Lonely Radars

local nameSuffix = '_scav'


local function radarcore(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corrad"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)

	end
end
table.insert(ScavengerBlueprintsT0,radarcore)
table.insert(ScavengerBlueprintsT1,radarcore)

local function radararm(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armrad"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT0,radararm)
table.insert(ScavengerBlueprintsT1,radararm)

local function aradarcore(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corarad"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)

	end
end
table.insert(ScavengerBlueprintsT2,aradarcore)
table.insert(ScavengerBlueprintsT3,aradarcore)

local function aradararm(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armarad"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)

	end
end
table.insert(ScavengerBlueprintsT2,aradararm)
table.insert(ScavengerBlueprintsT3,aradararm)


-- Lonely Sonars

local function sonarcore(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corsonar"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)

	end
end
table.insert(ScavengerBlueprintsT0Sea,sonarcore)
table.insert(ScavengerBlueprintsT1Sea,sonarcore)

local function sonararm(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armsonar"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT0Sea,sonararm)
table.insert(ScavengerBlueprintsT1Sea,sonararm)

local function asonarcore(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corason"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)

	end
end
table.insert(ScavengerBlueprintsT2Sea,asonarcore)
table.insert(ScavengerBlueprintsT3Sea,asonarcore)

local function asonararm(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armason"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)

	end
end
table.insert(ScavengerBlueprintsT2Sea,asonararm)
table.insert(ScavengerBlueprintsT3Sea,asonararm)

-- Lonely Torpedolaunchers

local function torpedoblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armtl"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, false, false)

	end
end
table.insert(ScavengerBlueprintsT1Sea,torpedoblue)
table.insert(ScavengerBlueprintsT2Sea,torpedoblue)

local function atorpedored(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("coratl"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID, false, false)

	end
end
table.insert(ScavengerBlueprintsT2Sea,atorpedored)
table.insert(ScavengerBlueprintsT3Sea,atorpedored)
