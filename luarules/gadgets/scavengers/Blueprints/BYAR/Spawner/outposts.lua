
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
		-- Spring.CreateUnit("scallt", posx-100, posy, posz, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("scallt", posx+100, posy, posz, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("scallt", posx, posy, posz-100, math_random(0,3),GaiaTeamID)
		-- Spring.CreateUnit("scallt", posx, posy, posz+100, math_random(0,3),GaiaTeamID)
	-- end
-- end
-- table.insert(ScavengerBlueprintsT1,a)

local nameSuffix = '_scav'

-- LIGHT RADAR OUTPOSTS
-- Outpost CORE

local function radaroutpostred(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"corllt", "corllt", "corhllt", "cormaw", "corrl",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corarad"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-100, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("corjamt"..nameSuffix, posx+100, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz-100, "north",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz+100, "south",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT0,radaroutpostred)
table.insert(ScavengerBlueprintsT1,radaroutpostred)

local function radaroutpostred2(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"corllt", "corllt", "corhllt", "corrad", "corerad",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-100, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("corjamt"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz-100, "north",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz+100, "south",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT1,radaroutpostred2)
table.insert(ScavengerBlueprintsT2,radaroutpostred2)

-- Outpost ARM

local function radaroutpostblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"armllt", "armllt", "armllt", "armclaw", "armrl",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armarad"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-100, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("armjamt"..nameSuffix, posx+100, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz-100, "south",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz+100, "north",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT0,radaroutpostblue)
table.insert(ScavengerBlueprintsT1,radaroutpostblue)

local function radaroutpostblue2(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"armllt", "armllt", "armrad", "armdrag", "armcir",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-100, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("armjamt"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz-100, "south",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz+100, "north",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT1,radaroutpostblue2)
table.insert(ScavengerBlueprintsT2,radaroutpostblue2)


-- ROADBLOCKS
-- Roadblock CORE

local function roadblockred(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"cordrag", "cordrag", "cordrag", "cormaw", "cordrag",}
local posradius = 30
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-60, posy, posz-60, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-30, posy, posz-30, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+30, posy, posz+30, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+60, posy, posz+60, math_random(0,3),GaiaTeamID)
	end
end
--table.insert(ScavengerBlueprintsT0,roadblockred)
table.insert(ScavengerBlueprintsT1,roadblockred)

-- Roadblock ARM

local function roadblockblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"armdrag", "armdrag", "armdrag", "armclaw", "armdrag",}
local posradius = 30
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-60, posy, posz-60, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-30, posy, posz-30, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+30, posy, posz+30, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+60, posy, posz+60, math_random(0,3),GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT0,roadblockblue)
--
table.insert(ScavengerBlueprintsT1,roadblockblue)

-- MEDIUM AA OUTPOSTS
-- Medium Anti-Air Outpost CORE

local function aaoutpostmediumred(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 80
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corflak"..nameSuffix, posx-50, posy, posz-50, "west",GaiaTeamID)
		Spring.CreateUnit("corflak"..nameSuffix, posx+50, posy, posz+50, "east",GaiaTeamID)
		Spring.CreateUnit("corshroud"..nameSuffix, posx-50, posy, posz+50, "south",GaiaTeamID)
		Spring.CreateUnit("corarad"..nameSuffix, posx+50, posy, posz-50, "north",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT2,aaoutpostmediumred)
table.insert(ScavengerBlueprintsT3,aaoutpostmediumred)

-- Medium Anti-Air Outpost ARM

local function aaoutpostmediumblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 80
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armflak"..nameSuffix, posx-50, posy, posz-50, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("armflak"..nameSuffix, posx+50, posy, posz+50, math_random(0,3),GaiaTeamID)
		--Spring.CreateUnit("armveil"..nameSuffix, posx-50, posy, posz+50, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("armarad"..nameSuffix, posx+50, posy, posz-50, math_random(0,3),GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT2,aaoutpostmediumblue)
table.insert(ScavengerBlueprintsT3,aaoutpostmediumblue)



-- MEDIUM/HEAVY OUTPOSTS
-- Heavy Outpost CORE

local function radaroutpostmediumred(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"corhlt", "corhlt", "corhllt", "corvipe", "corflak",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corarad"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort"..nameSuffix, posx-30, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort"..nameSuffix, posx, posy, posz-30, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort"..nameSuffix, posx+30, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort"..nameSuffix, posx, posy, posz+30, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corshroud"..nameSuffix, posx+90, posy, posz, math_random(0,3),GaiaTeamID)
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
		Spring.CreateUnit("corarad"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort"..nameSuffix, posx-30, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort"..nameSuffix, posx, posy, posz-30, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort"..nameSuffix, posx+30, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corfort"..nameSuffix, posx, posy, posz+30, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corshroud"..nameSuffix, posx+90, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-120, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+150, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-30, posy, posz+100, "south",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+60, posy, posz+100, "south",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-30, posy, posz-100, "north",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+60, posy, posz-100, "north",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT2,radaroutpostheavyred)
table.insert(ScavengerBlueprintsT3,radaroutpostheavyred)

-- Heavy Outpost RED 2

local function radaroutpostheavyred2(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"corhlt", "corhlt", "corvipe", "corvipe", "corflak",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corarad"..nameSuffix, posx-30, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corshroud"..nameSuffix, posx+30, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-120, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+120, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-40, posy, posz+100, "south",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+40, posy, posz+100, "south",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-40, posy, posz-100, "north",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+40, posy, posz-100, "north",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT2,radaroutpostheavyred2)
table.insert(ScavengerBlueprintsT3,radaroutpostheavyred2)

-- Heavy Defense Outpost ARM Cloaked

local function outpostheavybluesmall(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"armpb", "armferret",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-60, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+60, posy, posz, "east",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT2,outpostheavybluesmall)
table.insert(ScavengerBlueprintsT3,outpostheavybluesmall)

-- HEAVY BASES
-- Heavy Stealthy Base ARM

local function heavybaseblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"armpb", "armamb", "armferret",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armckfus"..nameSuffix, posx, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit("armferret"..nameSuffix, posx-120, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("armferret"..nameSuffix, posx+120, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit("armeyes"..nameSuffix, posx, posy, posz+170, "south",GaiaTeamID)
		Spring.CreateUnit("armeyes"..nameSuffix, posx, posy, posz-170, "north",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-100, posy, posz+70, "west",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+100, posy, posz+70, "east",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-100, posy, posz-70, "west",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+100, posy, posz-70, "east",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT3,heavybaseblue)

local function heavybasebluesimple(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armckfus"..nameSuffix, posx, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit("armferret"..nameSuffix, posx-120, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("armferret"..nameSuffix, posx+120, posy, posz, "east",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT3,heavybasebluesimple)

-- ULTRA BASES
-- Ultra Heavy Base

local function ultraheavybasered3(posx, posy, posz, GaiaTeamID, radiusCheck)
local unitpool = {"corvipe", "cortoast", "corarad",}
local unitpoolaa = {"corscreamer", "corflak",}
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corgate"..nameSuffix, posx, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit("cordoom"..nameSuffix, posx-160, posy, posz, "west",GaiaTeamID)
		Spring.CreateUnit("cordoom"..nameSuffix, posx+160, posy, posz, "east",GaiaTeamID)
		Spring.CreateUnit(unitpoolaa[math_random(1,#unitpoolaa)]..nameSuffix, posx, posy, posz+150, "south",GaiaTeamID)
		Spring.CreateUnit(unitpoolaa[math_random(1,#unitpoolaa)]..nameSuffix, posx, posy, posz-150, "north",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-100, posy, posz+70, "west",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+100, posy, posz+70, "east",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx-100, posy, posz-70, "west",GaiaTeamID)
		Spring.CreateUnit(unitpool[math_random(1,#unitpool)]..nameSuffix, posx+100, posy, posz-70, "east",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT3,ultraheavybasered3)

-- Ultra Heavy Base Annis

local function ultraheavybaseblueannis(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armflak"..nameSuffix, posx, posy, posz, "north",GaiaTeamID)
		Spring.CreateUnit("armanni"..nameSuffix, posx-60, posy, posz+60, "west",GaiaTeamID)
		Spring.CreateUnit("armanni"..nameSuffix, posx+60, posy, posz-60, "east",GaiaTeamID)
		Spring.CreateUnit("armanni"..nameSuffix, posx-60, posy, posz-60, "north",GaiaTeamID)
		Spring.CreateUnit("armanni"..nameSuffix, posx+60, posy, posz+60, "south",GaiaTeamID)
	end
end
--table.insert(ScavengerBlueprintsT3,ultraheavybaseblueannis)

-- Ultra Heavy Base Doom

local function ultraheavybasedoomred(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 110
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corflak"..nameSuffix, posx, posy, posz, "north",GaiaTeamID)
		Spring.CreateUnit("cordoom"..nameSuffix, posx-60, posy, posz+60, "west",GaiaTeamID)
		Spring.CreateUnit("cordoom"..nameSuffix, posx+60, posy, posz-60, "east",GaiaTeamID)
		Spring.CreateUnit("corflak"..nameSuffix, posx-60, posy, posz-60, "north",GaiaTeamID)
		Spring.CreateUnit("corarad"..nameSuffix, posx+60, posy, posz+60, "south",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT3,ultraheavybasedoomred)

-- Ultra Artillery Outpost Jammed

local function ultraheavyartybasered(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 110
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("corint"..nameSuffix, posx, posy, posz, math_random(0,3),GaiaTeamID)
		Spring.CreateUnit("corarad"..nameSuffix, posx-120, posy, posz+30, "west",GaiaTeamID)
		--Spring.CreateUnit("corveil"..nameSuffix, posx+120, posy, posz-30, "east",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT3,ultraheavyartybasered)

-- Ultra Artillery Outpost Dual

local function ultraheavyartybaseblue(posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.CreateUnit("armflak"..nameSuffix, posx-20, posy, posz-80, "south",GaiaTeamID)
		Spring.CreateUnit("armbrtha"..nameSuffix, posx-60, posy, posz+20, "south",GaiaTeamID)
		Spring.CreateUnit("armbrtha"..nameSuffix, posx+60, posy, posz-20, "south",GaiaTeamID)
	end
end
table.insert(ScavengerBlueprintsT3,ultraheavyartybaseblue)
