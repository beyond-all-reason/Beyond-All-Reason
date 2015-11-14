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
		enabled   = false
	}
end

--callin driven
--"hot" units

local floor                 = math.floor
local abs					= math.abs

local udefTab				= UnitDefs
local spGetUnitDefID        = Spring.GetUnitDefID
local spEcho                = Spring.Echo
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetMyPlayerID       = Spring.GetMyPlayerID
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetLocalTeamID		= Spring.GetLocalTeamID
local spGetUnitDefDimensions = Spring.GetUnitDefDimensions
local spSelectUnitMap		= Spring.SelectUnitMap
local spGetTeamColor 		= Spring.GetTeamColor
local spGetGroundHeight 	= Spring.GetGroundHeight
local spIsSphereInView  	= Spring.IsSphereInView
local spGetSpectatingState	= Spring.GetSpectatingState
local spGetGameSeconds		= Spring.GetGameSeconds

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



local hotFadeTime = 10.0
local lockTeamUnits = false --disallow selection of units selected by teammates
local showAlly = true 		--also show allies (besides coop)
local useHotColor = false --use RED for all hot units, if false use playerColor starting with transparency
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
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local playerSelectedUnits = {}
local hotUnits = {}
local circleLinesCoop
local circleLinesAlly
------------------------------------------------------------------
function widget:Initialize()
	circleLinesCoop = calcCircleLines(circleDivsCoop)
	circleLinesAlly = calcCircleLines(circleDivsAlly) 

	for _, playerID in pairs(Spring.GetPlayerList()) do
		widget:PlayerAdded(playerID)
	end

	widget:PlayerChanged(myPlayerID)

	widgetHandler:RegisterGlobal('selectedUnitsRemove', selectedUnitsRemove)
	widgetHandler:RegisterGlobal('selectedUnitsClear', selectedUnitsClear)
	widgetHandler:RegisterGlobal('selectedUnitsAdd', selectedUnitsAdd)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('selectedUnitsRemove')
	widgetHandler:DeregisterGlobal('selectedUnitsClear')
	widgetHandler:DeregisterGlobal('selectedUnitsAdd')
	gl.DeleteList(circleLines)
end

function widget:PlayerAdded(playerID)
	local playerTeam = select(4,spGetPlayerInfo(playerID))
	if not playerSelectedUnits[ playerID ] then
		playerSelectedUnits[ playerID ] = {
			["units"]={},
			["coop"]=(playerTeam == myTeamID),
			["todraw"] = DoDrawPlayer(playerID),
		}
	end
	--grab color from color pool for new teammate
	--no color yet
	getPlayerColour(playerID,playerTeam)
end

function getPlayerColour(playerID,teamID)
	if playerSelectedUnits[ playerID ]["coop"] then 
		if not playerColorPool[ nextPlayerPoolId ] then
			playerColors[ playerID ] = playerColorPool[ 1 ]  --we have only 8 colors, take color 1 as default
		else
			playerColors[ playerID ] = playerColorPool[ nextPlayerPoolId ]
		end
		nextPlayerPoolId = nextPlayerPoolId + 1
	else
		playerColors[ playerID ] = { spGetTeamColor( teamID ) }--he is only ally, use his color
	end
end

function widget:PlayerChanged(playerID)
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
	myTeamID = spGetLocalTeamID()
	local playerTeam = select(4,spGetPlayerInfo(playerID))
	local oldCoopStatus = playerSelectedUnits[ playerID ]["coop"]
	playerSelectedUnits[ playerID ]["coop"] = (teamID == myTeamID)
	playerSelectedUnits[ playerID ]["todraw"] = DoDrawPlayer(playerID)
	
	--grab color from color pool for new teammate
	if oldCoopStatus ~= playerSelectedUnits[ playerID ]["coop"] then
		getPlayerColour(playerID,playerTeam)
	end
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


function widget:CommandsChanged( id, params, options )
	if ( lockTeamUnits ) then
		deselectAllTeamSelected()
	end
end

function widget:UnitDestroyed(unitID, attacker )
	hotUnits[ unitID ] = nil
	
	for playerID, selUnits in pairs( playerSelectedUnits ) do
		selUnits["units"][ unitID ] = nil
	end
end

function newHotUnit( unitId, coop, playerID )
	if not playerSelectedUnits[playerID]["todraw"] then
		return
	end
	local timestamp = spGetGameSeconds()
	local udef = spGetUnitDefID( unitId )
	if ( udef ~= nil ) then
		local realDefRadius = GetUnitDefRealRadius( udef )
		if ( realDefRadius ~= nil ) then
			local defRadius = selectionDrawScaleFactor * realDefRadius
			hotUnits[ unitId ] = { ts = timestamp, coop = coop, defRadius = defRadius, playerID = playerID }
		end
	end
end 


function selectedUnitsClear(playerID)
	--make all hot
	for unitId, defRadius in pairs(playerSelectedUnits[ playerID ]["units"]) do
		newHotUnit( unitId, playerSelectedUnits[ playerID ]["coop"], playerID )
	end
	--clear all
	playerSelectedUnits[ playerID ]["units"] = {}
end

function selectedUnitsAdd(playerID,unitID)
	--add unit
	local realDefRadius = GetUnitDefRealRadius( spGetUnitDefID( unitID ) )
	if realDefRadius then
		playerSelectedUnits[ playerID ]["units"][ unitID] = realDefRadius * selectionDrawScaleFactor
		--un-hot it
		hotUnits[  unitID ] = nil
	end
end

function selectedUnitsRemove(playerID,unitID)
	--remove unit
	playerSelectedUnits[ playerID ]["units"][unitID] = nil
	--make it hot
	newHotUnit( unitID, playerSelectedUnits[ playerID ]["coop"], playerID )
end

function DoDrawPlayer(playerID,teamID)	
	if playerID == myPlayerID then
		return false
	end
	if teamID ~= myTeamID and not showAlly then
		return false
	end
	return true
		 
end

function deselectAllTeamSelected()
	local selectedUnits = array2Table( spGetSelectedUnits() )
	for playerID, selUnits in pairs( playerSelectedUnits ) do
		for unitId, defRadius in pairs( selUnits["units"] ) do
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
	for playerID, selUnits in pairs( playerSelectedUnits ) do
		if selUnits["todraw"] then
			glColor( playerColors[ playerID ][1],  playerColors[ playerID ][2],  playerColors[ playerID ][3] )  
			for unitId, defRadius in pairs( selUnits["units"] ) do
				local x, y, z = spGetUnitBasePosition(unitId)
				local inView = false
				if ( z ~= nil ) then --checking z should be enough insteady of x,y,z
					inView = spIsSphereInView( x, y, z, defRadius )
				end
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
					local cl = playerColors[ val["playerID"] ]
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
