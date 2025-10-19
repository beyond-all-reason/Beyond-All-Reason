--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gadgets.lua
--  brief:   the gadget manager, a call-in router
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  TODO:  - get rid of the ':'/self referencing, it's a waste of cycles
--         - (De)RegisterCOBCallback(data) + callin?
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local VFSMODE = VFS.ZIP_ONLY -- FIXME: ZIP_FIRST ?
if Spring.IsDevLuaEnabled() then
	VFSMODE = VFS.RAW_FIRST
end

VFS.Include('init.lua', nil, VFSMODE)

local SAFEWRAP = 0
-- 0: disabled
-- 1: enabled, but can be overriden by gadget.GetInfo().unsafe
-- 2: always enabled


local HANDLER_DIR = 'LuaGadgets/'
local GADGETS_DIR = Script.GetName():gsub('US$', '') .. '/Gadgets/'
local SCRIPT_DIR = Script.GetName() .. '/'
local LOG_SECTION = "" -- FIXME: "LuaRules" section is not registered anywhere



VFS.Include(HANDLER_DIR .. 'setupdefs.lua', nil, VFSMODE)
VFS.Include(SCRIPT_DIR .. 'system.lua', nil, VFSMODE)
VFS.Include(HANDLER_DIR .. 'callins.lua', nil, VFSMODE)
VFS.Include(SCRIPT_DIR .. 'utilities.lua', nil, VFSMODE)

local actionHandler = VFS.Include(HANDLER_DIR .. 'actions.lua', nil, VFSMODE)

-- Utility call
local isSyncedCode = (SendToUnsynced ~= nil)
local function IsSyncedCode()
	return isSyncedCode
end

if IsSyncedCode() then
	local devModeEnabled = string.find(string.upper(Game.gameVersion), "$VERSION", 1, true)
	Spring.SetGameRulesParam('isDevMode', devModeEnabled)
end

--------------------------------------------------------------------------------

--function pgl()
--	-- (print gadget list)  FIXME: move this into a gadget
--	for k, v in ipairs(gadgetHandler.gadgets) do
--		Spring.Log(LOG_SECTION, LOG.ERROR,
--			string.format("%3i  %3i  %s", k, v.ghInfo.layer, v.ghInfo.name)
--		)
--	end
--end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  the gadgetHandler object
--

gadgetHandler = {

	gadgets = {},

	orderList = {},

	knownGadgets = {},
	knownCount = 0,
	knownChanged = true,

	GG = {}, -- shared table for gadgets

	globals = {}, -- global vars/funcs

	CMDIDs = {},

	xViewSize = 1,
	yViewSize = 1,
	xViewSizeOld = 1,
	yViewSizeOld = 1,

	actionHandler = actionHandler,
	mouseOwner = nil,
}


-- these call-ins are set to 'nil' if not used
-- they are setup in UpdateCallIns()
local callInLists = {
	"Shutdown",

	"GamePreload",
	"GameStart",
	"GameOver",
	"GameID",
	"TeamDied",

	"PlayerAdded",
	"PlayerChanged",
	"PlayerRemoved",

	"GameFrame",
	"GameFramePost",
	"GamePaused",

	"ViewResize",  -- FIXME ?

	"TextCommand",
	"GotChatMsg",
	"RecvLuaMsg",

	-- Unit CallIns
	"UnitCreated",
	"UnitFinished",
	"UnitReverseBuilt",
	"UnitFromFactory",
	"UnitDestroyed",
	"RenderUnitDestroyed",
	"UnitExperience",
	"UnitIdle",
	"UnitCmdDone",
	"UnitPreDamaged",
	"UnitDamaged",
	"UnitStunned",
	"UnitTaken",
	"UnitGiven",
	"UnitEnteredRadar",
	"UnitEnteredLos",
	"UnitLeftRadar",
	"UnitLeftLos",
	"UnitSeismicPing",
	"UnitLoaded",
	"UnitUnloaded",
	"UnitCloaked",
	"UnitDecloaked",

	"MetaUnitAdded",
	"MetaUnitRemoved",

	-- optional
	-- "UnitUnitCollision",
	-- "UnitFeatureCollision",
	-- "UnitMoveFailed",
	"StockpileChanged",

	"ActiveCommandChanged",
	"CameraRotationChanged",
	"CameraPositionChanged",
	"CommandNotify",

	-- Feature CallIns
	"FeatureCreated",
	"FeatureDestroyed",
	"FeatureDamaged",
	"FeaturePreDamaged",

	-- Projectile CallIns
	"ProjectileCreated",
	"ProjectileDestroyed",

	-- Shield CallIns
	"ShieldPreDamaged",

	-- Misc Synced CallIns
	"Explosion",

	-- LUS callins
	"ScriptFireWeapon",
	"ScriptEndBurst",

	-- LuaRules CallIns (note: the *PreDamaged calls belong here too)
	"CommandFallback",
	"AllowCommand",
	"AllowStartPosition",
	"AllowUnitCreation",
	"AllowUnitTransfer",
	"AllowUnitBuildStep",
	"AllowUnitCaptureStep",
	"AllowUnitTransport",
	"AllowUnitTransportLoad",
	"AllowUnitTransportUnload",
	"AllowUnitCloak",
	"AllowUnitDecloak",
	"AllowUnitTargetRange",
	"AllowFeatureBuildStep",
	"AllowFeatureCreation",
	"AllowResourceLevel",
	"AllowResourceTransfer",
	"AllowDirectUnitControl",
	"AllowBuilderHoldFire",
	"MoveCtrlNotify",
	"TerraformComplete",
	"AllowWeaponTargetCheck",
	"AllowWeaponTarget",
	"AllowWeaponInterceptTarget",
	-- unsynced
	"DrawUnit",
	"DrawFeature",
	"DrawShield",
	"DrawProjectile",
	"RecvSkirmishAIMessage",

	"SunChanged",

	-- COB CallIn  (FIXME?)
	"CobCallback",

	-- Unsynced CallIns
	"Update",
	"DefaultCommand",
	"DrawGenesis",
	"DrawWorld",
	"DrawWorldPreUnit",
	"DrawWorldShadow",
	"DrawWorldReflection",
	"DrawWorldRefraction",
	"DrawScreenEffects",
	"DrawScreenPost",
	"DrawScreen",
	"DrawInMiniMap",
	'DrawOpaqueUnitsLua',
	'DrawOpaqueFeaturesLua',
	'DrawAlphaUnitsLua',
	'DrawAlphaFeaturesLua',
	'DrawShadowUnitsLua',
	'DrawShadowFeaturesLua',

	'FontsChanged',

	"RecvFromSynced",

	-- moved from LuaUI
	"KeyPress",
	"KeyRelease",
	"MousePress",
	"MouseRelease",
	"MouseMove",
	"MouseWheel",
	"IsAbove",
	"GetTooltip",

	-- FIXME -- not implemented  (more of these?)
	"WorldTooltip",
	"MapDrawCmd",
	"GameSetup",
	"DefaultCommand",

	-- Save/Load
	"Save",
	"Load",

	-- FIXME: NOT IN BASE
	"UnitCommand",
	"UnitEnteredWater",
	"UnitEnteredAir",
	"UnitLeftWater",
	"UnitLeftAir",

	"UnsyncedHeightMapUpdate"
}


-- initialize the call-in lists
do
	for _,listname in ipairs(callInLists) do
		gadgetHandler[listname .. 'List'] = {}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  array-table reverse iterator
