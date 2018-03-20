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

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------


	function gadget:UnitCreated(uID, uDefID, uTeam, bID)
   
		local uDef = UnitDefs[uDefID]
		
		--Fix for bad movement in 102
		--https://springrts.com/phpbb/viewtopic.php?f=12&t=34593
		local md = uDef.moveDef
		if (md.type ~= nil) then -- all non-flying units
			Spring.MoveCtrl.SetGroundMoveTypeData(uID, "turnAccel", uDef.turnRate)
		end
		
		--Instagibb any features that are unlucky enough to be in the build radius of new construction projects
		if uDef.isBuilding or uDef.isFactory then
			--Spring.Echo("Wheee it spins!")
			local ux, uy, uz = Spring.GetUnitPosition(uID)
			local xr, zr
			if Spring.GetUnitBuildFacing(uID) % 2 == 0 then
 				xr, zr = 5 * uDef.xsize, 5 * uDef.zsize
 			else
 				xr, zr = 5 * uDef.zsize, 5 * uDef.xsize
			end
		
			local features = Spring.GetFeaturesInRectangle(ux-xr, uz-zr, ux+xr, uz+zr)
			for i = 1, #features do
				local fID = features[i]
				local fDefID = Spring.GetFeatureDefID(fID)
				local fDef = FeatureDefs[fDefID]
			
				if (not fDef.geoThermal) and (fDef.name ~= 'geovent') 
				and (fDef.name ~= 'xelnotgawatchtower') 
				and (fDef.name ~= 'crystalring') 
				then
					local fx, fy, fz = Spring.GetFeaturePosition(fID)
					Spring.DestroyFeature(fID)
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
		return damage
	end

end

	--UNSYNCED