function widget:GetInfo()
   return {
      name      = "Commands FX",
      desc      = "Shows commands given by allies",
      author    = "Floris, Bluestone",
      date      = "July 2014",
      license   = "GNU GPL, v2 or later",
      layer     = 2,
      enabled   = true,
   }
end

-- future:          hotkey to show all current cmds? (like current shift+space)
--                  handle set target

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

local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local MAX_UNITS = Game.maxUnits

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

--------------------------------------------------------------------------------

local commands = {}
local minCommand = 1 -- track lowest/highest entries that need to be processed
local minQueueCommand = 1
local maxCommand = 0

local unitCommand = {} -- most recent key in command table of order for unitID 
local setTarget = {} -- set targets of units
local osClock

local opacity       = 0.75		
local duration      = 1.25
local lineWidth	    = 6
local dotRadius     = 28		

local CONFIG = {  
    [CMD_ATTACK] = {
        sizeMult = 1.4,
        colour = {1.00, 0.20, 0.20, 0.30},
    },
    [CMD_CAPTURE] = {
        sizeMult = 1.4,
        colour = {1.00, 1.00, 0.30, 0.30},
    },
    [CMD_FIGHT] = {
        sizeMult = 1.2,
        colour = {0.30, 0.50, 1.00, 0.25}, 
    },
    [CMD_GUARD] = {
        sizeMult = 1,
        colour = {0.10, 0.10, 0.50, 0.25},
    },
    [CMD_LOAD_ONTO] = {
        sizeMult = 1,
        colour = {0.30, 1.00, 1.00 ,0.25},
    },
    [CMD_LOAD_UNITS] = {
        sizeMult = 1,
        colour = {0.30, 1.00, 1.00, 0.30},
    },
    [CMD_MANUALFIRE] = {
        sizeMult = 1.4,
        colour = {1.00, 0.00, 0.00, 0.30},
    },
    [CMD_MOVE] = {
        sizeMult = 1, 
        colour = {0.00, 1.00, 0.00, 0.25},
    },
    [CMD_PATROL] = {
        sizeMult = 1,
        colour = {0.10, 0.10, 1.00, 0.25},
    },
    [CMD_RECLAIM] = {
        sizeMult = 1,
        colour = {1.00, 0.20, 1.00, 0.4},
    },
    [CMD_REPAIR] = {
        sizeMult = 1,
        colour = {0.30, 1.00, 1.00, 0.4},
    },
    [CMD_RESTORE] = {
        sizeMult = 1,
        colour = {0.00, 0.50, 0.00, 0.25},
    },
    [CMD_RESURRECT] = {
        sizeMult = 1,
        colour = {0.20, 0.60, 1.00, 0.25},
    },
    --[[
    [CMD_SET_TARGET] = {
        sizeMult = 1,
        colour = {1.00 ,0.75 ,1.00 ,0.25},
    },
    ]]
    [CMD_UNLOAD_UNIT] = {
        sizeMult = 1,
        colour = {1.00, 1.00 ,0.00 ,0.25},
    },
    [CMD_UNLOAD_UNITS] = {
        sizeMult = 1,
        colour = {1.00, 1.00 ,0.00 ,0.25},
    },
    [BUILD] = {
        sizeMult = 1,
        colour = {0.00, 1.00 ,0.00 ,0.25},    
    }
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local pi = math.pi
local sin = math.sin
local cos = math.cos
local atan = math.atan 
local random = math.random

local circle = {}
local radstep = (2*pi) / 7
for j = 1,20 do
    circle[j] = {}
    local t = (j/20)*2*pi
    for i = 0,7 do
        circle[j][i] = {[1]=sin(i*radstep+t), [2]=cos(i*radstep+t)}
    end
end

local function DrawDot(size, r,g,b,a, x,y,z)
    -- replace with texture and colour overlay?
    gl.Color(r,g,b,a)
    gl.Vertex(x,y,z)
    gl.Color(r,g,b,0)
    local j = random(20)
    for i = 0,7 do
        gl.Vertex(x+circle[j][i][1]*size, y, z+circle[j][i][2]*size)
    end
end

local function DrawLine(x1,y1,z1, x2,y2,z2, width) -- long thin rectangle
    local theta	= atan((z2-z1)/(x2-x1))
    local zOffset = cos(pi-theta) * width / 2
    local xOffset = sin(pi-theta) * width / 2
    
    gl.Vertex(x1+xOffset, y1, z1+zOffset)
    gl.Vertex(x1-xOffset, y1, z1-zOffset)
    
    gl.Vertex(x2-xOffset, y2, z2-zOffset)
    gl.Vertex(x2+xOffset, y2, z2+zOffset)	
end

------------------------------------------------------------------------------------

function RemovePreviousCommand(unitID)
    if unitCommand[unitID] and commands[unitCommand[unitID]] then
        commands[unitCommand[unitID]].draw = false
    end
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, _, _)
    -- record that a command was given (note: cmdID is not used, but useful to record for debugging)
    if unitID and (CONFIG[cmdID] or cmdID==CMD_INSERT or cmdID<0) then
        local el = {ID=cmdID,time=os.clock(),unitID=unitID,draw=false} -- command queue is not updated until next gameframe
        maxCommand = maxCommand + 1
        --Spring.Echo("Adding " .. maxCommand)
        commands[maxCommand] = el
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

