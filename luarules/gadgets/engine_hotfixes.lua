function gadget:GetInfo()
    return {
        name      = 'Engine Hotfixes for Various Engine Kludges',
        desc      = '',
        author    = '',
        version   = 'v1.0',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local unitTurnrate = {}
local unitXsize5 = {}
local unitZsize5 = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.moveDef and unitDef.moveDef.type ~= nil then
		unitTurnrate[unitDefID] = unitDef.turnRate
	end
	if unitDef.isBuilding or unitDef.isFactory then
		unitXsize5[unitDefID] = unitDef.xsize * 5
		unitZsize5[unitDefID] = unitDef.zsize * 5
	end
end
local gibFeatureDefs = {}
for featureDefID, fDef in pairs(FeatureDefs) do
	if not fDef.geoThermal and fDef.name ~= 'geovent' and fDef.name ~= 'xelnotgawatchtower' and fDef.name ~= 'crystalring' then
		gibFeatureDefs[featureDefID] = true
	end
end

function gadget:UnitCreated(uID, uDefID, uTeam, bID)

	--Fix for bad movement in 102
	--https://springrts.com/phpbb/viewtopic.php?f=12&t=34593
	--if unitTurnrate[uDefID] then -- all non-flying units
	--	Spring.MoveCtrl.SetGroundMoveTypeData(uID, "turnAccel", unitTurnrate[uDefID])
	--end

	--Instagibb any features that are unlucky enough to be in the build radius of new construction projects
	if unitXsize5[uDefID] then	-- buildings/factories
		local xr, zr
		if Spring.GetUnitBuildFacing(uID) % 2 == 0 then
			xr, zr = unitXsize5[uDefID], unitZsize5[uDefID]
		else
			xr, zr = unitZsize5[uDefID], unitXsize5[uDefID]
		end

		local ux, uy, uz = Spring.GetUnitPosition(uID)
		local features = Spring.GetFeaturesInRectangle(ux-xr, uz-zr, ux+xr, uz+zr)
		for i = 1, #features do
			if gibFeatureDefs[Spring.GetFeatureDefID(features[i])] then
				local fx, fy, fz = Spring.GetFeaturePosition(features[i])
				Spring.DestroyFeature(features[i])
				Spring.SpawnCEG('sparklegreen', fx, fy, fz)
				Spring.PlaySoundFile('reclaimate', 1, fx, fy, fz, 'sfx')
			end
		end
	end
end

--Remove damage hardcoded in the engine of gibbed pieces of units (hardcoded to 50 damage in engine)
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if weaponDefID == -1 then
		return 0, 0
	end
	return damage, 1
end
