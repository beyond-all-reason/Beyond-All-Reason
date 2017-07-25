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

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local drawBuildQueue			= true
local drawLineTexture			= true
local drawUnitHighlight 		= true
local drawUnitHighlightSkipFPS	= 8  -- (0 to disable) skip drawing when framerate gets below this value

local opacity      				= 1
local duration     				= 2.6

local lineWidth	   				= 7.8
local lineOpacity				= 0.75
local lineDuration 				= 1		-- set a value <= 1
local lineWidthEnd				= 0.85		-- multiplier
local lineTextureLength 		= 4
local lineTextureSpeed  		= 2.4

local groundGlow					= true
local glowRadius    			= 26
local glowDuration  			= 0.5
local glowOpacity   			= 0.11

-- limit amount of effects to keep performance sane
local maxCommandCount			= 400
local maxGroundGlowCount  = 50
local drawUnitHightlightMaxUnits = 50

local glowImg			= ":n:"..LUAUI_DIRNAME.."Images/commandsfx/glow.dds"
local lineImg			= ":n:"..LUAUI_DIRNAME.."Images/commandsfx/line2.dds"


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

local commands = {}
local monitorCommands = {}
local minQueueCommand = 1
local maxCommand = 0

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

function widget:Initialize()
	--SetUnitConf()
	
	--spLoadCmdColorsConfig('useQueueIcons  0 ')
	spLoadCmdColorsConfig('queueIconScale  0.66 ')
	spLoadCmdColorsConfig('queueIconAlpha  0.5 ')
	
	setCmdLineColors(0.5)
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
    gl.Vertex(x1+xOffset2, y1, z1+zOffset2)
    gl.Vertex(x1-xOffset2, y1, z1-zOffset2)
    
    gl.Vertex(x2-xOffset, y2, z2-zOffset)
    gl.Vertex(x2+xOffset, y2, z2+zOffset)
    
    -- second rounding
    gl.Vertex(x1+xOffset2, y1, z1+zOffset2)
    gl.Vertex(x1-xOffset2, y1, z1-zOffset2)
	
    xOffset2 = xOffset / 3.22
    zOffset2 = zOffset / 3.22
	
    gl.Vertex(x1_2-xOffset2, y1, z1_2-zOffset2)
    gl.Vertex(x1_2+xOffset2, y1, z1_2+zOffset2)
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
	gl.TexCoord(0.2-texOffset,0)
    gl.Vertex(x1+xOffset2, y1, z1+zOffset2)
	gl.TexCoord(0.2-texOffset,1)
    gl.Vertex(x1-xOffset2, y1, z1-zOffset2)
    
	gl.TexCoord(0.55-texOffset,0.85)
    gl.Vertex(x2-xOffset, y2, z2-zOffset)
	gl.TexCoord(0.55-texOffset,0.15)
    gl.Vertex(x2+xOffset, y2, z2+zOffset)
    
    -- second rounding
	gl.TexCoord(0.8-texOffset,0.7)
    gl.Vertex(x1+xOffset2, y1, z1+zOffset2)
	gl.TexCoord(0.8-texOffset,0.3)
    gl.Vertex(x1-xOffset2, y1, z1-zOffset2)
	
    xOffset2 = xOffset / 3.22
    zOffset2 = zOffset / 3.22
	
	gl.TexCoord(0.55-texOffset,0.15)
    gl.Vertex(x1_2-xOffset2, y1, z1_2-zOffset2)
	gl.TexCoord(0.55-texOffset,0.85)
    gl.Vertex(x1_2+xOffset2, y1, z1_2+zOffset2)
end

local function DrawLine(x1,y1,z1, x2,y2,z2, width) -- long thin rectangle
	
    local theta	= (x1~=x2) and atan((z2-z1)/(x2-x1)) or pi/2
    local zOffset = cos(pi-theta) * width / 2
    local xOffset = sin(pi-theta) * width / 2
    
    gl.Vertex(x1+xOffset, y1, z1+zOffset)
    gl.Vertex(x1-xOffset, y1, z1-zOffset)
    
    gl.Vertex(x2-xOffset, y2, z2-zOffset)
    gl.Vertex(x2+xOffset, y2, z2+zOffset)
end

