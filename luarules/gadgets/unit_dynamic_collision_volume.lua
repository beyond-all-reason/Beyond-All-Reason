local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Dynamic collision volume & Hitsphere Scaledown",
		desc = "Adjusts collision volume for pop-up style units & Reduces the diameter of default sphere collision volume for 3DO models",
		author = "Deadnight Warrior",
		date = "Nov 26, 2011",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	local popupUnits = {} --list of pop-up style units
	local unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume, modelUnitCollisionVolume, modelToVolume

	-- Localization and speedups
	local spSetPieceCollisionData = Spring.SetUnitPieceCollisionVolumeData
	local spGetPieceList = Spring.GetUnitPieceList
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitCollisionData = Spring.GetUnitCollisionVolumeData
	local spSetUnitCollisionData = Spring.SetUnitCollisionVolumeData
	local spSetUnitRadiusAndHeight = Spring.SetUnitRadiusAndHeight
	local spGetUnitHeight = Spring.GetUnitHeight
	local spSetUnitMidAndAimPos = Spring.SetUnitMidAndAimPos
	local spGetFeatureDefID = Spring.GetFeatureDefID

	local spArmor = Spring.GetUnitArmored
	local pairs = pairs
	local featureModelType = {}
	for featureDefID, def in pairs(FeatureDefs) do
		featureModelType[featureDefID] = def.modeltype
	end

	local unitName = {}
	local unitModeltype = {}
	local canFly = {}
	for unitDefID, def in pairs(UnitDefs) do
		unitName[unitDefID] = def.name
		unitModeltype[unitDefID] = def.modeltype
		if def.canFly then
			canFly[unitDefID] = def.canFly
		end
	end

	function gadget:Initialize()
		unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume, modelUnitCollisionVolume, modelToVolume =
			include("LuaRules/Configs/CollisionVolumes.lua")

		local allFeatures = Spring.GetAllFeatures()
		for i = 1, #allFeatures do
			local featID = allFeatures[i]
			if featureModelType[spGetFeatureDefID(featID)] == "s3o" then
				modelToVolume.FEATURE["s3o"].rescale(featID)
			end
		end
		local allUnits = Spring.GetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
		end
		for i = 1, #allFeatures do
			gadget:FeatureCreated(allFeatures[i])
		end
	end

	--Reduces the diameter of default (unspecified) collision volume for 3DO models,
	--for S3O models it's not needed and will in fact result in wrong collision volume
	--also handles per piece collision volume definitions
	--also makes sure subs are underwater
	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if pieceCollisionVolume[unitName[unitDefID]] then
			local t = pieceCollisionVolume[unitName[unitDefID]]
			for pieceIndex = 1, #spGetPieceList(unitID) do
				local p = t[pieceIndex]
				if p then
					spSetPieceCollisionData(
						unitID,
						pieceIndex,
						p[9] ~= false,
						p[1],
						p[2],
						p[3],
						p[4],
						p[5],
						p[6],
						p[7],
						p[8]
					)
				else
					spSetPieceCollisionData(unitID, pieceIndex, false, 1, 1, 1, 0, 0, 0, 1, 1)
				end
			end
			if t.offsets then
				local o = t.offsets
				spSetUnitMidAndAimPos(unitID, 0, spGetUnitHeight(unitID) / 2, 0, o[1], o[2], o[3], true)
			end
		elseif dynamicPieceCollisionVolume[unitName[unitDefID]] then
			local t = dynamicPieceCollisionVolume[unitName[unitDefID]].on
			for pieceIndex = 1, #spGetPieceList(unitID) do
				local p = t[pieceIndex]
				if p then
					spSetPieceCollisionData(
						unitID,
						pieceIndex,
						p[9] ~= false,
						p[1],
						p[2],
						p[3],
						p[4],
						p[5],
						p[6],
						p[7],
						p[8]
					)
				else
					spSetPieceCollisionData(unitID, pieceIndex, false, 1, 1, 1, 0, 0, 0, 1, 1)
				end
			end
		elseif modelUnitCollisionVolume[unitName[unitDefID]] then
			local v = modelUnitCollisionVolume[unitName[unitDefID]]
			if v[9] == nil then
				-- The first unit created of a given model provides the missing primaryAxis value.
				v[9] = select(9, spGetUnitCollisionData(unitID))
			end
			spSetUnitCollisionData(unitID, v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9])
			if v.radius then
				spSetUnitRadiusAndHeight(unitID, v.radius, v.height)
			end
		end

		-- Check if a unit is pop-up type (the list must be entered manually)
		-- If a building was constructed add it to the list for later radius and height scaling
		-- Changed from UnitFinished to UnitCreated
		-- Some building's scripting change their collision while still under construction
		-- These buildings should be added to the list of popupUnits to update when they are created, not when finished
		local un = unitName[unitDefID]
		if unitCollisionVolume[un] then
			popupUnits[unitID] = { name = un, state = -1, perPiece = false }
		elseif dynamicPieceCollisionVolume[un] then
			popupUnits[unitID] = { name = un, state = -1, perPiece = true }
		end
	end

	function gadget:FeatureCreated(featureID, allyTeam)
		if featureModelType[spGetFeatureDefID(featureID)] == "3do" then
			modelToVolume.FEATURE["3do"].rescale(featureID)
		end
	end

	--check if a pop-up type unit was destroyed
	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		if popupUnits[unitID] then
			popupUnits[unitID] = nil
		end
	end

	--Dynamic adjustment of pop-up style of units' collision volumes based on unit's ARMORED status, runs twice per second
	--rescaling of radius and height of 3DO buildings
	function gadget:GameFrame(n)
		if n % 15 ~= 0 then
			return
		end
		local p, t, stateString, stateInt
		for unitID, defs in pairs(popupUnits) do
			if spArmor(unitID) then
				stateString = "off"
				stateInt = 0
			else
				stateString = "on"
				stateInt = 1
			end
			if defs.state ~= stateInt then
				if defs.perPiece then
					t = dynamicPieceCollisionVolume[defs.name][stateString]
					for pieceIndex, piece in pairs(t) do
						if type(pieceIndex) == "number" then
							spSetPieceCollisionData(
								unitID,
								pieceIndex,
								piece[9] ~= false,
								piece[1],
								piece[2],
								piece[3],
								piece[4],
								piece[5],
								piece[6],
								piece[7],
								piece[8]
							)
						end
					end
					if t.offsets then
						p = t.offsets
						local unitHeight = spGetUnitHeight(unitID)
						if unitHeight == nil then -- had error once, hope this nil check helps
							popupUnits[unitID] = nil
						else
							spSetUnitMidAndAimPos(unitID, 0, unitHeight / 2, 0, p[1], p[2], p[3], true)
						end
					end
				else
					local unitHeight = spGetUnitHeight(unitID)
					if unitHeight == nil then -- had error once, hope this nil check helps
						popupUnits[unitID] = nil
					else
						p = unitCollisionVolume[defs.name][stateString]
						spSetUnitCollisionData(unitID, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9])
						if p[10] then
							spSetUnitMidAndAimPos(unitID, 0, unitHeight / 2, 0, p[10], p[11], p[12], true)
						end
					end
				end
				if popupUnits[unitID] ~= nil then
					popupUnits[unitID].state = stateInt
				end
			end
		end
	end
end
