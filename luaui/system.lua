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
    table = table,
    string = string,
    package = package,
    coroutine = coroutine,
    
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
