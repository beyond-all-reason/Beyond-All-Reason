include("keysym.h.lua")
local versionNumber = "1.21"

function widget:GetInfo()
	return {
		name      = "Ghost Radar",
		desc      = "Allows ghosted radar blips [v" .. string.format("%s", versionNumber ) .. "]",
		author    = "very_bad_soldier",
		date      = "July 21, 2008",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true
	}
end

local lineWidth = 1.0 -- calcs dynamic now

local printDebug

local udefTab				= UnitDefs
local spGetUnitDefID        = Spring.GetUnitDefID
local spEcho                = Spring.Echo
local spGetUnitPosition     = Spring.GetUnitPosition
local spGetGameSeconds      = Spring.GetGameSeconds
local floor                 = math.floor
local pairs					= pairs
local spGetMyPlayerID       = Spring.GetMyPlayerID
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spIsUnitInView		= Spring.IsUnitInView

local glColor               = gl.Color
local glDepthTest           = gl.DepthTest
local glUnitShape			= gl.UnitShape
local glPopMatrix           = gl.PopMatrix
local glPushMatrix          = gl.PushMatrix
local glTranslate           = gl.Translate
local glLoadIdentity       	= gl.LoadIdentity

----------------------------------------------------------------

local debug = false
local dots = {}
local lastTime
local updateInt = 2 --seconds for the ::update loop

function widget:UnitEnteredRadar(unitID, allyTeam)
	if ( dots[unitID] ~= nil ) then
		dots[unitID]["radar"] = true
	end
end

function widget:UnitEnteredLos(unitID, allyTeam )
	--update unitID info, ID could have been reused already!
	local udefID = spGetUnitDefID(unitID)
	local udef = udefTab[udefID]
		
	--skip buildings, they get ghosted anyway
	if ( udef.isBuilding == false and udef.isFactory == false ) then 
		dots[unitID] = {}
		dots[unitID]["unitDefId"] = udefID
		dots[unitID]["teamId"] = allyTeam
		dots[unitID]["radar"] = true
		dots[unitID]["los"] = true
	else
		dots[unitID] = nil	
	end
end


function widget:UnitCreated(unitID, allyTeam)
	--kill the dot info if this unitID gets reused on own team
	if ( dots[unitID] ~= nil ) then
		dots[unitID] = nil
	end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if ( dots[unitID] ~= nil ) then
		dots[unitID] = nil
	end
end

function widget:UnitLeftRadar(unitID, allyTeam)
	if ( dots[unitID] ~= nil ) then
		dots[unitID]["radar"] = false
	end
end

function widget:UnitLeftLos(unitID, allyTeam)
	if ( dots[unitID] ~= nil ) then
		dots[unitID]["los"] = false
	end
end


function widget:DrawWorld()
	glColor(1.0, 1.0, 1.0, 0.35 )
	glDepthTest(true)

	for unitID, dot in pairs( dots ) do
		if ( dot["radar"] == true ) and ( dot["los"] == false ) and ( dot["unitDefId"] ~= nil ) then
			local x, y, z = spGetUnitPosition(unitID)
			if x and ( spIsUnitInView(unitID) ) then
				glPushMatrix()
					glLoadIdentity()
					glTranslate( x, y + 5 , z)
					glUnitShape( dot["unitDefId"], dot["teamId"], false, false, false)
				glPopMatrix()
			end
		end
	end

	glDepthTest(false)
 	glColor(1, 1, 1, 1)
end

function widget:Update()
	local timef = spGetGameSeconds()
	local time = floor(timef)

	-- update timers once every <updateInt> seconds
	if (time % updateInt == 0 and time ~= lastTime) then	
		lastTime = time
		--do update stuff:
		local playerID = spGetMyPlayerID()
		local _, _, spec, _, _, _, _, _ = spGetPlayerInfo(playerID)
		
		if ( spec == true ) then
			widgetHandler:RemoveWidget(self)
			return false
		end
	end
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
