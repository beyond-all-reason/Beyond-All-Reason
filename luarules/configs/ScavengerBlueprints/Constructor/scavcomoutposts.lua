-- this has to be here on top of every blueprint file
local UDN = UnitDefNames

--	 facing:
--   0 - south
--   1 - east
--   2 - north
--   3 - west



local function scavradaronlyoutpost(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
local unitoptions = {UDN.scallt.id, UDN.scallt.id, UDN.corrl.id, UDN.scahllt.id, UDN.scahllt.id, UDN.scahlt.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corrad.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-100, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+100, posy, posz, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-100, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+100, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsStart,scavradaronlyoutpost)
table.insert(ScavengerConstructorBlueprintsT1,scavradaronlyoutpost)

local function scavradaroutpostsmallred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 70
local unitoptions = {UDN.scallt.id, UDN.scahllt.id, UDN.corrl.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt.id), {posx+40, posy, posz, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad.id), {posx-40, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+60, 3}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsStart,scavradaroutpostsmallred)
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostsmallred)

local function scavradaroutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
local unitoptions = {UDN.scallt.id, UDN.scallt.id, UDN.corrl.id, UDN.scahllt.id, UDN.corerad.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt.id), {posx+100, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-100, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-100, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+100, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsStart,scavradaroutpostred)
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostred)

local function scavartyoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt.id), {posx+100, posy, posz+25, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corpun.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad.id), {posx-100, posy, posz-25, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostred)
table.insert(ScavengerConstructorBlueprintsT2,scavradaroutpostred)

local function scavaaoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 75
local unitoptions = {UDN.corarad.id, UDN.scavape.id, UDN.scahlt.id, UDN.scahllt.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corflak.id), {posx-50, posy, posz-50, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corflak.id), {posx+50, posy, posz+50, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud.id), {posx-50, posy, posz+50, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+50, posy, posz-50, 2}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavaaoutpostred)
table.insert(ScavengerConstructorBlueprintsT3,scavaaoutpostred)

local function scavheavyoutpostcloak(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
local unitoptions = {UDN.scavape.id, UDN.armpacko.id,}
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
		Spring.GiveOrderToUnit(scav, -(UDN.corint.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corarad.id), {posx-120, posy, posz+30, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud.id), {posx+120, posy, posz-30, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,scavlrpcoutpostred)