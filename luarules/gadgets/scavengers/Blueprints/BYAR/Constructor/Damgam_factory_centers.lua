--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

local UDN = UnitDefNames
local nameSuffix = '_scav'

local function DamgamT1Spammer(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 192
	if radiusCheck then
		return posradius
	else
		local r = math_random(0,5)
		if r == 0 then
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(-24), posy, posz+(-24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(-24), posy, posz+(24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(24), posy, posz+(-24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(24), posy, posz+(24), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.corlab_scav.id), {posx+(96), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corlab_scav.id), {posx+(0), posy, posz+(-96), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corlab_scav.id), {posx+(0), posy, posz+(96), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corlab_scav.id), {posx+(-96), posy, posz+(0), 3}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(72), posy, posz+(-120), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-120), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-72), posy, posz+(120), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(72), posy, posz+(120), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(72), posy, posz+(72), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(120), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(72), posy, posz+(-72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-72), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-72), posy, posz+(-120), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-120), posy, posz+(72), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(120), posy, posz+(72), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-72), posy, posz+(-72), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-128), posy, posz+(-128), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-128), posy, posz+(128), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(128), posy, posz+(128), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(128), posy, posz+(-128), 1}, {"shift"})
		elseif r == 1 then
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(24), posy, posz+(24), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(24), posy, posz+(-24), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-24), posy, posz+(-24), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-24), posy, posz+(24), 3}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.armlab_scav.id), {posx+(0), posy, posz+(-96), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armlab_scav.id), {posx+(96), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armlab_scav.id), {posx+(0), posy, posz+(96), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armlab_scav.id), {posx+(-96), posy, posz+(0), 3}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-120), posy, posz+(-72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-72), posy, posz+(-120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(72), posy, posz+(120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-120), posy, posz+(72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(72), posy, posz+(-72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(72), posy, posz+(-120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(120), posy, posz+(-72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-72), posy, posz+(72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-72), posy, posz+(120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(72), posy, posz+(72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(120), posy, posz+(72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-72), posy, posz+(-72), 3}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(120), posy, posz+(-120), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(120), posy, posz+(120), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(-120), posy, posz+(120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(-120), posy, posz+(-120), 3}, {"shift"})
		elseif r == 2 then
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(-32), posy, posz+(32), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(-32), posy, posz+(-32), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(32), posy, posz+(-32), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(32), posy, posz+(32), 3}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.corvp_scav.id), {posx+(0), posy, posz+(-112), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corvp_scav.id), {posx+(0), posy, posz+(112), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corvp_scav.id), {posx+(112), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corvp_scav.id), {posx+(-96), posy, posz+(0), 3}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-128), posy, posz+(80), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-128), posy, posz+(-80), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(80), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(128), posy, posz+(80), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-80), posy, posz+(80), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(128), posy, posz+(-80), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-80), posy, posz+(128), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-80), posy, posz+(-128), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(80), posy, posz+(128), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(80), posy, posz+(-80), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-80), posy, posz+(-80), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(80), posy, posz+(-128), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-136), posy, posz+(136), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-136), posy, posz+(-136), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(136), posy, posz+(136), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(136), posy, posz+(-136), 1}, {"shift"})
		elseif r == 3 then
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(24), posy, posz+(24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-24), posy, posz+(-24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(24), posy, posz+(-24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-24), posy, posz+(24), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.armvp_scav.id), {posx+(0), posy, posz+(-104), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armvp_scav.id), {posx+(-104), posy, posz+(0), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armvp_scav.id), {posx+(0), posy, posz+(104), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armvp_scav.id), {posx+(104), posy, posz+(0), 1}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-120), posy, posz+(-72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(72), posy, posz+(-120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(120), posy, posz+(72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-72), posy, posz+(-120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(120), posy, posz+(-72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-72), posy, posz+(-72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(72), posy, posz+(72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(72), posy, posz+(120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-72), posy, posz+(120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(72), posy, posz+(-72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-120), posy, posz+(72), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-72), posy, posz+(72), 3}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(120), posy, posz+(120), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(-120), posy, posz+(-120), 3}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(120), posy, posz+(-120), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(-120), posy, posz+(120), 3}, {"shift"})
		elseif r == 4 then
			Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(0), posy, posz+(32), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corhlt_scav.id), {posx+(0), posy, posz+(-32), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(40), posy, posz+(24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(-40), posy, posz+(24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(40), posy, posz+(-24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cormadsam_scav.id), {posx+(-40), posy, posz+(-24), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.corap_scav.id), {posx+(128), posy, posz+(0), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corap_scav.id), {posx+(-128), posy, posz+(0), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corap_scav.id), {posx+(0), posy, posz+(-96), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corap_scav.id), {posx+(0), posy, posz+(96), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-136), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(184), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(88), posy, posz+(120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-88), posy, posz+(-120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(88), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(136), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-136), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-88), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-184), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(184), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(88), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-88), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(136), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(88), posy, posz+(-120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-88), posy, posz+(120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.cornanotc_scav.id), {posx+(-184), posy, posz+(72), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-144), posy, posz+(128), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-208), posy, posz+(128), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-144), posy, posz+(-128), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(-208), posy, posz+(-128), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(208), posy, posz+(-128), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(144), posy, posz+(128), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(208), posy, posz+(128), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.corpun_scav.id), {posx+(144), posy, posz+(-128), 2}, {"shift"})
		elseif r == 5 then
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(0), posy, posz+(24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(48), posy, posz+(24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-48), posy, posz+(-24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(48), posy, posz+(-24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(-48), posy, posz+(24), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armferret_scav.id), {posx+(0), posy, posz+(-24), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.armap_scav.id), {posx+(0), posy, posz+(-96), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armap_scav.id), {posx+(-144), posy, posz+(0), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armap_scav.id), {posx+(144), posy, posz+(0), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armap_scav.id), {posx+(0), posy, posz+(96), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(96), posy, posz+(-120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(144), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-96), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-96), posy, posz+(-120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-96), posy, posz+(120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(192), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(96), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-96), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-144), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(96), posy, posz+(120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-192), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-192), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(96), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(144), posy, posz+(-72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(192), posy, posz+(72), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armnanotc_scav.id), {posx+(-144), posy, posz+(72), 2}, {"shift"})

			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(144), posy, posz+(120), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(144), posy, posz+(-120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(-144), posy, posz+(120), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(192), posy, posz+(120), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(-192), posy, posz+(120), 0}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(-144), posy, posz+(-120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(-192), posy, posz+(-120), 2}, {"shift"})
			Spring.GiveOrderToUnit(scav, -(UDN.armguard_scav.id), {posx+(192), posy, posz+(-120), 2}, {"shift"})
		end
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamT1Spammer)
table.insert(ScavengerConstructorBlueprintsT4,DamgamT1Spammer)

-- local function DamgamT1EarlyFactory(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	-- local posradius = 96
	-- if radiusCheck then
		-- return posradius
	-- else
		-- local randomfac = {UDN.armap_scav.id, UDN.armhp_scav.id, UDN.armlab_scav.id, UDN.armvp_scav.id, UDN.corap_scav.id, UDN.corhp_scav.id, UDN.corlab_scav.id, UDN.corvp_scav.id,}
		-- Spring.GiveOrderToUnit(scav, -randomfac[math_random(1,#randomfac)], {posx, posy, posz, math_random(0,3)}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT0,DamgamT1EarlyFactory)
-- table.insert(ScavengerConstructorBlueprintsT1,DamgamT1EarlyFactory)
