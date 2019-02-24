function widget:GetInfo()
   return {
      name      = "Commands FX",
      desc      = "Shows commands given by allies",
      author    = "Floris (bluestone helped optimizing)",
      date      = "20 may 2015",
      license   = "GNU GPL, v2 or later",
      layer     = 2,
      enabled   = true,
   }
end

-- future:          hotkey to show all current cmds? (like current shift+space)
--                  handle set target
--					quickfade on cmd cancel

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local CMD_RAW_MOVE = 39812
local CMD_ATTACK = CMD.ATTACK --icon unit or map
local CMD_CAPTURE = CMD.CAPTURE --icon unit or area
local CMD_FIGHT = CMD.FIGHT -- icon map
local CMD_GUARD = CMD.GUARD -- icon unit
local CMD_INSERT = CMD.INSERT 
local CMD_LOAD_ONTO = CMD.LOAD_ONTO -- icon unit
local CMD_LOAD_UNITS = CMD.LOAD_UNITS -- icon unit or area
local CMD_MANUALFIRE = CMD.MANUALFIRE -- icon unit or map (cmdtype edited by gadget)
local CMD_MOVE = CMD.MOVE -- icon map
local CMD_PATROL = CMD.PATROL --icon map
local CMD_RECLAIM = CMD.RECLAIM --icon unit feature or area
local CMD_REPAIR = CMD.REPAIR -- icon unit or area
local CMD_RESTORE = CMD.RESTORE -- icon area
local CMD_RESURRECT = CMD.RESURRECT -- icon unit feature or area
-- local CMD_SET_TARGET = 34923 -- custom command, doesn't go through UnitCommand
local CMD_UNLOAD_UNIT = CMD.UNLOAD_UNIT -- icon map
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS -- icon  unit or area
local BUILD = -1

local diag = math.diag
local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan 
local random = math.random

local glPushMatrix = gl.PushMatrix
local glUnitShape = gl.UnitShape
local glRotate = gl.Rotate
local glTranslate = gl.Translate
local glPopMatrix = gl.PopMatrix
local glTexture = gl.Texture
local glColor = gl.Color
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glTexCoord = gl.TexCoord
local glUnit = gl.Unit
local GL_QUADS = GL.QUADS

local GaiaTeamID  = Spring.GetGaiaTeamID()

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local filterAIteams				= true

local drawBuildQueue			= true
local drawLineTexture			= true
local drawUnitHighlight 		= true
local drawUnitHighlightSkipFPS	= 13  -- (0 to disable) skip drawing when framerate gets below this value

local opacity      				= 1
local duration     				= 2.6

local lineWidth	   				= 7.8
local lineOpacity				= 0.75
local lineDuration 				= 1		-- set a value <= 1
local lineWidthEnd				= 0.85		-- multiplier
local lineTextureLength 		= 4
local lineTextureSpeed  		= 2.4

local groundGlow				= true
local glowRadius    			= 26
local glowDuration  			= 0.5
local glowOpacity   			= 0.11

-- limit amount of effects to keep performance sane
local maxCommandCount			= 500		-- dont draw more commands than this amount, but keep processing them
local maxTotalCommandCount		= 850		-- dont add more commands above this amount
local maxGroundGlowCount		= 50
local drawUnitHightlightMaxUnits = 70

local glowImg			= ":n:LuaUI/Images/commandsfx/glow.dds"
local lineImg			= ":n:LuaUI/Images/commandsfx/line.dds"

local ignoreUnits = {}
for udefID,def in ipairs(UnitDefs) do
	if def.customParams['nohealthbars'] then
		ignoreUnits[udefID] = true
	end
end

local mapX = Game.mapSizeX
local mapZ = Game.mapSizeZ

