-- this has to be here on top of every blueprint file
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

--	possible tables:
--	table.insert(ScavengerConstructorBlueprintsT0Sea,nameoffunction)
--	table.insert(ScavengerConstructorBlueprintsT1Sea,nameoffunction)
--	table.insert(ScavengerConstructorBlueprintsT2Sea,nameoffunction)
--	table.insert(ScavengerConstructorBlueprintsT3Sea,nameoffunction)

local nameSuffix = '_scav'

local function scavamphfactoryt1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {}
	local r = math_random(0,3)
	local posradius = 60
	if radiusCheck then
		return posradius
	else
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.corhp_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.armhp_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		elseif r == 2 then
			Spring.GiveOrderToUnit(scav, -(UDN.corhp_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		else
			Spring.GiveOrderToUnit(scav, -(UDN.armhp_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,scavamphfactoryt1)
table.insert(ScavengerConstructorBlueprintsT1Sea,scavamphfactoryt1)

local function scavamphfactoryt2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.corgantuw_scav.id, UDN.armshltxuw_scav.id,}
	local r = math_random(0,8)
	local posradius = 70
	if radiusCheck then
		return posradius
	else
		if r == 0 or r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.corplat_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		elseif r == 2 or r == 3 then
			Spring.GiveOrderToUnit(scav, -(UDN.armplat_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		elseif r == 4 or r == 5 then
			Spring.GiveOrderToUnit(scav, -(UDN.coramsub_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		elseif r == 6 or r == 7 then
			Spring.GiveOrderToUnit(scav, -(UDN.armamsub_scav.id), {posx, posy, posz, math_random(0,3)}, {"shift"})
		else
			Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz, math_random(0,3)}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,scavamphfactoryt2)
table.insert(ScavengerConstructorBlueprintsT3Sea,scavamphfactoryt2)

local function waterblocks(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptionsblue = {UDN.armfdrag_scav.id,}
	local unitoptionsred = {UDN.corfdrag_scav.id,}
	local posradius = 128
	local r = math_random(0,3)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+64, posy, posz+64, 0}, {"shift"})
			elseif r == 1 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-64, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx-32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+64, posy, posz-64, 0}, {"shift"})
			elseif r == 2 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+64, posy, posz+64, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-64, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx-32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+64, posy, posz-64, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,waterblocks)
table.insert(ScavengerConstructorBlueprintsT1Sea,waterblocks)

local function searadar(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptionsblue = {UDN.armfrad_scav.id,}
	local unitoptionsred = {UDN.corfrad_scav.id,}
	local posradius = 64
	local r = math_random(0,1)
		if radiusCheck then
			return posradius
		else
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(UDN.armsonar_scav.id), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math_random(1,#unitoptionsblue)]), {posx+64, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armfrt_scav.id), {posx-48, posy, posz+48, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(UDN.corsonar_scav.id), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math_random(1,#unitoptionsred)]), {posx+64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfrt_scav.id), {posx+48, posy, posz+64, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,searadar)
table.insert(ScavengerConstructorBlueprintsT1Sea,searadar)

local function scavsonaroutpost(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.armsonar_scav.id,}
	local defenseoptions = {UDN.armtl_scav.id, UDN.armtl_scav.id, UDN.armfrt_scav.id,}
	local posradius = 120
	local z1 = math_random(-60,40)
	local z2 = math_random(-40,60)
		if radiusCheck then
			return posradius
		else
			Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz, 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx-70, posy, posz+z1, 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+70, posy, posz+z2, 1}, {"shift"})
		end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,scavsonaroutpost)
table.insert(ScavengerConstructorBlueprintsT1Sea,scavsonaroutpost)

local function scavsonaroutpostadv(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local unitoptions = {UDN.corsonar_scav.id,}
local defenseoptions = {UDN.coratl_scav.id,}
local z1 = math_random(-60,40)
local z2 = math_random(-40,60)
local posradius = 120
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+z1, posy, posz-70, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+z2, posy, posz+70, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,scavsonaroutpostadv)
table.insert(ScavengerConstructorBlueprintsT3Sea,scavsonaroutpostadv)

local function scavuwmstore(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 128
local unitoptions = {UDN.corsonar_scav.id, UDN.armsonar_scav.id,}
local defenseoptions = {UDN.cortl_scav.id, UDN.armtl_scav.id, UDN.corfrt_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.coruwms_scav.id), {posx-50, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coruwms_scav.id), {posx+50, posy, posz-40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-20, posy, posz-150, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+40, posy, posz+100, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0Sea,scavuwmstore)
table.insert(ScavengerConstructorBlueprintsT1Sea,scavuwmstore)

local function scavuwmstoreadv(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 128
local unitoptions = {UDN.corsonar_scav.id, UDN.armsonar_scav.id,}
local defenseoptions = {UDN.coratl_scav.id, UDN.armatl_scav.id, UDN.armfrt_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.coruwadvms_scav.id), {posx-40, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coruwadvms_scav.id), {posx+30, posy, posz-50, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-30, posy, posz-150, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+30, posy, posz+150, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,scavuwmstoreadv)

local function scavuwestore(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 128
local unitoptions = {UDN.corsonar_scav.id, UDN.coruwfus_scav.id, UDN.cortl_scav.id,}
local defenseoptions = {UDN.cortl_scav.id, UDN.coratl_scav.id, UDN.corfrt_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.coruwes_scav.id), {posx+10, posy, posz+48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coruwes_scav.id), {posx+10, posy, posz-48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math_random(1,#unitoptions)]), {posx-96, posy, posz-16, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math_random(1,#defenseoptions)]), {posx+112, posy, posz-16, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1Sea,scavuwestore)
table.insert(ScavengerConstructorBlueprintsT2Sea,scavuwestore)

local function scavamphunitsblue(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 64
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armpincer_scav.id), {posx-50, posy, posz-50, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpincer_scav.id), {posx+50, posy, posz-50, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpincer_scav.id), {posx, posy, posz+50, 3}, {"shift"})
		--Spring.GiveOrderToUnit(scav, -(UDN.armpincer_scav.id), {posx+50, posy, posz+50, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1Sea,scavamphunitsblue)
table.insert(ScavengerConstructorBlueprintsT2Sea,scavamphunitsblue)

local function scavamphunitsredadv(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 65
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx-50, posy, posz-50, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx+50, posy, posz-50, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx, posy, posz+50, 3}, {"shift"})
		--Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx+50, posy, posz+50, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2Sea,scavamphunitsredadv)

local function scavuwfus(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 112
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armuwfus_scav.id), {posx, posy, posz-112, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armuwfus_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armuwfus_scav.id), {posx, posy, posz+112, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT3Sea,scavuwfus)

local function scavamphunitsredadvxl(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 80
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotcplat_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx-64, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx+64, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx-64, posy, posz+64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx, posy, posz+64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corseal_scav.id), {posx+64, posy, posz+64, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3Sea,scavamphunitsredadvxl)
