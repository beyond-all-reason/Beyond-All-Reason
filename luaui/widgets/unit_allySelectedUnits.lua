include("colors.h.lua")
include("keysym.h.lua")
local versionNumber = "2.03"

function widget:GetInfo()
	return {
		name      = "Ally Selected Units",
		desc      = "Shows units selected by teammates [v" .. string.format("%s", versionNumber ) .. "]",
		author    = "very_bad_soldier",
		date      = "August 1, 2008",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true
	}
end

--callin driven
--send 300 units per frame, if more, send next frame
--"hot" units

local floor                 = math.floor
local abs					= math.abs

local udefTab				= UnitDefs
local spGetUnitDefID        = Spring.GetUnitDefID
local spEcho                = Spring.Echo
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetGameSeconds      = Spring.GetGameSeconds
local spGetMyPlayerID       = Spring.GetMyPlayerID
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetLocalTeamID		= Spring.GetLocalTeamID
local spSendLuaUIMsg    	= Spring.SendLuaUIMsg
local spIsUnitSelected 		= Spring.IsUnitSelected
local spGetSelectedUnits	= Spring.GetSelectedUnits
local spGetUnitDefDimensions = Spring.GetUnitDefDimensions
local spSelectUnitMap		= Spring.SelectUnitMap
local spArePlayersAllied 	= Spring.ArePlayersAllied
local spGetTeamColor 		= Spring.GetTeamColor
local spGetGroundHeight 	= Spring.GetGroundHeight
local spIsSphereInView  	= Spring.IsSphereInView

local spZlibCompress        = Spring.ZlibCompress
local spZlibDecompress      = Spring.ZlibDecompress

local vfsPackU16			= VFS.PackU16
local vfsUnpackU16			= VFS.UnpackU16

local glDrawGroundCircle 	= gl.DrawGroundCircle
local glColor               = gl.Color
local glDepthTest           = gl.DepthTest
local glUnitShape			= gl.UnitShape
local glPopMatrix           = gl.PopMatrix
local glPushMatrix          = gl.PushMatrix
local glTranslate           = gl.Translate
local glText                = gl.Text
local glBillboard           = gl.Billboard
local glLineWidth 			= gl.LineWidth
local glBeginEnd			= gl.BeginEnd
local glScale				= gl.Scale
local glVertex              = gl.Vertex
local glCallList   			= gl.CallList

local GL_LINE_LOOP			= GL.LINE_LOOP

----------------------------------------------------------------

local debug = false
local unitLimitPerFrame = 300 -- controls how many units will be send per frame
local fullSelectionUpdateInt = 0 -- refresh full selection info once in ten seconds, 0 = disabled
local hotFadeTime = 10.0
local lockTeamUnits = true --disallow selection of units selected by teammates
local showAlly = true 		--also show allies (besides coop)
local useHotColor = false --use RED for all hot units, if false use playerColor starting with transparency
local minZlibSize = 130  --minimum size threshold of msg to use zlib (msg smaller than this will not be compressed before sending)
local updateInt = 0.1  --seconds for the ::update loop -- just controls isSpec check interval
local circleDivsCoop = 32  --nice circle
local circleDivsAlly = 5  --aka pentagon
local selectionDrawScaleFactor = 1.1

local hotColor = { 1.0, 0.0, 0.0, 1.0 }

local playerColorPool = {}
playerColorPool[1] = { 0.0, 1.0, 0.0 }
playerColorPool[2] = { 1.0, 1.0, 0.0 }
playerColorPool[3] = { 0.0, 0.0, 1.0 }
playerColorPool[4] = { 0.6, 0.0, 0.0 } --reserve full-red for hot units
playerColorPool[5] = { 0.0, 1.0, 1.0 }
playerColorPool[6] = { 1.0, 0.0, 1.0 }
playerColorPool[7] = { 1.0, 0.0, 0.0 }
playerColorPool[8] = { 1.0, 0.0, 0.0 }

--Internals------------------------------------------------------
local playerColors = {}
local nextPlayerPoolId = 1
local myTeamId
local myPlayerId
local coopSelectedUnits = {}
local myLastSelectedUnits = {}
local lastTime = 0
local lastFullUpdateTime = 0
local sendInNextFrame = false
local hotUnits = {}
local useZlib = false
local circleLinesCoop
local circleLinesAlly
------------------------------------------------------------------
function widget:Initialize()
	myPlayerId = spGetMyPlayerID() --spGetLocalTeamID()
	myTeamId = spGetLocalTeamID()
	
	if ( spZlibCompress ~= nil ) then
		useZlib = true
	end
	
	circleLinesCoop = calcCircleLines(circleDivsCoop)
	circleLinesAlly = calcCircleLines(circleDivsAlly) 