--
--  used to invert layer ordering so draw and events will have inverse ordering
--
local function r_ipairs(tbl)
	local function r_iter(tbl, key)
		if key <= 1 then
			return nil
		end

		-- next idx, next val
		return key - 1, tbl[key - 1]
	end

	return r_iter, tbl, (1 + #tbl)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  returns:  basename, dirname
--

local function Basename(fullpath)
	local _, _, base = string.find(fullpath, "([^\\/:]*)$")
	local _, _, path = string.find(fullpath, "(.*[\\/:])[^\\/:]*$")
	if (path == nil) then
		path = ""
	end
	return base, path
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- This table stores gadget paths that we want to override game side.
-- Please indicate why you are adding each file in a comment
local VFSMODE_OVERRIDE = {
	['luagaia/gadgets/fp_featureplacer.lua'] = VFS.GAME
	}

function gadgetHandler:Initialize()
	gadgetHandler:CreateQueuedReorderFuncs()
	local syncedHandler = Script.GetSynced()

	local unsortedGadgets = {}
	-- get the gadget names
	local gadgetFiles = VFS.DirList(GADGETS_DIR, "*.lua", VFSMODE)
	--  table.sort(gadgetFiles)

	--  for k,gf in ipairs(gadgetFiles) do
	--    Spring.Echo('gf1 = ' .. gf) -- FIXME
	--  end
	local doMoreYield = (Spring.Yield ~= nil);
	-- stuff the gadgets into unsortedGadgets
	for k, gf in ipairs(gadgetFiles) do
		--    Spring.Echo('gf2 = ' .. gf) -- FIXME
		local gadget = self:LoadGadget(gf, VFSMODE_OVERRIDE[string.lower(gf)])
		if gadget then
			table.insert(unsortedGadgets, gadget)
			if not IsSyncedCode() and doMoreYield then
				doMoreYield = Spring.Yield()
				if doMoreYield == false then --GetThreadSafety == false
					--Spring.Echo("GadgetHandler Yield: entering critical section")
				end
			end
		end
	end

	-- sort the gadgets
	table.sort(unsortedGadgets, function(g1, g2)
		local l1 = g1.ghInfo.layer
		local l2 = g2.ghInfo.layer
		if l1 ~= l2 then
			return (l1 < l2)
		end
		local n1 = g1.ghInfo.name
		local n2 = g2.ghInfo.name
		local o1 = self.orderList[n1]
		local o2 = self.orderList[n2]
		if o1 ~= o2 then
			return (o1 < o2)
		else
			return (n1 < n2)
		end
	end)

	-- add the gadgets
	for _, g in ipairs(unsortedGadgets) do
		gadgetHandler:InsertGadgetRaw(g)

		local gtype = ((syncedHandler and "synced") or "unsynced")
		local gname = g.ghInfo.name
		local gbasename = g.ghInfo.basename

		Spring.Log(LOG_SECTION, LOG.INFO, string.format("Loaded %s gadget:  %-18s  <%s>", gtype, gname, gbasename))
	end
	-- Since Initialize is run out of the normal callin wrapper, we
	-- need to reorder explicitly here.
	gadgetHandler:PerformReorders()
end

function gadgetHandler:LoadGadget(filename, overridevfsmode)
	local kbytes = false -- set to number to enable
	if kbytes and collectgarbage then -- only present in special debug builds, otherwise collectgarbage is not preset in synced context!
		collectgarbage("collect") -- call it twice, mark
		collectgarbage("collect") -- sweep
		kbytes = collectgarbage("count")
	end

	local basename = Basename(filename)
	local text = VFS.LoadFile(filename, overridevfsmode or VFSMODE)
	if text == nil then
		Spring.Log(LOG_SECTION, LOG.ERROR, 'Failed to load: ' .. filename)
		return nil
	end
	local chunk, err = loadstring(text, filename)
	if chunk == nil then
		Spring.Log(LOG_SECTION, LOG.ERROR, 'Failed to load: ' .. basename .. '  (' .. err .. ')')
		return nil
	end

	local gadget = gadgetHandler:NewGadget()

	setfenv(chunk, gadget)
	local success, err = pcall(chunk)
	if not success then
		Spring.Log(LOG_SECTION, LOG.ERROR, 'Failed to load: ' .. basename .. '  (' .. err .. ')')
		return nil
	end
	if err == false then -- note that all "normal" gadgets return `nil` implicitly at EOF, so don't do "if not err"
		return nil -- gadget asked for a quiet death
	end

	if gadget.GetInfo and (Platform and not Platform.check(gadget.GetInfo().depends)) then
		Spring.Echo('Missing capabilities:  ' .. gadget:GetInfo().name .. '. Disabling.')
		return nil
	end

	-- raw access to gadgetHandler
	if gadget.GetInfo and gadget:GetInfo().handler then
		gadget.gadgetHandler = self
	end

	self:FinalizeGadget(gadget, filename, basename)
	local name = gadget.ghInfo.name

	err = self:ValidateGadget(gadget)
	if err then
		Spring.Log(LOG_SECTION, LOG.ERROR, 'Failed to load: ' .. basename .. '  (' .. err .. ')')
		return nil
	end

	local knownInfo = self.knownGadgets[name]
	if knownInfo then
		if knownInfo.active then
			Spring.Log(LOG_SECTION, LOG.ERROR, 'Failed to load: ' .. basename .. '  (duplicate name)')
			return nil
		end
	else
		-- create a knownInfo table
		knownInfo = {}
		knownInfo.desc = gadget.ghInfo.desc
		knownInfo.author = gadget.ghInfo.author
		knownInfo.basename = gadget.ghInfo.basename
		knownInfo.filename = gadget.ghInfo.filename
		self.knownGadgets[name] = knownInfo
		self.knownCount = self.knownCount + 1
		self.knownChanged = true
	end
	knownInfo.active = true

	local info = gadget.GetInfo and gadget:GetInfo()
	local order = self.orderList[name]
	if ((order ~= nil and order > 0) or (order == nil and (info == nil or info.enabled))) then
		-- this will be an active gadget
		if order == nil then
			self.orderList[name] = 12345  -- back of the pack
		else
			self.orderList[name] = order
		end
	else
		self.orderList[name] = 0
		self.knownGadgets[name].active = false
		return nil
	end

	if kbytes then
		collectgarbage("collect") -- mark
		collectgarbage("collect") -- sweep
		Spring.Echo("LoadGadget",filename,"delta=",collectgarbage("count")-kbytes,"total=",collectgarbage("count"),"KB, synced =", IsSyncedCode())
	end
	return gadget
end

function gadgetHandler:NewGadget()
	local gadget = {}
	-- load the system calls into the gadget table
	for k, v in pairs(System) do
		gadget[k] = v
	end
	gadget._G = _G         -- the global table
	gadget.GG = self.GG    -- the shared table
	gadget.gadget = gadget -- easy self referencing

	-- wrapped calls (closures)
	gadget.gadgetHandler = {}
	local gh = gadget.gadgetHandler
	local self = self

	gadget.include = function(f)
		return VFS.Include(f, gadget, VFSMODE)
	end

	gh.RaiseGadget = function(_)
		self:RaiseGadget(gadget)
	end
	gh.LowerGadget = function(_)
		self:LowerGadget(gadget)
	end
	gh.RemoveGadget = function(_)
		self:RemoveGadget(gadget)
	end
	gh.GetViewSizes = function(_)
		return self:GetViewSizes()
	end
	gh.GetHourTimer = function(_)
		return self:GetHourTimer()
	end
	gh.IsSyncedCode = function(_)
		return IsSyncedCode()
	end

	gh.UpdateCallIn = function(_, name)
		self:UpdateGadgetCallIn(name, gadget)
	end
	gh.RemoveCallIn = function(_, name)
		self:RemoveGadgetCallIn(name, gadget)
	end

	gh.RegisterCMDID = function(_, id)
		self:RegisterCMDID(gadget, id)
	end

	gh.RegisterGlobal = function(_, name, value)
		return self:RegisterGlobal(gadget, name, value)
	end
	gh.DeregisterGlobal = function(_, name)
		return self:DeregisterGlobal(gadget, name)
	end
	gh.SetGlobal = function(_, name, value)
		return self:SetGlobal(gadget, name, value)
	end

	gh.AddChatAction = function(_, cmd, func, help)
		return actionHandler.AddChatAction(gadget, cmd, func, help)
	end
	gh.RemoveChatAction = function(_, cmd)
		return actionHandler.RemoveChatAction(gadget, cmd)
	end
	gh.RegisterAllowCommand = function(_, cmdID)
		return self:RegisterAllowCommand(gadget, cmdID)
	end
	gh.DeregisterAllowCommands = function(_)
		return self:DeregisterAllowCommands(gadget)
	end

	if not IsSyncedCode() then
		gh.AddSyncAction = function(_, cmd, func, help)
			return actionHandler.AddSyncAction(gadget, cmd, func, help)
		end
		gh.RemoveSyncAction = function(_, cmd)
			return actionHandler.RemoveSyncAction(gadget, cmd)
		end
	end

	-- for proxied call-ins
	gh.IsMouseOwner = function(_)
		return (self.mouseOwner == gadget)
	end
	gh.DisownMouse = function(_)
		if self.mouseOwner == gadget then
			self.mouseOwner = nil
		end
	end

	return gadget
end

function gadgetHandler:FinalizeGadget(gadget, filename, basename)
	local gi = {}

	gi.filename = filename
	gi.basename = basename
	if gadget.GetInfo == nil then
		gi.name = basename
		gi.layer = 0
	else
		local info = gadget:GetInfo()
		gi.name = info.name or basename
		gi.layer = info.layer or 0
		gi.desc = info.desc or ""
		gi.author = info.author or ""
		gi.license = info.license or ""
		gi.enabled = info.enabled or false
	end

	gadget.ghInfo = {}  --  a proxy table
	local mt = {
		__index = gi,
		__newindex = function()
			error("ghInfo tables are read-only")
		end,
		__metatable = "protected"
	}
	setmetatable(gadget.ghInfo, mt)
end

function gadgetHandler:ValidateGadget(gadget)
	if gadget.GetTooltip and not gadget.IsAbove then
		return "Gadget has GetTooltip() but not IsAbove()"
	end
	return nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SafeWrap(func, funcName)
	local gh = gadgetHandler
	return function(g, ...)
		local r = { pcall(func, g, ...) }
		if r[1] then
			table.remove(r, 1)
			return unpack(r)
		else
			if funcName ~= 'Shutdown' then
				gadgetHandler:RemoveGadget(g)
			else
				Spring.Log(LOG_SECTION, LOG.ERROR, 'Error in Shutdown')
			end
			local name = g.ghInfo.name
			Spring.Log(LOG_SECTION, LOG.INFO, r[2])
			Spring.Log(LOG_SECTION, LOG.INFO, 'Removed gadget: ' .. name)
			return nil
		end
	end
end

local function SafeWrapGadget(gadget)
	if SAFEWRAP <= 0 then
		return
	elseif SAFEWRAP == 1 then
		if gadget.GetInfo and gadget.GetInfo().unsafe then
			Spring.Log(LOG_SECTION, LOG.ERROR, 'LuaUI: loaded unsafe gadget: ' .. gadget.ghInfo.name)
			return
		end
	end

	for _, ciName in ipairs(callInLists) do
		if gadget[ciName] then
			gadget[ciName] = SafeWrap(gadget[ciName], ciName)
		end
		if gadget.Initialize then
			gadget.Initialize = SafeWrap(gadget.Initialize, 'Initialize')
		end
	end
end


--------------------------------------------------------------------------------

local function ArrayInsert(t, f, g)
	if f then
		local layer = g.ghInfo.layer
		local index = 1
		for i, v in ipairs(t) do
			if v == g then
				return -- already in the table
			end
			if layer >= v.ghInfo.layer then
				index = i + 1
			end
		end
		table.insert(t, index, g)
	end
end

local function ArrayRemove(t, g)
	for k, v in ipairs(t) do
		if v == g then
			table.remove(t, k)
			-- break
		end
	end
end

--------------------------------------------------------------------------------
--- Safe reordering

-- Since we are traversing lists, some of the gadgetHandler api would be dangerous to use.
--
-- We will queue all the dangerous methods to process after callin loop finishes iterating.
-- The 'real' methods have 'Raw' appended to them, and are unsafe to use unless you know what
-- you are doing.

local reorderQueue = {}
local reorderNeeded = false
local reorderFuncs = {}
local callinDepth = 0

function gadgetHandler:CreateQueuedReorderFuncs()
	-- This will create an array with linked Raw methods so we can find them by index.
	-- It will also create the gadgetHandler usual api queing the calls.
	local reorderFuncNames = {'InsertGadget', 'RemoveGadget', 'EnableGadget', 'DisableGadget',
		'LowerGadget', 'RaiseGadget', 'UpdateGadgetCallIn', 'RemoveGadgetCallIn'}
	local queueReorder = gadgetHandler.QueueReorder

	for idx, name in ipairs(reorderFuncNames) do
		-- linked method index
		reorderFuncs[#reorderFuncs + 1] = gadgetHandler[name .. 'Raw']

		-- gadgetHandler api
		gadgetHandler[name] = function(s, ...)
			queueReorder(s, idx, ...)
		end
	end
end

function gadgetHandler:QueueReorder(methodIndex, ...)
	reorderQueue[#reorderQueue + 1] = {methodIndex, ...}
	reorderNeeded = true
end

function gadgetHandler:PerformReorder(methodIndex, ...)
	reorderFuncs[methodIndex](self, ...)
end

function gadgetHandler:PerformReorders()
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

function gadgetHandler:InsertGadgetRaw(gadget)
	if gadget == nil then
		return
	end
	ArrayInsert(self.gadgets, true, gadget)
	for _, listname in ipairs(callInLists) do
		local func = gadget[listname]
		if type(func) == 'function' then
			ArrayInsert(self[listname .. 'List'], func, gadget)
		end
	end

	local kbytes = nil -- set to number to enable
	if kbytes and collectgarbage then
		collectgarbage("collect")
		collectgarbage("collect")
		kbytes= collectgarbage("count")
	end

	self:UpdateCallIns()
	if gadget.Initialize then
		gadget:Initialize()
	end
	self:UpdateCallIns()

	if gadget.AllowCommand and not self:HasAllowCommands(gadget) then
		Spring.Log('AllowCommand', LOG.WARNING, "<" .. gadget.ghInfo.basename .. "> AllowCommand defined but didn't register any commands. Autoregistering for all commands!")
		self:RegisterAllowCommand(gadget, CMD.ANY)
	end

	if kbytes then
		collectgarbage("collect")
		collectgarbage("collect")
		Spring.Echo("Initialize",gadget.ghInfo.name,"delta=",collectgarbage("count")-kbytes,"total=",collectgarbage("count"),"KB, synced =", IsSyncedCode())
	end
end

function gadgetHandler:RemoveGadgetRaw(gadget)
	if gadget == nil then
		return
	end

	local name = gadget.ghInfo.name
	self.knownGadgets[name].active = false
	if gadget.Shutdown then
		gadget:Shutdown()
	end

	ArrayRemove(self.gadgets, gadget)
	self:RemoveGadgetGlobals(gadget)
	actionHandler.RemoveGadgetActions(gadget)
	for _, listname in ipairs(callInLists) do
		ArrayRemove(self[listname .. 'List'], gadget)
	end
	self:DeregisterAllowCommands(gadget)

	for id, g in pairs(self.CMDIDs) do
		if g == gadget then
			self.CMDIDs[id] = nil
		end
	end

	self:UpdateCallIns()
end


--------------------------------------------------------------------------------

function gadgetHandler:UpdateCallIn(name)
	local listName = name .. 'List'
	local forceUpdate = (name == 'GotChatMsg' or name == 'RecvFromSynced') -- redundant?

	_G[name] = nil

	if forceUpdate or #self[listName] > 0 then
		local selffunc = self[name]

		if selffunc ~= nil then
			-- max 2 return parameters for top level callins!
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
			Spring.Log(LOG_SECTION, LOG.ERROR, "UpdateCallIn: " .. name .. " is not implemented")
		end
	end

	Script.UpdateCallIn(name)
end

function gadgetHandler:UpdateGadgetCallInRaw(name, g)
	local listName = name .. 'List'
	local ciList = self[listName]
	if ciList then
		local func = g[name]
		if type(func) == 'function' then
			ArrayInsert(ciList, func, g)
		else
			ArrayRemove(ciList, g)
		end
		self:UpdateCallIn(name)
	else
		Spring.Log(LOG_SECTION, LOG.ERROR, 'UpdateGadgetCallIn: bad name: ' .. name)
	end
end

function gadgetHandler:RemoveGadgetCallInRaw(name, g)
	local listName = name .. 'List'
	local ciList = self[listName]
	if ciList then
		ArrayRemove(ciList, g)
		self:UpdateCallIn(name)
	else
		Spring.Log(LOG_SECTION, LOG.ERROR, 'RemoveGadgetCallIn: bad name: ' .. name)
	end
end

function gadgetHandler:UpdateCallIns()
	for _, name in ipairs(callInLists) do
		self:UpdateCallIn(name)
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadgetHandler:EnableGadgetRaw(name)
	local ki = self.knownGadgets[name]
	if not ki then
		Spring.Log(LOG_SECTION, LOG.ERROR, "EnableGadget(), could not find gadget: " .. tostring(name))
		return false
	end
	if not ki.active then
		Spring.Log(LOG_SECTION, LOG.INFO, 'Loading:  ' .. ki.filename)
		local order = gadgetHandler.orderList[name]
		if not order or order <= 0 then
			self.orderList[name] = 1
		end
		local w = self:LoadGadget(ki.filename)
		if not w then
			return false
		end
		self:InsertGadgetRaw(w)
	end
	return true
end

function gadgetHandler:DisableGadgetRaw(name)
	local ki = self.knownGadgets[name]
	if not ki then
		Spring.Log(LOG_SECTION, LOG.ERROR, "DisableGadget(), could not find gadget: " .. tostring(name))
		return false
	end
	if ki.active then
		local w = self:FindGadget(name)
		if not w then
			return false
		end
		Spring.Log(LOG_SECTION, LOG.INFO, 'Removed:  ' .. ki.filename)
		self:RemoveGadgetRaw(w)     -- deactivate
		self.orderList[name] = 0 -- disable
	end
	return true
end

function gadgetHandler:ToggleGadget(name)
	local ki = self.knownGadgets[name]
	if not ki then
		Spring.Log(LOG_SECTION, LOG.ERROR, "ToggleGadget(), could not find gadget: " .. tostring(name))
		return
	end
	if ki.active then
		return self:DisableGadget(name)
	elseif self.orderList[name] <= 0 then
		return self:EnableGadget(name)
	else
		-- the gadget is not active, but enabled; disable it
		self.orderList[name] = 0
	end
	return true
end


--------------------------------------------------------------------------------

local function FindGadgetIndex(t, w)
	for k, v in ipairs(t) do
		if (v == w) then
			return k
		end
	end
	return nil
end

local function FindLowestIndex(t, i, layer)
	for x = (i - 1), 1, -1 do
		if t[x].ghInfo.layer < layer then
			return x + 1
		end
	end
	return 1
end

function gadgetHandler:RaiseGadgetRaw(gadget)
	if gadget == nil then
		return
	end
	local function Raise(t, f, w)
		if f == nil then
			return
		end
		local i = FindGadgetIndex(t, w)
		if i == nil then
			return
		end
		local n = FindLowestIndex(t, i, w.ghInfo.layer)
		if n and n < i then
			table.remove(t, i)
			table.insert(t, n, w)
		end
	end
	Raise(self.gadgets, true, gadget)
	for _, listname in ipairs(callInLists) do
		Raise(self[listname .. 'List'], gadget[listname], gadget)
	end
	self:ReorderAllowCommands(gadget, Raise)
end

local function FindHighestIndex(t, i, layer)
	local ts = #t
	for x = (i + 1), ts do
		if t[x].ghInfo.layer > layer then
			return (x - 1)
		end
	end
	return ts
end

function gadgetHandler:LowerGadgetRaw(gadget)
	if gadget == nil then
		return
	end
	local function Lower(t, f, w)
		if f == nil then
			return
		end
		local i = FindGadgetIndex(t, w)
		if i == nil then
			return
		end
		local n = FindHighestIndex(t, i, w.ghInfo.layer)
		if n and n > i then
			table.insert(t, n+1, w)
			table.remove(t, i)
		end
	end
	Lower(self.gadgets, true, gadget)
	for _, listname in ipairs(callInLists) do
		Lower(self[listname .. 'List'], gadget[listname], gadget)
	end
	self:ReorderAllowCommands(gadget, Lower)
end

function gadgetHandler:FindGadget(name)
	if type(name) ~= 'string' then
		return nil
	end
	for k, v in ipairs(self.gadgets) do
		if name == v.ghInfo.name then
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

function gadgetHandler:RegisterGlobal(owner, name, value)
	if name == nil then
		return false
	end
	if _G[name] ~= nil then
		return false
	end
	if self.globals[name] ~= nil then
		return false
	end
	if CALLIN_MAP[name] ~= nil then
		return false
	end

	_G[name] = value
	self.globals[name] = owner
	return true
end

function gadgetHandler:DeregisterGlobal(owner, name)
	if name == nil then
		return false
	end
	_G[name] = nil
	self.globals[name] = nil
	return true
end

function gadgetHandler:SetGlobal(owner, name, value)
	if name == nil or self.globals[name] ~= owner then
		return false
	end
	_G[name] = value
	return true
end

function gadgetHandler:RemoveGadgetGlobals(owner)
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

function gadgetHandler:GetHourTimer()
	return hourTimer
end

function gadgetHandler:GetViewSizes()
	return self.xViewSize, self.yViewSize
end

function gadgetHandler:RegisterCMDID(gadget, id)
	if id <= 1000 then
		Spring.Log(LOG_SECTION, LOG.ERROR, 'Gadget (' .. gadget.ghInfo.name .. ') ' ..
			'tried to register a reserved CMD_ID')
		Script.Kill('Reserved CMD_ID code: ' .. id)
	end

	if self.CMDIDs[id] ~= nil then
		Spring.Log(LOG_SECTION, LOG.ERROR, 'Gadget (' .. gadget.ghInfo.name .. ') ' ..
			'tried to register a duplicated CMD_ID')
		Script.Kill('Duplicate CMD_ID code: ' .. id)
	end

	self.CMDIDs[id] = gadget
end



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  The call-in distribution routines
--
function gadgetHandler:GameSetup(state, ready, playerStates)
	local success, newReady = false, ready
	for _, g in ipairs(self.GameSetupList) do
		success, newReady = g:GameSetup(state, newReady, playerStates)
	end
	return success, newReady
end

function gadgetHandler:GamePreload()
	for _, g in ipairs(self.GamePreloadList) do
		g:GamePreload()
	end
	return
end

function gadgetHandler:GameStart()
	for _, g in ipairs(self.GameStartList) do
		g:GameStart()
	end
	return
end

function gadgetHandler:Shutdown()
	for _, g in ipairs(self.ShutdownList) do
		g:Shutdown()
	end
	return
end

function gadgetHandler:GameFrame(frameNum)
	-- Since GameGrame should never be called nested ensure here the callinDepth
	-- is ok. We set it to 1 so after the run it will be set to 0 again.
	callinDepth = 1
	tracy.ZoneBeginN("G:GameFrame")
	for _, g in ipairs(self.GameFrameList) do
		tracy.ZoneBeginN("G:GameFrame:" .. g.ghInfo.name)
		g:GameFrame(frameNum)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:GameFramePost(frameNum)
	callinDepth = 1 -- See notes on GameFrame.
	tracy.ZoneBeginN("G:GameFramePost")
	for _, g in r_ipairs(self.GameFramePostList) do
		tracy.ZoneBeginN("G:GameFramePost:" .. g.ghInfo.name)
		g:GameFramePost(frameNum)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
end

function gadgetHandler:GamePaused(playerID, paused)
	for _, g in ipairs(self.GamePausedList) do
		g:GamePaused(playerID, paused)
	end
	return
end

function gadgetHandler:RecvFromSynced(...)
	local arg1, arg2 = ...
  if (type(arg1) == 'string') then
		tracy.ZoneBeginN("G:RecvFromSynced:"..arg1)
	else
		tracy.ZoneBeginN("G:RecvFromSynced")
	end
	if actionHandler.RecvFromSynced(...) then
		tracy.ZoneEnd()
		return
	end
	for _, g in ipairs(self.RecvFromSyncedList) do
		if g:RecvFromSynced(...) then
			tracy.ZoneEnd()
			return
		end
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:GotChatMsg(msg, player)
	if player == 0 and Spring.IsCheatingEnabled() then
		local sp = '^%s*'    -- start pattern
		local ep = '%s+(.*)' -- end pattern
		local s, e, match
		s, e, match = string.find(msg, sp .. 'togglegadget' .. ep)
		if match then
			self:ToggleGadget(match)
			return true
		end
		s, e, match = string.find(msg, sp .. 'enablegadget' .. ep)
		if match then
			self:EnableGadget(match)
			return true
		end
		s, e, match = string.find(msg, sp .. 'disablegadget' .. ep)
		if match then
			self:DisableGadget(match)
			return true
		end
	end

	if actionHandler.GotChatMsg(msg, player) then
		return true
	end

	for _, g in ipairs(self.GotChatMsgList) do
		if g:GotChatMsg(msg, player) then
			return true
		end
	end

	return false
end

function gadgetHandler:RecvLuaMsg(msg, player)
	tracy.ZoneBeginN("G:RecvLuaMsg")
	for _, g in ipairs(self.RecvLuaMsgList) do
		if g:RecvLuaMsg(msg, player) then
			tracy.ZoneEnd()
			return true
		end
	end
	tracy.ZoneEnd()
	return false
end

function gadgetHandler:TextCommand(command)
	for _, g in ipairs(self.TextCommandList) do
		if g:TextCommand(command) then
			return true
		end
	end
	return
end

--------------------------------------------------------------------------------
--
--  Drawing call-ins
--

-- generates ViewResize() calls for the gadgets
function gadgetHandler:SetViewSize(vsx, vsy)
	self.xViewSize = vsx
	self.yViewSize = vsy
	if self.xViewSizeOld ~= vsx or self.yViewSizeOld ~= vsy then
		gadgetHandler:ViewResize(vsx, vsy)
		self.xViewSizeOld = vsx
		self.yViewSizeOld = vsy
	end
end

function gadgetHandler:ViewResize(vsx, vsy)
	tracy.ZoneBeginN("G:ViewResize")
	for _, g in ipairs(self.ViewResizeList) do
		tracy.ZoneBeginN("G:ViewResize:" .. g.ghInfo.name)
		g:ViewResize(vsx, vsy)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end


--------------------------------------------------------------------------------
--
--  Game call-ins
--

function gadgetHandler:GameOver(winningAllyTeams)
	for _, g in ipairs(self.GameOverList) do
		g:GameOver(winningAllyTeams)
	end
	return
end

function gadgetHandler:GameID(gameID)
	for _, g in ipairs(self.GameIDList) do
		g:GameID(gameID)
	end
	return
end

function gadgetHandler:TeamDied(teamID)
	for _, g in ipairs(self.TeamDiedList) do
		g:TeamDied(teamID)
	end
	return
end

function gadgetHandler:TeamChanged(teamID)
	for _, g in ipairs(self.TeamChangedList) do
		g:TeamChanged(teamID)
	end
	return
end

function gadgetHandler:PlayerChanged(playerID)
	tracy.ZoneBeginN("G:PlayerChanged")
	for _, g in ipairs(self.PlayerChangedList) do
		tracy.ZoneBeginN("G:PlayerChanged:" .. g.ghInfo.name)
		g:PlayerChanged(playerID)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:PlayerAdded(playerID)
	for _, g in ipairs(self.PlayerAddedList) do
		g:PlayerAdded(playerID)
	end
	return
end

function gadgetHandler:PlayerRemoved(playerID, reason)
	for _, g in ipairs(self.PlayerRemovedList) do
		g:PlayerRemoved(playerID, reason)
	end
	return
end

--------------------------------------------------------------------------------
--
--  AllowCommand subscription
--

local CMD_ANY = CMD.ANY
local CMD_NIL = CMD.NIL
local CMD_BUILD = CMD.BUILD
local allowCommandList = {[CMD_ANY] = {}}

function gadgetHandler:ReorderAllowCommands(gadget, f)
	if not gadget.AllowCommand then return true end
	for _, list in pairs(allowCommandList) do
		f(list, true, gadget)
	end
end

function gadgetHandler:HasAllowCommands(gadget)
	for _, list in pairs(allowCommandList) do
		for _, g in ipairs(list) do
			if g == gadget then
				return true
			end
		end
	end
end

function gadgetHandler:DeregisterAllowCommands(gadget)
	for _, list in pairs(allowCommandList) do
		ArrayRemove(list, gadget)
	end
end

function gadgetHandler:RegisterAllowCommand(gadget, cmdID)
	-- cmdID accepts CMD.ANY and CMD.NIL in addition to usual cmdIDs
	-- CMD.ANY subscribes to any command
	Spring.Log('AllowCommand', LOG.INFO, "<" .. gadget.ghInfo.basename .. "> Register "..tostring(cmdID))
	if cmdID == nil then
		-- use CMD.NIL instead
		Spring.Log('AllowCommand', LOG.ERROR, "<" .. gadget.ghInfo.basename .. "> Invalid cmdID "..tostring(cmdID))
		return
	end
	if not gadget.AllowCommand then
		Spring.Log('AllowCommand', LOG.ERROR, "<" .. gadget.ghInfo.basename .. "> No callin method")
		return
	end
	local cmdList = allowCommandList[cmdID]
	-- create list if needed
	if not cmdList then
		cmdList = {}
		allowCommandList[cmdID] = cmdList
		-- on a new list, register all known CMD.ANY commands
		if cmdID ~= CMD_ANY then
			for _, g in ipairs(allowCommandList[CMD_ANY]) do
				ArrayInsert(cmdList, true, g)
			end
		end
	end
	-- insert into the list
	ArrayInsert(cmdList, true, gadget)
	-- if it's a CMD.ANY registration, insert into all lists
	if cmdID == CMD_ANY then
		for _, list in pairs(allowCommandList) do
			ArrayInsert(list, true, gadget)
		end
	end
end

--------------------------------------------------------------------------------
--
--  LuaRules Game call-ins
--

function gadgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.MetaUnitAddedList) do
		g:MetaUnitAdded(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.MetaUnitRemovedList) do
		g:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:DrawUnit(unitID, drawMode)
	for _, g in ipairs(self.DrawUnitList) do
		if g:DrawUnit(unitID, drawMode) then
			return true
		end
	end
	return false
end

function gadgetHandler:DrawFeature(featureID, drawMode)
	for _, g in ipairs(self.DrawFeatureList) do
		if g:DrawFeature(featureID, drawMode) then
			return true
		end
	end
	return false
end

function gadgetHandler:DrawShield(unitID, weaponID, drawMode)
	for _, g in ipairs(self.DrawShieldList) do
		if g:DrawShield(unitID, weaponID, drawMode) then
			return true
		end
	end
	return false
end

function gadgetHandler:DrawProjectile(projectileID, drawMode)
	for _, g in ipairs(self.DrawProjectileList) do
		if g:DrawProjectile(projectileID, drawMode) then
			return true
		end
	end
	return false
end

function gadgetHandler:RecvSkirmishAIMessage(aiTeam, dataStr)
	for _, g in ipairs(self.RecvSkirmishAIMessageList) do
		local dataRet = g:RecvSkirmishAIMessage(aiTeam, dataStr)
		if dataRet then
			return dataRet
		end
	end
end

function gadgetHandler:CommandFallback(unitID, unitDefID, unitTeam,
									   cmdID, cmdParams, cmdOptions, cmdTag)
	for _, g in ipairs(self.CommandFallbackList) do
		local used, remove = g:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
		if used then
			return remove
		end
	end
	return true  -- remove the command
end

function gadgetHandler:AllowCommand(unitID, unitDefID, unitTeam,
									cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	local cmdKey = cmdID or CMD_NIL
	if not allowCommandList[cmdKey] then
		if type(cmdKey) == "number" and cmdKey < 0 then
			cmdKey = CMD_BUILD
		else
			cmdKey = CMD_ANY
		end
	end

	tracy.ZoneBeginN("G:AllowCommand")
	for _, g in ipairs(allowCommandList[cmdKey]) do
		--tracy.ZoneBeginN("G:AllowCommand:"..g.ghInfo.name)
		if not g:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua) then
			--tracy.ZoneEnd()
			tracy.ZoneEnd()
			return false
		end
		--tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return true
end

function gadgetHandler:AllowStartPosition(playerID, teamID, readyState, cx, cy, cz, rx, ry, rz)
	for _, g in ipairs(self.AllowStartPositionList) do
		if not g:AllowStartPosition(playerID, teamID, readyState, cx, cy, cz, rx, ry, rz) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing)
	for _, g in ipairs(self.AllowUnitCreationList) do
		if not g:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam)
	for _, g in ipairs(self.AllowUnitTransportList) do
		if not g:AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowUnitTransportLoad(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, loadX, loadY, loadZ)
	for _, g in ipairs(self.AllowUnitTransportLoadList) do
		if not g:AllowUnitTransportLoad(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, loadX, loadY, loadZ) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowUnitTransportUnload(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, unloadPosX, unloadPosY, unloadPosZ)
	for _, g in r_ipairs(self.AllowUnitTransportUnloadList) do
		if not g:AllowUnitTransportUnload(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, unloadPosX, unloadPosY, unloadPosZ) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowUnitTransfer(unitID, unitDefID,
										 oldTeam, newTeam, capture)
	for _, g in ipairs(self.AllowUnitTransferList) do
		if not g:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowUnitBuildStep(builderID, builderTeam,
										  unitID, unitDefID, part)

	tracy.ZoneBeginN("G:AllowUnitBuildStep")
	for _, g in ipairs(self.AllowUnitBuildStepList) do
		if not g:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part) then
			tracy.ZoneEnd()
			return false
		end
	end
	tracy.ZoneEnd()
	return true