local function DrawLineTex(x1,y1,z1, x2,y2,z2, width, texLength, texOffset) -- long thin rectangle

	local distance			= diag(x2-x1, y2-y1, z2-z1)
	
    local theta	= (x1~=x2) and atan((z2-z1)/(x2-x1)) or pi/2
    local zOffset = cos(pi-theta) * width / 2
    local xOffset = sin(pi-theta) * width / 2
    
	gl.TexCoord(((distance/width)/texLength)+1-texOffset, 1)
    gl.Vertex(x1+xOffset, y1, z1+zOffset)
	gl.TexCoord(((distance/width)/texLength)+1-texOffset, 0)
    gl.Vertex(x1-xOffset, y1, z1-zOffset)
    
	gl.TexCoord(0-texOffset,0)
    gl.Vertex(x2-xOffset, y2, z2-zOffset)
	gl.TexCoord(0-texOffset,1)
    gl.Vertex(x2+xOffset, y2, z2+zOffset)
end

local function DrawGroundquad(x,y,z,size)
	gl.TexCoord(0,0)
	gl.Vertex(x-size,y,z-size)
	gl.TexCoord(0,1)
	gl.Vertex(x-size,y,z+size)
	gl.TexCoord(1,1)
	gl.Vertex(x+size,y,z+size)
	gl.TexCoord(1,0)
	gl.Vertex(x+size,y,z-size)
end

------------------------------------------------------------------------------------

function RemovePreviousCommand(unitID)
    if unitCommand[unitID] and commands[unitCommand[unitID]] then
        commands[unitCommand[unitID]].draw = false
    end
end

function addUnitCommand(unitID, unitDefID, cmdID)
  -- record that a command was given (note: cmdID is not used, but useful to record for debugging)
  if string.sub(UnitDefs[unitDefID].name, 1, 7) == "critter" then return end
  if unitID and (CONFIG[cmdID] or cmdID==CMD_INSERT or cmdID<0) then
    maxCommand = maxCommand + 1
    commands[maxCommand] = {ID=cmdID,time=os.clock(),unitID=unitID,draw=false,selected=spIsUnitSelected(unitID),udid=unitDefID} -- command queue is not updated until next gameframe
  end
end

