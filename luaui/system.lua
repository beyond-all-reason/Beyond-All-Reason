--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    system.lua
--  brief:   defines the global entries placed into a widget's table
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



if (System == nil) then
	if tracy == nil then
		Spring.Echo("Tracy: No support detected, replacing tracy.* with function stubs.")
		tracy = {}
		tracy.ZoneBeginN = function () return end
		tracy.ZoneBegin = function () return end
		tracy.ZoneEnd = function () return end --Spring.Echo("No Tracy") return end
		tracy.Message = function () return end
		tracy.ZoneName = function () return end
		tracy.ZoneText = function () return end
	end

	System = {
		--
		--  Custom LuaUI variables
		--
		Commands = Commands,
		fontHandler = fontHandler,
		LUAUI_DIRNAME = LUAUI_DIRNAME,

		--
		--  Custom Spring tables
		--
		VFS = VFS,
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
		LOG = LOG,

		UnitDefs        = UnitDefs,
		UnitDefNames    = UnitDefNames,
		FeatureDefs     = FeatureDefs,
		FeatureDefNames = FeatureDefNames,
		WeaponDefs      = WeaponDefs,
		WeaponDefNames  = WeaponDefNames,

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

		-- Custom libraries

		Json = Json,
		RmlUi = RmlUi,

		-- luasocket
		socket          = socket,

		--
		--  Standard functions and variables
		--
		assert         = assert,
		error          = error,

		print          = print,

		next           = next,
		pairs          = pairs,
		pairsByKeys    = pairsByKeys, -- custom: defined in `common\tablefunctions.lua`
		ipairs         = ipairs,

		tonumber       = tonumber,
		tostring       = tostring,
		type           = type,

		collectgarbage = collectgarbage,
		gcinfo         = gcinfo,

		unpack         = unpack,
		select         = select,

		dofile         = dofile,
		loadfile       = loadfile,
		loadlib        = loadlib,
		loadstring     = loadstring,
		require        = require,

		getmetatable   = getmetatable,
		setmetatable   = setmetatable,

		rawequal       = rawequal,
		rawget         = rawget,
		rawset         = rawset,

		getfenv        = getfenv,
		setfenv        = setfenv,

		pcall          = pcall,
		xpcall         = xpcall,

		_VERSION       = _VERSION
	}
end
