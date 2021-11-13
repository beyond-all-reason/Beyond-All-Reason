if gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo() return {
	name      = "Widget Events",
	desc      = "Tells widgets about events they can know about",
	author    = "Sprung, Klon",
	date      = "2015-05-27",
	license   = "PD",
	layer     = 0,
	enabled   = true,
} end

local spAreTeamsAllied     	= Spring.AreTeamsAllied
local spGetMyAllyTeamID    	= Spring.GetMyAllyTeamID
local spGetMyTeamID        	= Spring.GetMyTeamID
local spGetSpectatingState 	= Spring.GetSpectatingState
local spGetUnitLosState    	= Spring.GetUnitLosState

local myAllyTeamID
local myTeamID

function gadget:Initialize()
  myTeamID = Spring.GetMyTeamID()
  myAllyTeamID = Spring.GetMyAllyTeamID()
end

function gadget:PlayerChanged()
  myTeamID = Spring.GetMyTeamID()
  myAllyTeamID = Spring.GetMyAllyTeamID()
end


--[[ NB: these are proxies, not the actual lua functions currently linked LuaUI-side,
     so it is safe to cache them here even if the underlying func changes afterwards ]]
local scriptUnitDestroyed		= Script.LuaUI.UnitDestroyed
local scriptUnitDestroyedByTeam	= Script.LuaUI.UnitDestroyedByTeam

function gadget:UnitDestroyed (unitID, unitDefID, unitTeam, attUnitID, attUnitDefID, attTeamID)
	myAllyTeamID = spGetMyAllyTeamID()
	local spec, specFullView = spGetSpectatingState()
	local isAllyUnit = spAreTeamsAllied(unitTeam, spGetMyTeamID())
	--Spring.Echo("Gadget:UnitDest", unitID, Script.LuaUI('UnitDestroyedByTeam') , "isAllyUnit", isAllyUnit, "spec", spec, "specFullView", specFullView)
	-- we need to check if any widget uses the callin, otherwise it is not bound and will produce error spam
	if Script.LuaUI('UnitDestroyedByTeam') then
		if spec then
			scriptUnitDestroyedByTeam (unitID, unitDefID, unitTeam, attTeamID)
			if not specFullView and not isAllyUnit and (spGetUnitLosState(unitID, myAllyTeamID, true) % 2 == 1) then
				scriptUnitDestroyed (unitID, unitDefID, unitTeam)
			end
		else
			local attackerInLos = attUnitID and (spGetUnitLosState(attUnitID, myAllyTeamID, true) % 2 == 1)
			if isAllyUnit then
				scriptUnitDestroyedByTeam (unitID, unitDefID, unitTeam, attackerInLos and attTeamID or nil)
			elseif spGetUnitLosState(unitID, myAllyTeamID, true) % 2 == 1 then
					scriptUnitDestroyed (unitID, unitDefID, unitTeam)
					scriptUnitDestroyedByTeam (unitID, unitDefID, unitTeam, attackerInLos and attTeamID or nil)
			end
		end
	else
		if not isAllyUnit and (not (spec and specFullView) and (spGetUnitLosState(unitID, spGetMyAllyTeamID(), true) % 2 == 1)) then
			scriptUnitDestroyed (unitID, unitDefID, unitTeam)
		end
	end
end

local scriptFeatureCreated = Script.LuaUI.FeatureCreated

function gadget:FeatureCreated(featureID, allyTeam) -- assume that features are always in LOS
  local myAllyTeamID = spGetMyAllyTeamID()
	local spec, specFullView = spGetSpectatingState()
	local isAllyUnit = spAreTeamsAllied(allyTeam, spGetMyTeamID())
	--Spring.Echo("Gadget:UnitDest", unitID, Script.LuaUI('UnitDestroyedByTeam') , "isAllyUnit", isAllyUnit, "spec", spec, "specFullView", specFullView)
	-- we need to check if any widget uses the callin, otherwise it is not bound and will produce error spam
  if not isAllyUnit and (not (spec and specFullView)) and Script.LuaUI('FeatureCreated') then
    --Spring.Echo("gadget:FeatureCreated",featureID, allyTeam)
    scriptFeatureCreated(featureID, allyTeam)
  end
end


local scriptFeatureDestroyed = Script.LuaUI.FeatureDestroyed

function gadget:FeatureDestroyed(featureID, allyTeam) -- assume that features are always in LOS
  local myAllyTeamID = spGetMyAllyTeamID()
	local spec, specFullView = spGetSpectatingState()
	local isAllyUnit = spAreTeamsAllied(allyTeam, spGetMyTeamID())
	--Spring.Echo("Gadget:UnitDest", unitID, Script.LuaUI('UnitDestroyedByTeam') , "isAllyUnit", isAllyUnit, "spec", spec, "specFullView", specFullView)
	-- we need to check if any widget uses the callin, otherwise it is not bound and will produce error spam
  if not isAllyUnit and (not (spec and specFullView)) and Script.LuaUI('FeatureDestroyed')  then
    --Spring.Echo("gadget:FeatureDestroyed",featureID, allyTeam)
    scriptFeatureDestroyed(featureID, allyTeam)
  end
end