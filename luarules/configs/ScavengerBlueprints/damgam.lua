
-- table.insert(ScavengerBlueprintsStart,FunctionName)
-- table.insert(ScavengerBlueprintsT1,FunctionName)
-- table.insert(ScavengerBlueprintsT2,FunctionName)
-- table.insert(ScavengerBlueprintsT3,FunctionName)
-- table.insert(ScavengerBlueprintsStartSea,FunctionName)
-- table.insert(ScavengerBlueprintsT1Sea,FunctionName)
-- table.insert(ScavengerBlueprintsT2Sea,FunctionName)
-- table.insert(ScavengerBlueprintsT3Sea,FunctionName)

-- example blueprint:
-- local function a(posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 120
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.CreateUnit("corrad", posx, posy, posz, math.random(0,3),GaiaTeamID) 
		-- Spring.CreateUnit("corllt", posx-100, posy, posz, math.random(0,3),GaiaTeamID) 
		-- Spring.CreateUnit("corllt", posx+100, posy, posz, math.random(0,3),GaiaTeamID) 
		-- Spring.CreateUnit("corllt", posx, posy, posz-100, math.random(0,3),GaiaTeamID) 
		-- Spring.CreateUnit("corllt", posx, posy, posz+100, math.random(0,3),GaiaTeamID) 
	-- end
-- end
-- table.insert(ScavengerBlueprintsT1,a)

-- Lonely Buildings

local function cloakedfus(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armckfus", posx, posy, posz, math.random(0,3),GaiaTeamID) 

	end
end
table.insert(ScavengerBlueprintsT2,cloakedfus)
table.insert(ScavengerBlueprintsT3,cloakedfus)

local function underwaterfus(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("coruwfus", posx, posy, posz, math.random(0,3),GaiaTeamID) 

	end
end
table.insert(ScavengerBlueprintsT3Sea,underwaterfus)
table.insert(ScavengerBlueprintsT2Sea,underwaterfus)


-- Lonely Radars

local function radarcore(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corrad", posx, posy, posz, math.random(0,3),GaiaTeamID) 

	end
end
table.insert(ScavengerBlueprintsStart,radarcore)
table.insert(ScavengerBlueprintsT1,radarcore)

local function radararm(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armrad", posx, posy, posz, math.random(0,3),GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsStart,radararm)
table.insert(ScavengerBlueprintsT1,radararm)

local function aradarcore(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corarad", posx, posy, posz, math.random(0,3),GaiaTeamID) 

	end
end
table.insert(ScavengerBlueprintsT2,aradarcore)
table.insert(ScavengerBlueprintsT3,aradarcore)

local function aradararm(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armarad", posx, posy, posz, math.random(0,3),GaiaTeamID) 

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
		Spring.CreateUnit("corsonar", posx, posy, posz, math.random(0,3),GaiaTeamID) 

	end
end
table.insert(ScavengerBlueprintsStartSea,sonarcore)
table.insert(ScavengerBlueprintsT1Sea,sonarcore)

local function sonararm(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armsonar", posx, posy, posz, math.random(0,3),GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsStartSea,sonararm)
table.insert(ScavengerBlueprintsT1Sea,sonararm)

local function asonarcore(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corason", posx, posy, posz, math.random(0,3),GaiaTeamID) 

	end
end
table.insert(ScavengerBlueprintsT2Sea,asonarcore)
table.insert(ScavengerBlueprintsT3Sea,asonarcore)

local function asonararm(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armason", posx, posy, posz, math.random(0,3),GaiaTeamID) 

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
		Spring.CreateUnit("armtl", posx, posy, posz, math.random(0,3),GaiaTeamID, false, false) 

	end
end
table.insert(ScavengerBlueprintsT1Sea,torpedoblue)
table.insert(ScavengerBlueprintsT2Sea,torpedoblue)

local function atorpedored(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 50
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("coratl", posx, posy, posz, math.random(0,3),GaiaTeamID, false, false) 

	end
end
table.insert(ScavengerBlueprintsT2Sea,atorpedored)
table.insert(ScavengerBlueprintsT3Sea,atorpedored)