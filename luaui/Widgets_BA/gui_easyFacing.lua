include("keysym.h.lua")
local versionNumber = "1.5"

function widget:GetInfo()
	return {
		name      = "Easy Facing",
		desc      = "[v" .. string.format("%s", versionNumber ) .. "] Enables changing building facing by holding left mouse button. Hold the middle mouse button to change facing while queueing.",
		author    = "very_bad_soldier",
		date      = "2009.08.10",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true
	}
end

--1.1 Tweaks by Pako, big thx!

-- CONFIGURATION
local debug = false
local updateInt = 1 --seconds for the ::update loop
local sens = 80	--rotate mouse sensitivity - length of mouse movement vector
local drawForAll = false --draw facing direction also for other buildings than labs
--------------------------------------------------------------------------------
local inDrag = false
local mmbStart = false
local mouseDeltaX = 0
local mouseDeltaY = 0
local mouseXStartRotate = 0
local mouseYStartRotate = 0
local mouseXStartDrag = 0
local mouseYStartDrag = 0
local mouseLbLast = false
-------------------------------------------------------------------------------
local udefTab				= UnitDefs

local spGetActiveCommand 	= Spring.GetActiveCommand
local spGetKeyState         = Spring.GetKeyState
local spGetModKeyState      = Spring.GetModKeyState
local spGetSelectedUnits    = Spring.GetSelectedUnits
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetGameSeconds      = Spring.GetGameSeconds
local spGetActiveCommand 	= Spring.GetActiveCommand
local spGetActiveCmdDesc 	= Spring.GetActiveCmdDesc
local spGetMouseState       = Spring.GetMouseState
local spTraceScreenRay      = Spring.TraceScreenRay
local spGetMyPlayerID       = Spring.GetMyPlayerID
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetCameraVectors    = Spring.GetCameraVectors
local spEcho                = Spring.Echo
local spWarpMouse			= Spring.WarpMouse
local spGetBuildFacing		= Spring.GetBuildFacing
local spSetBuildFacing 		= Spring.SetBuildFacing
local spPos2BuildPos 		= Spring.Pos2BuildPos
local spGetGroundHeight 	= Spring.GetGroundHeight

local floor                 = math.floor
local abs					= math.abs
local atan2                 = math.atan2
local pi                    = math.pi
local sqrt                  = math.sqrt

local glColor               = gl.Color
local glLineWidth           = gl.LineWidth
local glDepthTest           = gl.DepthTest
local glTexture             = gl.Texture
local glPopMatrix           = gl.PopMatrix
local glPushMatrix          = gl.PushMatrix
local glTranslate           = gl.Translate
local glText                = gl.Text
local glVertex              = gl.Vertex
local glRotate				= gl.Rotate
local glBeginEnd			= gl.BeginEnd
local glScale				= gl.Scale

local GL_TRIANGLES			= GL.TRIANGLES
----------------------------------------------------------------------------------


function widget:PlayerChanged(playerID)
    if Spring.GetSpectatingState() and Spring.GetGameFrame() > 0 then
        widgetHandler:RemoveWidget(self)
    end
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        widget:PlayerChanged()
    end
end

function widget:GameStart()
	widget:PlayerChanged()
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
	
	manipulateFacing()
end

function widget:DrawWorld()
	drawOrientation()
	
	ResetGl()
end

function getVector2dLen( vector )
	return sqrt( ( vector[1] * vector[1] ) + ( vector[2] * vector[2] ) )
end

function getRotationVectors2d( vectorA, vectorB )
	vectorA = normalizeVector2d( vectorA )
	vectorB = normalizeVector2d( vectorB )
	local radian = atan2( vectorA[2], vectorA[1] ) - atan2( vectorB[2], vectorB[1] )
	local val = ( 360.0 * radian) / ( 2 * pi ) 
	return normalizeDegreeRange(val)
end

