if not BAR.Utilities.IsDevMode() then -- and not Spring.Utilities.ShowDevUI() then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Widget Auto Reloader",
		desc = "Reloads all widgets that have changed after the mouse returned to the game window, including widgets whose VFS.Include'd files changed",
		author = "Beherith, Floris",
		date = "2024.03.12",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true, --  loaded by default?
		handler = true, -- so it can remove and add widgets
	}
end

-- Localized Spring API for performance
local spGetMouseState = Spring.GetMouseState
local spEcho = Spring.Echo

local widgetContents = {} -- maps widgetname to raw code
local widgetFilesNames = {} -- maps widgetname to filename
local widgetDependents = {} -- maps widgetname to {dependentName1, ...}
local widgetIncludes = {} -- maps widgetname to { [includeKey] = path } of the files it VFS.Includes directly
local includeFiles = {} -- maps includeKey (lowercased path) to { path, contents, includes = { [includeKey] = path }, changed }
local mouseOffscreen = select(6, spGetMouseState())

---------------------------------------------------------------------------------------------------
-- Include tracking
--
-- A widget's own file doesn't change when a file it VFS.Includes is edited, so the widget sources are
-- scanned for VFS.Include calls and the included files are tracked as well (recursively, included
-- files include further files). A widget is reloaded when its own file or any file in its include
-- closure changed. Paths built from a variable (luaShaderDir .. "x.lua") are resolved when that
-- variable is assigned a string literal somewhere in the same file; fully dynamic paths are skipped.
---------------------------------------------------------------------------------------------------

local function StripComments(source)
	source = source:gsub("%-%-%[(=*)%[.-%]%1%]", "") -- block comments
	source = source:gsub("%-%-[^\r\n]*", "") -- line comments
	return source
end

-- first string literal assigned to `name` in this source, e.g. local luaShaderDir = "LuaUI/Include/"
local function ResolveVariable(source, name)
	return source:match("%f[%w_]" .. name .. "%s*=%s*\"([^\"\r\n]*)\"")
		or source:match("%f[%w_]" .. name .. "%s*=%s*'([^'\r\n]*)'")
end

-- parses the first argument of a VFS.Include call, `pos` pointing just after the function name
-- returns the path, or nil plus the identifier that could not be resolved
local function ParseIncludeArgument(source, pos)
	local s = source:match("^%s*[%(,]%s*()", pos) -- VFS.Include(...) or pcall(VFS.Include, ...)
	if not s then
		return nil
	end
	local path = ""
	while true do
		local quote = source:sub(s, s)
		local term
		if quote == '"' or quote == "'" then
			local e = source:find(quote, s + 1, true)
			if not e then
				return nil
			end
			term = source:sub(s + 1, e - 1)
			s = e + 1
		else
			local ident, e = source:match("^([%a_][%w_]*)()", s)
			if not ident then
				return nil
			end
			term = ResolveVariable(source, ident)
			if not term then
				return nil, ident
			end
			s = e
		end
		path = path .. term
		local afterConcat = source:match("^%s*%.%.%s*()", s)
		if not afterConcat then
			return path
		end
		s = afterConcat
	end
end

