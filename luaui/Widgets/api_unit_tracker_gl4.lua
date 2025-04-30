local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "API Unit Tracker DEVMODE GL4",
      desc      = "Manages alliedunitslist, visibleunitslist",
      author    = "Beherith",
      date      = "2022.02.18",
      license   = "GNU GPL, v2 or later",
      layer     = -828888,
	  handler   = true,
      enabled   = true,
      depends   = {'gl4'}
   }
end

local debuglevel = 0
-- debuglevel 0 is no debugging
-- debuglevel 1 is show warnings for stuff periodicly and make self crash
-- debuglevel 2 is verbose
-- debuglevel 3 is super verbose mode

local debugdrawvisible = false
local L_DEPRECATED = LOG.DEPRECATED
-- This widget's job is to provide a common interface for GL4 drawing widgets, that rely on having visible units present
-- Widget draw classes:
-- widgets that draw stuff for all visible units (trivial case)
-- widgets that only draw for allies, turn into widgets that draw for all once you enter specfullview
	-- which is pretty much just sensor ranges los
	-- rank icons
	-- flank icons

-- TODO:
-- filter decoration unitDefIDs, but not gaia (neutrals) -- done
-- do taken/given correctly by add-remove  -- done
-- the callins should all pass unitID, unitDefID, and unitTeam (note the issues with taken unitteams!)
-- remove crashing aircraft - not actually needed methinks, since no bugs came up
-- BIG ASS TODO: dont reinit when in spec mode!
-- -- WE DONT HAVE WIDGETS THAT REMAIN PLAYER ONLY!!!!!!!!!!
-- todo: make debug mode an int (verbosity) -- done
-- todo: make addunit not call callins on reinit -- done
-- todo: make a callout or a WG table entry -- yes we need a wg entry
-- todo: finalize alliedunit/visibleunit differences -- done
-- todo: also pass unitteam, as it must be present! - done
-- todo: fix drawdebugvisible to be changeable - done
-- todo: test this in singleplayer scenarios, and loaded games!

-- SUPER IMPORTANT: NEVER EVER ADD UNITS TO A VBO TABLE THAT ARE IN unitDefIgnore!
-- As the unit tracker api wont track them as actual units, and wont ever remove them either!


local alliedUnits = {} -- table of unitID : unitDefID
local alliedUnitsTeam = {} -- table of unitID : unitTeam
local numAlliedUnits = 0

local visibleUnits = {} -- table of unitID : unitDefID
local visibleUnitsTeam = {} -- table of unitID : unitTeam
local numVisibleUnits = 0

local unitDefIgnore = {}

local factoryUnitDefIDs = {} -- key unitdefid, internalname

local lastknownunitpos = {} -- table on unitID to {x,y,z}

local gameFrame = Spring.GetGameFrame()

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams and unitDef.customParams.nohealthbars then
		--unitDefIgnore[unitDefID] = true
	end --ignore debug units
	if unitDef.isFactory then
		factoryUnitDefIDs[unitDefID] = unitDef.name
	end

end

--- GL4 STUFF ---
local unitTrackerVBO = nil
local unitTrackerShader = nil
local luaShaderDir = "LuaUI/Include/"
local texture = "luaui/images/solid.png"

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.TRANSPARENCY = 0.5
	shaderConfig.ANIMATION = 0
	shaderConfig.HEIGHTOFFSET = 3.99
  -- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	unitTrackerVBO, unitTrackerShader = InitDrawPrimitiveAtUnit(shaderConfig, "unitTracker")
end

-- speedups
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitLosState = Spring.GetUnitLosState
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitHealth = Spring.GetUnitHealth

-- scriptproxies:
--[[ NB: these are proxies, not the actual lua functions currently linked LuaUI-side,
     so it is safe to cache them here even if the underlying func changes afterwards ]]
local scriptLuauiVisibleUnitAdded
local scriptLuauiVisibleUnitRemoved
local scriptLuauiVisibleUnitsChanged

local scriptLuauiAlliedUnitAdded
local scriptLuauiAlliedUnitRemoved
local scriptLuauiAlliedUnitsChanged

