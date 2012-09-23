--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "unit stuck in lab fix",
    desc      = "units getting stuck in lab if they are given a build command they cannot fulfil fix",
    author    = "beherith",
    date      = "2012 sept",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local GetUnitCommands = Spring.GetUnitCommands

local badfactories={
  [UnitDefNames["corsy"].id] = true,
  [UnitDefNames["corasy"].id] = true,
  [UnitDefNames["corfhp"].id] = true,
  [UnitDefNames["csubpen"].id] = true,
  [UnitDefNames["armsy"].id] = true,
  [UnitDefNames["armasy"].id] = true,
  [UnitDefNames["armfhp"].id] = true,
  [UnitDefNames["asubpen"].id] = true,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID<0 then
		if UnitDefs[unitDefID]["buildOptions"] and #UnitDefs[unitDefID]["buildOptions"] >0 then
			for i,v in pairs(UnitDefs[unitDefID]["buildOptions"]) do
				if v==-1*cmdID then
					--Spring.Echo('yep, we can do that')
					return true
				end
			end
			return false
		else
			--Spring.Echo(UnitDefs[unitDefID]['name'],' cant build a', UnitDefs[-1*cmdID]['name'])
			return false
		end
	end
    return true
end

function gadget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	--Spring.Echo('UnitFromFactorycommands:',to_string(Spring.GetUnitCommands(unitID)))
			
	if userOrders then
		local cmd=Spring.GetUnitCommands(unitID)
		if cmd and #cmd==1 and cmd[1]['id']==CMD.SET_WANTED_MAX_SPEED then -- =70
			local factcmd=Spring.GetUnitCommands(factID)
			--Spring.Echo('UnitFromFactorycommands:',to_string(Spring.GetUnitCommands(unitID)))
			--Spring.Echo('Factorycommands:',to_string(factcmd))
			--Spring.Echo('FactorycmdID:',factcmd[1]['id'])
			
			local newcmd={}
			--Spring.Echo('newcmd',to_string(newcmd),factcmd)
			if #factcmd >0 then
				for k,v in pairs(factcmd) do
					--Spring.Echo('k,v',to_string(k),to_string(v))
					newcmd[k]={v['id'],v['params'],v['options']['coded']}
					--Spring.Echo('newcmd2',to_string(newcmd[k]))
				end
			else
				local x,y,z = Spring.GetUnitPosition(factID)
				local f=Spring.GetUnitBuildFacing(factID)
				if f==0 then
					z=z+96
				elseif f==1 then
					x=x+96
				elseif f==2 then
					z=z-96
				else
					x=x-96
				end
				y=Spring.GetGroundHeight(x,z)
				newcmd[1]={10,{x,y,z},16} --CMD.MOVE, pos ,16
				--Spring.Echo('facing',f)
			end
			--Spring.Echo('Unit unstuck from lab')
			Spring.GiveOrderArrayToUnitArray({unitID},newcmd)
		end
	else
		if badfactories[factDefID] and #Spring.GetUnitCommands(factID)==0 then
			local x,y,z = Spring.GetUnitPosition(factID)
				local f=Spring.GetUnitBuildFacing(factID)
				if f==0 then
					z=z+96
				elseif f==1 then
					x=x+96
				elseif f==2 then
					z=z-96
				else
					x=x-96
				end
				y=Spring.GetGroundHeight(x,z)
				local newcmd={{10,{x,y,z},16}} --CMD.MOVE, pos ,16
				Spring.GiveOrderArrayToUnitArray({unitID},newcmd)
		end
	end
end
function to_string(data, indent)
    local str = ""

    if(indent == nil) then
        indent = 0
    end

    -- Check the type
    if(type(data) == "string") then
        str = str .. (" "):rep(indent) .. data .. "\n"
    elseif(type(data) == "number") then
        str = str .. (" "):rep(indent) .. data .. "\n"
    elseif(type(data) == "boolean") then
        if(data == true) then
            str = str .. "true\n"
        else
            str = str .. "false\n"
        end
    elseif(type(data) == "table") then
        local i, v
        for i, v in pairs(data) do
            -- Check for a table in a table
            if(type(v) == "table") then
                str = str .. (" "):rep(indent) .. i .. ":\n"
                str = str .. to_string(v, indent + 2)
            else
		str = str .. (" "):rep(indent) .. i .. ": " ..to_string(v, 0)
	    end
        end
    elseif (data ==nil) then
		str=str..'nil'
	else
       -- print_debug(1, "Error: unknown data type: %s", type(data))
		--str=str.. "Error: unknown data type:" .. type(data)
		Spring.Echo(type(data) .. 'X data type')
    end

    return str
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------