--i currently get all degress in a range from 0 to 270 and 0 to -90
--this is a hack to correct this
--also corrects values >360
function normalizeDegreeRange( degree )
	if ( degree < 0.0 ) then
		degree = 360.0 + degree
	elseif ( degree > 360.0 ) then
		degree = degree - 360.0
	end
	return degree
end

--returns the rotation degrees between mouse move vector and defined forward vector
function getMouseFacingDegree( mouseVec )
	local forwVec = { 0.0, 1.0 }
	return getRotationVectors2d( forwVec, mouseVec )
end

function normalizeVector2d( vector )
	local len = getVector2dLen( vector )
	local normVec = {0.0,0.0};
	normVec[1] = vector[1] / len
	normVec[2] = vector[2] / len
	return normVec
end

function getFacingByMouseDelta( mouseDeltaX,mouseDeltaY )
	local camVecs = spGetCameraVectors()	--would be cool to update this only on a callin like "onCameraMoved()"
	
	local mouseMovVec = { mouseDeltaX, mouseDeltaY }
	local mMovVecLen = getVector2dLen( mouseMovVec )
	
	if ( mMovVecLen < sens ) then
		return nil
	end
	
	local mouseDegree = getMouseFacingDegree( mouseMovVec )
	
	--calculate the camera angle
	local camRight2d = { camVecs.right[1], -camVecs.right[3] }
	local camDegree = getMouseFacingDegree( camRight2d ) - 90
	camDegree = normalizeDegreeRange( camDegree )
	
	--take the camera angle into account here
	mouseDegree = mouseDegree + camDegree
	mouseDegree = normalizeDegreeRange( mouseDegree )
	
	local newFacing = nil
	if ( ( mouseDegree >= 280.0 ) or ( mouseDegree < 45.0 ) ) then
		newFacing = 2
	elseif ( ( mouseDegree >= 45.0 ) and ( mouseDegree < 135.0 ) ) then
		newFacing = 1
	elseif ( ( mouseDegree >= 135.0 ) and ( mouseDegree < 225.0 ) ) then 
		newFacing = 0
	elseif ( ( mouseDegree >= 225.0 ) and ( mouseDegree < 280.0 ) ) then
		newFacing = 3
	else
		newFacing = 0 --should not happen
	end
	
	return newFacing
end

local ineffect = false
function manipulateFacing()
	ineffect = false

	local mx,my,lmb,mmb,rmb = spGetMouseState()
	local alt,ctrl,meta,shift = spGetModKeyState()

	--check if valid command
	local idx, cmd_id, cmd_type, cmd_name = spGetActiveCommand()
	if (not cmd_id) then return end

	local unitDefID = -cmd_id
	local udef = udefTab[unitDefID]

	--if (lmb and (mmb or (not shift or (udef ~= nil and udef["isFactory"])))) then
	if (lmb and mmb) then
		--in
        if not inDrag then
            mouseDeltaX = 0
            mouseDeltaY = 0
            mouseXStartRotate = mx
            mouseYStartRotate = my
            mouseXStartDrag = mx
            mouseYStartDrag = my
        end

		inDrag = true
		printDebug("IN")
	else
		--out
		printDebug("OUT")
		inDrag = false
	end


	--check if build command
	local cmdDesc = spGetActiveCmdDesc( idx )
	if ( cmdDesc["type"] ~= 20 ) then
		--quit here if not a build command
		return
	end
	
	if ( inDrag ) then
		local curDeltaX = mx - mouseXStartRotate
		mouseDeltaX = mouseDeltaX + curDeltaX
		local curDeltaY = my - mouseYStartRotate
		mouseDeltaY = mouseDeltaY + curDeltaY
        
		local newFacing = getFacingByMouseDelta( mouseDeltaX, mouseDeltaY )

		if ( newFacing ~= nil ) then
			mouseDeltaX = 0
			mouseDeltaY = 0 
			
			if ( newFacing ~= spGetBuildFacing() ) then
				spSetBuildFacing( newFacing )
			end
		end
			
		if mouseXStartRotate~=mx or mouseYStartRotate~=my then
			spWarpMouse( mouseXStartRotate, mouseYStartRotate ) --set old mouse coords to prevent mouse movement
		end
	end
	ineffect = true