local function Scream(reason, unitID) -- This will pause the game and play some sound to alert anyone in debug mode of issue
	--Spring.Debug.TraceFullEcho(nil,nil,nil, reason)
	Spring.Debug.TraceEcho('API Unit Tracker error', reason)
	if unitID ~= nil then
		-- gather as much info as possible about this unitID
		local unitDefID = spGetUnitDefID(unitID)
		local unitTeam = spGetUnitTeam(unitID)
		local ux,uy,uz = spGetUnitPosition(unitID)
		Spring.Echo('API Unit Tracker error unitID', unitID, unitDefID and (UnitDefs[unitDefID].name) or "nil", unitTeam, px, pz)
	end
	if lastknownunitpos[unitID] then
		Spring.MarkerAddPoint(lastknownunitpos[unitID][1], lastknownunitpos[unitID][2], lastknownunitpos[unitID][3], lastknownunitpos[unitID][4], true)
	end
	Spring.Debug.TraceFullEcho()
	local unittrackerapinil = nil
	unittrackerapinil = unittrackerapinil + 1 -- this intentionally crashes this widget so that it will show up in analytics
	if debuglevel >=3 then
		Spring.SendCommands({"pause 1"})
		Spring.PlaySoundFile("commanderspawn", 1.0, 'ui')
	end
end

local function alliedUnitsChanged()
	if debuglevel >= 2 then Spring.Debug.TraceEcho() end
	if Script.LuaUI('AlliedUnitsChanged') then
		Script.LuaUI.AlliedUnitsChanged(visibleUnits, numVisibleUnits)
	else
		if debuglevel > 0 then Spring.Echo("Script.LuaUI.AlliedUnitsChanged() unavailable") end
	end
end

local function alliedUnitsAdd(unitID, unitDefID, unitTeam, silent)
	if debuglevel >= 3 then Spring.Debug.TraceEcho(numAlliedUnits) end
	if alliedUnits[unitID] then
		if debuglevel >= 2 then Spring.Echo("alliedUnitsAdd", "tried to add existing unitID", unitID) end
		return
	end -- already known
	alliedUnits[unitID] = unitDefID
	alliedUnitsTeam[unitID] = unitTeam
	numAlliedUnits = numAlliedUnits + 1
	if silent then return end
	if Script.LuaUI('AlliedUnitAdded') then
		Script.LuaUI.AlliedUnitAdded(unitID, unitDefID, unitTeam)
	else
		if debuglevel >= 1 then Spring.Echo("Script.LuaUI.AlliedUnitAdded() unavailable") end
	end
	-- call all listeners
end

local function alliedUnitsRemove(unitID, reason)
	if debuglevel >= 3 then Spring.Debug.TraceEcho(numAlliedUnits) end
	if alliedUnits[unitID] then
		local unitDefID = alliedUnits[unitID]
		alliedUnits[unitID] = nil
		local unitTeam = alliedUnitsTeam[unitID]
		alliedUnitsTeam[unitID] = nil
		numAlliedUnits = numAlliedUnits - 1
		-- call all listeners
		if Script.LuaUI('AlliedUnitRemoved') then
			Script.LuaUI.AlliedUnitRemoved(unitID, unitDefID, unitTeam)
		end
	else
		if debuglevel >= 2 then Spring.Echo("alliedUnitsRemove", "tried to remove non-existing unitID", unitID, reason) end
	end
end

local function GetAlliedUnits()
	if debuglevel >= 2 then Spring.Debug.TraceEcho() end
	return alliedUnits, numAlliedUnits
end

local function visibleUnitsChanged()
	if debuglevel >=3 then Spring.Debug.TraceEcho() end
	if Script.LuaUI('VisibleUnitsChanged') then
		Script.LuaUI.VisibleUnitsChanged(visibleUnits, numVisibleUnits)
	else
		if debuglevel > 0 then Spring.Echo("Script.LuaUI.VisibleUnitsChanged() unavailable") end
	end
end

local instanceVBOCacheTable = {
				96, 32, 8, 8,  -- lengthwidthcornerheight
				0, -- teamID
				2, -- how many trianges should we make (2 = cornerrect)
				0, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
				0, 1, 0, 1, -- These are our default UV atlas tranformations
				0, 0, 0, 0 -- these are just padding zeros, that will get filled in
			}

