local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Build Split",
		desc = "Splits builds over cons, and vice versa (use shift+space to activate)",
		author = "Niobium",
		version = "v1.0",
		date = "Jan 11, 2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end


-- Localized Spring API for performance
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSpectatingState = Spring.GetSpectatingState

local floor = math.floor
local spTestBuildOrder = Spring.TestBuildOrder
local spGetSelUnitCount = spGetSelectedUnitsCount
local spGetSelUnitsSorted = spGetSelectedUnitsSorted
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local activeModifier = false

local unitBuildOptions = {}
for udefID, def in ipairs(UnitDefs) do
	if #def.buildOptions > 0 then
		unitBuildOptions[udefID] = def.buildOptions
	end
end

local buildID = 0
local buildLocs = {}
local buildCount = 0

local gameStarted = false
local isSpec = false

local function maybeRemoveSelf()
	if isSpec then
		widgetHandler:RemoveWidget()

		return true
	end
end

function widget:GameStart()
	gameStarted = true
end

function widget:PlayerChanged()
	isSpec = spGetSpectatingState()
	maybeRemoveSelf()
end

local function handleSetModifier(_, _, _, data)
	data = data or {}
	activeModifier = data[1]
end

function widget:Initialize()
	gameStarted = Spring.GetGameFrame() > 0
	isSpec = spGetSpectatingState()

	if maybeRemoveSelf() then
		return
	end

	widgetHandler:AddAction("buildsplit", handleSetModifier, { true }, "p")
	widgetHandler:AddAction("buildsplit", handleSetModifier, { false }, "r")
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts) -- 3 of 3 parameters
	if not (cmdID < 0 and cmdOpts.shift and activeModifier) then
		return false
	end -- Note: All multibuilds require shift

	if spGetSelUnitCount() < 2 then
		return false
	end

	--if #cmdParams < 4 then return false end -- Probably not possible, commented for now
	if spTestBuildOrder(-cmdID, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4]) == 0 then
		return false
	end

	buildID = -cmdID
	buildCount = buildCount + 1
	buildLocs[buildCount] = cmdParams

	return true
end

function widget:Update()
	if buildCount == 0 then
		return
	end

	if not gameStarted then
		return
	end

	local selUnits = spGetSelUnitsSorted()

	local builders = {}
	local builderCount = 0
	for uDefID, uIDs in pairs(selUnits) do
		local uBuilds = unitBuildOptions[uDefID]
		if uBuilds then
			for bi = 1, #uBuilds do
				if uBuilds[bi] == buildID then
					for ui = 1, #uIDs do
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
		for bi = 1, builderCount do
			for _ = 1, ratio do
				buildingInd = buildingInd + 1
				spGiveOrderToUnit(builders[bi], -buildID, buildLocs[buildingInd], { "shift" })
			end
			if bi <= excess then
				buildingInd = buildingInd + 1
				spGiveOrderToUnit(builders[bi], -buildID, buildLocs[buildingInd], { "shift" })
			end
		end
	else
		local ratio = floor(builderCount / buildCount)
		local excess = builderCount - buildCount * ratio -- == builderCount % buildCount
		local builderInd = 0

		for bi = 1, buildCount do
			local setUnits = {}
			local setCount = 0
			for _ = 1, ratio do
				builderInd = builderInd + 1
				setCount = setCount + 1
				setUnits[setCount] = builders[builderInd]
			end
			if bi <= excess then
				builderInd = builderInd + 1
				setCount = setCount + 1
				setUnits[setCount] = builders[builderInd]
			end

			spGiveOrderToUnitArray(setUnits, -buildID, buildLocs[bi], { "shift" })
		end
	end

	buildCount = 0
end
