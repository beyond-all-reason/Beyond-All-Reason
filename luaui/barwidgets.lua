--------------------------------------------------------------------------------
--
--  file:    widgets.lua
--  brief:   the widget manager, a call-in router
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

VFS.Include(LUAUI_DIRNAME .. "Headers/keysym.h.lua", nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "system.lua",           nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "callins.lua",          nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "savetable.lua",        nil, VFS.ZIP)

local gl = gl

local CONFIG_FILENAME = LUAUI_DIRNAME .. 'Config/' .. Game.gameShortName .. '.lua'
local WIDGET_DIRNAME = LUAUI_DIRNAME .. 'Widgets/'
local RML_WIDGET_DIRNAME = LUAUI_DIRNAME .. 'RmlWidgets/'

local SELECTOR_BASENAME = 'selector.lua'

local SAFEWRAP = 1
-- 0: disabled
-- 1: enabled, but can be overriden by widget.GetInfo().unsafe
-- 2: always enabled

local SAFEDRAW = false  -- requires SAFEWRAP to work
local glPopAttrib = gl.PopAttrib
local glPushAttrib = gl.PushAttrib

Spring.SendCommands({
	"unbindkeyset  Any+f11",
	"unbindkeyset Ctrl+f11",
	"bind    f11  luaui selector",
	"echo LuaUI: bound F11 to the widget selector",
})

local allowuserwidgets = Spring.GetModOptions().allowuserwidgets
local allowunitcontrolwidgets = Spring.GetModOptions().allowunitcontrolwidgets

local SandboxedSystem = {}

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
if anonymousMode ~= "disabled" then
	allowuserwidgets = false

	-- disabling individual Spring functions isnt really good enough
	-- disabling user widget draw access would probably do the job but that wouldnt be easy to do
	Spring.SetTeamColor = function() return true end
end

if Spring.IsReplay() or Spring.GetSpectatingState() then
	allowuserwidgets = true
	allowunitcontrolwidgets = true
end

widgetHandler = {
	widgets = {},

	configData = {},
	orderList = {},

	knownWidgets = {},
	knownCount = 0,
	knownChanged = true,

	commands = {},
	customCommands = {},
	inCommandsChanged = false,

	allowUserWidgets = true,
	allowUnitControlWidgets = true,

	actionHandler = VFS.Include(LUAUI_DIRNAME .. "actions.lua", nil, VFS.ZIP),
	widgetHashes = {}, -- this is a table of widget md5 values to file names, used for user widget hashing

	WG = {}, -- shared table for widgets

	globals = {}, -- global vars/funcs

	textOwner = nil,
	mouseOwner = nil,
	ownedButton = 0,

	chobbyInterface = false,	-- will be true when chobby interface is on top

	xViewSize = 1,
	yViewSize = 1,
	xViewSizeOld = 1,
	yViewSizeOld = 1,
}


-- these call-ins are set to 'nil' if not used
-- they are setup in UpdateCallIns()
local flexCallIns = {
	'GameOver',
	'GameFrame',
	'GameSetup',
	'GamePaused',
	'TeamDied',
	'TeamChanged',
	'PlayerAdded',
	'PlayerRemoved',
	'PlayerChanged',
	'ShockFront',
	'WorldTooltip',
	'MapDrawCmd',
	'ActiveCommandChanged',
	'CameraRotationChanged',
	'CameraPositionChanged',
	'DefaultCommand',
	'UnitCreated',
	'UnitFinished',
	'UnitFromFactory',
	'UnitDestroyed',
	'UnitDestroyedByTeam', -- NB: called via gadget, not engine
	'RenderUnitDestroyed',
	'UnitExperience',
	'UnitTaken',
	'UnitGiven',
	'UnitIdle',
	'UnitCommand',
	'UnitCmdDone',
	'UnitDamaged',
	"UnitStunned",
	'UnitEnteredRadar',
	'UnitEnteredLos',
	'UnitLeftRadar',
	'UnitLeftLos',
	'UnitEnteredWater',
	'UnitEnteredAir',
	'UnitLeftWater',
	'UnitLeftAir',
	'UnitSeismicPing',
	'UnitLoaded',
	'UnitUnloaded',
	'UnitCloaked',
	'UnitDecloaked',
	'UnitMoveFailed',
	'MetaUnitAdded',
	'MetaUnitRemoved',
	'RecvLuaMsg',
	'StockpileChanged',
	'SelectionChanged',
	'DrawGenesis',
	'DrawGroundDeferred',
	'DrawWorld',
	'DrawWorldPreUnit',
	'DrawPreDecals',
	'DrawWorldPreParticles',
	'DrawWorldShadow',
	'DrawWorldReflection',
	'DrawWorldRefraction',
	'DrawUnitsPostDeferred',
	'DrawFeaturesPostDeferred',
	'DrawScreenEffects',
	'DrawScreenPost',
	'DrawInMiniMap',
	'DrawOpaqueUnitsLua',
	'DrawOpaqueFeaturesLua',
	'DrawAlphaUnitsLua',
	'DrawAlphaFeaturesLua',
	'DrawShadowUnitsLua',
	'DrawShadowFeaturesLua',
	'SunChanged',
	'FeatureCreated',
	'FeatureDestroyed',
	'UnsyncedHeightMapUpdate',
}
local flexCallInMap = {}
for _, ci in ipairs(flexCallIns) do
	flexCallInMap[ci] = true
end

local callInLists = {
	'FontsChanged',
	'GamePreload',
	'GameStart',
	'Shutdown',
	'Update',
	'TextCommand',
	'CommandNotify',
	'AddConsoleLine',
	'ViewResize',
	'DrawScreen',
	'KeyPress',
	'KeyRelease',
	'TextInput',
	'MousePress',
	'MouseWheel',
	'ControllerAdded',
	'ControllerRemoved',
	'ControllerConnected',
	'ControllerDisconnected',
	'ControllerRemapped',
	'ControllerButtonUp',
	'ControllerButtonDown',
	'ControllerAxisMotion',
	'IsAbove',
	'GetTooltip',
	'GroupChanged',
	'GameProgress',
	'CommandsChanged',
	'LanguageChanged',
	'VisibleUnitAdded',
	'VisibleUnitRemoved',
	'VisibleUnitsChanged',
	'AlliedUnitAdded',
	'AlliedUnitRemoved',
	'AlliedUnitsChanged',
	'UnitSale',
	'UnitSold',
	'VisibleExplosion',
	'Barrelfire',
	'CrashingAircraft',
	'ClearMapMarks',

	-- these use mouseOwner instead of lists
	--  'MouseMove',
	--  'MouseRelease',
}

-- append the flex call-ins
for _, uci in ipairs(flexCallIns) do
	table.insert(callInLists, uci)
end

-- initialize the call-in lists
do
	for _, listname in ipairs(callInLists) do
		widgetHandler[listname .. 'List'] = {}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Reverse integer iterator for drawing
--

local function rev_iter(t, key)
	if key <= 1 then
		return nil
	else
		local nkey = key - 1
		return nkey, t[nkey]
	end
end