local function visibleUnitsAdd(unitID, unitDefID, unitTeam, silent)
	if debuglevel >= 3 then Spring.Debug.TraceEcho(numVisibleUnits) end
	if visibleUnits[unitID] then  -- already known
		if debuglevel >= 2 then Spring.Echo("visibleUnitsAdd", "tried to add existing unitID", unitID) end
		return
	end
	visibleUnits[unitID] = unitDefID
	visibleUnitsTeam[unitID] = unitTeam
	numVisibleUnits = numVisibleUnits + 1
	if debugdrawvisible then
		unitTeam = unitTeam or spGetUnitTeam(unitID) or 0
		instanceVBOCacheTable[5] = unitTeam
		instanceVBOCacheTable[7] = gameFrame

		pushElementInstance(
			unitTrackerVBO, -- push into this Instance VBO Table
			instanceVBOCacheTable,
			unitID, -- this is the key inside the VBO TAble,
			true, -- update existing element
			nil, -- noupload, dont use unless you know what you are doing
			unitID -- last one should be UNITID?
		)
	end
	-- call all listeners:
	if silent then return end
	if Script.LuaUI('VisibleUnitAdded') then
		Script.LuaUI.VisibleUnitAdded(unitID, unitDefID, unitTeam)
	else
		if debuglevel >= 1 then Spring.Echo("Script.LuaUI.VisibleUnitAdded() unavailable") end
	end
end

local function visibleUnitsRemove(unitID, reason)
	if debuglevel >= 3 then
		Spring.Debug.TraceEcho(numVisibleUnits)
		if lastknownunitpos[unitID] then lastknownunitpos[unitID] = nil end
	end
	if visibleUnits[unitID] then
		local unitDefID = visibleUnits[unitID]
		visibleUnits[unitID] = nil
		local unitTeam = visibleUnitsTeam[unitID]
		visibleUnitsTeam[unitID] = nil
		numVisibleUnits = numVisibleUnits - 1

		if debugdrawvisible then
			popElementInstance(unitTrackerVBO, unitID)
		end
		-- call all listeners
		if Script.LuaUI('VisibleUnitRemoved') then
			Script.LuaUI.VisibleUnitRemoved(unitID, unitDefID, unitTeam)
		end
	else
		if debuglevel >= 2 then Spring.Echo("visibleUnitsRemove", "tried to remove non-existing unitID", unitID, reason) end
	end
end

local function GetVisibleUnits()
	if debuglevel >= 2 then Spring.Debug.TraceEcho() end
	return visibleUnits, numVisibleUnits
end

local spec, fullview = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local function isValidLivingSeenUnit(unitID, unitDefID, verbose)
	--[[
	-- This isnt helping
	if type(myAllyTeamID) ~= "number" or (type(myAllyTeamID) == "number" and ((myAllyTeamID < 0 ) or (myAllyTeamID > 32))) then
		local localMyAllyTeamID = myAllyTeamID
		Spring.Debug.TraceFullEcho(nil,nil,nil, "api_unit_tracker_gl4 error on myAllyTeamID")
	end
	]]--

	-- strange, ALL of these will be evaluated, which explains the crash, because according to the evaluation order,
	-- unitDef is not nil yet
	-- unitID is valid
	-- unit
	-- SPECTATING SYNTHETIC in that replay from start and /skip 1 DOES THIS SHIT! 20220307_201548_DSDR 4_105.1.1-861-ge8bf8a9 BAR105.sdfz
	-- Which is odd, because that commander belongs to petTurtle, who is on the other allyteam anyway, so this shouldnt really ever get called
	-- now why that allyteamID is invalid, I dont really know yet, as the allyteamID == 1, which seems sane

	if unitDefID == nil then return false end
	if spValidUnitID(unitID) ~= true then return false end
	if spGetUnitIsDead(unitID) == true then return false end
	if unitDefIgnore[unitDefID] then return false end
	if ((not fullview) and (spGetUnitLosState(unitID, myAllyTeamID, true) % 2 == 0)) then return false end

	if debuglevel >= (verbose or 0) then
		if unitDefID == nil or
			spValidUnitID(unitID) ~= true or
			spGetUnitIsDead(unitID) == true or
			((not fullview) and (spGetUnitLosState(unitID, myAllyTeamID, true) % 2 == 0)) or -- outside of LOS
			unitDefIgnore[unitDefID] then
			if debuglevel >= (verbose or 0) then
				Spring.Debug.TraceEcho()
				Spring.Echo("not isValidLivingSeenUnit",
				'unitDefID', unitDefID,
				'ValidUnitID', spValidUnitID(unitID),
				'GetUnitIsDead', spGetUnitIsDead(unitID),
				'Ignore', unitDefIgnore[unitDefID],
				'LOSstate', spGetUnitLosState(unitID, myAllyTeamID, true)
				)
			end
			return false
		end
	end

	return true
