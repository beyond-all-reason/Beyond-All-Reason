function widget:GetInfo()
	return {
		name = "Function Profiler",
		desc = "-",
		license = "GNU GPL, v2 or later",
		enabled = true,
		handler = true,
	}
end

local function pack(...)
	return { ... }
end

local function join(arr, delimiter)
	local result = ""
	local length = #arr
	for i, v in ipairs(arr) do
		result = result .. v
		if i < length then
			result = result .. delimiter
		end
	end
	return result
end

local function keys(inputTable)
	local result = {}
	for key, _ in pairs(inputTable) do
		table.insert(result, key)
	end
	return result
end

local function glListCache(originalFunc)
	local cache = {}

	local function clearCache()
		for key, listID in pairs(cache) do
			gl.DeleteList(listID)
		end
		cache = {}
	end

	local function decoratedFunc(...)
		local rawParams = { ... }
		local params = {}
		for index, value in ipairs(rawParams) do
			if index > 1 then
				table.insert(params, value)
			end
		end

		local key = table.toString(params)

		if cache[key] == nil then
			local function fn()
				originalFunc(unpack(params))
			end
			cache[key] = gl.CreateList(fn)
		end

		gl.CallList(cache[key])
	end

	local decoratedFunction = setmetatable({}, {
		__call = decoratedFunc,
		__index = {
			invalidate = clearCache,
			getCache = function()
				return cache
			end,
			getListID = function(...)
				local params = { ... }
				local key = table.toString(params)
				return cache[key]
			end
		}
	})

	return decoratedFunction
end

local function clamp(min, max, num)
	if (num < min) then
		return min
	elseif (num > max) then
		return max
	end
	return num
end

local function rgbToColorCode(r, g, b)
	local rs = clamp(1, 255, math.round(255 * r))
	local gs = clamp(1, 255, math.round(255 * g))
	local bs = clamp(1, 255, math.round(255 * b))
	return "\255" .. string.char(rs) .. string.char(gs) .. string.char(bs)
end

local function rgbReset()
	--return rgbToColorCode(1, 1, 1)
	return "\b"
end

local function mix(c1, c2, a)
	a = clamp(0, 1, a)
	return {
		c1[1] * (1 - a) + c2[1] * a,
		c1[2] * (1 - a) + c2[2] * a,
		c1[3] * (1 - a) + c2[3] * a,
	}
end

