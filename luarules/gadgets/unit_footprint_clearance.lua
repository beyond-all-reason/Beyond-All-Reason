local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Footprint clearance',
        desc      = 'Clears ground under newly build units any features that are under its footprint',
        author    = '',
        version   = '',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local unitXsize5 = {}
local unitZsize5 = {}
for unitDefID, unitDef in pairs(UnitDefs) do
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

	--Instagibb any features that are unlucky enough to be in the build radius of new construction projects
	if unitXsize5[uDefID] then	-- buildings/factories
		local xr, zr
		if Spring.GetUnitBuildFacing(uID) % 2 == 0 then
			xr, zr = unitXsize5[uDefID], unitZsize5[uDefID]
		else
			xr, zr = unitZsize5[uDefID], unitXsize5[uDefID]
		end

		local ux, _, uz = Spring.GetUnitPosition(uID)
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
