function gadget:GetInfo()
  return {
    name      = "Dynamic collision volume & Hitsphere Scaledown",
    desc      = "Adjusts collision volume for pop-up style units & Reduces the diameter of default sphere collision volume for 3DO models",
    author    = "Deadnight Warrior",
    date      = "Jul 12, 2011",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


local popupUnits = {}		--list of pop-up style units
local unitCollisionVolume, pieceCollisionVolume = include("LuaRules/Configs/CollisionVolumes.lua")	--pop-up style unit and per piece collision volume definitions

local spGetPieceCollisionData = Spring.GetUnitPieceCollisionVolumeData
local spSetPieceCollisionData = Spring.SetUnitPieceCollisionVolumeData
local spGetUnitCollisionData = Spring.GetUnitCollisionVolumeData
local spSetUnitCollisionData = Spring.SetUnitCollisionVolumeData
local spArmor = Spring.GetUnitArmored
local pairs = pairs	
	
if (gadgetHandler:IsSyncedCode()) then

	--Reduces the diameter of default (unspecified) collision volume for 3DO models,
	--for S3O models it's not needed and will in fact result in wrong collision volume
	--also handles per piece collision volume definitions, can't be dynamic ATM (and usually doesn't need to be)
	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if (pieceCollisionVolume[UnitDefs[unitDefID].name]) then
			for pieceIndex, p in pairs(pieceCollisionVolume[UnitDefs[unitDefID].name]) do
				if (p[1]==true) then
					spSetPieceCollisionData(unitID, pieceIndex, p[1], p[1],p[1],p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9])
				else
					spSetPieceCollisionData(unitID, pieceIndex, false, false,false,false, 1, 1, 1, 0, 0, 0, 1, 1)
				end
			end
		else
			if UnitDefs[unitDefID].model.type=="3do" then
				local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = spGetUnitCollisionData(unitID)
				if (vtype==4 and xs==ys and ys==zs) then
					if (xs>47 and not UnitDefs[unitDefID].canFly) then
						spSetUnitCollisionData(unitID, xs*0.68, ys*0.68, zs*0.68,  xo, yo, zo,  vtype, htype, axis)
					elseif (not UnitDefs[unitDefID].canFly) then
						spSetUnitCollisionData(unitID, xs*0.75, ys*0.75, zs*0.75,  xo, yo, zo,  vtype, htype, axis)
					else
						spSetUnitCollisionData(unitID, xs*0.375, ys*0.36, zs*0.44,  xo, yo, zo,  vtype, htype, axis)
					end
				end
			end
		end
	end


	--[[ unsupported by engine ATM, same as for 3DO units, but for features
	function gadget:FeatureCreated(featureID, allyTeam)
		local xs, ys, zs, xo, yo, zo, vtype, htype, axis, _ = Spring.GetFeatureCollisionVolumeData(featureID)
		if (vtype==4 and xs==ys and ys==zs) then
			Spring.SetFeatureCollisionVolumeData(unitID, xs*0.75, ys*0.75, zs*0.75,  xo, yo, zo,  vtype, htype, axis)

		end
	end
	]]--


	--check if a unit is pop-up type (the list must be entered manually)
	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		local un = UnitDefs[unitDefID].name
		if unitCollisionVolume[un] then
			popupUnits[unitID]={name=un, state=-1}
		end
	end


	--check if a pop-up type unit was destroyed
	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		if popupUnits[unitID] then
			popupUnits[unitID] = nil
		end
	end

	
	--Dynamic adjustment of pop-up style of units' collision volumes based on
	--unit's ARMORED status, runs twice per second
	function gadget:GameFrame(n)
		if (n%15 ~= 0) then
			return
		end
		local p
		for unitID,defs in pairs(popupUnits) do
			if spArmor(unitID) then
				if (defs.state ~= 0) then
					p = unitCollisionVolume[defs.name].off
					spSetUnitCollisionData(unitID, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9])
					popupUnits[unitID].state = 0
				end
			else
				if (defs.state ~= 1) then
					p = unitCollisionVolume[defs.name].on
					spSetUnitCollisionData(unitID, p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9])
					popupUnits[unitID].state = 1
				end
				--[[ if units don't use ARMORED variable, uncomment this block to make it use ACTIVATION as well
				if ( Spring.GetUnitIsActive(unitID) ) then
					p = unitCollisionVolume[name].on
				else
					p = unitCollisionVolume[name].off
				end
				]]--
			end			
		end
	end
end