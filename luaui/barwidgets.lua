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
local WIDGET_DIRNAME_MAP = LUAUI_DIRNAME .. 'Widgets/'

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

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
if anonymousMode ~= "disabled" then
	allowuserwidgets = false

	-- disabling individual Spring functions isnt really good enough
	-- disabling user widget draw access would probably do the job but that wouldnt be easy to do
	Spring.SetTeamColor = function() return true end
end

if Spring.IsReplay() then
	allowuserwidgets = true
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

	actionHandler = VFS.Include(LUAUI_DIRNAME .. "actions.lua", nil, VFS.ZIP),

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
	'AlliedUnitsChanged'

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
	if not self.orderList then
		self.orderList = {} -- safety
	end
	if not self.configData then
		self.configData = {} -- safety
	end
end

function widgetHandler:SaveConfigData()
	--  self:LoadConfigData()
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
local doMoreYield = (Spring.Yield ~= nil);

local function Yield()
	if doMoreYield then
		local doMoreYield = Spring.Yield()
		if doMoreYield == false then --GetThreadSafety == false
			--Spring.Echo("WidgetHandler Yield: entering critical section")
		end
	end
end

local function GetWidgetInfo(name, mode)

	do
		return
	end -- FIXME

	local lines = VFS.LoadFile(name, mode)

	local infoLines = {}

	for line in lines:gmatch('([^\n]*)\n') do
		if not line:find('^%s*%-%-') then
			if line:find('[^\r]') then
				break -- not commented, not a blank line
			end
		end
		local s, e, source = line:find('^%s*%-%-%>%>(.*)')
		if source then
			table.insert(infoLines, source)
		end
	end

	local info = {}
	local chunk, err = loadstring(table.concat(infoLines, '\n'))
	if not chunk then
		Spring.Echo('not loading ' .. name .. ': ' .. err)
	else
		setfenv(chunk, info)
		local success, err = pcall(chunk)
		if not success then
			Spring.Echo('not loading ' .. name .. ': ' .. err)
		end
	end

	for k, v in pairs(info) do
		Spring.Echo(name, k, 'type: ' .. type(v), '<' .. tostring(v) .. '>')
	end
end

local zipOnly = {
	["Widget Selector"] = true,
	["Widget Profiler"] = true,
}

function widgetHandler:Initialize()
	self:LoadConfigData()

	-- do we allow userland widgets?
	--local autoUserWidgets = Spring.GetConfigInt('LuaAutoEnableUserWidgets', 1)
	--self.autoUserWidgets = (autoUserWidgets ~= 0)
	if self.allowUserWidgets == nil then
		self.allowUserWidgets = true
	end
	if self.allowUserWidgets and allowuserwidgets then
		Spring.Echo("LuaUI: Allowing User Widgets")
	else
		Spring.Echo("LuaUI: Disallowing User Widgets")
	end

	-- create the "LuaUI/Config" directory
	Spring.CreateDir(LUAUI_DIRNAME .. 'Config')

	local unsortedWidgets = {}

	-- stuff the raw widgets into unsortedWidgets
	if self.allowUserWidgets and allowuserwidgets then
		local widgetFiles = VFS.DirList(WIDGET_DIRNAME, "*.lua", VFS.RAW)
		for k, wf in ipairs(widgetFiles) do
			GetWidgetInfo(wf, VFS.RAW)
			local widget = self:LoadWidget(wf, false)
			if widget and not zipOnly[widget.whInfo.name] then
				table.insert(unsortedWidgets, widget)
				Yield()
			end
		end
	end

	-- stuff the zip widgets into unsortedWidgets
	local widgetFiles = VFS.DirList(WIDGET_DIRNAME, "*.lua", VFS.ZIP)
	for k, wf in ipairs(widgetFiles) do
		GetWidgetInfo(wf, VFS.ZIP)
		local widget = self:LoadWidget(wf, true)
		if widget then
			table.insert(unsortedWidgets, widget)
			Yield()
		end
	end

	-- stuff the map widgets into unsortedWidgets
	local widgetFiles = VFS.DirList(WIDGET_DIRNAME_MAP, "*.lua", VFS.MAP)
	for k, wf in ipairs(widgetFiles) do
		GetWidgetInfo(wf, VFS.MAP)
		local widget = self:LoadWidget(wf, true)
		if widget then
			table.insert(unsortedWidgets, widget)
			Yield()
		end
	end

	-- sort the widgets
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

	-- add the widgets
	for _, w in ipairs(unsortedWidgets) do
		local name = w.whInfo.name
		local basename = w.whInfo.basename
		local source = self.knownWidgets[name].fromZip and "mod: " or "user:"
		Spring.Echo(string.format("Loading widget from %s  %-18s  <%s> ...", source, name, basename))
		Yield()
		widgetHandler:InsertWidget(w)
	end

	-- save the active widgets, and their ordering
	self:SaveConfigData()
