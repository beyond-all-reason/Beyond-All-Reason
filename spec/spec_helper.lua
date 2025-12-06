
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

_G.VFS.FileExists = function(path)
    -- First try the exact path provided
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end

    -- Fallback: Case-insensitive check using cached file list
    if not _G.VFS._ci_file_cache then
        _G.VFS._ci_file_cache = {}
        -- Find all files, excluding .git directory
        local handle = io.popen("find . -name '.git' -prune -o -type f -print")
        if handle then
            for line in handle:lines() do
                -- Strip leading ./
                local p = line:gsub("^%./", "")
                _G.VFS._ci_file_cache[p:lower()] = p
            end
            handle:close()
        end
    end

    local cleanPath = path:gsub("^%./", "")
    return _G.VFS._ci_file_cache[cleanPath:lower()] ~= nil
end

_G.VFS.Include = function(path, env, mode)
    -- Check cache first
    if _G.VFS._cache[path] then
        return _G.VFS._cache[path]
    end

    -- Try direct path first
    local realPath = path
    local file = io.open(path, "r")
    if file then
        file:close()
    else
        -- Check case-insensitive cache
        if not _G.VFS._ci_file_cache then
            -- Force cache population by calling FileExists with a dummy path
            _G.VFS.FileExists("___dummy_path___")
        end
        
        local cleanPath = path:gsub("^%./", "")
        local cachedPath = _G.VFS._ci_file_cache[cleanPath:lower()]
        if cachedPath then
            realPath = cachedPath
        end
    end

    -- Use loadfile/dofile instead of require to better simulate VFS and handle case-insensitive paths
    local chunk, err = loadfile(realPath)
    if chunk then
        -- Handle environment if provided
        if env then
            setfenv(chunk, env)
        end
        
        local success, result = pcall(chunk)
        if success then
            _G.VFS._cache[path] = result
            return result
        else
            print("Error loading " .. path .. ": " .. tostring(result))
        end
    end
    
    -- Fallback to old require method if file not found on disk (e.g. standard libs)
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

-- we have to do this after VFS.Include is declared
-- if we used `require("common/tablefunction")` above here, it could potentially cause "The same file is required with different names." linter errors when `VFS.Include("common/tablefunctions.lua")` is called
VFS.Include("common/tablefunctions.lua")

_G.VFS.SubDirs = function(path)
    -- Check case-insensitive cache for correct directory path
    if not _G.VFS._ci_file_cache then
        -- Force cache population
        _G.VFS.FileExists("___dummy_path___")
    end
    
    -- Currently the cache only has files. We need directories too or just assume 'find' works if we fix the path.
    -- But for SubDirs we want to list subdirectories.
    -- Let's assume the input path might be wrong casing.
    
    -- Simple heuristic: try to find the directory case-insensitively if it doesn't exist
    local searchPath = path
    local handle = io.open(path)
    if handle then
        handle:close()
    else
        -- Try to find matching directory
        local parent = path:match("(.+)/[^/]+$") or "."
        local base = path:match("([^/]+)$")
        if base then
            local pHandle = io.popen(string.format("find %s -maxdepth 1 -type d -iname '%s'", parent, base))
            if pHandle then
                local match = pHandle:read("*l")
                if match then searchPath = match end
                pHandle:close()
            end
        end
    end

    local dirs = {}
    local handle = io.popen(string.format("find %s -maxdepth 1 -type d", searchPath))
    if handle then
        for line in handle:lines() do
            if line ~= searchPath then
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
    
    -- Fix directory path case-sensitivity
    local searchDir = directory
    local handle = io.open(directory)
    if handle then
        handle:close()
    else
         -- Try to find matching directory case-insensitively
        local parent = directory:match("(.+)/[^/]+$") or "."
        local base = directory:match("([^/]+)$")
        if base then
            local pHandle = io.popen(string.format("find %s -maxdepth 1 -type d -iname '%s'", parent, base))
            if pHandle then
                local match = pHandle:read("*l")
                if match then searchDir = match end
                pHandle:close()
            end
        end
    end

    -- Use find command with pattern matching
    -- Use -iname for case-insensitive pattern matching
    local name_pattern = pattern and pattern ~= "*" and string.format("-iname '%s'", pattern) or ""
    if recursive then
        cmd = string.format("find %s %s -type f", searchDir, name_pattern)
    else
        cmd = string.format("find %s %s -maxdepth 1 -type f", searchDir, name_pattern)
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

