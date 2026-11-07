local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Strange Orders",
		desc = "There's no reason to need to insert a remove command (if even possible)",
		author = "TheFatController",
		date = "Aug 31, 2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

---@type fun(builtUnitDefID: UnitDefID, builderUnitDefID: UnitDefID): boolean
local hasBuildOption

function gadget:Initialize()
	-- api_dynamic_build_options.lua has a lower layer, so it is initialized first.
	hasBuildOption = GG.DynamicBuildOptions.HasBuildOption

	gadgetHandler:RegisterAllowCommand(CMD.INSERT)
	gadgetHandler:RegisterAllowCommand(CMD.REMOVE)
	gadgetHandler:RegisterAllowCommand(CMD.BUILD)
end

function gadget:AllowCommand(
	unitID,
	unitDefID,
	teamID,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua,
	fromInsert
)
	if cmdID == CMD.INSERT or cmdID == CMD.REMOVE then
		return fromInsert == nil
	end

	-- Build command (cmdID < 0) coming from CMD.INSERT: reject if the unit
	-- doesn't have this in its buildOptions. Prevents immobile assist turrets
	-- (nanotc) from getting stuck with an unexecutable build command at the
	-- front of their queue, permanently blocking fight/patrol behind it.
	-- Build options can change at runtime, so ask api_dynamic_build_options.lua.
	if cmdID < 0 and fromInsert then
		local buildDefID = -cmdID
		---@cast buildDefID UnitDefID
		return hasBuildOption(buildDefID, unitDefID)
	end

	return true
end