end

function gadgetHandler:AllowUnitCaptureStep(builderID, builderTeam,
										  unitID, unitDefID, part)
	for _, g in ipairs(self.AllowUnitCaptureStepList) do
		if not g:AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowUnitCloak(unitID, enemyID)
	for _, g in ipairs(self.AllowUnitCloakList) do
		if not g:AllowUnitCloak(unitID, enemyID) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowUnitDecloak(unitID, objectID, weaponID)
	for _, g in ipairs(self.AllowUnitDecloakList) do
		if not g:AllowUnitDecloak(unitID, objectID, weaponID) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowFeatureBuildStep(builderID, builderTeam,
											 featureID, featureDefID, part)
	for _, g in ipairs(self.AllowFeatureBuildStepList) do
		if not g:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowFeatureCreation(featureDefID, teamID, x, y, z)
	for _, g in ipairs(self.AllowFeatureCreationList) do
		if not g:AllowFeatureCreation(featureDefID, teamID, x, y, z) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowResourceLevel(teamID, res, level)
	for _, g in ipairs(self.AllowResourceLevelList) do
		if not g:AllowResourceLevel(teamID, res, level) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowResourceTransfer(oldTeamID, newTeamID, res, amount)
	for _, g in ipairs(self.AllowResourceTransferList) do
		if not g:AllowResourceTransfer(oldTeamID, newTeamID, res, amount) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowDirectUnitControl(unitID, unitDefID, unitTeam,
											  playerID)
	for _, g in ipairs(self.AllowDirectUnitControlList) do
		if not g:AllowDirectUnitControl(unitID, unitDefID, unitTeam, playerID) then
			return false
		end
	end
	return true
