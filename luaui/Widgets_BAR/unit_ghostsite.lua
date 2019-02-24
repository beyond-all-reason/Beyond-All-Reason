local versionNumber = "1.3"

function widget:GetInfo()
	return {
		name      = "Ghost Site",
		desc      = "Displays ghosted buildings for buildings in progress",
		author    = "very_bad_soldier, Bluestone",
		date      = "April 7, 2009",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true
	}
end

--[[changelog:
1.1: removes itself when old defense range found (thx to TFC)
1.2: fixed buildframes not showing up, now uses correct rotation, tracks enemy wrecks when necessary.
1.3: removed features, handles substitutions
--]]

local lastUpdate
local ghostSites = {}

local glColor               = gl.Color
local glDepthTest           = gl.DepthTest
local glTexture             = gl.Texture
local glPopMatrix           = gl.PopMatrix
local glPushMatrix          = gl.PushMatrix
local glTranslate           = gl.Translate
local glRotate              = gl.Rotate
local glUnitShape           = gl.UnitShape
local glLoadIdentity       	= gl.LoadIdentity

local spGetUnitDefID        = Spring.GetUnitDefID
local spValidUnitID       	= Spring.ValidUnitID
local spIsUnitAllied		= Spring.IsUnitAllied
local spGetUnitDirection    = Spring.GetUnitDirection
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitRulesParam   = Spring.GetUnitRulesParam
local spGetPositionLosState = Spring.GetPositionLosState

local mdeg = math.deg
local matan2 = math.atan2

local spec,_ = Spring.GetSpectatingState()

function widget:Update()
    if spec then return end

    local curTime = Spring.GetTimer()
    lastUpdate = lastUpdate or Spring.GetTimer()

	-- check ghost sites for deletion 
	if Spring.DiffTimers(curTime,lastUpdate)>1 then	
		DeleteGhostSites()
        lastUpdate = curTime
	end
end

function widget:DrawWorld()
    if spec then return end
	DrawGhostSites()
	ResetGl()
end

function widget:UnitEnteredLos(unitID, teamID)
	if spec or spIsUnitAllied(unitID) then
		return
	end

    local uDID = spGetUnitDefID(unitID)
	local uDef = UnitDefs[uDID]
		
	if uDef.isBuilding==true and spGetUnitRulesParam(unitID,"under_construction")==1 then
		local x, y, z = spGetUnitBasePosition(unitID)
		local dx,_,dz = spGetUnitDirection(unitID)
		local angle = mdeg(matan2(dx,dz))	
		
		ghostSites[unitID] = {uDID=uDID, x=x, y=y, z=z, teamID=teamID, angle=angle}
	end
end

function DrawGhostSites()
	glColor(0.3, 1.0, 0.3, 0.25)
	glDepthTest(true)

	for unitID, ghost in pairs( ghostSites ) do
		local x,y,z = ghost.x,ghost.y,ghost.z
		local _,inLos,_ = spGetPositionLosState(x,y,z)
	
		if not inLos then
			--glow effect?
			--gl.Blending(GL.SRC_ALPHA, GL.ONE)
            
			glPushMatrix()
				glLoadIdentity()
            	glTranslate( x, y, z)
            	glRotate(ghost.angle,0,y,0)
            	glUnitShape(ghost.uDID, ghost.teamID, false, false, false)
			glPopMatrix()
		end
	end
end

function DeleteGhostSites()
	for unitID, ghost in pairs(ghostSites) do
		local _,inLos,_ = spGetPositionLosState(ghost.x, ghost.y, ghost.z)
        local alive = spValidUnitID(unitID) and spGetUnitDefID(unitID)==ghost.uDID
        local built = spGetUnitRulesParam(unitID,"under_construction")~=1
		
		if (not alive) or built or inLos then	
			ghostSites[unitID] = nil
		end
	end
end

function ResetGl() 
	glColor( { 1.0, 1.0, 1.0, 1.0 } )
	glDepthTest(false)
	glTexture(false)
end

function widget:PlayerChanged()
	spec,_,_ = Spring.GetSpectatingState()
end

function widget:GameOver()
    widgetHandler:RemoveWidget(self)
end
