-- this has to be here on top of every blueprint file
local UDN = UnitDefNames

--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

--	possible tables:
--	table.insert(ScavengerConstructorBlueprintsT0,nameoffunction)
--	table.insert(ScavengerConstructorBlueprintsT1,nameoffunction)
--	table.insert(ScavengerConstructorBlueprintsT2,nameoffunction)
--	table.insert(ScavengerConstructorBlueprintsT3,nameoffunction)

local nameSuffix = '_scav'

-- FACTORIES

local function scavlabt1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local unitoptions = {}
local r = math.random(0,5)		
	local posradius = 60
		if radiusCheck then
			return posradius
		else	
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(UDN.corlab_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			elseif r == 1 then
				Spring.GiveOrderToUnit(scav, -(UDN.armlab_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			elseif r == 2 then
				Spring.GiveOrderToUnit(scav, -(UDN.corvp_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			elseif r == 3 then
				Spring.GiveOrderToUnit(scav, -(UDN.armvp_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			elseif r == 4 then
				Spring.GiveOrderToUnit(scav, -(UDN.corap_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(UDN.armap_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})

		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavlabt1)
table.insert(ScavengerConstructorBlueprintsT1,scavlabt1)

local function scavlabt2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local unitoptions = {}
local r = math.random(0,5)		
	local posradius = 70
		if radiusCheck then
			return posradius
		else	
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(UDN.coralab_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			elseif r == 1 then
				Spring.GiveOrderToUnit(scav, -(UDN.armalab_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			elseif r == 2 then
				Spring.GiveOrderToUnit(scav, -(UDN.coravp_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			elseif r == 3 then
				Spring.GiveOrderToUnit(scav, -(UDN.armavp_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			elseif r == 4 then
				Spring.GiveOrderToUnit(scav, -(UDN.coraap_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(UDN.armaap_scav.id), {posx, posy, posz, math.random(0,3)}, {"shift"})

		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavlabt2)
table.insert(ScavengerConstructorBlueprintsT3,scavlabt2)

-- ECO BUILDINGS

local function scavmetalmakerst1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 70
local unitoptions = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx-32, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+32, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx-32, posy, posz+32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormakr_scav.id), {posx+32, posy, posz+32, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-72, posy, posz-72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-40, posy, posz-72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-8, posy, posz-72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-72, posy, posz-40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-72, posy, posz-8, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+72, posy, posz+72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+72, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+72, posy, posz+8, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+40, posy, posz+72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+8, posy, posz+72, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavmetalmakerst1)
table.insert(ScavengerConstructorBlueprintsT1,scavmetalmakerst1)

local function scavmetalmakerst2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 80
local unitoptions = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx-40, posy, posz-40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormmkr_scav.id), {posx+40, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx-40, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+40, posy, posz-40, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-104, posy, posz-104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-72, posy, posz-104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-40, posy, posz-104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-104, posy, posz-72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-104, posy, posz-40, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+104, posy, posz+104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+104, posy, posz+72, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+104, posy, posz+40, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+72, posy, posz+104, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+40, posy, posz+104, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavmetalmakerst2)
table.insert(ScavengerConstructorBlueprintsT3,scavmetalmakerst2)

local function scavmstoredual(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 80
local unitoptions = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cormstor_scav.id), {posx-40, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cormstor_scav.id), {posx+40, posy, posz, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-96, posy, posz-80, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz-48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz-80, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+96, posy, posz+80, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz+48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+64, posy, posz+80, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavmstoredual)
table.insert(ScavengerConstructorBlueprintsT2,scavmstoredual)
table.insert(ScavengerConstructorBlueprintsT3,scavmstoredual)

-- SMALL RADAR OUTPOSTS

local function scavradaronlyoutpost(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 90
local unitoptions = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.cornanotc_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-88, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+88, posy, posz, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-88, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+88, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavradaronlyoutpost)
table.insert(ScavengerConstructorBlueprintsT1,scavradaronlyoutpost)

local function scavradaroutpostsmallred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 70
local unitoptions = {UDN.corrad_scav.id, UDN.coreyes_scav.id, UDN.corwin_scav.id, UDN.corjamt_scav.id, UDN.cornanotc_scav.id,}
local defenseoptions = {UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corrl_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+40, posy, posz, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-40, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math.random(1,#defenseoptions)]), {posx, posy, posz+60, 3}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavradaroutpostsmallred)
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostsmallred)

-- ROADBLOCKS

local function roadblocks(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptionsblue = {UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armclaw_scav.id,}
	local unitoptionsred = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	local posradius = 40
	local r = math.random(0,7)	
		if radiusCheck then
			return posradius
		else	
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx-32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})	
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx+32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx+64, posy, posz+64, 0}, {"shift"})
			elseif r == 1 then		
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx-64, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx-32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})	
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx+32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx+64, posy, posz-64, 0}, {"shift"})
			elseif r == 2 then		
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx-64, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx-32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})	
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx+32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx+64, posy, posz, 0}, {"shift"})
			elseif r == 3 then		
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx, posy, posz, 0}, {"shift"})	
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsblue[math.random(1,#unitoptionsblue)]), {posx, posy, posz-64, 0}, {"shift"})
			elseif r == 4 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx-32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx+32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx+64, posy, posz+64, 0}, {"shift"})
			elseif r == 5 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx-64, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx-32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx+32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx+64, posy, posz-64, 0}, {"shift"})
			elseif r == 6 then
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx-64, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx-32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx+32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx+64, posy, posz, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptionsred[math.random(1,#unitoptionsred)]), {posx, posy, posz-64, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0,roadblocks)
table.insert(ScavengerConstructorBlueprintsT1,roadblocks)

-- WALL OF TURRETS (lines)

local function scavwallofturrets(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id,}
	local posradius = 80
	local r = math.random(0,3)	
		if radiusCheck then
			return posradius
		else	
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-64, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+64, posy, posz-32, 0}, {"shift"})			
			elseif r == 1 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-32, posy, posz+64, 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz, 3}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+32, posy, posz-64, 1}, {"shift"})
			elseif r == 2 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-96, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+32, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+96, posy, posz, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-96, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+96, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT0,scavwallofturrets)
