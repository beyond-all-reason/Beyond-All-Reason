-- constants.lua ---------------------------------------------------------------
-- General game and engine constants, for use in general Lua environments.

if not Engine or not Spring then return end

--------------------------------------------------------------------------------
-- Version handling ------------------------------------------------------------

-- TODO: support Engine.commitsNumber
local function isEngineMinVersion(major, minor, patch)
    if tonumber(Engine.versionMajor) > major then
        return true
    elseif tonumber(Engine.versionMajor) < major then
        return false
    end

    if tonumber(Engine.versionMinor) > minor then
        return true
    elseif tonumber(Engine.versionMinor) < minor then
        return false
    end

    return tonumber(Engine.versionPatchSet) >= patch
end

-- An enhancement to add ellipsoidal and cylindrical targeting volumes was bugged briefly for BeamLaser and LightningCannon.
if Engine.FeatureSupport.targetBorderBug == nil then
	local inRange = isEngineMinVersion(2025, 6, 4) and not isEngineMinVersion(2025, 6, 14)
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

--------------------------------------------------------------------------------
-- Game constants --------------------------------------------------------------

if Game then
	---The first frame that units are spawned. Used for scenario units and commanders.
	---@type integer
	Game.spawnInitialFrame = 2 * Game.gameSpeed

	---Non-scenario starting units spend a number of frames warping/teleporting in.
	---@type integer
	Game.spawnWarpInFrame = 3 * Game.gameSpeed
end
