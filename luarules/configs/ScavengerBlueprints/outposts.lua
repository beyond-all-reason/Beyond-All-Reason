
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


-- LIGHT RADAR OUTPOSTS
-- Outpost CORE

local function radaroutpostred(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"corllt", "corllt", "corhllt", "cormaw", "corrl",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corarad", posx, posy, posz, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-100, posy, posz, "west",GaiaTeamID) 
		Spring.CreateUnit("corjamt", posx+100, posy, posz, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz-100, "south",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz+100, "north",GaiaTeamID) 
	end
end
table.insert(ScavengerBlueprintsStart,radaroutpostred)
table.insert(ScavengerBlueprintsT1,radaroutpostred)

local function radaroutpostred2(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"corllt", "corllt", "corhllt", "corrad", "corerad",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-100, posy, posz, "west",GaiaTeamID) 
		Spring.CreateUnit("corjamt", posx, posy, posz, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz-100, "south",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz+100, "north",GaiaTeamID) 
	end
end
table.insert(ScavengerBlueprintsT1,radaroutpostred2)
table.insert(ScavengerBlueprintsT2,radaroutpostred2)

-- Outpost ARM

-- local function radaroutpostblue(posx, posy, posz, GaiaTeamID, radiusCheck)
-- local unitpool = {"armllt", "armllt", "armllt", "armclaw", "armrl",}
-- local posradius = 100
-- 	if radiusCheck then
-- 		return posradius
-- 	else
-- 		Spring.CreateUnit("armarad", posx, posy, posz, math.random(0,3),GaiaTeamID) 
-- 		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-100, posy, posz, "west",GaiaTeamID) 
-- 		Spring.CreateUnit("armjamt", posx+100, posy, posz, math.random(0,3),GaiaTeamID) 
-- 		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz-100, "south",GaiaTeamID) 
-- 		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz+100, "north",GaiaTeamID) 
-- 	end
-- end
-- table.insert(ScavengerBlueprintsStart,radaroutpostblue)
-- table.insert(ScavengerBlueprintsT1,radaroutpostblue)

-- local function radaroutpostblue2(posx, posy, posz, GaiaTeamID, radiusCheck)
-- local unitpool = {"armllt", "armllt", "armrad", "armdrag", "armcir",}
-- local posradius = 100
-- 	if radiusCheck then
-- 		return posradius
-- 	else
-- 		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-100, posy, posz, "west",GaiaTeamID) 
-- 		Spring.CreateUnit("armjamt", posx, posy, posz, math.random(0,3),GaiaTeamID) 
-- 		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz-100, "south",GaiaTeamID) 
-- 		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz+100, "north",GaiaTeamID) 
-- 	end
-- end
-- table.insert(ScavengerBlueprintsT1,radaroutpostblue2)
-- table.insert(ScavengerBlueprintsT2,radaroutpostblue2)


-- ROADBLOCKS
-- Roadblock CORE

local function roadblockred(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"cordrag", "cordrag", "cordrag", "cormaw", "cordrag",}
local posradius = 30
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-60, posy, posz-60, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-30, posy, posz-30, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+30, posy, posz+30, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+60, posy, posz+60, math.random(0,3),GaiaTeamID) 
	end
end
table.insert(ScavengerBlueprintsStart,roadblockred)
table.insert(ScavengerBlueprintsT1,roadblockred)

-- Roadblock ARM

local function roadblockblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"armdrag", "armdrag", "armdrag", "armclaw", "armdrag",}
local posradius = 30
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-60, posy, posz-60, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-30, posy, posz-30, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+30, posy, posz+30, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+60, posy, posz+60, math.random(0,3),GaiaTeamID) 
	end
end
table.insert(ScavengerBlueprintsStart,roadblockblue)
table.insert(ScavengerBlueprintsT1,roadblockblue)

-- MEDIUM AA OUTPOSTS
-- Medium Anti-Air Outpost CORE