end

function gadgetHandler:AllowBuilderHoldFire(unitID, unitDefID, action)
	for _, g in ipairs(self.AllowBuilderHoldFireList) do
		if not g:AllowBuilderHoldFire(unitID, unitDefID, action) then
			return false
		end
	end
	return true
end

function gadgetHandler:MoveCtrlNotify(unitID, unitDefID, unitTeam, data)
	local state = false
	for _, g in ipairs(self.MoveCtrlNotifyList) do
		if g:MoveCtrlNotify(unitID, unitDefID, unitTeam, data) then
			state = true
		end
	end
	return state
end

function gadgetHandler:TerraformComplete(unitID, unitDefID, unitTeam,
										 buildUnitID, buildUnitDefID, buildUnitTeam)
	for _, g in ipairs(self.TerraformCompleteList) do
		local stop = g:TerraformComplete(unitID, unitDefID, unitTeam, buildUnitID, buildUnitDefID, buildUnitTeam)
		if stop then
			return true
		end
	end
	return false
end

function gadgetHandler:AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID)
local ignore = true
for _, g in ipairs(self.AllowWeaponTargetCheckList) do
	local allowCheck, ignoreCheck = g:AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID)
	if not ignoreCheck then
		ignore = false
		if not allowCheck then
			return 0
		end
	end