end


function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID, reason, silent) -- this was visible at the time

	--[[
	local currentspec, currentfullview = Spring.GetSpectatingState()
	local currentAllyTeamID = Spring.GetMyAllyTeamID()
	local currentTeamID = Spring.GetMyTeamID()
	local currentPlayerID = Spring.GetMyPlayerID()
	if true or debuglevel >= 2 then
		Spring.Echo("UnitCreated PlayerChanged",
					"spec", spec, "->",currentspec,
					" fullview:", fullview , "->", currentfullview,
					" team:", myTeamID , "->", currentTeamID,
					" allyteam:", myAllyTeamID , "->", currentAllyTeamID,
					" player:", myPlayerID , "->", currentPlayerID
					)
	end

	if gameFrame <= 1000 then
		Spring.Echo("UnitCreated Pre-gameFrame", unitID, unitDefID, unitTeam, builderID, reason, silent, gameFrame)
		Spring.Echo(UnitDefs[unitDefID].name)
		local px, py, pz = Spring.GetUnitPosition(unitID)
		Spring.Echo('pos',px, py, pz)
		Spring.Echo("Mystate", spec, fullview, myAllyTeamID, myTeamID, myPlayerID )
	end
	]]--

	if gameFrame <= 0 and not fullview then
		local currentAllyTeamID = Spring.GetMyAllyTeamID()
		if myAllyTeamID ~= currentAllyTeamID then
			widget:PlayerChanged()
		end
	end

	unitDefID = unitDefID or spGetUnitDefID(unitID)
	if debuglevel >= 3 then Spring.Echo("UnitCreated", unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, reason) end

	if isValidLivingSeenUnit(unitID, unitDefID, 3) == false then return end

	-- Units that are cheated or spawned will fire unitcreated, then unitfinished right after each other
	-- In this case, their health is already maxhealth, and their buildprogress is 0.
	-- So, to prevent zero build progress from further turning into problematic things
	-- we will suppress the createunit for any unit that is spawned at full health, and only fire its unitfinished version.
	-- So we are relying on UnitFinished to be called right after this one
	-- Sensibly enough, this is not a problem for players, as they see the units only after their LOS status is checked, later in the same gameframe.
	-- So spectators, and 'own team' suffers this hit only
	local health,maxhealth, paralyzeDamage,captureProgress,buildProgress = spGetUnitHealth(unitID)
	if health == maxhealth and buildProgress == 0 then
		if debuglevel >= 3 then
			Spring.Echo("Skipping visibleUnitsAdd for CreateUnit'ed unit", UnitDefs[unitDefID].name, unitID, unitDefID, unitTeam, builderID, reason, silent)
		end
		return
	end

	-- alliedunits
	if spAreTeamsAllied(unitTeam, myTeamID) then
		alliedUnitsAdd(unitID, unitDefID, unitTeam, silent)
	end

	-- visibleUnits
	if visibleUnits[unitID] == nil then
		visibleUnitsAdd(unitID, unitDefID, unitTeam, silent)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID, reason)
	if debuglevel >= 3 then
		unitDefID = unitDefID or spGetUnitDefID(unitID)
		Spring.Echo("UnitDestroyed",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, nil, nil, nil, nil, reason)
	end
	visibleUnitsRemove(unitID, reason or "destroyed")
	alliedUnitsRemove(unitID, reason or "destroyed")
end

--function widget:CrashingAircraft(unitID, unitDefID, teamID)
	--Spring.Echo("Global:GadgetCrashingAircraft",unitID, unitDefID, teamID)
--end


--function widget:UnitDestroyedByTeam(unitID, unitDefID, unitTeam)
	--alliedUnitsRemove(unitID)
	--visibleUnitsRemove(unitID)
--end

function widget:UnitFinished(unitID, unitDefID, unitTeam) -- todo, this should probably add-remove a unit
	widget:UnitDestroyed(unitID, unitDefID, unitTeam, nil, nil, nil, nil, "UnitFinished")
	widget:UnitCreated(unitID, unitDefID, unitTeam, nil, "UnitFinished")
	if unitTeam == myTeamID and factoryUnitDefIDs[unitDefID] then
		widgetHandler:AddSpadsMessage("UnitFinished:"..tostring(factoryUnitDefIDs[unitDefID]))
	end
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam) --1.  this is only called when one if my units gets captured
	widget:UnitDestroyed(unitID, unitDefID, oldTeam, nil, nil, nil, nil, "UnitTaken")
	-- not needed, as the unit will call enemyenteredlos, but what if we are spec?
	if not fullview then
		-- todo, look at this real closely if its even needed!
		--widget:UnitCreated(unitID, unitDefID, newTeam, nil, "UnitTaken")
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam) --2.  this is only called when my team captures a unit
	widget:UnitDestroyed(unitID, unitDefID, oldTeam, nil, nil, nil, nil, "UnitGiven") -- to ensure that team changes will trigger from this!
	widget:UnitCreated(unitID, unitDefID, newTeam, nil, "UnitGiven")
