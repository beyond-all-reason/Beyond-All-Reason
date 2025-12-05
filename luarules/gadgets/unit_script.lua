-- Author: Tobi Vollebregt

--[[
Please, think twice before editing this file. Compared to most gadgets, there
are some complex things going on.  A good understanding of Lua's coroutines is
required to make nontrivial modifications to this file.

In other words, HERE BE DRAGONS =)

Known issues:
- {Query,AimFrom,Aim,Fire}{Primary,Secondary,Tertiary} are not handled.
  (use {Query,AimFrom,Aim,Fire}{Weapon1,Weapon2,Weapon3} instead!)
- Errors in callins which aren't wrapped in a thread do not show a traceback.
- Which callins are wrapped in a thread and which aren't is a bit arbitrary.
- MoveFinished, TurnFinished and Destroy are overwritten by the framework.
- There is no way to reload the script of a single unit. (use /luarules reload)
- Error checking is lacking.  (In particular for incorrect unitIDs.)

To do:
- Test real world performance (compared to COB)
]]--

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Lua unit script framework",
		desc      = "Manages Lua unit scripts",
		author    = "Tobi Vollebregt",
		date      = "2 September 2009",
		license   = "GPL v2",
		layer     = 0,
		enabled   = true --  loaded by default?
	}
end


if (not gadgetHandler:IsSyncedCode()) then
	return false
end


-- This lists all callins which may be wrapped in a coroutine (thread).
-- The ones which should not be thread-wrapped are commented out.
-- Create, Killed, AimWeapon and AimShield callins are always wrapped.
local thread_wrap = {
	--"StartMoving",
	--"StopMoving",
	--"Activate",
	--"Deactivate",
	--"WindChanged",
	--"ExtractionRateChanged",
	"RockUnit",
	--"HitByWeapon",
	--"MoveRate",
	--"setSFXoccupy",
	--"QueryLandingPad",
	"Falling",
	"Landed",
	"BeginTransport",
	--"QueryTransport",
	"TransportPickup",
	"StartUnload",
	"EndTransport",
	"TransportDrop",
	"StartBuilding",
	"StopBuilding",
	--"QueryNanoPiece",
	--"QueryBuildInfo",
	--"QueryWeapon",
	--"AimFromWeapon",
	"FireWeapon",
	--"EndBurst",
	--"Shot",
	--"BlockShot",
	--"TargetWeight",
}

local weapon_funcs = {
	"QueryWeapon",
	"AimFromWeapon",
	"AimWeapon",
	"AimShield",
	"FireWeapon",
	"Shot",
	"EndBurst",
	"BlockShot",
	"TargetWeight",
}