end

function widgetHandler:LoadWidget(filename, fromZip)
	local basename = Basename(filename)
	local text = VFS.LoadFile(filename)
	if text == nil then
		Spring.Echo('Failed to load: ' .. basename .. '  (missing file: ' .. filename .. ')')
		return nil
	end
	local chunk, err = loadstring(text, filename)
	if chunk == nil then
		Spring.Echo('Failed to load: ' .. basename .. '  (' .. err .. ')')
		return nil
	end

	local widget = widgetHandler:NewWidget()
	setfenv(chunk, widget)
	local success, err = pcall(chunk)
	if not success then
		Spring.Echo('Failed to load: ' .. basename .. '  (' .. err .. ')')
		return nil
	end
	if err == false then
		return nil -- widget asked for a silent death
	end

	-- raw access to widgetHandler
	if widget.GetInfo and widget:GetInfo().handler then
		widget.widgetHandler = self
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

	-- load the config data
	local config = self.configData[name]
	if widget.SetConfigData and config then
		widget:SetConfigData(config)
	end

	return widget
end

function widgetHandler:NewWidget()
	local widget = {}
	if true then
		-- copy the system calls into the widget table
		for k, v in pairs(System) do
			widget[k] = v
		end
	else
		-- use metatable redirection
		setmetatable(widget, {
			__index = System,
			__metatable = true,
		})
	end
	widget.WG = self.WG    -- the shared table
	widget.widget = widget -- easy self referencing

	-- wrapped calls (closures)
	widget.widgetHandler = {}
	local wh = widget.widgetHandler
	local self = self
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
	local wh = widgetHandler
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
		--[[
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
			Spring.Echo(r[1])
			Spring.Echo('Error in ' .. funcName .. '(): ' .. tostring(r[2]))
			Spring.Echo('Removed widget: ' .. name)
			return nil
		end
		]]--
	end
end

local function SafeWrapFuncGL(func, funcName)
	local wh = widgetHandler
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
		if widget.Initialize then
			widget.Initialize = SafeWrapFunc(widget.Initialize, 'Initialize')
		end
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

local function ArrayRemove(t, w)
	for k, v in ipairs(t) do
		if v == w then
			table.remove(t, k)
			--break
		end
	end
end

function widgetHandler:InsertWidget(widget)
	if widget == nil then
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

function widgetHandler:RemoveWidget(widget)
	if widget == nil or widget.whInfo == nil then
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
		_G[name] = function(...)
			return selffunc(self, ...)
		end
	else
		_G[name] = nil
	end
	Script.UpdateCallIn(name)
end

function widgetHandler:UpdateWidgetCallIn(name, w)
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

function widgetHandler:RemoveWidgetCallIn(name, w)
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

function widgetHandler:EnableWidget(name)
	local ki = self.knownWidgets[name]
	if not ki then
		Spring.Echo("EnableWidget(), could not find widget: " .. tostring(name))
		return false
	end
	if not ki.active then
		Spring.Echo('Loading:  ' .. ki.filename)
		local order = widgetHandler.orderList[name]
		if not order or order <= 0 then
			self.orderList[name] = 1
		end
		local w = self:LoadWidget(ki.filename)
		if not w then
			return false
		end
		self:InsertWidget(w)
		self:SaveConfigData()
	end
	return true
end

function widgetHandler:DisableWidget(name)
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
		self:RemoveWidget(w)     -- deactivate
		self.orderList[name] = 0 -- disable
		self:SaveConfigData()
	end
	return true
end

function widgetHandler:ToggleWidget(name)
	local ki = self.knownWidgets[name]
	if not ki then
		Spring.Echo("ToggleWidget(), could not find widget: " .. tostring(name))
		return
	end
	if ki.active then
		return self:DisableWidget(name)
	elseif self.orderList[name] <= 0 then
		return self:EnableWidget(name)
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

function widgetHandler:RaiseWidget(widget)
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
	return (ts + 1)
end

