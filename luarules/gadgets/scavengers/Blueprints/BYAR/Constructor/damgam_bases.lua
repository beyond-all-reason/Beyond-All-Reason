--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west
-- randompopups[math_random(1,#randompopups)]

local UDN = UnitDefNames
local nameSuffix = '_scav'

local function DamBase1Red(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local randompopups = {UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cormaw_scav.id,}
	local randomturrets = {UDN.corllt_scav.id, UDN.corllt_scav.id, UDN.corhllt_scav.id, UDN.corhlt_scav.id, UDN.cormaw_scav.id, UDN.corrl_scav.id, UDN.cornanotc_scav.id,}
	local r = math_random(0,1)
	local posradius = 196
	if radiusCheck then
		return posradius
	else
		-- Defences
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz+64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz-128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz+128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz+64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz-128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz+128, 0}, {"shift"})


		-- Nanos
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-96, posy, posz-48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-96, posy, posz+48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-96, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+96, posy, posz-48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+96, posy, posz+48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+96, posy, posz, 0}, {"shift"})

		-- Utility
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.corlab_scav.id), {posx, posy, posz, 0}, {"shift"})
		elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.corvp_scav.id), {posx, posy, posz, 0}, {"shift"})
		end

		-- Walls
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz+32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz+64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz+32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz+64, 0}, {"shift"})
	end
end
	table.insert(ScavengerConstructorBlueprintsT2,DamBase1Red)
	table.insert(ScavengerConstructorBlueprintsT3,DamBase1Red)

local function DamBase1Blue(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local randompopups = {UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armclaw_scav.id,}
local randomturrets = {UDN.armllt_scav.id, UDN.armllt_scav.id, UDN.armhlt_scav.id, UDN.armclaw_scav.id, UDN.armrl_scav.id, UDN.armnanotc_scav.id,}
local r = math_random(0,1)
local posradius = 196
	if radiusCheck then
		return posradius
	else
		-- Defences
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz+64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz-128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-196, posy, posz+128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz+64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz-128, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+196, posy, posz+128, 0}, {"shift"})


		-- Nanos
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-96, posy, posz-48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-96, posy, posz+48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx-96, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+96, posy, posz-48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+96, posy, posz+48, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randomturrets[math_random(1,#randomturrets)], {posx+96, posy, posz, 0}, {"shift"})

		-- Utility
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.armlab_scav.id), {posx, posy, posz, 0}, {"shift"})
		elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.armvp_scav.id), {posx, posy, posz, 0}, {"shift"})
		end

		-- Walls
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz+32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx-136, posy, posz+64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz-32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz+32, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz-64, 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -randompopups[math_random(1,#randompopups)], {posx+136, posy, posz+64, 0}, {"shift"})

	end
end
table.insert(ScavengerConstructorBlueprintsT2,DamBase1Blue)
table.insert(ScavengerConstructorBlueprintsT3,DamBase1Blue)

local function DamBase2Blue(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 192
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-24), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-24), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(24), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(24), posy, posz+(-24), 1}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(-64), posy, posz+(-160), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(72), posy, posz+(72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-160), posy, posz+(-128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(128), posy, posz+(160), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(160), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(64), posy, posz+(160), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(72), posy, posz+(-72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(128), posy, posz+(-160), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-72), posy, posz+(72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(-160), posy, posz+(128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(-160), posy, posz+(-64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(-128), posy, posz+(-160), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(64), posy, posz+(-160), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(160), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armbeamer_scav.id), {posx+(-128), posy, posz+(160), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(-64), posy, posz+(160), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-72), posy, posz+(-72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(160), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(160), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armllt_scav.id), {posx+(-160), posy, posz+(64), 3}, {"shift"})

		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(160), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(128), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-128), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(64), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-64), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-64), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-96), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(64), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-160), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-160), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(96), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(160), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-128), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(96), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(-160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-192), posy, posz+(160), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(128), posy, posz+(-192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(-96), posy, posz+(192), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armdrag_scav.id), {posx+(192), posy, posz+(192), 1}, {"shift"})
	end
end

table.insert(ScavengerConstructorBlueprintsT1,DamBase2Blue)
table.insert(ScavengerConstructorBlueprintsT2,DamBase2Blue)
table.insert(ScavengerConstructorBlueprintsT3,DamBase2Blue)

