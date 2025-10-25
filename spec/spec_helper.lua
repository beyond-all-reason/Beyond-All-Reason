require("common.tablefunctions")

-- Spring logging mocks
_G.LOG = _G.LOG or {
    ERROR = "ERROR",
    WARNING = "WARNING",
    INFO = "INFO",
    DEBUG = "DEBUG",
}

-- Log level hierarchy for filtering
local LOG_LEVELS = {
    [_G.LOG.DEBUG] = 1,
    [_G.LOG.INFO] = 2,
    [_G.LOG.WARNING] = 3,
    [_G.LOG.ERROR] = 4,
}

-- Current log level - only log messages at this level or higher
_G.CURRENT_LOG_LEVEL = _G.LOG.INFO

_G.Spring = _G.Spring or {
    Log = function(tag, level, message)
        -- If only one argument provided, treat it as a simple message
        if message == nil then
            message = tag
            tag = "Spring"
            level = _G.LOG.INFO
        end

        -- Only log if the message level meets or exceeds the current log level
        if LOG_LEVELS[level] and LOG_LEVELS[level] >= LOG_LEVELS[_G.CURRENT_LOG_LEVEL] then
            print(string.format("[%s] %s: %s", tag, level, message))
        end
    end
}

_G.unpack = _G.unpack or table.unpack or function(t, i, j)
    i = i or 1; j = j or #t
    if i > j then return end
    return t[i], _G.unpack(t, i+1, j)
end

-- VFS.Include mock for testing
_G.VFS = _G.VFS or {}
_G.VFS._cache = _G.VFS._cache or {}
_G.VFS.Include = function(path, env, mode)
    -- Check cache first
    if _G.VFS._cache[path] then
        return _G.VFS._cache[path]
    end

    -- Convert filesystem-like path to module name for require
    local mod = path
        :gsub("^%./", "")
        :gsub("%.lua$", "")
        :gsub("/", ".")

    local success, result = pcall(require, mod)
    if success then
        _G.VFS._cache[path] = result
        return result
    else
        -- Instead of erroring, return an empty table for missing files
        -- This allows unitdefs.lua and other files to continue loading even if some dependencies are missing
        _G.VFS._cache[path] = {}
        return {}
    end
end

_G.VFS.FileExists = function(path)
    -- Handle case-insensitive file checking for Linux CI compatibility
    local checkPath = path
    -- Apply case-insensitive logic: lowercase the filename part (after last /)
    local dirPart, filePart = checkPath:match("^(.-)([^/]+)$")
    if dirPart and filePart then
        checkPath = dirPart .. string.lower(filePart)
    else
        checkPath = string.lower(checkPath)
    end

    -- Try the normalized path
    local file = io.open(checkPath, "r")
    if file then
        file:close()
        return true
    end

    return false
end

_G.VFS.SubDirs = function(path)
    local dirs = {}
    local handle = io.popen(string.format("find %s -maxdepth 1 -type d", path))
    if handle then
        for line in handle:lines() do
            if line ~= path then
                table.insert(dirs, line)
            end
        end
        handle:close()
    end
    return dirs
end

_G.VFS.DirList = function(directory, pattern, mode, recursive)
    -- Returns relative paths with directory prefix, just like native VFS.DirList
    local files = {}
    local cmd

    -- Use find command with pattern matching
    local name_pattern = pattern and pattern ~= "*" and string.format("-name '%s'", pattern) or ""
    if recursive then
        cmd = string.format("find %s %s -type f", directory, name_pattern)
    else
        cmd = string.format("find %s %s -maxdepth 1 -type f", directory, name_pattern)
    end

    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            table.insert(files, line)
        end
        handle:close()
    end

    return files
end

_G.VFS.MAP = 1
_G.VFS.MOD = 2
_G.VFS.BASE = 4
_G.VFS_MODES = _G.VFS.MAP + _G.VFS.MOD + _G.VFS.BASE

-- to enable, `luarocks install inspect`
_G.inspect = (function()
    local ok, mod = pcall(require, "inspect")
    if ok and mod then return mod end
    -- fallback: no-op string (won't break prints/concats)
    return function(_) return _ end
end)()
