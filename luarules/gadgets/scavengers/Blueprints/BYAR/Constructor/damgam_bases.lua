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
