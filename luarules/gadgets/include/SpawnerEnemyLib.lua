local EnemyLib = {}

local adjustSide = function(sideMin, sideMax, mapSize, spread)
	local sideSize = sideMax - sideMin
	if sideSize > spread then
		return sideMin, sideMax
	end

	local incrementBy = math.ceil((spread - sideSize) / 2)
	sideMin = sideMin - incrementBy
	sideMax = sideMax + incrementBy
	sideMin = math.max(sideMin, 0)
	sideMax = math.min(sideMax, mapSize)
	return sideMin, sideMax
end

local adjustStartBox = function(startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax, spread)
	startBoxXMin, startBoxXMax = adjustSide(startBoxXMin, startBoxXMax, Game.mapSizeX, spread)
	startBoxZMin, startBoxZMax = adjustSide(startBoxZMin, startBoxZMax, Game.mapSizeZ, spread)
	return startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax
end

local StartboxLib = VFS.Include("luarules/gadgets/include/startbox_utilities.lua")

-- Not Spring.GetAllyTeamStartBox: callers ask for this while gadget files are still being
-- loaded, and the config gadget does not apply the startbox modoption until its Initialize
-- runs, so the engine still reports whatever the host put in the start script.
EnemyLib.GetAdjustedStartBox = function(enemyAllyTeamID, spread)
	local startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax = StartboxLib.GetBounds(enemyAllyTeamID)
	if startBoxXMin and startBoxZMin and startBoxXMax and startBoxZMax then
		startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax =
			adjustStartBox(startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax, spread)
	end
	return startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax
end

-- The bounds above are only a sampling window for a shape that may not fill them, so
-- spawners pick through here rather than randomising between the bounds themselves.
EnemyLib.GetRandomPosInStartBox = function(enemyAllyTeamID, inset, tries)
	return StartboxLib.GetRandomPos(enemyAllyTeamID, inset, tries)
end

EnemyLib.HasStartBox = function(enemyAllyTeamID)
	return StartboxLib.HasStartbox(enemyAllyTeamID)
end

EnemyLib.IsInStartBox = function(enemyAllyTeamID, x, z)
	return StartboxLib.IsInside(enemyAllyTeamID, x, z)
end

return EnemyLib