local CONFIG = {  
    [CMD_ATTACK] = {
        sizeMult = 1.4,
		endSize = 0.28,
        colour = {1.00, 0.20, 0.20, 0.30},
    },
    [CMD_CAPTURE] = {
        sizeMult = 1.4,
		endSize = 0.28,
        colour = {1.00, 1.00, 0.30, 0.30},
    },
    [CMD_FIGHT] = {
        sizeMult = 1.2,
		endSize = 0.24,
        colour = {0.30, 0.50, 1.00, 0.25}, 
    },
    [CMD_GUARD] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {0.10, 0.10, 0.50, 0.25},
    },
    [CMD_LOAD_ONTO] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {0.30, 1.00, 1.00 ,0.25},
    },
    [CMD_LOAD_UNITS] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {0.30, 1.00, 1.00, 0.30},
    },
    [CMD_MANUALFIRE] = {
        sizeMult = 1.4,
		endSize = 0.28,
        colour = {1.00, 0.00, 0.00, 0.30},
    },
	[CMD_MOVE] = {
		sizeMult = 1,
		endSize = 0.2,
		colour = {0.00, 1.00, 0.00, 0.25},
	},
	[CMD_RAW_MOVE] = {
		sizeMult = 1,
		endSize = 0.2,
		colour = {0.00, 1.00, 0.00, 0.25},
	},
    [CMD_PATROL] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {0.10, 0.10, 1.00, 0.25},
    },
    [CMD_RECLAIM] = {
        sizeMult = 1,
		endSize = 0,
        colour = {1.00, 0.20, 1.00, 0.4},
    },
    [CMD_REPAIR] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {0.30, 1.00, 1.00, 0.4},
    },
    [CMD_RESTORE] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {0.00, 0.50, 0.00, 0.25},
    },
    [CMD_RESURRECT] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {0.20, 0.60, 1.00, 0.25},
    },
    --[[
    [CMD_SET_TARGET] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {1.00 ,0.75 ,1.00 ,0.25},
    },
    ]]
    [CMD_UNLOAD_UNIT] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {1.00, 1.00 ,0.00 ,0.25},
    },
    [CMD_UNLOAD_UNITS] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {1.00, 1.00 ,0.00 ,0.25},
    },
    [BUILD] = {
        sizeMult = 1,
		endSize = 0.2,
        colour = {0.00, 1.00 ,0.00 ,0.25},
    }
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local enabledTeams = {}
local commands = {}
local monitorCommands = {}
local minQueueCommand = 1
local maxCommand = 0
local totalCommands = 0

local unitCommand = {} -- most recent key in command table of order for unitID 
local osClock

local UNITCONF = {}
local shapes = {}

local drawFrame = 0
local gameframeDrawFrame = 0

local spGetUnitPosition	= Spring.GetUnitPosition
local spGetUnitCommands	= Spring.GetUnitCommands
local spIsUnitInView = Spring.IsUnitInView
local spIsSphereInView = Spring.IsSphereInView
local spIsUnitIcon = Spring.IsUnitIcon
local spValidUnitID = Spring.ValidUnitID
local spValidFeatureID = Spring.ValidFeatureID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spIsUnitSelected = Spring.IsUnitSelected
local spIsGUIHidden = Spring.IsGUIHidden
local spTraceScreenRay = Spring.TraceScreenRay
local spIsUnitSelected = Spring.IsUnitSelected
local spGetUnitDefID = Spring.GetUnitDefID
local spLoadCmdColorsConfig	= Spring.LoadCmdColorsConfig
local spGetFPS = Spring.GetFPS
local spGetMyTeamID = Spring.GetMyTeamID

local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local MAX_UNITS = Game.maxUnits
local find = string.find

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function SetUnitConf()
	local name, shape, xscale, zscale, scale, xsize, zsize, weaponcount
	for udid, unitDef in pairs(UnitDefs) do
		xsize, zsize = unitDef.xsize, unitDef.zsize
		scale = ( xsize^2 + zsize^2 )^0.5
		name = unitDef.name
		
		if (unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0) then
			shapeName = 'square'
			shape = shapes.square
			xscale, zscale = xsize, zsize
		elseif (unitDef.isAirUnit) then
			shapeName = 'triangle'
			shape = shapes.triangle
			xscale, zscale = scale, scale
		else
			shapeName = 'circle'
			shape = shapes.circle
			xscale, zscale = scale, scale
		end
			
		UNITCONF[udid] = {name=name, shape=shape, shapeName=shapeName, xscale=xscale, zscale=zscale}
	end
end


