
local levelTimeout = 100
local heightMapChanged = false
local autoHeightMap = false
local currentLevel = 0

local function setAutoHeightMap(enable)
	autoHeightMap = enable
end

local function levelHeightMap(level)
	if level == nil then level = 10 end
	if currentLevel == level then return end
	SyncedRun(function(locals)
		local level = locals.level - locals.currentLevel
		if level == 0 then return end
		Spring.LevelHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, level)
		Spring.RebuildSmoothMesh(0, 0, Game.mapSizeX, Game.mapSizeZ)
	end, levelTimeout)
	currentLevel = level
	heightMapChanged = true
end

local function restoreHeightMap(force)
	if not force and not heightMapChanged then return end
	SyncedRun(function()
		Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1.0)
		Spring.RebuildSmoothMesh(0, 0, Game.mapSizeX, Game.mapSizeZ)
	end, levelTimeout)
	heightMapChanged = false
	currentLevel = 0
end

-- Internal methods

local function initTests()
	if autoHeightMap then
		levelTerrain()
	end
end

local function endTests()
	if autoHeightMap then
		restoreTerrain(true)
	end
end

local linkActions = function(widget)
	widgetHandler.actionHandler:AddAction(
		widget,
		"testsautoheightmap",
		function(cmd, optLine, optWords, data, isRepeat, release, actions)
			local enable = not autoHeightMap
			local enableOpt = optWords[1]
			if enableOpt == 'on' or enableOpt == '1' then
				enable = true
			elseif enableOpt == 'off' or enableOpt == '0' then
				enable = false
			end
			setAutoHeightMap(enable)
		end,
		nil,
		"t"
	)
end

return {
	exports = {
		levelHeightMap = levelHeightMap,
		restoreHeightMap = restoreHeightMap,
	},
	initTests = initTests,
	endTests = endTests,
	linkActions = linkActions,
}
