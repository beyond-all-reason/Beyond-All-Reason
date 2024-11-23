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
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
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
  [UnitDefNames.corvalk.id] = true,
  [UnitDefNames.corseah.id] = true,
  [UnitDefNames.armatlas.id] = true,
  [UnitDefNames.armdfly.id] = true,
  [UnitDefNames.armthovr.id] = true,
}
local Nanos = {
	[UnitDefNames.cornanotc.id] = true,
	[UnitDefNames.armnanotc.id] = true,
}
for udid, ud in pairs(UnitDefs) do
    for id, v in pairs(AirTrans) do
        if string.find(ud.name, UnitDefs[id].name) then
            AirTrans[udid] = v
        end
    end
    for id, v in pairs(Nanos) do
        if string.find(ud.name, UnitDefs[id].name) then
            Nanos[udid] = v
        end
    end
end

local watchList = {}

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_LOAD_UNITS)
	gadgetHandler:RegisterAllowCommand(CMD_UNLOAD_UNITS)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD_LOAD_UNITS then
		if #cmdParams==1 then -- if unit is target
			if ValidUnitID(cmdParams[1]) and GetUnitTeam(cmdParams[1]) ~= teamID and Nanos[GetUnitDefID(cmdParams[1])] then
				return false
			end
		end
		--if Spring.ValidUnit(cmdParams[1]) then
		--end
	else -- CMD_UNLOAD_UNITS
		if GetUnitIsTransporting(unitID) then
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
