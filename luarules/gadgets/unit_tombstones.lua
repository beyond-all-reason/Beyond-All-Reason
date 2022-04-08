
function gadget:GetInfo()
	return {
		name		= "Tombstones",
		desc		= "Adds a tombstone next to commander wreck",
		author		= "Floris",
		date		= "December 2021",
		license		= "",
		layer		= 0,
		enabled		= true,
	}
end

if gadgetHandler:IsSyncedCode() then

	local isCommander = {}
	for defID, def in ipairs(UnitDefs) do
		if def.customParams.iscommander ~= nil and not string.find(def.name, "scav") then
			isCommander[defID] = def.name == 'armcom' and FeatureDefNames.armstone.id or FeatureDefNames.corstone.id
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		if isCommander[unitDefID] then
			local px,py,pz = Spring.GetUnitPosition(unitID)
			pz = pz - 40
			local tombstoneID = Spring.CreateFeature(isCommander[unitDefID], px, Spring.GetGroundHeight(px,pz), pz, 0, teamID)
			if tombstoneID then
				local rx,ry,rz = Spring.GetFeatureRotation(tombstoneID)
				rx = rx + 0.18 + (math.random(0, 6) / 50)
				rz = rz - 0.12 + (math.random(0, 12) / 50)
				ry = ry - 0.12 + (math.random(0, 12) / 50)
				Spring.SetFeatureRotation(tombstoneID, rx,ry,rz)
			end
		end
	end


else


	local drawTombstones = Spring.GetConfigInt("tombstones", 1) == 1
	local updateTimer = 0
	local tombstones = {}

	local isTombstone = {
		[FeatureDefNames.armstone.id] = 'armstone',
		[FeatureDefNames.corstone.id] = 'corstone',
	}

	function gadget:Initialize()
		local allFeatures = Spring.GetAllFeatures()
		for i = 1, #allFeatures do
			local featureID = allFeatures[i]
			gadget:FeatureCreated(featureID)
		end
	end

	function gadget:Shutdown()
		for featureID, v in pairs(tombstones) do
			Spring.FeatureRendering.SetFeatureLuaDraw(featureID, not drawTombstones)
		end
	end

	function gadget:Update()
		updateTimer = updateTimer + Spring.GetLastUpdateSeconds()
		if updateTimer > 0.7 then
			updateTimer = 0
			local prevDrawTombstones = drawTombstones
			drawTombstones = Spring.GetConfigInt("tombstones", 1) == 1
			if drawTombstones ~= prevDrawTombstones then
				for featureID, v in pairs(tombstones) do
					Spring.FeatureRendering.SetFeatureLuaDraw(featureID, not drawTombstones)
				end
			end
		end
	end

	function gadget:FeatureCreated(featureID, allyTeamID)
		if isTombstone[Spring.GetFeatureDefID(featureID)] then
			tombstones[featureID] = true
			if not drawTombstones then
				Spring.FeatureRendering.SetFeatureLuaDraw(featureID, true)
			end
		end
	end

	function gadget:DrawFeature(featureID, drawMode)
		if isTombstone[Spring.GetFeatureDefID(featureID)] then
			gl.Scale( 0, 0, 0 )
			return false
		end
	end
end
