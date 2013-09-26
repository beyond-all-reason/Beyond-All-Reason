function widget:GetInfo()
	return {
		name      = "Show Build V2",
		desc      = "Shows buildings about to be built",
		author    = "WarXperiment",
		date      = "February 15, 2010",
		license   = "GNU GPL, v2 or later",
        version   = "2",
        layer     = -4,
		enabled   = true,  --  loaded by default?
		handler   = true,
    }
end

-- project page on github: https://github.com/jamerlan/unit_showbuild

--Changelog
-- before v2 developed outside of BA by WarXperiment
-- v2 [teh]decay - fixed crash: Error in DrawWorld(): [string "LuaUI/Widgets/unit_showbuild.lua"]:82: bad argument #1 to 'GetTeamColor' (number expected, got no value)

local command = {}
local update = {}
local myTeamID

local glPushMatrix	= gl.PushMatrix
local glPopMatrix	= gl.PopMatrix
local glTranslate	= gl.Translate
local glBillboard	= gl.Billboard
local glColor		= gl.Color
local glText		= gl.Text
local glBeginEnd	= gl.BeginEnd
local GL_LINE_STRIP	= GL.LINE_STRIP
local glDepthTest	= gl.DepthTest
local glRotate		= gl.Rotate
local glUnitShape	= gl.UnitShape
local glVertex		= gl.Vertex

local gameframe = 0
function widget:Initialize()
	if Spring.GetSpectatingState() or Spring.IsReplay() then
    widgetHandler:RemoveWidget()
	end
end

function widget:GameFrame(frame)
gameframe = frame

	for unitID,_ in pairs(update) do
		if(update[unitID] == frame) then
			for key, myCmd in pairs(command) do	
				if myCmd.uid == unitID then
				command[key] = nil
				end
			end	
		check(unitID)
		end	
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams)
update[unitID] = gameframe + math.random(1,10)
end

function duplicate(buildData1)
local dupe = false
	for key, myCmd in pairs(command) do	
	local params1 = buildData1.params
	local params2 = myCmd.params
		if buildData1.id == myCmd.id and params1[1] == params2[1] and params1[2] == params2[2] and params1[3] == params2[3] then
		dupe = true
		end
	end
	if(dupe == false) then
	return false
	else 
	return true
	end
end

function widget:DrawWorld()
	for key, myCmd in pairs(command) do	
		local cmd = myCmd.id
		local params = myCmd.params
		cmd = math.abs( cmd )
		local x, y, z, h = params[1], params[2], params[3], params[4]
		if(h ~= nil) then
			local degrees = h * 90
			if Spring.IsAABBInView(x-1,y-1,z-1,x+1,y+1,z+1) then
                if(myCmd.uid ~= nil and Spring.GetUnitTeam(myCmd.uid) and type(Spring.GetUnitTeam(myCmd.uid)) == "number") then
                    local r,g,b = Spring.GetTeamColor(Spring.GetUnitTeam(myCmd.uid))
                    glColor(r, g, b, 0.8 )
                    gl.LineWidth(2.5)
                    glBeginEnd(GL_LINE_STRIP, DrawOutline, cmd, x, y+5, z, h)
                    glColor(1.0, 1.0, 1.0, 0.30 )
                    glDepthTest(true)
                    glPushMatrix()
                    glTranslate( x, y, z )
                    glRotate( degrees, 0, 1.0, 0 )
                    glUnitShape( cmd, Spring.GetUnitTeam(myCmd.uid))
                    glRotate( degrees, 0, -1.0, 0 )
                    glBillboard()
                    glPopMatrix()
                    glDepthTest(false)
                    glColor(1, 1, 1, 1)
                end
			end
		end	
	end	
end

	
function DrawOutline(cmd,x,y,z,h)
	local ud = UnitDefs[cmd]
	local baseX = ud.xsize * 4 -- ud.buildingDecalSizeX
	local baseZ = ud.zsize * 4 -- ud.buildingDecalSizeY
	if (h == 1 or h==3) then
		baseX,baseZ = baseZ,baseX
	end
	glVertex(x-baseX,y,z-baseZ)
	glVertex(x-baseX,y,z+baseZ)
	glVertex(x+baseX,y,z+baseZ)
	glVertex(x+baseX,y,z-baseZ)
	glVertex(x-baseX,y,z-baseZ)
end	

-------------------------------------------------------------
function check(unitID)
local queue = Spring.GetCommandQueue(unitID)
	if(queue and #queue > 0) then
		for _, cmd in ipairs(queue) do
			if ( cmd.id < 0 ) then
				if(not duplicate(cmd)) then
				local cmdParams = cmd.params
				local myCmd = {['uid'] = unitID, ['id'] = cmd.id, ['params'] ={[1] = cmdParams[1], [2] = cmdParams[2], [3] = cmdParams[3], [4] = cmdParams[4]}}
				table.insert(command,myCmd)
				end				
			end
		end
	end	
end