local newUnitCommands = {}
function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, _, _)
	if newUnitCommands[unitID] == nil then		-- only process the first in queue, else when super large queue order is given widget will hog memory and crash
    	addUnitCommand(unitID, unitDefID, cmdID)
    	newUnitCommands[unitID] = true
    else
		newUnitCommands[unitID] = {unitDefID, cmdID}
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
	for _,cmd in ipairs(q) do
	  if CONFIG[cmd.id] or cmd.id < 0 then
		  if cmd.id < 0 then
			  cmd.buildingID = -cmd.id;
			  cmd.id = BUILD
			  if not cmd.params[4] then
				  cmd.params[4] = 0 --sometimes the facing param is missing (wtf)
			  end
		  end
		  our_q[#our_q+1] = cmd
	  end
	end
	return our_q
end


local sec = 0
local lastUpdate = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > lastUpdate + 0.2 then
		lastUpdate = sec
		
		-- process newly given commands (not done in widgetUnitCommand() because with huge build queue it eats memory and can crash lua)
		for i, v in pairs(newUnitCommands) do
			if v ~= true then
				addUnitCommand(i, v[1], v[2])
			end
		end
		newUnitCommands = {}
  
		-- update queue (in case unit has reached the nearest queue coordinate)
	  for i, qsize in pairs(monitorCommands) do
	    if commands[i] ~= nil then
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


function widget:GameFrame(gameFrame)

  if drawFrame == gameframeDrawFrame then 
  	return
  end
	gameframeDrawFrame = drawFrame
	
	-- process new commands (cant be done directly because at widget:UnitCommand() the queue isnt updated yet)
  for i, v in pairs(commands) do
    if v.processed ~= true then
    
	    RemovePreviousCommand(v.unitID)
	    unitCommand[v.unitID] = i

	    -- get pruned command queue
	    local our_q = getCommandsQueue(v.unitID)
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
	    commands[i].processed = true
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
	  gl.DepthTest(false)
	  gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		if drawLineTexture then
			texOffset = prevTexOffset - ((osClock - prevOsClock)*lineTextureSpeed)
			texOffset = texOffset - math.floor(texOffset)
			prevTexOffset = texOffset
	  end
		prevOsClock = os.clock()
		
		local groundGlowCount = 0
		local commandCount = 0
    for i, v in pairs(commands) do
        local progress = (osClock - commands[i].time) / duration
        local unitID = commands[i].unitID
        
        if progress >= 1 and commands[i].processed then
            -- remove when duration has passed (also need to check if it was processed yet, because of pausing)
            --Spring.Echo("Removing " .. i)
            commands[i] = nil
            monitorCommands[i] = nil
            if unitCommand[unitID] == i then 
            	unitCommand[unitID] = nil
            end
        elseif commands[i].draw and (spIsUnitInView(unitID) or IsPointInView(commands[i].x,commands[i].y,commands[i].z)) then 				
            local prevX, prevY, prevZ = spGetUnitPosition(unitID)
            
            -- draw set target command (TODO)
            --[[
            if prevX and commands[i].set_target and commands[i].set_target.params and commands[i].set_target.params[1] then
                local lineColour = CONFIG[CMD_SET_TARGET].colour
                local lineAlpha = opacity * lineColour[4] * (1-progress)
                gl.Color(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
                if commands[i].set_target.params[3] then
                    gl.BeginEnd(GL.QUADS, DrawLine, prevX,prevY,prevZ, commands[i].set_target.params[1], commands[i].set_target.params[2], commands[i].set_target.params[3], lineWidth) 
                else
                    local x,y,z = spGetUnitPosition(commands[i].set_target.params[1])    
                    if x then
                        gl.BeginEnd(GL.QUADS, DrawLine, prevX,prevY,prevZ, x,y,z, lineWidth)
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
														gl.Color(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
														if drawLineTexture then
															
							                usedLineWidth = lineWidth - (progress * (lineWidth - (lineWidth * lineWidthEnd)))
															gl.Texture(lineImg)
															gl.BeginEnd(GL.QUADS, DrawLineTex, prevX,prevY,prevZ, X, Y, Z, usedLineWidth, lineTextureLength * (lineWidth / usedLineWidth), texOffset)
															gl.Texture(false)
														else
															gl.BeginEnd(GL.QUADS, DrawLine, prevX,prevY,prevZ, X, Y, Z, usedLineWidth)
														end
														-- ghost of build queue
														if drawBuildQueue and commands[i].queue[j].buildingID then
															gl.PushMatrix()
															gl.Translate(X,Y+1,Z)
															gl.Rotate(90 * commands[i].queue[j].params[4], 0, 1, 0)
															gl.UnitShape(commands[i].queue[j].buildingID, spGetMyTeamID(), true, false, false)
															gl.Rotate(-90 * commands[i].queue[j].params[4], 0, 1, 0)
															gl.Translate(-X,-Y-1,-Z)
															gl.PopMatrix()
														end
														if j == 1 and not drawLineTexture then
															-- draw startpoint rounding
															gl.Color(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
															gl.BeginEnd(GL.QUADS, DrawLineEnd, X, Y, Z, prevX,prevY,prevZ, usedLineWidth)
														end
												end
		                    if j==commands[i].queueSize then
									
														-- draw endpoint rounding
														if drawLineTexture == false and lineAlpha > 0 then 
															if drawLineTexture then
																gl.Texture(lineImg)
																gl.Color(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
																gl.BeginEnd(GL.QUADS, DrawLineEndTex, prevX,prevY,prevZ, X, Y, Z, usedLineWidth, lineTextureLength, texOffset)
																gl.Texture(false)
															else
																gl.Color(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
																gl.BeginEnd(GL.QUADS, DrawLineEnd, prevX,prevY,prevZ, X, Y, Z, usedLineWidth)
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
															gl.Color(lineColour[1],lineColour[2],lineColour[3],glowAlpha)
															gl.Texture(glowImg)
															gl.BeginEnd(GL.QUADS,DrawGroundquad,X,Y+3,Z,size)
															gl.Texture(false)
														end
									
                        end
                        prevX, prevY, prevZ = X, Y, Z
                    end
                end                            
            end
        end
    end
    gl.Scale(1,1,1)
    gl.Color(1,1,1,1)
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
		for i, v in pairs(commands) do
			if commands[i].draw and commands[i].highlight and not spIsUnitIcon(commands[i].unitID) then
				local progress = (osClock - commands[i].time) / duration
				gl.Color(commands[i].highlight[1],commands[i].highlight[2],commands[i].highlight[3],0.08*(1-progress))
				gl.Unit(commands[i].unitID, true)
			end
			highlightUnitCounter = highlightUnitCounter + 1
			if highlightUnitCounter <= drawUnitHightlightMaxUnits then
				break
			end
		end
		gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		gl.PolygonOffset(false)
		gl.DepthTest(false)
	end
end