local versionNumber = "1.3"

function widget:GetInfo()
	return {
		name      = "Unit Marker",
		desc      = "[v" .. string.format("%s", versionNumber ) .. "] Marks spotted units of interest.",
		author    = "very_bad_soldier",
		date      = "October 21, 2007",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = false
	}
end

--[[
Features:
-multiple mod support
-no multiple markers if multiple players use it

Changelog:
1.3: fixed: double markers for one unit 
1.2: added XTA support (thx to manolo_), deactivates older defense range widget (thx to TFC)
1.1: auto-disable when spec
1.0: initial release
--]]
local debug = false --generates debug message

local unitList = {}
--MARKER LIST ------------------------------------
unitList["BA"] = {} --initialize table
unitList["BA"]["armamd"] = { markerText = "Anti Nuke" }
unitList["BA"]["corfmd"] = { markerText = "Anti Nuke" }
unitList["BA"]["armsilo"] = { markerText = "Nuke" }
unitList["BA"]["corsilo"] = { markerText = "Nuke" }
--END OF MARKER LIST---------------------------------------

local markerTimePerId = 0.2 --400ms

local myPlayerID
local curModID
local updateInt = 1 --seconds for the ::update loop
local lastTimeUpdate = 0


local markersToSet = {} --this is a todo list filled with marker which have to be set, widget waits before setting them to see if another play tags them before to avoid multitagging
local knownUnits = {} --all units that have been marked already, so they wont get marked again

--local spGetLocalTeamID	 	= Spring.GetLocalTeamID
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spSendLuaUIMsg    	= Spring.SendLuaUIMsg
local spGetGameSeconds      = Spring.GetGameSeconds
local spMarkerAddPoint      = Spring.MarkerAddPoint
local spIsUnitAllied		= Spring.IsUnitAllied
local spGetMyPlayerID       = Spring.GetMyPlayerID
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spEcho                = Spring.Echo
local spGetPlayerList  		= Spring.GetPlayerList
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spArePlayersAllied	= Spring.ArePlayersAllied
local spGetLocalPlayerID 	= Spring.GetLocalPlayerID
local upper                 = string.upper
local floor                 = math.floor
local max					= math.max
local min					= math.min


function widget:Initialize()
	myPlayerID = spGetLocalPlayerID() --spGetMyPlayerID() --spGetLocalTeamID()
	printDebug("<Unit Marker> My Player ID: " .. myPlayerID )
		
	curModID = upper(Game.modShortName or "")
	
	if ( unitList[curModID] == nil ) then
		spEcho("<Unit Marker> Unsupported Game, shutting down...")
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:Update()
	local timef = spGetGameSeconds()
	local time = floor(timef)
	
	-- update timers once every <updateInt> seconds
	if (time % updateInt == 0 and time ~= lastTimeUpdate) then	
		lastTimeUpdate = time
		--do update stuff:
		
		if ( CheckSpecState() == false ) then
			return false
		end
	end
end

function widget:UnitEnteredLos(unitID, allyTeam)
	if ( spIsUnitAllied( unitID ) ) then
		return
	end

	local udefId = spGetUnitDefID(unitID)
	local udef = UnitDefs[udefId]
	local x, y, z = spGetUnitPosition(unitID)
	
	if (  unitList[curModID] ~= nil ) and (  unitList[curModID][udef.name] ~= nil ) and  ( unitList[curModID][udef.name]["markerText"] ~= nil ) then
		--the unit is in the list -> has to get marked
		if ( knownUnits[unitID] == nil ) or ( knownUnits[unitID] ~= udefId ) then
			--unit wasnt marked already or unit changed
			knownUnits[unitID] = udefId
			setMarkerForUnit( unitID, udef, { x,y,z }  )
		end
	end
end

function setMarkerForUnit( unitId, udef, pos )
	local markerText = unitList[curModID][udef.name]["markerText"]
	
	spSendLuaUIMsg("dfT" .. unitId, "allies")

	printDebug( "Storing to markerQueue. UnitId #" .. unitId )
	markersToSet[unitId] = { time = spGetGameSeconds(), pos = pos, text = markerText }
