--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Unit transportable nanos",
    desc      = "Prevent loading of ally and enemy nanos, prevent unloading onto cliffs and underwater",
    author    = "Beherith",
    date      = "Jul 2012",
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

local GetCommandQueue = Spring.GetCommandQueue
local GetUnitTeam = Spring.GetUnitTeam
local GetUnitDefID = Spring.GetUnitDefID
local GetGroundNormal = Spring.GetGroundNormal
local GetUnitIsTransporting = Spring.GetUnitIsTransporting

local ValidUnitID = Spring.ValidUnitID
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_INSERT = CMD.INSERT
local CMD_MOVE = CMD.MOVE
local CMD_REMOVE = CMD.REMOVE

--------------------------------------------------------------------------------
--WHAT THIS DOES:
--Nanos are now transportable (7.69)
--No unloading underwater from airtrans.
--No loading of allied or enemy nanos
--No unloading nanos on cliffs
--also do for AREA LOAD!
--------------------------------------------------------------------------------
local AirTrans = {
  [UnitDefNames["corvalk"].id] = true,
  [UnitDefNames["armsl"].id] = true,
  [UnitDefNames["armatlas"].id] = true,
  [UnitDefNames["armdfly"].id] = true,
}
local Nanos={
	[UnitDefNames["cornanotc"].id] = true,
	[UnitDefNames["armnanotc"].id] = true,
}
local watchList = {}

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
 -- if synced then return true end
	if (cmdID == CMD_LOAD_UNITS) then
		--Spring.Echo('Load','unitID',unitID, 'unitDefID', unitDefID, 'teamID', teamID, 'cmdID', cmdID, 'cmdParams',to_string(cmdParams), 'cmdOptions',to_string(cmdOptions), 'cmdTag',cmdTag, 'synced',synced)
		if #cmdParams==1 then -- if unit is target
			if (ValidUnitID(cmdParams[1]) and GetUnitTeam(cmdParams[1]) ~= teamID and Nanos[GetUnitDefID(cmdParams[1])]) then
				return false
			end
		end
		--if Spring.ValidUnit(cmdParams[1]) then
		--end
	end
	if (cmdID == CMD_UNLOAD_UNITS) then
		--Spring.Echo('Unload','unitID',unitID, 'unitDefID', unitDefID, 'teamID', teamID, 'cmdID', cmdID, 'cmdParams',to_string(cmdParams), 'cmdOptions',cmdOptions, 'cmdTag',cmdTag, 'synced',synced)
		if (GetUnitIsTransporting(unitID)) then
			local intrans=GetUnitIsTransporting(unitID)
			if #intrans>=1 then
				--for i=1,#intrans do
					--Spring.Echo(unitID,'is transporting',UnitDefs[Spring.GetUnitDefID(intrans[i])]['name'])
				--end
				local x,y,z=GetGroundNormal(cmdParams[1],cmdParams[3])
				if Nanos[GetUnitDefID(intrans[1])] and (cmdParams[2]<0 or y<0.9) then
					return false
				end
			end
		end
	end
  return true
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
            str = str .. "true"
        else
            str = str .. "false"
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