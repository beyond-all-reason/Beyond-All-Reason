local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Unit transportable nanos",
        desc      = "Prevent loading of ally nanos, prevent unloading onto cliffs and underwater",
        author    = "Beherith, Chronographer",
        date      = "Jul 2012",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spValidUnitID = Spring.ValidUnitID
local spGetGroundNormal = Spring.GetGroundNormal
local stringFind = string.find

local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS

local Nanos = {
	[UnitDefNames.cornanotc.id] = true,
	[UnitDefNames.armnanotc.id] = true,
}
if Spring.GetModOptions().experimentallegionfaction then
	Nanos[UnitDefNames.legnanotc.id] = true
end
for udid, ud in pairs(UnitDefs) do
    for id in pairs(Nanos) do
        if stringFind(ud.name, UnitDefs[id].name, 1, true) then
            Nanos[udid] = true
            break
        end
    end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_LOAD_UNITS)
	gadgetHandler:RegisterAllowCommand(CMD_UNLOAD_UNITS)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if not UnitDefs[unitDefID].isTransport then
		return false
	end
	
	if cmdID == CMD_LOAD_UNITS then
		if #cmdParams == 1 then -- if unit is target
			local targetId = cmdParams[1]
			local isvalidId = spValidUnitID(targetId)
			local isTeamTarget = isvalidId and spGetUnitTeam(targetId) == teamID
			local isEnemyTarget = isvalidId and spGetUnitAllyTeam(targetId) ~= spGetUnitAllyTeam(unitID)
			if isvalidId and not isEnemyTarget and not isTeamTarget and Nanos[spGetUnitDefID(targetId)] then
				return false
			end
		end
	else	 -- CMD_UNLOAD_UNITS
		if cmdParams[1] and cmdParams[3] and spGetUnitIsTransporting(unitID) then
			local intrans = spGetUnitIsTransporting(unitID)
			if #intrans >= 1 then
				-- no unloading underwater
				local _,y,_ = spGetGroundNormal(cmdParams[1], cmdParams[3])
				if Nanos[spGetUnitDefID(intrans[1])] and (cmdParams[2] < 0 or y < 0.9) then
					return false
				end
			end
		end
	end
    return true
end
