function widget:GetInfo()
	return {
		name      = "Show Builder Queue",	-- old name: Show Build
		desc      = "Shows buildings about to be built",
		author    = "WarXperiment",
		date      = "February 15, 2010",
		license   = "GNU GPL, v2 or later",
        version   = "5",
        layer     = -4,
		enabled   = true,  --  loaded by default?
    }
end

-- project page on github: https://github.com/jamerlan/unit_showbuild

--Changelog
-- before v2 developed outside of BA by WarXperiment
-- v2 [teh]decay - fixed crash: Error in DrawWorld(): [string "LuaUI/Widgets/unit_showbuild.lua"]:82: bad argument #1 to 'GetTeamColor' (number expected, got no value)
-- v3 [teh]decay - updated for spring 98 engine
-- v4 Floris - lots of performance increases
-- v5 Floris - cleanup, polishing and fixes

local command = {}
local watchBuilders = {}
local updateTime = 1		-- dont bother editing: updateTime dynamically changing

local glPushMatrix		= gl.PushMatrix
local glPopMatrix		= gl.PopMatrix
local glTranslate		= gl.Translate
local glColor			= gl.Color
local glDepthTest		= gl.DepthTest
local glRotate			= gl.Rotate
local glUnitShape		= gl.UnitShape
local glLoadIdentity	= gl.LoadIdentity

local spGetUnitDefID	= Spring.GetUnitDefID


local builderUnitDefs = {}
for udefID,def in ipairs(UnitDefs) do
	if def.isBuilder and not def.isFactory and def.buildOptions[1] then
		local buildOptions = {}
		for _,unit in ipairs(def.buildOptions) do
			buildOptions[unit] = true
		end
		builderUnitDefs[udefID] = buildOptions
	end
end

function checkBuilder(unitID)
	local queue = Spring.GetCommandQueue(unitID, 48)
	if(queue and #queue > 0) then
		for _, cmd in ipairs(queue) do
			if ( cmd.id < 0 ) then
				if(not duplicate(cmd)) then
					local myCmd = {
						uid = unitID,
						id = math.abs(cmd.id),
						teamid = Spring.GetUnitTeam(unitID),
						params = cmd.params
					}
					table.insert(command,myCmd)
					watchBuilders[unitID] = true
				end
			end
		end
	end
end

function checkBuilders()
	command = {}
	watchBuilders = {}
	local allUnits = Spring.GetAllUnits()
	for _, unitID in pairs(allUnits) do
		local uDefID = spGetUnitDefID(unitID)
		if builderUnitDefs[uDefID] then
			checkBuilder(unitID)
		end
	end
	updateTime = 0.05 + (#allUnits/3300)
	if updateTime > 1 then updateTime = 1 end
end

function widget:Initialize()
	if Spring.GetSpectatingState() or Spring.IsReplay() then
    	widgetHandler:RemoveWidget(self)
	end
	if Spring.GetGameFrame() > 0 then
		checkBuilders()
	end
end

local sec = 0
local sceduledCheck = false
function widget:Update(dt)
	sec=sec+dt
	if sec>updateTime or (sec>1/(updateTime*5) and sceduledCheck) then
		sec = 0
		sceduledCheck = false
		checkBuilders()
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams)
	if cmdID == 70 and builderUnitDefs[unitDefID] then
		checkBuilder(unitID)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, builderID)
	if watchBuilders[unitID] then
		sceduledCheck = true
	end
end


function duplicate(buildData1)
	local dupe = false
	for _, myCmd in pairs(command) do
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
	glDepthTest(true)
	for _, myCmd in pairs(command) do
		local params = myCmd.params

		local x, y, z, h = params[1], params[2], params[3], params[4]
		if(h ~= nil) then
			local degrees = h * 90
			if Spring.IsAABBInView(x-1,y-1,z-1,x+1,y+1,z+1) then
				if (myCmd.uid ~= nil) then
					glPushMatrix()
						glLoadIdentity()
						glTranslate( x, y, z )
						glRotate( degrees, 0, 1.0, 0 )
						glUnitShape(myCmd.id, myCmd.teamid, false, false, false)
					glPopMatrix()
				end
			end
		end
	end
	glDepthTest(false)
	glColor(1, 1, 1, 1)
end