local function interpolateColors(colors, t)
	t = clamp(0, 1, t)

	local numColors = #colors
	if numColors == 1 then
		return colors[1]
	elseif t == 1 then
		return colors[#colors]
	end

	local segment = (numColors - 1) * t
	local index = math.floor(segment)
	local segmentT = segment - index

	local c1, c2 = colors[index + 1], colors[index + 2]
	return {
		c1[1] * (1 - segmentT) + c2[1] * segmentT,
		c1[2] * (1 - segmentT) + c2[2] * segmentT,
		c1[3] * (1 - segmentT) + c2[3] * segmentT
	}
end

local KNOWN_GLOBALS = {}
--for _, g in ipairs({ Spring, Script, Game, math, gl, VFS }) do
--	for _, v in pairs(g) do
--		KNOWN_GLOBALS[v] = true
--	end
--end

local ALLOWED_GLOBALS = {
	["GameOver"] = true,
	["GameFrame"] = true,
	["GameSetup"] = true,
	["GamePaused"] = true,
	["TeamDied"] = true,
	["TeamChanged"] = true,
	["PlayerAdded"] = true,
	["PlayerRemoved"] = true,
	["PlayerChanged"] = true,
	["ShockFront"] = true,
	["WorldTooltip"] = true,
	["MapDrawCmd"] = true,
	["DefaultCommand"] = true,
	["UnitCreated"] = true,
	["UnitFinished"] = true,
	["UnitFromFactory"] = true,
	["UnitDestroyed"] = true,
	["UnitDestroyedByTeam"] = true,
	["RenderUnitDestroyed"] = true,
	["UnitExperience"] = true,
	["UnitTaken"] = true,
	["UnitGiven"] = true,
	["UnitIdle"] = true,
	["UnitCommand"] = true,
	["UnitCmdDone"] = true,
	["UnitDamaged"] = true,
	["UnitEnteredRadar"] = true,
	["UnitEnteredLos"] = true,
	["UnitLeftRadar"] = true,
	["UnitLeftLos"] = true,
	["UnitEnteredWater"] = true,
	["UnitEnteredAir"] = true,
	["UnitLeftWater"] = true,
	["UnitLeftAir"] = true,
	["UnitSeismicPing"] = true,
	["UnitLoaded"] = true,
	["UnitUnloaded"] = true,
	["UnitCloaked"] = true,
	["UnitDecloaked"] = true,
	["UnitMoveFailed"] = true,
	["MetaUnitAdded"] = true,
	["MetaUnitRemoved"] = true,
	["RecvLuaMsg"] = true,
	["StockpileChanged"] = true,
	["SelectionChanged"] = true,
	["DrawGenesis"] = true,
	["DrawWorld"] = true,
	["DrawWorldPreUnit"] = true,
	["DrawPreDecals"] = true,
	["DrawWorldPreParticles"] = true,
	["DrawWorldShadow"] = true,
	["DrawWorldReflection"] = true,
	["DrawWorldRefraction"] = true,
	["DrawUnitsPostDeferred"] = true,
	["DrawFeaturesPostDeferred"] = true,
	["DrawScreenEffects"] = true,
	["DrawScreenPost"] = true,
	["DrawInMiniMap"] = true,
	["DrawOpaqueUnitsLua"] = true,
	["DrawOpaqueFeaturesLua"] = true,
	["DrawAlphaUnitsLua"] = true,
	["DrawAlphaFeaturesLua"] = true,
	["DrawShadowUnitsLua"] = true,
	["DrawShadowFeaturesLua"] = true,
	["SunChanged"] = true,
	["FeatureCreated"] = true,
	["FeatureDestroyed"] = true,
	["UnsyncedHeightMapUpdate"] = true,
	["GamePreload"] = true,
	["GameStart"] = true,
	["Shutdown"] = true,
	["Update"] = true,
	["TextCommand"] = true,
	["CommandNotify"] = true,
	["AddConsoleLine"] = true,
	["ViewResize"] = true,
	["DrawScreen"] = true,
	["KeyPress"] = true,
	["KeyRelease"] = true,
	["TextInput"] = true,
	["MousePress"] = true,
	["MouseWheel"] = true,
	["ControllerAdded"] = true,
	["ControllerRemoved"] = true,
	["ControllerConnected"] = true,
	["ControllerDisconnected"] = true,
	["ControllerRemapped"] = true,
	["ControllerButtonUp"] = true,
	["ControllerButtonDown"] = true,
	["ControllerAxisMotion"] = true,
	["IsAbove"] = true,
	["GetTooltip"] = true,
	["GroupChanged"] = true,
	["GameProgress"] = true,
	["CommandsChanged"] = true,
	["LanguageChanged"] = true,
	["VisibleUnitAdded"] = true,
	["VisibleUnitRemoved"] = true,
	["VisibleUnitsChanged"] = true,
	["AlliedUnitAdded"] = true,
	["AlliedUnitRemoved"] = true,
	["AlliedUnitsChanged"] = true,
}

local timerStats = {}
local realTimeElapsed = 0

local function resetTimerStats()
	timerStats = {}
	realTimeElapsed = 0
end

local currentLabel = {}
local function timerWrapper(widgetName, label, f)
	local widgetPrefix = widgetName .. "."
	return function(...)
		table.insert(currentLabel, label)

		local _, _, startMem = Spring.GetLuaMemUsage()
		local start = Spring.GetTimer()
		local result = pack(f(...))
		local duration = Spring.DiffTimers(Spring.GetTimer(), start, true)
		local _, _, endMem = Spring.GetLuaMemUsage()
		local diffMem = (endMem - startMem) * 1024

		local localLabelStr = widgetPrefix .. join(currentLabel, ".")

		if not timerStats[localLabelStr] then
			timerStats[localLabelStr] = {
				duration = 0,
				calls = 0,
				mem = 0,
			}
		end
		local s = timerStats[localLabelStr]

		s.duration = s.duration + duration / 1000
		s.calls = s.calls + 1
		s.lastCall = realTimeElapsed
		s.mem = s.mem + diffMem

		table.remove(currentLabel, #currentLabel)

		return unpack(result)
	end,
	f
end

local function timerRun(widgetName, label, f)
	local widgetPrefix = widgetName .. "."
	table.insert(currentLabel, label)

	local start = Spring.GetTimer()
	local result = pack(f())
	local duration = Spring.DiffTimers(Spring.GetTimer(), start, true)

	local localLabelStr = widgetPrefix .. join(currentLabel, ".")

	if not timerStats[localLabelStr] then
		timerStats[localLabelStr] = {
			duration = 0,
			calls = 0,
		}
	end
	local s = timerStats[localLabelStr]

	s.duration = s.duration + duration / 1000
	s.calls = s.calls + 1
	s.lastCall = realTimeElapsed

	table.remove(currentLabel, #currentLabel)

	return unpack(result)
end

local originalFunctions = {}
local function profileFunction(widgetName, functionName, functionPrefix)
	local widget = widgetHandler:FindWidget(widgetName)
	local original = widget[functionName]
	if not original then
		error("Unknown function: " .. tostring(functionName))
	end
	widget[functionName] = timerWrapper(widgetName, (functionPrefix or "") .. functionName, original)

	if not originalFunctions[widgetName] then
		originalFunctions[widgetName] = {}
	end
	originalFunctions[widgetName][functionName] = original
end

local function unprofileFunction(widgetName, functionName)
	local widget = widgetHandler:FindWidget(widgetName)
	widget[functionName] = originalFunctions[widgetName][functionName]
end

local function profileFunctionWrapper(widgetName, functionName, functionPrefix, original)
	return timerWrapper(widgetName, (functionPrefix or "") .. functionName, original)
end

local function loadWidget(widgetName, enableLocalsAccess)
	local initialWidgetActive = widgetHandler.knownWidgets[widgetName].active
	if initialWidgetActive then
		widgetHandler:DisableWidget(widgetName)
	end
	widgetHandler:EnableWidget(widgetName, enableLocalsAccess)
end

local function buildLabelTree(labels)
	local result = {}

	for _, str in ipairs(labels) do
		local currentNode = result
		for node in str:gmatch("[^.]+") do
			currentNode[node] = currentNode[node] or {}
			currentNode = currentNode[node]
		end
	end

	return result
end

local HIDE_TIMEOUT = 5
local fractionColorLow = { 0.1, 0.8, 0.1 }
local fractionColorMedium = { 0.9, 0.9, 0.1 }
local fractionColorHigh = { 1.0, 0.0, 0.0 }
local fractionColors = { fractionColorLow, fractionColorMedium, fractionColorHigh }
local widgetColor = { 0.6, 0.6, 1.0 }
local branchColor = { 0.6, 0.6, 0.6 }
local backgroundColor = { 0.0, 0.0, 0.0, 0.6 }

local function renderGradient(str, colors, t)
	return rgbToColorCode(unpack(interpolateColors(colors, t))) .. str .. rgbReset()
end

local function renderWidgetName(widgetName)
	return rgbToColorCode(unpack(widgetColor)) .. widgetName .. rgbReset()
end

local function renderBranch(str)
	return rgbToColorCode(unpack(branchColor)) .. str .. rgbReset()
end

local function renderTree(node, renderLine, parentKeys, prefix)
	prefix = prefix or ""

	local result = ""
	local nodeKeys = keys(node)
	table.sort(nodeKeys)

	for index, key in ipairs(nodeKeys) do
		local childNode = node[key]
		local lastNode = index == #nodeKeys

		local branch
		if not parentKeys then
			branch = ""
		elseif lastNode then
			branch = renderBranch("└╌")
		else
			branch = renderBranch("├╌")
		end

		local extraPrefix
		if not parentKeys then
			extraPrefix = ""
		elseif lastNode then
			extraPrefix = "  "
		else
			extraPrefix = renderBranch("│ ")
		end

		local fullKey = key
		if parentKeys then
			fullKey = parentKeys .. "." .. fullKey
		end

		result = result .. renderLine(fullKey, prefix .. branch)
		result = result .. renderTree(
			childNode,
			renderLine,
			fullKey,
			prefix .. extraPrefix
		)
	end

	return result
end

local renderStatsLineFormat = "%8s %8s %8s %8s %8s %s\n"
local renderStatsLineFormatBlank = string.format(
	renderStatsLineFormat,
	"-", "-", "-", "-", "-", "%s"
)
local renderStatsHeader = string.format(
	renderStatsLineFormat,
	"call/s", "avgtime", "%time", "time", "mem/s", "function"
)
local function renderStatsLine(prefix, label, stats)
	local labelStr
	local labelSplit = string.split(label, ".")
	if #labelSplit == 1 then
		labelStr = prefix .. renderWidgetName(label)
	else
		labelStr = prefix .. labelSplit[#labelSplit]
	end

	if not stats then
		return string.format(renderStatsLineFormatBlank, labelStr)
	end

	local timePercent = stats.duration / realTimeElapsed
	local timePercentStrRaw = string.format("%4.1f%%", 100 * timePercent)
	local timePercentStrColor = renderGradient(
		timePercentStrRaw,
		fractionColors,
		timePercent / 0.05
	)
	local timePercentStr = string.rep(
		" ",
		math.max(0, 8 - string.len(timePercentStrRaw))
	) .. timePercentStrColor

	local memRate = stats.mem / realTimeElapsed
	local memRateStrRaw = string.formatSI(memRate, { leaveTrailingZeros = true }) .. "B"
	local memT = math.max(0, math.min(1, math.log10(memRate) / 9))
	local memRateStrColor = renderGradient(
		memRateStrRaw,
		fractionColors,
		memT
	)
	local memRateStr = string.rep(
		" ",
		math.max(0, 8 - string.len(memRateStrRaw))
	) .. memRateStrColor

	return string.format(
		renderStatsLineFormat,
		string.formatSI(stats.calls / realTimeElapsed, { leaveTrailingZeros = true }),
		string.formatSI(stats.duration / stats.calls, { leaveTrailingZeros = true }) .. "s",
		timePercentStr,
		string.formatSI(stats.duration / realTimeElapsed, { leaveTrailingZeros = true }) .. "s",
		memRateStr,
		labelStr
	)
end

local font
local fontSize = 16
local drawTimerStats = glListCache(function()
	if not font then
		font = WG['fonts'].getFont("fonts/monospaced/SourceCodePro-Medium.otf")
	end

	local x = 10
	local mmposX, mmposY, mmsizeX, mmsizeY = Spring.GetMiniMapGeometry()
	local y = mmposY - 30

	local allLabels = {}
	for key in pairs(timerStats) do
		table.insert(allLabels, key)
	end
	table.sort(allLabels)

	local labelTree = buildLabelTree(keys(timerStats))

	local text = renderStatsHeader .. renderTree(labelTree, function(label, prefix)
		return renderStatsLine(prefix, label, timerStats[label])
	end) .. " "

	local textWidth = font:GetTextWidth(text)
	local textHeight, textDescender = font:GetTextHeight(text)
	local yOffset = fontSize / 3
	local xPadding = fontSize / 3

	gl.Color(unpack(backgroundColor))
	gl.Rect(
		x - xPadding,
		y + textHeight * fontSize + yOffset,
		x + textWidth * fontSize + xPadding,
		y + textDescender * fontSize + yOffset
	)

	gl.Color(1.0, 1.0, 1.0, 1.0)
	font:Print(text, x, y, fontSize)
end)

local invalidatePeriod = 0.5
local timeSinceLastInvalidate = 0
function widget:Update(dt)
	realTimeElapsed = realTimeElapsed + dt

	timeSinceLastInvalidate = timeSinceLastInvalidate + dt
	if timeSinceLastInvalidate > invalidatePeriod then
		timeSinceLastInvalidate = 0

		for label, stats in pairs(timerStats) do
			if stats and stats.lastCall < (realTimeElapsed - HIDE_TIMEOUT) then
				timerStats[label] = nil
			end
		end

		drawTimerStats.invalidate()
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	font = WG['fonts'].getFont("fonts/monospaced/SourceCodePro-Medium.otf")
end

function widget:DrawScreen()
	drawTimerStats()
end

local function isCallable(f)
	local tf = type(f)
	if tf == 'function' then
		return true
	end
	--if tf == 'table' then
	--	local mt = getmetatable(f)
	--	return type(mt) == 'table' and isCallable(mt.__call)
	--end
	return false
end

local function profileWidget(widgetName)
	loadWidget(widgetName, true)
	local widgetTable = widgetHandler:FindWidget(widgetName)

	for _, localName in ipairs(widgetTable.__getLocals()) do
		if widgetTable[localName]
			and isCallable(widgetTable[localName])
			and not KNOWN_GLOBALS[widgetTable[localName]]
		then
			profileFunction(widgetName, localName)
		end
	end

	for globalName, globalValue in pairs(widgetTable) do
		if ALLOWED_GLOBALS[globalName] and globalValue and type(globalValue) == "function" then
			profileFunction(widgetName, globalName, "widget:")
		end
	end
end

local function unprofileWidget(widgetName)
	if not originalFunctions[widgetName] then
		return
	end
	for functionName, _ in pairs(originalFunctions[widgetName]) do
		unprofileFunction(widgetName, functionName)
	end
end

function widget:Initialize()
	WG['function_profiler'] = {
		profileFunction = profileFunction,
		unprofileFunction = unprofileFunction,
		profileWidget = profileWidget,
		unprofileWidget = unprofileWidget,
		timerRun = timerRun,
	}

	widgetHandler.actionHandler:AddAction(
		self,
		"profilewidget",
		function(cmd, optLine, optWords, data, isRepeat, release, actions)
			local widgetName = optLine
			if not widgetHandler.knownWidgets[widgetName] then
				Spring.Echo("unknown widget: " .. widgetName)
				return
			end
			profileWidget(widgetName)
			resetTimerStats()
		end,
		nil,
		"t"
	)
	widgetHandler.actionHandler:AddAction(
		self,
		"unprofilewidget",
		function(cmd, optLine, optWords, data, isRepeat, release, actions)
			local widgetName = optLine
			if not widgetHandler.knownWidgets[widgetName] then
				Spring.Echo("unknown widget: " .. widgetName)
				return
			end
			unprofileWidget(widgetName)
		end,
		nil,
		"t"
	)
	widgetHandler.actionHandler:AddAction(
		self,
		"profilereset",
		function(cmd, optLine, optWords, data, isRepeat, release, actions)
			resetTimerStats()
		end,
		nil,
		"t"
	)
end

function widget:Shutdown()
	for widgetName, widgetFunctions in pairs(originalFunctions) do
		for functionName, _ in pairs(widgetFunctions) do
			unprofileFunction(widgetName, functionName)
		end
	end

	WG['function_profiler'] = nil

	widgetHandler.actionHandler:RemoveAction("profilewidget", "t")
	widgetHandler.actionHandler:RemoveAction("unprofilewidget", "t")
	widgetHandler.actionHandler:RemoveAction("profilereset", "t")
end