-- returns { [includeKey] = path } for every statically resolvable VFS.Include target in the source,
-- plus the list of identifiers whose include path could not be resolved
local function ScanIncludes(source)
	local includes, unresolved = {}, {}
	source = StripComments(source)
	local pos = 1
	while true do
		local s, e = source:find("VFS%.Include", pos)
		if not s then
			break
		end
		pos = e + 1
		local path, ident = ParseIncludeArgument(source, pos)
		if path then
			includes[path:lower()] = path
		elseif ident then
			unresolved[#unresolved + 1] = ident
		end
	end
	return includes, unresolved
end

local function RegisterIncludeFile(key, path)
	if includeFiles[key] then
		return
	end
	local contents = VFS.LoadFile(path)
	if not contents then
		return -- not readable (e.g. a wrongly resolved dynamic path)
	end
	local entry = { path = path, contents = contents, includes = {} }
	includeFiles[key] = entry -- registered before recursing: guards against include cycles
	entry.includes = ScanIncludes(contents)
	for childKey, childPath in pairs(entry.includes) do
		RegisterIncludeFile(childKey, childPath)
	end
end

local function RegisterWidgetIncludes(widgetName, contents)
	local includes = ScanIncludes(contents)
	widgetIncludes[widgetName] = includes
	for key, path in pairs(includes) do
		RegisterIncludeFile(key, path)
	end
end

-- walks the widget's include closure; returns the path of the first changed file, if any
local function FindChangedInclude(widgetName)
	local includes = widgetIncludes[widgetName]
	if not includes then
		return nil
	end
	local visited, stack = {}, {}
	for key in pairs(includes) do
		stack[#stack + 1] = key
	end
	while #stack > 0 do
		local key = stack[#stack]
		stack[#stack] = nil
		if not visited[key] then
			visited[key] = true
			local entry = includeFiles[key]
			if entry then
				if entry.changed then
					return entry.path
				end
				for childKey in pairs(entry.includes) do
					stack[#stack + 1] = childKey
				end
			end
		end
	end
	return nil
end

local function CheckIncludeForChanges(key)
	local entry = includeFiles[key]
	local newContents = VFS.LoadFile(entry.path)
	if newContents == nil or newContents == entry.contents then
		return
	end
	entry.contents = newContents
	entry.includes = ScanIncludes(newContents)
	for childKey, childPath in pairs(entry.includes) do
		RegisterIncludeFile(childKey, childPath)
	end
	local chunk, err = loadstring(newContents, entry.path)
	if chunk == nil then
		spEcho("Failed to load: " .. entry.path .. "  (" .. err .. ")")
		return -- the including widgets are reloaded once the file compiles again
	end
	entry.changed = true -- consumed by the widget checks of the same sweep
end

---------------------------------------------------------------------------------------------------

local function RefreshWidgetList()
	for _, w in pairs(widgetHandler.widgets) do
		local whInfo = w.whInfo
		widgetFilesNames[whInfo.name] = whInfo.filename
		if not widgetContents[whInfo.name] then
			local contents = VFS.LoadFile(whInfo.filename)
			widgetContents[whInfo.name] = contents
			if contents then
				RegisterWidgetIncludes(whInfo.name, contents)
			end
		end
		if w.GetInfo then
			local info = w:GetInfo()
			if info.dependents then
				widgetDependents[whInfo.name] = info.dependents
			end
		end
	end
end

function widget:Initialize()
	RefreshWidgetList()
	local includeCount = 0
	for _ in pairs(includeFiles) do
		includeCount = includeCount + 1
	end
	spEcho("Widget Auto Reloader: tracking " .. includeCount .. " included files")
end

local function ReloadWidget(widgetName, reason)
	spEcho("Reloading widget: " .. widgetName .. " (" .. reason .. ")")
	widgetHandler:DisableWidget(widgetName)
	widgetHandler:EnableWidget(widgetName)
end

local function CheckForChanges(widgetName, fileName)
	local newContents = VFS.LoadFile(fileName)
	local reason
	if newContents ~= widgetContents[widgetName] then
		widgetContents[widgetName] = newContents
		if newContents == nil then
			return
		end
		RegisterWidgetIncludes(widgetName, newContents)
		local chunk, err = loadstring(newContents, fileName)
		if chunk == nil then
			spEcho("Failed to load: " .. fileName .. "  (" .. err .. ")")
			return
		end
		reason = "file changed"
	else
		local changedInclude = FindChangedInclude(widgetName)
		if not changedInclude then
			return
		end
		reason = changedInclude .. " changed"
	end
	if not widgetHandler:FindWidget(widgetName) then
		return -- disabled meanwhile; enabling it by hand loads the file fresh anyway
	end
	ReloadWidget(widgetName, reason)
	local deps = widgetDependents[widgetName]
	if deps then
		for i = 1, #deps do
			local depName = deps[i]
			if widgetHandler:FindWidget(depName) then
				ReloadWidget(depName, "dependent of " .. widgetName)
			end
		end
	end
end

local lastUpdate = Spring.GetTimer()
local updateQueue = {} -- included files first, then widgets, so widgets see the include changes of the same sweep
local queueIndex = 1
local lastQueueRun = lastUpdate
local gameFrameHappened = false
local minimumQueueRate = 1 / 30

local function StartSweep()
	RefreshWidgetList()
	updateQueue = {}
	queueIndex = 1
	for key in pairs(includeFiles) do
		updateQueue[#updateQueue + 1] = { includeKey = key }
	end
	for widgetName, fileName in pairs(widgetFilesNames) do
		updateQueue[#updateQueue + 1] = { widgetName = widgetName, fileName = fileName }
	end
end

local function FinishSweep()
	for _, entry in pairs(includeFiles) do
		entry.changed = nil
	end
	updateQueue = {}
	queueIndex = 1
end

local function ProcessQueueItem(item)
	if item.includeKey then
		tracy.ZoneBeginN("Widget Auto Reloader:" .. item.includeKey)
		CheckIncludeForChanges(item.includeKey)
	else
		tracy.ZoneBeginN("Widget Auto Reloader:" .. item.widgetName)
		CheckForChanges(item.widgetName, item.fileName)
	end
	tracy.ZoneEnd()
end

function widget:GameFrame()
	gameFrameHappened = true
end

function widget:Update()
	local now = Spring.GetTimer()
	if queueIndex <= #updateQueue and (not gameFrameHappened or Spring.DiffTimers(now, lastQueueRun) >= minimumQueueRate) then
		lastQueueRun = now
		-- 2 ms budget per frame
		while queueIndex <= #updateQueue and Spring.DiffTimers(Spring.GetTimer(), now, true) < 2.0 do
			local item = updateQueue[queueIndex]
			queueIndex = queueIndex + 1
			ProcessQueueItem(item)
		end
		if queueIndex > #updateQueue then
			FinishSweep()
		end
	end
	gameFrameHappened = false

	if Spring.DiffTimers(now, lastUpdate) < 1 then
		return
	end
	lastUpdate = now

	local prevMouseOffscreen = mouseOffscreen
	mouseOffscreen = select(6, spGetMouseState())

	if not mouseOffscreen and prevMouseOffscreen then
		StartSweep()
	end
end
