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
VFS.Include(LUAUI_DIRNAME .. "system.lua", nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "callins.lua", nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "savetable.lua", nil, VFS.ZIP)

-- What each widget shares with others through WG, read out of its source as it loads, so the widget
-- selector can say what depends on what. Optional: a file added to the game since it started is
-- invisible to VFS until the next start, and that is no reason for LuaUI not to load.
local widgetDependencies
do
	local ok, module = pcall(VFS.Include, LUAUI_DIRNAME .. "Include/widget_dependencies.lua", nil, VFS.ZIP)
	widgetDependencies = ok and module or nil
end

-- Watches what user widgets allocate and hold, and LuaUI's share of the engine's Lua memory pool.
-- Optional for the same reason. The instance is made once the sandbox it looks through exists.
local MemoryGuard
do
	local ok, module = pcall(VFS.Include, LUAUI_DIRNAME .. "Include/memory_guard.lua", nil, VFS.ZIP)
	MemoryGuard = ok and module or nil
end
local memoryGuard

-- Avoid deep copies and cycles.
local function copyTable(source)
	local copy = {}
	for k, v in pairs(source) do
		copy[k] = v
	end
	return copy
end

-- Locals for performance.
local loadstring = loadstring
local getfenv = getfenv
local setfenv = setfenv
local pcall = pcall
local select = select
local tracyZoneBeginN = tracy.ZoneBeginN
local tracyZoneEnd = tracy.ZoneEnd

-- Widgets share these tables and can replace their functions for everyone.
local stringByte = string.byte
local stringFind = string.find
local stringLower = string.lower
local stringGsub = string.gsub
local stringSub = string.sub
local stringGmatch = string.gmatch
local tableInsert = table.insert
local tableRemove = table.remove
local tableSave = table.save
local tableSort = table.sort
local tableAppend = table.append
local tableConcat = table.concat
local debugTraceback = debug.traceback
local debugGetinfo = debug.getinfo
local debugGetlocal = debug.getlocal
local ioOpen = io.open
local vfsLoadFile = VFS.LoadFile
local vfsFileExists = VFS.FileExists
local vfsDirList = VFS.DirList
local vfsSubDirs = VFS.SubDirs
local vfsInclude = VFS.Include
local vfsZip = VFS.ZIP
local vfsRaw = VFS.RAW
local vfsRawFirst = VFS.RAW_FIRST
local platformCheck = Platform.check
local spEcho = Spring.Echo
local spLog = Spring.Log
local spSendCommands = Spring.SendCommands
local spGetSpectatingState = Spring.GetSpectatingState
local spIsReplay = Spring.IsReplay
local LOG = copyTable(LOG)
local isSinglePlayer = BAR.Utilities.Gametype.IsSinglePlayer
local getAccountID = BAR.Utilities.GetAccountID

local CONFIG_FILENAME = LUAUI_DIRNAME .. "Config/" .. Game.gameShortName .. ".lua"
local WIDGET_DIRNAME = LUAUI_DIRNAME .. "Widgets/"
local RML_WIDGET_DIRNAME = LUAUI_DIRNAME .. "RmlWidgets/"

local SELECTOR_BASENAME = "widget_selector.lua"

local SAFEWRAP = 1
-- 0: disabled
-- 1: enabled, but can be overridden by widget.GetInfo().unsafe
-- 2: always enabled

local SAFEDRAW = false -- requires SAFEWRAP to work
local glPopAttrib = gl.PopAttrib
local glPushAttrib = gl.PushAttrib
local GL_ALL_ATTRIB_BITS = GL.ALL_ATTRIB_BITS

Spring.SendCommands({
	"unbindkeyset  Any+f11",
	"unbindkeyset Ctrl+f11",
	"bind    f11  luaui selector",
	"echo LuaUI: bound F11 to the widget selector",
})

local allowuserwidgets = Spring.GetModOptions().allowuserwidgets
local allowunitcontrolwidgets = Spring.GetModOptions().allowunitcontrolwidgets
local isHeadless = Platform.isHeadless or false

local SandboxedSystem = {}
local SANDBOXED_ERROR_UNIT_CONTROL = "User 'unit control' widgets disallowed on this game"
local SANDBOXED_ERROR_USER_WIDGETS = "User widgets cannot control other widgets or execute remote code"

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
if anonymousMode ~= "disabled" then
	allowuserwidgets = false

	-- disabling individual Spring functions isn't really good enough
	-- disabling user widget draw access would probably do the job but that wouldn't be easy to do
	Spring.SetTeamColor = function()
		return true
	end

	if not spGetSpectatingState() then
		Spring.SendCommands("info 0")
	end
end

if spIsReplay() or spGetSpectatingState() then
	allowuserwidgets = true
	allowunitcontrolwidgets = true
end

-- Convenience copies for protected member access.
local table = copyTable(table)
local string = copyTable(string)
local math = copyTable(math)
local Spring = copyTable(Spring)
local Json = copyTable(Json)

local widgetHandler = {
	widgets = {},

	configData = {},
	-- Every error each widget has raised this session, kept against its file. See RecordError.
	errorLog = {},
	-- And how many in all, so a panel can notice a new one with a single comparison.
	errorCount = 0,
	orderList = {},

	knownWidgets = {},
	knownCount = 0,
	knownChanged = true,

	commands = {},
	customCommands = {},
	inCommandsChanged = false,

	allowUserWidgets = true,

	actionHandler = vfsInclude(LUAUI_DIRNAME .. "actions.lua", nil, vfsZip),
	widgetHashes = {}, -- this is a table of widget md5 values to file names, used for user widget hashing

	WG = {}, -- shared table for widgets
	widgetsRevision = 0,

	globals = {}, -- global vars/funcs

	textOwner = nil,
	mouseOwner = nil,
	ownedButton = 0,

	chobbyInterface = false, -- will be true when chobby interface is on top

	xViewSize = 1,
	yViewSize = 1,
	xViewSizeOld = 1,
	yViewSizeOld = 1,
}