end

-- one of the most difficult test cases here, when the transfer of a unit happens between two other teams (1 and 2, we are 0)
-- only the unitenteredlos part gets called for us!
-- this is quite a severe problem, as we can see that only the unitenteredlos/radar gets recalled!
-- solution: in the api_widget_events gadget, we need to forward this too!

--[[
[t=00:04:53.877051][f=0004348] g:UnitTaken, 24007, armacv, 2, 1
[t=00:04:53.877107][f=0004348] g:UnitEnteredLos, 24007, 1
[t=00:04:53.877163][f=0004348] w:UnitEnteredLos, 24007, 1
[t=00:04:53.877198][f=0004348] g:UnitEnteredRadar, 24007, 1
[t=00:04:53.877213][f=0004348] w:UnitEnteredRadar, 24007, 1
[t=00:04:53.877228][f=0004348] g:UnitEnteredLos, 24007, 1
[t=00:04:53.877240][f=0004348] g:UnitEnteredRadar, 24007, 1
[t=00:04:53.877277][f=0004348] g:UnitGiven, 24007, armacv, 1, 2
[t=00:04:53.877451][f=0004348] g:UnitIdle, 24007, armacv, 1
[t=00:04:53.909507][f=0004349] g:UnitLeftLos, 14177, 1
[t=00:04:53.909535][f=0004349] g:UnitLeftRadar, 14177, 1
[t=00:04:53.909549][f=0004349] g:UnitLeftLos, 24007, 1
[t=00:04:53.909562][f=0004349] g:UnitLeftRadar, 24007, 1
[t=00:04:54.109905][f=0004355] g:UnitCmdDone, 14177, corcom, 1, 130, <table>, <table>, 16
[t=00:04:54.109951][f=0004355] g:UnitIdle, 14177, corcom, 1
]]--


function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if not fullview then
		widget:UnitCreated(unitID, unitDefID, unitTeam, nil, "UnitEnteredLos")
	end
end

function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if not fullview then
		widget:UnitDestroyed(unitID, unitDefID, unitTeam, nil, nil, nil, nil, "UnitLeftLos")
	end
end

function widget:GameFrame()
	--Spring.Echo("GameFrame", gameFrame, "->", Spring.GetGameFrame())
	gameFrame = Spring.GetGameFrame()
	if debuglevel >= 1 then -- here we will scan all units and ensure that they match what we expect
		if (debuglevel <= 2) and (math.random() > 0.05 ) then return end  -- lower frequency at smaller debug levels
		local allunits = Spring.GetAllUnits()
		local allunitsTable = {}
		for i = 1, #allunits do
			local unitID = allunits[i]
			if isValidLivingSeenUnit(unitID, spGetUnitDefID(unitID), 3) then
				allunitsTable[unitID] = true
			end
		end

		local cntvisibleunits = 0
		for unitID, unitDefID in pairs(visibleUnits) do
			if allunitsTable[unitID] == nil then
				Scream("A unitID from visibleUnits is not in allunitstable: " .. tostring(unitID))
			end

			if isValidLivingSeenUnit(unitID, unitDefID, 3) then
				cntvisibleunits = cntvisibleunits + 1
				local ux, uy, uz = spGetUnitPosition(unitID)
				local unitDefName = UnitDefs[spGetUnitDefID(unitID)].name
				if lastknownunitpos[unitID] then
					lastknownunitpos[unitID][1] = ux
					lastknownunitpos[unitID][2] = uy
					lastknownunitpos[unitID][3] = uz
					lastknownunitpos[unitID][4] = unitDefName
				else
					lastknownunitpos[unitID] = {ux,uy,uz, unitDefName}
				end
			else
				isValidLivingSeenUnit(unitID, unitDefID, 1)
				Scream("Unit in visibleUnits does not exist", unitID)
			end
		end
		if cntvisibleunits ~= numVisibleUnits then
			Scream("cntvisibleunits ~= numVisibleUnits " .. tostring(cntvisibleunits) .. " vs " .. tostring(numVisibleUnits))
		end

		if drawdebugvisible then
			locateInvalidUnits(unitTrackerVBO)
		end

		local cntalliedunits = 0
		for unitID, unitDefID in pairs(alliedUnits) do
			if allunitsTable[unitID] == nil then
				Scream("A unitID from alliedUnits is not in allunitstable: " .. tostring(unitID))
			end

			if isValidLivingSeenUnit(unitID, unitDefID, 3) then
				cntalliedunits = cntalliedunits + 1
			else
				isValidLivingSeenUnit(unitID, unitDefID, 1)
				Scream("Unit in alliedunits does not exist", unitID)
			end
		end
		if cntalliedunits ~= numAlliedUnits then
			Scream("cntalliedunits ~= numAlliedUnits " .. tostring(cntalliedunits) .. " vs " .. tostring(numAlliedUnits))
		end

		if debugdrawvisible then
			unitTrackerVBO.debug = true
		end
	end
