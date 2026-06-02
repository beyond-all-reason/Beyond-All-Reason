-- Temporary gadget to test if zoom level can be used to determine whether to
-- use formation click drag (zoomed out) or area guard (zoomed in). If this works well, 
-- we can expand this to other commands like repair area.

local function tableToString(tbl, indent)
    if type(tbl) ~= "table" then return tostring(tbl) end
    indent = indent or 0
    local toprint = string.rep(" ", indent) .. "{\n"
    indent = indent + 2
    for k, v in pairs(tbl) do
        toprint = toprint .. string.rep(" ", indent)
        toprint = toprint .. tostring(k) .. " = "
        if type(v) == "table" then
            toprint = toprint .. tableToString(v, indent + 2) .. ",\n"
        else
            toprint = toprint .. tostring(v) .. ",\n"
        end
    end
    toprint = toprint .. string.rep(" ", indent - 2) .. "}"
    return toprint
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Test gadget command",
		desc	= 'Testing a new custom command',
		author	= 'uBdead',
		date	= 'May 2026',
		license	= 'GNU GPL, v2 or later',
		layer	= 0,
		enabled	= true
	}
end

--------------------------------
-- SYNCED/UNSYNCED
--------------------------------
local CMD_AREA_GUARD = GameCMD.AREA_GUARD
local CMD_GUARD = CMD.GUARD

local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spGetCameraState = Spring.GetCameraState

local canGuardDefs = {}
local ignoreUnits = {}
local areaGuardCmdDesc = {
    id = CMD_AREA_GUARD,
    type = CMDTYPE.ICON_UNIT_OR_AREA,
    name = 'Guard!',
    action = 'areaguard',
    cursor = 'Guard',
    tooltip = 'Guard a unit or area.\nDrag to issue multiple guard orders in an area.',
    hidden = false,
}

for unitDefID, unitDef in pairs(UnitDefs) do
        if unitDef.canGuard then
                canGuardDefs[unitDefID] = true
        end
        if unitDef.modCategories and unitDef.modCategories['object']
            or (unitDef.customParams and unitDef.customParams.objectify) then 
        ignoreUnits[unitDefID] = true
    end
end  

local function replaceGuardCommand(unitID)
		-- If we've already inserted our AREA_GUARD button, skip
		if spFindUnitCmdDesc(unitID, CMD_AREA_GUARD) then
			return
		end

		local guardIndex = spFindUnitCmdDesc(unitID, CMD_GUARD)
		if not guardIndex then
			return
		end

		-- Remove engine GUARD button and insert our AREA_GUARD in its place
		-- spRemoveUnitCmdDesc(unitID, guardIndex)
		spInsertUnitCmdDesc(unitID, guardIndex, areaGuardCmdDesc)
	end

------------------------------------
if gadgetHandler:IsSyncedCode() then
    --------------------------------
    -- SYNCED
    --------------------------------

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_AREA_GUARD)
		gadgetHandler:RegisterAllowCommand(CMD_AREA_GUARD)
		gadgetHandler:RegisterAllowCommand(CMD_GUARD)

		-- Replace guard button on existing units
		local allUnits = spGetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			local unitDefID = spGetUnitDefID(unitID)
			if canGuardDefs[unitDefID] then
				replaceGuardCommand(unitID)
			end
		end
	end

    function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
        if cmdID == CMD_AREA_GUARD then
            Spring.Echo("Received AREA_GUARD command for unitID", unitID, "with params", cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4])
            -- Here you would implement the logic to handle the AREA_GUARD command, such as issuing guard orders to units in the specified area.
            return true -- Allow the command to be processed
        end
        return true -- Allow other commands
    end

    function gadget:UnitFinished(unitID, unitDefID, unitTeam)
        if canGuardDefs[unitDefID] then
            replaceGuardCommand(unitID)
        end
    end

    -- Handle transfer of units between teams (capture/share)
    function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
        if canGuardDefs[unitDefID] then
            replaceGuardCommand(unitID)
        end
    end

    function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
        if canGuardDefs[unitDefID] then
            replaceGuardCommand(unitID)
        end
    end

    --------------------------------
    return
else
    --------------------------------
    -- UNSYNCED
    --------------------------------
    local spSetCustomCommandDrawData = Spring.SetCustomCommandDrawData

	function gadget:Initialize()
		spSetCustomCommandDrawData(CMD_AREA_GUARD, "Guard", { 136/255, 251/255, 255, 0.7 }, true)
	end

    local last = false
	function gadget:DefaultCommand(type, id, defaultCmd)
        -- get the current zoom level
        local cam = spGetCameraState()
		if defaultCmd == CMD_GUARD and cam.dist < 3500 then
            if last ~= true then
                Spring.Echo("DefaultCommand: Replacing GUARD with AREA_GUARD due to zoom level", cam.dist)
            end
            last = true
			return CMD_AREA_GUARD
		end

        if last ~= false then
            Spring.Echo("DefaultCommand: Reverting to GUARD due to zoom level", cam.dist)
        end
        last = false
    
        return nil
	end
end