local function setCmdLineColors(alpha)
	spLoadCmdColorsConfig('move        0.5  1.0  0.5  '..alpha)
	spLoadCmdColorsConfig('attack      1.0  0.2  0.2  '..alpha)
	spLoadCmdColorsConfig('fight       0.5  0.5  1.0  '..alpha)
	spLoadCmdColorsConfig('wait        0.5  0.5  0.5  '..alpha)
	spLoadCmdColorsConfig('build       0.0  1.0  0.0  '..alpha)
	spLoadCmdColorsConfig('guard       0.3  0.3  1.0  '..alpha)
	spLoadCmdColorsConfig('stop        0.0  0.0  0.0  '..alpha)
	spLoadCmdColorsConfig('patrol      0.3  0.3  1.0  '..alpha)
	spLoadCmdColorsConfig('capture     1.0  1.0  0.3  '..alpha)
	spLoadCmdColorsConfig('repair      0.3  1.0  1.0  '..alpha)
	spLoadCmdColorsConfig('reclaim     1.0  0.2  1.0  '..alpha)
	spLoadCmdColorsConfig('restore     0.0  1.0  0.0  '..alpha)
	spLoadCmdColorsConfig('resurrect   0.2  0.6  1.0  '..alpha)
	spLoadCmdColorsConfig('load        0.3  1.0  1.0  '..alpha)
	spLoadCmdColorsConfig('unload      1.0  1.0  0.0  '..alpha)
	spLoadCmdColorsConfig('deathWatch  0.5  0.5  0.5  '..alpha)
end

function resetEnabledTeams()
	enabledTeams = {}
	local t = Spring.GetTeamList()
	for _,teamID in ipairs(t) do
		if not filterAIteams  or  not select(4,Spring.GetTeamInfo(teamID)) then
			enabledTeams[teamID] = true
		end
	end
end

function widget:Initialize()
	--SetUnitConf()
	
	--spLoadCmdColorsConfig('useQueueIcons  0 ')
	spLoadCmdColorsConfig('queueIconScale  0.66 ')
	spLoadCmdColorsConfig('queueIconAlpha  0.5 ')
	
	setCmdLineColors(0.5)
	resetEnabledTeams()

	WG['commandsfx'] = {}
	WG['commandsfx'].getOpacity = function()
		return opacity
	end
	WG['commandsfx'].setOpacity = function(value)
		opacity = value
	end
	WG['commandsfx'].getFilterAI = function()
		return filterAIteams
	end
	WG['commandsfx'].setFilterAI = function(value)
		filterAIteams = value
		resetEnabledTeams()
	end
end

function widget:Shutdown()
	--spLoadCmdColorsConfig('useQueueIcons  1 ')
	spLoadCmdColorsConfig('queueIconScale  1 ')
	spLoadCmdColorsConfig('queueIconAlpha  1 ')
	
	setCmdLineColors(0.7)
end




local function DrawLineEnd(x1,y1,z1, x2,y2,z2, width)
	y1 = y2
	
	local distance			= diag(x2-x1, y2-y1, z2-z1) 
	
	-- for 2nd rounding
	local distanceDivider = distance / (width/2.25)
	x1_2 = x2 - ((x1 - x2) / distanceDivider)
	z1_2 = z2 - ((z1 - z2) / distanceDivider)
	
	-- for first rounding
	distanceDivider = distance / (width/4.13)
	x1 = x2 - ((x1 - x2) / distanceDivider)
	z1 = z2 - ((z1 - z2) / distanceDivider)
	
    local theta	= (x1~=x2) and atan((z2-z1)/(x2-x1)) or pi/2
    local zOffset = cos(pi-theta) * width / 2
    local xOffset = sin(pi-theta) * width / 2
    
    local xOffset2 = xOffset / 1.35
    local zOffset2 = zOffset / 1.35
	
	-- first rounding
    glVertex(x1+xOffset2, y1, z1+zOffset2)
    glVertex(x1-xOffset2, y1, z1-zOffset2)
    
    glVertex(x2-xOffset, y2, z2-zOffset)
    glVertex(x2+xOffset, y2, z2+zOffset)
    
    -- second rounding
    glVertex(x1+xOffset2, y1, z1+zOffset2)
    glVertex(x1-xOffset2, y1, z1-zOffset2)
	
    xOffset2 = xOffset / 3.22
    zOffset2 = zOffset / 3.22
	
    glVertex(x1_2-xOffset2, y1, z1_2-zOffset2)
    glVertex(x1_2+xOffset2, y1, z1_2+zOffset2)
end


