function gadget:GetInfo()
  return {
    name      = "Hacky Unreached Command workaround for 87",
    desc      = "Set smaller move goal for builder commands",
    author    = "Beherith",
    date      = "16 March 2012",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end


-- BEHE IS AWESOME:
-- SEND DOUBLE WAIT command to ALL cons that dont have an empty queu

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
    return
end
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
local CMD_RECLAIM = CMD.RECLAIM
local CMD_RESURRECT = CMD.RESURRECT
local CMD_REPAIR = CMD.REPAIR
local CMD_WAIT = CMD.WAIT
local CMD_MOVE = CMD.MOVE
local spValidUnitID = Spring.ValidUnitID
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitPosition = Spring.GetUnitPosition

local builders = {}
local numbuilders=0
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  if unitDefID and tonumber(UnitDefs[unitDefID].buildSpeed) and UnitDefs[unitDefID].buildSpeed > 0  and tonumber(UnitDefs[unitDefID].speed) and UnitDefs[unitDefID].speed>0 and not UnitDefs[unitDefID].canFly then
	--Spring.Echo(UnitDefs[unitDefID].name .. " added to table id:" .. tostring(unitID))
	local x,y,z=Spring.GetUnitPosition(unitID)
	local u={}
	table.insert(u, x)
	table.insert(u, y)
	table.insert(u, z)
	table.insert(u, 0)
	builders[unitID]=u

	numbuilders = numbuilders+1
  else
    --builders[unitID] = nil
	--Spring.Echo(UnitDefs[unitDefID].name .. " is not a builder")
  end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitDefID and tonumber(UnitDefs[unitDefID].buildSpeed) and UnitDefs[unitDefID].buildSpeed > 0  and tonumber(UnitDefs[unitDefID].speed) and UnitDefs[unitDefID].speed>0 and not UnitDefs[unitDefID].canFly then
		table.remove(builders, unitID)
		numbuilders = numbuilders-1
		--Spring.Echo(UnitDefs[unitDefID].name .. " removed from table")
	end
end

--buildDistance
function gadget:GameFrame(f)
	
	local framemod=f%37
	for unitID,b in pairs(builders) do
		if unitID%37 == framemod then -- only wait wait each unit every 37 frames, only if they actually have commands, this also staggers the command sending so it doesnt all happen in 1 frame
		
			if spValidUnitID(unitID) and spGetUnitCommands(unitID) and #spGetUnitCommands(unitID) >0 then 
				cmds=spGetUnitCommands(unitID)
				if spGetUnitHealth(unitID ) then
					_,_,_,_,buildProgress = spGetUnitHealth(unitID ) ---> nil | number health, number maxHealth, number paralyzeDamage, number captureProgress, number 
					if not spGetUnitIsBuilding(unitID) and buildProgress == 1.0 then
						local x,y,z = spGetUnitVelocity(unitID)
						spGiveOrderToUnit(unitID,CMD_WAIT,{},{})
						spGiveOrderToUnit(unitID,CMD_WAIT,{},{})
						--Spring.Echo("doublewait")
						if cmds[1].id<0 then --unit is moving to build something
							local x,y,z =spGetUnitPosition(unitID)
							if builders[unitID][4]%5==4 then --unit has been stationary while trying to build for 5 rounds
								--kick the unit perpendicular to its target vector about 24 elmos
								--builders[unitID][4]=0
								local tx=cmds[1].params[1]
								local tz=cmds[1].params[3]
								local vx=math.min(24,math.max(-24, tx-x))*(builders[unitID][4]/3.0)
								local vz=math.min(24,math.max(-24, tz-z))*(builders[unitID][4]/3.0)
								spGiveOrderToUnit(unitID,CMD.INSERT,{0,CMD_MOVE,0,x-vz,y,z+vx},{"alt"}) -- give them increasingly larger move orders
								--Spring.Echo("kicked unit" .. unitID .. " to:" .. vz.. " " .. vx .. " n=" .. builders[unitID][4])
								builders[unitID][4]=builders[unitID][4]+1
							else
								if (math.abs(x-builders[unitID][1])+math.abs(z-builders[unitID][3]))<12 then
									builders[unitID][4]=builders[unitID][4]+1
									--Spring.Echo("bitch" .. unitID .. " is stuck" .. builders[unitID][4])
								else
									builders[unitID][1]=x
									builders[unitID][2]=y
									builders[unitID][3]=z
									if builders[unitID][4]~=0 then
										--Spring.Echo("unit" .. unitID .. " was a bitch"..builders[unitID][4])
									end
									builders[unitID][4]=0
								end
							end
						
						end
					end
				end
				--case where unit is stuck:
				--has move command CMD[Spring.GetUnitCommands(unitID)[1].id] ==cmd.move
				--is finished Spring.GetUnitHealth
				--is builder 
				--has build command in queue AFTER move
				--
				--if command 1 is build, and is not building atm, and did not get closer to target since last check (
				-- if command 1 is build, save position! (4th param is counter since last change!)
			end
		end
		
	end
	
end

-- local function to_string(data, indent)
    -- local str = ""

    -- if(indent == nil) then
        -- indent = 0
    -- end

    -- -- Check the type
    -- if(type(data) == "string") then
        -- str = str .. (" "):rep(indent) .. data .. "\n"
    -- elseif(type(data) == "number") then
        -- str = str .. (" "):rep(indent) .. data .. "\n"
    -- elseif(type(data) == "boolean") then
        -- if(data == true) then
            -- str = str .. "true"
        -- else
            -- str = str .. "false"
        -- end
    -- elseif(type(data) == "table") then
        -- local i, v
        -- for i, v in pairs(data) do
            -- -- Check for a table in a table
            -- if(type(v) == "table") then
                -- str = str .. (" "):rep(indent) .. i .. ":\n"
                -- str = str .. to_string(v, indent + 2)
            -- else
		-- str = str .. (" "):rep(indent) .. i .. ": " ..to_string(v, 0)
	    -- end
        -- end
    -- elseif (data ==nil) then
		-- str=str..'nil'
	-- else
       -- -- print_debug(1, "Error: unknown data type: %s", type(data))
		-- --str=str.. "Error: unknown data type:" .. type(data)
		-- Spring.Echo(type(data) .. 'X data type')
    -- end

    -- return str
-- end