local function DamBase2Red(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 192
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(24), posy, posz+(24), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(24), posy, posz+(-24), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-24), posy, posz+(24), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-24), posy, posz+(-24), 3}, {"shift"})
		
		Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(-80), posy, posz+(-80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-128), posy, posz+(160), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(80), posy, posz+(-80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(-160), posy, posz+(-64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(-160), posy, posz+(64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(128), posy, posz+(-160), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(-160), posy, posz+(128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(160), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(64), posy, posz+(160), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(64), posy, posz+(-160), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(-80), posy, posz+(80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(128), posy, posz+(160), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(-64), posy, posz+(160), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corerad_scav.id), {posx+(80), posy, posz+(80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(-160), posy, posz+(-128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corhllt_scav.id), {posx+(160), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(160), posy, posz+(-128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(-128), posy, posz+(-160), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(-64), posy, posz+(-160), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corllt_scav.id), {posx+(160), posy, posz+(64), 1}, {"shift"})
		
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-160), posy, posz+(192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-192), posy, posz+(-128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(160), posy, posz+(192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(128), posy, posz+(192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-192), posy, posz+(96), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(96), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(64), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-192), posy, posz+(-96), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-96), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-192), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-192), posy, posz+(128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-192), posy, posz+(-160), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(-128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-192), posy, posz+(192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(160), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(160), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-96), posy, posz+(192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-128), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(128), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(96), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-160), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(96), posy, posz+(192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(-64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-128), posy, posz+(192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(64), posy, posz+(192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(-96), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-64), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(192), posy, posz+(-160), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-192), posy, posz+(64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordrag_scav.id), {posx+(-192), posy, posz+(-64), 3}, {"shift"})
	end
end

table.insert(ScavengerConstructorBlueprintsT1,DamBase2Red)
table.insert(ScavengerConstructorBlueprintsT2,DamBase2Red)
table.insert(ScavengerConstructorBlueprintsT3,DamBase2Red)

local function DamTrap1Blue(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 96
	if radiusCheck then
		return posradius
	else
		local unitOptions = {UDN.armclaw_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id, UDN.armdrag_scav.id}
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-32), posy, posz+(32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(32), posy, posz+(-32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-32), posy, posz+(-32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(32), posy, posz+(32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(96), posy, posz+(-32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-32), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(32), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(96), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(64), posy, posz+(-64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(0), posy, posz+(64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-32), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(64), posy, posz+(0), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-96), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(0), posy, posz+(0), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-64), posy, posz+(-64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(64), posy, posz+(64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-64), posy, posz+(0), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(96), posy, posz+(32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-96), posy, posz+(-32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(96), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(0), posy, posz+(-64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-96), posy, posz+(32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-64), posy, posz+(64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(32), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-96), posy, posz+(96), 0}, {"shift"})
	end
end

table.insert(ScavengerConstructorBlueprintsT1,DamTrap1Blue)
table.insert(ScavengerConstructorBlueprintsT2,DamTrap1Blue)
table.insert(ScavengerConstructorBlueprintsT3,DamTrap1Blue)

local function DamTrap1Red(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
local posradius = 96
	if radiusCheck then
		return posradius
	else
		local unitOptions = {UDN.cormaw_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id, UDN.cordrag_scav.id}
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(32), posy, posz+(32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(32), posy, posz+(-32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-32), posy, posz+(-32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-32), posy, posz+(32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-32), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(64), posy, posz+(0), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-64), posy, posz+(0), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(0), posy, posz+(-64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(64), posy, posz+(-64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-96), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(32), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-32), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-64), posy, posz+(-64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(0), posy, posz+(64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(96), posy, posz+(32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-64), posy, posz+(64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(96), posy, posz+(-32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-96), posy, posz+(32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-96), posy, posz+(-32), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(64), posy, posz+(64), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(96), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(32), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(96), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(-96), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(unitOptions[math_random(1,5)]), {posx+(0), posy, posz+(0), 0}, {"shift"})
	end
end

table.insert(ScavengerConstructorBlueprintsT1,DamTrap1Red)
table.insert(ScavengerConstructorBlueprintsT2,DamTrap1Red)
table.insert(ScavengerConstructorBlueprintsT3,DamTrap1Red)