table.insert(ScavengerConstructorBlueprintsT1,scavwallofturrets)

local function scavwallofturretsadv(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id,}
	local r = math.random(0,1)	
	local posradius = 90
		if radiusCheck then
			return posradius
		else	
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+100, posy, posz-60, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+50, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx-50, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-100, posy, posz+60, 0}, {"shift"})			
			else
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+60, posy, posz-100, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+32, posy, posz-50, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx-32, posy, posz+50, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-60, posy, posz+100, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavwallofturretsadv)
table.insert(ScavengerConstructorBlueprintsT3,scavwallofturretsadv)

local function scavadvsol(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.corllt_scav.id, UDN.corrad_scav.id, UDN.corjamt_scav.id,}
	local unitoptions2 = {UDN.armllt_scav.id, UDN.armrad_scav.id, UDN.armjamt_scav.id,}
	local r = math.random(0,1)
	local x1 = math.random(-48,48)
	local x2 = math.random(-48,48)			
	local posradius = 80
		if radiusCheck then
			return posradius
		else	
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+x1, posy, posz-120, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx-40, posy, posz-40, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+40, posy, posz-40, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx-40, posy, posz+40, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.coradvsol_scav.id), {posx+40, posy, posz+40, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+x2, posy, posz+120, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(unitoptions2[math.random(1,#unitoptions2)]), {posx+x1, posy, posz-112, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+32, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-32, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+32, posy, posz+32, 0}, {"shift"})				
				Spring.GiveOrderToUnit(scav, -(unitoptions2[math.random(1,#unitoptions2)]), {posx+x2, posy, posz+112, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavadvsol)
table.insert(ScavengerConstructorBlueprintsT2,scavadvsol)

-- MEDIUM RADAR OUTPOSTS

local function scavradaroutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 110
local unitoptions = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corerad_scav.id, UDN.cornanotc_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corjamt_scav.id), {posx+96, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corrad_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-96, posy, posz, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-96, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+96, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz+32, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+128, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz+32, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavradaroutpostred)
table.insert(ScavengerConstructorBlueprintsT2,scavradaroutpostred)

local function scavartyoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 90
local unitoptions = {UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.corrad_scav.id, UDN.coreyes_scav.id, UDN.corjamt_scav.id, UDN.cornanotc_scav.id,}
local unitoptions2 = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+100, posy, posz+25, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-100, posy, posz-25, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-32, posy, posz+80, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions2[math.random(1,#unitoptions2)]), {posx, posy, posz+96, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+32, posy, posz+112, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-32, posy, posz-112, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions2[math.random(1,#unitoptions2)]), {posx, posy, posz-96, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+32, posy, posz-80, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT1,scavartyoutpostred)
table.insert(ScavengerConstructorBlueprintsT2,scavartyoutpostred)

-- MEDIUM ARTILLERY BASES

local function scavartyoutpostredadv(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 90
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+25, posy, posz+100, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx-25, posy, posz-128, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz+32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz+64, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+192, posy, posz+128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+160, posy, posz+96, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+128, posy, posz+64, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavartyoutpostredadv)
table.insert(ScavengerConstructorBlueprintsT3,scavartyoutpostredadv)

-- JAMMED AA BASES

local function scavaaoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 70
local unitoptions = {UDN.corarad_scav.id, UDN.corvipe_scav.id, UDN.corhlt_scav.id, UDN.corhllt_scav.id, UDN.cormadsam_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx-48, posy, posz-48, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corflak_scav.id), {posx+48, posy, posz+48, 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx-48, posy, posz+48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+48, posy, posz-48, 2}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-80, posy, posz+48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-80, posy, posz+80, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-48, posy, posz+80, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+80, posy, posz-48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+80, posy, posz-80, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+48, posy, posz-80, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavaaoutpostred)
table.insert(ScavengerConstructorBlueprintsT3,scavaaoutpostred)

-- CLOAKED BASES

local function scavheavyoutpostcloak(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 100
local unitoptions = {UDN.corvipe_scav.id, UDN.armpacko_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-48, posy, posz+16, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+48, posy, posz-16, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavheavyoutpostcloak)
table.insert(ScavengerConstructorBlueprintsT3,scavheavyoutpostcloak)

-- BIG BASES

local function scavbigoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 120
local unitoptions = {UDN.corrad_scav.id, UDN.corarad_scav.id, UDN.corshroud_scav.id, UDN.cornanotc_scav.id, UDN.armtarg_scav.id,}
local defenseoptions = {UDN.corhlt_scav.id, UDN.corhllt_scav.id, UDN.corllt_scav.id, UDN.corrl_scav.id, UDN.corhllt_scav.id, UDN.corhllt_scav.id, UDN.corerad_scav.id, UDN.cornanotc_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math.random(1,#defenseoptions)]), {posx-56, posy, posz+56, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+40, posy, posz-16, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math.random(1,#defenseoptions)]), {posx-100, posy, posz-140, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-20, posy, posz-100, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+60, posy, posz-100, 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math.random(1,#defenseoptions)]), {posx+240, posy, posz-260, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(defenseoptions[math.random(1,#defenseoptions)]), {posx+140, posy, posz+56, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz+128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz+96, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-128, posy, posz+64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz+128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz+128, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+160, posy, posz-192, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+128, posy, posz-192, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz-192, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+160, posy, posz-160, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+160, posy, posz-128, 0}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(defenseoptions[math.random(1,#defenseoptions)]), {posx+240, posy, posz-260, 0}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavbigoutpostred)
table.insert(ScavengerConstructorBlueprintsT3,scavbigoutpostred)

-- LONG RANGE PLASMA CANNON BASES

local function scavlrpcoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 120
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx-120, posy, posz+32, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+120, posy, posz-32, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,scavlrpcoutpostred)

-- HEAVY DEFENSIVE BASES

local function scavdoomoutpostred(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 120
local unitoptions = {UDN.corvipe_scav.id, UDN.corvipe_scav.id, UDN.corflak_scav.id,}
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corarad_scav.id), {posx-120, posy, posz-32, 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+120, posy, posz+32, 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,scavdoomoutpostred)

-- HEAVY POWERPLANT BASES

local function scavnrgplants(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local unitoptions = {UDN.corhlt_scav.id, UDN.corflak_scav.id, UDN.corshroud_scav.id, UDN.cortarg_scav.id, UDN.corfort_scav.id, UDN.corfort_scav.id,}
	local posradius = 120
	local r = math.random(0,2)	
		if radiusCheck then 
			return posradius
		else	
			if r == 0 then
				Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx-192, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+192, posy, posz, 0}, {"shift"})
				
				Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx-96, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfus_scav.id), {posx+96, posy, posz, 0}, {"shift"})

				--Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx-64, posy, posz, 0}, {"shift"})
				--Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx+64, posy, posz, 0}, {"shift"})

				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-32, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz-64, 2}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+32, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-96, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-64, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-32, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+32, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+64, posy, posz+80, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+96, posy, posz+80, 0}, {"shift"})			
			elseif r == 1 then
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx-160, posy, posz-160, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+160, posy, posz-160, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx-160, posy, posz+160, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+160, posy, posz+160, 0}, {"shift"})
				
				Spring.GiveOrderToUnit(scav, -(UDN.armafus_scav.id), {posx, posy, posz, 1}, {"shift"})
				
				--Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx, posy, posz-40, 0}, {"shift"})
				--Spring.GiveOrderToUnit(scav, -(UDN.armfus_scav.id), {posx, posy, posz+40, 0}, {"shift"})

				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-80, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-96, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx-96, posy, posz, 3}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx-96, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx-80, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+80, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+96, posy, posz-32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(unitoptions[math.random(1,#unitoptions)]), {posx+96, posy, posz, 1}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.corfort_scav.id), {posx+96, posy, posz+32, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+80, posy, posz+64, 0}, {"shift"})
			else
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx-160, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+160, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+64, posy, posz-64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-64, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+64, posy, posz, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx-64, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx, posy, posz+64, 0}, {"shift"})
				Spring.GiveOrderToUnit(scav, -(UDN.armadvsol_scav.id), {posx+64, posy, posz+64, 0}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT2,scavnrgplants)
table.insert(ScavengerConstructorBlueprintsT3,scavnrgplants)