local function DrawLineEndTex(x1,y1,z1, x2,y2,z2, width, texLength, texOffset)
	y1 = y2
	
	local distance			= diag(x2-x1, y2-y1, z2-z1)
	
	-- for 2nd rounding
	local distanceDivider = distance / (width/2.25)
	x1_2 = x2 - ((x1 - x2) / distanceDivider)
	z1_2 = z2 - ((z1 - z2) / distanceDivider)
	
	-- for first rounding
	local distanceDivider2 = distance / (width/4.13)
	x1 = x2 - ((x1 - x2) / distanceDivider2)
	z1 = z2 - ((z1 - z2) / distanceDivider2)
	
    local theta	= (x1~=x2) and atan((z2-z1)/(x2-x1)) or pi/2
    local zOffset = cos(pi-theta) * width / 2
    local xOffset = sin(pi-theta) * width / 2
    
    local xOffset2 = xOffset / 1.35
    local zOffset2 = zOffset / 1.35
	
	-- first rounding
	glTexCoord(0.2-texOffset,0)
    glVertex(x1+xOffset2, y1, z1+zOffset2)
	glTexCoord(0.2-texOffset,1)
    glVertex(x1-xOffset2, y1, z1-zOffset2)
    
	glTexCoord(0.55-texOffset,0.85)
    glVertex(x2-xOffset, y2, z2-zOffset)
	glTexCoord(0.55-texOffset,0.15)
    glVertex(x2+xOffset, y2, z2+zOffset)
    
    -- second rounding
	glTexCoord(0.8-texOffset,0.7)
    glVertex(x1+xOffset2, y1, z1+zOffset2)
	glTexCoord(0.8-texOffset,0.3)
    glVertex(x1-xOffset2, y1, z1-zOffset2)
	
    xOffset2 = xOffset / 3.22
    zOffset2 = zOffset / 3.22
	
	glTexCoord(0.55-texOffset,0.15)
    glVertex(x1_2-xOffset2, y1, z1_2-zOffset2)
	glTexCoord(0.55-texOffset,0.85)
    glVertex(x1_2+xOffset2, y1, z1_2+zOffset2)
end

local function DrawLine(x1,y1,z1, x2,y2,z2, width) -- long thin rectangle
	
    local theta	= (x1~=x2) and atan((z2-z1)/(x2-x1)) or pi/2
    local zOffset = cos(pi-theta) * width / 2
    local xOffset = sin(pi-theta) * width / 2
    
    glVertex(x1+xOffset, y1, z1+zOffset)
    glVertex(x1-xOffset, y1, z1-zOffset)
    
    glVertex(x2-xOffset, y2, z2-zOffset)
    glVertex(x2+xOffset, y2, z2+zOffset)
end

local function DrawLineTex(x1,y1,z1, x2,y2,z2, width, texLength, texOffset) -- long thin rectangle

	local distance			= diag(x2-x1, y2-y1, z2-z1)
	
    local theta	= (x1~=x2) and atan((z2-z1)/(x2-x1)) or pi/2
    local zOffset = cos(pi-theta) * width / 2
    local xOffset = sin(pi-theta) * width / 2
    
	glTexCoord(((distance/width)/texLength)+1-texOffset, 1)
    glVertex(x1+xOffset, y1, z1+zOffset)
	glTexCoord(((distance/width)/texLength)+1-texOffset, 0)
    glVertex(x1-xOffset, y1, z1-zOffset)
    
	glTexCoord(0-texOffset,0)
    glVertex(x2-xOffset, y2, z2-zOffset)
	glTexCoord(0-texOffset,1)
    glVertex(x2+xOffset, y2, z2+zOffset)
end

local function DrawGroundquad(x,y,z,size)
	glTexCoord(0,0)
	glVertex(x-size,y,z-size)
	glTexCoord(0,1)
	glVertex(x-size,y,z+size)
	glTexCoord(1,1)
	glVertex(x+size,y,z+size)
	glTexCoord(1,0)
	glVertex(x+size,y,z-size)
end

------------------------------------------------------------------------------------

function RemovePreviousCommand(unitID)
    if unitCommand[unitID] and commands[unitCommand[unitID]] then
        commands[unitCommand[unitID]].draw = false
    end
end

local unprocessedCommands = {}
local unprocessedCommandsNum = 0
function addUnitCommand(unitID, unitDefID, cmdID)
	-- record that a command was given (note: cmdID is not used, but useful to record for debugging)
	if unitID and (CONFIG[cmdID] or cmdID==CMD_INSERT or cmdID<0) then
		unprocessedCommandsNum = unprocessedCommandsNum + 1
		unprocessedCommands[unprocessedCommandsNum] = {ID=cmdID,time=os.clock(),unitID=unitID,draw=false,selected=spIsUnitSelected(unitID),udid=unitDefID} -- command queue is not updated until next gameframe
	end