end

function calcCircleLines(divs)
	local circleOffset = 0
	local lines = gl.CreateList(function()
    gl.BeginEnd(GL.LINE_LOOP, function()
		  local radstep = (2.0 * math.pi) / divs
		  for i = 1, divs do
			local a = (i * radstep)
			gl.Vertex(math.sin(a), circleOffset, math.cos(a))
		  end
		end)
		gl.BeginEnd(GL.POINTS, function()
		  local radstep = (2.0 * math.pi) / divs
		  for i = 1, divs do
			local a = (i * radstep)
			gl.Vertex(math.sin(a), circleOffset, math.cos(a))
		  end
		end)
	  end)
  
	return lines
end

function widget:Shutdown()
	gl.DeleteList(circleLines)
end

function widget:CommandsChanged( id, params, options )
	if ( lockTeamUnits ) then
		deselectAllTeamSelected()
	end
	
	sendSelectedUnits()
end

function widget:UnitDestroyed(unitID, attacker )
	hotUnits[ unitID ] = nil
	myLastSelectedUnits[ unitID ] = nil
	
	for playerId, selUnits in pairs( coopSelectedUnits ) do
		selUnits["units"][ unitID ] = nil
	end
end

function newHotUnit( unitId, coop, playerId )
	local timestamp = spGetGameSeconds()
	local udef = spGetUnitDefID( unitId )
	if ( udef ~= nil ) then
		local realDefRadius = GetUnitDefRealRadius( udef )
		if ( realDefRadius ~= nil ) then
			local defRadius = selectionDrawScaleFactor * realDefRadius
			hotUnits[ unitId ] = { ts = timestamp, coop = coop, defRadius = defRadius, playerId = playerId }
		end
	end
end 

function widget:Update(deltaTime)
	local time = spGetGameSeconds()

	-- update timers once every <updateInt> seconds
	if ( ( lastTime + updateInt ) < time ) then	
		lastTime = time
		--do update stuff:
		if ( checkSpecstate() == false ) then
			return false
		end
	end
	
	if ( ( fullSelectionUpdateInt ~= 0 ) and ( lastFullUpdateTime + fullSelectionUpdateInt ) < time ) then
		--its time for a full update
		sendFullRefresh()
		lastFullUpdateTime = time
	elseif ( sendInNextFrame ) then
		sendSelectedUnits()
	end
end

--all values are 16bit
--FORMAT: uncompressed msg "cosu[addCount][removeCount]([unitIdToAdd]*)([unitIdToRemove]*)"
--FORMAT: compressed msg "cosc{[addCount][removeCount]([unitIdToAdd]*)([unitIdToRemove]*)}"  the part in curly braces has to be zlib compressed 
--FORMAT clear all: "cosu[0xffffff][0xffffff]"  --magic value. impossible to have as normal message

function sendFullRefresh()
	myLastSelectedUnits = {}
	sendSelectedUnits()
end

function sendUnitsMsg( msg )
	local finalMsg = msg
	local header = "cosu"
	if ( useZlib == true and msg:len() >= minZlibSize ) then
		finalMsg = spZlibCompress( finalMsg ) 
		header = "cosc"
		
		printDebug("ZLIBSEND")
	end
	
	spSendLuaUIMsg( header .. finalMsg, "allies")
end


