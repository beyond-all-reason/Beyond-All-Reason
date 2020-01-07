-- this has to be here on top of every blueprint file
local UDN = UnitDefNames

--	 facing:
--   0 - south
--   1 - east
--   2 - north
--   3 - west

local nameSuffix = '_scav'


local function scavradaronlyoutpost(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
local unitoptions = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-100, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+100, posy, posz, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-100, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+100, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavradaronlyoutpost)
table.insert(ScavengerConstructorBlueprintsT1,scavradaronlyoutpost)

local function scavradaroutpostsmallred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 70
local unitoptions = {UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corrl_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+40, posy, posz, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx-40, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+60, 3}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavradaroutpostsmallred)
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostsmallred)

local function scavradaroutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
local unitoptions = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corerad_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+100, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-100, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-100, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+100, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavradaroutpostred)
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostred)

local function scavartyoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+100, posy, posz+25, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx-100, posy, posz-25, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostred)
table.insert(ScavengerConstructorBlueprintsT2,scavradaroutpostred)

local function scavaaoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 75
local unitoptions = {UDN.corarad_scav.id, UDN.corvipe_scav.id, UDN.corhlt_scav.id, UDN.corhllt_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx-50, posy, posz-50, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+50, posy, posz+50, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx-50, posy, posz+50, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+50, posy, posz-50, 2}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavaaoutpostred)
table.insert(ScavengerConstructorBlueprintsT3,scavaaoutpostred)

local function scavheavyoutpostcloak(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
local unitoptions = {UDN.corvipe_scav.id, UDN.armpacko_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-60, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+60, posy, posz, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavheavyoutpostcloak)
table.insert(ScavengerConstructorBlueprintsT3,scavheavyoutpostcloak)

local function scavlrpcoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 120
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx-120, posy, posz+30, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+120, posy, posz-30, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,scavlrpcoutpostred)

local function scavdoomoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 120
local unitoptions = {UDN.corvipe_scav.id, UDN.corvipe_scav.id, UDN.corflak_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx-120, posy, posz-30, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+120, posy, posz+30, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,scavdoomoutpostred)