local gadget = gadget ---@type Gadget

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

local GetUnitTeam = Spring.GetUnitTeam
local GetUnitDefID = Spring.GetUnitDefID
local GetGroundNormal = Spring.GetGroundNormal
local GetUnitIsTransporting = Spring.GetUnitIsTransporting

local ValidUnitID = Spring.ValidUnitID
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
    for id, v in pairs(Nanos) do
        if string.find(ud.name, UnitDefs[id].name) then
            Nanos[udid] = v
        end
    end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_LOAD_UNITS)
	gadgetHandler:RegisterAllowCommand(CMD_UNLOAD_UNITS)
end

local CMD_INSERT = CMD.INSERT
local params = {}

local function fromInsert(cmdParams)
	local p = params
	p[1], p[2], p[3], p[4], p[5] = cmdParams[4], cmdParams[5], cmdParams[6], cmdParams[7], cmdParams[8]
	return cmdParams[2], p
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD_INSERT then
		cmdID, cmdParams = fromInsert(cmdParams)
	end

	if cmdID == CMD_LOAD_UNITS then
		if #cmdParams == 1 then -- if unit is target
			if ValidUnitID(cmdParams[1]) and GetUnitTeam(cmdParams[1]) ~= teamID and Nanos[GetUnitDefID(cmdParams[1])] then
				return false
			end
		end
	else	 -- CMD_UNLOAD_UNITS
		if GetUnitIsTransporting(unitID) then
			local intrans = GetUnitIsTransporting(unitID)
			if #intrans >= 1 then
				-- no unloading underwater
				local _,y,_ = GetGroundNormal(cmdParams[1], cmdParams[3])
				if Nanos[GetUnitDefID(intrans[1])] and (cmdParams[2] < 0 or y < 0.9) then
					return false
				end
			end
		end
	end
    return true
end