end

--returns highest ping from all players whos playerid < myPlayerId
function getHighestPing()
	local highPing = 0
	local playerTab = spGetPlayerList()
	for _, p in ipairs( playerTab ) do
		--printDebug( "player " .. p .. " myPlayerId: " .. myPlayerId )
		local _, _, _, _, _, ping, _ = spGetPlayerInfo(p)
		--printDebug( "Ping: "  .. ping )
		--printDebug( spArePlayersAllied( p, myPlayerID ) )
		--printDebug( "p: " .. p .. "    MyplayerId: " .. myPlayerID )
		--printDebug( "ping: " .. ping .. "    highPing: " .. highPing )
		if ( spArePlayersAllied( p, myPlayerID ) and ( p < myPlayerID ) and ( ping > highPing ) ) then
			--printDebug( "SAving ping")
			highPing = ping
		end
	end
	
	--cap to 5s
	highPing = min( highPing, 5.0 )
	printDebug( "HighPing:" .. highPing )
	
	return highPing
end

--this one receives lua msgs from allied players. the player with the lowest id sets the marker first
--the others discard their markers when receiving a message from a lower player id
function widget:RecvLuaMsg(msg, playerID)
	if (msg:sub(1,3)=="dfT") then
		local unitId = tonumber( msg:sub( 4 ) ) -- take from pos 4 to the end
		printDebug( "Df-Msg rcvd: Player " .. playerID .. " can tag unitId: " .. unitId )
  		
		if (playerID==myPlayerID) then 
			printDebug( "...from me")
			return true; 
		end

		if ( playerID < myPlayerID ) then
			--he is first, delete mine
			printDebug( "Player #" .. playerID .. " is first. Removing my marker #" .. unitId )
			markersToSet[unitId] = nil
		else
			printDebug( "Player #" .. playerID .. " is first. Removing my marker #" .. unitId )
		end
	
		--printDebugTable( markersToSet )
		return true; 
	end
end

function widget:DrawWorld()
	local now = spGetGameSeconds()
	local currentWaitTime = 2 * getHighestPing() --wait twice the worst ping time of all candidates (=players with lower id than myself)
	printDebug(currentWaitTime)
	for k, marker in pairs( markersToSet ) do
		--if ( now >= ( myPlayerID * markerTimePerId + marker["time"] ) ) then 
		printDebug( "Start " .. marker["time"] .. " Wait until " .. marker["time"] + currentWaitTime )
		if ( now >= marker["time"] + currentWaitTime ) then
			printDebug( "Setting marker " .. marker["text"] )
	
			spMarkerAddPoint( marker["pos"][1], marker["pos"][2], marker["pos"][3],  marker["text"] )
			markersToSet[k] = nil
		--else	printDebug("Key: " .. k .. " Waiting: " .. ( myPlayerID * markerTimePerId + marker["time"] ) - now .. "ms" )
		end
	end
end

function widget:GameStart()
  if widgetHandler.widgets ~= nil then
	  for i, widget in ipairs(widgetHandler.widgets) do
		if (widget:GetInfo().name == 'Defense Range') then
		  local version = tonumber(string.match(widget:GetInfo().desc,'%d+%.%d+'))
		  if version and (version < tonumber("6")) then
			spEcho("<Unit Marker> Old DefenseRange found! Widget removed.")
			widgetHandler:RemoveWidget()
		  end
		end
	  end
  end
end

function CheckSpecState()
	local _, _, spec, _, _, _, _, _ = spGetPlayerInfo(myPlayerID)
		
	if ( spec == true ) then
		spEcho("<Unit Marker> Spectator mode. Widget removed.")
		widgetHandler:RemoveWidget()
		return false
	end
	
	return true	
end


function printDebug( value )
	if ( debug ) then
		if ( type( value ) == "boolean" ) then
			if ( value == true ) then spEcho( "true" )
				else spEcho("false") end
		elseif ( type(value ) == "table" ) then
			spEcho("Dumping table:")
			for key,val in pairs(value) do 
				spEcho(key,val) 
			end
		else
			spEcho( value )
		end
	end
end