end

return ((ignore and -1) or 1)
end


function gadgetHandler:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	local allowed = true
	local priority = 1.0

	for _, g in ipairs(self.AllowWeaponTargetList) do
		local targetAllowed, targetPriority = g:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)

		if not targetAllowed then
			allowed = false;
			break
		end
		if targetPriority > priority then
			priority = targetPriority
		end
	end

	return allowed, priority
end

function gadgetHandler:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponNum, interceptorTargetID)
	for _, g in ipairs(self.AllowWeaponInterceptTargetList) do
		if not g:AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponNum, interceptorTargetID) then
			return false
		end
	end

	return true
end


--------------------------------------------------------------------------------
--
--  Unit call-ins
--

function gadgetHandler:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	tracy.ZoneBeginN("G:UnitCreated")
	gadgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)

	for _, g in ipairs(self.UnitCreatedList) do
		g:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:UnitFinished(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("G:UnitFinished")
	for _, g in ipairs(self.UnitFinishedList) do
		g:UnitFinished(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:UnitFromFactory(unitID, unitDefID, unitTeam,
									   factID, factDefID, userOrders)
	for _, g in ipairs(self.UnitFromFactoryList) do
		g:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	end
	return
end

function gadgetHandler:UnitReverseBuilt(unitID, unitDefID, unitTeam)
	for _, g in r_ipairs(self.UnitReverseBuiltList) do
		g:UnitReverseBuilt(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:UnitStunned(unitID, unitDefID, unitTeam, stunned)
	for _,g in r_ipairs(self.UnitStunnedList) do
		g:UnitStunned(unitID, unitDefID, unitTeam, stunned)
	end
	return
end

function gadgetHandler:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	tracy.ZoneBeginN("G:UnitDestroyed")
	gadgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)

	for _, g in ipairs(self.UnitDestroyedList) do
		g:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	for _, g in r_ipairs(self.RenderUnitDestroyedList) do
		g:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:UnitExperience(unitID, unitDefID, unitTeam,
									  experience, oldExperience)
	for _, g in ipairs(self.UnitExperienceList) do
		g:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	end
	return
end

function gadgetHandler:UnitIdle(unitID, unitDefID, unitTeam)
	tracy.ZoneBeginN("G:UnitIdle")
	for _, g in ipairs(self.UnitIdleList) do
		g:UnitIdle(unitID, unitDefID, unitTeam)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	for _, g in ipairs(self.UnitCmdDoneList) do
		g:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	end
	return
end

function gadgetHandler:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	tracy.ZoneBeginN("G:UnitPreDamaged")
	local retDamage = damage
	local retImpulse = 1.0

	-- To future devs
	-- yes, multiple gadgets can affect damage and impulse
	-- and that ordering *does* matter
	-- so if your new UnitPreDamaged is behaving weird
	-- check every other gadget that may be handing damage or impulse
	-- and check the layering and ordering of the gadgets
	for _, g in ipairs(self.UnitPreDamagedList) do
		local dmg, imp = g:UnitPreDamaged(
			unitID, unitDefID, unitTeam,
			retDamage, paralyzer,
			weaponDefID, projectileID,
			attackerID, attackerDefID, attackerTeam)

		if dmg ~= nil then
			retDamage = dmg
		end
		if imp ~= nil then
			retImpulse = retImpulse*imp
		end
	end

	tracy.ZoneEnd()
	return retDamage, retImpulse
end

function gadgetHandler:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	tracy.ZoneBeginN("G:UnitDamaged")
	for _, g in ipairs(self.UnitDamagedList) do
		g:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	end
	tracy.ZoneEnd()
end

function gadgetHandler:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	gadgetHandler:MetaUnitRemoved(unitID, unitDefID, unitTeam)

	for _, g in ipairs(self.UnitTakenList) do
		g:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	end
	return
end

function gadgetHandler:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	gadgetHandler:MetaUnitAdded(unitID, unitDefID, unitTeam)

	for _, g in ipairs(self.UnitGivenList) do
		g:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	end
	return
end

function gadgetHandler:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	tracy.ZoneBeginN("G:UnitCommand")
	for _, g in ipairs(self.UnitCommandList) do
		g:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:UnitEnteredWater(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.UnitEnteredWaterList) do
		g:UnitEnteredWater(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:UnitLeftWater(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.UnitLeftWaterList) do
		g:UnitLeftWater(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:UnitEnteredAir(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.UnitEnteredAirList) do
		g:UnitEnteredAir(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:UnitLeftAir(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.UnitLeftAirList) do
		g:UnitLeftAir(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
	for _, g in ipairs(self.UnitEnteredRadarList) do
		g:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
	end
	return
end

function gadgetHandler:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	tracy.ZoneBeginN("G:UnitEnteredLos")
	for _, g in ipairs(self.UnitEnteredLosList) do
		g:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
	for _, g in ipairs(self.UnitLeftRadarList) do
		g:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
	end
	return
end

function gadgetHandler:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	tracy.ZoneBeginN("G:UnitLeftLos")
	for _, g in ipairs(self.UnitLeftLosList) do
		g:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	for _, g in ipairs(self.UnitSeismicPingList) do
		g:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	end
	return
end

function gadgetHandler:UnitLoaded(unitID, unitDefID, unitTeam,  transportID, transportTeam)
	for _, g in ipairs(self.UnitLoadedList) do
		g:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	end
	return
end

function gadgetHandler:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	for _, g in ipairs(self.UnitUnloadedList) do
		g:UnitUnloaded(unitID, unitDefID, unitTeam,
			transportID, transportTeam)
	end
	return
end

function gadgetHandler:UnitCloaked(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.UnitCloakedList) do
		g:UnitCloaked(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:UnitDecloaked(unitID, unitDefID, unitTeam)
	for _, g in ipairs(self.UnitDecloakedList) do
		g:UnitDecloaked(unitID, unitDefID, unitTeam)
	end
	return
end

function gadgetHandler:UnitUnitCollision(colliderID, collideeID)
	for _, g in ipairs(self.UnitUnitCollisionList) do
		g:UnitUnitCollision(colliderID, collideeID)
	end
end

function gadgetHandler:UnitFeatureCollision(colliderID, collideeID)
	for _, g in r_ipairs(self.UnitFeatureCollisionList) do
		if g:UnitFeatureCollision(colliderID, collideeID) then
			return true
		end
	end
	return false
end

function gadgetHandler:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	for _, g in ipairs(self.StockpileChangedList) do
		g:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	end
	return
end

--------------------------------------------------------------------------------
--
--  Feature call-ins
--

function gadgetHandler:FeatureCreated(featureID, allyTeam)
	tracy.ZoneBeginN("G:FeatureCreated")
	for _, g in ipairs(self.FeatureCreatedList) do
		g:FeatureCreated(featureID, allyTeam)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:FeatureDestroyed(featureID, allyTeam)
	tracy.ZoneBeginN("G:FeatureDestroyed")
	for _, g in ipairs(self.FeatureDestroyedList) do
		g:FeatureDestroyed(featureID, allyTeam)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:FeatureDamaged(
	featureID,
	featureDefID,
	featureTeam,
	damage,
	weaponDefID,
	projectileID,
	attackerID,
	attackerDefID,
	attackerTeam
)
	for _, g in ipairs(self.FeatureDamagedList) do
		g:FeatureDamaged(featureID, featureDefID, featureTeam,
			damage, weaponDefID, projectileID,
			attackerID, attackerDefID, attackerTeam)
	end
end

function gadgetHandler:FeaturePreDamaged(
	featureID,
	featureDefID,
	featureTeam,
	damage,
	weaponDefID,
	projectileID,
	attackerID,
	attackerDefID,
	attackerTeam
)
	local retDamage = damage
	local retImpulse = 1.0

	for _, g in ipairs(self.FeaturePreDamagedList) do
		local dmg, imp = g:FeaturePreDamaged(
			featureID, featureDefID, featureTeam,
			retDamage,
			weaponDefID, projectileID,
			attackerID, attackerDefID, attackerTeam)

		if dmg ~= nil then
			retDamage = dmg
		end
		if imp ~= nil then
			retImpulse = imp
		end
	end

	return retDamage, retImpulse
end


--------------------------------------------------------------------------------
--
--  Projectile call-ins
--

function gadgetHandler:ProjectileCreated(proID, proOwnerID, proWeaponDefID)
	tracy.ZoneBeginN("G:ProjectileCreated")
	for _, g in ipairs(self.ProjectileCreatedList) do
		g:ProjectileCreated(proID, proOwnerID, proWeaponDefID)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:ProjectileDestroyed(proID, proOwnerID, proWeaponDefID)
	tracy.ZoneBeginN("G:ProjectileDestroyed")
	for _, g in ipairs(self.ProjectileDestroyedList) do
		g:ProjectileDestroyed(proID, proOwnerID, proWeaponDefID)
	end
	tracy.ZoneEnd()
	return
end


--------------------------------------------------------------------------------
--
--  Shield call-ins
--
--ShieldPreDamaged(proID, proOwnerID, shieldEmitterWeaponNum, shieldCarrierUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
function gadgetHandler:ShieldPreDamaged(proID, proOwnerID, shieldEmitterWeaponNum, shieldCarrierUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)

	for _, g in ipairs(self.ShieldPreDamagedList) do
		-- first gadget to handle this consumes the event
		if g:ShieldPreDamaged(proID, proOwnerID, shieldEmitterWeaponNum, shieldCarrierUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ) then
			return true
		end
	end

	return false
end


--------------------------------------------------------------------------------
--
--  Misc call-ins
--

function gadgetHandler:Explosion(weaponID, px, py, pz, ownerID, projectileID)
	-- "noGfx = noGfx or ..." short-circuits, so equivalent to this
	for _, g in r_ipairs(self.ExplosionList) do
		if g:Explosion(weaponID, px, py, pz, ownerID, projectileID) then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------
--
--  Draw call-ins
--

function gadgetHandler:SunChanged()
	for _, g in ipairs(self.SunChangedList) do
		g:SunChanged()
	end
	return
end

function gadgetHandler:Update()
	local deltaTime = Spring.GetLastUpdateSeconds()
	tracy.ZoneBeginN("G:Update")
	for _, g in ipairs(self.UpdateList) do
		tracy.ZoneBeginN("G:Update:" .. g.ghInfo.name)
		g:Update(deltaTime)
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:DefaultCommand(type, id, cmd)
	for _, g in ipairs(self.DefaultCommandList) do
		local id = g:DefaultCommand(type, id, cmd)
		if id then
			return id
		end
	end
	return
end

function gadgetHandler:ActiveCommandChanged(id, cmdType)
	for _, g in ipairs(self.ActiveCommandChangedList) do
		g:ActiveCommandChanged(id, cmdType)
	end
end

function gadgetHandler:CameraRotationChanged(rotx, roty, rotz)
	for _, g in r_ipairs(self.CameraRotationChangedList) do
		g:CameraRotationChanged(rotx, roty, rotz)
	end
end

function gadgetHandler:CameraPositionChanged(posx, posy, posz)
	for _, g in r_ipairs(self.CameraPositionChangedList) do
		g:CameraPositionChanged(posx, posy, posz)
	end
end

function gadgetHandler:CommandNotify(id, params, options)
	for _, g in ipairs(self.CommandNotifyList) do
		if g:CommandNotify(id, params, options) then
			return true
		end
	end
	return false
end

function gadgetHandler:DrawGenesis()
	tracy.ZoneBeginN("G:DrawGenesis")
	for _, g in ipairs(self.DrawGenesisList) do
		g:DrawGenesis()
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:DrawWorld()
	tracy.ZoneBeginN("G:DrawWorld")
	for _, g in ipairs(self.DrawWorldList) do
		tracy.ZoneBeginN("G:DrawWorld:" .. g.ghInfo.name)
		g:DrawWorld()
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:DrawWorldPreUnit()
	tracy.ZoneBeginN("G:DrawWorldPreUnit")
	for _, g in ipairs(self.DrawWorldPreUnitList) do
		tracy.ZoneBeginN("G:DrawWorldPreUnit:" .. g.ghInfo.name)
		g:DrawWorldPreUnit()
		tracy.ZoneEnd()
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:DrawOpaqueUnitsLua(deferredPass, drawReflection, drawRefraction)
	for _, g in ipairs(self.DrawOpaqueUnitsLuaList) do
		g:DrawOpaqueUnitsLua(deferredPass, drawReflection, drawRefraction)
	end
	return
end

function gadgetHandler:DrawOpaqueFeaturesLua(deferredPass, drawReflection, drawRefraction)
	for _, g in ipairs(self.DrawOpaqueFeaturesLuaList) do
		g:DrawOpaqueFeaturesLua(deferredPass, drawReflection, drawRefraction)
	end
	return
end

function gadgetHandler:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	for _, g in ipairs(self.DrawAlphaUnitsLuaList) do
		g:DrawAlphaUnitsLua(drawReflection, drawRefraction)
	end
	return
end

function gadgetHandler:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	for _, g in ipairs(self.DrawAlphaFeaturesLuaList) do
		g:DrawAlphaFeaturesLua(drawReflection, drawRefraction)
	end
	return
end

function gadgetHandler:DrawShadowUnitsLua()
	for _, g in ipairs(self.DrawShadowUnitsLuaList) do
		g:DrawShadowUnitsLua()
	end
	return
end

function gadgetHandler:DrawShadowFeaturesLua()
	for _, g in ipairs(self.DrawShadowFeaturesLuaList) do
		g:DrawShadowFeaturesLua()
	end
	return
end


function gadgetHandler:DrawWorldShadow()
	for _, g in ipairs(self.DrawWorldShadowList) do
		g:DrawWorldShadow()
	end
	return
end

function gadgetHandler:DrawWorldReflection()
	for _, g in ipairs(self.DrawWorldReflectionList) do
		g:DrawWorldReflection()
	end
	return
end

function gadgetHandler:DrawWorldRefraction()
	for _, g in ipairs(self.DrawWorldRefractionList) do
		g:DrawWorldRefraction()
	end
	return
end

function gadgetHandler:DrawScreenEffects(vsx, vsy)
	tracy.ZoneBeginN("G:DrawScreenEffects")
	for _, g in ipairs(self.DrawScreenEffectsList) do
		g:DrawScreenEffects(vsx, vsy)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:DrawScreenPost()
	tracy.ZoneBeginN("G:DrawScreenPost")
	for _, g in ipairs(self.DrawScreenPostList) do
		g:DrawScreenPost(vsx, vsy)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:DrawScreen(vsx, vsy)
	tracy.ZoneBeginN("G:DrawScreen")
	for _, g in ipairs(self.DrawScreenList) do
		g:DrawScreen(vsx, vsy)
	end
	tracy.ZoneEnd()
	return
end

function gadgetHandler:DrawInMiniMap(mmsx, mmsy)
	tracy.ZoneBeginN("G:DrawInMiniMap")
	for _, g in ipairs(self.DrawInMiniMapList) do
		g:DrawInMiniMap(mmsx, mmsy)
	end
	tracy.ZoneEnd()
	return
end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadgetHandler:KeyPress(key, mods, isRepeat, label, unicode)
	for _, g in ipairs(self.KeyPressList) do
		if g:KeyPress(key, mods, isRepeat, label, unicode) then
			return true
		end
	end
	return false
end

function gadgetHandler:KeyRelease(key, mods, label, unicode)
	for _, g in ipairs(self.KeyReleaseList) do
		if g:KeyRelease(key, mods, label, unicode) then
			return true
		end
	end
	return false
end

function gadgetHandler:MousePress(x, y, button)
	local mo = self.mouseOwner
	if mo then
		mo:MousePress(x, y, button)
		return true  --  already have an active press
	end
	for _, g in ipairs(self.MousePressList) do
		if g:MousePress(x, y, button) then
			self.mouseOwner = g
			return true
		end
	end
	return false
end

function gadgetHandler:MouseMove(x, y, dx, dy, button)
	tracy.ZoneBeginN("G:MouseMove")
	local mo = self.mouseOwner
	if mo and mo.MouseMove then
		tracy.ZoneEnd()
		return mo:MouseMove(x, y, dx, dy, button)
	end
	tracy.ZoneEnd()
end

function gadgetHandler:MouseRelease(x, y, button)
	tracy.ZoneBeginN("G:MouseRelease")
	local mo = self.mouseOwner
	local mx, my, lmb, mmb, rmb = Spring.GetMouseState()
	if not (lmb or mmb or rmb) then
		self.mouseOwner = nil
	end
	if mo and mo.MouseRelease then
		tracy.ZoneEnd()
		return mo:MouseRelease(x, y, button)
	end
	tracy.ZoneEnd()
	return -1
end

function gadgetHandler:MouseWheel(up, value)
	for _, g in ipairs(self.MouseWheelList) do
		if g:MouseWheel(up, value) then
			return true
		end
	end
	return false
end

function gadgetHandler:IsAbove(x, y)
	for _, g in ipairs(self.IsAboveList) do
		if g:IsAbove(x, y) then
			return true
		end
	end
	return false
end

function gadgetHandler:GetTooltip(x, y)
	for _, g in ipairs(self.GetTooltipList) do
		if g:IsAbove(x, y) then
			local tip = g:GetTooltip(x, y)
			if string.len(tip) > 0 then
				return tip
			end
		end
	end
	return ''
end

function gadgetHandler:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	for _, g in r_ipairs(self.UnsyncedHeightMapUpdateList) do
		g:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	end
	return
end

function gadgetHandler:GameProgress(serverFrameNum)
	for _, g in ipairs(self.GameProgressList) do
		g:GameProgress(serverFrameNum)
	end
	return
end

function gadgetHandler:MapDrawCmd(playerID, cmdType, px, py, pz, labelText)
	for _, g in ipairs(self.MapDrawCmdList) do
		if g:MapDrawCmd(playerID, cmdType, px, py, pz, labelText) then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadgetHandler:Save(zip)
	for _, g in ipairs(self.SaveList) do
		g:Save(zip)
	end
	return
end

function gadgetHandler:Load(zip)
	for _, g in ipairs(self.LoadList) do
		g:Load(zip)
	end
	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadgetHandler:FontsChanged()
	tracy.ZoneBeginN("FontsChanged")
	for _, w in r_ipairs(self.FontsChangedList) do
		w:FontsChanged()
	end
	tracy.ZoneEnd()
	return
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

gadgetHandler:Initialize()
