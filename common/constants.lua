-- constants.lua ---------------------------------------------------------------
-- General game and engine constants, for use in general Lua environments.

if not Engine or not Spring then return end

--------------------------------------------------------------------------------
-- Version handling ------------------------------------------------------------

local function isEngineMinVersion(major, minor, patch, commits)
	if major and tonumber(Engine.versionMajor) ~= major then
		return tonumber(Engine.versionMajor) > major
	elseif minor and tonumber(Engine.versionMinor) ~= minor then
		return tonumber(Engine.versionMinor) > minor
	elseif patch and tonumber(Engine.versionPatchSet) ~= patch then
		return tonumber(Engine.versionPatchSet) >= patch
	elseif commits and tonumber(Engine.commitsNumber) ~= 0 then -- dev builds are > 0
		return tonumber(Engine.commitsNumber) >= commits
	else
		return true
	end
end

if Engine.FeatureSupport.targetBorderBug == nil then
	local inRange = isEngineMinVersion(2025, 6, 4) and not isEngineMinVersion(2025, 6, 14)
	---@type boolean Whether the `targetBorder` property is doubled for BeamLaser and LightningCannon.
	Engine.FeatureSupport.targetBorderBug = inRange
end

--------------------------------------------------------------------------------
-- Extended LuaConst -----------------------------------------------------------

if CMD then
	CMD.NIL   = "n" -- Handling for unintended nil's.
	CMD.ANY   = "a" -- Matches on all command values.
	CMD.BUILD = "b" -- Filters for negative commands.

	CMD.n     = "NIL"
	CMD.a     = "ANY"
	CMD.b     = "BUILD"
end
