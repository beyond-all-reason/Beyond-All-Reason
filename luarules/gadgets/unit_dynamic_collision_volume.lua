local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Dynamic collision volume & Hitsphere Scaledown",
		desc      = "Adjusts collision volume for pop-up style units & Reduces the diameter of default sphere collision volume for 3DO models",
		author    = "Deadnight Warrior",
		date      = "Nov 26, 2011",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if gadgetHandler:IsSyncedCode() then

	-- Pop-up style unit and per piece collision volume definitions
	local popupUnits = {}		--list of pop-up style units
	local unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume

	-- Localization and speedups
	local spSetPieceCollisionData = Spring.SetUnitPieceCollisionVolumeData
	local spGetPieceList = Spring.GetUnitPieceList
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitCollisionData = Spring.GetUnitCollisionVolumeData
	local spSetUnitCollisionData = Spring.SetUnitCollisionVolumeData
	local spSetUnitRadiusAndHeight = Spring.SetUnitRadiusAndHeight
	local spGetUnitRadius = Spring.GetUnitRadius
	local spGetUnitHeight = Spring.GetUnitHeight
	local spSetUnitMidAndAimPos = Spring.SetUnitMidAndAimPos
	local spGetFeatureCollisionData = Spring.GetFeatureCollisionVolumeData
	local spSetFeatureCollisionData = Spring.SetFeatureCollisionVolumeData
	local spSetFeatureRadiusAndHeight = Spring.SetFeatureRadiusAndHeight
	local spGetFeatureRadius = Spring.GetFeatureRadius
	local spGetFeatureHeight = Spring.GetFeatureHeight

	local spArmor = Spring.GetUnitArmored
	local pairs = pairs
	
	local unitDefMidAndAimPos = {} -- this is a table read from customparams mapping unitDefID to 
	local featureDefMidAndAimPos = {} -- this is a table read from customparams mapping unitDefID to 
		-- {unitDefID  = {aimx, aimz, aimy, midx, midy, midz}}
	local function parseMidAndAimPos(defID, def, midAimPosTable, prefix)
		if def.customParams then
			if def.customParams['unit'..prefix..'pos'] then 
				if midAimPosTable[defID] == nil then 
					midAimPosTable[defID] = {}
				end 
				local midaimpossplit = string.split(def.customParams['unit'..prefix..'pos'], " ")
				if midaimpossplit[1] and tonumber(midaimpossplit[1]) then midAimPosTable[defID][prefix..'x'] = tonumber(midaimpossplit[1]) end 
				if midaimpossplit[2] and tonumber(midaimpossplit[2]) then midAimPosTable[defID][prefix..'y'] = tonumber(midaimpossplit[2]) end 
				if midaimpossplit[3] and tonumber(midaimpossplit[3]) then midAimPosTable[defID][prefix..'z'] = tonumber(midaimpossplit[3]) end 
				--Spring.Echo("Setting", 'unit'..prefix..'pos','to', midaimpossplit[1],midaimpossplit[2],midaimpossplit[3])
			end
		end
	end
	
	local is3doFeature = {}
	for featureDefID, def in pairs(FeatureDefs) do
		parseMidAndAimPos(featureDefID, def, featureDefMidAndAimPos, 'aim')
		parseMidAndAimPos(featureDefID, def, featureDefMidAndAimPos, 'mid')
		if def.modelpath:lower():find(".3do") then
			is3doFeature[featureDefID] = true
		end
	end

	local unitName = {}
	local unitModeltype ={}
	local canFly = {}
	for unitDefID, def in pairs(UnitDefs) do
		parseMidAndAimPos(unitDefID, def, unitDefMidAndAimPos, 'aim')
		parseMidAndAimPos(unitDefID, def, unitDefMidAndAimPos, 'mid')
		unitName[unitDefID] = def.name
		unitModeltype[unitDefID] = def.modeltype
		if def.canFly then
			canFly[unitDefID] = def.canFly
		end
	end
	--unitDefMidAndAimPos[UnitDefNames['armllt'].id] = { midx = -5, midy = 0, midz= 0, aimx = -40, aimy = 20, aimz = 20}
	--unitDefMidAndAimPos[UnitDefNames['corak'].id] = { midx = 0, midy = 0, midz= 0, aimx = -40, aimy = 20, aimz = 20}
	--Process all initial map features
	function gadget:Initialize()
		--loading the file here allows to have /luarules reload dyn reload it as necessary
		unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume = include("LuaRules/Configs/CollisionVolumes.lua")
		local mapConfig = "LuaRules/Configs/DynCVmapCFG/" .. Game.mapName .. ".lua"

		local allFeatures = Spring.GetAllFeatures()
		if VFS.FileExists(mapConfig) then
			local mapFeatures = VFS.Include(mapConfig)
			for i=1,#allFeatures do
				local featID = allFeatures[i]
				local modelpath = FeatureDefs[Spring.GetFeatureDefID(featID)].modelpath
				local featureModel = modelpath:lower()
				if featureModel:len() > 4 then
					local featureModelTrim = featureModel:sub(1,-5) -- featureModel:match("/.*%."):sub(2,-2)
					if mapFeatures[featureModelTrim] then
						local p = mapFeatures[featureModelTrim]
						spSetFeatureCollisionData(featID, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9])
						spSetFeatureRadiusAndHeight(featID, math.min(p[1], p[3])/2, p[2])
					elseif featureModel:find(".s3o") then
						local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetFeatureCollisionData(featID)
						--Spring.Echo(featureModel, xs, ys, zs, xo, yo, zo, vtype, htype, axis)
						if (vtype>=3 and xs==ys and ys==zs) then
                            spSetFeatureCollisionData(featID, xs, ys*0.75, zs,  xo, yo-ys*0.09, zo,  1, htype, 1)
						end
					end
				end
			end
		else
			for i=1,#allFeatures do
				local featID = allFeatures[i]
				local modelpath = FeatureDefs[Spring.GetFeatureDefID(featID)].modelpath
				local featureModel = modelpath:lower()
				if featureModel:find(".3do") then
					local rs, hs
					if (spGetFeatureRadius(featID)>47) then
						rs, hs = 0.68, 0.60
					else
						rs, hs = 0.75, 0.67
					end
					local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetFeatureCollisionData(featID)
					if (vtype>=3 and xs==ys and ys==zs) then
						spSetFeatureCollisionData(featID, xs*rs, ys*hs, zs*rs,  xo, yo-ys*0.1323529*rs, zo,  vtype, htype, axis)
					end
					spSetFeatureRadiusAndHeight(featID, spGetFeatureRadius(featID)*rs, spGetFeatureHeight(featID)*hs)
				elseif featureModel:find(".s3o") then
					local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetFeatureCollisionData(featID)
					if (vtype>=3 and xs==ys and ys==zs) then
						spSetFeatureCollisionData(featID, xs, ys*0.75, zs,  xo, yo-ys*0.09, zo,  vtype, htype, axis)
					end
				end
			end
		end
		local allUnits = Spring.GetAllUnits()
		for i=1,#allUnits do
			local unitID = allUnits[i]
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
			--gadget:UnitFinished(unitID, spGetUnitDefID(unitID))
		end
		for i=1,#allFeatures do
			gadget:FeatureCreated(allFeatures[i])
		end
	end

	--Reduces the diameter of default (unspecified) collision volume for 3DO models,
	--for S3O models it's not needed and will in fact result in wrong collision volume
	--also handles per piece collision volume definitions
	--also makes sure subs are underwater
	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitDefMidAndAimPos[unitDefID] then 
			local midAndAimPos = unitDefMidAndAimPos[unitDefID]
			Spring.SetUnitMidAndAimPos(unitID, 
				midAndAimPos['midx'] or 0,
				midAndAimPos['midy'] or 0,
				midAndAimPos['midz'] or 0,
				(midAndAimPos['aimx'] or 0) * -1, -- because engine is bugged
				midAndAimPos['aimy'] or 0,
				midAndAimPos['aimz'] or 0, -- relative?
				true)
		end
		if pieceCollisionVolume[unitName[unitDefID]] then
			local t = pieceCollisionVolume[unitName[unitDefID]]
			for pieceIndex=0, #spGetPieceList(unitID)-1 do
				local p = t[tostring(pieceIndex)]
				if p then
					spSetPieceCollisionData(unitID, pieceIndex + 1, true, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8])
				else
					spSetPieceCollisionData(unitID, pieceIndex + 1, false, 1, 1, 1, 0, 0, 0, 1, 1)
				end
				if t.offsets then
					p = t.offsets
					spSetUnitMidAndAimPos(unitID, 0, spGetUnitHeight(unitID)/2, 0, p[1], p[2], p[3],true)
				end
			end
		elseif dynamicPieceCollisionVolume[unitName[unitDefID]] then
			local t = dynamicPieceCollisionVolume[unitName[unitDefID]].on
			for pieceIndex=0, #spGetPieceList(unitID)-1 do
				local p = t[tostring(pieceIndex)]
				if p then
					spSetPieceCollisionData(unitID, pieceIndex + 1, true, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8])
				else
					spSetPieceCollisionData(unitID, pieceIndex + 1, false, 1, 1, 1, 0, 0, 0, 1, 1)
				end
			end
		elseif unitModeltype[unitDefID] == "3do" then
			local rs, hs, ws
			local r = spGetUnitRadius(unitID)
			if r>47 and not canFly[unitDefID] then
				rs, hs, ws = 0.68, 0.68, 0.68
			elseif not canFly[unitDefID] then
				rs, hs, ws = 0.73, 0.73, 0.73
			else
				rs, hs, ws = 0.53, 0.17, 0.53
			end
			local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetUnitCollisionData(unitID)
			if vtype>=3 and xs==ys and ys==zs then
			  if ys*hs < 13 and canFly[unitDefID] then -- Limit Max V height
			    spSetUnitCollisionData(unitID, xs*ws, 13, zs*rs,  xo, yo, zo,  1, htype, 1)
			  elseif canFly[unitDefID] then
				spSetUnitCollisionData(unitID, xs*ws, ys*hs, zs*rs,  xo, yo, zo,  1, htype, 1)
			  else
				spSetUnitCollisionData(unitID, xs*ws, ys*hs, zs*rs,  xo, yo, zo,  vtype, htype, axis)
			  end
			end

			-- set aircraft size
			if canFly[unitDefID] and UnitDefs[unitDefID].transportCapacity>0 then
				spSetUnitRadiusAndHeight(unitID, 16, 16)
			else
				spSetUnitRadiusAndHeight(unitID, spGetUnitRadius(unitID)*rs, spGetUnitHeight(unitID)*hs)
			end

			-- make sure underwater units are really underwater (need midpoint + model radius <0)
			local h = spGetUnitHeight(unitID)
			local wd = UnitDefs[unitDefID].minWaterDepth
			if UnitDefs[unitDefID].modCategories['underwater'] and wd and wd+r>0 then
				spSetUnitRadiusAndHeight(unitID, wd-1, h)
			end
		elseif unitModeltype[unitDefID] == "s3o" then
			if canFly[unitDefID] then
				local rs, hs, ws = 1.15, 0.33, 1.15	-- dont know why 3do uses: 0.53, 0.17, 0.53
				local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetUnitCollisionData(unitID)
				if vtype>=3 and xs==ys and ys==zs then
					if ys*hs < 13 then -- Limit Max V height
						spSetUnitCollisionData(unitID, xs*ws, 13, zs*rs,  xo, yo, zo,  3, htype, 0)
					elseif canFly[unitDefID] then
						spSetUnitCollisionData(unitID, xs*ws, ys*hs, zs*rs,  xo, yo, zo,  3, htype, 0)
					else
						spSetUnitCollisionData(unitID, xs*ws, ys*hs, zs*rs,  xo, yo, zo,  vtype, htype, axis)
					end
				end
			end
		end
		
		-- Check if a unit is pop-up type (the list must be entered manually)
		-- If a building was constructed add it to the list for later radius and height scaling
		-- Changed from UnitFinished to UnitCreated
		-- Some building's scripting change their collision while still under construction
		-- These buildings should be added to the list of popupUnits to update when they are created, not when finished
		local un = unitName[unitDefID]
		if unitCollisionVolume[un] then
			popupUnits[unitID]={name=un, state=-1, perPiece=false}
		elseif dynamicPieceCollisionVolume[un] then
			popupUnits[unitID]={name=un, state=-1, perPiece=true, numPieces = #spGetPieceList(unitID)-1}
		end
	end


	-- Same as for 3DO units, but for features
	function gadget:FeatureCreated(featureID, allyTeam)
		if featureDefMidAndAimPos[featureDefID] then 
			--Spring.SetFeatureMidAndAimPos ( number featureID, number mpX, number mpY, number mpZ, number apX, number apY, number apZ [, bool relative )
			local midAndAimPos = featureDefMidAndAimPos[featureDefID]
			Spring.SetFeatureMidAndAimPos(featureID, 
				midAndAimPos['midx'] or 0,
				midAndAimPos['midy'] or 0,
				midAndAimPos['midz'] or 0,
				(midAndAimPos['aimx'] or 0) * -1, -- because engine is bugged
				midAndAimPos['aimy'] or 0,
				midAndAimPos['aimz'] or 0-- relative?
				)
		end
		if is3doFeature[Spring.GetFeatureDefID(featureID)] then
			local rs, hs
			if spGetFeatureRadius(featureID)>47 then
				rs, hs = 0.68, 0.60
			else
				rs, hs = 0.75, 0.67
			end
			local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetFeatureCollisionData(featureID)
			if vtype>=3 and xs==ys and ys==zs then
				spSetFeatureCollisionData(featureID, xs*rs, ys*hs, zs*rs,  xo, yo-ys*0.09, zo,  vtype, htype, axis)
			end
			spSetFeatureRadiusAndHeight(featureID, spGetFeatureRadius(featureID)*rs, spGetFeatureHeight(featureID)*hs)
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
		if n%15 ~= 0 then
			return
		end
		local p, t, stateString, stateInt
		for unitID,defs in pairs(popupUnits) do
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
					for pieceIndex=0, defs.numPieces do
						p = t[tostring(pieceIndex)]
						if p then
							spSetPieceCollisionData(unitID, pieceIndex + 1, true, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8])
						else
							spSetPieceCollisionData(unitID, pieceIndex + 1, false, 1, 1, 1, 0, 0, 0, 1, 1)
						end
					end
					if t.offsets then
						p = t.offsets
						local unitHeight = spGetUnitHeight(unitID)
						if unitHeight == nil then  -- had error once, hope this nil check helps
							popupUnits[unitID] = nil
						else
							spSetUnitMidAndAimPos(unitID, 0, unitHeight/2, 0, p[1], p[2], p[3],true)
						end
					end
				else
					local unitHeight = spGetUnitHeight(unitID)
					if unitHeight == nil then  -- had error once, hope this nil check helps
						popupUnits[unitID] = nil
					else
						p = unitCollisionVolume[defs.name][stateString]
						spSetUnitCollisionData(unitID, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9])
						if p[10] then
							spSetUnitMidAndAimPos(unitID, 0, unitHeight/2, 0, p[10], p[11], p[12],true)
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