function widgetHandler:LowerWidget(widget)
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
			table.insert(t, n, w)
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

	-- save config
	if self.__blankOutConfig then
		table.save({ ["allowUserWidgets"] = self.allowUserWidgets }, CONFIG_FILENAME, '-- Widget Custom data and order')
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
		local sw = self:LoadWidget(LUAUI_DIRNAME .. SELECTOR_BASENAME) -- load the game's included widget_selector.lua, instead of the default selector.lua
		self:InsertWidget(sw)
		self:RaiseWidget(sw)
		return true
	elseif string.find(command, 'togglewidget') == 1 then
		self:ToggleWidget(string.sub(command, 14))
		return true
	elseif string.find(command, 'enablewidget') == 1 then
		self:EnableWidget(string.sub(command, 14))
		return true
	elseif string.find(command, 'disablewidget') == 1 then
		self:DisableWidget(string.sub(command, 15))
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

function widgetHandler:CommandNotify(id, params, options)
	for _, w in ipairs(self.CommandNotifyList) do
		if w:CommandNotify(id, params, options) then
			return true
		end
	end
	return false
end

function widgetHandler:AddConsoleLine(msg, priority)
	for _, w in ipairs(self.AddConsoleLineList) do
		w:AddConsoleLine(msg, priority)
	end
	return
end

function widgetHandler:GroupChanged(groupID)
	for _, w in ipairs(self.GroupChangedList) do
		w:GroupChanged(groupID)
	end
	return
end

function widgetHandler:CommandsChanged()
	if widgetHandler:UpdateSelection() then
		-- for selectionchanged
		return -- selection updated, don't call commands changed.
	end
	self.inCommandsChanged = true
	self.customCommands = {}
	for _, w in ipairs(self.CommandsChangedList) do
		w:CommandsChanged()
	end
	self.inCommandsChanged = false
	return
end


--------------------------------------------------------------------------------
--
--  Drawing call-ins
--


-- generates ViewResize() calls for the widgets
function widgetHandler:SetViewSize(vsx, vsy)
	self.xViewSize = vsx
	self.yViewSize = vsy
	if self.xViewSizeOld ~= vsx or self.yViewSizeOld ~= vsy then
		widgetHandler:ViewResize(vsx, vsy)
		self.xViewSizeOld = vsx
		self.yViewSizeOld = vsy
	end
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

function widgetHandler:DrawWorld()
	tracy.ZoneBeginN("W:DrawWorld")
	for _, w in r_ipairs(self.DrawWorldList) do
		tracy.ZoneBeginN("W:DrawWorld:" .. w.whInfo.name)
		w:DrawWorld()
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:DrawWorldPreUnit()
	tracy.ZoneBeginN("W:DrawWorldPreUnit")
	for _, w in r_ipairs(self.DrawWorldPreUnitList) do
		tracy.ZoneBeginN("W:DrawWorldPreUnit:" .. w.whInfo.name)
		w:DrawWorldPreUnit()
		tracy.ZoneEnd()
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
	for _, w in r_ipairs(self.DrawOpaqueFeaturesLuaList) do
		w:DrawOpaqueFeaturesLua(deferredPass, drawReflection, drawRefraction)
	end
	return
end

function widgetHandler:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	for _, w in r_ipairs(self.DrawAlphaUnitsLuaList) do
		w:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	end
	return
end

function widgetHandler:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	for _, w in r_ipairs(self.DrawAlphaFeaturesLuaList) do
		w:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	end
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
	for _, w in r_ipairs(self.DrawShadowFeaturesLuaList) do
		w:DrawShadowFeaturesLua()
	end
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

function widgetHandler:DrawWorldPreParticles()
	tracy.ZoneBeginN("W:DrawWorldPreParticles")
	for _, w in r_ipairs(self.DrawWorldPreParticlesList) do
		w:DrawWorldPreParticles()
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
	for _, w in r_ipairs(self.DrawUnitsPostDeferredList) do
		w:DrawUnitsPostDeferred()
	end
	return
end

function widgetHandler:DrawFeaturesPostDeferred()
	for _, w in r_ipairs(self.DrawFeaturesPostDeferredList) do
		w:DrawFeaturesPostDeferred()
	end
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


--------------------------------------------------------------------------------
--
--  Keyboard call-ins
--