function sendSelectedUnits()
	local units = spGetSelectedUnits()
	
	local partAdd = ""
	local addCount = 0
	for i, unitId in ipairs(units) do
		--check if unit is new this time
		if ( myLastSelectedUnits[unitId] == nil ) then
			--printDebug( "adding: " .. unitId )
			partAdd = partAdd .. vfsPackU16(unitId)
			myLastSelectedUnits[unitId] = true
			addCount = addCount + 1
			
			if ( addCount > unitLimitPerFrame ) then
				break;
			end
		end
	end

	local remTab = {} --these units will be removed in the next step
	local partRemove = ""
	local remCount = 0
	for unitId, unit in pairs(myLastSelectedUnits) do
		--check if unit is still selected
		if ( spIsUnitSelected(unitId) == false ) then
			partRemove = partRemove .. vfsPackU16(unitId)
			remTab[unitId] = true
			remCount = remCount + 1
			
			if ( (addCount + remCount) > unitLimitPerFrame ) then
				break;
			end
		end
	end
	
	--remove not anymore selected units
	for unitId, b in pairs(remTab) do
		myLastSelectedUnits[unitId] = nil
	end
	
	sendInNextFrame = false --reset
	local msg = partAdd .. partRemove
	if ( msg:len() > 1 ) then
		local msgToSend = ""
		if ( #units > 0 ) and ( addCount + remCount > #units ) then
			printDebug("OptimizedMove" )
			--its more efficient to clear all and then start from zero
			--so: 1. Clear All
			msgToSend = vfsPackU16(0xffff) .. vfsPackU16(0xffff)
			sendUnitsMsg( msgToSend, "allies")
			myLastSelectedUnits = {}
			--2. do normal send
			sendSelectedUnits()
		else
			if ( #units == 0 ) then
				--send clear all message
				printDebug("Clear" )
				msgToSend = vfsPackU16(0xffff) .. vfsPackU16(0xffff)
				myLastSelectedUnits = {}
			else
				--send standard message
				printDebug("Sending: " .. addCount .. " " .. remCount )
				msgToSend = vfsPackU16(addCount) .. vfsPackU16(remCount) .. msg
				
				if ( addCount + remCount >= unitLimitPerFrame ) then
					--there is more (very probably)
					sendInNextFrame = true
				end
			end
			
			sendUnitsMsg( msgToSend, "allies")
		end
	end
end

function checkSpecstate()
	local _, _, spec, _, _, _, _, _ = spGetPlayerInfo(myPlayerId)
	
	if ( spec == true ) then
		spEcho("<CoopSelectedUnits> Spectator mode. Widget removed.")
		widgetHandler:RemoveWidget()
		return false
	end
end

function tokenizeSelectedUnitsMsg( addCount, removeCount, msg )
	local addUnits = {}
	if ( addCount > 0 ) then
		addUnits = vfsUnpackU16( msg, 5, addCount )
	end
	
	local remUnits = {}
	if ( removeCount > 0 ) then
		remUnits = vfsUnpackU16( msg, 5 + addCount * 2, removeCount )
	end
	
	local units = addUnits
	for i, unitId in ipairs(remUnits) do
		table.insert( units, -unitId)
	end
	
	return units
end


function widget:RecvLuaMsg(inMsg, playerID)	
	if ( ( (inMsg:sub(1,4)=="cosu") or (inMsg:sub(1,4)=="cosc") ) ) then
		if ( ( playerID == myPlayerId ) and ( debug == false ) ) then
			return false
		end
		
		local _,_,_,teamId = spGetPlayerInfo(playerID)
		--teamId = 1
		if ( teamId == myTeamId or ( showAlly and spArePlayersAllied( playerID, myPlayerId ) ) ) then
			if ( coopSelectedUnits[ playerID ] == nil ) then
				coopSelectedUnits[ playerID ] = {}
				coopSelectedUnits[ playerID ]["units"] = {}
				coopSelectedUnits[ playerID ]["coop"] = true
				if ( teamId ~= myTeamId ) then
					coopSelectedUnits[ playerID ]["coop"] = false					
				end
			end
			
			--grab color from color pool for new teammate
			if ( playerColors[ playerID ] == nil ) then
				--no color yet
				if ( coopSelectedUnits[ playerID ]["coop"] == true ) then 
					if ( playerColorPool[ nextPlayerPoolId ] == nil ) then
						playerColors[ playerID ] = playerColorPool[ 1 ]  --we have only 8 colors, take color 1 as default
					else
						playerColors[ playerID ] = playerColorPool[ nextPlayerPoolId ]
					end
					nextPlayerPoolId = nextPlayerPoolId + 1
				else
					local r,g,b,a  = spGetTeamColor( teamId )--he is only ally, use his color
					playerColors[ playerID ] = { r, g, b, a }
				end
			end
			
			local msg = inMsg:sub(5)
			if ( inMsg:sub(4,4) == "c" ) then		--we have a compressed msg here
				printDebug( "Received compressed msg!")
				msg = spZlibDecompress( msg )
			end
			
			local counts = vfsUnpackU16( msg, 1, 2 )
			
			if ( ( counts[1] == counts[2] ) and ( counts[1] == 0xffff ) ) then
				printDebug("Recvd Clearall")
				--make all hot
				for unitId, defRadius in pairs(coopSelectedUnits[ playerID ]["units"]) do
					newHotUnit( unitId, coopSelectedUnits[ playerID ]["coop"], playerID )
				end
				--clear all
				coopSelectedUnits[ playerID ]["units"] = {}
			else
				selUnits = tokenizeSelectedUnitsMsg( counts[1], counts[2], msg )
				for i,unitId in ipairs(selUnits) do
					if ( unitId < 0 ) then
						--remove unit
						coopSelectedUnits[ playerID ]["units"][-unitId] = nil
						--make it hot
						newHotUnit( -unitId, coopSelectedUnits[ playerID ]["coop"], playerID )
					else
						--add unit
						local realDefRadius = GetUnitDefRealRadius( spGetUnitDefID( unitId ) )
						if ( realDefRadius ~= nil ) then
							coopSelectedUnits[ playerID ]["units"][ unitId] = realDefRadius * selectionDrawScaleFactor
							--un-hot it
							hotUnits[  unitId ] = nil
						end
					end
				end
			end
		end
		
		return true
	end
	
	return false; 
end

function deselectAllTeamSelected()
	local selectedUnits = array2Table( spGetSelectedUnits() )
	for playerId, selUnits in pairs( coopSelectedUnits ) do
		for unitId, defRadius in pairs( selUnits["units"] ) do
			--printDebug("Desel: " .. unitId )
			selectedUnits[unitId] = nil
		end
	end
	spSelectUnitMap( selectedUnits )
end

function array2Table( arr )
	tab = {}
	for i,v in ipairs(arr) do
		tab[v] = true
	end
	return tab
end

function widget:DrawWorldPreUnit()
	DrawSelectedUnits()
	DrawHotUnits()
end

--stolen from team_platter - thanks trepan ;)
local realRadii = {}
function GetUnitDefRealRadius(udid)
  local radius = realRadii[udid]
  if (radius) then
    return radius
  end

  local ud = udefTab[udid]
  if (ud == nil) then return nil end
  
  local dims = spGetUnitDefDimensions(udid)
  if (dims == nil) then return nil end

  local scale = ud.hitSphereScale -- missing in 0.76b1+
  scale = ((scale == nil) or (scale == 0.0)) and 1.0 or scale
  radius = dims.radius / scale
  realRadii[udid] = radius
    
  return radius
end

function DrawSelectedUnits()
	glDepthTest(false)
	glColor(0.0, 1.0, 0.0, 1.0 )
	glLineWidth( 2 )
	
	local now = spGetGameSeconds()
	for playerId, selUnits in pairs( coopSelectedUnits ) do
		glColor( playerColors[ playerId ][1],  playerColors[ playerId ][2],  playerColors[ playerId ][3] )  
		for unitId, defRadius in pairs( selUnits["units"] ) do
			local x, y, z = spGetUnitBasePosition(unitId)
			local inView = false
			if ( z ~= nil ) then --checking z should be enough insteady of x,y,z
				inView = spIsSphereInView( x, y, z, defRadius )
			end
			--printDebug( "Draw unitID:" .. unitId  .. " radius: " .. defRadius)
			if ( inView ) then
				local lines = circleLinesAlly
				if ( selUnits["coop"] == true ) then
					lines = circleLinesCoop
				end

				glPushMatrix()
				glTranslate( x, y, z)
				glScale( defRadius, 1, defRadius)
				glCallList(lines)
				glPopMatrix()
			end
		end
	end
	
	glDepthTest(false)
 	glColor(1, 1, 1, 1)
	glLineWidth( 1 )
end

function DrawHotUnits()
	glDepthTest(false)
	glLineWidth( 2 )

	local toDelete = {}
	
	local now = spGetGameSeconds()
	for unitID, val in pairs( hotUnits ) do
		local x, y, z = spGetUnitBasePosition(unitID)
		local defRadius = val["defRadius"]
		local inView = false
		if ( z ~= nil ) then --checking z should be enough insteady of x,y,z
			inView = spIsSphereInView( x, y, z, defRadius )
		end
		if ( inView ) then
			local timeDiff = (now - val["ts"])
			
			if ( timeDiff <= hotFadeTime ) then
				if ( useHotColor ) then
					hotColor[4] = 1.0 - ( timeDiff / hotFadeTime )
					glColor( hotColor )
				else
					local cl = playerColors[ val["playerId"] ]
					cl[4] = 0.5 - 0.5 * ( timeDiff / hotFadeTime )
					glColor( cl )  
				end
			else
				toDelete[unitID] = true
			end
			
			if ( toDelete[unitID] == nil ) then
				local lines = circleLinesAlly
				if ( val["coop"] == true ) then
					lines = circleLinesCoop
				end

				glPushMatrix()
				glTranslate(x,y,z)
				glScale( defRadius, 1, defRadius)
				glCallList(lines)
				glPopMatrix()
			end
		end
	end
	
	for unitID, val in pairs( toDelete ) do
		hotUnits[unitID] = nil
	end
	
	glDepthTest(false)
 	glColor(1, 1, 1, 1)
	glLineWidth( 1 )
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