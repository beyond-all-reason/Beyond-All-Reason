--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    system.lua
--  brief:   defines the global entries placed into a gadget's table
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if System == nil then
	if tracy == nil then
		Spring.Echo("Gadgetside tracy: No support detected, replacing tracy.* with function stubs.")
		-- Built in a local and rawset, so the language server does not read the
		-- stubs as competing definitions of the engine's `tracy` global -- which
		-- makes every tracy.* call site disagree about its parameters.
		local tracyStub = {}
		tracyStub.ZoneBeginN = function() end
		tracyStub.ZoneBegin = function() end
		tracyStub.ZoneEnd = function() end
		tracyStub.Message = function() end
		tracyStub.ZoneName = function() end
		tracyStub.ZoneText = function() end
		rawset(_G, "tracy", tracyStub)
	end

	System = {
		--
		--  Custom Spring tables
		--
		Script = Script,
		Spring = Spring,
		Engine = Engine,
		Platform = Platform,
		Game = Game,
		GameCMD = Game.CustomCommands.GameCMD,
		gl = gl,
		GL = GL,
		CMD = CMD,
		CMDTYPE = CMDTYPE,
		COB = COB,
		SFX = SFX,
		VFS = VFS,
		LOG = LOG,

		UnitDefs = UnitDefs,
		UnitDefNames = UnitDefNames,
		FeatureDefs = FeatureDefs,
		FeatureDefNames = FeatureDefNames,
		WeaponDefs = WeaponDefs,
		WeaponDefNames = WeaponDefNames,

		--
		-- Custom Constants
		--
		COBSCALE = COBSCALE,

		--
		--  Synced Utilities
		--
		CallAsTeam = CallAsTeam,
		SendToUnsynced = SendToUnsynced,

		--
		--  Unsynced Utilities
		--
		SYNCED = SYNCED,
		snext = next, -- the following 3 are deprecated, but defined in case any legacy code uses them
		spairs = pairs,
		sipairs = ipairs,

		--
		--  Standard libraries
		--
		io = io,
		os = os,
		math = math,
		debug = debug,
		tracy = tracy,
		table = table,
		string = string,
		package = package,
		coroutine = coroutine,

		--
		--  Custom libraries
		--
		Json = Json,

		-- BAR module namespace (created by init.lua; detached from Spring table)
		BAR = BAR,

		--
		--  Standard functions and variables
		--
		assert = assert,
		error = error,

		print = print,

		next = next,
		pairs = pairs,
		pairsByKeys = pairsByKeys, -- custom: defined in `common\tablefunctions.lua`
		ipairs = ipairs,

		tonumber = tonumber,
		tostring = tostring,
		type = type,

		collectgarbage = collectgarbage,
		gcinfo = gcinfo,

		unpack = unpack,
		select = select,
		dofile = dofile,
		loadfile = loadfile,
		loadlib = loadlib,
		loadstring = loadstring,
		require = require,

		getmetatable = getmetatable,
		setmetatable = setmetatable,

		rawequal = rawequal,
		rawget = rawget,
		rawset = rawset,

		getfenv = getfenv,
		setfenv = setfenv,

		pcall = pcall,
		xpcall = xpcall,

		_VERSION = _VERSION,
	}
end