local function r_ipairs(t)
	return rev_iter, t, (1 + #t)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widgetHandler:LoadConfigData()
	local chunk, err = loadfile(CONFIG_FILENAME)
	if chunk == nil or err then
		if err then
			Spring.Log("barwidgets.lua", LOG.INFO, err)
		end
		return {}
	elseif chunk() == nil then
		Spring.Log("barwidgets.lua", LOG.ERROR, 'Luaui config file was blank')
		return {}
	end
	local tmp = {}
	setfenv(chunk, tmp)
	self.orderList = chunk().order
	self.configData = chunk().data
	self.allowUserWidgets = chunk().allowUserWidgets
	self.allowUnitControlWidgets = chunk().allowUnitControlWidgets
	if not self.orderList then
		self.orderList = {} -- safety
	end
	if not self.configData then
		self.configData = {} -- safety
	end
end

function widgetHandler:SaveConfigData()
	local filetable = {}
	for i, w in ipairs(self.widgets) do
		if w.GetConfigData then
			self.configData[w.whInfo.name] = w:GetConfigData()
		end
		self.orderList[w.whInfo.name] = i
	end
	filetable.order = self.orderList
	filetable.data = self.configData
	filetable.allowUserWidgets = self.allowUserWidgets
	filetable.allowUnitControlWidgets = self.allowUnitControlWidgets
	table.save(filetable, CONFIG_FILENAME, '-- Widget Custom data and order, order = 0 disabled widget')
end

function widgetHandler:SendConfigData()
	self:LoadConfigData()
	for i, w in ipairs(self.widgets) do
		local data = self.configData[w.whInfo.name]
		if w.SetConfigData and data then
			w:SetConfigData(data)
		end
	end
end


--------------------------------------------------------------------------------
local unsortedWidgets
local doMoreYield = (Spring.Yield ~= nil);

local function Yield()
	if doMoreYield then
		doMoreYield = Spring.Yield()
	end
end

local zipOnly = {
	["Widget Selector"] = true,
	["Widget Profiler"] = true,
}

local function loadWidgetFiles(folder, vfsMode)
	local fromZip = vfsMode ~= VFS.RAW
	local widgetFiles = VFS.DirList(folder, "*.lua", vfsMode)

	for _, subDirectory in ipairs( VFS.SubDirs(folder) ) do
		table.append( widgetFiles, VFS.DirList(subDirectory, "*.lua", vfsMode) )
	end

	for _, file in ipairs(widgetFiles) do
		local widget = widgetHandler:LoadWidget(file, fromZip)
		local excludeWidget = widget and not fromZip and zipOnly[widget.whInfo.name]

		if widget and not excludeWidget then
			table.insert(unsortedWidgets, widget)
			Yield()
		end
	end
end

local function CreateSandboxedSystem()
	local function disabledOrder()
		error("User 'unit control' widgets disallowed on this game", 2)
	end
	local SandboxedSpring = {}
	for k, v in pairs(Spring) do
		if string.find(k, '^GiveOrder') then
			SandboxedSpring[k] = disabledOrder
		else
			SandboxedSpring[k] = v
		end
	end
	for k, v in pairs(System) do
		if k == 'Spring' then
			SandboxedSystem[k] = SandboxedSpring
		else
			SandboxedSystem[k] = v
		end
	end
end

function widgetHandler:Initialize()
	widgetHandler:CreateQueuedReorderFuncs()
	widgetHandler:HookReorderSpecialFuncs()
	self:LoadConfigData()

	if self.allowUserWidgets == nil then
		self.allowUserWidgets = true
	end
	if self.allowUnitControlWidgets == nil then
		self.allowUnitControlWidgets = true
	end

	Spring.CreateDir(LUAUI_DIRNAME .. 'Config')

	unsortedWidgets = {}

	if self.allowUserWidgets and allowuserwidgets then
		if not (self.allowUnitControlWidgets and allowunitcontrolwidgets) then
			CreateSandboxedSystem()
		end

		Spring.Echo("LuaUI: Allowing User Widgets")
		loadWidgetFiles(WIDGET_DIRNAME, VFS.RAW)
		loadWidgetFiles(RML_WIDGET_DIRNAME, VFS.RAW)
	else
		Spring.Echo("LuaUI: Disallowing User Widgets")
	end

	loadWidgetFiles(WIDGET_DIRNAME, VFS.ZIP)
	loadWidgetFiles(RML_WIDGET_DIRNAME, VFS.ZIP)

	table.sort(unsortedWidgets, function(w1, w2)
		local l1 = w1.whInfo.layer
		local l2 = w2.whInfo.layer
		if l1 ~= l2 then
			return (l1 < l2)
		end
		local n1 = w1.whInfo.name
		local n2 = w2.whInfo.name
		local o1 = self.orderList[n1]
		local o2 = self.orderList[n2]
		if o1 ~= o2 then
			return (o1 < o2)
		else
			return (n1 < n2)
		end
	end)

	for _, w in ipairs(unsortedWidgets) do
		local name = w.whInfo.name
		local basename = w.whInfo.basename
		local source = self.knownWidgets[name].fromZip and "mod: " or "user:"
		Spring.Echo(string.format("Loading widget from %s  %-18s  <%s> ...", source, name, basename))
		Yield()
		widgetHandler:InsertWidgetRaw(w)
	end

	-- Since Initialize is run out of the normal callin wrapper by InsertWidget, we, need to reorder explicitly here.
	widgetHandler:PerformReorders()

	-- save the active widgets, and their ordering
	self:SaveConfigData()
end

function widgetHandler:AddSpadsMessage(contents)
	-- The canonical, agreed format is the following:
	-- This must be called from an unsynced context, cause it needs playername and playerid and stuff

	-- The game sends a lua message, which should be base64'd to prevent wierd character bullshit:
	-- Lua Message Format:
		-- leetspeek luaspads:base64message
		-- lu@$p@d$:ABCEDFGS==
		-- Must contain, with triangle bracket literals <playername>[space]<contents>[space]<gameseconds>
	-- will get parsed by barmanager, and forwarded to autohostmonitor as:
	-- match-event <UnnamedPlayer> <LuaUI\Widgets\test_unitshape_instancing.lua/czE3YEocdDJ8bLoO5++a2A==> <35>
	local myPlayerID = Spring.GetMyPlayerID()
	local myPlayerName = Spring.GetPlayerInfo(myPlayerID,false)
	local gameSeconds = math.max(0,math.round(Spring.GetGameFrame() / 30))
	if type(contents) == 'table' then
		contents = Json.encode(contents)
	end
	local rawmessage = string.format("<%s> <%s> <%d>", myPlayerName, contents, gameSeconds)
	local b64message = 'lu@$p@d$:' .. string.base64Encode(rawmessage)
	Spring.SendLuaRulesMsg(b64message)
end



function widgetHandler:LoadWidget(filename, fromZip, enableLocalsAccess)
	local basename = Basename(filename)
	local text = VFS.LoadFile(filename, not (self.allowUserWidgets and allowuserwidgets) and VFS.ZIP or VFS.RAW_FIRST)
	if text == nil then
		Spring.Echo('Failed to load: ' .. basename .. '  (missing file: ' .. filename .. ')')
		return nil
	end

	if enableLocalsAccess then
		-- enableLocalsAccess makes it so local variables within the widget can be accessed as if they were globals (as
		-- opposed to not being able to access them at all from outside the widget). This is accomplished by loading the
		-- widget with an additional code snippet to list all of the local variables, getting that result, and then
		-- loading again with a code snippet that sets up external access to those variables.
		localsAccess = localsAccess or VFS.Include('common/testing/locals_access.lua')

		local textWithLocalsDetector = text .. localsAccess.localsDetectorString

		local chunk, err = loadstring(textWithLocalsDetector, filename)
		if chunk == nil then
			Spring.Echo('Failed to load: ' .. basename .. '  (' .. err .. ')')
			return nil
		end

		local widget = widgetHandler:NewWidget(enableLocalsAccess, fromZip)
		setfenv(chunk, widget)
		local success, err = pcall(chunk)
		if not success then
			Spring.Echo('Failed to load: ' .. basename .. '  (' .. err .. ')')
			return nil
		end
		if err == false then
			return nil -- widget asked for a silent death
		end

		local localsNames = err

		text = text .. localsAccess.generateLocalsAccessStr(localsNames)
	end

	local chunk, err = loadstring(text, filename)
	if chunk == nil then
		Spring.Echo('Failed to load: ' .. basename .. '  (' .. err .. ')')
		return nil
	end

	local widget = widgetHandler:NewWidget(enableLocalsAccess, fromZip)
	setfenv(chunk, widget)
	local success, err = pcall(chunk)
	if not success then
		Spring.Echo('Failed to load: ' .. basename .. '  (' .. err .. ')')
		return nil
	end
	if err == false then
		return nil -- widget asked for a silent death
	end

	if enableLocalsAccess then
		setmetatable(widget, localsAccess.generateLocalsAccessMetatable(getmetatable(widget)))
	end

	-- user widgets may not access widgetHandler
	-- fixme: remove the or true part
	if widget.GetInfo and widget:GetInfo().handler then
		if fromZip or true then
			widget.widgetHandler = self
		else
			Spring.Echo('Failed to load: ' .. basename .. '  (user widgets may not access widgetHandler)', fromZip, filename, allowuserwidgets)
			return nil
		end
	end

	self:FinalizeWidget(widget, filename, basename)
	local name = widget.whInfo.name
	if basename == SELECTOR_BASENAME then
		self.orderList[name] = 1  -- always load the widget selector
	end

	err = self:ValidateWidget(widget)
	if err then
		Spring.Echo('Failed to load: ' .. basename .. '  (' .. err .. ')')
		return nil
	end

	local knownInfo = self.knownWidgets[name]
	if knownInfo then
		if knownInfo.active then
			Spring.Echo('Failed to load: ' .. basename .. '  (duplicate name)')
			return nil
		end
	else
		-- create a knownInfo table
		knownInfo = {}
		knownInfo.desc = widget.whInfo.desc
		knownInfo.author = widget.whInfo.author
		knownInfo.basename = widget.whInfo.basename
		knownInfo.filename = widget.whInfo.filename
		knownInfo.fromZip = fromZip
		self.knownWidgets[name] = knownInfo
		self.knownCount = self.knownCount + 1
		self.knownChanged = true
	end
	knownInfo.active = true

	if widget.GetInfo == nil then
		Spring.Echo('Failed to load: ' .. basename .. '  (no GetInfo() call)')
		return nil
	end

	-- Get widget information
	local info = widget:GetInfo()

	-- Enabling
	local order = self.orderList[name]
	if order then
		if order <= 0 then
			order = nil
		end
	else
		if info.enabled and (knownInfo.fromZip or (self.allowUserWidgets and not allowuserwidgets)) then
			order = 12345
		end
	end

	if order then
		self.orderList[name] = order
	else
		self.orderList[name] = 0
		self.knownWidgets[name].active = false
		return nil
	end
	if not fromZip then
		local md5 = VFS.CalculateHash(text,0)
		if widgetHandler.widgetHashes[md5] == nil then
			widgetHandler.widgetHashes[md5] = filename
		end
	end

	-- load the config data
	local config = self.configData[name]
	if widget.SetConfigData and config then
		widget:SetConfigData(config)
	end

	return widget
end

local WidgetMeta =
{
	__index = System,
	__metatable = true,
}

local SandboxedWidgetMeta =
{
	__index = SandboxedSystem,
	__metatable = true,
}

function widgetHandler:NewWidget(enableLocalsAccess, fromZip, filename)
	tracy.ZoneBeginN("W:NewWidget")
	local widget = {}
	local controlWidgetsEnabled = fromZip or (self.allowUnitControlWidgets and allowunitcontrolwidgets)

	if enableLocalsAccess then
		local systemRef = controlWidgetsEnabled and System or SandboxedSystem
		-- copy the system calls into the widget table
		for k, v in pairs(systemRef) do
			widget[k] = v
		end
	else
		local metaRef = controlWidgetsEnabled and WidgetMeta or SandboxedWidgetMeta
		-- use metatable redirection
		setmetatable(widget, metaRef)
	end

	widget.WG = self.WG    -- the shared table
	widget.widget = widget -- easy self referencing

	-- wrapped calls (closures)
	widget.widgetHandler = {}
	local wh = widget.widgetHandler
	widget.canControlUnits = controlWidgetsEnabled
	widget.include = function(f)
		return include(f, widget)
	end
	wh.RaiseWidget = function(_)
		self:RaiseWidget(widget)
	end
	wh.LowerWidget = function(_)
		self:LowerWidget(widget)
	end
	wh.RemoveWidget = function(_)
		self:RemoveWidget(widget)
	end
	wh.GetCommands = function(_)
		return self.commands
	end
	wh.GetViewSizes = function(_)
		return self:GetViewSizes()
	end
	wh.GetHourTimer = function(_)
		return self:GetHourTimer()
	end
	wh.IsMouseOwner = function(_)
		return (self.mouseOwner == widget)
	end
	wh.DisownMouse = function(_)
		if self.mouseOwner == widget then
			self.mouseOwner = nil
		end
	end
	wh.OwnText = function(_)
		if self.textOwner then
			return false
		end

		self.textOwner = widget

		return true
	end
	wh.DisownText = function(_)
		if self.textOwner == widget then
			self.textOwner = nil

			return true
		else
			return false
		end
	end

	wh.UpdateCallIn = function(_, name)
		self:UpdateWidgetCallIn(name, widget)
	end
	wh.RemoveCallIn = function(_, name)
		self:RemoveWidgetCallIn(name, widget)
	end

	wh.AddAction = function(_, cmd, func, data, types)
		return self.actionHandler:AddAction(widget, cmd, func, data, types)
	end
	wh.RemoveAction = function(_, cmd, types)
		return self.actionHandler:RemoveAction(widget, cmd, types)
	end

	wh.RegisterGlobal = function(_, name, value)
		return self:RegisterGlobal(widget, name, value)
	end
	wh.DeregisterGlobal = function(_, name)
		return self:DeregisterGlobal(widget, name)
	end
	wh.SetGlobal = function(_, name, value)
		return self:SetGlobal(widget, name, value)
	end
	tracy.ZoneEnd()
	return widget
end

function widgetHandler:FinalizeWidget(widget, filename, basename)
	local wi = {}

	wi.filename = filename
	wi.basename = basename
	if widget.GetInfo == nil then
		wi.name = basename
		wi.layer = 0
	else
		local info = widget:GetInfo()
		wi.name = info.name or basename
		wi.layer = info.layer or 0
		wi.desc = info.desc or ""
		wi.author = info.author or ""
		wi.license = info.license or ""
		wi.enabled = info.enabled or false
	end

	widget.whInfo = {}  --  a proxy table
	local mt = {
		__index = wi,
		__newindex = function()
			error("whInfo tables are read-only")
		end,
		__metatable = "protected"
	}
	setmetatable(widget.whInfo, mt)
end

function widgetHandler:ValidateWidget(widget)
	if widget.GetTooltip and not widget.IsAbove then
		return "Widget has GetTooltip() but not IsAbove()"
	end
	return nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SafeWrapFuncNoGL(func, funcName)
	return function(w, ...)
		-- New method avoids needless table creation, but is limited to at most 2 return values per callin!
		local r1, r2, r3 = pcall(func, w, ...)
		if r1 then
			return r2, r3
		else
			if funcName ~= 'Shutdown' then
				widgetHandler:RemoveWidget(w)
			else
				Spring.Echo('Error in Shutdown()')
			end
			local name = w.whInfo.name
			Spring.Echo('Error in ' .. funcName .. '(): ' .. tostring(r2))
			Spring.Echo('Removed widget: ' .. name)
			return nil
		end
	end
end

local function SafeWrapFuncGL(func, funcName)
	return function(w, ...)
		glPushAttrib(GL.ALL_ATTRIB_BITS)
		glPopAttrib()
		local r = { pcall(func, w, ...) }
		if r[1] then
			table.remove(r, 1)
			return unpack(r)
		else
			if funcName ~= 'Shutdown' then
				widgetHandler:RemoveWidget(w)
			else
				Spring.Echo('Error in Shutdown()')
			end
			local name = w.whInfo.name
			Spring.Echo('Error in ' .. funcName .. '(): ' .. tostring(r[2]))
			Spring.Echo('Removed widget: ' .. name)
			return nil
		end
	end
end

local function SafeWrapFunc(func, funcName)
	if not SAFEDRAW then
		return SafeWrapFuncNoGL(func, funcName)
	else
		if string.sub(funcName, 1, 4) ~= 'Draw' then
			return SafeWrapFuncNoGL(func, funcName)
		else
			return SafeWrapFuncGL(func, funcName)
		end
	end
end

local function SafeWrapWidget(widget)
	if SAFEWRAP <= 0 then
		return
	elseif SAFEWRAP == 1 then
		if widget.GetInfo and widget.GetInfo().unsafe then
			Spring.Echo('LuaUI: loaded unsafe widget: ' .. widget.whInfo.name)
			return
		end
	end

	for _, ciName in ipairs(callInLists) do
		if widget[ciName] then
			widget[ciName] = SafeWrapFunc(widget[ciName], ciName)
		end
	end

	if widget.Initialize then
		widget.Initialize = SafeWrapFunc(widget.Initialize, 'Initialize')
	end
end


--------------------------------------------------------------------------------

local function ArrayInsert(t, f, w)
	if f then
		local layer = w.whInfo.layer
		local index = 1
		for i, v in ipairs(t) do
			if v == w then
				return -- already in the table
			end
			if layer >= v.whInfo.layer then
				index = i + 1
			end
		end
		table.insert(t, index, w)
	end
end

---Removes all elements equal to value from given array.
---@generic V
---@param t V[]
---@param value V
local function ArrayRemove(t, value)
	for i = #t, 1, -1 do
		if t[i] == value then
			table.remove(t, i)
		end
	end
end


--------------------------------------------------------------------------------
--- Safe reordering

-- Since we are traversing lists, some of the widgetHandler api would be dangerous to use.
--
-- We will queue all the dangerous methods to process after callin loop finishes iterating.
-- The 'real' methods have 'Raw' appended to them, and are unsafe to use unless you know what
-- you are doing.

local reorderQueue = {}
local reorderNeeded = false
local reorderFuncs = {}
local callinDepth = 0

function widgetHandler:HookReorderSpecialFuncs()
	-- Methods that need manual PerformReorders calls because of not
	-- being wrapped by UpdateCallIns.
	self:HookReorderPost('DrawScreen', true)
	self:HookReorderPost('Update', true)
	self:HookReorderPost('MouseMove')
	self:HookReorderPost('MouseRelease')
	self:HookReorderPost('ConfigureLayout')
end

function widgetHandler:HookReorderPost(name, topMethod)
	-- Add callinDepth updating and PerformReorders to methods not getting it through UpdateCallIns.
	-- Can only be used for methods returning just one result.
	-- We define some methods to be topMethod, those will hard set the callinDepth as a consistency
	-- measure.
	local func = self[name]
	if not func or not type(func) == 'function' then
		Spring.Log("barwidgets.lua", LOG.WARNING, name .. " does not exist or isn't a function")
		return
	end
	if self[name .. 'Raw'] then
		Spring.Log("barwidgets.lua", LOG.WARNING, name .. "Raw already exists")
		return
	end
	self[name .. 'Raw'] = func
	self[name] = function(...)
		callinDepth = topMethod and 1 or callinDepth + 1
		local res = func(...)
		callinDepth = topMethod and 0 or callinDepth - 1

		if reorderNeeded and callinDepth == 0 then
			self:PerformReorders()
		end
		return res
	end
end

function widgetHandler:CreateQueuedReorderFuncs()
	-- This will create an array with linked Raw methods so we can find them by index.
	-- It will also create the widgetHandler usual api queing the calls.
	local reorderFuncNames = {'InsertWidget', 'RemoveWidget', 'EnableWidget', 'DisableWidget',
		'ToggleWidget', 'LowerWidget', 'RaiseWidget', 'UpdateWidgetCallIn', 'RemoveWidgetCallIn'}
	local queueReorder = widgetHandler.QueueReorder

	for idx, name in ipairs(reorderFuncNames) do
		-- linked method index
		reorderFuncs[#reorderFuncs + 1] = widgetHandler[name .. 'Raw']

		-- widgetHandler api
		widgetHandler[name] = function(s, ...)
			queueReorder(s, idx, ...)
		end
	end
end

function widgetHandler:QueueReorder(methodIndex, ...)
	reorderQueue[#reorderQueue + 1] = {methodIndex, ...}
	reorderNeeded = true
end

function widgetHandler:PerformReorder(methodIndex, ...)
	reorderFuncs[methodIndex](self, ...)
end

function widgetHandler:PerformReorders()
	-- Reset and store the list so we can support nested reorderings
	reorderNeeded = false
	local nextReorder = reorderQueue
	reorderQueue = {}
	-- Process the reorder queue
	for _, elmts in ipairs(nextReorder) do
		self:PerformReorder(unpack(elmts))
	end
	-- Check for further reordering
	if reorderNeeded then
		self:PerformReorders()
	end
end

--------------------------------------------------------------------------------
--- Unsafe insert/remove


function widgetHandler:InsertWidgetRaw(widget)
	if widget == nil then
		return
	end
	if widget.GetInfo and not Platform.check(widget:GetInfo().depends) then
		local name = widget.whInfo.name
		if self.knownWidgets[name] then
			self.knownWidgets[name].active = false
		end
		Spring.Echo('Missing capabilities:  ' .. name .. '. Disabling.')
		return
	end
	-- Gracefully ignore good control widgets advertising themselves as such, if user 'unit control' widgets disabled.
	if widget.GetInfo and widget:GetInfo().control and not widget.canControlUnits then
		local name = widget.whInfo.name
		Spring.Echo('Blocked loading: ' .. name .. "  (user 'unit control' widgets disabled for this game)")
		return
	end

	SafeWrapWidget(widget)

	ArrayInsert(self.widgets, true, widget)
	for _, listname in ipairs(callInLists) do
		local func = widget[listname]
		if type(func) == 'function' then
			ArrayInsert(self[listname .. 'List'], func, widget)
		end
	end
	self:UpdateCallIns()

	if widget.Initialize then
		widget:Initialize()
	end
end

function widgetHandler:RemoveWidgetRaw(widget)
	if widget == nil or widget.whInfo == nil then
		return
	end
	if not Platform.check(widget.whInfo.depends) then
		return
	end

	if self.textOwner == widget then
		self.textOwner = nil
	end

	local name = widget.whInfo.name
	if widget.GetConfigData then
		self.configData[name] = widget:GetConfigData()
	end
	self.knownWidgets[name].active = false
	if widget.Shutdown then
		widget:Shutdown()
	end
	ArrayRemove(self.widgets, widget)
	self:RemoveWidgetGlobals(widget)
	self.actionHandler:RemoveWidgetActions(widget)
	for _, listname in ipairs(callInLists) do
		ArrayRemove(self[listname .. 'List'], widget)
	end
	self:UpdateCallIns()
end

--------------------------------------------------------------------------------

function widgetHandler:UpdateCallIn(name)
	local listName = name .. 'List'
	if name == 'Update' or	name == 'DrawScreen' then
		return
	end
	if #self[listName] > 0 or not flexCallInMap[name] or (name == 'GotChatMsg' and actionHandler.HaveChatAction()) or (name == 'RecvFromSynced' and actionHandler.HaveSyncAction()) then
		-- always assign these call-ins
		local selffunc = self[name]

		-- max two return parameters for top level callins!
		_G[name] = function(...)
			callinDepth = callinDepth + 1

			local res1, res2 = selffunc(self, ...)

			callinDepth = callinDepth - 1

			if reorderNeeded and callinDepth == 0 then
				self:PerformReorders()
			end

			return res1, res2
		end
	else
		_G[name] = nil
	end
	Script.UpdateCallIn(name)
end

function widgetHandler:UpdateWidgetCallInRaw(name, w)
	local listName = name .. 'List'
	local ciList = self[listName]
	if ciList then
		local func = w[name]
		if type(func) == 'function' then
			ArrayInsert(ciList, func, w)
		else
			ArrayRemove(ciList, w)
		end
		self:UpdateCallIn(name)
	else
		Spring.Echo('UpdateWidgetCallIn: bad name: ' .. name)
	end
end

function widgetHandler:RemoveWidgetCallInRaw(name, w)
	local listName = name .. 'List'
	local ciList = self[listName]
	if ciList then
		ArrayRemove(ciList, w)
		self:UpdateCallIn(name)
	else
		Spring.Echo('RemoveWidgetCallIn: bad name: ' .. name)
	end
end

function widgetHandler:UpdateCallIns()
	for _, name in ipairs(callInLists) do
		self:UpdateCallIn(name)
	end
end

--------------------------------------------------------------------------------

function widgetHandler:IsWidgetKnown(name)
	return self.knownWidgets[name] and true or false
end

function widgetHandler:EnableWidgetRaw(name, enableLocalsAccess)
	local ki = self.knownWidgets[name]
	if not ki then
		Spring.Echo("EnableWidget(), could not find widget: " .. tostring(name))
		return false
	end
	if not ki.active then
		Spring.Echo('Loading:  ' .. ki.filename .. (enableLocalsAccess and " (with locals)" or ""))
		local order = widgetHandler.orderList[name]
		if not order or order <= 0 then
			self.orderList[name] = 1
		end
		local w = self:LoadWidget(ki.filename, ki.fromZip, enableLocalsAccess)
		if not w then
			return false
		end
		self:InsertWidgetRaw(w)
		self:SaveConfigData()
	end
	return true
end

function widgetHandler:DisableWidgetRaw(name)
	local ki = self.knownWidgets[name]
	if not ki then
		Spring.Echo("DisableWidget(), could not find widget: " .. tostring(name))
		return false
	end
	if ki.active then
		local w = self:FindWidget(name)
		if not w then
			return false
		end
		Spring.Echo('Removed:  ' .. ki.filename)
		self:RemoveWidgetRaw(w)     -- deactivate
		self.orderList[name] = 0 -- disable
		self:SaveConfigData()
	end
	return true
end

function widgetHandler:ToggleWidgetRaw(name)
	local ki = self.knownWidgets[name]
	if not ki then
		Spring.Echo("ToggleWidget(), could not find widget: " .. tostring(name))
		return
	end
	if ki.active then
		return self:DisableWidgetRaw(name)
	elseif self.orderList[name] <= 0 then
		return self:EnableWidgetRaw(name)
	else
		-- the widget is not active, but enabled; disable it
		self.orderList[name] = 0
		self:SaveConfigData()
	end
	return true
end


--------------------------------------------------------------------------------

local function FindWidgetIndex(t, w)
	for k, v in ipairs(t) do
		if v == w then
			return k
		end
	end
	return nil
end

local function FindLowestIndex(t, i, layer)
	for x = (i - 1), 1, -1 do
		if t[x].whInfo.layer < layer then
			return x + 1
		end
	end
	return 1
end

function widgetHandler:RaiseWidgetRaw(widget)
	if widget == nil then
		return
	end
	local function Raise(t, f, w)
		if f == nil then
			return
		end
		local i = FindWidgetIndex(t, w)
		if i == nil then
			return
		end
		local n = FindLowestIndex(t, i, w.whInfo.layer)
		if n and n < i then
			table.remove(t, i)
			table.insert(t, n, w)
		end
	end
	Raise(self.widgets, true, widget)
	for _, listname in ipairs(callInLists) do
		Raise(self[listname .. 'List'], widget[listname], widget)
	end
end

local function FindHighestIndex(t, i, layer)
	local ts = #t
	for x = (i + 1), ts do
		if t[x].whInfo.layer > layer then
			return (x - 1)
		end
	end
	return ts
end

function widgetHandler:LowerWidgetRaw(widget)
	if widget == nil then
		return
	end
	local function Lower(t, f, w)
		if f == nil then
			return
		end
		local i = FindWidgetIndex(t, w)
		if i == nil then
			return
		end
		local n = FindHighestIndex(t, i, w.whInfo.layer)
		if n and n > i then
			table.insert(t, n+1, w)
			table.remove(t, i)
		end
	end
	Lower(self.widgets, true, widget)
	for _, listname in ipairs(callInLists) do
		Lower(self[listname .. 'List'], widget[listname], widget)
	end
end

function widgetHandler:FindWidget(name)
	if type(name) ~= 'string' then
		return nil
	end
	for k, v in ipairs(self.widgets) do
		if name == v.whInfo.name then
			return v, k
		end
	end
	return nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Global var/func management
--

function widgetHandler:RegisterGlobal(owner, name, value)
	if name == nil or _G[name] or self.globals[name] or CallInsMap[name] then
		return false
	end
	_G[name] = value
	self.globals[name] = owner
	return true
end

function widgetHandler:DeregisterGlobal(owner, name)
	if name == nil then
		return false
	end
	_G[name] = nil
	self.globals[name] = nil
	return true
end

function widgetHandler:SetGlobal(owner, name, value)
	if name == nil or self.globals[name] ~= owner then
		return false
	end
	_G[name] = value
	return true
end

function widgetHandler:RemoveWidgetGlobals(owner)
	local count = 0
	for name, o in pairs(self.globals) do
		if o == owner then
			_G[name] = nil
			self.globals[name] = nil
			count = count + 1
		end
	end
	return count
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Helper facilities
--

local hourTimer = 0

function widgetHandler:GetHourTimer()
	return hourTimer
end

function widgetHandler:GetViewSizes()
	return self.xViewSize, self.yViewSize
end

function widgetHandler:ConfigLayoutHandler(data)
	ConfigLayoutHandler(data)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  The call-in distribution routines
--

function widgetHandler:Shutdown()
	-- record if we will allow user widgets on next load
	if self.__allowUserWidgets ~= nil then
		self.allowUserWidgets = self.__allowUserWidgets
	end

	if self.__allowUnitControlWidgets ~= nil then
		self.allowUnitControlWidgets = self.__allowUnitControlWidgets
	end

	-- save config
	if self.__blankOutConfig then
		local saveData = { ["allowUserWidgets"] = self.allowUserWidgets, ["allowUnitControlWidgets"] = self.allowUnitControlWidgets }
		table.save(saveData, CONFIG_FILENAME, '-- Widget Custom data and order')
	else
		self:SaveConfigData()
	end

	for _, w in ipairs(self.ShutdownList) do
		w:Shutdown()
	end
	return
end

function widgetHandler:BlankOut()
	for _, w in ipairs(self.ShutdownList) do
		w:Shutdown()
	end
end


function widgetHandler:Update()

	if collectgarbage("count") > 1200000 then
		Spring.Echo("Warning: Emergency garbage collection due to exceeding 1.2GB LuaRAM")
		collectgarbage("collect")
	end

	local deltaTime = Spring.GetLastUpdateSeconds()
	-- update the hour timer
	hourTimer = (hourTimer + deltaTime) % 3600.0
	tracy.ZoneBeginN("W:Update")
	for _, w in ipairs(self.UpdateList) do
		tracy.ZoneBeginN("W:Update:" .. w.whInfo.name)
		w:Update(deltaTime)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:ConfigureLayout(command)

	if command == 'reconf' then
		self:SendConfigData()
		return true
	elseif command == 'selector' then
		for _, w in ipairs(self.widgets) do
			if w.whInfo.basename == SELECTOR_BASENAME then
				return true  -- there can only be one
			end
		end
		local sw = self:LoadWidget(LUAUI_DIRNAME .. SELECTOR_BASENAME, true) -- load the game's included widget_selector.lua, instead of the default selector.lua
		self:InsertWidgetRaw(sw)
		self:RaiseWidgetRaw(sw)
		return true
	elseif string.find(command, 'togglewidget') == 1 then
		self:ToggleWidgetRaw(string.sub(command, 14))
		return true
	elseif string.find(command, 'enablewidget') == 1 then
		self:EnableWidgetRaw(string.sub(command, 14))
		return true
	elseif string.find(command, 'disablewidget') == 1 then
		self:DisableWidgetRaw(string.sub(command, 15))
		return true
	end

	if self.actionHandler:TextAction(command) then
		return true
	end

	for _, w in ipairs(self.TextCommandList) do
		if w:TextCommand(command) then
			return true
		end
	end
	return false
end

function widgetHandler:ActiveCommandChanged(id, cmdType)
	tracy.ZoneBeginN("W:ActiveCommandChanged")
	for _, w in ipairs(self.ActiveCommandChangedList) do
		w:ActiveCommandChanged(id, cmdType)
	end
	tracy.ZoneEnd()
end

function widgetHandler:CameraRotationChanged(rotx, roty, rotz)
	tracy.ZoneBeginN("W:CameraRotationChanged")
	for _,w in ipairs(self.CameraRotationChangedList) do
		w:CameraRotationChanged(rotx, roty, rotz)
	end
	tracy.ZoneEnd()
end

function widgetHandler:CameraPositionChanged(posx, posy, posz)
	tracy.ZoneBeginN("W:CameraPositionChanged")
	for _,w in ipairs(self.CameraPositionChangedList) do
		w:CameraPositionChanged(posx, posy, posz)
	end
	tracy.ZoneEnd()
end

function widgetHandler:CommandNotify(id, params, options)
	tracy.ZoneBeginN("W:CommandNotify")
	for _, w in ipairs(self.CommandNotifyList) do
		if w:CommandNotify(id, params, options) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:AddConsoleLine(msg, priority)
	tracy.ZoneBeginN("W:AddConsoleLine")
	for _, w in ipairs(self.AddConsoleLineList) do
		w:AddConsoleLine(msg, priority)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:GroupChanged(groupID)
	tracy.ZoneBeginN("W:GroupChanged")
	for _, w in ipairs(self.GroupChangedList) do
		w:GroupChanged(groupID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:CommandsChanged()
	tracy.ZoneBeginN("W:CommandsChanged")
	if widgetHandler:UpdateSelection() then
		-- for selectionchanged
		tracy.ZoneEnd()
		return -- selection updated, don't call commands changed.
	end
	self.inCommandsChanged = true
	self.customCommands = {}
	for _, w in ipairs(self.CommandsChangedList) do
		w:CommandsChanged()
	end
	self.inCommandsChanged = false
	tracy.ZoneEnd()
	return
end


--------------------------------------------------------------------------------
--
--  Drawing call-ins
--


-- generates ViewResize() calls for the widgets
function widgetHandler:SetViewSize(vsx, vsy)
	tracy.ZoneBeginN("W:SetViewSize")
	self.xViewSize = vsx
	self.yViewSize = vsy
	if self.xViewSizeOld ~= vsx or self.yViewSizeOld ~= vsy then
		widgetHandler:ViewResize(vsx, vsy)
		self.xViewSizeOld = vsx
		self.yViewSizeOld = vsy
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:ViewResize(vsx, vsy)
	if type(vsx) == 'table' then
		vsy = vsx.viewSizeY
		vsx = vsx.viewSizeX
		print('real ViewResize') -- FIXME
	end

	tracy.ZoneBeginN("W:ViewResize")
	if widgetHandler.WG.FlowUI then
		tracy.ZoneBeginN("W:ViewResize:FlowUI")
		widgetHandler.WG.FlowUI.Callin.ViewResize1(vsx, vsy)
		tracy.ZoneEnd()
	end
	for _, w in ipairs(self.ViewResizeList) do
		tracy.ZoneBeginN("W:ViewResize:" .. w.whInfo.name)
		w:ViewResize(vsx, vsy)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end


function widgetHandler:DrawScreen()
	if (not Spring.GetSpectatingState()) and anonymousMode ~= "disabled" then
		Spring.SendCommands("info 0")
	end
	tracy.ZoneBeginN("W:DrawScreen")
	if not Spring.IsGUIHidden() then
		if not self.chobbyInterface  then
			for _, w in r_ipairs(self.DrawScreenList) do
				tracy.ZoneBeginN("W:DrawScreen:" .. w.whInfo.name)
				w:DrawScreen()
				tracy.ZoneEnd()
			end
		elseif widgetHandler.WG.guishader and widgetHandler.WG.guishader.DrawScreen then
			tracy.ZoneBeginN("W:DrawScreen:guishader")
			widgetHandler.WG.guishader.DrawScreen()
			tracy.ZoneEnd()
		end
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawGenesis()
	tracy.ZoneBeginN("W:DrawGenesis")
	for _, w in r_ipairs(self.DrawGenesisList) do
		w:DrawGenesis()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawGroundDeferred()
	tracy.ZoneBeginN("W:DrawGroundDeferred")
	for _, w in r_ipairs(self.DrawGroundDeferredList) do
		w:DrawGroundDeferred()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawWorld()
	tracy.ZoneBeginN("W:DrawWorld")
	if not self.chobbyInterface  then
		for _, w in r_ipairs(self.DrawWorldList) do
			tracy.ZoneBeginN("W:DrawWorld:" .. w.whInfo.name)
			w:DrawWorld()
			tracy.ZoneEnd()
		end
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawWorldPreUnit()
	tracy.ZoneBeginN("W:DrawWorldPreUnit")
	if not self.chobbyInterface  then
		for _, w in r_ipairs(self.DrawWorldPreUnitList) do
			tracy.ZoneBeginN("W:DrawWorldPreUnit:" .. w.whInfo.name)
			w:DrawWorldPreUnit()
			tracy.ZoneEnd()
		end
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawOpaqueUnitsLua(deferredPass, drawReflection, drawRefraction)
	tracy.ZoneBeginN("W:DrawOpaqueUnitsLua")
	for _, w in r_ipairs(self.DrawOpaqueUnitsLuaList) do
		w:DrawOpaqueUnitsLua(deferredPass, drawReflection, drawRefraction)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawOpaqueFeaturesLua(deferredPass, drawReflection, drawRefraction)
	tracy.ZoneBeginN("W:DrawOpaqueFeaturesLua")
	for _, w in r_ipairs(self.DrawOpaqueFeaturesLuaList) do
		w:DrawOpaqueFeaturesLua(deferredPass, drawReflection, drawRefraction)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	tracy.ZoneBeginN("W:DrawAlphaUnitsLua")
	for _, w in r_ipairs(self.DrawAlphaUnitsLuaList) do
		w:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	tracy.ZoneBeginN("W:DrawAlphaFeaturesLua")
	for _, w in r_ipairs(self.DrawAlphaFeaturesLuaList) do
		w:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawShadowUnitsLua()
	tracy.ZoneBeginN("W:DrawShadowUnitsLua")
	for _, w in r_ipairs(self.DrawShadowUnitsLuaList) do
		w:DrawShadowUnitsLua()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawShadowFeaturesLua()
	tracy.ZoneBeginN("W:DrawShadowFeaturesLua")
	for _, w in r_ipairs(self.DrawShadowFeaturesLuaList) do
		w:DrawShadowFeaturesLua()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawPreDecals()
	tracy.ZoneBeginN("W:DrawPreDecals")
	for _, w in r_ipairs(self.DrawPreDecalsList) do
		w:DrawPreDecals()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawWorldPreParticles(drawAboveWater, drawBelowWater, drawReflection, drawRefraction)
	-- NOTE: This is called TWICE per draw frame, once before water and once after, even if no water is present. The second is the refraction pass.
	-- drawAboveWater, drawBelowWater, drawReflection, drawRefraction
	-- 1. false, 			true, 			false, 			false 
	-- 2. true, 			false, 			true, 			false
	-- 3. true, 			false, 			false, 			false

	-- When refractions are on:
	-- false, true, false, false
	-- false, true, false, true
	-- true, false, true, false
	-- true, false, false, false
	tracy.ZoneBeginN("W:DrawWorldPreParticles")
	for _, w in r_ipairs(self.DrawWorldPreParticlesList) do
		w:DrawWorldPreParticles(drawAboveWater, drawBelowWater, drawReflection, drawRefraction)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawWorldShadow()
	tracy.ZoneBeginN("W:DrawWorldShadow")
	for _, w in r_ipairs(self.DrawWorldShadowList) do
		w:DrawWorldShadow()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawWorldReflection()
	tracy.ZoneBeginN("W:DrawWorldReflection")
	for _, w in r_ipairs(self.DrawWorldReflectionList) do
		w:DrawWorldReflection()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawWorldRefraction()
	tracy.ZoneBeginN("W:DrawWorldRefraction")
	for _, w in r_ipairs(self.DrawWorldRefractionList) do
		w:DrawWorldRefraction()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawUnitsPostDeferred()
	tracy.ZoneBeginN("W:DrawUnitsPostDeferred")
	for _, w in r_ipairs(self.DrawUnitsPostDeferredList) do
		w:DrawUnitsPostDeferred()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawFeaturesPostDeferred()
	tracy.ZoneBeginN("W:DrawFeaturesPostDeferred")
	for _, w in r_ipairs(self.DrawFeaturesPostDeferredList) do
		w:DrawFeaturesPostDeferred()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawScreenEffects(vsx, vsy)
	tracy.ZoneBeginN("W:DrawScreenEffects")
	for _, w in r_ipairs(self.DrawScreenEffectsList) do
		tracy.ZoneBeginN("W:DrawScreenEffects:" .. w.whInfo.name)
		w:DrawScreenEffects(vsx, vsy)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawScreenPost()
	tracy.ZoneBeginN("W:DrawScreenPost")
	for _, w in r_ipairs(self.DrawScreenPostList) do
		tracy.ZoneBeginN("W:DrawScreenPost:" .. w.whInfo.name)
		w:DrawScreenPost()
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawInMiniMap(xSize, ySize)
	tracy.ZoneBeginN("W:DrawInMiniMap")
	for _, w in r_ipairs(self.DrawInMiniMapList) do
		w:DrawInMiniMap(xSize, ySize)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:SunChanged()
	tracy.ZoneBeginN("W:SunChanged")
	local nmp = _G['NightModeParams']
	for _, w in r_ipairs(self.SunChangedList) do
		w:SunChanged(nmp)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:FontsChanged()
	tracy.ZoneBeginN("FontsChanged")
	for _, w in r_ipairs(self.FontsChangedList) do
		w:FontsChanged()
	end
	tracy.ZoneEnd()
	return
end

--------------------------------------------------------------------------------
--
--  Keyboard call-ins
--

function widgetHandler:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
	tracy.ZoneBeginN("W:KeyPress")
	local textOwner = self.textOwner

	if textOwner then
		if (not textOwner.KeyPress) or textOwner:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions) then
			tracy.ZoneEnd()
			return true
		end
	end

	if self.actionHandler:KeyAction(true, key, mods, isRepeat, scanCode, actions) then
		tracy.ZoneEnd()
		return true
	end

	for _, w in ipairs(self.KeyPressList) do
		if w:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:KeyRelease(key, mods, label, unicode, scanCode, actions)
	tracy.ZoneBeginN("W:KeyRelease")
	local textOwner = self.textOwner

	if textOwner then
		if (not textOwner.KeyRelease) or textOwner:KeyRelease(key, mods, label, unicode, scanCode, actions) then
			tracy.ZoneEnd()
			return true
		end
	end

	if self.actionHandler:KeyAction(false, key, mods, false, scanCode, actions) then
		tracy.ZoneEnd()
		return true
	end

	for _, w in ipairs(self.KeyReleaseList) do
		if w:KeyRelease(key, mods, label, unicode, scanCode, actions) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:TextInput(utf8, ...)
	tracy.ZoneBeginN("W:TextInput")
	local textOwner = self.textOwner

	if textOwner then
		if textOwner.TextInput then
			textOwner:TextInput(utf8, ...)
		end

		tracy.ZoneEnd()
		return true
	end

	for _, w in r_ipairs(self.TextInputList) do
		if w:TextInput(utf8, ...) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

--------------------------------------------------------------------------------
--
--  Mouse call-ins
--

-- local helper (not a real call-in)
function widgetHandler:WidgetAt(x, y)
	tracy.ZoneBeginN("W:WidgetAt")
	for _, w in ipairs(self.IsAboveList) do
		if w:IsAbove(x, y) then
			tracy.ZoneEnd()
			return w
		end
	end
	tracy.ZoneEnd()
	return nil
end

function widgetHandler:MousePress(x, y, button)
	tracy.ZoneBeginN("W:MousePress")
	if self.mouseOwner then
		self.mouseOwner:MousePress(x, y, button)
	else
		for _, w in ipairs(self.MousePressList) do
			if w:MousePress(x, y, button) then
				self.mouseOwner = w
				break
			end
		end
	end

	local hasMouseOwner = self.mouseOwner ~= nil
	if widgetHandler.WG.SmartSelect_MousePress2 then
		widgetHandler.WG.SmartSelect_MousePress2(x, y, button, hasMouseOwner)
	end

	tracy.ZoneEnd()
	return hasMouseOwner
end

function widgetHandler:MouseMove(x, y, dx, dy, button)
	tracy.ZoneBeginN("W:MouseMove")
	local mo = self.mouseOwner
	if mo and mo.MouseMove then
		tracy.ZoneEnd()
		return mo:MouseMove(x, y, dx, dy, button)
	end
	tracy.ZoneEnd()
end

function widgetHandler:MouseRelease(x, y, button)
	tracy.ZoneBeginN("W:MouseRelease")
	local mo = self.mouseOwner
	local _, _, lmb, mmb, rmb = Spring.GetMouseState()
	if not (lmb or mmb or rmb) then
		self.mouseOwner = nil
	end

	if mo and mo.MouseRelease then
		tracy.ZoneEnd()
		return mo:MouseRelease(x, y, button)
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:MouseWheel(up, value)
	tracy.ZoneBeginN("W:MouseWheel")
	for _, w in ipairs(self.MouseWheelList) do
		if w:MouseWheel(up, value) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:ControllerAdded(deviceIndex)
	tracy.ZoneBeginN("W:ControllerAdded")
	for _, w in ipairs(self.ControllerAddedList) do
		if w:ControllerAdded(deviceIndex) then
			tracy.ZoneEnd()
			return true
		end
	end

	tracy.ZoneEnd()
	return false
end

function widgetHandler:ControllerRemoved(instanceId)
	tracy.ZoneBeginN("W:ControllerRemoved")
	for _, w in ipairs(self.ControllerRemovedList) do
		if w:ControllerRemoved(instanceId) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:ControllerConnected(instanceId)
	tracy.ZoneBeginN("W:ControllerConnected")
	for _, w in ipairs(self.ControllerConnectedList) do
		if w:ControllerConnected(instanceId) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:ControllerDisconnected(instanceId)
	tracy.ZoneBeginN("W:ControllerDisconnected")
	for _, w in ipairs(self.ControllerDisconnectedList) do
		if w:ControllerDisconnected(instanceId) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:ControllerRemapped(instanceId)
	tracy.ZoneBeginN("W:ControllerRemapped")
	for _, w in ipairs(self.ControllerRemappedList) do
		if w:ControllerRemapped(instanceId) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:ControllerButtonUp(instanceId, button, state, name)
	tracy.ZoneBeginN("W:ControllerButtonUp")
	for _, w in ipairs(self.ControllerButtonUpList) do
		if w:ControllerButtonUp(instanceId, button, state, name) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:ControllerButtonDown(instanceId, button, state, name)
	tracy.ZoneBeginN("W:ControllerButtonDown")
	for _, w in ipairs(self.ControllerButtonDownList) do
		if w:ControllerButtonDown(instanceId, button, state, name) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:ControllerAxisMotion(instanceId, axis, value, name)
	tracy.ZoneBeginN("W:ControllerAxisMotion")
	for _, w in ipairs(self.ControllerAxisMotionList) do
		if w:ControllerAxisMotion(instanceId, axis, value, name) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:IsAbove(x, y)
	return (widgetHandler:WidgetAt(x, y) ~= nil)
end

function widgetHandler:GetTooltip(x, y)
	tracy.ZoneBeginN("W:GetTooltip")
	for _, w in ipairs(self.GetTooltipList) do
		if w:IsAbove(x, y) then
			local tip = w:GetTooltip(x, y)
			if type(tip) == 'string' and #tip > 0 then
				tracy.ZoneEnd()
				return tip
			end
		end
	end
	tracy.ZoneEnd()
	return ""
end


--------------------------------------------------------------------------------
--
--  Game call-ins
--

function widgetHandler:GamePreload()
	tracy.ZoneBeginN("W:GamePreload")
	for _, w in ipairs(self.GamePreloadList) do
		w:GamePreload()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:GameStart()
	tracy.ZoneBeginN("W:GameStart")
	for _, w in ipairs(self.GameStartList) do
		tracy.ZoneBeginN("W:GameStart:" .. w.whInfo.name)
		w:GameStart()
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:GameOver()
	tracy.ZoneBeginN("W:GameOver")
	for _, w in ipairs(self.GameOverList) do
		w:GameOver()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:GamePaused(playerID, paused)
	tracy.ZoneBeginN("W:GamePaused")
	for _, w in ipairs(self.GamePausedList) do
		w:GamePaused(playerID, paused)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:TeamDied(teamID)
	tracy.ZoneBeginN("W:TeamDied")
	for _, w in ipairs(self.TeamDiedList) do
		w:TeamDied(teamID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:TeamChanged(teamID)
	tracy.ZoneBeginN("W:TeamChanged")
	for _, w in ipairs(self.TeamChangedList) do
		w:TeamChanged(teamID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:PlayerAdded(playerID)
	tracy.ZoneBeginN("W:PlayerAdded")
	for _, w in ipairs(self.PlayerAddedList) do
		w:PlayerAdded(playerID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:PlayerRemoved(playerID, reason)
	tracy.ZoneBeginN("W:PlayerRemoved")
	for _, w in ipairs(self.PlayerRemovedList) do
		w:PlayerRemoved(playerID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:PlayerChanged(playerID)
	tracy.ZoneBeginN("W:PlayerChanged")
	for _, w in ipairs(self.PlayerChangedList) do
		tracy.ZoneBeginN("W:PlayerChanged:" .. w.whInfo.name)
		w:PlayerChanged(playerID)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:GameFrame(frameNum)
	tracy.ZoneBeginN("W:GameFrame")
	for _, w in ipairs(self.GameFrameList) do
		tracy.ZoneBeginN("W:GameFrame:" .. w.whInfo.name)
		w:GameFrame(frameNum)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

-- local helper (not a real call-in)
local oldSelection = {}
function widgetHandler:UpdateSelection()
	tracy.ZoneBeginN("W:UpdateSelection")
	local changed
	local newSelection = Spring.GetSelectedUnits()
	if #newSelection == #oldSelection then
		for i = 1, #oldSelection do
			if newSelection[i] ~= oldSelection[i] then
				-- it seems the order stays
				changed = true
				break
			end
		end
	else
		changed = true
	end
	if changed then
		local subselection = true
		if #newSelection > #oldSelection then
			subselection = false
		else
			local oldSelectionMap = {}
			for i = 1, #oldSelection do
				oldSelectionMap[oldSelection[i]] = true
			end
			for i = 1, #newSelection do
				if not oldSelectionMap[newSelection[i]] then
					subselection = false
					break
				end
			end
		end
		if widgetHandler:SelectionChanged(newSelection, subselection) then
			-- selection changed, don't set old selection to new selection as it is soon to change.
			tracy.ZoneEnd()
			return true
		end
	end
	oldSelection = newSelection

	tracy.ZoneEnd()
	return false
end

function widgetHandler:SelectionChanged(selectedUnits, subselection)
	tracy.ZoneBeginN("W:SelectionChanged")
	for _, w in ipairs(self.SelectionChangedList) do
		local unitArray = w:SelectionChanged(selectedUnits, subselection)
		if unitArray then
			Spring.SelectUnitArray(unitArray)
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:GameProgress(serverFrameNum)
	tracy.ZoneBeginN("W:GameProgress")
	for _, w in ipairs(self.GameProgressList) do
		w:GameProgress(serverFrameNum)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	tracy.ZoneBeginN("W:UnsyncedHeightMapUpdate")
	for _, w in r_ipairs(self.UnsyncedHeightMapUpdateList) do
		w:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:ShockFront(power, dx, dy, dz)
	tracy.ZoneBeginN("W:ShockFront")
	for _, w in ipairs(self.ShockFrontList) do
		w:ShockFront(power, dx, dy, dz)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:WorldTooltip(ttType, ...)
	tracy.ZoneBeginN("W:WorldTooltip")
	for _, w in ipairs(self.WorldTooltipList) do
		local tt = w:WorldTooltip(ttType, ...)
		if type(tt) == 'string' and #tt > 0 then
			tracy.ZoneEnd()
			return tt
		end
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:MapDrawCmd(playerID, cmdType, px, py, pz, ...)
	tracy.ZoneBeginN("W:MapDrawCmd")
	local retval = false
	for _, w in ipairs(self.MapDrawCmdList) do
		local takeEvent = w:MapDrawCmd(playerID, cmdType, px, py, pz, ...)
		if takeEvent then
			retval = true
		end
	end
	tracy.ZoneEnd()
	return retval
end

function widgetHandler:ClearMapMarks()
	tracy.ZoneBeginN("W:ClearMapMarks")
	for _, w in ipairs(self.ClearMapMarksList) do
		w:ClearMapMarks()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:GameSetup(state, ready, playerStates)
	tracy.ZoneBeginN("W:GameSetup")
	for _, w in ipairs(self.GameSetupList) do
		local success, newReady = w:GameSetup(state, ready, playerStates)
		if success then
			tracy.ZoneEnd()
			return true, newReady
		end
	end
	tracy.ZoneEnd()
	return false
end

function widgetHandler:DefaultCommand(...)
	tracy.ZoneBeginN("W:DefaultCommand")
	for _, w in r_ipairs(self.DefaultCommandList) do
		local result = w:DefaultCommand(...)
		if type(result) == 'number' then
			tracy.ZoneEnd()
			return result
		end
	end
	tracy.ZoneEnd()
	return nil  --  not a number, use the default engine command
end

function widgetHandler:LanguageChanged()
	tracy.ZoneBeginN("W:LanguageChanged")
	for _, w in ipairs(self.LanguageChangedList) do
		w:LanguageChanged()
	end
	tracy.ZoneEnd()
end


--------------------------------------------------------------------------------
--
--  Unit call-ins
--

function widgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:MetaUnitAdded")
	for _, w in ipairs(self.MetaUnitAddedList) do
		w:MetaUnitAdded(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:MetaUnitRemoved")
	for _, w in ipairs(self.MetaUnitRemovedList) do
		w:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	widgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)
	tracy.ZoneBegin("W:UnitCreated")
	for _, w in ipairs(self.UnitCreatedList) do

		w:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitFinished(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitFinished")
	for _, w in ipairs(self.UnitFinishedList) do
		w:UnitFinished(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	tracy.ZoneBeginN("W:UnitFromFactory")
	for _, w in ipairs(self.UnitFromFactoryList) do
		w:UnitFromFactory(unitID, unitDefID, unitTeam,
			factID, factDefID, userOrders)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	widgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitDestroyed")
	for _, w in ipairs(self.UnitDestroyedList) do
		w:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitDestroyedByTeam(unitID, unitDefID, unitTeam, attackerTeamID)
	tracy.ZoneBeginN("W:UnitDestroyedByTeam")
	for _, w in ipairs(self.UnitDestroyedByTeamList) do
		w:UnitDestroyedByTeam(unitID, unitDefID, unitTeam, attackerTeamID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:RenderUnitDestroyed")
	-- at the time of committing, this does not get called by the widgethandler
	for _, w in ipairs(self.RenderUnitDestroyedList) do
		w:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	tracy.ZoneBeginN("W:UnitExperience")
	for _, w in ipairs(self.UnitExperienceList) do
		w:UnitExperience(unitID, unitDefID, unitTeam,
			experience, oldExperience)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)

	tracy.ZoneBeginN("W:UnitTaken")
	for _, w in ipairs(self.UnitTakenList) do
		w:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)

	tracy.ZoneBeginN("W:UnitGiven")
	for _, w in ipairs(self.UnitGivenList) do
		w:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitIdle(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitIdle")
	for _, w in ipairs(self.UnitIdleList) do
		w:UnitIdle(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	tracy.ZoneBeginN("W:UnitCommand")
	for _, w in ipairs(self.UnitCommandList) do
		w:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	tracy.ZoneBeginN("W:UnitCmdDone")
	for _, w in ipairs(self.UnitCmdDoneList) do
		w:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	tracy.ZoneBeginN("W:UnitDamaged")
	for _, w in ipairs(self.UnitDamagedList) do
		w:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitStunned(unitID, unitDefID, unitTeam, stunned)
	tracy.ZoneBeginN("W:UnitStunned")
	for _, w in ipairs(self.UnitStunnedList) do
		w:UnitStunned(unitID, unitDefID, unitTeam, stunned)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitEnteredRadar(unitID, unitTeam)
	tracy.ZoneBeginN("W:UnitEnteredRadar")
	for _, w in ipairs(self.UnitEnteredRadarList) do
		w:UnitEnteredRadar(unitID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitEnteredLos(unitID, unitTeam)
	tracy.ZoneBeginN("W:UnitEnteredLos")
	for _, w in ipairs(self.UnitEnteredLosList) do
		w:UnitEnteredLos(unitID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitLeftRadar(unitID, unitTeam)
	tracy.ZoneBeginN("W:UnitLeftRadar")
	for _, w in ipairs(self.UnitLeftRadarList) do
		w:UnitLeftRadar(unitID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitLeftLos(unitID, unitTeam)
	tracy.ZoneBeginN("W:UnitLeftLos")
	for _, w in ipairs(self.UnitLeftLosList) do
		w:UnitLeftLos(unitID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitEnteredWater(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitEnteredWater")
	for _, w in ipairs(self.UnitEnteredWaterList) do
		w:UnitEnteredWater(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitEnteredAir(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitEnteredAir")
	for _, w in ipairs(self.UnitEnteredAirList) do
		w:UnitEnteredAir(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitLeftWater(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitLeftWater")
	for _, w in ipairs(self.UnitLeftWaterList) do
		w:UnitLeftWater(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitLeftAir(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitLeftAir")
	for _, w in ipairs(self.UnitLeftAirList) do
		w:UnitLeftAir(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitSeismicPing(x, y, z, strength)
	tracy.ZoneBeginN("W:UnitSeismicPing")
	for _, w in ipairs(self.UnitSeismicPingList) do
		w:UnitSeismicPing(x, y, z, strength)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	tracy.ZoneBeginN("W:UnitLoaded")
	for _, w in ipairs(self.UnitLoadedList) do
		w:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	tracy.ZoneBeginN("W:UnitUnloaded")
	for _, w in ipairs(self.UnitUnloadedList) do
		w:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitCloaked(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitCloaked")
	for _, w in ipairs(self.UnitCloakedList) do
		w:UnitCloaked(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitDecloaked(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitDecloaked")
	for _, w in ipairs(self.UnitDecloakedList) do
		w:UnitDecloaked(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitMoveFailed(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:UnitMoveFailed")
	for _, w in ipairs(self.UnitMoveFailedList) do
		w:UnitMoveFailed(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:RecvLuaMsg(msg, playerID)
	tracy.ZoneBeginN("W:RecvLuaMsg")
	local retval = false
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		self.chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
		retval = true
	end
	for _, w in ipairs(self.RecvLuaMsgList) do
		if w:RecvLuaMsg(msg, playerID) then
			retval = true
		end
	end
	tracy.ZoneEnd()
	return retval  --  FIXME  --  another actionHandler type?
end

function widgetHandler:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	tracy.ZoneBeginN("W:StockpileChanged")
	for _, w in ipairs(self.StockpileChangedList) do
		w:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:VisibleUnitAdded")
	for _, w in ipairs(self.VisibleUnitAddedList) do
		w:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
end

function widgetHandler:VisibleUnitRemoved(unitID, unitDefID, unitTeam, reason)
	tracy.ZoneBeginN("W:VisibleUnitRemoved")
	for _, w in ipairs(self.VisibleUnitRemovedList) do
		w:VisibleUnitRemoved(unitID, unitDefID, unitTeam, reason)
	end
	tracy.ZoneEnd()
end

function widgetHandler:VisibleUnitsChanged(visibleUnits, numVisibleUnits)
	tracy.ZoneBeginN("W:VisibleUnitsChanged")
	for _, w in ipairs(self.VisibleUnitsChangedList) do
		tracy.ZoneBeginN("W:VisibleUnitsChanged:" .. w.whInfo.name)
		w:VisibleUnitsChanged(visibleUnits, numVisibleUnits)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
end

function widgetHandler:AlliedUnitAdded(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:AlliedUnitAdded")
	for _, w in ipairs(self.AlliedUnitAddedList) do
		w:AlliedUnitAdded(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
end

function widgetHandler:AlliedUnitRemoved(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:AlliedUnitRemoved")
	for _, w in ipairs(self.AlliedUnitRemovedList) do
		w:AlliedUnitRemoved(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
end

function widgetHandler:AlliedUnitsChanged(visibleUnits, numVisibleUnits)
	tracy.ZoneBeginN("W:AlliedUnitsChanged")
	for _, w in ipairs(self.AlliedUnitsChangedList) do
		w:AlliedUnitsChanged(visibleUnits, numVisibleUnits)
	end
	tracy.ZoneEnd()
end


--------------------------------------------------------------------------------
--
--  GFX
--

function widgetHandler:VisibleExplosion(px, py, pz, weaponID, ownerID)
	tracy.ZoneBeginN("W:VisibleExplosion")
	for _, w in ipairs(self.VisibleExplosionList) do
		w:VisibleExplosion(px, py, pz, weaponID, ownerID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:Barrelfire(px, py, pz, weaponID, ownerID)
	tracy.ZoneBeginN("W:Barrelfire")
	for _, w in ipairs(self.BarrelfireList) do
		w:Barrelfire(px, py, pz, weaponID, ownerID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:CrashingAircraft(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:CrashingAircraft")
	for _, w in ipairs(self.CrashingAircraftList) do
		w:CrashingAircraft(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end


--------------------------------------------------------------------------------
--
--  Feature call-ins
--

function widgetHandler:FeatureCreated(featureID, allyTeam)
	tracy.ZoneBeginN("W:FeatureCreated")
	for _, w in ipairs(self.FeatureCreatedList) do
		w:FeatureCreated(featureID, allyTeam)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:FeatureDestroyed(featureID, allyTeam)
	tracy.ZoneBeginN("W:FeatureDestroyed")
	for _, w in ipairs(self.FeatureDestroyedList) do
		w:FeatureDestroyed(featureID, allyTeam)
	end
	tracy.ZoneEnd()
	return
end


--------------------------------------------------------------------------------
--
--  Unit Market
--

function widgetHandler:UnitSale(unitID, price, msgFromTeamID)
	tracy.ZoneBeginN("W:UnitSale")
	for _, w in ipairs(self.UnitSaleList) do
		w:UnitSale(unitID, price, msgFromTeamID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitSold(unitID, price, old_ownerTeamID, msgFromTeamID)
	tracy.ZoneBeginN("W:UnitSold")
	for _, w in ipairs(self.UnitSoldList) do
		w:UnitSold(unitID, price, old_ownerTeamID, msgFromTeamID)
	end
	tracy.ZoneEnd()
	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

widgetHandler:Initialize()
