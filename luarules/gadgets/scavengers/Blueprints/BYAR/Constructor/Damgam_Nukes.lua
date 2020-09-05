--	facing:
--  0 - south
--  1 - east
--  2 - north
--  3 - west

local UDN = UnitDefNames
local nameSuffix = '_scav'

local function DamgamNukeOutpost1(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 80
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(72), posy, posz+(72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(0), posy, posz+(80), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corsilo_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-72), posy, posz+(-72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(-72), posy, posz+(72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(0), posy, posz+(-80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(72), posy, posz+(-72), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(80), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(-80), posy, posz+(0), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost1)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost1)

local function DamgamNukeOutpost2(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 112
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corfmd_scav.id), {posx+(104), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(104), posy, posz+(-56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(-112), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corsilo_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfmd_scav.id), {posx+(-104), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-24), posy, posz+(104), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(-48), posy, posz+(-96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(48), posy, posz+(96), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(-104), posy, posz+(56), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(112), posy, posz+(96), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(24), posy, posz+(-104), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost2)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost2)

local function DamgamNukeOutpost3(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 192
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(-104), posy, posz+(-56), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corsilo_scav.id), {posx+(0), posy, posz+(0), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(-24), posy, posz+(-104), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfmd_scav.id), {posx+(56), posy, posz+(-104), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(128), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(104), posy, posz+(-24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(104), posy, posz+(56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(96), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(-96), posy, posz+(-128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(-104), posy, posz+(24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corfmd_scav.id), {posx+(-56), posy, posz+(104), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(24), posy, posz+(104), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(16), posy, posz+(-192), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corvipe_scav.id), {posx+(-128), posy, posz+(96), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corint_scav.id), {posx+(-16), posy, posz+(192), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost3)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost3)

local function DamgamNukeOutpost4(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 80
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armveil_scav.id), {posx+(-72), posy, posz+(-72), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(0), posy, posz+(80), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armsilo_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armveil_scav.id), {posx+(-72), posy, posz+(72), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(80), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armveil_scav.id), {posx+(72), posy, posz+(-72), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-80), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(0), posy, posz+(-80), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armveil_scav.id), {posx+(72), posy, posz+(72), 2}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost4)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost4)

local function DamgamNukeOutpost5(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 112
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(104), posy, posz+(-56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(104), posy, posz+(24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(-104), posy, posz+(-24), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(-24), posy, posz+(104), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armsilo_scav.id), {posx+(0), posy, posz+(0), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(24), posy, posz+(-104), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-112), posy, posz+(-96), 2}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(112), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(48), posy, posz+(96), 0}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-104), posy, posz+(56), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-48), posy, posz+(-96), 2}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost5)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost5)

local function DamgamNukeOutpost6(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 184
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-96), posy, posz+(-128), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(-8), posy, posz+(184), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(-104), posy, posz+(-56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(104), posy, posz+(56), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(-128), posy, posz+(96), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armemp_scav.id), {posx+(24), posy, posz+(104), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armemp_scav.id), {posx+(-104), posy, posz+(24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armsilo_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armemp_scav.id), {posx+(-24), posy, posz+(-104), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(96), posy, posz+(128), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-56), posy, posz+(104), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armemp_scav.id), {posx+(104), posy, posz+(-24), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(56), posy, posz+(-104), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armbrtha_scav.id), {posx+(8), posy, posz+(-184), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armpb_scav.id), {posx+(128), posy, posz+(-96), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost6)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost6)

local function DamgamNukeOutpost7(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 64
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(-64), posy, posz+(64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(-64), posy, posz+(-64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cordoom_scav.id), {posx+(64), posy, posz+(-64), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(64), posy, posz+(64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corshroud_scav.id), {posx+(0), posy, posz+(0), 3}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost7)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost7)

local function DamgamNukeOutpost8(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 64
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(-64), posy, posz+(64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armemp_scav.id), {posx+(-64), posy, posz+(-64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armemp_scav.id), {posx+(64), posy, posz+(64), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armveil_scav.id), {posx+(0), posy, posz+(0), 3}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armanni_scav.id), {posx+(64), posy, posz+(-64), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost8)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost8)

local function DamgamNukeOutpost9(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 112
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-112), posy, posz+(112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.cortron_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(112), posy, posz+(-112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(0), posy, posz+(112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(112), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-112), posy, posz+(-112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(-112), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(112), posy, posz+(112), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.corscreamer_scav.id), {posx+(0), posy, posz+(-112), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost9)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost9)

local function DamgamNukeOutpost10(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	local posradius = 96
	if radiusCheck then
		return posradius
	else
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(96), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armemp_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(-96), posy, posz+(0), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(0), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(-96), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(96), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(-96), posy, posz+(96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(0), posy, posz+(-96), 1}, {"shift"})
		Spring.GiveOrderToUnit(scav, -(UDN.armmercury_scav.id), {posx+(96), posy, posz+(0), 1}, {"shift"})
	end
end
table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost10)
table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost10)

-- local function DamgamNukeOutpost11(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	-- local posradius = 72
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(72), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(24), posy, posz+(72), 0}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(-24), posy, posz+(-72), 2}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(-24), posy, posz+(72), 0}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(24), posy, posz+(-72), 2}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(72), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(-72), posy, posz+(24), 3}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.corfmd_scav.id), {posx+(0), posy, posz+(0), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.cortoast_scav.id), {posx+(-72), posy, posz+(-24), 3}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost11)
-- table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost11)

-- local function DamgamNukeOutpost12(scav, posx, posy, posz, GaiaTeamID, radiusCheck)
	-- local posradius = 72
	-- if radiusCheck then
		-- return posradius
	-- else
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(72), posy, posz+(-24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-72), posy, posz+(-24), 3}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-24), posy, posz+(72), 0}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-72), posy, posz+(24), 3}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(72), posy, posz+(24), 1}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(-24), posy, posz+(-72), 2}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(24), posy, posz+(-72), 2}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamb_scav.id), {posx+(24), posy, posz+(72), 0}, {"shift"})
		-- Spring.GiveOrderToUnit(scav, -(UDN.armamd_scav.id), {posx+(0), posy, posz+(0), 0}, {"shift"})
	-- end
-- end
-- table.insert(ScavengerConstructorBlueprintsT3,DamgamNukeOutpost12)
-- table.insert(ScavengerConstructorBlueprintsT4,DamgamNukeOutpost12)