end

function widget:DrawWorldPreUnit()
	if Spring.IsGUIHidden() then
		return
	end

	if debugdrawvisible then
		-- Spring.Echo("Drawing unitTracker", unitTrackerVBO.usedElements)
		if unitTrackerVBO.usedElements > 0 then
			gl.Texture(0, texture)
			unitTrackerShader:Activate()
			unitTrackerShader:SetUniform("iconDistance", 99999) -- pass
			unitTrackerShader:SetUniform("addRadius", 0)
			gl.DepthTest(true)
			gl.DepthMask(false)
			unitTrackerVBO.VAO:DrawArrays(GL.POINTS, unitTrackerVBO.usedElements)
			unitTrackerShader:Deactivate()
			gl.Texture(0, false)
		end
	end
end

local function initializeAllUnits()
	alliedUnits = {}
	alliedUnitsTeam = {}
	numAlliedUnits = 0

	visibleUnits = {}
	visibleUnitsTeam = {}
	numVisibleUnits = 0

	if debuglevel >= 2 then
				Spring.Echo("initializeAllUnits()",
					"spec", spec,
					" fullview:", fullview ,
					" team:", myTeamID ,
					" allyteam:", myAllyTeamID ,
					" player:", myPlayerID
					)
	end

	if debugdrawvisible then
		clearInstanceTable(unitTrackerVBO)
	end

	local allunits = Spring.GetAllUnits()
	for i, unitID in pairs (allunits) do
		widget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID), nil, "initializeAllUnits", true) -- silent is true
	end

	WG['unittrackerapi'].visibleUnits = visibleUnits
	WG['unittrackerapi'].visibleUnitsTeam = visibleUnitsTeam
	WG['unittrackerapi'].alliedUnits = alliedUnits
	WG['unittrackerapi'].alliedUnitsTeam = alliedUnitsTeam
	visibleUnitsChanged()
	alliedUnitsChanged()
end

function widget:TextCommand(command)
	if string.find(command, "debugapiunittracker", nil, true) == 1 then
		local startmatch, endmatch = string.find(command, "debugapiunittracker", nil, true)
		local param = string.sub(command, endmatch + 2,nil)
		if param and param == 'draw' then
			Spring.Echo("Debug mode for API Unit Tracker GL4 set to draw:", not debugdrawvisible)
			if debugdrawvisible then
				clearInstanceTable(unitTrackerVBO)
				debugdrawvisible = false
			else
				debugdrawvisible = true
				initGL4()
				initializeAllUnits()
			end
		end
		if param and tonumber(param) then
			local newdebuglevel = tonumber(param)
			if newdebuglevel ~= debuglevel then
				Spring.Echo("Debug level for API Unit Tracker GL4 set to:", newdebuglevel)
				debuglevel = newdebuglevel
			end
		end
	end

	if string.find(command, "execute", nil, true) == 1 then
		local cmd = string.sub(command, string.find(command, "execute", nil, true) + 8, nil)
		local success, functionize = pcall(loadstring( 'return function() return {' .. cmd .. '} end')) -- note, because of the return{} stuff, this cant execute any arbitrary for loop
		if not success then
			Spring.Echo("Failed to parse command:",success, cmd)
		else
			local success, data = pcall(functionize)
			if not success then
				Spring.Echo("Failed to execute command:", success, cmd)
			else
				if type(data) == type({}) then
					if #data == 1 then
						Spring.Echo(data[1])
					elseif #data == 0 then
						Spring.Echo("nil")
					else
						Spring.Echo(data)
					end
				else
					Spring.Echo(data)
				end
			end
		end
	end

	if string.find(command, "noreturnexecute", nil, true) == 1 then
		local cmd = string.sub(command, string.find(command, "noreturnexecute", nil, true) + 16, nil)
		local success, functionize = pcall(loadstring( 'return function() ' .. cmd .. ' end')) --
		if not success then
			Spring.Echo("Failed to parse command:",success, cmd)
		else
			local success, data = pcall(functionize)
			if not success then
				Spring.Echo("Failed to execute command:", success, cmd)
			else
				if type(data) == type({}) then
					if #data == 1 then
						Spring.Echo(data[1])
					elseif #data == 0 then
						Spring.Echo("nil")
					else
						Spring.Echo(data)
					end
				else
					Spring.Echo(data)
				end
			end
		end
	end
