local CONTRIB_BASEPATH = "contrib/"

if not REQUIRE_LOADED_FILES then
    REQUIRE_LOADED_FILES = {}
end

local function getFileName(modname)
    local libraryPath = string.gsub(modname, "%.", "/")

    local baseName = CONTRIB_BASEPATH .. libraryPath

    local luaExtension = baseName .. ".lua"
    if VFS.FileExists(luaExtension) then
        return luaExtension
    end

    local initExtension = baseName .. "/init.lua"
    if VFS.FileExists(initExtension) then
        return initExtension
    end

    return nil
end

local function requireImplementation(modname)
    local filename = getFileName(modname)
    if not filename then
        error("no such library: " .. modname)
    end

    if REQUIRE_LOADED_FILES[filename] then
        return REQUIRE_LOADED_FILES[filename]
    end

    local value = VFS.Include(filename)

    REQUIRE_LOADED_FILES[filename] = value

    return REQUIRE_LOADED_FILES[filename]
end

return requireImplementation