local default_return_values = {
	QueryWeapon = -1,
	AimFromWeapon = -1,
	AimWeapon = false,
	AimShield = false,
	BlockShot = false,
	TargetWeight = 1,
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Localize often used methods.
local pairs = pairs
local ipairs = ipairs
local table_remove = table.remove
local type = type
local setmetatable = setmetatable
local setfenv = setfenv
local unpack = unpack
local error = error
local pcall = pcall
local loadstring = loadstring
local tostring = tostring

local co_create = coroutine.create
local co_resume = coroutine.resume
local co_yield = coroutine.yield
local co_running = coroutine.running

local bit_and = math.bit_and
local floor = math.floor

local sp_GetGameFrame = Spring.GetGameFrame
local sp_GetUnitWeaponState = Spring.GetUnitWeaponState
local sp_SetUnitWeaponState = Spring.SetUnitWeaponState
local sp_SetUnitShieldState = Spring.SetUnitShieldState
local sp_GetUnitDefID = Spring.GetUnitDefID
local sp_GetAllUnits = Spring.GetAllUnits
local sp_GetUnitPieceMap = Spring.GetUnitPieceMap

-- Keep local reference to engine's CallAsUnit/WaitForMove/WaitForTurn,
-- as we overwrite them with (safer) framework version later on.
local sp_CallAsUnit  = Spring.UnitScript.CallAsUnit
local sp_WaitForMove = Spring.UnitScript.WaitForMove
local sp_WaitForTurn = Spring.UnitScript.WaitForTurn
local sp_WaitForScale = Spring.UnitScript.WaitForScale
local sp_SetPieceVisibility = Spring.UnitScript.SetPieceVisibility
local sp_SetDeathScriptFinished = Spring.UnitScript.SetDeathScriptFinished

local LUA_WEAPON_MIN_INDEX = 1
local LUA_WEAPON_MAX_INDEX = LUA_WEAPON_MIN_INDEX + 31

local UNITSCRIPT_DIR = (UNITSCRIPT_DIR or "scripts/"):lower()
local VFSMODE = VFS.ZIP_ONLY
if (Spring.IsDevLuaEnabled()) then
	VFSMODE = VFS.RAW_ONLY
end

-- needed here too, and gadget handler doesn't expose it
VFS.Include('LuaGadgets/system.lua', nil, VFSMODE)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--[[
Data structure to administrate the threads of each managed unit.
We store a set of all threads for each unit, and in two separate tables
the threads which are waiting for a turn or move animation to finish.

The 'thread' stored in waitingForMove/waitingForTurn/waitingForScale/sleepers is the table
wrapping the actual coroutine object.  This way the signal_mask etc. is
available too.

The threads table is a weak table.  This saves us from having to manually clean
up dead threads: any thread which is not sleeping or waiting is in none of
(sleepers,waitingForMove,waitingForTurn,waitingForScale) => it is only in the threads table
=> garbage collector will harvest it because the table is weak.

Beware the threads are indexed by thread (coroutine), so careless
iteration of threads WILL cause desync!

Format: {
	[unitID] = {
		env = {},  -- the unit's environment table
		waitingForMove = { [piece*3+axis] = thread, ... },
		waitingForTurn = { [piece*3+axis] = thread, ... },
		waitingForScale = { [piece] = thread, ... },
		threads = {
			[thread] = {
				thread = thread,      -- the coroutine object
				signal_mask = object, -- see Signal/SetSignalMask
				unitID = number,      -- 'owner' of the thread
				onerror = function,   -- called after thread died due to an error
			},
			...
		},
	},
}
--]]
local units = {}


-- this keeps track of the unit that is active (ie.
-- running a script) at the time a callin triggers
--
-- the _current_ active unit (ID) is always at the
-- top of the stack (index #activeUnitStack)
local activeUnitStack = {}

local function PushActiveUnitID(unitID)
	local n = #activeUnitStack + 1
	activeUnitStack[n] = unitID
end

local function PopActiveUnitID()
	activeUnitStack[#activeUnitStack] = nil
end

local function GetActiveUnit()
	return units[activeUnitStack[#activeUnitStack]]
end


--[[
This is the bed, it stores all the sleeping threads,
indexed by the frame in which they need to be woken up.

Format: {
	[framenum] = { [1] = thread1, [2] = thread2, ... },
}

(inner tables are in order the calls to Sleep were made)
--]]
local sleepers = {}
local section = 'unit_script.lua'

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Helper for Destroy and Signal.
-- NOTE:
--   Must not change the relative order of all other elements!
--   Also must not break the #-operator, so removal must leave
--   no holes --> uses table.remove() instead of tab[i] = nil.
local function RemoveTableElement(tab, item)
	local n = #tab
	for i = 1,n do
		if (tab[i] == item) then
			table_remove(tab, i)
			return
		end
	end
end

-- This is put in every script to clean up if the script gets destroyed.
local function Destroy()
	local activeUnit = GetActiveUnit()

	if (activeUnit ~= nil) then
		for _,thread in pairs(activeUnit.threads) do
			if thread.container then
				RemoveTableElement(thread.container, thread)
			end
		end
		units[activeUnit.unitID] = nil
	end
end

-- Pcalls thread.onerror, if present.
local function RunOnError(thread)
	local fun = thread.onerror
	if fun then
		local good, err = pcall(fun, err)
		if (not good) then
			Spring.Log(section, LOG.ERROR, "error in error handler: " .. tostring(err))
		end
	end
end

-- Helper for AnimFinished, StartThread and gadget:GameFrame.
-- Resumes a sleeping or waiting thread; displays any errors.
local function WakeUp(thread, ...)
	thread.container = nil
	local co = thread.thread
	local good, err = co_resume(co, ...)
	if (not good) then
		Spring.Log(section, LOG.ERROR, err)
		Spring.Log(section, LOG.ERROR, debug.traceback(co))
		RunOnError(thread)
	end
end

-- Helper for MoveFinished and TurnFinished
local function AnimFinished(waitingForAnim, piece, axis)
	local index = axis and (piece * 3 + axis) or piece
	local wthreads = waitingForAnim[index]
	local wthread = nil

	if wthreads then
		waitingForAnim[index] = {}

		while (#wthreads > 0) do	
			wthread = wthreads[#wthreads]
			wthreads[#wthreads] = nil

			WakeUp(wthread)
		end
	end
end

-- MoveFinished and TurnFinished are put in every script by the framework.
-- They resume the threads which were waiting for the move/turn.
local function MoveFinished(piece, axis)
	local activeUnit = units[activeUnitStack[#activeUnitStack]]
	return AnimFinished(activeUnit.waitingForMove, piece, axis)
end

local function TurnFinished(piece, axis)
	local activeUnit = units[activeUnitStack[#activeUnitStack]]
	return AnimFinished(activeUnit.waitingForTurn, piece, axis)
end

local function ScaleFinished(piece)
	local activeUnit = GetActiveUnit()
	local activeAnim = activeUnit.waitingForScale
	return AnimFinished(activeAnim, piece)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- overwrites engine's CallAsUnit
function Spring.UnitScript.CallAsUnit(unitID, fun, ...)
	PushActiveUnitID(unitID)
	local ret = {sp_CallAsUnit(unitID, fun, ...)}
	PopActiveUnitID()

	return unpack(ret)
end

local function CallAsUnitNoReturn(unitID, fun, ...)
	PushActiveUnitID(unitID)
	sp_CallAsUnit(unitID, fun, ...)
	PopActiveUnitID()
end

-- Helper for WaitForMove and WaitForTurn
-- Unsafe, because it does not check whether the animation to wait for actually exists.
local function WaitForAnim(threads, waitingForAnim, piece, axis)
	local index = axis and (piece * 3 + axis) or piece
	local wthreads = waitingForAnim[index]
	if (not wthreads) then
		wthreads = {}
		waitingForAnim[index] = wthreads
	end
	local thread = threads[co_running() or error("not in a thread", 2)]
	wthreads[#wthreads+1] = thread
	thread.container = wthreads
	-- yield the running thread:
	-- it will be resumed once the wait finished (in AnimFinished).
	co_yield()
end

-- overwrites engine's WaitForMove
function Spring.UnitScript.WaitForMove(piece, axis)
	if sp_WaitForMove(piece, axis) then
		local activeUnit = units[activeUnitStack[#activeUnitStack]]
		return WaitForAnim(activeUnit.threads, activeUnit.waitingForMove, piece, axis)
	end
end

-- overwrites engine's WaitForTurn
function Spring.UnitScript.WaitForTurn(piece, axis)
	if sp_WaitForTurn(piece, axis) then
		local activeUnit = units[activeUnitStack[#activeUnitStack]]
		return WaitForAnim(activeUnit.threads, activeUnit.waitingForTurn, piece, axis)
	end
end

-- overwrites engine's WaitForScale
function Spring.UnitScript.WaitForScale(piece)
	if sp_WaitForScale(piece) then
		local activeUnit = GetActiveUnit()
		return WaitForAnim(activeUnit.threads, activeUnit.waitingForScale, piece)
	end
end


function Spring.UnitScript.Sleep(milliseconds)
	local n = floor(milliseconds * 0.03030303) -- faster than division by 33
	if n <= 0 then n = 1 end
	n = n + sp_GetGameFrame()
	local zzz = sleepers[n]
	if not zzz then
		zzz = {}
		sleepers[n] = zzz
	end

	local activeUnit = units[activeUnitStack[#activeUnitStack]] or error("[Sleep] no active unit on stack?", 2)
	local activeThread = activeUnit.threads[co_running() or error("[Sleep] not in a thread?", 2)]

	local m = #zzz + 1
	zzz[m] = activeThread
	activeThread.container = zzz
	-- yield the running thread:
	-- it will be resumed in frame #n (in gadget:GameFrame).
	co_yield()
end



function Spring.UnitScript.StartThread(fun, ...)
	local activeUnit = units[activeUnitStack[#activeUnitStack]]
	local co = co_create(fun)
	-- signal_mask is inherited from current thread, if any
	local running = co_running()
	local sigmask = 0
	if running then
		local thd = activeUnit.threads[running]
		if thd then
			sigmask = thd.signal_mask
		end
	end
	local thread = {
		thread = co,
		signal_mask = sigmask,
		unitID = activeUnit.unitID,
	}

	-- add the new thread to activeUnit's registry
	activeUnit.threads[co] = thread

	-- COB doesn't start thread immediately: it only sets up stack and
	-- pushes parameters on it for first time the thread is scheduled.
	-- Here it is easier however to start thread immediately, so we don't need
	-- to remember the parameters for the first co_resume call somewhere.
	-- I think in practice the difference in behavior isn't an issue.
	return WakeUp(thread, ...)
end

local function SetOnError(fun)
	local activeUnit = units[activeUnitStack[#activeUnitStack]]
	local activeThread = activeUnit.threads[co_running()]
	if activeThread then
		activeThread.onerror = fun
	end
end

function Spring.UnitScript.SetSignalMask(mask)
	local activeUnit = units[activeUnitStack[#activeUnitStack]]
	local activeThread = activeUnit.threads[co_running() or error("[SetSignalMask] not in a thread", 2)]
	activeThread.signal_mask = mask
end

function Spring.UnitScript.Signal(mask)
	local activeUnit = units[activeUnitStack[#activeUnitStack]]

	-- beware, unsynced loop order
	-- (doesn't matter here as long as all threads get removed)
	if type(mask) == "number" then
		for _,thread in pairs(activeUnit.threads) do
			local container = thread.container
			if container then
				local signal_mask = thread.signal_mask
				if type(signal_mask) == "number" and bit_and(signal_mask, mask) ~= 0 then
					RemoveTableElement(container, thread)
				end
			end
		end
	else
		for _,thread in pairs(activeUnit.threads) do
			local container = thread.container
			if container and thread.signal_mask == mask then
				RemoveTableElement(container, thread)
			end
		end
	end
end

function Spring.UnitScript.Hide(piece)
	return sp_SetPieceVisibility(piece, false)
end

function Spring.UnitScript.Show(piece)
	return sp_SetPieceVisibility(piece, true)
end

-- may be useful to other gadgets
function Spring.UnitScript.GetScriptEnv(unitID)
	local unit = units[unitID]
	if unit then
		return unit.env
	end
	return nil
end

function Spring.UnitScript.GetLongestReloadTime(unitID)
	local longest = 0
	for i = LUA_WEAPON_MIN_INDEX, LUA_WEAPON_MAX_INDEX do
		local reloadTime = sp_GetUnitWeaponState(unitID, i, "reloadTime")
		if (not reloadTime) then break end
		if (reloadTime > longest) then longest = reloadTime end
	end
	return 1000 * longest
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local scriptHeader = VFS.LoadFile("gamedata/unit_script_header.lua", VFSMODE)

-- Newlines (and comments) are stripped to not change line numbers in stacktraces.
scriptHeader = scriptHeader:gsub("%-%-[^\r\n]*", ""):gsub("[\r\n]", " ")


--[[
Dictionary mapping script name (without path or extension) to a Lua chunk which
returns a new closure (read; instance) of this unitscript.

Format: {
	[unitID] = chunk,
}
--]]
local scripts = {}


-- Creates a new prototype environment for a unit script.
-- This environment is used as prototype for the unit script instances.
-- (To save on time copying and space for a copy for each and every unit.)
local prototypeEnv
do
	local script = {}
	for k,v in pairs(System) do
		script[k] = v
	end
	--script._G = _G  -- the global table. (Update: _G points to unit environment now)
	script.GG = GG  -- the shared table (shared with gadgets!)
	prototypeEnv = script
end


local function Basename(filename)
	return filename:match("[^\\/:]*$") or filename
end


local function LoadChunk(filename)
	local text = VFS.LoadFile(filename, VFSMODE)
	if (text == nil) then
		Spring.Log(section, LOG.ERROR, "Failed to load: " .. filename)
		return nil
	end
	local chunk, err = loadstring(scriptHeader .. text, filename)
	if (chunk == nil) then
		Spring.Log(section, LOG.ERROR, "Failed to load: " .. Basename(filename) .. "  (" .. err .. ")")
		return nil
	end
	return chunk
end


local function LoadScript(scriptName, filename)
	local chunk = LoadChunk(filename)
	scripts[scriptName] = chunk
	return chunk
end


function gadget:Initialize()
	Spring.Log(section, LOG.INFO, string.format("Loading gadget: %-18s  <%s>", ghInfo.name, ghInfo.basename))

	-- This initialization code has following properties:
	--  * all used scripts are loaded => early syntax error detection
	--  * unused scripts aren't loaded
	--  * files can be arbitrarily ordered in subdirs (like defs)
	--  * exact path doesn't need to be specified
	--  * exact path can be specified to resolve ambiguous basenames
	--  * engine default scriptName (with .cob extension) works

	-- Recursively collect files below UNITSCRIPT_DIR.
	local scriptFiles = {}
	for _,filename in ipairs(VFS.DirList(UNITSCRIPT_DIR, "*.lua", VFSMODE, true)) do
		local basename = Basename(filename)
		scriptFiles[filename] = filename  -- for exact match
		scriptFiles[basename] = filename  -- for basename match
	end

	-- Go through all UnitDefs and load scripts.
	-- Names are tested in following order:
	--  * exact match
	--  * basename match
	--  * exact match where .cob->.lua
	--  * basename match where .cob->.lua
	for i=1,#UnitDefs do
		local unitDef = UnitDefs[i]
		if (unitDef and not scripts[unitDef.scriptName]) then
			local fn  = UNITSCRIPT_DIR .. unitDef.scriptName:lower()
			local bn  = Basename(fn)
			local cfn = fn:gsub("%.cob$", "%.lua")
			local cbn = bn:gsub("%.cob$", "%.lua")
			local filename = scriptFiles[fn] or scriptFiles[bn] or
			                 scriptFiles[cfn] or scriptFiles[cbn]
			if filename then
				Spring.Log(section, LOG.INFO, "  Loading unit script: " .. filename)
				LoadScript(unitDef.scriptName, filename)
			end
		end
	end

	-- Fake UnitCreated events for existing units. (for '/luarules reload')
	local allUnits = sp_GetAllUnits()
	for i=1,#allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, sp_GetUnitDefID(unitID))
	end
end

--------------------------------------------------------------------------------

local StartThread = Spring.UnitScript.StartThread


local function Wrap_AimWeapon(unitID, callins)
	local AimWeapon = callins["AimWeapon"]
	if (not AimWeapon) then return end

	-- SetUnitShieldState wants true or false, while
	-- SetUnitWeaponState wants 1.0 or 0.0, niiice =)
	--
	-- NOTE:
	--   the LuaSynced* API functions all EXPECT 1-based arguments
	--   the LuaUnitScript::*Weapon* callins all SUPPLY 1-based arguments
	--
	--   therefore on the Lua side all weapon indices are ASSUMED to be
	--   1-based and if LuaConfig::LUA_WEAPON_BASE_INDEX is changed to 0
	--   no Lua code should need to be updated
	local function AimWeaponThread(weaponNum, heading, pitch)
		local bAimReady = AimWeapon(weaponNum, heading, pitch) or false
		local fAimReady = (bAimReady and 1.0) or 0.0

		return sp_SetUnitWeaponState(unitID, weaponNum, "aimReady", fAimReady)
	end

	callins["AimWeapon"] = function(weaponNum, heading, pitch)
		return StartThread(AimWeaponThread, weaponNum, heading, pitch)
	end
end


local function Wrap_AimShield(unitID, callins)
	local AimShield = callins["AimShield"]
	if (not AimShield) then return end

	-- SetUnitShieldState wants true or false, while
	-- SetUnitWeaponState wants 1 or 0, niiice =)
	local function AimShieldThread(weaponNum)
		local enabled = AimShield(weaponNum) and true or false

		return sp_SetUnitShieldState(unitID, weaponNum, enabled)
	end

	callins["AimShield"] = function(weaponNum)
		return StartThread(AimShieldThread, weaponNum)
	end
end


local function Wrap_Killed(unitID, callins)
	local Killed = callins["Killed"]
	if (not Killed) then return end

	local function KilledThread(recentDamage, maxHealth)
		-- It is *very* important the sp_SetDeathScriptFinished is executed, even on error.
		SetOnError(sp_SetDeathScriptFinished)
		local wreckLevel = Killed(recentDamage, maxHealth)
		sp_SetDeathScriptFinished(wreckLevel)
	end

	callins["Killed"] = function(recentDamage, maxHealth)
		StartThread(KilledThread, recentDamage, maxHealth)
		return -- no return value signals Spring to wait for SetDeathScriptFinished call.
	end
end


local function Wrap(callins, name)
	local fun = callins[name]
	if (not fun) then return end

	callins[name] = function(...)
		return StartThread(fun, ...)
	end
end

--------------------------------------------------------------------------------

--[[
Storage for MemoizedInclude.
Format: { [filename] = chunk }
--]]
local include_cache = {}


-- core of include() function for unit scripts
local function ScriptInclude(filename)
	--Spring.Echo("  Loading include: " .. UNITSCRIPT_DIR .. filename)
	local chunk = LoadChunk(UNITSCRIPT_DIR .. filename)
	if chunk then
		include_cache[filename] = chunk
		return chunk
	end
end


-- memoize it so we don't need to decompress and parse the .lua file everytime..
local function MemoizedInclude(filename, env)
	local chunk = include_cache[filename] or ScriptInclude(filename)
	if chunk then
		--overwrite environment so it access environment of current unit
		setfenv(chunk, env)
		return chunk()
	end
end

--------------------------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	local chunk = scripts[ud.scriptName]
	if (not chunk) then return end

	-- Global variables in the script are still per unit.
	-- Set up a new environment that is an instance of the prototype
	-- environment, so we don't need to copy all globals for every unit.

	-- This means of course, that global variable accesses are a bit more
	-- expensive inside unit scripts, but this can be worked around easily
	-- by localizing the necessary globals.

	local pieces = sp_GetUnitPieceMap(unitID)
	local env = {
		unitID = unitID,
		unitDefID = unitDefID,
		script = {},     -- will store the callins
	}

	-- easy self-referencing (Note: use of _G differs from _G in gadgets & widgets)
	env._G = env

	env.include = function(f)
		return MemoizedInclude(f, env)
	end

	env.piece = function(...)
		local args = {...}
		local p = {}
		local n = 0
		for i = 1, #args do
			local name = args[i]
			n = n + 1
			p[n] = pieces[name] or error("piece not found: " .. tostring(name), 2)
		end
		return unpack(p)
	end

	setmetatable(env, { __index = prototypeEnv })
	setfenv(chunk, env)

	-- Execute the chunk. This puts the callins in env.script
	CallAsUnitNoReturn(unitID, chunk)
	local callins = env.script

	-- Add framework callins.
	callins.MoveFinished = MoveFinished
	callins.TurnFinished = TurnFinished
	callins.ScaleFinished = ScaleFinished
	callins.Destroy = Destroy

	-- AimWeapon/AimShield is required for a functional weapon/shield,
	-- so it doesn't hurt to not check other weapons.
	local numWeapons = #ud.weapons
	if ((not callins.AimWeapon and callins.AimWeapon1) or
	    (not callins.AimShield and callins.AimShield1)) then
		for j=1,#weapon_funcs do
			local name = weapon_funcs[j]
			local dispatch = {}
			local n = 0
			for i=1,numWeapons do
				local fun = callins[name .. i]
				if fun then
					dispatch[i] = fun
					n = n + 1
				end
			end
			if n == numWeapons then
				-- optimized case
				callins[name] = function(w, ...)
					return dispatch[w](...)
				end
			elseif n > 0 then
				-- needed for QueryWeapon / AimFromWeapon to return -1
				-- while AimWeapon / AimShield should return false, etc.
				local ret = default_return_values[name]
				callins[name] = function(w, ...)
					local fun = dispatch[w]
					if fun then return fun(...) end
					return ret
				end
			end
		end
	end

	-- Wrap certain callins in a thread and/or safety net.
	for i=1,#thread_wrap do
		Wrap(callins, thread_wrap[i])
	end
	Wrap_AimWeapon(unitID, callins)
	Wrap_AimShield(unitID, callins)
	Wrap_Killed(unitID, callins)

	-- Wrap everything so activeUnit get's set properly.
	for k,v in pairs(callins) do
		local fun = v

		callins[k] = function(...)
			PushActiveUnitID(unitID)
			local ret = fun(...)
			PopActiveUnitID()

			return ret
		end
	end

	-- Register the callins with Spring.
	Spring.UnitScript.CreateScript(unitID, callins)

	-- Register (must be last: it shouldn't be done in case of error.)
	units[unitID] = {
		env = env,
		unitID = unitID,
		waitingForMove = {},
		waitingForTurn = {},
		waitingForScale = {},
		threads = setmetatable({}, {__mode = "kv"}), -- weak table
	}

	-- Now it's safe to start a thread which will run Create().
	-- (Spring doesn't run it, and if it did, it would do so too early to be useful.)
	if callins.Create then
		CallAsUnitNoReturn(unitID, StartThread, callins.Create)
	end
end


function gadget:GameFrame()
	local n = sp_GetGameFrame()
	local zzz = sleepers[n]

	if zzz then
		sleepers[n] = nil

		-- Wake up the lazy bastards for this frame (in reverse order).
		-- NOTE:
		--   1. during WakeUp() a thread t1 might Signal (kill) another thread t2
		--   2. t2 might also be registered in sleepers[n] and not yet woken up
		--   3. if so, t1's signal would cause t2 to be removed from sleepers[n]
		--      via Signal --> RemoveTableElement
		--   4. therefore we cannot use the "for i = 1, #zzz" pattern since the
		--      container size/contents might change while we are iterating over
		--      it (and a Lua for-loop range expression is only evaluated once)
		while (#zzz > 0) do
			local sleeper = zzz[#zzz]
			local unitID = sleeper.unitID

			zzz[#zzz] = nil

			PushActiveUnitID(unitID)
			sp_CallAsUnit(unitID, WakeUp, sleeper)
			PopActiveUnitID()
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