local function aaoutpostmediumred(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 80
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corflak", posx-50, posy, posz-50, math.random(0,3),GaiaTeamID)
		Spring.CreateUnit("corflak", posx+50, posy, posz+50, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit("corshroud", posx-50, posy, posz+50, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit("corarad", posx+50, posy, posz-50, math.random(0,3),GaiaTeamID) 
	end
end
table.insert(ScavengerBlueprintsT2,aaoutpostmediumred)
table.insert(ScavengerBlueprintsT3,aaoutpostmediumred)

-- Medium Anti-Air Outpost ARM

-- local function aaoutpostmediumblue(posx, posy, posz, GaiaTeamID, radiusCheck)
-- local posradius = 80
-- 	if radiusCheck then
-- 		return posradius
-- 	else
-- 		Spring.CreateUnit("armflak", posx-50, posy, posz-50, math.random(0,3),GaiaTeamID)
-- 		Spring.CreateUnit("armflak", posx+50, posy, posz+50, math.random(0,3),GaiaTeamID) 
-- 		Spring.CreateUnit("armveil", posx-50, posy, posz+50, math.random(0,3),GaiaTeamID) 
-- 		Spring.CreateUnit("armarad", posx+50, posy, posz-50, math.random(0,3),GaiaTeamID) 
-- 	end
-- end
-- table.insert(ScavengerBlueprintsT2,aaoutpostmediumblue)
-- table.insert(ScavengerBlueprintsT3,aaoutpostmediumblue)



-- MEDIUM/HEAVY OUTPOSTS
-- Heavy Outpost CORE

local function radaroutpostmediumred(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"corhlt", "corhlt", "corhllt", "corvipe", "corflak",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corarad", posx, posy, posz, math.random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort", posx-30, posy, posz, math.random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort", posx, posy, posz-30, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit("corfort", posx+30, posy, posz, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit("corfort", posx, posy, posz+30, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit("corshroud", posx+90, posy, posz, math.random(0,3),GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT2,radaroutpostmediumred)
table.insert(ScavengerBlueprintsT3,radaroutpostmediumred)

local function radaroutpostheavyred(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"corhlt", "corhlt", "corhllt", "corvipe", "corflak",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corarad", posx, posy, posz, math.random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort", posx-30, posy, posz, math.random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort", posx, posy, posz-30, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit("corfort", posx+30, posy, posz, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit("corfort", posx, posy, posz+30, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit("corshroud", posx+90, posy, posz, math.random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-120, posy, posz, "west",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+150, posy, posz, "east",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-30, posy, posz+100, "north",GaiaTeamID)
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+60, posy, posz+100, "north",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-30, posy, posz-100, "south",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+60, posy, posz-100, "south",GaiaTeamID) 
	end
end
table.insert(ScavengerBlueprintsT2,radaroutpostheavyred)
table.insert(ScavengerBlueprintsT3,radaroutpostheavyred)

-- Heavy Outpost ARM

local function radaroutpostheavyblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"armhlt", "armhlt", "armbeamer", "armpb", "armpacko", "armflak",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armarad", posx-30, posy, posz, math.random(0,3),GaiaTeamID)
		Spring.CreateUnit("armveil", posx+30, posy, posz, math.random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-120, posy, posz, "west",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+120, posy, posz, "east",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-40, posy, posz+100, "north",GaiaTeamID)
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+40, posy, posz+100, "north",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-40, posy, posz-100, "south",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+40, posy, posz-100, "south",GaiaTeamID) 
	end
end
table.insert(ScavengerBlueprintsT2,radaroutpostheavyblue)
table.insert(ScavengerBlueprintsT3,radaroutpostheavyblue)

-- HEAVY BASES
-- Heavy Stealthy Base ARM

local function heavybaseblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"armpb", "armamb", "armpacko",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armckfus", posx, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit("armpacko", posx-120, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("armpacko", posx+120, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit("armeyes", posx, posy, posz+150, "north",GaiaTeamID) 
		Spring.CreateUnit("armeyes", posx, posy, posz-150, "south",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-100, posy, posz+70, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+100, posy, posz+70, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-100, posy, posz-70, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+100, posy, posz-70, math.random(0,3),GaiaTeamID) 
	end
end
table.insert(ScavengerBlueprintsT3,heavybaseblue)

local function heavybasebluesimple(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armckfus", posx, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit("armpacko", posx-120, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("armpacko", posx+120, posy, posz, "east",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT3,heavybasebluesimple)

-- ULTRA BASES
-- Ultra Heavy Base

local function ultraheavybaseblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"armpb", "armamb", "armarad",}
local unitpoolaa = {"armmercury", "armflak",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armgate", posx, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit("armanni", posx-160, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("armanni", posx+160, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz+150, "north",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx, posy, posz-150, "south",GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-100, posy, posz+70, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+100, posy, posz+70, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx-100, posy, posz-70, math.random(0,3),GaiaTeamID) 
		Spring.CreateUnit(unitpool[math.random(1,#unitpool)], posx+100, posy, posz-70, math.random(0,3),GaiaTeamID) 
	end
end
table.insert(ScavengerBlueprintsT3,ultraheavybaseblue)

-- Ultra Artillery Outpost

local function ultraheavyartybasered(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 120
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corint", posx, posy, posz, math.random(0,3),GaiaTeamID)
		Spring.CreateUnit("armarad", posx-120, posy, posz+30, "west",GaiaTeamID)
		Spring.CreateUnit("armveil", posx+120, posy, posz-30, "east",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT3,ultraheavyartybasered)