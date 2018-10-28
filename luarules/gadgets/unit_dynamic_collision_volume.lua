function gadget:GetInfo()
  return {
    name      = "Dynamic collision volume & Hitsphere Scaledown",
    desc      = "Adjusts collision volume for pop-up style units & Reduces the diameter of default sphere collision volume for 3DO models",
    author    = "Deadnight Warrior",
    date      = "Nov 26, 2011",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

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


if (gadgetHandler:IsSyncedCode()) then

	--Process all initial map features
	function gadget:Initialize()
		--loading the file here allows to have /luarules reload dyn reload it as necessary
		unitCollisionVolume, pieceCollisionVolume, dynamicPieceCollisionVolume = include("LuaRules/Configs/CollisionVolumes.lua")
		local mapConfig = "LuaRules/Configs/DynCVmapCFG/" .. Game.mapName .. ".lua"
		if VFS.FileExists(mapConfig) then
			local mapFeatures = VFS.Include(mapConfig)
			for _, featID in pairs(Spring.GetAllFeatures()) do
				local modelpath = FeatureDefs[Spring.GetFeatureDefID(featID)].modelpath
				if modelpath == nil then
					modelpath = FeatureDefs[Spring.GetFeatureDefID(featID)].model.path
				end
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
			for _, featID in pairs(Spring.GetAllFeatures()) do
				local modelpath = FeatureDefs[Spring.GetFeatureDefID(featID)].modelpath
				if modelpath == nil then    -- engine < 104 compatibility
					modelpath = FeatureDefs[Spring.GetFeatureDefID(featID)].model.path
				end
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
		for _,unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
			gadget:UnitFinished(unitID, spGetUnitDefID(unitID))
		end
		for _,featureID in pairs(Spring.GetAllFeatures()) do
			gadget:FeatureCreated(featureID)
		end
	end

	
	--Reduces the diameter of default (unspecified) collision volume for 3DO models,
	--for S3O models it's not needed and will in fact result in wrong collision volume
	--also handles per piece collision volume definitions
	--also makes sure subs are underwater
	function gadget:UnitCreated(unitID, unitDefID, unitTeam)

		local modeltype = UnitDefs[unitDefID].modeltype
		if modeltype == nil then    -- engine < 104 compatibility
			modeltype = UnitDefs[unitDefID].model.type
		end
		if (pieceCollisionVolume[UnitDefs[unitDefID].name]) then
			local t = pieceCollisionVolume[UnitDefs[unitDefID].name]
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
		elseif dynamicPieceCollisionVolume[UnitDefs[unitDefID].name] then
			local t = dynamicPieceCollisionVolume[UnitDefs[unitDefID].name].on
			for pieceIndex=0, #spGetPieceList(unitID)-1 do
				local p = t[tostring(pieceIndex)]
				if p then
					spSetPieceCollisionData(unitID, pieceIndex + 1, true, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8])
				else
					spSetPieceCollisionData(unitID, pieceIndex + 1, false, 1, 1, 1, 0, 0, 0, 1, 1)
				end
			end
		elseif modeltype=="3do" then
			local rs, hs, ws
			local r = spGetUnitRadius(unitID) 
			if (r>47 and not UnitDefs[unitDefID].canFly) then
				rs, hs, ws = 0.68, 0.68, 0.68
			elseif (not UnitDefs[unitDefID].canFly) then
				rs, hs, ws = 0.73, 0.73, 0.73
			else
				rs, hs, ws = 0.53, 0.17, 0.53
			end
			local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetUnitCollisionData(unitID)
			if (vtype>=3 and xs==ys and ys==zs) then
			  if ( ys*hs ) < 13 and (UnitDefs[unitDefID].canFly) then -- Limit Max V height
			        spSetUnitCollisionData(unitID, xs*ws, 13, zs*rs,  xo, yo, zo,  1, htype, 1)
			  elseif (UnitDefs[unitDefID].canFly) then
				spSetUnitCollisionData(unitID, xs*ws, ys*hs, zs*rs,  xo, yo, zo,  1, htype, 1)
			  else 
				spSetUnitCollisionData(unitID, xs*ws, ys*hs, zs*rs,  xo, yo, zo,  vtype, htype, axis)
			  end
			end
			
			-- set aircraft size 
			if UnitDefs[unitDefID].canFly and UnitDefs[unitDefID].transportCapacity>0 then
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
		elseif modeltype=="s3o" then
			if UnitDefs[unitDefID].canFly then
				local rs, hs, ws = 1.15, 0.33, 1.15	-- dont know why 3do uses: 0.53, 0.17, 0.53
				local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetUnitCollisionData(unitID)
				if (vtype>=3 and xs==ys and ys==zs) then
					if ( ys*hs ) < 13 then -- Limit Max V height
						spSetUnitCollisionData(unitID, xs*ws, 13, zs*rs,  xo, yo, zo,  1, htype, 1)
					elseif (UnitDefs[unitDefID].canFly) then
						spSetUnitCollisionData(unitID, xs*ws, ys*hs, zs*rs,  xo, yo, zo,  1, htype, 1)
					else
						spSetUnitCollisionData(unitID, xs*ws, ys*hs, zs*rs,  xo, yo, zo,  vtype, htype, axis)
					end
				end
			end
		end
	end


	-- Same as for 3DO units, but for features
	function gadget:FeatureCreated(featureID, allyTeam)
		local modelpath = FeatureDefs[Spring.GetFeatureDefID(featureID)].modelpath
		if modelpath == nil then    -- engine < 104 compatibility
			modelpath = FeatureDefs[Spring.GetFeatureDefID(featureID)].model.path
		end
		local featureModel = modelpath:lower()
		if featureModel:find(".3do") then
			local rs, hs
			if (spGetFeatureRadius(featureID)>47) then
				rs, hs = 0.68, 0.60
			else
				rs, hs = 0.75, 0.67
			end
			local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetFeatureCollisionData(featureID)
			if (vtype>=3 and xs==ys and ys==zs) then
				spSetFeatureCollisionData(featureID, xs*rs, ys*hs, zs*rs,  xo, yo-ys*0.09, zo,  vtype, htype, axis)
			end
			spSetFeatureRadiusAndHeight(featureID, spGetFeatureRadius(featureID)*rs, spGetFeatureHeight(featureID)*hs)			
		end
	end


	-- Check if a unit is pop-up type (the list must be entered manually)
	-- If a building was constructed add it to the list for later radius and height scaling
	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		local un = UnitDefs[unitDefID].name
		if unitCollisionVolume[un] then
			popupUnits[unitID]={name=un, state=-1, perPiece=false}
		elseif dynamicPieceCollisionVolume[un] then
			popupUnits[unitID]={name=un, state=-1, perPiece=true, numPieces = #spGetPieceList(unitID)-1}
		end
	end


	--check if a pop-up type unit was destroyed
	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		if popupUnits[unitID] then
			popupUnits[unitID] = nil
		end
	end

	
	--Dynamic adjustment of pop-up style of units' collision volumes based on unit's ARMORED status, runs twice per second
	--rescaling of radius and height of 3DO buildings
	function gadget:GameFrame(n)
		if (n%15 ~= 0) then
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
