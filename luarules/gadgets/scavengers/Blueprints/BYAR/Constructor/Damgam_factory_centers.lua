--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

local UDN = UnitDefNames
local nameSuffix = '_scav'

local function DamgamFactoryCenterKbotT1Red(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 128
	if radiusCheck then
		return posradius
	else	
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
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamFactoryCenterKbotT1Red)

local function DamgamFactoryCenterKbotT1Blue(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 120
	if radiusCheck then
		return posradius
	else	
		
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(24), posy, posz+(24), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(24), posy, posz+(-24), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(-24), posy, posz+(-24), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(-24), posy, posz+(24), 3}, {"shift"})
		
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
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamFactoryCenterKbotT1Blue)

local function DamgamFactoryCenterVehT1Red(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 136
	if radiusCheck then
		return posradius
	else	
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
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamFactoryCenterVehT1Red)

local function DamgamFactoryCenterVehT1Blue(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 128
	if radiusCheck then
		return posradius
	else	
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(24), posy, posz+(24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(-24), posy, posz+(-24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(24), posy, posz+(-24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(-24), posy, posz+(24), 2}, {"shift"})
		
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
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamFactoryCenterVehT1Blue)

local function DamgamFactoryCenterAirT1Red(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 208
	if radiusCheck then
		return posradius
	else	
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
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamFactoryCenterAirT1Red)

local function DamgamFactoryCenterAirT1Blue(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 192
	if radiusCheck then
		return posradius
	else	
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(0), posy, posz+(24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(48), posy, posz+(24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(-48), posy, posz+(-24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(48), posy, posz+(-24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(-48), posy, posz+(24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpacko_scav.id), {posx+(0), posy, posz+(-24), 2}, {"shift"})
		
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
table.insert(ScavengerConstructorBlueprintsT3,DamgamFactoryCenterAirT1Blue)