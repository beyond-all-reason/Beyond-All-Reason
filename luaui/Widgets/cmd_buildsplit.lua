function widget:GetInfo()
	return {
		name      = "Build Split",
		desc      = "Splits builds over cons, and vice versa (use shift+space to activate)",
		author    = "Niobium",
		version   = "v1.0",
		date      = "Jan 11, 2009",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled = true  --  loaded by default?
	}
end

local floor = math.floor
local spGetSpecState = Spring.GetSpectatingState
local spTestBuildOrder = Spring.TestBuildOrder
local spGetSelUnitCount = Spring.GetSelectedUnitsCount
local spGetSelUnitsSorted = Spring.GetSelectedUnitsSorted
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray

local unitBuildOptions = {}
for udefID, def in ipairs(UnitDefs) do
	if #def.buildOptions > 0 then
		unitBuildOptions[udefID] = def.buildOptions
	end
end

local buildID = 0
local buildLocs = {}
local buildCount = 0

local gameStarted

local function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts) -- 3 of 3 parameters
	if not (cmdID < 0 and cmdOpts.shift and cmdOpts.meta) then return false end -- Note: All multibuilds require shift
	if spGetSelUnitCount() < 2 then return false end

	--if #cmdParams < 4 then return false end -- Probably not possible, commented for now
	if spTestBuildOrder(-cmdID, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4]) == 0 then return false end

	local areSpec = spGetSpecState()
	if areSpec then
		widgetHandler:RemoveWidget()
		return false
	end

	buildID = -cmdID
	buildCount = buildCount + 1
	buildLocs[buildCount] = cmdParams

	return true
end

function widget:Update()
	if buildCount == 0 then return end

	local selUnits = spGetSelUnitsSorted()
	selUnits.n = nil

	local builders = {}
	local builderCount = 0
	for uDefID, uIDs in pairs(selUnits) do
		local uBuilds = unitBuildOptions[uDefID]
		if uBuilds then
			for bi=1, #uBuilds do
				if uBuilds[bi] == buildID then
					for ui=1, #uIDs do
						builderCount = builderCount + 1
						builders[builderCount] = uIDs[ui]
					end
					break
				end
			end
		end
	end

	if buildCount > builderCount then
		local ratio = floor(buildCount / builderCount)
		local excess = buildCount - builderCount * ratio -- == buildCount % builderCount
		local buildingInd = 0
		for bi=1, builderCount do
			for r=1, ratio do
				buildingInd = buildingInd + 1
				spGiveOrderToUnit(builders[bi], -buildID, buildLocs[buildingInd], {"shift"})
			end
			if bi <= excess then
				buildingInd = buildingInd + 1
				spGiveOrderToUnit(builders[bi], -buildID, buildLocs[buildingInd], {"shift"})
			end
		end
	else
		local ratio = floor(builderCount / buildCount)
		local excess = builderCount - buildCount * ratio -- == builderCount % buildCount
		local builderInd = 0

		for bi=1, buildCount do
			local setUnits = {}
			local setCount = 0
			for r=1, ratio do
				builderInd = builderInd + 1
				setCount = setCount + 1
				setUnits[setCount] = builders[builderInd]
			end
			if bi <= excess then
				builderInd = builderInd + 1
				setCount = setCount + 1
				setUnits[setCount] = builders[builderInd]
			end

			spGiveOrderToUnitArray(setUnits, -buildID, buildLocs[bi], {"shift"})
		end
	end

	buildCount = 0
end
