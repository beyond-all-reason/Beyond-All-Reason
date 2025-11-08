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

local floor = math.floor
local spTestBuildOrder = Spring.TestBuildOrder
local spGetSelUnitCount = Spring.GetSelectedUnitsCount
local spGetSelUnitsSorted = Spring.GetSelectedUnitsSorted
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
	isSpec = Spring.GetSpectatingState()
	maybeRemoveSelf()
end

local function handleSetModifier(_, _, _, data)
	data = data or {}
	activeModifier = data[1]
end

function widget:Initialize()
	gameStarted = Spring.GetGameFrame() > 0
	isSpec = Spring.GetSpectatingState()

	if maybeRemoveSelf() then
		return
	end

	widgetHandler:AddAction("buildsplit", handleSetModifier, { true }, "p")
	widgetHandler:AddAction("buildsplit", handleSetModifier, { false }, "r")

	WG['build_split'] = {
		isActive = function() return activeModifier end,
	}
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts) -- 3 of 3 parameters
	-- Don't handle blueprint commands (let cmd_blueprint handle those)
	if cmdID == GameCMD.BLUEPRINT_PLACE or cmdID == GameCMD.BLUEPRINT_CREATE then
		return false
	end
	
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
	for uDefID, uIDs in pairs(selUnits) do
		local uDef = UnitDefs[uDefID]
		if uDef and uDef.buildOptions and #uDef.buildOptions > 0 then
			for _, uID in ipairs(uIDs) do
				local builderInfo = WG["api_blueprint"].getBuilderInfo(uID)
				if builderInfo then
					table.insert(builders, builderInfo)
				end
			end
		end
	end

	local buildings = {}
	for i = 1, buildCount do
		table.insert(buildings, {
			unitDefID = buildID,
			position = buildLocs[i],
			facing = buildLocs[i][4],
			originalName = UnitDefs[buildID].name,
		})
	end

	WG["api_blueprint"].splitBuildOrders(builders, buildings, { "shift" })

	buildCount = 0
end

function widget:Shutdown()
	WG['build_split'] = nil
end