end

function drawOrientation()
	if not ineffect then return end

	--local mx,my,lmb,mmb,rmb = spGetMouseState()
	--if not lmb then return false end

	--local alt,ctrl,meta,shift = spGetModKeyState()
	--if shift then return false end

	local idx, cmd_id, cmd_type, cmd_name = spGetActiveCommand()
	local cmdDesc = spGetActiveCmdDesc( idx )

	if ( cmdDesc == nil or cmdDesc["type"] ~= 20 ) then
		--quit here if not a build command
		return
	end

	local unitDefID = -cmd_id

	local udef = udefTab[unitDefID]

	--check for an empty buildlist to avoid to draw for air repair pads
	if (drawForAll == false and (udef["isFactory"] == false or #udef["buildOptions"] == 0)) then
		return
	end

	local mx, my = spGetMouseState()

	if ( shift and inDrag ) then
		mx = mouseXStartDrag
		my = mouseYStartDrag
		printDebug("UDEFID: " .. mx )
	end

	local _, coords = spTraceScreenRay(mx, my, true, true)

	if not coords then return end

	local centerX = coords[1]
	local centerY = coords[2]
	local centerZ = coords[3]

	centerX, centerY, centerZ = spPos2BuildPos( unitDefID, centerX, centerY, centerZ )

	glLineWidth(1)
	glColor( 0.0, 1.0, 0.0, 0.45 )

	local function drawFunc()
		glVertex( 0, 0, -23)
		glVertex( 0, 0, 23)
		glVertex( 15, 0, 0)

		--glVertex( 0, 0, -10)
		--glVertex( 0, 0, 10)
		--glVertex( 30, 0, -7)

		--glVertex( 0, 0,  10)
		--glVertex( 30, 0, 7)
		--glVertex( 30, 0, -7 )

		--glVertex( 30, 0, -7)
		--glVertex( 24, 0, -26 )
		--glVertex( 56, 0, 0 )

		--glVertex( 30, 0, 7)
		--glVertex( 56, 0, 0 )
		--glVertex( 24, 0, 26 )

		--glVertex( 30, 0, 7)
		--glVertex( 56, 0, 0)
		--glVertex( 30, 0, -7)
	end

	--local height = spGetGroundHeight( centerX, centerZ )
	local transSpace = udef["zsize"] * 4   --should be ysize but its not there?!?

	local transX, transZ
	local facing = spGetBuildFacing()
	if ( facing == 0 ) then
		transX = 0
		transZ = transSpace
	elseif ( facing == 1 ) then
		transX = transSpace
		transZ = 0
	elseif ( facing == 2 ) then
		transX = 0
		transZ = -transSpace
	elseif ( facing == 3 ) then
		transX = -transSpace
		transZ = 0
	end

	glPushMatrix()

	glTranslate( centerX + transX, centerY, centerZ + transZ)
	glRotate( ( 3 + facing ) * 90, 0, 1, 0 )
	glScale( (transSpace or 70)/70, 1.0, (transSpace or 70)/70)
	glBeginEnd( GL_TRIANGLES, drawFunc )

	glScale( 1.0, 1.0, 1.0 )

	glPopMatrix()

	glColor( 1.0, 1.0, 1.0 )
end

--Commons
function ResetGl() 
	glColor( { 1.0, 1.0, 1.0, 1.0 } )
	glLineWidth( 1.0 )
	glDepthTest(false)
	glTexture(false)
end

function CheckSpecState()
	local playerID = spGetMyPlayerID()
	local _, _, spec, _, _, _, _, _ = spGetPlayerInfo(playerID)
		
	if ( spec == true ) then
		widgetHandler:RemoveWidget(self)
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
	