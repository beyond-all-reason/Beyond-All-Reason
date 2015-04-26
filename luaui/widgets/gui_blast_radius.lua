include("keysym.h.lua")

function widget:GetInfo()
	return {
		name      = "Blast Radius",
		desc      = "Displays blast radius while placing buildings (META)\nand of selected units (META+X)",
		author    = "very_bad_soldier",
		date      = "April 7, 2009",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true
	}
end

--These can be modified if needed
local blastCircleDivs = 64
local blastLineWidth = 1.0
local blastAlphaValue = 0.5
local updateInt = 1 --seconds for the ::update loop

--------------------------------------------------------------------------------
local blastColor = { 1.0, 0.0, 0.0 }
local expBlastAlphaValue = 1.0
local expBlastColor = { 1.0, 0.0, 0.0}
local explodeTag = "deathExplosion"
local selfdTag = "selfDExplosion"
local aoeTag = "damageAreaOfEffect"

local lastTimeUpdate = 0
local lastColorChangeTime = 0.0
local selfdCycleDir = false
local selfdCycleTime = 0.3
local expCycleTime = 0.5
local mapSquareSize = 16

-------------------------------------------------------------------------------

local udefTab				= UnitDefs
local weapNamTab			= WeaponDefNames
local weapTab				= WeaponDefs

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
local spEcho                = Spring.Echo

local glColor               = gl.Color
local glLineWidth           = gl.LineWidth
local glDepthTest           = gl.DepthTest
local glTexture             = gl.Texture
local glDrawGroundCircle    = gl.DrawGroundCircle
local glPopMatrix           = gl.PopMatrix
local glPushMatrix          = gl.PushMatrix
local glTranslate           = gl.Translate
local glBillboard           = gl.Billboard
local glText                = gl.Text

local max					= math.max
local min					= math.min
local sqrt					= math.sqrt
local abs					= math.abs
local lower                 = string.lower
local floor                 = math.floor


-----------------------------------------------------------------------------------
function widget:DrawWorld()
	DrawBuildMenuBlastRange()
	
	--hardcoded: meta + X
	local keyPressed = spGetKeyState( KEYSYMS.X )
	local alt,ctrl,meta,shift = spGetModKeyState()
		
	if (meta and keyPressed) then
		DrawBlastRadiusSelectedUnits()
	end
	
	ResetGl()
end

function ChangeBlastColor()
	--cycle red/yellow
	local time = spGetGameSeconds()
	local timediff = ( time - lastColorChangeTime )
		
	local addValueSelf = timediff/ selfdCycleTime 	
	local addValueExp = timediff/ expCycleTime 	

	if ( blastColor[2] >= 1.0 ) then
		selfdCycleDir = false
	elseif ( blastColor[2] <= 0.0 ) then
		selfdCycleDir = true
	end
	
	if ( expBlastColor[2] >= 1.0 ) then
		expCycleDir = false
	elseif ( expBlastColor[2] <= 0.0 ) then
		expCycleDir = true
	end

	if ( selfdCycleDir == false ) then
		blastColor[2] = blastColor[2] - addValueSelf
		blastColor[2] = max( 0.0, blastColor[2] )
	else
		blastColor[2] = blastColor[2] + addValueSelf
		blastColor[2] = min( 1.0, blastColor[2] )
	end
	
	if ( expCycleDir == false) then
		expBlastColor[2] = expBlastColor[2] - addValueExp
		expBlastColor[2] = max( 0.0, expBlastColor[2] )
	else
		expBlastColor[2] = expBlastColor[2] + addValueExp
		expBlastColor[2] = min( 1.0, expBlastColor[2] )
	end
					
	lastColorChangeTime = time
end