end

function widget:PlayerChanged(playerID)
	-- VERY IMPORTANT NOTE:
	-- When starting up a game, and spectating a player (e.g. /spec 2), or clicking on them in playerTV,
	-- My allyTeamID and myTeamID BOTH get RESET internally by the engine on game start!
	-- and this does NOT result in a playerchanged callin
	-- the fullview variable is not changed, however

	local currentspec, currentfullview = Spring.GetSpectatingState()
	local currentAllyTeamID = Spring.GetMyAllyTeamID()
	local currentTeamID = Spring.GetMyTeamID()
	local currentPlayerID = Spring.GetMyPlayerID()

	local reinit = false

	-- testing for visibleUnitsChanged and alliedUnitsChanged

	if debuglevel >= 2 then
		Spring.Echo("PlayerChanged",
					"spec", spec, "->",currentspec,
					" fullview:", fullview , "->", currentfullview,
					" team:", myTeamID , "->", currentTeamID,
					" allyteam:", myAllyTeamID , "->", currentAllyTeamID,
					" player:", myPlayerID , "->", currentPlayerID
					)
	end

	-- testing for visible units changed
	if (currentspec ~= spec) or -- we change from spec to non spec (I dont think its possible to go from player to non-fullview spec in one go)
		(currentfullview ~= fullview) or
		((currentAllyTeamID ~= myAllyTeamID) and not currentfullview) then -- our ALLYteam changes, and we are not in fullview
		reinit = true
	end

	-- which can happen if we are spec and only want to show for allies what the FUCK
	-- WHAT EFFECTS DO WE HAVE THAT ONLY SHOW FOR ALLIES IN sPEC MODE?

	spec = currentspec
	fullview = currentfullview
	myAllyTeamID = currentAllyTeamID
	myTeamID = currentTeamID
	myPlayerID = currentPlayerID

	if reinit then initializeAllUnits() end
end

function widget:GameStart()
	local function LobbyInfo()
		local test = false
		if not test then
			if Spring.IsReplay() then return end
			if Spring.Utilities.GetPlayerCount() < 2 then return end
			if Spring.Utilities.Gametype.IsSinglePlayer == true then return end
		end

		local pnl = {a = "a"}
		for ct, id in ipairs(Spring.GetPlayerList()) do
			local playername, _, spec = Spring.GetPlayerInfo(id, false)
			pnl[ct] = playername
			if (not test) and spec and (string.find(playername,"[teh]cluster", nil, true) or string.find(playername,"Host[", nil, true) )then
				return
			end
		end

		for j, script in ipairs({"script.txt", "_script.txt"}) do
			if VFS.FileExists(script) then
				for i, line in ipairs(string.lines(VFS.LoadFile(script))) do
					if string.find(string.lower(line),"hostip", nil, true) then pnl[script] = line end
				end
			end
		end

		local client=socket.tcp()
		local res, err = client:connect("server4.beyondallreason.info", 8200)
		if not res and err ~= "timeout" then
			--Spring.Echo("Failure",res,err)
		else
			local message = "c.telemetry.log_client_event lobby:info " .. string.base64Encode(Json.encode(pnl)).." ZGVhZGJlZWZkZWFkYmVlZmRlYWRiZWVmZGVhZGJlZWY=\n"
			client:send(message)
		end
		client:close()
	end
	--local succes, res = pcall(LobbyInfo)
end