function widget:GameFrame()
    --Spring.Echo("GameFrame: minCommand " .. minCommand .. " minQueueCommand " .. minQueueCommand .. " maxCommand " .. maxCommand)
    local i = minQueueCommand
    while (i <= maxCommand) do
        --Spring.Echo("Processing " .. i) --debug
        
        local unitID = commands[i].unitID
        RemovePreviousCommand(unitID)
        unitCommand[unitID] = i

        -- get pruned command queue
        local q = spGetUnitCommands(commands[i].unitID,20) or {} --limit to prevent mem leak, hax etc
        local our_q = {}
        local gotHighlight = false
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
        
        commands[i].queue = our_q
        commands[i].queueSize = #our_q 
        if #our_q>0 then
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
        
        commands[i].processed = true
        
        minQueueCommand = minQueueCommand + 1
        i = i + 1
    end
end

local function IsPointInView(x,y,z)
    if x and y and z then
        return spIsSphereInView(x,y,z,1) --better way of doing this?
    end
    return false
end

function widget:DrawWorldPreUnit()
    --Spring.Echo(maxCommand-minCommand) --EXPENSIVE! often handling hundreds of command queues at once 
    if spIsGUIHidden() then return end
    
    osClock = os.clock()
    gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    gl.DepthTest(false)
        
    local i = minCommand
    while (i <= maxCommand) do --only draw commands that have already been processed in GameFrame
        
        local progress = (osClock - commands[i].time) / duration
        local unitID = commands[i].unitID
        
        if progress > 1 and commands[i].processed then
            -- remove when duration has passed (also need to check if it was processed yet, because of pausing)
            --Spring.Echo("Removing " .. i)
            commands[i] = nil
            minCommand = minCommand + 1
            
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
                    local x,y,z = Spring.GetUnitPosition(commands[i].set_target.params[1])    
                    if x then
                        gl.BeginEnd(GL.QUADS, DrawLine, prevX,prevY,prevZ, x,y,z, lineWidth)                     
                    end
                end                  
            end
            ]]
            -- draw command queue
            if commands[i].queueSize > 0 and prevX then
                for j=1,commands[i].queueSize do
                    --Spring.Echo(CMD[commands[i].queue[j].id]) --debug
                    local X,Y,Z = ExtractTargetLocation(commands[i].queue[j].params[1], commands[i].queue[j].params[2], commands[i].queue[j].params[3], commands[i].queue[j].params[4], commands[i].queue[j].id)                                
                    -- draw
                    if X then
                        -- lines
                        local lineColour = CONFIG[commands[i].queue[j].id].colour
                        local lineAlpha = opacity * lineColour[4] * (1-progress)
                        gl.Color(lineColour[1],lineColour[2],lineColour[3],lineAlpha)
                        gl.BeginEnd(GL.QUADS, DrawLine, prevX,prevY,prevZ, X, Y, Z, lineWidth)
                        if commands[i].queue[j].buildingID then
                            -- ghost of build queue
                            gl.PushMatrix()
                            gl.Translate(X,Y+1,Z)
                            gl.Rotate(90 * commands[i].queue[j].params[4], 0, 1, 0)
                            gl.UnitShape(commands[i].queue[j].buildingID, Spring.GetMyTeamID())
                            gl.Rotate(-90 * commands[i].queue[j].params[4], 0, 1, 0)
                            gl.Translate(-X,-Y-1,-Z)
                            gl.PopMatrix()
                        end
                        prevX, prevY, prevZ = X, Y, Z
                        -- dot 
                        if j==commands[i].queueSize and not spIsUnitIcon(unitID) and not spIsUnitSelected(unitID) then
                            local size = dotRadius * CONFIG[commands[i].queue[j].id].sizeMult
                            gl.BeginEnd(GL.TRIANGLE_FAN, DrawDot, size, lineColour[1],lineColour[2],lineColour[4],lineAlpha, X,Y,Z)
                        end
                    end
                end                            
            end
                                
        end
        
        i = i + 1
    end
    
    gl.Scale(1,1,1)
    gl.Color(1,1,1,1)
end

function widget:DrawWorld()
    if spIsGUIHidden() then return end

    -- highlight unit 
    gl.DepthTest(true)
    gl.PolygonOffset(-2, -2)
    gl.Blending(GL_SRC_ALPHA, GL_ONE)
    local i = minCommand
    while (i <= maxCommand) do
        if commands[i].draw and commands[i].highlight and not spIsUnitIcon(commands[i].unitID) then
            local progress = (osClock - commands[i].time) / duration
            gl.Color(commands[i].highlight[1],commands[i].highlight[2],commands[i].highlight[3],0.1*(1-progress))
            gl.Unit(commands[i].unitID, true)
        end
        i = i + 1
    end
    gl.Blending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    gl.PolygonOffset(false)
    gl.DepthTest(false)
end