function DrawBuildMenuBlastRange()
	--check if valid command
	local idx, cmd_id, cmd_type, cmd_name = spGetActiveCommand()
	
	if (not cmd_id) then return end
	--printDebug("Cmds: idx: " .. idx .. " cmd_id: " .. cmd_id .. " cmd_type: " .. cmd_type .. " cmd_name: " .. cmd_name )
	
	--check if META is pressed
	--local keyPressed = spGetKeyState(KEYSYMS.X )
	local alt,ctrl,meta,shift = spGetModKeyState()
		
	if ( not meta ) then --and keyPressed) then
		return
	end
	
	--check if build command
	local cmdDesc = spGetActiveCmdDesc( idx )
	
	local units = spGetSelectedUnits()
	local cmdQ = Spring.GetCommandQueue( units[1] )
	
	if ( cmdDesc["type"] ~= 20 ) then
		--quit here if not a build command
		return
	end
	
	local unitDefID = -cmd_id
		
	local udef = udefTab[unitDefID]
	if ( weapNamTab[lower(udef[explodeTag])] == nil ) then
		return
	end
	
	local deathBlasId = weapNamTab[lower(udef[explodeTag])].id
	local blastRadius = weapTab[deathBlasId][aoeTag]
	local defaultDamage = weapTab[deathBlasId].damages[0]	--get default damage
		
	local mx, my = spGetMouseState()
	local _, coords = spTraceScreenRay(mx, my, true, true)
	
	if not coords then return end
		
	local centerX = coords[1]
	local centerZ = coords[3]
		
	centerX, _, centerZ = Spring.Pos2BuildPos( unitDefID, centerX, 0, centerZ )
 
    glLineWidth(blastLineWidth)
	glColor( expBlastColor[1], expBlastColor[2], expBlastColor[3], blastAlphaValue )
	
	--draw static ground circle
	glDrawGroundCircle(centerX, 0, centerZ, blastRadius, blastCircleDivs )

	--tidy up
	glLineWidth(1)
	glColor(1, 1, 1, 1)
	
	--cycle colors for next frame
	ChangeBlastColor()
end

function DrawUnitBlastRadius( unitID )
	local unitDefID =  spGetUnitDefID(unitID)
	local udef = udefTab[unitDefID]
						
	local x, y, z = spGetUnitPosition(unitID)
	
	if ( weapNamTab[lower(udef[explodeTag])] ~= nil and weapNamTab[lower(udef[selfdTag])] ~= nil ) then
		deathBlasId = weapNamTab[lower(udef[explodeTag])].id
		blastId = weapNamTab[lower(udef[selfdTag])].id

		blastRadius = weapTab[blastId][aoeTag]
		deathblastRadius = weapTab[deathBlasId][aoeTag]
						
		blastDamage = weapTab[blastId].damages[0]
		deathblastDamage = weapTab[deathBlasId].damages[0]
					
		local height = Spring.GetGroundHeight(x,z)
					
		glLineWidth(blastLineWidth)
		glColor( blastColor[1], blastColor[2], blastColor[3], blastAlphaValue)
		glDrawGroundCircle( x,y,z, blastRadius, blastCircleDivs )
				
		glPushMatrix()
		glTranslate(x - ( blastRadius / 1.5 ), height , z  + ( blastRadius / 1.5 ) )
		glBillboard()
		text = "SELF-D"
		if ( deathblastRadius == blastRadius ) then
			text = blastDamage .. " / " .. deathblastDamage --text = "SELF-D / EXPLODE"
		end

		glText( text, 0.0, 0.0, sqrt(blastRadius) , "")
		glPopMatrix()  

		if ( deathblastRadius ~= blastRadius ) then
			glColor( expBlastColor[1], expBlastColor[2], expBlastColor[3], expBlastAlphaValue)
			glDrawGroundCircle( x,y,z, deathblastRadius, blastCircleDivs )

			glPushMatrix()
			glTranslate(x - ( deathblastRadius / 1.6 ), height , z  + ( deathblastRadius / 1.6) )
			glBillboard()
			glText("EXPLODE" , 0.0, 0.0, sqrt(deathblastRadius), "cn")
			glPopMatrix()  
		end
	end
end

function DrawBlastRadiusSelectedUnits()
	glLineWidth(blastLineWidth)
  	  
	local units = spGetSelectedUnits()
        
	local deathBlasId
	local blastId
	local blastRadius
	local blastDamage
	local deathblastRadius
	local deathblastDamage
	local text
	for i,unitID in ipairs(units) do
		DrawUnitBlastRadius( unitID )
	end
	  
	ChangeBlastColor()
end

--Commons
function ResetGl() 
	glColor( { 1.0, 1.0, 1.0, 1.0 } )
	glLineWidth( 1.0 )
	glDepthTest(false)
	glTexture(false)
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