function widget:Initialize()
	gameFrame = Spring.GetGameFrame()
	spec, fullview = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	myPlayerID = Spring.GetMyPlayerID()

	scriptLuauiVisibleUnitAdded = Script.LuaUI.VisibleUnitAdded
	scriptLuauiVisibleUnitRemoved = Script.LuaUI.VisibleUnitRemoved
	scriptLuauiVisibleUnitsChanged = Script.LuaUI.VisibleUnitChanged

	scriptLuauiAlliedUnitAdded = Script.LuaUI.AlliedUnitAdded
	scriptLuauiAlliedUnitRemoved = Script.LuaUI.AlliedUnitRemoved
	scriptLuauiAlliedUnitsChanged = Script.LuaUI.AlliedUnitChanged


	if debugdrawvisible then
		initGL4()
	end

	WG['unittrackerapi'] = {}
	WG['unittrackerapi'].visibleUnits = visibleUnits
	WG['unittrackerapi'].visibleUnitsTeam = visibleUnitsTeam
	WG['unittrackerapi'].alliedUnits = alliedUnits
	WG['unittrackerapi'].alliedUnitsTeam = alliedUnitsTeam
	initializeAllUnits()
	widgetHandler:RegisterGlobal('GadgetCrashingAircraft1', GadgetCrashingAircraft)
end


local iHaveDesynced = false
-- Example console line:
-- [t=00:01:41.862230][f=0011049] Sync error for UnnamedPlayer in frame 11044 (got 5537e3ca, correct is cc130165)
local syncerrorpattern = "Sync error for ([%w%[%]_]+) in frame (%d+) %(got (%x+), correct is (%x+)%)"

function widget:AddConsoleLine(lines, priority)
	if priority and priority == L_DEPRECATED then return end
	--Spring.Echo(lines)
	if iHaveDesynced then return end
    local username, frameNumber, gotChecksum, correctChecksum = lines:match(syncerrorpattern)
    if username and frameNumber and gotChecksum and correctChecksum  then
        local myPlayerName = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
        if myPlayerName == username then
            -- Yes, we have desynced, time to send a LuaUIMsg to notify the server
            -- desyncee, gameID, frame, gameversion, engine version, map, chobby version?
            local jsondict = {
                eventtype = "syncerror",
                username = username, -- desyncee
                lobbyName = tostring(Spring.GetMenuName and Spring.GetMenuName()), -- this returns rapid://byar-chobby:test, which is completely useless
                gameVersion = tostring(Game.gameVersion), -- this better not be the rapid tag
                engineVersion = tostring(Engine.versionFull), -- full complete engine version string
                mapName = tostring(Game.mapName), -- full map name
                gameID = tostring(Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")), -- gameID parameter, not the same as server_match_id, we will match that in teiserver
                frame = frameNumber, -- the frame where it happened.
                gotChecksum = gotChecksum,
                correctChecksum = correctChecksum,
            }
			--Spring.Echo(jsondict)

			local complex_match_event = string.format("complex-match-event:%s", string.base64Encode(Json.encode(jsondict)))

            -- We will be forwarding this as a complex event:
            -- sayPrivate  complex-match-event <Beherith> <desyncreport> <67> <eyJrZXkiOiJ2YWx1ZSJ9>
            -- !sendLobby SAYPRIVATE AutohostMonitor 'complex-match-event <[teh]Beherith> <desyncreport> <67> <eyJrZXkiOiJ2YWx1ZSJ9>'
            Spring.SendLuaUIMsg(complex_match_event)

			-- then remove ourselves, no point to keep running after the first desync is detected
			iHaveDesynced = true
        end
    end
end


function widget:Shutdown()
	-- ok this is quite sensitive, in order to prevent taking down the rest of the world with it
	-- we need to clear the visible units, and call the respective callins
	alliedUnits = {}
	alliedUnitsTeam = {}
	numAlliedUnits = 0
	visibleUnits = {}
	visibleUnitsTeam = {}
	numVisibleUnits = 0


	WG['unittrackerapi'].visibleUnits = visibleUnits
	WG['unittrackerapi'].visibleUnitsTeam = visibleUnitsTeam
	WG['unittrackerapi'].alliedUnits = alliedUnits
	WG['unittrackerapi'].alliedUnitsTeam = alliedUnitsTeam
	visibleUnitsChanged()
	alliedUnitsChanged()

	widgetHandler:DeregisterGlobal('GadgetCrashingAircraft1')
end