function widgetHandler:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
	local textOwner = self.textOwner

	if textOwner then
		if (not textOwner.KeyPress) or textOwner:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions) then
			return true
		end
	end

	if self.actionHandler:KeyAction(true, key, mods, isRepeat, scanCode, actions) then
		return true
	end

	for _, w in ipairs(self.KeyPressList) do
		if w:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions) then
			return true
		end
	end
	return false
end

function widgetHandler:KeyRelease(key, mods, label, unicode, scanCode, actions)
	local textOwner = self.textOwner

	if textOwner then
		if (not textOwner.KeyRelease) or textOwner:KeyRelease(key, mods, label, unicode, scanCode, actions) then
			return true
		end
	end

	if self.actionHandler:KeyAction(false, key, mods, false, scanCode, actions) then
		return true
	end

	for _, w in ipairs(self.KeyReleaseList) do
		if w:KeyRelease(key, mods, label, unicode, scanCode, actions) then
			return true
		end
	end
	return false
end

function widgetHandler:TextInput(utf8, ...)
	local textOwner = self.textOwner

	if textOwner then
		if textOwner.TextInput then
			textOwner:TextInput(utf8, ...)
		end

		return true
	end

	for _, w in r_ipairs(self.TextInputList) do
		if w:TextInput(utf8, ...) then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
--
--  Mouse call-ins
--

-- local helper (not a real call-in)
function widgetHandler:WidgetAt(x, y)
	for _, w in ipairs(self.IsAboveList) do
		if w:IsAbove(x, y) then
			return w
		end
	end
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
	for _, w in ipairs(self.MouseWheelList) do
		if w:MouseWheel(up, value) then
			return true
		end
	end
	return false
end

function widgetHandler:ControllerAdded(deviceIndex)
	for _, w in ipairs(self.ControllerAddedList) do
		if w:ControllerAdded(deviceIndex) then
			return true
		end
	end
	return false
end

function widgetHandler:ControllerRemoved(instanceId)
	for _, w in ipairs(self.ControllerRemovedList) do
		if w:ControllerRemoved(instanceId) then
			return true
		end
	end
	return false
end

function widgetHandler:ControllerConnected(instanceId)
	for _, w in ipairs(self.ControllerConnectedList) do
		if w:ControllerConnected(instanceId) then
			return true
		end
	end
	return false
end

function widgetHandler:ControllerDisconnected(instanceId)
	for _, w in ipairs(self.ControllerDisconnectedList) do
		if w:ControllerDisconnected(instanceId) then
			return true
		end
	end
	return false
end

function widgetHandler:ControllerRemapped(instanceId)
	for _, w in ipairs(self.ControllerRemappedList) do
		if w:ControllerRemapped(instanceId) then
			return true
		end
	end
	return false
end

function widgetHandler:ControllerButtonUp(instanceId, button, state, name)
	for _, w in ipairs(self.ControllerButtonUpList) do
		if w:ControllerButtonUp(instanceId, button, state, name) then
			return true
		end
	end
	return false
end

function widgetHandler:ControllerButtonDown(instanceId, button, state, name)
	for _, w in ipairs(self.ControllerButtonDownList) do
		if w:ControllerButtonDown(instanceId, button, state, name) then
			return true
		end
	end
	return false
end

function widgetHandler:ControllerAxisMotion(instanceId, axis, value, name)
	for _, w in ipairs(self.ControllerAxisMotionList) do
		if w:ControllerAxisMotion(instanceId, axis, value, name) then
			return true
		end
	end
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
	for _, w in ipairs(self.GamePreloadList) do
		w:GamePreload()
	end
	return
end

function widgetHandler:GameStart()
	for _, w in ipairs(self.GameStartList) do
		w:GameStart()
	end
	return
end

function widgetHandler:GameOver()
	for _, w in ipairs(self.GameOverList) do
		w:GameOver()
	end
	return
end

function widgetHandler:GamePaused(playerID, paused)
	for _, w in ipairs(self.GamePausedList) do
		w:GamePaused(playerID, paused)
	end
	return
end

function widgetHandler:TeamDied(teamID)
	for _, w in ipairs(self.TeamDiedList) do
		w:TeamDied(teamID)
	end
	return
end

function widgetHandler:TeamChanged(teamID)
	for _, w in ipairs(self.TeamChangedList) do
		w:TeamChanged(teamID)
	end
	return
end

function widgetHandler:PlayerAdded(playerID)
	for _, w in ipairs(self.PlayerAddedList) do
		w:PlayerAdded(playerID)
	end
	return
end

