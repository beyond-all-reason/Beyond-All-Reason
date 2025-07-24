local EnemyLib = {}

local adjustSide = function(sideMin, sideMax, mapSize, spread)
	local sideSize = sideMax - sideMin
	if sideSize > spread then
		return sideMin, sideMax
	end

	local incrementBy = math.ceil((spread - sideSize)/2)
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

EnemyLib.GetAdjustedStartBox = function(enemyAllyTeamID, spread)
	local startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax = Spring.GetAllyTeamStartBox(enemyAllyTeamID)
	if startBoxXMin and startBoxZMin and startBoxXMax and startBoxZMax then
		startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax = adjustStartBox(startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax, spread)
	end
	return startBoxXMin, startBoxZMin, startBoxXMax, startBoxZMax
end

return EnemyLib
