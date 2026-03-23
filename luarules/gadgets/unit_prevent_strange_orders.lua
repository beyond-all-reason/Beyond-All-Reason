local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Strange Orders",
		desc = "There's no reason to need to insert a remove command (if even possible)",
		author = "TheFatController",
		date = "Aug 31, 2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Pre-compute which unitDefs have which build options for fast lookup
local canBuildDef = {} -- [builderDefID][buildDefID] = true
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.buildOptions then
		for _, optDefID in ipairs(unitDef.buildOptions) do
			if not canBuildDef[unitDefID] then
				canBuildDef[unitDefID] = {}
			end
			canBuildDef[unitDefID][optDefID] = true
		end
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.INSERT)
	gadgetHandler:RegisterAllowCommand(CMD.REMOVE)
	gadgetHandler:RegisterAllowCommand(CMD.BUILD)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
	if cmdID == CMD.INSERT or cmdID == CMD.REMOVE then
		return fromInsert == nil
	end

	-- Build command (cmdID < 0) coming from CMD.INSERT: reject if the unit
	-- doesn't have this in its buildOptions. Prevents immobile assist turrets
	-- (nanotc) from getting stuck with an unexecutable build command at the
	-- front of their queue, permanently blocking fight/patrol behind it.
	if cmdID < 0 and fromInsert then
		local buildDefID = -cmdID
		if not canBuildDef[unitDefID] or not canBuildDef[unitDefID][buildDefID] then
			return false
		end
	end

	return true
end