function widgetHandler:PlayerRemoved(playerID, reason)
	for _, w in ipairs(self.PlayerRemovedList) do
		w:PlayerRemoved(playerID)
	end
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
			local newSeen = 0
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
	for _, w in ipairs(self.GameProgressList) do
		w:GameProgress(serverFrameNum)
	end
	return
end

function widgetHandler:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	for _, w in r_ipairs(self.UnsyncedHeightMapUpdateList) do
		w:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	end
	return
end

function widgetHandler:ShockFront(power, dx, dy, dz)
	for _, w in ipairs(self.ShockFrontList) do
		w:ShockFront(power, dx, dy, dz)
	end
	return
end

function widgetHandler:WorldTooltip(ttType, ...)
	for _, w in ipairs(self.WorldTooltipList) do
		local tt = w:WorldTooltip(ttType, ...)
		if type(tt) == 'string' and #tt > 0 then
			return tt
		end
	end
	return
end

function widgetHandler:MapDrawCmd(playerID, cmdType, px, py, pz, ...)
	local retval = false
	for _, w in ipairs(self.MapDrawCmdList) do
		local takeEvent = w:MapDrawCmd(playerID, cmdType, px, py, pz, ...)
		if takeEvent then
			retval = true
		end
	end
	return retval
end

function widgetHandler:GameSetup(state, ready, playerStates)
	for _, w in ipairs(self.GameSetupList) do
		local success, newReady = w:GameSetup(state, ready, playerStates)
		if success then
			return true, newReady
		end
	end
	return false
end

function widgetHandler:DefaultCommand(...)
	for _, w in r_ipairs(self.DefaultCommandList) do
		local result = w:DefaultCommand(...)
		if type(result) == 'number' then
			return result
		end
	end
	return nil  --  not a number, use the default engine command
end

function widgetHandler:LanguageChanged()
	for _, w in ipairs(self.LanguageChangedList) do
		w:LanguageChanged()
	end
end


--------------------------------------------------------------------------------
--
--  Unit call-ins
--

function widgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.MetaUnitAddedList) do
		w:MetaUnitAdded(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.MetaUnitRemovedList) do
		w:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	tracy.ZoneBegin("W:UnitCreated")
	widgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)

	for _, w in ipairs(self.UnitCreatedList) do

		w:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	end
	tracy.ZoneEnd()
	return
end

function widgetHandler:UnitFinished(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.UnitFinishedList) do
		w:UnitFinished(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	for _, w in ipairs(self.UnitFromFactoryList) do
		w:UnitFromFactory(unitID, unitDefID, unitTeam,
			factID, factDefID, userOrders)
	end
	return
end

function widgetHandler:UnitDestroyed(unitID, unitDefID, unitTeam)
	widgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)

	for _, w in ipairs(self.UnitDestroyedList) do
		w:UnitDestroyed(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitDestroyedByTeam(unitID, unitDefID, unitTeam, attackerTeamID)
	for _, w in ipairs(self.UnitDestroyedByTeamList) do
		w:UnitDestroyedByTeam(unitID, unitDefID, unitTeam, attackerTeamID)
	end
	return
end

function widgetHandler:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	-- at the time of committing, this does not get called by the widgethandler
	for _, w in ipairs(self.RenderUnitDestroyedList) do
		w:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	for _, w in ipairs(self.UnitExperienceList) do
		w:UnitExperience(unitID, unitDefID, unitTeam,
			experience, oldExperience)
	end
	return
end

function widgetHandler:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)

	for _, w in ipairs(self.UnitTakenList) do
		w:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	end
	return
end

function widgetHandler:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)

	for _, w in ipairs(self.UnitGivenList) do
		w:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	end
	return
end

function widgetHandler:UnitIdle(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.UnitIdleList) do
		w:UnitIdle(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	for _, w in ipairs(self.UnitCommandList) do
		w:UnitCommand(unitID, unitDefID, unitTeam,
			cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	end
	return
end

function widgetHandler:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdTag, cmdParams, cmdOpts)
	for _, w in ipairs(self.UnitCmdDoneList) do
		w:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdTag, cmdParams, cmdOpts)
	end
	return
end

function widgetHandler:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	for _, w in ipairs(self.UnitDamagedList) do
		w:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	end
	return
end

function widgetHandler:UnitEnteredRadar(unitID, unitTeam)
	for _, w in ipairs(self.UnitEnteredRadarList) do
		w:UnitEnteredRadar(unitID, unitTeam)
	end
	return
