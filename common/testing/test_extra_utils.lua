
local levelTimeout = 100
local heightMapChanged = false
local noHeightMapRestore = false

local function setHeightmapNoRestore(noRestore)
	noHeightMapRestore = noRestore
end

local function levelHeightmap(level)
	if level == nil then level = 10 end
	SyncedRun(function(locals)
		local level = locals.level
		Spring.LevelHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, level)
		Spring.RebuildSmoothMesh(0, 0, Game.mapSizeX, Game.mapSizeZ)
	end, levelTimeout)
	heightMapChanged = true
end

local function restoreHeightmap(force)
	if not force and not heightMapChanged then return end
	SyncedRun(function()
		Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1.0)
		Spring.RebuildSmoothMesh(0, 0, Game.mapSizeX, Game.mapSizeZ)
	end, levelTimeout)
	heightMapChanged = false
end

return {
	levelHeightmap = levelHeightmap,
	restoreHeightmap = restoreHeightmap,
	setHeightmapNoRestore = setHeightmapNoRestore,
}