end

local newUnitCommands = {}
function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, _, _)
	if enabledTeams[teamID] ~= nil then
		if teamID ~= GaiaTeamID or not string.find(UnitDefs[unitDefID].name, "critter_") then
			if ignoreUnits[unitDefID] == nil then
				if newUnitCommands[unitID] == nil then		-- only process the first in queue, else when super large queue order is given widget will hog memory and crash
					addUnitCommand(unitID, unitDefID, cmdID)
					newUnitCommands[unitID] = true
				else
					newUnitCommands[unitID] = {unitDefID, cmdID}
				end
			end
		end
	end
end

function ExtractTargetLocation(a,b,c,d,cmdID)
    -- input is first 4 parts of cmd.params table
    local x,y,z
    if c or d then
        if cmdID==CMD_RECLAIM and a >= MAX_UNITS and spValidFeatureID(a-MAX_UNITS) then --ugh, but needed
            x,y,z = spGetFeaturePosition(a-MAX_UNITS)        
        elseif cmdID==CMD_REPAIR and spValidUnitID(a) then
            x,y,z = spGetUnitPosition(a)
        else
            x=a
            y=b
            z=c
        end
    elseif a then
        if a >= MAX_UNITS then
            x,y,z = spGetFeaturePosition(a-MAX_UNITS)
        else
            x,y,z = spGetUnitPosition(a)     
        end
    end
    return x,y,z
end