end

function widgetHandler:UnitEnteredLos(unitID, unitTeam)
	for _, w in ipairs(self.UnitEnteredLosList) do
		w:UnitEnteredLos(unitID, unitTeam)
	end
	return
end

function widgetHandler:UnitLeftRadar(unitID, unitTeam)
	for _, w in ipairs(self.UnitLeftRadarList) do
		w:UnitLeftRadar(unitID, unitTeam)
	end
	return
end

function widgetHandler:UnitLeftLos(unitID, unitTeam)
	for _, w in ipairs(self.UnitLeftLosList) do
		w:UnitLeftLos(unitID, unitTeam)
	end
	return
end

function widgetHandler:UnitEnteredWater(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.UnitEnteredWaterList) do
		w:UnitEnteredWater(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitEnteredAir(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.UnitEnteredAirList) do
		w:UnitEnteredAir(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitLeftWater(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.UnitLeftWaterList) do
		w:UnitLeftWater(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitLeftAir(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.UnitLeftAirList) do
		w:UnitLeftAir(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitSeismicPing(x, y, z, strength)
	for _, w in ipairs(self.UnitSeismicPingList) do
		w:UnitSeismicPing(x, y, z, strength)
	end
	return
end

function widgetHandler:UnitLoaded(unitID, unitDefID, unitTeam,
								  transportID, transportTeam)
	for _, w in ipairs(self.UnitLoadedList) do
		w:UnitLoaded(unitID, unitDefID, unitTeam,
			transportID, transportTeam)
	end
	return
end

function widgetHandler:UnitUnloaded(unitID, unitDefID, unitTeam,
									transportID, transportTeam)
	for _, w in ipairs(self.UnitUnloadedList) do
		w:UnitUnloaded(unitID, unitDefID, unitTeam,
			transportID, transportTeam)
	end
	return
end

function widgetHandler:UnitCloaked(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.UnitCloakedList) do
		w:UnitCloaked(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitDecloaked(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.UnitDecloakedList) do
		w:UnitDecloaked(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:UnitMoveFailed(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.UnitMoveFailedList) do
		w:UnitMoveFailed(unitID, unitDefID, unitTeam)
	end
	return
end

function widgetHandler:RecvLuaMsg(msg, playerID)
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
	return retval  --  FIXME  --  another actionHandler type?
end

function widgetHandler:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	for _, w in ipairs(self.StockpileChangedList) do
		w:StockpileChanged(unitID, unitDefID, unitTeam,
			weaponNum, oldCount, newCount)
	end
	return
end

function widgetHandler:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("W:VisibleUnitAdded")
	for _, w in ipairs(self.VisibleUnitAddedList) do
		w:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
end

function widgetHandler:VisibleUnitRemoved(unitID)
	for _, w in ipairs(self.VisibleUnitRemovedList) do
		w:VisibleUnitRemoved(unitID)
	end
end

function widgetHandler:VisibleUnitsChanged(visibleUnits, numVisibleUnits)
	for _, w in ipairs(self.VisibleUnitsChangedList) do
		w:VisibleUnitsChanged(visibleUnits, numVisibleUnits)
	end
end

function widgetHandler:AlliedUnitAdded(unitID, unitDefID, unitTeam)
	for _, w in ipairs(self.AlliedUnitAddedList) do
		w:AlliedUnitAdded(unitID, unitDefID, unitTeam)
	end
end

function widgetHandler:AlliedUnitRemoved(unitID)
	for _, w in ipairs(self.AlliedUnitRemovedList) do
		w:AlliedUnitRemoved(unitID)
	end
end

function widgetHandler:AlliedUnitsChanged(visibleUnits, numVisibleUnits)
	for _, w in ipairs(self.AlliedUnitsChangedList) do
		w:AlliedUnitsChanged(visibleUnits, numVisibleUnits)
	end
end


--------------------------------------------------------------------------------
--
--  Feature call-ins
--

function widgetHandler:FeatureCreated(featureID, allyTeam)
	for _, w in ipairs(self.FeatureCreatedList) do
		w:FeatureCreated(featureID, allyTeam)
	end
	return
end

function widgetHandler:FeatureDestroyed(featureID, allyTeam)
	for _, w in ipairs(self.FeatureDestroyedList) do
		w:FeatureDestroyed(featureID, allyTeam)
	end
	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

widgetHandler:Initialize()
