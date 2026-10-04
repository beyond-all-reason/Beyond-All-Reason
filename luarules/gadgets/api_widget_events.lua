if gadgetHandler:IsSyncedCode() then return end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Widget Events",
		desc      = "Tells widgets about events they can know about",
		author    = "Sprung, Klon, Beherith",
		date      = "2015-05-27",
		license   = "PD",
		layer     = 0,
		enabled   = true,
	}
end

local spAreTeamsAllied     	= Spring.AreTeamsAllied
local spGetMyAllyTeamID    	= Spring.GetMyAllyTeamID
local spGetSpectatingState 	= Spring.GetSpectatingState
local spGetUnitLosState    	= Spring.GetUnitLosState

local myAllyTeamID, myTeamID, spec, specFullView

function gadget:Initialize()
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	spec, specFullView = spGetSpectatingState()
end

function gadget:PlayerChanged()
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	spec, specFullView = spGetSpectatingState()
end


--[[ NB: these are proxies, not the actual lua functions currently linked LuaUI-side,
     so it is safe to cache them here even if the underlying func changes afterwards ]]
local scriptUnitDestroyed		= Script.LuaUI.UnitDestroyed
local scriptUnitDestroyedByTeam	= Script.LuaUI.UnitDestroyedByTeam

function gadget:UnitDestroyed (unitID, unitDefID, unitTeam, attUnitID, attUnitDefID, attTeamID)
	local isAllyUnit = spAreTeamsAllied(unitTeam, myTeamID)
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

local scriptUnitTaken		= Script.LuaUI.UnitTaken
function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	-- we need to notify my team if a unit transfer between two other teams happens, within my radar or los
	local unitwasandisenemy = not (spAreTeamsAllied(oldTeamID, myTeamID) or spAreTeamsAllied(newTeamID, myTeamID))
	local unitinmyradarorlos = (spGetUnitLosState(unitID, myAllyTeamID, true) % 4 > 0)
	-- Spring.Echo("gadget:UnitGiven",unitID, unitDefID, oldTeamID, newTeamID, unitwasandisenemy, unitinmyradarorlos)
	if unitwasandisenemy and unitinmyradarorlos then
		scriptUnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	end
end

local scriptUnitGiven		= Script.LuaUI.UnitGiven
function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	-- we need to notify my team if a unit transfer between two other teams happens, within my radar or los
	local unitwasandisenemy = not (spAreTeamsAllied(oldTeamID, myTeamID) or spAreTeamsAllied(newTeamID, myTeamID))
	local unitinmyradarorlos = (spGetUnitLosState(unitID, myAllyTeamID, true) % 4 > 0)
	-- Spring.Echo("gadget:UnitGiven",unitID, unitDefID, newTeamID, oldTeamID, unitwasandisenemy, unitinmyradarorlos)
	if unitwasandisenemy and unitinmyradarorlos then
		scriptUnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
	end
end

local scriptUnitFinished		= Script.LuaUI.UnitFinished
function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if spec and specFullView then return end
	-- Important: Enemy units finished within LOS do not get the respective widget:UnitFinished calls!
	-- Also important: units that are created and finished in the same gameframe (like /give, or created fully built) are not in los yet, so this wont trigger!
	local unitisenemy = not spAreTeamsAllied(unitTeam, myTeamID)
	local isinlos = spGetUnitLosState(unitID, myAllyTeamID, true) % 2
	--Spring.Echo("gadget:UnitFinished",unitID, unitDefID, unitTeam, unitisenemy, isinlos)
	if unitisenemy and (isinlos == 1) then
		scriptUnitFinished(unitID, unitDefID, unitTeam)
	end
end

local scriptFeatureCreated = Script.LuaUI.FeatureCreated
function gadget:FeatureCreated(featureID, allyTeam) -- assume that features are always in LOS
	local isAllyUnit = (allyTeam == myAllyTeamID)
	--Spring.Echo("Gadget:FeatureCreated", featureID, FeatureDefs[Spring.GetFeatureDefID(featureID)].name, Script.LuaUI('FeatureCreated') , "isAllyUnit", isAllyUnit, "spec", spec, "specFullView", specFullView)
	-- we need to check if any widget uses the callin, otherwise it is not bound and will produce error spam
	if not isAllyUnit and (not (spec and specFullView)) and Script.LuaUI('FeatureCreated') then
		--Spring.Echo("gadget:FeatureCreated",featureID, allyTeam)
		scriptFeatureCreated(featureID, allyTeam)
	end
end

local scriptFeatureDestroyed = Script.LuaUI.FeatureDestroyed
function gadget:FeatureDestroyed(featureID, allyTeam)
	-- assume that features are always in LOS
	-- feauture allyTeam is equal to my allyteam when its a gaia feature, that is wierd
	-- am i always allied with gaia?
	local isAllyUnit = (allyTeam == myAllyTeamID)
	--Spring.Echo("Gadget:FeatureDestroyed", featureID, FeatureDefs[Spring.GetFeatureDefID(featureID)].name, Script.LuaUI('FeatureDestroyed') , "isAllyUnit", isAllyUnit, "spec", spec, "specFullView", specFullView, allyTeam, Spring.GetMyTeamID())
	-- we need to check if any widget uses the callin, otherwise it is not bound and will produce error spam
	if not isAllyUnit and (not (spec and specFullView)) and Script.LuaUI('FeatureDestroyed')  then
		--Spring.Echo("gadget:FeatureDestroyed",featureID, allyTeam)
		scriptFeatureDestroyed(featureID, allyTeam)
	end
end