-- these call-ins are set to 'nil' if not used
-- they are setup in UpdateCallIns()
local flexCallIns = {
	"GameOver",
	"GameFrame",
	"GameFramePost",
	"GameSetup",
	"GamePaused",
	"TeamDied",
	"TeamChanged",
	"PlayerAdded",
	"PlayerRemoved",
	"PlayerChanged",
	"ShockFront",
	"WorldTooltip",
	"MapDrawCmd",
	"ActiveCommandChanged",
	"CameraRotationChanged",
	"CameraPositionChanged",
	"DefaultCommand",
	"UnitCreated",
	"UnitFinished",
	"UnitFromFactory",
	"UnitDestroyed",
	"UnitDestroyedByTeam", -- NB: called via gadget, not engine
	"RenderUnitDestroyed",
	"UnitExperience",
	"UnitTaken",
	"UnitGiven",
	"UnitIdle",
	"UnitCommand",
	"UnitCmdDone",
	"UnitDamaged",
	"UnitStunned",
	"UnitEnteredRadar",
	"UnitEnteredLos",
	"UnitLeftRadar",
	"UnitLeftLos",
	"UnitEnteredWater",
	"UnitEnteredAir",
	"UnitLeftWater",
	"UnitLeftAir",
	"UnitSeismicPing",
	"UnitLoaded",
	"UnitUnloaded",
	"UnitCloaked",
	"UnitDecloaked",
	"UnitMoveFailed",
	"MetaUnitAdded",
	"MetaUnitRemoved",
	"RecvLuaMsg",
	"StockpileChanged",
	"SelectionChanged",
	"DrawGenesis",
	"DrawGroundPreForward",
	"DrawGroundPostForward",
	"DrawGroundPreDeferred",
	"DrawGroundPostDeferred",
	"DrawGroundDeferred",
	"DrawWorld",
	"DrawWorldPreUnit",
	"DrawPreDecals",
	"DrawWorldPreParticles",
	"DrawWorldShadow",
	"DrawWorldReflection",
	"DrawWorldRefraction",
	"DrawUnitsPostDeferred",
	"DrawFeaturesPostDeferred",
	"DrawScreenEffects",
	"DrawScreenPost",
	"DrawInMiniMap",
	"DrawBuildSquare",
	"DrawOpaqueUnitsLua",
	"DrawOpaqueFeaturesLua",
	"DrawAlphaUnitsLua",
	"DrawAlphaFeaturesLua",
	"DrawShadowUnitsLua",
	"DrawShadowFeaturesLua",
	"SunChanged",
	"FeatureCreated",
	"FeatureDestroyed",
	"UnsyncedHeightMapUpdate",
}
if Engine.FeatureSupport.nanoParticleUpdateCallin then
	flexCallIns[#flexCallIns + 1] = "NanoParticleUpdate"
end
local flexCallInMap = {}
for _, ci in ipairs(flexCallIns) do
	flexCallInMap[ci] = true
end

local callInLists = {
	"FontsChanged",
	"GamePreload",
	"GameStart",
	"Shutdown",
	"Update",
	"TextCommand",
	"CommandNotify",
	"AllowQuit",
	"AddConsoleLine",
	"ViewResize",
	"DrawScreen",
	"KeyPress",
	"KeyRelease",
	"TextInput",
	"MousePress",
	"MouseWheel",
	"ControllerAdded",
	"ControllerRemoved",
	"ControllerConnected",
	"ControllerDisconnected",
	"ControllerRemapped",
	"ControllerButtonUp",
	"ControllerButtonDown",
	"ControllerAxisMotion",
	"IsAbove",
	"GetTooltip",
	"GroupChanged",
	"GameProgress",
	"CommandsChanged",
	"LanguageChanged",
	"UnitBlocked",
	"BuildOptionsChanged",
	"VisibleUnitAdded",
	"VisibleUnitRemoved",
	"VisibleUnitsChanged",
	"AlliedUnitAdded",
	"AlliedUnitRemoved",
	"AlliedUnitsChanged",
	"UnitSale",
	"UnitSold",
	"VisibleExplosion",
	"VisibleExplosionBatch",
	"Barrelfire",
	"BarrelfireBatch",
	"CrashingAircraft",
	"SendStats",
	"SendStats_GameMode",
	"ActivityEvent",
	"FpsEvent",
	"ApmEvent",
	"GpuMemEvent",
	"LuaMemEvent",
	"SystemEvent",
	"RankingEvent",
	"MouseCursorEvent",
	"CameraBroadcastEvent",
	"FeatureReclaimStartedETA",
	"UnitBuildspeedDebuffHealthbars",
	"UnitBuildspeedDebuffEndHealthbars",
	"GadgetAddMessage",
	"GadgetReceiveAwards",
	"UnitScriptLight",
	"UnitScriptDistortion",
	"UnitScriptDecal",
	"UnitScriptDecalBatch",
	"GadgetRemoveGrass",
	"GadgetCoopStartPoint",
	"NotificationEvent",
	"NightFactorChanged",
	"ScavEvent",
	"RaptorEvent",
	"FeatureReclaimStartedHealthbars",
	"UnitCaptureStartedHealthbars",
	"ProjectileCreatedReloadHB",
	"UnitParalyzeDamageHealthbars",
	"UnitParalyzeDamageEffect",
	"SelectedUnitsClear",
	"SelectedUnitsSet",
	"SelectedUnitsBatchUpdate",
	"SelectedUnitsRemove",
	"SelectedUnitsAdd",
	"LavaRenderState",
	"ClearMapMarks",

	-- these use mouseOwner instead of lists
	--  'MouseMove',
	--  'MouseRelease',
}

local headlessDisabledCallIns = {
	FontsChanged = true,
	ViewResize = true,
	DrawScreen = true,
	DrawGenesis = true,
	DrawGroundDeferred = true,
	DrawWorld = true,
	DrawWorldPreUnit = true,
	DrawPreDecals = true,
	DrawWorldPreParticles = true,
	DrawWorldShadow = true,
	DrawWorldReflection = true,
	DrawWorldRefraction = true,
	DrawUnitsPostDeferred = true,
	DrawFeaturesPostDeferred = true,
	DrawScreenEffects = true,
	DrawScreenPost = true,
	DrawInMiniMap = true,
	DrawBuildSquare = true,
	DrawOpaqueUnitsLua = true,
	DrawOpaqueFeaturesLua = true,
	DrawAlphaUnitsLua = true,
	DrawAlphaFeaturesLua = true,
	DrawShadowUnitsLua = true,
	DrawShadowFeaturesLua = true,
	SunChanged = true,
}

-- append the flex call-ins
for _, uci in ipairs(flexCallIns) do
	tableInsert(callInLists, uci)
end

-- initialize the call-in lists
do
	for _, listname in ipairs(callInLists) do
		widgetHandler[listname .. "List"] = {}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function loadSourceChunk(text, chunkname, env)
	if type(text) == "string" and stringByte(text, 1) == 27 then
		return nil, "bytecode unsupported"
	end
	return loadstring(text, chunkname, env)
end

local function loadSourceFile(filename, env)
	local file, err = ioOpen(filename, "rb")
	if not file then
		return nil, err
	end
	local text = file:read("*a")
	file:close()
	return loadSourceChunk(text, "@" .. filename, env)
end

function widgetHandler:LoadConfigData()
	-- Config must be data. Loaded code cannot access any globals. It gets an empty env.
	local chunk, err = loadSourceFile(CONFIG_FILENAME, {})
	if chunk == nil then
		if err then
			spLog("barwidgets.lua", LOG.INFO, err)
		end
		return {}
	end
	local config = chunk()
	if config == nil then
		spLog("barwidgets.lua", LOG.ERROR, "Luaui config file was blank")
		return {}
	end
	self.orderList = config.order
	self.configData = config.data
	self.allowUserWidgets = config.allowUserWidgets
	if not self.orderList then
		self.orderList = {} -- safety
	end
	if not self.configData then
		self.configData = {} -- safety
	end
end

-- Writes the widget config out.
--
-- A reset asked for on the way out is honoured here rather than at the call site,
-- because this is called from more places than the shutdown: a widget's own Shutdown can
-- call it (cmd_terraform_suite does, to leave its suite switched off), and those run
-- after Shutdown has written - which put the whole config back and left a factory reset
-- looking like it had done nothing at all.
function widgetHandler:SaveConfigData()
	if self.__blankOutConfig then
		-- Everything goes: which widgets are on, and whatever each of them had saved.
		tableSave({ allowUserWidgets = self.allowUserWidgets }, CONFIG_FILENAME, "-- Widget Custom data and order")

		return
	end

	local filetable = {}
	for i, w in ipairs(self.widgets) do
		if w.GetConfigData then
			self.configData[w.whInfo.name] = w:GetConfigData()
		end
		self.orderList[w.whInfo.name] = i
	end
	-- Which widgets are on goes back to what the game enables by default; what each of
	-- them has saved is kept.
	if not self.__blankOutOrder then
		filetable.order = self.orderList
	end
	filetable.data = self.configData
	filetable.allowUserWidgets = self.allowUserWidgets
	tableSave(filetable, CONFIG_FILENAME, "-- Widget Custom data and order, order = 0 disabled widget")
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
local unsortedWidgets ---@type table
-- While Initialize inserts the startup widgets, each insert updates only the call-ins its widget has.
local insertingStartupWidgets = false
local springYield = Spring.Yield
local doMoreYield = (springYield ~= nil)

local function Yield()
	if doMoreYield then
		doMoreYield = springYield()
	end
end

local zipOnly = {
	["Widget Selector"] = "LuaUI/Widgets/widget_selector.lua",
}
local zipOnlyFiles = {}
for name, filename in pairs(zipOnly) do
	zipOnlyFiles[filename:lower()] = name
end

local function loadWidgetFiles(folder, vfsMode)
	local fromZip = vfsMode ~= vfsRaw
	local widgetFiles = vfsDirList(folder, "*.lua", vfsMode)

	for _, subDirectory in ipairs(vfsSubDirs(folder)) do
		tableAppend(widgetFiles, vfsDirList(subDirectory, "*.lua", vfsMode))
	end

	for _, file in ipairs(widgetFiles) do
		local gameName = not fromZip and zipOnlyFiles[(file:lower():gsub("\\", "/"))] ---@as boolean|string

		if gameName then
			-- Not loaded at all, since loading runs its code before its name can be checked.
			spEcho("Ignoring user copy: " .. file .. "  (the game provides " .. gameName .. ")")
		else
			local widget = widgetHandler:LoadWidget(file, fromZip)

			if widget then
				tableInsert(unsortedWidgets, widget)
				Yield()
			end
		end
	end
end

-- Catches absolutely any attempt at running or binding the command.
local function isPrivilegedCommand(command)
	command = stringLower(command)
	return stringFind(command, "enablewidget", 1, true) ~= nil
		or stringFind(command, "disablewidget", 1, true) ~= nil
		or stringFind(command, "togglewidget", 1, true) ~= nil
		or stringFind(command, "execute", 1, true) ~= nil
		or stringFind(command, "keyload", 1, true) ~= nil
		or stringFind(command, "keyreload", 1, true) ~= nil
		or stringFind(command, "keysave", 1, true) ~= nil
		or stringFind(command, "keybindingfile", 1, true) ~= nil
		or stringFind(command, "factoryreset", 1, true) ~= nil
		or stringFind(command, "userwidgets", 1, true) ~= nil
		or stringFind(command, "runtests", 1, true) ~= nil
		or stringFind(command, "runscenario", 1, true) ~= nil
		or stringFind(command, "%f[%w_]option%f[^%w_]") ~= nil -- not "options", which only opens the panel
end

local inMultiplayer = not isSinglePlayer()
local function isHiddenStateCommand(command)
	if not inMultiplayer or select(2, spGetSpectatingState()) then
		return false
	end
	command = stringLower(command)
	return stringFind(command, "%f[%w_]save%f[^%w_]") ~= nil
		or stringFind(command, "%f[%w_]luasave%f[^%w_]") ~= nil
		or stringFind(command, "%f[%w_]dumpstate%f[^%w_]") ~= nil
end

local userWritableFolders = { "luaui/config/", "luaui/widgets/" }
local userReadableFolder = "luaui/"
local userReadonlyFiles = {
	[stringLower(CONFIG_FILENAME)] = "is the widget handler config",
	["luaui/widgets/uikeys.txt"] = "is run as console commands by the game",
	["luaui/config/keybind_profiles.json"] = "is applied as key binds by the game",
}

-- FIXME: Other OS handling would need to be added here. Preferably engine would provide a method.
---@return string? path nil when blocked
---@return string? reason for blocking
local function normalizeUserPath(path)
	if type(path) ~= "string" then
		return nil, "is not a path"
	end
	if stringFind(path, "\0", 1, true) then
		return nil, "contains a NUL character" -- engine opens the path as a C string
	end
	if stringFind(path, ":", 1, true) then
		return nil, "may be a drive or a stream"
	end
	if stringFind(path, "~", 1, true) then
		return nil, "may be a Windows shortname"
	end
	path = stringGsub(path, "\\", "/")
	if stringSub(path, 1, 1) == "/" then
		return nil, "is an absolute path"
	end
	local parts = {}
	for part in stringGmatch(path, "[^/]+") do
		if part == ".." then
			return nil, "tries to climb dirs"
		elseif part ~= "." then
			if stringFind(part, "[%. ]$") then
				return nil, "has a name that Windows will modify on open"
			end
			parts[#parts + 1] = part
		end
	end
	return tableConcat(parts, "/")
end

---@return string? path nil when blocked
---@return string? reason for blocking
local function checkUserWritePath(path)
	local target, reason = normalizeUserPath(path)
	if not target then
		return nil, reason
	end
	local lowerPath = stringLower(target)
	local readonly = userReadonlyFiles[lowerPath] ---@type string?
	if readonly then
		return nil, readonly
	end
	for _, folder in ipairs(userWritableFolders) do
		if stringSub(lowerPath .. "/", 1, #folder) == folder then
			return target
		end
	end
	return nil, "is outside the write paths for user widgets"
end

---@return string? path nil when blocked
---@return string? reason for blocking
local function checkUserReadPath(path)
	local target, reason = normalizeUserPath(path)
	if not target then
		return nil, reason
	end
	if stringSub(stringLower(target) .. "/", 1, #userReadableFolder) == userReadableFolder then
		return target
	end
	return nil, "is outside the read paths for user widgets"
end

-- User widgets can only read from LuaUI/ and archives.
local function getUserReadMode(path, mode)
	if type(mode) ~= "string" then
		mode = vfsRawFirst
	end
	if checkUserReadPath(path) then
		return mode
	end
	return (stringGsub(mode, "[rp]", ""))
end

local warnOnceMessages = {}
local warnOnceCount = 0 -- a widget can send different command text over & over
local function warnOnce(message)
	if warnOnceMessages[message] or warnOnceCount > 256 then -- count is shared
		return
	end
	warnOnceMessages[message] = true
	warnOnceCount = warnOnceCount + 1
	spLog("barwidgets.lua", LOG.WARNING, message)
end

local function refuseUserPath(path, reason)
	local message = tostring(path) .. ": " .. reason
	spLog("barwidgets.lua", LOG.ERROR, message)
	return message
end

local function unavailableFunction() end

local function grantUserRmlUi()
	local ok, powerUsers = pcall(vfsInclude, "luarules/configs/powerusers.lua", {}, vfsZip)
	if not ok or type(powerUsers) ~= "table" then
		return false
	end
	local accountID = getAccountID(Spring.GetMyPlayerID())
	local permissions = accountID and accountID > 0 and powerUsers[accountID]
	if type(permissions) ~= "table" then
		return false
	end
	if spGetSpectatingState() and not Spring.GetGameRulesParam("IsPlayerAccount" .. accountID) then
		return permissions.userrmlui_spectator == true
	end
	return permissions.userrmlui_player == true
end

local function CreateSandboxedSystem()
	local sandboxedTable = copyTable(table)
	sandboxedTable.save = function(t, filename, header)
		local target, reason = checkUserWritePath(filename)
		if not target then
			refuseUserPath(filename, reason)
			return
		end
		return tableSave(t, target, header)
	end

	local sandboxedDebug = { traceback = debugTraceback, getinfo = debugGetinfo }

	local sandboxedIo = copyTable(io)
	local ioOutput = io.output
	local ioInput = io.input
	local ioLines = io.lines
	sandboxedIo.open = function(path, mode)
		local checkUserPath = stringFind(mode or "r", "[wa+]") and checkUserWritePath or checkUserReadPath
		local target, reason = checkUserPath(path)
		if not target then
			return nil, refuseUserPath(path, reason)
		end
		return ioOpen(target, mode)
	end
	sandboxedIo.input = function(file)
		if type(file) ~= "string" then
			return ioInput(file)
		end
		local target, reason = checkUserReadPath(file)
		if not target then
			refuseUserPath(file, reason)
			return nil
		end
		return ioInput(target)
	end
	sandboxedIo.lines = function(filename)
		if filename == nil then
			return ioLines()
		end
		local target, reason = checkUserReadPath(filename)
		if not target then
			refuseUserPath(filename, reason)
			return unavailableFunction
		end
		return ioLines(target)
	end
	sandboxedIo.output = function(file)
		if type(file) ~= "string" then
			return ioOutput(file)
		end
		local target, reason = checkUserWritePath(file)
		if not target then
			refuseUserPath(file, reason)
			return nil
		end
		return ioOutput(target)
	end

	local sandboxedOs = copyTable(os)
	local osRemove = os.remove
	local osRename = os.rename
	sandboxedOs.remove = function(path)
		local target, reason = checkUserWritePath(path)
		if not target then
			return nil, refuseUserPath(path, reason)
		end
		return osRemove(target)
	end
	sandboxedOs.rename = function(from, to)
		local fromTarget, fromReason = checkUserWritePath(from)
		if not fromTarget then
			return nil, refuseUserPath(from, fromReason)
		end
		local toTarget, toReason = checkUserWritePath(to)
		if not toTarget then
			return nil, refuseUserPath(to, toReason)
		end
		return osRename(fromTarget, toTarget)
	end

	local sandboxedVfs = copyTable(VFS)
	local vfsCompressFolder = VFS.CompressFolder
	sandboxedVfs.CompressFolder = function(folder, archiveType, archivePath, ...)
		local target, reason = checkUserWritePath(archivePath)
		if not target then
			refuseUserPath(archivePath, reason)
			return
		end
		return vfsCompressFolder(folder, archiveType, target, ...)
	end
	sandboxedVfs.LoadFile = function(path, mode)
		return vfsLoadFile(path, getUserReadMode(path, mode))
	end
	sandboxedVfs.FileExists = function(path, mode)
		return vfsFileExists(path, getUserReadMode(path, mode))
	end
	sandboxedVfs.DirList = function(path, pattern, mode, recursive)
		return vfsDirList(path, pattern, getUserReadMode(path, mode), recursive)
	end
	sandboxedVfs.SubDirs = function(path, pattern, mode)
		return vfsSubDirs(path, pattern, getUserReadMode(path, mode))
	end
	-- This is the nilling trick again. A widget that sets its VFS nil can reach this function.
	sandboxedVfs.Include = function(path, env, mode)
		if type(env) ~= "table" then
			env = {} -- So replace nil env with empty env.
		end
		return vfsInclude(path, env, getUserReadMode(path, mode))
	end

	local sandboxedGl = copyTable(gl)
	local glSaveImage = gl.SaveImage
	-- Saving deletes any existing file at the path first.
	sandboxedGl.SaveImage = function(x, y, width, height, filename, options)
		local target, reason = checkUserWritePath(filename)
		if not target then
			refuseUserPath(filename, reason)
			return false
		end
		return glSaveImage(x, y, width, height, target, options)
	end

	local sandboxedRmlUi -- rmlui elements have event handlers that run in the document's env, etc.
	if RmlUi then
		local rmlUi = RmlUi
		local rmlUiCreateContext = rmlUi.CreateContext
		local rmlUiGetContext = rmlUi.GetContext
		local rmlUiRemoveContext = rmlUi.RemoveContext
		local rmlUiSetDebugContext = rmlUi.SetDebugContext
		local rmlUiContexts = rmlUi.contexts
		local USER_CONTEXT_PREFIX = "user:"
		local function isUserContext(context)
			return context ~= nil and stringSub(context.name, 1, #USER_CONTEXT_PREFIX) == USER_CONTEXT_PREFIX
		end
		local function getUserContextName(context)
			if type(context) == "string" then
				return USER_CONTEXT_PREFIX .. context
			end
			return isUserContext(context) and context.name or nil
		end
		-- TODO: Needs exploration for escapes by other means
		sandboxedRmlUi = setmetatable({
			CreateContext = function(name)
				return rmlUiCreateContext(USER_CONTEXT_PREFIX .. name)
			end,
			GetContext = function(name)
				return rmlUiGetContext(USER_CONTEXT_PREFIX .. name)
			end,
			RemoveContext = function(context)
				local name = getUserContextName(context)
				if name then
					return rmlUiRemoveContext(name)
				end
			end,
			SetDebugContext = function(context)
				local name = getUserContextName(context)
				if name then
					return rmlUiSetDebugContext(name)
				end
			end,
		}, {
			__index = function(_, key)
				if key == "contexts" then
					local contexts = {}
					for _, context in ipairs(rmlUiContexts or rmlUi.contexts) do
						if isUserContext(context) then
							contexts[#contexts + 1] = context
						end
					end
					return contexts
				end
				return rmlUi[key]
			end,
		})
	end

	local sandboxedScript = copyTable(Script)
	local scriptLuaUI = Script.LuaUI
	sandboxedScript.LuaUI = setmetatable({}, {
		__index = function(_, name)
			if widgetHandler.globals[name] then
				return scriptLuaUI[name]
			end
			if _G[name] ~= nil then
				warnOnce("Script.LuaUI." .. tostring(name) .. " is not available to user widgets")
			end
			return unavailableFunction
		end,
		__call = function(_, name)
			if name == nil then
				return scriptLuaUI()
			end
			return widgetHandler.globals[name] ~= nil and scriptLuaUI(name)
		end,
		__metatable = true,
	})

	local sandboxedSpring = copyTable(Spring)
	local spSetConfigString = Spring.SetConfigString
	local spCreateDir = Spring.CreateDir
	local spExtractModArchiveFile = Spring.ExtractModArchiveFile
	function sandboxedSpring.CreateDir(path)
		local target, reason = checkUserWritePath(path)
		if not target then
			refuseUserPath(path, reason)
			return nil
		end
		return spCreateDir(target)
	end
	-- The engine passes unhandled actions to LuaUI, where game widgets run them with full access.
	-- Dropped rather than raised, so widgets that still send them keep loading.
	function sandboxedSpring.SendCommands(...)
		local commands = type((...)) == "table" and (...) or { ... }
		local allowed = {}
		for _, command in ipairs(commands) do
			if type(command) == "string" and (isPrivilegedCommand(command) or isHiddenStateCommand(command)) then
				warnOnce(SANDBOXED_ERROR_USER_WIDGETS .. ": " .. command)
			else
				allowed[#allowed + 1] = command
			end
		end
		if allowed[1] ~= nil then
			spSendCommands(allowed)
		end
	end
	function sandboxedSpring.SetConfigString(key, value, useOverlay)
		if type(key) == "string" and stringLower(key) == "keybindingfile" then
			warnOnce(SANDBOXED_ERROR_USER_WIDGETS .. ": SetConfigString " .. key)
			return
		end
		return spSetConfigString(key, value, useOverlay)
	end
	-- Would replace the archive on the next launch.
	function sandboxedSpring.ExtractModArchiveFile(path)
		local target, reason = checkUserWritePath(path)
		if not target then
			refuseUserPath(path, reason)
			return false
		end
		return spExtractModArchiveFile(target)
	end
	-- Would replace the start script on the next launch.
	local function refuseEngineRestart()
		spLog("barwidgets.lua", LOG.ERROR, "User widgets cannot start, restart or reload the engine")
		return false
	end
	sandboxedSpring.Start = refuseEngineRestart
	sandboxedSpring.Restart = refuseEngineRestart
	sandboxedSpring.Reload = refuseEngineRestart
	if not allowunitcontrolwidgets then
		local function disabledOrder()
			error(SANDBOXED_ERROR_UNIT_CONTROL, 2)
		end
		for k in pairs(Spring) do
			if stringFind(k, "^GiveOrder") then
				sandboxedSpring[k] = disabledOrder
			end
		end
	end
	local sandboxedLibraries = {
		table = sandboxedTable,
		debug = sandboxedDebug,
		io = sandboxedIo,
		os = sandboxedOs,
		VFS = sandboxedVfs,
		Spring = sandboxedSpring,
		Script = sandboxedScript,
		gl = sandboxedGl,
		RmlUi = sandboxedRmlUi,
	}
	for k, v in pairs(System) do
		SandboxedSystem[k] = sandboxedLibraries[k] or v
	end

	-- A user widget that sets a global func to nil can then call the underlying global again.
	-- The workaround does nothing in the locals-access system setup which is metatable-backed.
	local function refuseSharedEnvFunction()
		spLog("barwidgets.lua", LOG.ERROR, "User widgets can only use their own environment functions")
	end
	SandboxedSystem.getfenv = refuseSharedEnvFunction
	SandboxedSystem.setfenv = refuseSharedEnvFunction
	SandboxedSystem.loadstring = refuseSharedEnvFunction
	SandboxedSystem.loadfile = refuseSharedEnvFunction
	SandboxedSystem.dofile = refuseSharedEnvFunction
	SandboxedSystem.require = refuseSharedEnvFunction
	-- The same goes for global tables. Either sub them back in or remove.
	SandboxedSystem.debug = sandboxedDebug
	SandboxedSystem.socket = nil
	-- TODO: restore once rmlui security assessment finishes
	SandboxedSystem.RmlUi = grantUserRmlUi() and RmlUi or nil
end

function widgetHandler:Initialize()
	widgetHandler:CreateQueuedReorderFuncs()
	widgetHandler:HookReorderSpecialFuncs()
	self:LoadConfigData()
	self:SetWindowsHideInterface(Spring.GetConfigInt("WindowsHideInterface", 0) == 1)
	self:InitPause()

	if self.allowUserWidgets == nil then
		self.allowUserWidgets = true
	end

	Spring.CreateDir(LUAUI_DIRNAME .. "Config")

	unsortedWidgets = {}
	CreateSandboxedSystem()

	if self.allowUserWidgets and allowuserwidgets then
		spEcho("LuaUI: Allowing User Widgets")
		loadWidgetFiles(WIDGET_DIRNAME, vfsRaw)
		loadWidgetFiles(RML_WIDGET_DIRNAME, vfsRaw)
	else
		spEcho("LuaUI: Disallowing User Widgets")
	end

	loadWidgetFiles(WIDGET_DIRNAME, vfsZip)
	loadWidgetFiles(RML_WIDGET_DIRNAME, vfsZip)

	local ModuleHandler = require("modules/module_handler", nil, vfsZip)
	ModuleHandler.Register(vfsZip)
	for _, moduleWidgetDir in ipairs(ModuleHandler.WidgetDirs(vfsZip)) do
		loadWidgetFiles(moduleWidgetDir, vfsZip)
	end
	for _, moduleWidgetDir in ipairs(ModuleHandler.RmlWidgetDirs(vfsZip)) do
		loadWidgetFiles(moduleWidgetDir, vfsZip)
	end

	tableSort(unsortedWidgets, function(w1, w2)
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

	-- A widget that takes the place of others (GetInfo `replaces`: a name or a list) keeps them from
	-- loading while it is on: they are switched off, and told which widget took their place so it
	-- can hand it back. Switching one off once it has started would still run its Initialize and
	-- Shutdown, which can undo what the new one set up.
	local replacedBy = {} ---@type table<string, string>
	for _, w in ipairs(unsortedWidgets) do
		local replaces = w.whInfo.replaces
		for _, name in ipairs(type(replaces) == "table" and replaces or { replaces }) do
			if name ~= w.whInfo.name then
				replacedBy[name] = w.whInfo.name
			end
		end
	end

	-- Every call-in once up front: a full pass after each insert was ~35k engine calls per load.
	self:UpdateCallIns()
	insertingStartupWidgets = true
	for _, w in ipairs(unsortedWidgets) do
		local name = w.whInfo.name
		local basename = w.whInfo.basename
		local by = replacedBy[name]
		if by then
			local ki = self.knownWidgets[name]
			ki.active, ki.replacedBy = false, by
			self.orderList[name] = 0
			spEcho(string.format("Not loading widget %-18s  <%s>  (replaced by %s)", name, basename, by))
		else
			local source = self.knownWidgets[name].fromZip and "mod: " or "user:"
			spEcho(string.format("Loading widget from %s  %-18s  <%s> ...", source, name, basename))
			Yield()
			widgetHandler:InsertWidgetRaw(w)
		end
	end
	insertingStartupWidgets = false
	-- Kept, the list would hold every startup widget in memory after it is switched off.
	unsortedWidgets = {}

	-- Since Initialize is run out of the normal callin wrapper by InsertWidget, we, need to reorder explicitly here.
	widgetHandler:PerformReorders()

	-- save the active widgets, and their ordering
	self:SaveConfigData()
end

function widgetHandler:AddSpadsMessage(contents)
	-- The canonical, agreed format is the following:
	-- This must be called from an unsynced context, cause it needs playername and playerid and stuff

	-- The game sends a lua message, which should be base64'd to prevent weird character bullshit:
	-- Lua Message Format:
	-- leetspeek luaspads:base64message
	-- lu@$p@d$:ABCEDFGS==
	-- Must contain, with triangle bracket literals <playername>[space]<contents>[space]<gameseconds>
	-- will get parsed by barmanager, and forwarded to autohostmonitor as:
	-- match-event <UnnamedPlayer> <LuaUI\Widgets\test_unitshape_instancing.lua/czE3YEocdDJ8bLoO5++a2A==> <35>
	local myPlayerID = Spring.GetLocalPlayerID()
	local myPlayerName = Spring.GetPlayerInfo(myPlayerID, false)
	local gameSeconds = math.max(0, math.round(Spring.GetGameFrame() / 30))
	if type(contents) == "table" then
		contents = Json.encode(contents)
	end
	local rawmessage = string.format("<%s> <%s> <%d>", myPlayerName, contents, gameSeconds)
	local b64message = "lu@$p@d$:" .. string.base64Encode(rawmessage)
	Spring.SendLuaRulesMsg(b64message)
end

function widgetHandler:ReloadUserWidgetFromGameRaw(name)
	local ki = self.knownWidgets[name]
	if not ki or not vfsFileExists(ki.filename, vfsZip) then
		return
	end
	local w = widgetHandler:LoadWidget(ki.filename, true, ki.localsAccess, true)
	if w then
		widgetHandler:InsertWidgetRaw(w)
		spEcho("Reloaded from game: " .. name .. "  (user 'unit control' widgets disabled for this game)")
	end
	return w
end

-- Every error a widget raises is kept against its file for the rest of the session: by
-- file rather than by name, because most of the ways loading can fail happen before the
-- widget has told anyone its name. The same error from the same place is one entry with
-- a count, moved to the end, rather than an entry per time - a widget re-enabled into the
-- same crash would otherwise push everything else out. At most twenty are kept.
--
-- `callin` is nil for a failure to load. `stops` says this error is why the widget is not
-- running, and `stopped` holds it until the widget next loads. The handler's `errorCount`
-- counts every error of every widget, repeats included, so a panel can tell a new one has
-- arrived with one comparison instead of reading anybody's log.
function widgetHandler:RecordError(basename, callin, message, stops)
	local log = self.errorLog[basename]
	if not log then
		log = { entries = {} }
		self.errorLog[basename] = log
	end

	local entries = log.entries
	local entry
	for i = 1, #entries do
		if entries[i].callin == callin and entries[i].message == message then
			entry = tableRemove(entries, i)
			break
		end
	end
	local frame = Spring.GetGameFrame()
	if entry then
		entry.count = entry.count + 1
		entry.lastFrame = frame
	else
		entry = { callin = callin, message = message, count = 1, frame = frame, lastFrame = frame }
	end
	entries[#entries + 1] = entry
	if #entries > 20 then
		tableRemove(entries, 1)
	end

	self.errorCount = self.errorCount + 1
	if stops then
		log.stopped = entry
	end

	return entry
end

-- Why a widget did not load, keyed by its file.
--
-- These used to be echoed and forgotten, which left the widget selector able to say a
-- widget was asked for and is not running, but not why - and the reason was sitting in
-- infolog.txt the whole time. Keyed by basename because most of the ways loading can fail
-- happen before the widget has told anyone its name.
local function loadFailed(basename, reason)
	spEcho("Failed to load: " .. basename .. "  (" .. reason .. ")")
	widgetHandler:RecordError(basename, nil, reason, true)
end

-- A user widget's file runs under the memory guard like its call-ins do, and the WG entries it
-- makes count as its own.
local function runWidgetChunk(chunk, widget, fromZip, basename)
	if fromZip or not memoryGuard then
		return pcall(chunk)
	end
	memoryGuard.register(widget)
	local wgKeys = memoryGuard.snapshotWG()
	memoryGuard.enter(widget)
	local success, err = pcall(chunk)
	local tripped = memoryGuard.leave()
	memoryGuard.claimWG(widget, wgKeys)
	if tripped then
		return false, memoryGuard.takeTrip(widget, basename)
	end
	return success, err
end

-- Whether a source reaches for the RmlUi API (`RmlUi.x`, `RmlUi[x]`, `not RmlUi`), not just names it.
-- Plain finds first: two pattern searches over every widget's source cost ~60 ms per LuaUI load.
local function usesRmlUi(text)
	local init = 1
	while true do
		local s = stringFind(text, "RmlUi", init, true)
		if not s then
			return false
		end
		local e = s + 4
		if stringFind(text, "^%s*[%.%[]", e + 1) then
			return true
		end
		local runStart = s -- of the %s run in front of it
		for i = s - 1, 1, -1 do
			local b = stringByte(text, i)
			if b ~= 32 and (b < 9 or b > 13) then
				break
			end
			runStart = i
		end
		if runStart < s and runStart > 3 and stringSub(text, runStart - 3, runStart - 1) == "not" then
			return true
		end
		init = e + 1
	end
end

-- Not a handler method. `fromZip` grants full System to anything with handler access.
local newWidget ---@type function

-- User widgets can read its own environment and an env it builds. Everything else returns its own env.
-- Weak values too: a widget's own entry points at itself, and Lua 5.1 keeps a weak key alive
-- while its value is, which kept every widget ever loaded in memory.
local ownedEnvs = setmetatable({}, { __mode = "kv" }) ---@type table<table, table>

local function userEnv(widget, env)
	return ownedEnvs[env] == widget and env or widget
end

local function callerFrame(f)
	if f == nil then
		return 2
	elseif type(f) == "number" and f > 0 then
		return f + 1
	end
	return f
end

local function getLocalName(level, index)
	local name = debugGetlocal(level + 1, index)
	return name
end

-- Prevent widgets rewriting their own fields, namely unit control flags.
local loadedWidgets = setmetatable({}, { __mode = "k" }) ---@type table<table, boolean>
-- What each user widget's proxy hands out as customCommands, kept here so the widget cannot swap it.
local userCustomCommands = setmetatable({}, { __mode = "k" }) ---@type table<table, table>

local function findPrivilegedCommand(list)
	if type(list) ~= "table" then
		return nil
	end
	for _, value in pairs(list) do
		if type(value) == "string" and (isPrivilegedCommand(value) or isHiddenStateCommand(value)) then
			return value
		end
	end
	return nil
end

-- A command button runs its action when clicked. Copied first, so the widget cannot change it once checked.
local function moveUserCustomCommands(source, target)
	for i = 1, #source do
		local desc = source[i]
		source[i] = nil
		if type(desc) == "table" then
			local copy = {}
			local duplicateKey
			for k, v in pairs(desc) do
				if type(k) == "string" and copy[stringLower(k)] ~= nil then
					duplicateKey = stringLower(k) -- the engine forces keys to lowercase before comparing
				end
				copy[k] = type(v) == "table" and copyTable(v) or v
			end
			local privilegedCommand = findPrivilegedCommand({ copy.action })
				or findPrivilegedCommand(copy.actions)
				or findPrivilegedCommand(copy.params)
			if duplicateKey then
				warnOnce("User widget command description has a duplicate key: " .. duplicateKey)
			elseif privilegedCommand then
				warnOnce(SANDBOXED_ERROR_USER_WIDGETS .. ": " .. privilegedCommand)
			else
				target[#target + 1] = copy
			end
		end
	end
end

function widgetHandler:LoadWidget(filename, fromZip, enableLocalsAccess, reload)
	local basename = Basename(filename)
	local text = vfsLoadFile(
		filename,
		not (self.allowUserWidgets and allowuserwidgets and not fromZip and not reload) and vfsZip or vfsRawFirst
	)
	if text == nil then
		return loadFailed(basename, "missing file: " .. filename)
	end

	if enableLocalsAccess then
		-- enableLocalsAccess makes it so local variables within the widget can be accessed as if they were globals (as
		-- opposed to not being able to access them at all from outside the widget). This is accomplished by loading the
		-- widget with an additional code snippet to list all of the local variables, getting that result, and then
		-- loading again with a code snippet that sets up external access to those variables.
		localsAccess = localsAccess or require("common/testing/locals_access")

		local textWithLocalsDetector = text .. localsAccess.localsDetectorString

		local chunk, err = loadstring(textWithLocalsDetector, filename)
		if chunk == nil then
			return loadFailed(basename, err)
		end

		local widget = newWidget(widgetHandler, enableLocalsAccess, fromZip)
		if not fromZip then
			widget.debug.getlocal = getLocalName -- the detector needs getlocal -- ! do not give to user widgets
		end
		setfenv(chunk, widget)
		local success, err = runWidgetChunk(chunk, widget, fromZip, basename)
		if not success then
			return loadFailed(basename, err)
		end
		if err == false then
			return nil -- widget asked for a silent death
		end

		local localsNames = err

		text = text .. localsAccess.generateLocalsAccessStr(localsNames)
	end

	local chunk, err = loadstring(text, filename)
	if chunk == nil then
		return loadFailed(basename, err)
	end

	local widget, canControlUnits = newWidget(widgetHandler, enableLocalsAccess, fromZip)
	setfenv(chunk, widget)
	local success, err = runWidgetChunk(chunk, widget, fromZip, basename)
	if not success then
		return loadFailed(basename, err)
	end
	if err == false then
		return nil -- widget asked for a silent death
	end

	if enableLocalsAccess then
		setmetatable(widget, localsAccess.generateLocalsAccessMetatable(getmetatable(widget)))
	end

	self:FinalizeWidget(widget, filename, basename)
	local name = widget.whInfo.name

	if zipOnly[name] and not fromZip then
		spEcho("Ignoring user copy: " .. filename .. "  (the game provides " .. name .. ")")
		return nil
	end

	-- Only the game gets to hide a widget: a hidden one always loads and cannot be disabled.
	local hidden = fromZip and widget.whInfo.hidden or false

	if fromZip and basename == SELECTOR_BASENAME then
		self.orderList[name] = 1 -- always load the widget selector
	elseif hidden then
		self.orderList[name] = 1 -- hidden widgets back other widgets, so they always load
	end

	err = self:ValidateWidget(widget)
	if err then
		return loadFailed(basename, err)
	end

	if widget.GetInfo == nil then
		-- Do not keep widgets known but unregistered (active, no order entry)
		return loadFailed(basename, "no GetInfo() call")
	end

	local knownInfo = self.knownWidgets[name]
	if knownInfo and not reload then
		if knownInfo.active then
			return loadFailed(basename, "duplicate name")
		end
	else
		-- create a knownInfo table
		knownInfo = {}
		knownInfo.desc = widget.whInfo.desc
		knownInfo.author = widget.whInfo.author
		knownInfo.basename = widget.whInfo.basename
		knownInfo.filename = widget.whInfo.filename
		knownInfo.fromZip = fromZip
		knownInfo.hidden = hidden
		-- Whether the widget ships switched on. Kept here because this is the only place it is
		-- seen for a widget that ends up not being loaded: whInfo belongs to the instance, and
		-- a widget that is off has no instance.
		knownInfo.enabled = widget.whInfo.enabled
		-- And whether it draws through RmlUi, which nothing else records. Read out of the
		-- source, because where the file sits does not answer it: most RmlUi widgets live
		-- under LuaUI/RmlWidgets but a player's own can sit anywhere and still use the API.
		-- Matched on the API being reached for rather than the word appearing, so a widget
		-- that only mentions RmlUi in a comment is not mistaken for one.
		knownInfo.rml = usesRmlUi(text)
		-- And what it shares with other widgets through WG. The source is in hand here, and a source
		-- the reading trips over must not stop the widget from loading.
		if widgetDependencies then
			local ok, deps = pcall(widgetDependencies.scan, text, vfsLoadFile)
			knownInfo.deps = ok and deps or nil
		end
		self.knownWidgets[name] = knownInfo
		self.knownCount = self.knownCount + 1
		self.knownChanged = true
	end
	knownInfo.active = true
	knownInfo.localsAccess = enableLocalsAccess

	-- Enabling
	local order = self.orderList[name]
	if order then
		if order <= 0 then
			order = nil
		end
	else
		if widget.whInfo.enabled and (knownInfo.fromZip or self.allowUserWidgets) then
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

	-- user widgets may not access widgetHandler
	-- Granted last, so a widget refused above never holds the real handler.
	if widget.whInfo.handler and fromZip then
		widget.widgetHandler = self
	end

	if not fromZip then
		local md5 = VFS.CalculateHash(text, 0)
		if widgetHandler.widgetHashes[md5] == nil then
			widgetHandler.widgetHashes[md5] = filename
		end
	end

	-- load the config data
	local config = self.configData[name]
	if widget.SetConfigData and config then
		widget:SetConfigData(config)
	end

	-- It loaded, so whatever stopped it last time no longer is. What it raised stays in the
	-- log: a widget that crashed and came back is still worth being able to look into.
	local log = self.errorLog[basename]
	if log then
		log.stopped = nil
	end

	loadedWidgets[widget] = canControlUnits and true or false

	return widget
end

local WidgetMeta = {
	__index = System,
	__metatable = true,
}

local SandboxedWidgetMeta = {
	__index = SandboxedSystem,
	__metatable = true,
}

-- Turned off for its memory: it stays off next game, and the selector says why.
local function disableForMemory(w, reason)
	local info = w.whInfo
	local entry = widgetHandler:RecordError(info.basename, nil, reason, true)
	entry.memory = true
	widgetHandler:DisableWidget(info.name)
end

if MemoryGuard then
	local spGetTimer, spGetTimerMicros, spDiffTimers = Spring.GetTimer, Spring.GetTimerMicros, Spring.DiffTimers
	local spGetLuaMemUsage = Spring.GetLuaMemUsage
	local startTimer = spGetTimer()
	memoryGuard = MemoryGuard.new({
		now = function()
			return spDiffTimers(spGetTimer(), startTimer)
		end,
		startTimer = spGetTimerMicros,
		elapsedMs = function(timer)
			return spDiffTimers(spGetTimerMicros(), timer, true, true)
		end,
		poolUsage = function()
			local _, _, globalKB = spGetLuaMemUsage()
			return globalKB
		end,
		gameFrame = Spring.GetGameFrame,
		setCollectorBudget = function(ms)
			Spring.GarbageCollectCtrl(nil, nil, nil, nil, nil, nil, ms)
		end,
		activeWidgets = function()
			return widgetHandler.widgets
		end,
		isActive = function(w)
			return table.getKeyOf(widgetHandler.widgets, w) ~= nil
		end,
		ownsEnv = function(env, w)
			return ownedEnvs[env] == w
		end,
		stopRoots = function()
			return {
				{ System, 1 },
				{ SandboxedSystem, 1 },
				{ _G, 1 },
				{ widgetHandler, 1 },
				{ widgetHandler.WG, 2 },
				{ UnitDefs, 1 },
				{ WeaponDefs, 1 },
				{ FeatureDefs, 1 },
				{ WidgetMeta, 0 },
				{ SandboxedWidgetMeta, 0 },
			}
		end,
		WG = widgetHandler.WG,
		disable = disableForMemory,
		notify = function(text)
			spEcho("\255\255\170\100" .. text)
		end,
		log = spEcho,
		translate = function(key, vars)
			return BAR.I18N("ui.widgetMemory." .. key, vars)
		end,
		-- 0 for widget authors who want to see their numbers without anything being stopped
		enforce = Spring.GetConfigInt("UserWidgetMemoryLimits", 1) ~= 0,
	})
end

newWidget = function(self, enableLocalsAccess, fromZip, filename)
	tracyZoneBeginN("W:NewWidget")
	local widget = {}
	local canControlUnits = fromZip or allowunitcontrolwidgets

	if enableLocalsAccess then
		local systemRef = fromZip and System or SandboxedSystem
		-- copy the system calls into the widget table
		for k, v in pairs(systemRef) do
			widget[k] = v
		end
	else
		local metaRef = fromZip and WidgetMeta or SandboxedWidgetMeta
		-- use metatable redirection
		setmetatable(widget, metaRef)
	end

	widget.WG = self.WG -- the shared table
	widget.widget = widget -- easy self referencing

	-- wrapped calls (closures)
	widget.widgetHandler = {}
	local wh = widget.widgetHandler
	widget.canControlUnits = canControlUnits
	local includeMode = fromZip and vfsZip or vfsRawFirst
	widget.include = function(f)
		local mode = includeMode
		if not fromZip then
			mode = getUserReadMode(LUAUI_DIRNAME .. tostring(f), includeMode)
		end
		return include(f, widget, mode)
	end

	ownedEnvs[widget] = widget
	-- The handler can build owned environments for widgets to run loaded code in isolation.
	-- Use it to load data that sets globals and then read them back, like in the following:
	-- - `local env = newfenv(); loadstring(raw, nil, env)(); use(env.loadedGlobalName)`
	-- - `setfenv(chunk, newfenv()); chunk()`
	-- But in general I have no expectation you will need to inspect and reflect widget code.
	-- If you're loading code in your widgets, still, use this. Inspect it at load, then pull
	-- out trusted functions to setfenv to your widget to grant permissions or keep isolated.
	widget.newfenv = function()
		local env = {}
		ownedEnvs[env] = widget
		return env
	end
	widget.getfenv = function(f)
		return userEnv(widget, getfenv(callerFrame(f)))
	end
	widget.setfenv = function(f, env)
		local frame = callerFrame(f)
		if ownedEnvs[getfenv(frame)] ~= widget then
			spLog("barwidgets.lua", LOG.ERROR, "setfenv: cannot change this environment")
			return type(f) == "function" and f or nil
		end
		return setfenv(frame, env)
	end
	widget.loadstring = function(text, chunkname, env)
		if type(env) ~= "table" then
			env = userEnv(widget, getfenv(2))
		end
		return loadSourceChunk(text, chunkname, env)
	end
	widget.loadfile = function(filename)
		if not fromZip then
			local target, reason = checkUserReadPath(filename)
			if not target then
				return nil, refuseUserPath(filename, reason)
			end
			filename = target
		end
		return loadSourceFile(filename, userEnv(widget, getfenv(2)))
	end
	widget.dofile = function(filename)
		if not fromZip then
			local target, reason = checkUserReadPath(filename)
			if not target then
				error(refuseUserPath(filename, reason), 2)
			end
			filename = target
		end
		local chunk, err = loadSourceFile(filename, userEnv(widget, getfenv(2)))
		if not chunk then
			error(err, 0)
		end
		return chunk()
	end
	if not fromZip then
		widget.debug = { traceback = debugTraceback, getinfo = debugGetinfo }
		local customCommands = {}
		userCustomCommands[widget] = customCommands
		wh.customCommands = customCommands
		-- User widgets keep reading raw files first. Called through pcall or as a tail call, the caller's
		-- env is pcall's or unknown, and the widget's own table stands in for it.
		local function callerEnv()
			local ok, env = pcall(getfenv, 4)
			return ok and userEnv(widget, env) or widget
		end
		widget.VFS = copyTable(SandboxedSystem.VFS)
		widget.VFS.Include = function(path, env, mode)
			if type(env) ~= "table" then
				env = callerEnv()
			end
			return vfsInclude(path, env, getUserReadMode(path, mode))
		end
		widget.require = function(path, env, mode)
			if type(env) ~= "table" then
				env = callerEnv()
			end
			return require(path, env, getUserReadMode(type(path) == "string" and path .. ".lua", mode))
		end
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
	wh.RegisterUnitCommand = function(_, cmdID)
		self:RegisterUnitCommand(widget, cmdID)
	end

	wh.AddAction = function(_, cmd, func, data, types)
		return self.actionHandler:AddAction(widget, cmd, func, data, types)
	end
	wh.RemoveAction = function(_, cmd, types)
		return self.actionHandler:RemoveAction(widget, cmd, types)
	end
	wh.actionHandler = {
		AddAction = function(_, _, cmd, func, data, types)
			return self.actionHandler:AddAction(widget, cmd, func, data, types)
		end,
		RemoveAction = function(_, _, cmd, types)
			return self.actionHandler:RemoveAction(widget, cmd, types)
		end,
		AddSyncAction = function(_, _, cmd, func, data)
			return self.actionHandler:AddSyncAction(widget, cmd, func, data)
		end,
		RemoveSyncAction = function(_, _, cmd)
			return self.actionHandler:RemoveSyncAction(widget, cmd)
		end,
		KeyAction = function(_, press, key, mods, isRepeat, _, actions)
			local bridged = {}
			if type(actions) == "table" then
				-- Key actions reuse the same command filters as Spring.SendCommands.
				for _, action in ipairs(actions) do
					local command = type(action) == "table" and action.command
					local extra = type(action) == "table" and type(action.extra) == "string" and action.extra or ""
					local text = type(command) == "string" and command .. " " .. extra
					if text and not isPrivilegedCommand(text) and not isHiddenStateCommand(text) then
						bridged[#bridged + 1] = { command = command, extra = extra }
					else
						warnOnce(SANDBOXED_ERROR_USER_WIDGETS .. ": " .. (text or tostring(command)))
					end
				end
			end
			if bridged[1] == nil then
				return false
			end
			-- Do not pass a scan code, so keypress handling does not wait for a release.
			return self.actionHandler:KeyAction(press, key, mods, isRepeat, nil, bridged)
		end,
	}

	wh.RegisterGlobal = function(_, name, value)
		return self:RegisterGlobal(widget, name, value)
	end
	wh.DeregisterGlobal = function(_, name)
		return self:DeregisterGlobal(widget, name)
	end
	wh.SetGlobal = function(_, name, value)
		return self:SetGlobal(widget, name, value)
	end

	-- Modal windows (see the "Modal windows" block further down)
	wh.RegisterModalWindow = function(_, isOpen)
		return self:RegisterModalWindow(widget, isOpen)
	end
	wh.DeregisterModalWindow = function(_)
		return self:DeregisterModalWindow(widget)
	end
	wh.IsModalActive = function(_)
		return self:IsModalActive()
	end
	wh.ModalAllows = function(_, owner)
		return self:ModalAllows(owner)
	end
	wh.GetModalRevision = function(_)
		return self:GetModalRevision()
	end
	wh.GetWidgetsRevision = function(_)
		return self:GetWidgetsRevision()
	end
	wh.GetActiveWidgetFiles = function(_)
		return self:GetActiveWidgetFiles()
	end
	wh.SetWindowsHideInterface = function(_, enabled)
		return self:SetWindowsHideInterface(enabled)
	end
	wh.SetWindowsPauseGame = function(_, enabled)
		return self:SetWindowsPauseGame(enabled)
	end
	wh.HideInterface = function(_, reason, keep)
		return self:HideInterface(reason, keep)
	end
	wh.ShowInterface = function(_, reason)
		return self:ShowInterface(reason)
	end
	wh.IsInterfaceHidden = function(_)
		return self:IsInterfaceHidden()
	end
	-- see widgetHandler:Pause
	wh.Pause = function(_, source)
		return self:Pause(source)
	end
	wh.Unpause = function(_, source)
		return self:Unpause(source)
	end

	if not fromZip then
		-- Warnings are not repeated to avoid clogging the infolog. Error logs are repeated on purpose.
		local warned = {}
		-- TODO: Remove friendly-sandboxing eventually. Code should error or crash on invalid accesses.
		local function substituteUnavailable(name, value)
			if value == nil then
				return nil
			end
			if not warned[name] then
				warned[name] = true
				local info = rawget(widget, "whInfo")
				spLog(
					"barwidgets.lua",
					LOG.WARNING,
					tostring(info and info.name or "A user widget")
						.. ": "
						.. name
						.. " is not available to user widgets"
				)
			end
			if type(value) == "function" then
				return unavailableFunction
			elseif type(value) == "table" then
				return {}
			end
		end

		-- Sandboxed members are handled via metatable, not collected individually:
		setmetatable(wh, {
			__index = function(_, key)
				return substituteUnavailable("widgetHandler." .. tostring(key), self[key])
			end,
		})
		setmetatable(wh.actionHandler, {
			__index = function(_, key)
				return substituteUnavailable("widgetHandler.actionHandler." .. tostring(key), self.actionHandler[key])
			end,
		})
		setmetatable(widget.debug, {
			__index = function(_, key)
				return substituteUnavailable("debug." .. tostring(key), debug[key])
			end,
		})
	end
	tracyZoneEnd()
	return widget, canControlUnits
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
		wi.hidden = info.hidden or false
		wi.modalExempt = info.modalExempt or false
		wi.replaces = info.replaces
		wi.unsafe = info.unsafe or false
		wi.depends = info.depends
		wi.control = info.control or false
		wi.handler = info.handler or false
	end

	widget.whInfo = {} --  a proxy table
	local mt = {
		__index = wi,
		__newindex = function()
			error("whInfo tables are read-only")
		end,
		__metatable = "protected",
	}
	setmetatable(widget.whInfo, mt)
	-- cache tracy zone name strings to avoid per-frame string allocation. Saves 0.5us per tracy call, (1 us -> 0.5us)
	if tracy then
		widget._tracyUpdateName = "W:Update:" .. wi.name
		widget._tracyViewResizeName = "W:ViewResize:" .. wi.name
		widget._tracyDrawScreenName = "W:DrawScreen:" .. wi.name
		widget._tracyDrawGenesisName = "W:DrawGenesis:" .. wi.name
		widget._tracyDrawWorldName = "W:DrawWorld:" .. wi.name
		widget._tracyDrawWorldPreUnitName = "W:DrawWorldPreUnit:" .. wi.name
		widget._tracyDrawScreenEffectsName = "W:DrawScreenEffects:" .. wi.name
		widget._tracyDrawScreenPostName = "W:DrawScreenPost:" .. wi.name
		widget._tracyGameStartName = "W:GameStart:" .. wi.name
		widget._tracyPlayerChangedName = "W:PlayerChanged:" .. wi.name
		widget._tracyGameFrameName = "W:GameFrame:" .. wi.name
		widget._tracyGameFramePostName = "W:GameFramePost:" .. wi.name
		widget._tracyVisibleUnitsChangedName = "W:VisibleUnitsChanged:" .. wi.name
		widget._tracyVisibleUnitAddedName = "W:VisibleUnitAdded:" .. wi.name
		widget._tracyVisibleUnitRemovedName = "W:VisibleUnitRemoved:" .. wi.name
		widget._tracyUnitFinishedName = "W:UnitFinished:" .. wi.name
		widget._tracyUnitDestroyedName = "W:UnitDestroyed:" .. wi.name
		widget._tracyFeatureCreatedName = "W:FeatureCreated:" .. wi.name
		widget._tracyFeatureDestroyedName = "W:FeatureDestroyed:" .. wi.name
		widget._tracyVisibleExplosionName = "W:VisibleExplosion:" .. wi.name
		widget._tracyCommandNotifyName = "W:CommandNotify:" .. wi.name
		widget._tracyRecvLuaMsgName = "W:RecvLuaMsg:" .. wi.name
	end
end

function widgetHandler:ValidateWidget(widget)
	if widget.GetTooltip and not widget.IsAbove then
		return "Widget has GetTooltip() but not IsAbove()"
	end
	return nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function widgetFailure(w, funcName, errorMsg)
	local memory = memoryGuard and memoryGuard.failure(w, funcName, errorMsg)
	if memory == "handled" then
		return nil
	end
	local name = w.whInfo.name
	-- Kept against the widget as well as said, and before anything below can reload it: the
	-- log is how the widget selector shows what went wrong once the line has scrolled out of
	-- the console. Shutdown is the one callin whose failure does not take the widget down.
	widgetHandler:RecordError(w.whInfo.basename, funcName, tostring(errorMsg), funcName ~= "Shutdown")
	local errorBase = "Error"
	if funcName ~= "Shutdown" then
		widgetHandler:RemoveWidget(w)
		if not loadedWidgets[w] and errorMsg:find(SANDBOXED_ERROR_UNIT_CONTROL) then
			errorBase = "Sandbox error"
			widgetHandler:ReloadUserWidgetFromGame(name)
		end
	else
		spEcho("Error in Shutdown()")
	end
	spEcho(errorBase .. " in " .. funcName .. "(): " .. tostring(errorMsg))
	spEcho("Removed widget: " .. name)
	if memory == "reload" then
		-- Ran out of memory that a user widget most likely filled, and was freed since.
		widgetHandler:EnableWidget(name)
	end
	return nil
end

local function SafeWrapFuncNoGL(func, funcName)
	return function(w, ...)
		-- New method avoids needless table creation, but is limited to at most 2 return values per callin!
		local r1, r2, r3 = pcall(func, w, ...)
		if r1 then
			return r2, r3
		else
			return widgetFailure(w, funcName, r2)
		end
	end
end

local function SafeWrapFuncGL(func, funcName)
	return function(w, ...)
		glPushAttrib(GL_ALL_ATTRIB_BITS)
		glPopAttrib()
		local r1, r2, r3 = pcall(func, w, ...)
		if r1 then
			return r2, r3
		else
			return widgetFailure(w, funcName, r2)
		end
	end
end

-- What a user widget's call-in allocates is counted, and one that allocates far too much is stopped.
local function SafeWrapFuncUser(func, funcName)
	local guard = memoryGuard --[[@as table]]
	local guardEnter, guardLeave, tripError = guard.enter, guard.leave, guard.TRIP_ERROR
	local function wrapper(w, ...)
		guardEnter(w)
		local r1, r2, r3 = pcall(func, w, ...)
		if guardLeave() then
			r1, r2 = false, tripError -- also when the widget caught it itself
		end
		if r1 then
			return r2, r3
		else
			return widgetFailure(w, funcName, r2)
		end
	end
	guard.addWrapper(wrapper)
	return wrapper
end

local function SafeWrapFunc(func, funcName)
	if not SAFEDRAW then
		return SafeWrapFuncNoGL(func, funcName)
	else
		if stringSub(funcName, 1, 4) ~= "Draw" then
			return SafeWrapFuncNoGL(func, funcName)
		else
			return SafeWrapFuncGL(func, funcName)
		end
	end
end

local function SafeWrapWidget(widget)
	-- User widgets cannot opt out: the memory guard sits in the wrapper.
	local user = memoryGuard ~= nil and memoryGuard.isUser(widget)
	if SAFEWRAP <= 0 then
		return
	elseif SAFEWRAP == 1 then
		if widget.whInfo.unsafe and not user then
			spEcho("LuaUI: loaded unsafe widget: " .. widget.whInfo.name)
			return
		end
	end

	local wrap = user and SafeWrapFuncUser or SafeWrapFunc
	for _, ciName in ipairs(callInLists) do
		if widget[ciName] then
			widget[ciName] = wrap(widget[ciName], ciName)
		end
	end

	if widget.Initialize then
		widget.Initialize = wrap(widget.Initialize, "Initialize")
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
		tableInsert(t, index, w)
	end
end

---Removes all elements equal to value from given array.
---@generic V
---@param t V[]
---@param value V
local function ArrayRemove(t, value)
	for i = #t, 1, -1 do
		if t[i] == value then
			tableRemove(t, i)
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
	self:HookReorderPost("DrawScreen", true)
	self:HookReorderPost("Update", true)
	self:HookReorderPost("MouseMove")
	self:HookReorderPost("MouseRelease")
	self:HookReorderPost("ConfigureLayout")
end

function widgetHandler:HookReorderPost(name, topMethod)
	-- Add callinDepth updating and PerformReorders to methods not getting it through UpdateCallIns.
	-- Can only be used for methods returning just one result.
	-- We define some methods to be topMethod, those will hard set the callinDepth as a consistency
	-- measure.
	local func = self[name]
	if not func or not type(func) == "function" then
		spLog("barwidgets.lua", LOG.WARNING, name .. " does not exist or isn't a function")
		return
	end
	if self[name .. "Raw"] then
		spLog("barwidgets.lua", LOG.WARNING, name .. "Raw already exists")
		return
	end
	self[name .. "Raw"] = func
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
	-- It will also create the widgetHandler usual api queueing the calls.
	local reorderFuncNames = {
		"InsertWidget",
		"RemoveWidget",
		"EnableWidget",
		"DisableWidget",
		"ReloadUserWidgetFromGame",
		"ToggleWidget",
		"LowerWidget",
		"RaiseWidget",
		"UpdateWidgetCallIn",
		"RemoveWidgetCallIn",
	}
	local queueReorder = widgetHandler.QueueReorder

	for idx, name in ipairs(reorderFuncNames) do
		-- linked method index
		reorderFuncs[#reorderFuncs + 1] = widgetHandler[name .. "Raw"]

		-- widgetHandler api
		widgetHandler[name] = function(s, ...)
			queueReorder(s, idx, ...)
		end
	end
end

function widgetHandler:QueueReorder(methodIndex, ...)
	reorderQueue[#reorderQueue + 1] = { methodIndex, ... }
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
	local canControlUnits = loadedWidgets[widget]
	if canControlUnits == nil then
		spEcho("Blocked loading: a widget that was not loaded from a file")
		return
	end
	if self:FindWidget(widget.whInfo.name) then
		spEcho("Blocked loading: " .. widget.whInfo.name .. "  (already running)")
		return
	end
	if not platformCheck(widget.whInfo.depends) then
		local name = widget.whInfo.name
		if self.knownWidgets[name] then
			self.knownWidgets[name].active = false
		end
		spEcho("Missing capabilities:  " .. name .. ". Disabling.")
		self:RecordError(widget.whInfo.basename, nil, "missing capabilities", true)
		return
	end
	-- Gracefully ignore/reload good control widgets advertising themselves as such, if user 'unit control' widgets disabled.
	if widget.whInfo.control and not canControlUnits then
		local name = widget.whInfo.name
		if not self:ReloadUserWidgetFromGameRaw(name) then
			if self.knownWidgets[name] then
				self.knownWidgets[name].active = false
			end
			spEcho("Blocked loading: " .. name .. "  (user 'unit control' widgets disabled for this game)")
			self:RecordError(
				widget.whInfo.basename,
				nil,
				"user 'unit control' widgets are disabled for this game",
				true
			)
		end
		return
	end

	SafeWrapWidget(widget)

	self:ApplyModalExempt(widget)

	ArrayInsert(self.widgets, true, widget)
	for _, listname in ipairs(callInLists) do
		local func = widget[listname]
		if type(func) == "function" then
			ArrayInsert(self[listname .. "List"], func, widget)
			if insertingStartupWidgets then
				self:UpdateCallIn(listname)
			end
		end
	end
	if not insertingStartupWidgets then
		self:UpdateCallIns()
	end

	self.widgetsRevision = self.widgetsRevision + 1

	if widget.Initialize then
		local wgKeys = memoryGuard and memoryGuard.isUser(widget) and memoryGuard.snapshotWG()
		widget:Initialize()
		if wgKeys then
			memoryGuard.claimWG(widget, wgKeys)
		end
	end
	if memoryGuard then
		memoryGuard.settle(widget)
	end
end

function widgetHandler:RemoveWidgetRaw(widget)
	if widget == nil or widget.whInfo == nil then
		return
	end
	if not platformCheck(widget.whInfo.depends) then
		return
	end

	if self.textOwner == widget then
		self.textOwner = nil
	end

	-- A refused widget can have queued its own removal and would write over a running one.
	if table.getKeyOf(self.widgets, widget) then
		local name = widget.whInfo.name
		if widget.GetConfigData then
			self.configData[name] = widget:GetConfigData()
		end
		self.knownWidgets[name].active = false
		if widget.Shutdown then
			widget:Shutdown()
		end
	end
	ArrayRemove(self.widgets, widget)
	self:ForgetModalWidget(widget)
	self:RemoveWidgetGlobals(widget)
	self.actionHandler:RemoveWidgetActions(widget)
	for _, listname in ipairs(callInLists) do
		ArrayRemove(self[listname .. "List"], widget)
	end
	self:UpdateCallIns()
	self.widgetsRevision = self.widgetsRevision + 1
end

--------------------------------------------------------------------------------

function widgetHandler:UpdateCallIn(name)
	local listName = name .. "List"
	if isHeadless and headlessDisabledCallIns[name] then
		_G[name] = nil
		Script.UpdateCallIn(name)
		return
	end
	if name == "Update" or name == "DrawScreen" then
		return
	end
	if
		#self[listName] > 0
		or not flexCallInMap[name]
		or (name == "GotChatMsg" and actionHandler.HaveChatAction())
		or (name == "RecvFromSynced" and actionHandler.HaveSyncAction())
	then
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
	local listName = name .. "List"
	local ciList = self[listName]
	if ciList then
		local func = w[name]
		if type(func) == "function" then
			ArrayInsert(ciList, func, w)
		else
			ArrayRemove(ciList, w)
		end
		self:UpdateCallIn(name)
	else
		spEcho("UpdateWidgetCallIn: bad name: " .. name)
	end
end

function widgetHandler:RemoveWidgetCallInRaw(name, w)
	local listName = name .. "List"
	local ciList = self[listName]
	if ciList then
		ArrayRemove(ciList, w)
		self:UpdateCallIn(name)
	else
		spEcho("RemoveWidgetCallIn: bad name: " .. name)
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

function widgetHandler:ForgetWidget(name)
	if not self:IsWidgetKnown(name) then
		return
	end
	local ki = self.knownWidgets[name]
	local md5 = ki and table.getKeyOf(self.widgetHashes, ki.filename)
	if md5 ~= nil then
		self.widgetHashes[md5] = nil
	end
	self.knownWidgets[name] = nil
	self.knownCount = self.knownCount - 1
	self.knownChanged = true
end

function widgetHandler:EnableWidgetRaw(name, enableLocalsAccess)
	local ki = self.knownWidgets[name]
	if not ki then
		spEcho("EnableWidget(), could not find widget: " .. tostring(name))
		return false
	end
	ki.replacedBy = nil
	if not ki.active then
		spEcho("Loading:  " .. ki.filename .. (enableLocalsAccess and " (with locals)" or ""))
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
		spEcho("DisableWidget(), could not find widget: " .. tostring(name))
		return false
	end
	if ki.hidden then
		return false -- hidden widgets back other widgets; disabling one breaks them with no way back
	end
	ki.replacedBy = nil
	if ki.active then
		local w = self:FindWidget(name)
		if not w then
			return false
		end
		spEcho("Removed:  " .. ki.filename)
		self:RemoveWidgetRaw(w) -- deactivate
	elseif (self.orderList[name] or 0) <= 0 then
		return true
	end
	self.orderList[name] = 0 -- disable
	self:SaveConfigData()
	return true
end

function widgetHandler:ToggleWidgetRaw(name)
	local ki = self.knownWidgets[name]
	if not ki then
		spEcho("ToggleWidget(), could not find widget: " .. tostring(name))
		return
	end
	if ki.active or self.orderList[name] > 0 then
		return self:DisableWidgetRaw(name)
	end
	return self:EnableWidgetRaw(name)
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
			tableRemove(t, i)
			tableInsert(t, n, w)
		end
	end
	Raise(self.widgets, true, widget)
	for _, listname in ipairs(callInLists) do
		Raise(self[listname .. "List"], widget[listname], widget)
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
			tableInsert(t, n + 1, w)
			tableRemove(t, i)
		end
	end
	Lower(self.widgets, true, widget)
	for _, listname in ipairs(callInLists) do
		Lower(self[listname .. "List"], widget[listname], widget)
	end
end

function widgetHandler:FindWidget(name)
	if type(name) ~= "string" then
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
	if name == nil or self.globals[name] ~= owner then
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
	ConfigLayoutHandler(data, self)
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

	-- save config. SaveConfigData knows about the two reset flags, so a widget's own
	-- Shutdown calling it below cannot put back what a reset just took out.
	self:SaveConfigData()
	self:SavePause()

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

--------------------------------------------------------------------------------
--
--  Modal windows
--
--  Optional behaviour (springsetting "WindowsHideInterface", default off): while one
--  of the big central windows is open, the rest of the screen interface is neither
--  drawn nor clickable, so the window is the only thing the player can interact with.
--
--  In singleplayer and replays an open window (or the lobby overlay) also pauses the
--  game (springsetting "WindowsPauseGame", default on) until the last one closes. A
--  pause the player made or lifted themselves in the meantime is left alone.
--
--  Widgets pause the game under a source, as gadgets do (api_game_pause.lua), and the
--  game resumes once the last source on either side unpauses:
--      widgetHandler:Pause("modals")
--      widgetHandler:Unpause("modals")
--  Unpause also takes a gadget's source, when that gadget publishes it to widgets.
--
--  A window widget opts in from its Initialize with an is-open predicate:
--      widgetHandler:RegisterModalWindow(function() return show end)
--  (widgets with handler = true get the real handler, so they pass themselves first:
--   widgetHandler:RegisterModalWindow(widget, function() return show end))
--
--  A widget that must stay visible and usable regardless declares it in GetInfo:
--      modalExempt = true,
--
--  Filtered while a window is open: DrawScreen, KeyPress, TextInput, MousePress,
--  MouseWheel, IsAbove and GetTooltip, and a MousePress nothing claimed is swallowed
--  so clicks never reach the engine (no unit orders under an open window).
--  Deliberately not filtered: KeyRelease/MouseRelease (a hidden widget must still see
--  the release of a press it got before the window opened), Update, the world and
--  effects draw passes, and the action handler, so keybinds keep working.
--
--  Registered windows stay in the allowed set while closed, so a window that closes
--  while another is open can still run its own cleanup frame.
--
--  The same hiding can also be asked for outright, with no window involved and
--  regardless of the springsetting, for a cutscene or a tool:
--      widgetHandler:HideInterface("cutscene")             -- keeps the menu buttons
--      widgetHandler:HideInterface("cutscene", {"Chat"})   -- keeps only chat
--      widgetHandler:HideInterface("cutscene", {})         -- keeps nothing
--      widgetHandler:ShowInterface("cutscene")
--  Requests are named so two callers cannot switch each other off, and the
--  interface returns once the last one is released.
--
local modalWindows = {} -- widget -> is-open predicate
local modalExempt = {} -- widget -> true
local modalAllowed = {} -- widget -> true (exempt widgets and registered windows)
local modalActive = false
local modalRevision = 0
local modalEnabled = false
local modalConfigTimer = 0
local MODAL_CONFIG_INTERVAL = 1 -- seconds between config re-reads (picks up /set)

-- pausing under a source, see widgetHandler:Pause
local PAUSESOURCE_MODALS = "modals"
local RULESPARAM_GADGET_PAUSE = "gamePaused"
local RULESPARAM_GADGET_PAUSE_GENERATION = "gamePauseGeneration"
local RULESPARAM_GADGET_PAUSE_PUBLISH = "gamePausePublished"
local MESSAGE_GADGET_UNPAUSE = "GamePauseUnpause:"
local MESSAGE_WIDGETS_UNPAUSED = "GamePauseWidgetsUnpaused:"
local pauseSources = {}
local widgetPaused = false
-- pausing while a modal window is open, see UpdatePause
local modalPauseEnabled = true
local modalPauseAllowed = false -- only in singleplayer and replays

-- The same hiding, asked for outright rather than driven by an open window: for a
-- cutscene, a screenshot mode, an editor. Requests are named so two callers cannot
-- switch each other off, and each names the widgets it wants kept. Unlike the window
-- case this ignores the springsetting: a caller that asks for it means it.
local interfaceHiddenReasons = {} -- reason -> set of widget names to keep
local interfaceHidden = false
local interfaceAllowedNames = {} -- union of the names every active reason keeps
-- what a caller gets when it names nothing: the menu buttons, so there is always a
-- way back out. Pass an explicit (possibly empty) list to keep something else.
local DEFAULT_INTERFACE_ALLOW = { "Top Bar Buttons" }

-- The single question every filtered call-in asks. Kept cheap: two upvalue reads
-- when nothing is hiding anything.
local function allowedWidget(widget)
	if interfaceHidden then
		local info = widget.whInfo
		if interfaceAllowedNames[info.name] then
			return true
		end
		-- a widget taking another's place (GetInfo replaces) is kept where that one would be
		local replaces = info.replaces
		if type(replaces) == "table" then
			for i = 1, #replaces do
				if interfaceAllowedNames[replaces[i]] then
					return true
				end
			end
			return false
		end
		return replaces ~= nil and interfaceAllowedNames[replaces] == true
	end
	return (not modalActive) or (modalAllowed[widget] == true)
end

local function ModalAllowWidget(widget, allowed)
	if (modalAllowed[widget] or false) ~= allowed then
		modalAllowed[widget] = allowed or nil
		modalRevision = modalRevision + 1
	end
end

function widgetHandler:RegisterModalWindow(widget, isOpen)
	if type(isOpen) ~= "function" then
		spLog("barwidgets.lua", LOG.ERROR, "RegisterModalWindow: expected an is-open function")
		return false
	end
	modalWindows[widget] = isOpen
	ModalAllowWidget(widget, true)
	return true
end

function widgetHandler:DeregisterModalWindow(widget)
	modalWindows[widget] = nil
	ModalAllowWidget(widget, modalExempt[widget] == true)
end

-- Called from InsertWidgetRaw/RemoveWidgetRaw, which are defined above this block and
-- so reach the state through the handler rather than as upvalues.
function widgetHandler:ApplyModalExempt(widget)
	if widget.whInfo and widget.whInfo.modalExempt then
		modalExempt[widget] = true
		ModalAllowWidget(widget, true)
	end
end

function widgetHandler:ForgetModalWidget(widget)
	modalWindows[widget] = nil
	modalExempt[widget] = nil
	ModalAllowWidget(widget, false)
end

function widgetHandler:IsModalActive()
	return modalActive
end

local function rebuildInterfaceAllowed()
	local hidden = false
	local names = {}
	for _, allow in pairs(interfaceHiddenReasons) do
		hidden = true
		for name in pairs(allow) do
			names[name] = true
		end
	end
	interfaceAllowedNames = names
	interfaceHidden = hidden
	-- cached visibility elsewhere (the guishader stencil) has to be rebuilt
	modalRevision = modalRevision + 1
end

---Hide every widget except the ones named, until the same reason is released.
---@param reason string caller-chosen key; pass the same one to ShowInterface
---@param keep string[]? widget names to keep drawing and clickable.
---Defaults to the menu buttons; pass {} to keep nothing at all.
function widgetHandler:HideInterface(reason, keep)
	if type(reason) ~= "string" then
		spLog("barwidgets.lua", LOG.ERROR, "HideInterface: expected a reason name")
		return false
	end
	local names = {}
	for _, name in ipairs(keep or DEFAULT_INTERFACE_ALLOW) do
		names[name] = true
	end
	interfaceHiddenReasons[reason] = names
	rebuildInterfaceAllowed()
	return true
end

---Release one reason. The interface comes back once no reason is left.
---@param reason string
function widgetHandler:ShowInterface(reason)
	if interfaceHiddenReasons[reason] == nil then
		return false
	end
	interfaceHiddenReasons[reason] = nil
	rebuildInterfaceAllowed()
	return true
end

function widgetHandler:IsInterfaceHidden()
	return interfaceHidden
end

-- Bumped whenever the allowed set changes, so cached state elsewhere (the guishader's
-- stencil) can tell it needs rebuilding.
function widgetHandler:GetModalRevision()
	return modalRevision
end

-- Bumped whenever a widget goes in or comes out, so state derived from the running set can tell
-- it moved.
function widgetHandler:GetWidgetsRevision()
	return self.widgetsRevision
end

function widgetHandler:GetActiveWidgetFiles()
	local files = {}
	for i, w in ipairs(self.widgets) do
		files[i] = w.whInfo.filename
	end

	return files
end

-- Whether a widget is drawing and taking input right now, whether it is a window
-- or an outright hide that is covering it. A nil widget (e.g. an unowned guishader
-- region) counts as not allowed, which is the wanted default.
function widgetHandler:ModalAllows(widget)
	if widget == nil then
		return (not modalActive) and (not interfaceHidden)
	end
	return allowedWidget(widget)
end

function widgetHandler:SetWindowsHideInterface(enabled)
	modalEnabled = enabled and true or false
	modalConfigTimer = 0
	self:UpdateModalState()
end

function widgetHandler:SetWindowsPauseGame(enabled)
	modalPauseEnabled = enabled and true or false
	modalConfigTimer = 0
end

local function anyWindowOpen()
	for w, isOpen in pairs(modalWindows) do
		local ok, open = pcall(isOpen)
		if not ok then
			spLog(
				"barwidgets.lua",
				LOG.ERROR,
				"modal window check failed for " .. tostring(w.whInfo and w.whInfo.name) .. ": " .. tostring(open)
			)
			modalWindows[w] = nil -- removing the current key mid-traversal is allowed
			ModalAllowWidget(w, modalExempt[w] == true)
		elseif open then
			return true
		end
	end
	return false
end

function widgetHandler:UpdateModalState(deltaTime)
	if deltaTime then
		modalConfigTimer = modalConfigTimer + deltaTime
		if modalConfigTimer >= MODAL_CONFIG_INTERVAL then
			modalConfigTimer = 0
			modalEnabled = (Spring.GetConfigInt("WindowsHideInterface", 0) == 1)
			modalPauseEnabled = (Spring.GetConfigInt("WindowsPauseGame", 1) == 1)
		end
	end

	modalActive = modalEnabled and anyWindowOpen()
end

local function isClientPaused()
	local _, _, paused = Spring.GetGameState()
	return paused
end

local function inGadgetPause()
	return (Spring.GetGameRulesParam(RULESPARAM_GADGET_PAUSE) or 0) == 1
end

local function getPauseReleaseKey(source)
	local publishedRule = Spring.GetGameRulesParam(RULESPARAM_GADGET_PAUSE_PUBLISH) or "[]"
	if publishedRule == "[]" then
		return nil
	end
	local published = Json.decode(publishedRule)
	if type(published) ~= "table" then
		return nil
	end
	for _, entry in ipairs(published) do
		if type(entry) == "table" and entry[1] == source then
			return entry[2]
		end
	end
end

---Pause and resume the game using basic claims and releases on claims.
---@param source string key set by caller; pass the same key to Unpause
function widgetHandler:Pause(source)
	if type(source) ~= "string" then
		Spring.Log("barwidgets.lua", LOG.ERROR, "Pause: expected a source name")
		return false
	end
	if Spring.GetGameFrame() == 0 then
		return false -- cannot pause until the game starts
	end
	if next(pauseSources) == nil and not widgetPaused then
		widgetPaused = not isClientPaused()
		if widgetPaused then
			Spring.SendCommands("pause 1")
		end
	end
	pauseSources[source] = true
	return true
end

---Unpause one source. The game resumes once no source on either side is left.
---@param source string # a widget's source, or a gadget's published source
function widgetHandler:Unpause(source)
	if pauseSources[source] then
		pauseSources[source] = nil
		if next(pauseSources) == nil then
			if widgetPaused and isClientPaused() then
				if inGadgetPause() then
					local generation = Spring.GetGameRulesParam(RULESPARAM_GADGET_PAUSE_GENERATION) or 0
					Spring.SendLuaRulesMsg(MESSAGE_WIDGETS_UNPAUSED .. generation) -- the gadgets resume the game
				else
					Spring.SendCommands("pause 0")
				end
			end
			widgetPaused = false
		end
		return true
	end
	local release = getPauseReleaseKey(source)
	if release then
		Spring.SendLuaRulesMsg(MESSAGE_GADGET_UNPAUSE .. release .. ":" .. source)
		return true
	end
	return false
end

local function gameUnpausing()
	if next(pauseSources) == nil then
		return false
	end
	widgetPaused = true
	return true
end

-- This runs after the widgets update, so the game stays paused when:
-- one modal closes -and- another opens, or a modal reopens after a reload.
function widgetHandler:UpdatePause()
	if widgetPaused and not isClientPaused() then
		widgetPaused = false -- the player unpaused during another pause, so the pause remains
	end
	local wanted = modalPauseAllowed and modalPauseEnabled and (self.chobbyInterface or anyWindowOpen())
	if wanted ~= (pauseSources[PAUSESOURCE_MODALS] == true) then
		if wanted then
			self:Pause(PAUSESOURCE_MODALS)
		else
			self:Unpause(PAUSESOURCE_MODALS)
		end
	end
end

-- A LuaUI reload hands the pause over in memory, tied to the frame it froze, so widgets
-- that pause again after the reload, like a modal reopening, still resume the game.
function widgetHandler:SavePause()
	Spring.SetConfigInt("WidgetsPausedAtFrame", widgetPaused and Spring.GetGameFrame() or 0, true)
end

function widgetHandler:InitPause()
	-- headless, nobody would ever close a modal that opened by itself
	modalPauseAllowed = not isHeadless and (spIsReplay() or isSinglePlayer())
	modalPauseEnabled = (Spring.GetConfigInt("WindowsPauseGame", 1) == 1)
	local frame = Spring.GetGameFrame()
	widgetPaused = frame > 0 and Spring.GetConfigInt("WidgetsPausedAtFrame", 0) == frame and isClientPaused()
	Spring.SetConfigInt("WidgetsPausedAtFrame", 0, true)
	self:RegisterGlobal(self, "GameUnpausing", gameUnpausing)
end

function widgetHandler:Update()
	-- Collects LuaUI's garbage when the shared Lua memory pool runs high, and watches user widgets.
	if memoryGuard then
		memoryGuard.update()
	end

	local deltaTime = Spring.GetLastUpdateSeconds()
	-- update the hour timer
	hourTimer = (hourTimer + deltaTime) % 3600.0

	-- before the widgets run, so a widget asking IsModalActive this frame sees the
	-- window that was opened by the input events just handled
	self:UpdateModalState(deltaTime)

	tracyZoneBeginN("W:Update")
	for _, w in ipairs(self.UpdateList) do
		tracyZoneBeginN(w._tracyUpdateName)
		w:Update(deltaTime)
		tracyZoneEnd()
	end
	tracyZoneEnd()

	self:UpdatePause()
	return
end

-- The widget selector is how widgets get switched back on from inside the game, so asking for it has to
-- work when it is not running. An error in it removes the widget, and with it the /widgetselector action
-- it registers - and so F11 - which left a LuaUI reload as the only way back. Switches it on again, and
-- it opens itself once loaded, through the flag it reopens with after a reload it asked for. While it
-- runs this does nothing, its own action answering instead; returns whether it did anything.
function widgetHandler:RecoverWidgetSelector()
	for name, ki in pairs(self.knownWidgets) do
		if ki.basename == "widget_selector.lua" then
			if ki.active then
				return false
			end
			if type(self.configData[name]) ~= "table" then
				self.configData[name] = {}
			end
			self.configData[name].reopen = true
			self:EnableWidget(name)
			return true
		end
	end
	return false
end

function widgetHandler:ConfigureLayout(command)
	if command == "reconf" then
		self:SendConfigData()
		return true
	elseif command == "selector" then
		-- F11's binding in every shipped preset. It once looked for LuaUI/selector.lua, which this game does
		-- not ship: its selector is Widgets/widget_selector.lua, reached through what it puts in WG, or
		-- switched back on here when an error took it down.
		if not self:RecoverWidgetSelector() and self.WG.widgetselector then
			self.WG.widgetselector.toggle()
		end
		return true
	elseif stringFind(command, "togglewidget") == 1 then
		self:ToggleWidgetRaw(stringSub(command, 14))
		return true
	elseif stringFind(command, "enablewidget") == 1 then
		self:EnableWidgetRaw(stringSub(command, 14))
		return true
	elseif stringFind(command, "disablewidget") == 1 then
		self:DisableWidgetRaw(stringSub(command, 15))
		return true
	elseif command == "widgetmemory" and memoryGuard then
		memoryGuard.report()
		return true
	end

	-- Answered by the widget selector's own action while it runs.
	if command == "widgetselector" and self:RecoverWidgetSelector() then
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
	tracyZoneBeginN("W:ActiveCommandChanged")
	for _, w in ipairs(self.ActiveCommandChangedList) do
		w:ActiveCommandChanged(id, cmdType)
	end
	tracyZoneEnd()
end

function widgetHandler:CameraRotationChanged(rotx, roty, rotz)
	tracyZoneBeginN("W:CameraRotationChanged")
	for _, w in ipairs(self.CameraRotationChangedList) do
		w:CameraRotationChanged(rotx, roty, rotz)
	end
	tracyZoneEnd()
end

function widgetHandler:CameraPositionChanged(posx, posy, posz)
	tracyZoneBeginN("W:CameraPositionChanged")
	for _, w in ipairs(self.CameraPositionChangedList) do
		w:CameraPositionChanged(posx, posy, posz)
	end
	tracyZoneEnd()
end

function widgetHandler:CommandNotify(id, params, options)
	tracyZoneBeginN("W:CommandNotify")
	for _, w in ipairs(self.CommandNotifyList) do
		tracyZoneBeginN(w._tracyCommandNotifyName)
		local consumed = w:CommandNotify(id, params, options)
		tracyZoneEnd()
		if consumed then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

-- Engine AllowQuit callin (Engine.FeatureSupport.allowQuitCallin): a window
-- close request (the close button, Alt+F4) asks before the game quits. Every
-- widget that answers must allow; a widget that returns false keeps the game
-- open and is expected to quit it later itself (Spring.Quit never asks).
-- Engines without the callin never call this.
function widgetHandler:AllowQuit()
	for _, w in ipairs(self.AllowQuitList) do
		if w:AllowQuit() == false then
			return false
		end
	end
	return true
end

function widgetHandler:AddConsoleLine(msg, priority)
	tracyZoneBeginN("W:AddConsoleLine")
	for _, w in ipairs(self.AddConsoleLineList) do
		w:AddConsoleLine(msg, priority)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GroupChanged(groupID)
	tracyZoneBeginN("W:GroupChanged")
	for _, w in ipairs(self.GroupChangedList) do
		w:GroupChanged(groupID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:CommandsChanged()
	tracyZoneBeginN("W:CommandsChanged")
	if widgetHandler:UpdateSelection() then
		-- for selectionchanged
		tracyZoneEnd()
		return -- selection updated, don't call commands changed.
	end
	self.inCommandsChanged = true
	self.customCommands = {}
	for _, w in ipairs(self.CommandsChangedList) do
		w:CommandsChanged()
		local customCommands = userCustomCommands[w]
		if customCommands then
			moveUserCustomCommands(customCommands, self.customCommands)
		end
	end
	self.inCommandsChanged = false
	tracyZoneEnd()
	return
end

--------------------------------------------------------------------------------
--
--  Drawing call-ins
--

-- generates ViewResize() calls for the widgets
function widgetHandler:SetViewSize(vsx, vsy)
	tracyZoneBeginN("W:SetViewSize")
	self.xViewSize = vsx
	self.yViewSize = vsy
	if self.xViewSizeOld ~= vsx or self.yViewSizeOld ~= vsy then
		widgetHandler:ViewResize(vsx, vsy)
		self.xViewSizeOld = vsx
		self.yViewSizeOld = vsy
	end
	tracyZoneEnd()
	return
end

function widgetHandler:ViewResize(vsx, vsy)
	if type(vsx) == "table" then
		vsy = vsx.viewSizeY
		vsx = vsx.viewSizeX
		print("real ViewResize") -- FIXME
	end

	tracyZoneBeginN("W:ViewResize")
	if widgetHandler.WG.FlowUI then
		tracyZoneBeginN("W:ViewResize:FlowUI")
		widgetHandler.WG.FlowUI.Callin.ViewResize1(vsx, vsy)
		tracyZoneEnd()
	end
	for _, w in ipairs(self.ViewResizeList) do
		tracyZoneBeginN(w._tracyViewResizeName)
		w:ViewResize(vsx, vsy)
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawScreen()
	tracyZoneBeginN("W:DrawScreen")
	-- catches a window opened from another widget's Update, which ran after the
	-- recompute at the top of widgetHandler:Update
	self:UpdateModalState()
	if not Spring.IsGUIHidden() then
		if not self.chobbyInterface then
			local list = self.DrawScreenList
			for i = #list, 1, -1 do
				local w = list[i]
				if not (modalActive or interfaceHidden) or allowedWidget(w) then
					tracyZoneBeginN(w._tracyDrawScreenName)
					w:DrawScreen()
					tracyZoneEnd()
				end
			end
		elseif widgetHandler.WG.guishader and widgetHandler.WG.guishader.DrawScreen then
			tracyZoneBeginN("W:DrawScreen:guishader")
			widgetHandler.WG.guishader.DrawScreen()
			tracyZoneEnd()
		end
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawGenesis()
	tracyZoneBeginN("W:DrawGenesis")
	local list = self.DrawGenesisList
	for i = #list, 1, -1 do
		local w = list[i]
		tracyZoneBeginN(w._tracyDrawGenesisName)
		w:DrawGenesis()
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawGroundPreForward()
	tracyZoneBeginN("W:DrawGroundPreForward")
	local list = self.DrawGroundPreForwardList
	for i = #list, 1, -1 do
		list[i]:DrawGroundPreForward()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawGroundPostForward()
	tracyZoneBeginN("W:DrawGroundPostForward")
	local list = self.DrawGroundPostForwardList
	for i = #list, 1, -1 do
		list[i]:DrawGroundPostForward()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawGroundPreDeferred()
	tracyZoneBeginN("W:DrawGroundPreDeferred")
	local list = self.DrawGroundPreDeferredList
	for i = #list, 1, -1 do
		list[i]:DrawGroundPreDeferred()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawGroundPostDeferred()
	tracyZoneBeginN("W:DrawGroundPostDeferred")
	local list = self.DrawGroundPostDeferredList
	for i = #list, 1, -1 do
		list[i]:DrawGroundPostDeferred()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawGroundDeferred()
	tracyZoneBeginN("W:DrawGroundDeferred")
	local list = self.DrawGroundDeferredList
	for i = #list, 1, -1 do
		list[i]:DrawGroundDeferred()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawWorld()
	tracyZoneBeginN("W:DrawWorld")
	if not self.chobbyInterface then
		local list = self.DrawWorldList
		for i = #list, 1, -1 do
			local w = list[i]
			tracyZoneBeginN(w._tracyDrawWorldName)
			w:DrawWorld()
			tracyZoneEnd()
		end
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawWorldPreUnit()
	tracyZoneBeginN("W:DrawWorldPreUnit")
	if not self.chobbyInterface then
		local list = self.DrawWorldPreUnitList
		for i = #list, 1, -1 do
			local w = list[i]
			tracyZoneBeginN(w._tracyDrawWorldPreUnitName)
			w:DrawWorldPreUnit()
			tracyZoneEnd()
		end
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawOpaqueUnitsLua(deferredPass, drawReflection, drawRefraction)
	tracyZoneBeginN("W:DrawOpaqueUnitsLua")
	local list = self.DrawOpaqueUnitsLuaList
	for i = #list, 1, -1 do
		list[i]:DrawOpaqueUnitsLua(deferredPass, drawReflection, drawRefraction)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawOpaqueFeaturesLua(deferredPass, drawReflection, drawRefraction)
	tracyZoneBeginN("W:DrawOpaqueFeaturesLua")
	local list = self.DrawOpaqueFeaturesLuaList
	for i = #list, 1, -1 do
		list[i]:DrawOpaqueFeaturesLua(deferredPass, drawReflection, drawRefraction)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	tracyZoneBeginN("W:DrawAlphaUnitsLua")
	local list = self.DrawAlphaUnitsLuaList
	for i = #list, 1, -1 do
		list[i]:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	tracyZoneBeginN("W:DrawAlphaFeaturesLua")
	local list = self.DrawAlphaFeaturesLuaList
	for i = #list, 1, -1 do
		list[i]:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawShadowUnitsLua()
	tracyZoneBeginN("W:DrawShadowUnitsLua")
	local list = self.DrawShadowUnitsLuaList
	for i = #list, 1, -1 do
		list[i]:DrawShadowUnitsLua()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawShadowFeaturesLua()
	tracyZoneBeginN("W:DrawShadowFeaturesLua")
	local list = self.DrawShadowFeaturesLuaList
	for i = #list, 1, -1 do
		list[i]:DrawShadowFeaturesLua()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawPreDecals()
	tracyZoneBeginN("W:DrawPreDecals")
	local list = self.DrawPreDecalsList
	for i = #list, 1, -1 do
		list[i]:DrawPreDecals()
	end
	tracyZoneEnd()
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
	tracyZoneBeginN("W:DrawWorldPreParticles")
	local list = self.DrawWorldPreParticlesList
	for i = #list, 1, -1 do
		list[i]:DrawWorldPreParticles(drawAboveWater, drawBelowWater, drawReflection, drawRefraction)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawWorldShadow()
	tracyZoneBeginN("W:DrawWorldShadow")
	local list = self.DrawWorldShadowList
	for i = #list, 1, -1 do
		list[i]:DrawWorldShadow()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawWorldReflection()
	tracyZoneBeginN("W:DrawWorldReflection")
	local list = self.DrawWorldReflectionList
	for i = #list, 1, -1 do
		list[i]:DrawWorldReflection()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawWorldRefraction()
	tracyZoneBeginN("W:DrawWorldRefraction")
	local list = self.DrawWorldRefractionList
	for i = #list, 1, -1 do
		list[i]:DrawWorldRefraction()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawUnitsPostDeferred()
	tracyZoneBeginN("W:DrawUnitsPostDeferred")
	local list = self.DrawUnitsPostDeferredList
	for i = #list, 1, -1 do
		list[i]:DrawUnitsPostDeferred()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawFeaturesPostDeferred()
	tracyZoneBeginN("W:DrawFeaturesPostDeferred")
	local list = self.DrawFeaturesPostDeferredList
	for i = #list, 1, -1 do
		list[i]:DrawFeaturesPostDeferred()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawScreenEffects(vsx, vsy)
	tracyZoneBeginN("W:DrawScreenEffects")
	local list = self.DrawScreenEffectsList
	for i = #list, 1, -1 do
		local w = list[i]
		tracyZoneBeginN(w._tracyDrawScreenEffectsName)
		w:DrawScreenEffects(vsx, vsy)
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawScreenPost()
	tracyZoneBeginN("W:DrawScreenPost")
	local list = self.DrawScreenPostList
	for i = #list, 1, -1 do
		local w = list[i]
		tracyZoneBeginN(w._tracyDrawScreenPostName)
		w:DrawScreenPost()
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawInMiniMap(xSize, ySize)
	tracyZoneBeginN("W:DrawInMiniMap")
	-- When PIP minimap replacement is active, skip normal DrawInMiniMap calls
	-- The PIP widget will call these functions itself with proper coordinate transformations
	-- during its render-to-texture pass in RenderPipContents()
	if
		widgetHandler.minimap
		and widgetHandler.minimap.isPipMinimapActive
		and widgetHandler.minimap.isPipMinimapActive()
	then
		tracyZoneEnd()
		return
	end
	local list = self.DrawInMiniMapList
	for i = #list, 1, -1 do
		list[i]:DrawInMiniMap(xSize, ySize)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:DrawBuildSquare(unitDefID, x, z, facing, statuses)
	tracyZoneBeginN("W:DrawBuildSquare")
	local list = self.DrawBuildSquareList
	for i = #list, 1, -1 do
		list[i]:DrawBuildSquare(unitDefID, x, z, facing, statuses)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:SunChanged()
	tracyZoneBeginN("W:SunChanged")
	local nmp = _G.NightModeParams
	local list = self.SunChangedList
	for i = #list, 1, -1 do
		list[i]:SunChanged(nmp)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:FontsChanged()
	tracyZoneBeginN("FontsChanged")
	local list = self.FontsChangedList
	for i = #list, 1, -1 do
		list[i]:FontsChanged()
	end
	tracyZoneEnd()
	return
end

--------------------------------------------------------------------------------
--
--  Keyboard call-ins
--

function widgetHandler:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
	tracyZoneBeginN("W:KeyPress")
	local textOwner = self.textOwner

	if textOwner then
		if (not textOwner.KeyPress) or textOwner:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions) then
			tracyZoneEnd()
			return true
		end
	end

	if self.actionHandler:KeyAction(true, key, mods, isRepeat, scanCode, actions) then
		tracyZoneEnd()
		return true
	end

	-- A key bound to /widgetselector - F11 - with no selector running to answer it.
	if actions and not isRepeat then
		for _, bound in ipairs(actions) do
			if bound.command == "widgetselector" and self:RecoverWidgetSelector() then
				tracyZoneEnd()
				return true
			end
		end
	end

	for _, w in ipairs(self.KeyPressList) do
		if allowedWidget(w) then
			if w:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions) then
				tracyZoneEnd()
				return true
			end
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:KeyRelease(key, mods, label, unicode, scanCode, actions)
	tracyZoneBeginN("W:KeyRelease")
	local textOwner = self.textOwner

	if textOwner then
		if (not textOwner.KeyRelease) or textOwner:KeyRelease(key, mods, label, unicode, scanCode, actions) then
			-- the action handler (actions.lua) never sees this release, so let's forget the key itself
			self.actionHandler:ClearPressedKey(scanCode)
			tracyZoneEnd()
			return true
		end
	end

	if self.actionHandler:KeyAction(false, key, mods, false, scanCode, actions) then
		tracyZoneEnd()
		return true
	end

	for _, w in ipairs(self.KeyReleaseList) do
		if w:KeyRelease(key, mods, label, unicode, scanCode, actions) then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:TextInput(utf8, ...)
	tracyZoneBeginN("W:TextInput")
	local textOwner = self.textOwner

	if textOwner then
		if textOwner.TextInput then
			textOwner:TextInput(utf8, ...)
		end

		tracyZoneEnd()
		return true
	end

	local list = self.TextInputList
	for i = #list, 1, -1 do
		if allowedWidget(list[i]) then
			if list[i]:TextInput(utf8, ...) then
				tracyZoneEnd()
				return true
			end
		end
	end
	tracyZoneEnd()
	return false
end

--------------------------------------------------------------------------------
--
--  Mouse call-ins
--

-- local helper (not a real call-in)
function widgetHandler:WidgetAt(x, y)
	tracyZoneBeginN("W:WidgetAt")
	for _, w in ipairs(self.IsAboveList) do
		if (not (modalActive or interfaceHidden) or allowedWidget(w)) and w:IsAbove(x, y) then
			tracyZoneEnd()
			return w
		end
	end
	tracyZoneEnd()
	return nil
end

function widgetHandler:MousePress(x, y, button)
	tracyZoneBeginN("W:MousePress")
	if self.mouseOwner then
		-- unfiltered: a drag that started before the window opened has to finish
		self.mouseOwner:MousePress(x, y, button)
	else
		for _, w in ipairs(self.MousePressList) do
			if allowedWidget(w) then
				if w:MousePress(x, y, button) then
					self.mouseOwner = w
					break
				end
			end
		end
	end

	-- While a window is open the click is consumed even when nothing claimed it, so it
	-- never reaches the engine and orders no units. No mouseOwner is taken for that:
	-- there is nothing to route the follow-up move/release to.
	local consumed = (self.mouseOwner ~= nil) or modalActive or interfaceHidden
	if widgetHandler.WG.SmartSelect_MousePress2 then
		widgetHandler.WG.SmartSelect_MousePress2(x, y, button, consumed)
	end

	tracyZoneEnd()
	return consumed
end

function widgetHandler:MouseMove(x, y, dx, dy, button)
	tracyZoneBeginN("W:MouseMove")
	local mo = self.mouseOwner
	if mo and mo.MouseMove then
		tracyZoneEnd()
		return mo:MouseMove(x, y, dx, dy, button)
	end
	tracyZoneEnd()
end

function widgetHandler:MouseRelease(x, y, button)
	tracyZoneBeginN("W:MouseRelease")
	local mo = self.mouseOwner
	local _, _, lmb, mmb, rmb = Spring.GetMouseState()
	if not (lmb or mmb or rmb) then
		self.mouseOwner = nil
	end

	if mo and mo.MouseRelease then
		tracyZoneEnd()
		return mo:MouseRelease(x, y, button)
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:MouseWheel(up, value)
	if value == 0 then
		return false -- fix for touchpads: after any scroll it somehow adds an up=false, value=0
	end
	tracyZoneBeginN("W:MouseWheel")
	for _, w in ipairs(self.MouseWheelList) do
		if allowedWidget(w) and w:MouseWheel(up, value) then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:ControllerAdded(deviceIndex)
	tracyZoneBeginN("W:ControllerAdded")
	for _, w in ipairs(self.ControllerAddedList) do
		if w:ControllerAdded(deviceIndex) then
			tracyZoneEnd()
			return true
		end
	end

	tracyZoneEnd()
	return false
end

function widgetHandler:ControllerRemoved(instanceId)
	tracyZoneBeginN("W:ControllerRemoved")
	for _, w in ipairs(self.ControllerRemovedList) do
		if w:ControllerRemoved(instanceId) then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:ControllerConnected(instanceId)
	tracyZoneBeginN("W:ControllerConnected")
	for _, w in ipairs(self.ControllerConnectedList) do
		if w:ControllerConnected(instanceId) then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:ControllerDisconnected(instanceId)
	tracyZoneBeginN("W:ControllerDisconnected")
	for _, w in ipairs(self.ControllerDisconnectedList) do
		if w:ControllerDisconnected(instanceId) then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:ControllerRemapped(instanceId)
	tracyZoneBeginN("W:ControllerRemapped")
	for _, w in ipairs(self.ControllerRemappedList) do
		if w:ControllerRemapped(instanceId) then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:ControllerButtonUp(instanceId, button, state, name)
	tracyZoneBeginN("W:ControllerButtonUp")
	for _, w in ipairs(self.ControllerButtonUpList) do
		if w:ControllerButtonUp(instanceId, button, state, name) then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:ControllerButtonDown(instanceId, button, state, name)
	tracyZoneBeginN("W:ControllerButtonDown")
	for _, w in ipairs(self.ControllerButtonDownList) do
		if w:ControllerButtonDown(instanceId, button, state, name) then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:ControllerAxisMotion(instanceId, axis, value, name)
	tracyZoneBeginN("W:ControllerAxisMotion")
	for _, w in ipairs(self.ControllerAxisMotionList) do
		if w:ControllerAxisMotion(instanceId, axis, value, name) then
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:IsAbove(x, y)
	return (widgetHandler:WidgetAt(x, y) ~= nil)
end

function widgetHandler:GetTooltip(x, y)
	tracyZoneBeginN("W:GetTooltip")
	for _, w in ipairs(self.GetTooltipList) do
		if (not (modalActive or interfaceHidden) or allowedWidget(w)) and w:IsAbove(x, y) then
			local tip = w:GetTooltip(x, y)
			if type(tip) == "string" and #tip > 0 then
				tracyZoneEnd()
				return tip
			end
		end
	end
	tracyZoneEnd()
	return ""
end

--------------------------------------------------------------------------------
--
--  Game call-ins
--

function widgetHandler:GamePreload()
	tracyZoneBeginN("W:GamePreload")
	for _, w in ipairs(self.GamePreloadList) do
		w:GamePreload()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GameStart()
	tracyZoneBeginN("W:GameStart")
	for _, w in ipairs(self.GameStartList) do
		tracyZoneBeginN(w._tracyGameStartName)
		w:GameStart()
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GameOver(winningAllyTeams)
	tracyZoneBeginN("W:GameOver")
	for _, w in ipairs(self.GameOverList) do
		w:GameOver(winningAllyTeams)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GamePaused(playerID, paused)
	tracyZoneBeginN("W:GamePaused")
	for _, w in ipairs(self.GamePausedList) do
		w:GamePaused(playerID, paused)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:TeamDied(teamID)
	tracyZoneBeginN("W:TeamDied")
	for _, w in ipairs(self.TeamDiedList) do
		w:TeamDied(teamID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:TeamChanged(teamID)
	tracyZoneBeginN("W:TeamChanged")
	for _, w in ipairs(self.TeamChangedList) do
		w:TeamChanged(teamID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:PlayerAdded(playerID)
	tracyZoneBeginN("W:PlayerAdded")
	for _, w in ipairs(self.PlayerAddedList) do
		w:PlayerAdded(playerID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:PlayerRemoved(playerID, reason)
	tracyZoneBeginN("W:PlayerRemoved")
	for _, w in ipairs(self.PlayerRemovedList) do
		w:PlayerRemoved(playerID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:PlayerChanged(playerID)
	if anonymousMode ~= "disabled" and not spGetSpectatingState() then
		Spring.SendCommands("info 0")
	end
	tracyZoneBeginN("W:PlayerChanged")
	for _, w in ipairs(self.PlayerChangedList) do
		tracyZoneBeginN(w._tracyPlayerChangedName)
		w:PlayerChanged(playerID)
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GameFrame(frameNum)
	tracyZoneBeginN("W:GameFrame")
	for _, w in ipairs(self.GameFrameList) do
		tracyZoneBeginN(w._tracyGameFrameName)
		w:GameFrame(frameNum)
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GameFramePost(frameNum)
	tracyZoneBeginN("W:GameFramePost")
	for _, w in ipairs(self.GameFramePostList) do
		tracyZoneBeginN(w._tracyGameFramePostName)
		w:GameFramePost(frameNum)
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

-- local helper (not a real call-in)
local oldSelection = {}
function widgetHandler:UpdateSelection()
	tracyZoneBeginN("W:UpdateSelection")
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
			tracyZoneEnd()
			return true
		end
	end
	oldSelection = newSelection

	tracyZoneEnd()
	return false
end

function widgetHandler:SelectionChanged(selectedUnits, subselection)
	tracyZoneBeginN("W:SelectionChanged")
	for _, w in ipairs(self.SelectionChangedList) do
		local unitArray = w:SelectionChanged(selectedUnits, subselection)
		if unitArray then
			Spring.SelectUnitArray(unitArray)
			tracyZoneEnd()
			return true
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:GameProgress(serverFrameNum)
	tracyZoneBeginN("W:GameProgress")
	for _, w in ipairs(self.GameProgressList) do
		w:GameProgress(serverFrameNum)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	tracyZoneBeginN("W:UnsyncedHeightMapUpdate")
	local list = self.UnsyncedHeightMapUpdateList
	for i = #list, 1, -1 do
		list[i]:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:ShockFront(power, dx, dy, dz)
	tracyZoneBeginN("W:ShockFront")
	for _, w in ipairs(self.ShockFrontList) do
		w:ShockFront(power, dx, dy, dz)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:WorldTooltip(ttType, ...)
	tracyZoneBeginN("W:WorldTooltip")
	for _, w in ipairs(self.WorldTooltipList) do
		local tt = w:WorldTooltip(ttType, ...)
		if type(tt) == "string" and #tt > 0 then
			tracyZoneEnd()
			return tt
		end
	end
	tracyZoneEnd()
	return
end

function widgetHandler:MapDrawCmd(playerID, cmdType, px, py, pz, ...)
	tracyZoneBeginN("W:MapDrawCmd")
	local retval = false
	for _, w in ipairs(self.MapDrawCmdList) do
		local takeEvent = w:MapDrawCmd(playerID, cmdType, px, py, pz, ...)
		if takeEvent then
			retval = true
		end
	end
	tracyZoneEnd()
	return retval
end

function widgetHandler:ClearMapMarks()
	tracyZoneBeginN("W:ClearMapMarks")
	for _, w in ipairs(self.ClearMapMarksList) do
		w:ClearMapMarks()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GameSetup(state, ready, playerStates)
	tracyZoneBeginN("W:GameSetup")
	for _, w in ipairs(self.GameSetupList) do
		local success, newReady = w:GameSetup(state, ready, playerStates)
		if success then
			tracyZoneEnd()
			return true, newReady
		end
	end
	tracyZoneEnd()
	return false
end

function widgetHandler:DefaultCommand(...)
	tracyZoneBeginN("W:DefaultCommand")
	local list = self.DefaultCommandList
	for i = #list, 1, -1 do
		local result = list[i]:DefaultCommand(...)
		if type(result) == "number" then
			tracyZoneEnd()
			return result
		end
	end
	tracyZoneEnd()
	return nil --  not a number, use the default engine command
end

function widgetHandler:LanguageChanged()
	tracyZoneBeginN("W:LanguageChanged")
	for _, w in ipairs(self.LanguageChangedList) do
		w:LanguageChanged()
	end
	tracyZoneEnd()
end

function widgetHandler:UnitBlocked(unitDefID, reasons, builderUnitDefID)
	tracyZoneBeginN("W:UnitBlocked")
	for _, w in ipairs(self.UnitBlockedList) do
		w:UnitBlocked(unitDefID, reasons, builderUnitDefID)
	end
	tracyZoneEnd()
end

---A builder unit type gained or lost a build option (api_dynamic_build_options.lua).
function widgetHandler:BuildOptionsChanged(builderUnitDefID, builtUnitDefID, added)
	tracyZoneBeginN("W:BuildOptionsChanged")
	for _, w in ipairs(self.BuildOptionsChangedList) do
		w:BuildOptionsChanged(builderUnitDefID, builtUnitDefID, added)
	end
	tracyZoneEnd()
end

--------------------------------------------------------------------------------
--
--  Unit call-ins
--

function widgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:MetaUnitAdded")
	for _, w in ipairs(self.MetaUnitAddedList) do
		w:MetaUnitAdded(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:MetaUnitRemoved")
	for _, w in ipairs(self.MetaUnitRemovedList) do
		w:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	widgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitCreated")
	for _, w in ipairs(self.UnitCreatedList) do
		w:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitFinished(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitFinished")
	for _, w in ipairs(self.UnitFinishedList) do
		tracyZoneBeginN(w._tracyUnitFinishedName)
		w:UnitFinished(unitID, unitDefID, unitTeam)
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	tracyZoneBeginN("W:UnitFromFactory")
	for _, w in ipairs(self.UnitFromFactoryList) do
		w:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	widgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitDestroyed")
	for _, w in ipairs(self.UnitDestroyedList) do
		tracyZoneBeginN(w._tracyUnitDestroyedName)
		w:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitDestroyedByTeam(unitID, unitDefID, unitTeam, attackerTeamID)
	tracyZoneBeginN("W:UnitDestroyedByTeam")
	for _, w in ipairs(self.UnitDestroyedByTeamList) do
		w:UnitDestroyedByTeam(unitID, unitDefID, unitTeam, attackerTeamID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:RenderUnitDestroyed")
	-- at the time of committing, this does not get called by the widgethandler
	for _, w in ipairs(self.RenderUnitDestroyedList) do
		w:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	tracyZoneBeginN("W:UnitExperience")
	for _, w in ipairs(self.UnitExperienceList) do
		w:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)

	tracyZoneBeginN("W:UnitTaken")
	for _, w in ipairs(self.UnitTakenList) do
		w:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)

	tracyZoneBeginN("W:UnitGiven")
	for _, w in ipairs(self.UnitGivenList) do
		w:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitIdle(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitIdle")
	for _, w in ipairs(self.UnitIdleList) do
		w:UnitIdle(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

local CMD_BUILD = CMD.BUILD

-- Limits widget:UnitCommand to the registered commands (CMD.BUILD: all build commands).
-- Widgets that never register get every command.
function widgetHandler:RegisterUnitCommand(widget, cmdID)
	widget._unitCommandIDs = widget._unitCommandIDs or {}
	widget._unitCommandIDs[cmdID] = true
end

function widgetHandler:UnitCommand(
	unitID,
	unitDefID,
	unitTeam,
	cmdId,
	cmdParams,
	cmdOpts,
	cmdTag,
	playerID,
	fromSynced,
	fromLua
)
	tracyZoneBeginN("W:UnitCommand")
	local list = self.UnitCommandList
	for i = 1, #list do
		local w = list[i]
		local cmdIDs = w._unitCommandIDs
		if not cmdIDs or cmdIDs[cmdId] or (cmdId < 0 and cmdIDs[CMD_BUILD]) then
			w:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
		end
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	tracyZoneBeginN("W:UnitCmdDone")
	for _, w in ipairs(self.UnitCmdDoneList) do
		w:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	tracyZoneBeginN("W:UnitDamaged")
	for _, w in ipairs(self.UnitDamagedList) do
		w:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitStunned(unitID, unitDefID, unitTeam, stunned)
	tracyZoneBeginN("W:UnitStunned")
	for _, w in ipairs(self.UnitStunnedList) do
		w:UnitStunned(unitID, unitDefID, unitTeam, stunned)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitEnteredRadar(unitID, unitTeam)
	tracyZoneBeginN("W:UnitEnteredRadar")
	for _, w in ipairs(self.UnitEnteredRadarList) do
		w:UnitEnteredRadar(unitID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitEnteredLos(unitID, unitTeam)
	tracyZoneBeginN("W:UnitEnteredLos")
	for _, w in ipairs(self.UnitEnteredLosList) do
		w:UnitEnteredLos(unitID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitLeftRadar(unitID, unitTeam)
	tracyZoneBeginN("W:UnitLeftRadar")
	for _, w in ipairs(self.UnitLeftRadarList) do
		w:UnitLeftRadar(unitID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitLeftLos(unitID, unitTeam)
	tracyZoneBeginN("W:UnitLeftLos")
	for _, w in ipairs(self.UnitLeftLosList) do
		w:UnitLeftLos(unitID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitEnteredWater(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitEnteredWater")
	for _, w in ipairs(self.UnitEnteredWaterList) do
		w:UnitEnteredWater(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitEnteredAir(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitEnteredAir")
	for _, w in ipairs(self.UnitEnteredAirList) do
		w:UnitEnteredAir(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitLeftWater(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitLeftWater")
	for _, w in ipairs(self.UnitLeftWaterList) do
		w:UnitLeftWater(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitLeftAir(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitLeftAir")
	for _, w in ipairs(self.UnitLeftAirList) do
		w:UnitLeftAir(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	tracyZoneBeginN("W:UnitSeismicPing")
	for _, w in ipairs(self.UnitSeismicPingList) do
		w:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	tracyZoneBeginN("W:UnitLoaded")
	for _, w in ipairs(self.UnitLoadedList) do
		w:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	tracyZoneBeginN("W:UnitUnloaded")
	for _, w in ipairs(self.UnitUnloadedList) do
		w:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitCloaked(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitCloaked")
	for _, w in ipairs(self.UnitCloakedList) do
		w:UnitCloaked(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitDecloaked(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitDecloaked")
	for _, w in ipairs(self.UnitDecloakedList) do
		w:UnitDecloaked(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitMoveFailed(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:UnitMoveFailed")
	for _, w in ipairs(self.UnitMoveFailedList) do
		w:UnitMoveFailed(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:RecvLuaMsg(msg, playerID)
	tracyZoneBeginN("W:RecvLuaMsg:" .. msg:sub(1, 100))
	local retval = false
	if msg:find("LobbyOverlayActive", 1, true) == 1 then
		-- LuaMenu delivers these as player 0. From any other player they are spoofed.
		-- ! FIXME: We cannot distinguish LuaMenu from an actual player 0.
		if playerID ~= 0 then
			tracyZoneEnd()
			return true
		end
		self.chobbyInterface = (msg:byte(19) == 49) -- 49 == string.byte('1')
		retval = true
	end
	for _, w in ipairs(self.RecvLuaMsgList) do
		tracyZoneBeginN(w._tracyRecvLuaMsgName)
		if w:RecvLuaMsg(msg, playerID) then
			retval = true
		end
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return retval --  FIXME  --  another actionHandler type?
end

function widgetHandler:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	tracyZoneBeginN("W:StockpileChanged")
	for _, w in ipairs(self.StockpileChangedList) do
		w:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:VisibleUnitAdded(unitID, unitDefID, unitTeam, reason)
	tracyZoneBeginN("W:VisibleUnitAdded")
	for _, w in ipairs(self.VisibleUnitAddedList) do
		tracyZoneBeginN(w._tracyVisibleUnitAddedName)
		w:VisibleUnitAdded(unitID, unitDefID, unitTeam, reason)
		tracyZoneEnd()
	end
	tracyZoneEnd()
end

function widgetHandler:VisibleUnitRemoved(unitID, unitDefID, unitTeam, reason)
	tracyZoneBeginN("W:VisibleUnitRemoved")
	for _, w in ipairs(self.VisibleUnitRemovedList) do
		tracyZoneBeginN(w._tracyVisibleUnitRemovedName)
		w:VisibleUnitRemoved(unitID, unitDefID, unitTeam, reason)
		tracyZoneEnd()
	end
	tracyZoneEnd()
end

function widgetHandler:VisibleUnitsChanged(visibleUnits, numVisibleUnits)
	tracyZoneBeginN("W:VisibleUnitsChanged")
	for _, w in ipairs(self.VisibleUnitsChangedList) do
		tracyZoneBeginN(w._tracyVisibleUnitsChangedName)
		w:VisibleUnitsChanged(visibleUnits, numVisibleUnits)
		tracyZoneEnd()
	end
	tracyZoneEnd()
end

function widgetHandler:AlliedUnitAdded(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:AlliedUnitAdded")
	for _, w in ipairs(self.AlliedUnitAddedList) do
		w:AlliedUnitAdded(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
end

function widgetHandler:AlliedUnitRemoved(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:AlliedUnitRemoved")
	for _, w in ipairs(self.AlliedUnitRemovedList) do
		w:AlliedUnitRemoved(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
end

function widgetHandler:AlliedUnitsChanged(visibleUnits, numVisibleUnits)
	tracyZoneBeginN("W:AlliedUnitsChanged")
	for _, w in ipairs(self.AlliedUnitsChangedList) do
		w:AlliedUnitsChanged(visibleUnits, numVisibleUnits)
	end
	tracyZoneEnd()
end

--------------------------------------------------------------------------------
--
--  GFX
--

function widgetHandler:VisibleExplosion(px, py, pz, weaponID, ownerID)
	self:VisibleExplosionBatch({ px, py, pz, weaponID, ownerID }, 5)
end

function widgetHandler:Barrelfire(px, py, pz, weaponID, ownerID)
	self:BarrelfireBatch({ px, py, pz, weaponID, ownerID }, 5)
end

-- a sim frame's events as px, py, pz, weaponID, ownerID runs: batch widgets get the array,
-- the others one call per event
function widgetHandler:VisibleExplosionBatch(events, count)
	tracyZoneBeginN("W:VisibleExplosionBatch")
	for _, w in ipairs(self.VisibleExplosionBatchList) do
		tracyZoneBeginN(w._tracyVisibleExplosionName)
		w:VisibleExplosionBatch(events, count)
		tracyZoneEnd()
	end
	for _, w in ipairs(self.VisibleExplosionList) do
		tracyZoneBeginN(w._tracyVisibleExplosionName)
		for i = 1, count, 5 do
			w:VisibleExplosion(events[i], events[i + 1], events[i + 2], events[i + 3], events[i + 4])
		end
		tracyZoneEnd()
	end
	tracyZoneEnd()
end

function widgetHandler:BarrelfireBatch(events, count)
	tracyZoneBeginN("W:BarrelfireBatch")
	for _, w in ipairs(self.BarrelfireBatchList) do
		w:BarrelfireBatch(events, count)
	end
	for _, w in ipairs(self.BarrelfireList) do
		for i = 1, count, 5 do
			w:Barrelfire(events[i], events[i + 1], events[i + 2], events[i + 3], events[i + 4])
		end
	end
	tracyZoneEnd()
end

function widgetHandler:CrashingAircraft(unitID, unitDefID, unitTeam)
	tracyZoneBeginN("W:CrashingAircraft")
	for _, w in ipairs(self.CrashingAircraftList) do
		w:CrashingAircraft(unitID, unitDefID, unitTeam)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:SendStats(unitDefID, n, ts, dmgDealt, dmgRec, minutes, kills, killedCost)
	tracyZoneBeginN("W:SendStats")
	for _, w in ipairs(self.SendStatsList) do
		w:SendStats(unitDefID, n, ts, dmgDealt, dmgRec, minutes, kills, killedCost)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:SendStats_GameMode(mode)
	tracyZoneBeginN("W:SendStats_GameMode")
	for _, w in ipairs(self.SendStats_GameModeList) do
		w:SendStats_GameMode(mode)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:ActivityEvent(playerID)
	tracyZoneBeginN("W:ActivityEvent")
	for _, w in ipairs(self.ActivityEventList) do
		w:ActivityEvent(playerID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:FpsEvent(playerID, fps)
	tracyZoneBeginN("W:FpsEvent")
	for _, w in ipairs(self.FpsEventList) do
		w:FpsEvent(playerID, fps)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:ApmEvent(teamID, apm)
	tracyZoneBeginN("W:ApmEvent")
	for _, w in ipairs(self.ApmEventList) do
		w:ApmEvent(teamID, apm)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GpuMemEvent(playerID, mem)
	tracyZoneBeginN("W:GpuMemEvent")
	for _, w in ipairs(self.GpuMemEventList) do
		w:GpuMemEvent(playerID, mem)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:LuaMemEvent(playerID, mem)
	tracyZoneBeginN("W:LuaMemEvent")
	for _, w in ipairs(self.LuaMemEventList) do
		w:LuaMemEvent(playerID, mem)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:SystemEvent(playerID, systemData)
	tracyZoneBeginN("W:SystemEvent")
	for _, w in ipairs(self.SystemEventList) do
		w:SystemEvent(playerID, systemData)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:RankingEvent(ranking)
	tracyZoneBeginN("W:RankingEvent")
	for _, w in ipairs(self.RankingEventList) do
		w:RankingEvent(ranking)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:MouseCursorEvent(playerID, x1, z1, x2, z2, click)
	tracyZoneBeginN("W:MouseCursorEvent")
	for _, w in ipairs(self.MouseCursorEventList) do
		w:MouseCursorEvent(playerID, x1, z1, x2, z2, click)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:CameraBroadcastEvent(playerID, cameraState)
	tracyZoneBeginN("W:CameraBroadcastEvent")
	for _, w in ipairs(self.CameraBroadcastEventList) do
		w:CameraBroadcastEvent(playerID, cameraState)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:FeatureReclaimStartedETA(featureID, step)
	tracyZoneBeginN("W:FeatureReclaimStartedETA")
	for _, w in ipairs(self.FeatureReclaimStartedETAList) do
		w:FeatureReclaimStartedETA(featureID, step)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitBuildspeedDebuffHealthbars(unitID, startFrame, expireFrame)
	tracyZoneBeginN("W:UnitBuildspeedDebuffHealthbars")
	for _, w in ipairs(self.UnitBuildspeedDebuffHealthbarsList) do
		w:UnitBuildspeedDebuffHealthbars(unitID, startFrame, expireFrame)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitBuildspeedDebuffEndHealthbars(unitID)
	tracyZoneBeginN("W:UnitBuildspeedDebuffEndHealthbars")
	for _, w in ipairs(self.UnitBuildspeedDebuffEndHealthbarsList) do
		w:UnitBuildspeedDebuffEndHealthbars(unitID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GadgetAddMessage(msg)
	tracyZoneBeginN("W:GadgetAddMessage")
	for _, w in ipairs(self.GadgetAddMessageList) do
		w:GadgetAddMessage(msg)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GadgetReceiveAwards(awards)
	tracyZoneBeginN("W:GadgetReceiveAwards")
	for _, w in ipairs(self.GadgetReceiveAwardsList) do
		w:GadgetReceiveAwards(awards)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitScriptLight(unitID, unitDefID, lightIndex, param)
	tracyZoneBeginN("W:UnitScriptLight")
	for _, w in ipairs(self.UnitScriptLightList) do
		w:UnitScriptLight(unitID, unitDefID, lightIndex, param)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:NanoParticleUpdate(events, eventCount, gameFrame)
	tracyZoneBeginN("W:NanoParticleUpdate")
	local list = self.NanoParticleUpdateList
	for i = #list, 1, -1 do
		list[i]:NanoParticleUpdate(events, eventCount, gameFrame)
	end
	tracyZoneEnd()
end

function widgetHandler:UnitScriptDistortion(unitID, unitDefID, distortionIndex, param)
	tracyZoneBeginN("W:UnitScriptDistortion")
	for _, w in ipairs(self.UnitScriptDistortionList) do
		w:UnitScriptDistortion(unitID, unitDefID, distortionIndex, param)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitScriptDecal(unitID, unitDefID, decalIndex, posx, posz, heading)
	self:UnitScriptDecalBatch({ unitID, unitDefID, decalIndex, posx, posz, heading }, 6)
end

-- a sim frame's decals as unitID, unitDefID, decalIndex, posx, posz, heading runs: batch widgets get the
-- array, the others one call per decal
function widgetHandler:UnitScriptDecalBatch(decals, count)
	tracyZoneBeginN("W:UnitScriptDecalBatch")
	for _, w in ipairs(self.UnitScriptDecalBatchList) do
		w:UnitScriptDecalBatch(decals, count)
	end
	for _, w in ipairs(self.UnitScriptDecalList) do
		for i = 1, count, 6 do
			w:UnitScriptDecal(decals[i], decals[i + 1], decals[i + 2], decals[i + 3], decals[i + 4], decals[i + 5])
		end
	end
	tracyZoneEnd()
end

function widgetHandler:GadgetRemoveGrass(posx, posz, radius)
	tracyZoneBeginN("W:GadgetRemoveGrass")
	for _, w in ipairs(self.GadgetRemoveGrassList) do
		w:GadgetRemoveGrass(posx, posz, radius)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:GadgetCoopStartPoint(playerID, x, y, z)
	tracyZoneBeginN("W:GadgetCoopStartPoint")
	for _, w in ipairs(self.GadgetCoopStartPointList) do
		w:GadgetCoopStartPoint(playerID, x, y, z)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:NotificationEvent(msg)
	tracyZoneBeginN("W:NotificationEvent")
	for _, w in ipairs(self.NotificationEventList) do
		w:NotificationEvent(msg)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:NightFactorChanged(red, green, blue, shadow, altitude)
	tracyZoneBeginN("W:NightFactorChanged")
	for _, w in ipairs(self.NightFactorChangedList) do
		w:NightFactorChanged(red, green, blue, shadow, altitude)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:ScavEvent(args)
	tracyZoneBeginN("W:ScavEvent")
	for _, w in ipairs(self.ScavEventList) do
		w:ScavEvent(args)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:RaptorEvent(args)
	tracyZoneBeginN("W:RaptorEvent")
	for _, w in ipairs(self.RaptorEventList) do
		w:RaptorEvent(args)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:FeatureReclaimStartedHealthbars(featureID, step)
	tracyZoneBeginN("W:FeatureReclaimStartedHealthbars")
	for _, w in ipairs(self.FeatureReclaimStartedHealthbarsList) do
		w:FeatureReclaimStartedHealthbars(featureID, step)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitCaptureStartedHealthbars(unitID, step)
	tracyZoneBeginN("W:UnitCaptureStartedHealthbars")
	for _, w in ipairs(self.UnitCaptureStartedHealthbarsList) do
		w:UnitCaptureStartedHealthbars(unitID, step)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:ProjectileCreatedReloadHB(projectileID, ownerID, weaponID)
	tracyZoneBeginN("W:ProjectileCreatedReloadHB")
	for _, w in ipairs(self.ProjectileCreatedReloadHBList) do
		w:ProjectileCreatedReloadHB(projectileID, ownerID, weaponID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitParalyzeDamageHealthbars(unitID, unitDefID, damage)
	tracyZoneBeginN("W:UnitParalyzeDamageHealthbars")
	for _, w in ipairs(self.UnitParalyzeDamageHealthbarsList) do
		w:UnitParalyzeDamageHealthbars(unitID, unitDefID, damage)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:UnitParalyzeDamageEffect(unitID, unitDefID, damage)
	tracyZoneBeginN("W:UnitParalyzeDamageEffect")
	for _, w in ipairs(self.UnitParalyzeDamageEffectList) do
		w:UnitParalyzeDamageEffect(unitID, unitDefID, damage)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:SelectedUnitsClear(playerID)
	tracyZoneBeginN("W:SelectedUnitsClear")
	for _, w in ipairs(self.SelectedUnitsClearList) do
		w:SelectedUnitsClear(playerID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:SelectedUnitsSet(playerID, units, unitCount)
	tracyZoneBeginN("W:SelectedUnitsSet")
	for _, w in ipairs(self.SelectedUnitsSetList) do
		w:SelectedUnitsSet(playerID, units, unitCount)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:SelectedUnitsBatchUpdate(playerID, addUnits, addCount, remUnits, remCount)
	tracyZoneBeginN("W:SelectedUnitsBatchUpdate")
	for _, w in ipairs(self.SelectedUnitsBatchUpdateList) do
		w:SelectedUnitsBatchUpdate(playerID, addUnits, addCount, remUnits, remCount)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:SelectedUnitsRemove(playerID, unitID)
	tracyZoneBeginN("W:SelectedUnitsRemove")
	for _, w in ipairs(self.SelectedUnitsRemoveList) do
		w:SelectedUnitsRemove(playerID, unitID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:SelectedUnitsAdd(playerID, unitID)
	tracyZoneBeginN("W:SelectedUnitsAdd")
	for _, w in ipairs(self.SelectedUnitsAddList) do
		w:SelectedUnitsAdd(playerID, unitID)
	end
	tracyZoneEnd()
	return
end

function widgetHandler:LavaRenderState(tideLevel, heatDistortX, heatDistortZ)
	tracyZoneBeginN("W:LavaRenderState")
	for _, w in ipairs(self.LavaRenderStateList) do
		w:LavaRenderState(tideLevel, heatDistortX, heatDistortZ)
	end
	tracyZoneEnd()
	return
end

--------------------------------------------------------------------------------
--
--  Feature call-ins
--

function widgetHandler:FeatureCreated(featureID, allyTeam)
	tracyZoneBeginN("W:FeatureCreated")
	for _, w in ipairs(self.FeatureCreatedList) do
		tracyZoneBeginN(w._tracyFeatureCreatedName)
		w:FeatureCreated(featureID, allyTeam)
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

function widgetHandler:FeatureDestroyed(featureID, allyTeam)
	tracyZoneBeginN("W:FeatureDestroyed")
	for _, w in ipairs(self.FeatureDestroyedList) do
		tracyZoneBeginN(w._tracyFeatureDestroyedName)
		w:FeatureDestroyed(featureID, allyTeam)
		tracyZoneEnd()
	end
	tracyZoneEnd()
	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

widgetHandler:ConfigLayoutHandler(true)
widgetHandler:Initialize()

return widgetHandler