function getCommandsQueue(unitID)
	local q = spGetUnitCommands(unitID, 35) or {} --limit to prevent mem leak, hax etc
	local our_q = {}
	local cmd
	for i=1, #q do
	  if CONFIG[q[i].id] or q[i].id < 0 then
		  if q[i].id < 0 then
			  q[i].buildingID = -q[i].id;
			  q[i].id = BUILD
			  if not q[i].params[4] then
				  q[i].params[4] = 0 --sometimes the facing param is missing (wtf)
			  end
		  end
		  our_q[#our_q+1] = q[i]
	  end
	end
	return our_q
end

local prevGameframe = 0
local sec = 0
local lastUpdate = 0
local sec2 = 0
local lastUpdate2 = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > lastUpdate + 0.1 then
		lastUpdate = sec
		
		-- process newly given commands (not done in widgetUnitCommand() because with huge build queue it eats memory and can crash lua)
		for unitID,v in pairs(newUnitCommands) do
			if v ~= true and ignoreUnits[v[1]] == nil then
				addUnitCommand(unitID, v[1], v[2])
			end
		end
		newUnitCommands = {}

		-- process new commands (cant be done directly because at widget:UnitCommand() the queue isnt updated yet)
		for k=1, #unprocessedCommands do
			if totalCommands <= maxTotalCommandCount then
				maxCommand = maxCommand + 1
				local i = maxCommand
				commands[i] = unprocessedCommands[k]
				totalCommands = totalCommands + 1

				RemovePreviousCommand(unprocessedCommands[k].unitID)
				unitCommand[unprocessedCommands[k].unitID] = i

				-- get pruned command queue
				local our_q = getCommandsQueue(unprocessedCommands[k].unitID)
				local qsize = #our_q
				commands[i].queue = our_q
				commands[i].queueSize = qsize
				if qsize > 1 then
					monitorCommands[i] = qsize
				end
				if qsize > 0 then
					commands[i].highlight = CONFIG[our_q[1].id].colour
					commands[i].draw = true
				end

				-- get location of final command
				local lastCmd = our_q[#our_q]
				if lastCmd and lastCmd.params then
					local x,y,z = ExtractTargetLocation(lastCmd.params[1],lastCmd.params[2],lastCmd.params[3],lastCmd.params[4],lastCmd.id)
					if x then
						commands[i].x = x
						commands[i].y = y
						commands[i].z = z
					end
				end
				commands[i].time = os.clock()
			end
		end
		unprocessedCommands = {}
		unprocessedCommandsNum = 0


		if sec2 > lastUpdate2 + 0.3 then
			lastUpdate2 = sec2
			if prevGameframe ~= Spring.GetGameFrame() then
				prevGameframe = Spring.GetGameFrame()
				-- update queue (in case unit has reached the nearest queue coordinate)
				local qsize
				for i=1, #monitorCommands do
					if commands[i] ~= nil then
						qsize = monitorCommands[i]
						if commands[i].draw == false then
							monitorCommands[i] = nil
						else
							local q = spGetUnitCommands(commands[i].unitID,35) or {}
							if qsize ~= #q then
								local our_q = getCommandsQueue(commands[i].unitID)
								commands[i].queue = our_q
								commands[i].queueSize = #our_q
								if qsize > 1 then
									monitorCommands[i] = qsize
								else
									monitorCommands[i] = nil
								end
							end
						end
					end
				end
			end
		end
	end
end


local function IsPointInView(x,y,z)
    if x and y and z then
        return spIsSphereInView(x,y,z,1) --better way of doing this?
    end
    return false
end


local prevTexOffset			= 0
local texOffset				= 0
local prevOsClock = os.clock()


function widget:DrawWorldPreUnit()
	drawFrame = drawFrame + 1

	if spIsGUIHidden() then return end

	osClock = os.clock()
	if drawLineTexture then
		texOffset = prevTexOffset - ((osClock - prevOsClock)*lineTextureSpeed)
		texOffset = texOffset - math.floor(texOffset)
		prevTexOffset = texOffset
	end
	prevOsClock = os.clock()

	gl.DepthTest(false)
	gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	local groundGlowCount = 0
	local commandCount = 0
	local newCommands = {}
	local newCommandsCount = 0

	--for i=1, #commands do
	for i, v in pairs(commands) do
		local progress = (osClock - commands[i].time) / duration
		local unitID = commands[i].unitID

		if progress >= 1 then
			-- remove when duration has passed
			--Spring.Echo("Removing " .. i)
			commands[i] = nil
			totalCommands = totalCommands - 1
			monitorCommands[i] = nil
			if unitCommand[unitID] == i then
				unitCommand[unitID] = nil
			end
		elseif commands[i].draw and (spIsUnitInView(unitID) or IsPointInView(commands[i].x,commands[i].y,commands[i].z)) then
			--newCommandsCount = newCommandsCount + 1
			--newCommands[newCommandsCount] = commands[i]
			--unitCommand[unitID] = newCommandsCount
			--if monitorCommands[i] then
			--	monitorCommands[newCommandsCount] = monitorCommands[i]
			--	if i ~= newCommandsCount then
			--		monitorCommands[i] = nil
			--	end
			--end

			local prevX, prevY, prevZ = spGetUnitPosition(unitID)

			-- draw set target command (TODO)
			--[[
			if prevX and commands[i].set_target and commands[i].set_target.params and commands[i].set_target.params[1] then
				local lineColour = CONFIG[CMD_SET_TARGET].colour
				local lineAlpha = opacity * lineColour[4] * (1-progress)
				glColor(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
				if commands[i].set_target.params[3] then
					glBeginEnd(GL_QUADS, DrawLine, prevX,prevY,prevZ, commands[i].set_target.params[1], commands[i].set_target.params[2], commands[i].set_target.params[3], lineWidth)
				else
					local x,y,z = spGetUnitPosition(commands[i].set_target.params[1])
					if x then
						glBeginEnd(GL_QUADS, DrawLine, prevX,prevY,prevZ, x,y,z, lineWidth)
					end
				end
			end
			]]

			-- draw command queue
			if commands[i].queueSize > 0 and prevX and commandCount < maxCommandCount then

				local lineAlphaMultiplier  = 1 - (progress / lineDuration)
				for j=1,commands[i].queueSize do
					local X,Y,Z = ExtractTargetLocation(commands[i].queue[j].params[1], commands[i].queue[j].params[2], commands[i].queue[j].params[3], commands[i].queue[j].params[4], commands[i].queue[j].id)
					local validCoord = X and Z and X>=0 and X<=mapX and Z>=0 and Z<=mapZ
					-- draw
					if X and validCoord then
						commandCount = commandCount + 1
						-- lines
						local usedLineWidth = lineWidth - (progress * (lineWidth - (lineWidth * lineWidthEnd)))
						local lineColour = CONFIG[commands[i].queue[j].id].colour
						local lineAlpha = opacity * lineOpacity * (lineColour[4] * 2) * lineAlphaMultiplier
						if lineAlpha > 0 then
							glColor(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
							if drawLineTexture then

								usedLineWidth = lineWidth - (progress * (lineWidth - (lineWidth * lineWidthEnd)))
								glTexture(lineImg)
								glBeginEnd(GL_QUADS, DrawLineTex, prevX,prevY,prevZ, X, Y, Z, usedLineWidth, lineTextureLength * (lineWidth / usedLineWidth), texOffset)
								glTexture(false)
							else
								glBeginEnd(GL_QUADS, DrawLine, prevX,prevY,prevZ, X, Y, Z, usedLineWidth)
							end
							-- ghost of build queue
							if drawBuildQueue and commands[i].queue[j].buildingID then
								glPushMatrix()
								glTranslate(X,Y+1,Z)
								glRotate(90 * commands[i].queue[j].params[4], 0, 1, 0)
								glUnitShape(commands[i].queue[j].buildingID, spGetMyTeamID(), true, false, false)
								glRotate(-90 * commands[i].queue[j].params[4], 0, 1, 0)
								glTranslate(-X,-Y-1,-Z)
								glPopMatrix()
							end
							if j == 1 and not drawLineTexture then
								-- draw startpoint rounding
								glColor(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
								glBeginEnd(GL_QUADS, DrawLineEnd, X, Y, Z, prevX,prevY,prevZ, usedLineWidth)
							end
						end
						if j==commands[i].queueSize then

							-- draw endpoint rounding
							if drawLineTexture == false and lineAlpha > 0 then
								if drawLineTexture then
									glTexture(lineImg)
									glColor(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
									glBeginEnd(GL_QUADS, DrawLineEndTex, prevX,prevY,prevZ, X, Y, Z, usedLineWidth, lineTextureLength, texOffset)
									glTexture(false)
								else
									glColor(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
									glBeginEnd(GL_QUADS, DrawLineEnd, prevX,prevY,prevZ, X, Y, Z, usedLineWidth)
								end
							end

							-- ground glow
							if groundGlow and groundGlowCount < maxGroundGlowCount then
								groundGlowCount = groundGlowCount + 1
								local size = (glowRadius * CONFIG[commands[i].queue[j].id].sizeMult) + ((glowRadius * CONFIG[commands[i].queue[j].id].endSize - glowRadius * CONFIG[commands[i].queue[j].id].sizeMult) * progress)
								local glowAlpha = (1 - progress) * glowOpacity * opacity

								if commands[i].selected then
									glowAlpha = glowAlpha * 1.5
								end
								glColor(lineColour[1],lineColour[2],lineColour[3],glowAlpha)
								glTexture(glowImg)
								glBeginEnd(GL_QUADS,DrawGroundquad,X,Y+3,Z,size)
								glTexture(false)
							end

						end
						prevX, prevY, prevZ = X, Y, Z
					end
				end
			end
		end
	end
	--commands = newCommands
	--maxCommand = #commands
	--newCommands = nil
    glColor(1,1,1,1)
end



function widget:DrawWorld()
  if spIsGUIHidden() then return end
    
	if drawUnitHighlightSkipFPS > 0 and spGetFPS() < drawUnitHighlightSkipFPS then return end
	
	-- highlight unit 
	if drawUnitHighlight then
		gl.DepthTest(true)
		gl.PolygonOffset(-2, -2)
		gl.Blending(GL_SRC_ALPHA, GL_ONE)
		local highlightUnitCounter = 0
		for i,_ in pairs(commands) do
			if commands[i].draw and commands[i].highlight and not spIsUnitIcon(commands[i].unitID) then
				local progress = (osClock - commands[i].time) / duration
				glColor(commands[i].highlight[1],commands[i].highlight[2],commands[i].highlight[3],0.08*(1-progress))
				glUnit(commands[i].unitID, true)
				highlightUnitCounter = highlightUnitCounter + 1
			end
			if highlightUnitCounter >= drawUnitHightlightMaxUnits then
				break
			end
		end
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		gl.PolygonOffset(false)
		gl.DepthTest(false)
	end
end


function widget:GetConfigData(data)
	savedTable = {}
	savedTable.opacity = opacity
	savedTable.filterAIteams = filterAIteams
	return savedTable
end

function widget:SetConfigData(data)
	if data.opacity ~= nil 	then  opacity	= data.opacity end
	if data.filterAIteams ~= nil 	then  filterAIteams	= data.filterAIteams end
end