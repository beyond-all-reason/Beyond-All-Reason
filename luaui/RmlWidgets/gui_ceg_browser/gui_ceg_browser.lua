-- CEG Browser (RmlUi)
-- Author: Steel
-- Developer/artist tool for browsing, filtering and previewing CEG effects and sounds in-game.
--
-- Dependencies:
--   game_ceg_preview.lua  (synced gadget -- handles CEG spawning, projectile preview, world audio)
--   ceg_test_projectile.lua (dummy unit def required for projectile mode)
--
-- Permissions:
--   Gated behind devhelpers permission (multiplayer) or /cheat enabled (singleplayer).
--
-- Code quality notes:
--   DOM poking audit passed -- all DOM reads/writes are deferred to widget:Update or
--   widget:Initialize / AddEventListener callbacks. No DOM access in model callbacks.
--   Data model is authoritative for all list data, selection state, toggle states and
--   tuning values (RmlUi doctrine compliant).

if not RmlUi then
    return
end

function widget:GetInfo()
    return {
        name    = "CEG Browser",
        desc    = "RmlUi CEG Browser -- browse, filter and preview Core Effect Generators in-game",
        author  = "Steel",
        layer   = 0,
        enabled = true,
    }
end

local spEcho            = Spring.Echo
local spSendCommands    = Spring.SendCommands
local spTraceScreenRay      = Spring.TraceScreenRay
local spSendLuaRulesMsg     = Spring.SendLuaRulesMsg
local spGetViewGeom         = Spring.GetViewGeometry
local spGetConfigInt        = Spring.GetConfigInt
local spSetConfigInt        = Spring.SetConfigInt
local spIsCheatingEnabled   = Spring.IsCheatingEnabled

local pi, cos, sin, sqrt, random = math.pi, math.cos, math.sin, math.sqrt, math.random

local MODEL_NAME = "ceg_browser_model"
local RML_PATH   = "LuaUI/RmlWidgets/gui_ceg_browser/gui_ceg_browser.rml"

local allCEGs       = {}
local selectedCEGs       = {}   -- name -> true, trail multi-select
local selectedImpactCEGs = {}   -- name -> true, impact multi-select
local selectedMuzzleCEGs = {}   -- name -> true, muzzle multi-select
local selectedCEG        = ""   -- last trail selected, for spawn and info panel
local document      = nil
local dm_handle     = nil

local pageSize      = 50
local pageIndex     = 0
local currentFilter = ""
local letterFilter  = ""

-- Tuning state
local spawnCount   = 1
local spacingValue = 20
local heightOffset = 0
local pattern      = "line"

local infoOpen      = false
local soundsOpen    = false
local groundArmed   = true
local fireArmed     = false

-- Sound panel state
local soundPageSize      = 36
local soundPageIndex     = 0
local soundFilter        = ""
local soundLetterFilter  = ""
local soundInputFocused  = false
local selectedFireSound   = nil
local selectedImpactSound = nil
local soundHoveredName    = ""

-- Sound category filter state (additive, weapons default)
local activeSoundCats = { weapons = true }

local SOUND_CATS = {
    weapons     = { "sounds/weapons/", "sounds/weapons-mult/", "sounds/bombs/" },
    environment = { "sounds/atmos/", "sounds/atmos-geovents/", "sounds/atmos-local/" },
    unit        = { "sounds/unit/", "sounds/unit-local/", "sounds/movement/", "sounds/movement-air/" },
    critters    = { "sounds/critters/", "sounds/raptors/" },
    ui          = { "sounds/ui/", "sounds/voice/", "sounds/voice-soundeffects/", "sounds/replies/" },
    buildings   = { "sounds/buildings/" },
    functions   = { "sounds/function/", "sounds/global-events/", "sounds/commands/", "sounds/uw/" },
}

-- Projectile tuning state
local projYaw       = 0
local projPitch     = 20
local projSpeed     = 17
local projGravity   = 0.16   -- stored as float, slider uses integer *100
local projFwdOffset = 0
local projUpOffset  = 0
local projTTL       = 6
local projAirburst  = false
local cegDefs       = {}   -- name -> def table, populated during LoadAllCEGs
local altHeld       = false
local hoveredCEG    = ""

----------------------------------------------------------------
-- CEG name loading
----------------------------------------------------------------
local function LoadAllCEGs()
    allCEGs = {}
    cegDefs = {}

    local effectsDir = "effects"
    local files
    if VFS.ZIP_FIRST then
        files = VFS.DirList(effectsDir, "*.lua", VFS.ZIP_FIRST, true)
    else
        files = VFS.DirList(effectsDir, "*.lua", VFS.RAW_FIRST, true)
    end
    files = files or {}

    local function CopyTable(src, deep)
        if type(src) ~= "table" then return src end
        local dst = {}
        for k, v in pairs(src) do
            dst[k] = (deep and type(v) == "table") and CopyTable(v, true) or v
        end
        return dst
    end

    local function MergeTable(dst, src, deep)
        if type(dst) ~= "table" or type(src) ~= "table" then return dst end
        for k, v in pairs(src) do
            if deep and type(v) == "table" and type(dst[k]) == "table" then
                MergeTable(dst[k], v, true)
            else
                dst[k] = v
            end
        end
        return dst
    end

    local function lowerkeys(t)
        if type(t) ~= "table" then return t end
        local out = {}
        for k, v in pairs(t) do
            out[type(k) == "string" and string.lower(k) or k] = v
        end
        return out
    end

    local function MakeEnv()
        return {
            pairs = pairs, ipairs = ipairs, next = next,
            type = type, tonumber = tonumber, tostring = tostring,
            select = select, assert = assert, error = error,
            pcall = pcall, xpcall = xpcall,
            math = math, string = string, table = table,
            unpack = unpack or table.unpack,
            Spring = Spring, VFS = VFS,
            CopyTable = CopyTable, MergeTable = MergeTable, lowerkeys = lowerkeys,
        }
    end

    local names = {}
    local seen  = {}
    local okCount, errCount = 0, 0
    local shownErr = 0

    local function AddFromDefsTable(defs, srcPath)
        if type(defs) ~= "table" then return end
        for k, v in pairs(defs) do
            if type(k) == "string" and not seen[k] then
                seen[k] = true
                names[#names + 1] = k
                cegDefs[k] = { def = v, src = srcPath or "?" }
            end
        end
    end

    for _, path in ipairs(files) do
        local env = MakeEnv()
        local ok, ret = pcall(VFS.Include, path, env)
        if ok then
            okCount = okCount + 1
            if type(ret) == "table" then
                AddFromDefsTable(ret, path)
            elseif type(env.effects) == "table" then
                AddFromDefsTable(env.effects, path)
            end
        else
            errCount = errCount + 1
            if shownErr < 10 then
                shownErr = shownErr + 1
                spEcho("[CEG Browser] Failed: " .. tostring(path) .. ": " .. tostring(ret))
            end
        end
    end

    table.sort(names)
    allCEGs = names
    spEcho(string.format("[CEG Browser] Loaded %d CEG names from %d file(s) (ok=%d err=%d).",
        #allCEGs, #files, okCount, errCount))
end

----------------------------------------------------------------
-- Sound name loading
----------------------------------------------------------------
local allSounds = {}

local function LoadAllSounds()
    allSounds = {}
    local seen  = {}
    local names = {}
    local modes = { VFS.RAW, VFS.GAME, VFS.MOD, VFS.ZIP, VFS.MAP }

    -- Build list of dirs to scan based on active categories; if none active, scan all
    local dirs = {}
    local anyActive = false
    for cat, _ in pairs(activeSoundCats) do
        anyActive = true
        for _, d in ipairs(SOUND_CATS[cat] or {}) do
            dirs[#dirs + 1] = d
        end
    end
    if not anyActive then
        for _, catDirs in pairs(SOUND_CATS) do
            for _, d in ipairs(catDirs) do
                dirs[#dirs + 1] = d
            end
        end
    end

    for _, dir in ipairs(dirs) do
        for _, mode in ipairs(modes) do
            local files = VFS.DirList(dir, "*", mode, true) or {}
            for _, path in ipairs(files) do
                local logical = path
                    :gsub("^sounds/", "")
                    :gsub("%.[%a%d]+$", "")
                if not seen[logical] then
                    seen[logical] = true
                    names[#names + 1] = logical
                end
            end
        end
    end

    table.sort(names)
    allSounds = names
    spEcho(string.format("[CEG Browser] Loaded %d sounds.", #allSounds))
end

local function BuildSoundItems(filterText, letter)
    local out = {}
    local q  = (filterText or ""):lower()
    local lf = (letter or ""):lower()

    local function basename(s)
        return s:match("([^/]+)$") or s
    end

    for _, name in ipairs(allSounds) do
        local base = basename(name):lower()
        local ok = true

        -- A-Z filter applies to basename only
        if lf ~= "" and base:sub(1, 1) ~= lf then
            ok = false
        end

        -- search matches full path
        if ok and q ~= "" and not name:lower():find(q, 1, true) then
            ok = false
        end

        if ok then
            out[#out + 1] = { name = name }
        end
    end

    -- Sort by basename first, full path as tiebreak
    table.sort(out, function(a, b)
        local ba = (basename(a.name)):lower()
        local bb = (basename(b.name)):lower()
        if ba == bb then return a.name < b.name end
        return ba < bb
    end)

    return out
end

local function RebuildSoundList()
    if not dm_handle then return end
    local items     = BuildSoundItems(soundFilter, soundLetterFilter)
    local total     = #items
    local pageCount = math.max(1, math.ceil(total / soundPageSize))
    soundPageIndex  = math.max(0, math.min(soundPageIndex, pageCount - 1))

    local displayList = {}
    if total > 0 then
        local s = soundPageIndex * soundPageSize + 1
        local e = math.min(s + soundPageSize - 1, total)
        for i = s, e do
            local name = items[i].name
            displayList[#displayList + 1] = {
                name      = name,
                fireSel   = (selectedFireSound   == name) and 1 or 0,
                impactSel = (selectedImpactSound == name) and 1 or 0,
            }
        end
    end

    dm_handle.soundList        = displayList
    dm_handle.soundFilterText  = soundFilter
    dm_handle.soundLetterFilter = soundLetterFilter
    dm_handle.soundPageDisplay = (soundPageIndex + 1) .. " / " .. pageCount
    dm_handle.soundTotalCount  = total .. " sounds"
end

----------------------------------------------------------------
-- Spawn
----------------------------------------------------------------
local function SpawnPattern(name, wx, wz)
    if not name or name == "" then return end
    local cnt  = math.max(1, math.min(spawnCount, 100))
    local spac = math.max(0, math.min(spacingValue, 1000))
    local pat  = pattern
    if pat ~= "line" and pat ~= "ring" and pat ~= "scatter" then pat = "line" end
    local x  = math.floor(wx + 0.5)
    local z  = math.floor(wz + 0.5)
    local ho = math.floor(heightOffset + 0.5)

    local msg = string.format("cegtest:%s:%d:%d:%d:%d:%s:%d",
        name, x, z, cnt, spac, pat, ho)
    if selectedImpactSound and selectedImpactSound ~= "" then
        msg = msg .. "|impactSound=" .. selectedImpactSound
    end
    spSendLuaRulesMsg(msg)
end

local function SpawnPatternMulti(names, wx, wz)
    if not names or #names == 0 then return end
    local cnt  = math.max(1, math.min(spawnCount, 100))
    local spac = math.max(0, math.min(spacingValue, 1000))
    local pat  = pattern
    if pat ~= "line" and pat ~= "ring" and pat ~= "scatter" then pat = "line" end
    local x  = math.floor(wx + 0.5)
    local z  = math.floor(wz + 0.5)
    local ho = math.floor(heightOffset + 0.5)

    local msg = string.format("cegtest_multi:%s:%d:%d:%d:%d:%s:%d",
        table.concat(names, ","), x, z, cnt, spac, pat, ho)
    if selectedImpactSound and selectedImpactSound ~= "" then
        msg = msg .. "|impactSound=" .. selectedImpactSound
    end
    spSendLuaRulesMsg(msg)
end

----------------------------------------------------------------
-- List building
----------------------------------------------------------------
local function BuildItems(filterText, letter)
    local out = {}
    local q  = (filterText or ""):lower()
    local lf = (letter or ""):lower()

    for _, name in ipairs(allCEGs) do
        local low = name:lower()
        if (lf == "" or low:sub(1, 1) == lf)
        and (q  == "" or low:find(q, 1, true)) then
            out[#out + 1] = { name = name }
        end
    end

    return out
end

----------------------------------------------------------------
-- CEG INFO panel
----------------------------------------------------------------
local function BuildInfoLines(name)
    if not name or name == "" then
        if dm_handle then
            dm_handle.infoName   = "(no CEG selected)"
            dm_handle.infoSource = ""
            dm_handle.infoLines  = {}
        end
        return
    end

    local entry = cegDefs[name]
    local src   = (entry and entry.src) or "(unknown)"
    local def   = (entry and entry.def)

    if dm_handle then
        dm_handle.infoName   = name
        dm_handle.infoSource = src
    end

    local lines = {}
    local maxLines = 200

    local function addLine(s)
        if #lines >= maxLines then return false end
        lines[#lines + 1] = { text = s }
        return true
    end

    local function sortedKeys(t)
        local ks = {}
        for k in pairs(t) do ks[#ks + 1] = k end
        table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
        return ks
    end

    local function dump(t, indent, depth)
        if depth > 6 then addLine(indent .. "..."); return end
        for _, k in ipairs(sortedKeys(t)) do
            local v = t[k]
            if type(v) == "table" then
                addLine(indent .. tostring(k) .. ": {")
                dump(v, indent .. "  ", depth + 1)
                addLine(indent .. "}")
            else
                local vs = type(v) == "string" and ('"' .. v .. '"') or tostring(v)
                if not addLine(indent .. tostring(k) .. ": " .. vs) then return end
            end
        end
    end

    if type(def) == "table" then
        dump(def, "", 1)
    else
        addLine("(no definition captured)")
    end

    if dm_handle then dm_handle.infoLines = lines end
end

local function RebuildList()
    local items     = BuildItems(currentFilter, letterFilter)
    local total     = #items
    local pageCount = math.max(1, math.ceil(total / pageSize))
    pageIndex = math.max(0, math.min(pageIndex, pageCount - 1))

    local displayList = {}
    if total > 0 then
        local s = pageIndex * pageSize + 1
        local e = math.min(s + pageSize - 1, total)
        for i = s, e do
            local item = items[i]
            item.selected   = selectedCEGs[item.name]       and 1 or 0
            item.impactSel  = selectedImpactCEGs[item.name] and 1 or 0
            item.muzzleSel  = selectedMuzzleCEGs[item.name] and 1 or 0
            displayList[#displayList + 1] = item
        end
    end

    if dm_handle then
        dm_handle.cegList      = displayList
        dm_handle.filterText   = currentFilter
        dm_handle.letterFilter = letterFilter
        dm_handle.pageIndex    = pageIndex
        dm_handle.pageCount    = pageCount
        dm_handle.pageDisplay  = (pageIndex + 1) .. " / " .. pageCount
        dm_handle.totalCount   = total .. " CEGs (filtered)"
    end

    return displayList
end

local function SelectCEG(name, ctrl, selType)
    name    = name or ""
    selType = selType or "trail"

    local tbl
    if selType == "impact" then
        tbl = selectedImpactCEGs
    elseif selType == "muzzle" then
        tbl = selectedMuzzleCEGs
    else
        tbl = selectedCEGs
    end

    if ctrl then
        if tbl[name] then
            tbl[name] = nil
            if selType == "trail" then
                selectedCEG = ""
                for k in pairs(selectedCEGs) do selectedCEG = k; break end
            end
        else
            tbl[name] = true
            if selType == "trail" then selectedCEG = name end
        end
    else
        -- Single select: clear only this type's set
        if selType == "trail" then
            selectedCEGs = {}
            if name ~= "" then selectedCEGs[name] = true; selectedCEG = name
            else selectedCEG = "" end
        elseif selType == "impact" then
            selectedImpactCEGs = {}
            if name ~= "" then selectedImpactCEGs[name] = true end
        elseif selType == "muzzle" then
            selectedMuzzleCEGs = {}
            if name ~= "" then selectedMuzzleCEGs[name] = true end
        end
    end

    if dm_handle then
        dm_handle.selectedCEG = selectedCEG
        if infoOpen then BuildInfoLines(selectedCEG) end
    end
    RebuildList()
end

----------------------------------------------------------------
-- Mouse
----------------------------------------------------------------
function widget:MousePress(x, y, button)
    -- RMB
    if button == 3 then
        if fireArmed then
            if hoveredCEG ~= "" then
                local ctrl = Spring.GetModKeyState and select(2, Spring.GetModKeyState()) or false
                SelectCEG(hoveredCEG, ctrl, "impact")
                return true
            elseif next(selectedImpactCEGs) then
                SelectCEG("", false, "impact")
                return true
            end
        else
            if next(selectedCEGs) then
                SelectCEG("")
                return true
            end
        end
        return false
    end

    -- MMB
    if button == 2 then
        if fireArmed and hoveredCEG ~= "" then
            local ctrl = Spring.GetModKeyState and select(2, Spring.GetModKeyState()) or false
            SelectCEG(hoveredCEG, ctrl, "muzzle")
            return true
        end
        return false
    end

    -- LMB: ground spawn or projectile fire
    if button ~= 1 then return false end

    local hitType, pos = spTraceScreenRay(x, y, true)
    if hitType ~= "ground" then return false end

    if fireArmed then
        -- Projectile mode: need at least a trail CEG selected
        if not next(selectedCEGs) then return false end

        local trailList  = {}
        local impactList = {}
        local muzzleList = {}
        for name in pairs(selectedCEGs)       do trailList[#trailList+1]   = name end
        for name in pairs(selectedImpactCEGs) do impactList[#impactList+1] = name end
        for name in pairs(selectedMuzzleCEGs) do muzzleList[#muzzleList+1] = name end

        local wx = math.floor(pos[1] + 0.5)
        local wz = math.floor(pos[3] + 0.5)

        for _, trailName in ipairs(trailList) do
            local msg = string.format("cegproj:%s:%s:%d:%d:%d:%d:%d:%.2f",
                trailName,
                table.concat(impactList, ","),
                wx, wz,
                math.floor(projYaw + 0.5),
                math.floor(projPitch + 0.5),
                math.floor(projSpeed + 0.5),
                projGravity
            )
            msg = msg .. string.format("|ttl=%.2f|airburst=%d",
                projTTL, projAirburst and 1 or 0)
            if #muzzleList > 0 then
                msg = msg .. "|muzzle=" .. table.concat(muzzleList, ",")
            end
            if selectedFireSound and selectedFireSound ~= "" then
                msg = msg .. "|fireSound=" .. selectedFireSound
            end
            if selectedImpactSound and selectedImpactSound ~= "" then
                msg = msg .. "|impactSound=" .. selectedImpactSound
            end
            msg = msg .. string.format("|ofs=%d,%d",
                math.floor(projFwdOffset + 0.5),
                math.floor(projUpOffset + 0.5))
            spSendLuaRulesMsg(msg)
        end
        return true
    end

    -- Ground mode
    if not next(selectedCEGs) then return false end

    local names = {}
    for name in pairs(selectedCEGs) do names[#names + 1] = name end

    if #names == 1 then
        SpawnPattern(names[1], pos[1], pos[3])
    elseif #names > 1 then
        SpawnPatternMulti(names, pos[1], pos[3])
    end
    return true
end

----------------------------------------------------------------
-- Position persistence
----------------------------------------------------------------
local function SavePosition()
    if not document then return end
    -- rml-dom-escape: no data-binding API to read element pixel position at arbitrary call time
    local root = document:GetElementById("widget-container")
    if not root then return end
    local vsx, vsy = spGetViewGeom()
    if not vsx then return end
    spSetConfigInt("ceg_browser_x", math.floor((root.offset_left / vsx) * 1000))
    spSetConfigInt("ceg_browser_y", math.floor((root.offset_top  / vsy) * 1000))
end

local function LoadPosition()
    if not document then return end
    -- rml-dom-escape: no data-binding API to read/set element pixel position at arbitrary call time
    local root = document:GetElementById("widget-container")
    if not root then return end
    local vsx, vsy = spGetViewGeom()
    if not vsx then return end
    local rx = spGetConfigInt("ceg_browser_x", -1)
    local ry = spGetConfigInt("ceg_browser_y", -1)
    if rx < 0 or ry < 0 then return end
    root.style["position"] = "absolute"
    root.style["left"]     = math.floor((rx / 1000) * vsx) .. "px"
    root.style["top"]      = math.floor((ry / 1000) * vsy) .. "px"
end

----------------------------------------------------------------
-- Data model
----------------------------------------------------------------
local init_model = {
    cegList      = {},
    filterText   = "",
    letterFilter = "",
    selectedCEG  = "",
    pageIndex    = 0,
    pageCount    = 1,
    pageDisplay  = "1 / 1",
    totalCount   = "",
    isCollapsed  = true,

    cheatOn     = 0,
    globallosOn = 0,

    -- Mode arm buttons
    groundArmed = 1,
    fireArmed   = 0,

    -- Aux panels
    infoOpen   = 0,
    soundsOpen = 0,
    infoName   = "(no CEG selected)",
    infoSource = "",
    infoLines  = {},

    -- Sound list
    soundList         = {},
    soundFilterText   = "",
    soundLetterFilter = "",
    soundPageDisplay  = "1 / 1",
    soundTotalCount   = "",
    soundInputFocused = 0,

    -- Sound category toggles
    catWeapons     = 1,
    catEnvironment = 0,
    catUnit        = 0,
    catCritters    = 0,
    catUI          = 0,
    catBuildings   = 0,
    catFunctions   = 0,

    -- ALT hover tooltip (managed via DOM in widget:Update, not data model)
    inputFocused = 0,

    -- Tuning
    spawnCount   = 1,
    spacingValue = 20,
    heightOffset = 0,
    patternLine    = 1,
    patternRing    = 0,
    patternScatter = 0,

    -- Projectile tuning
    projYaw        = 0,
    projPitch      = 20,
    projSpeed      = 17,
    projGravityInt = 16,     -- slider integer (gravity * 100)
    projGravityDisp = "0.16", -- display string for text input
    projFwdOffset  = 0,
    projUpOffset   = 0,
    projTTL        = 6,
    projAirburst   = 0,

    applyFilter = function(ev)
        -- rml-dom-escape: read value from event parameters, not DOM GetAttribute
        currentFilter = (ev and ev.parameters and ev.parameters.value) or ""
        pageIndex = 0
        RebuildList()
    end,

    clearFilter = function(ev)
        currentFilter = ""
        pageIndex = 0
        if dm_handle then dm_handle.filterText = "" end
        RebuildList()
    end,

    nextPage = function(ev)
        pageIndex = pageIndex + 1
        RebuildList()
    end,

    prevPage = function(ev)
        pageIndex = pageIndex - 1
        RebuildList()
    end,

    gotoLetter = function(ev, letter)
        letterFilter = (letter or ""):lower()
        pageIndex = 0
        RebuildList()
    end,

    spawnCEG = function(ev, name)
        local ctrl = ev and ev.parameters and (ev.parameters.ctrl_key == 1)
        SelectCEG(name, ctrl, "trail")
    end,

    setPattern = function(ev, pat)
        pattern = pat or "line"
        if dm_handle then
            dm_handle.patternLine    = (pattern == "line")    and 1 or 0
            dm_handle.patternRing    = (pattern == "ring")    and 1 or 0
            dm_handle.patternScatter = (pattern == "scatter") and 1 or 0
        end
    end,

    setSpawnCount = function(ev)
        local v = tonumber(ev.parameters.value) or 1
        spawnCount = math.max(1, math.min(100, math.floor(v + 0.5)))
        if dm_handle then dm_handle.spawnCount = spawnCount end
    end,

    setSpawnCountText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        spawnCount = math.max(1, math.min(100, math.floor(v + 0.5)))
        if dm_handle then dm_handle.spawnCount = spawnCount end
    end,

    setSpacing = function(ev)
        local v = tonumber(ev.parameters.value) or 20
        spacingValue = math.max(0, math.min(1000, math.floor(v + 0.5)))
        if dm_handle then dm_handle.spacingValue = spacingValue end
    end,

    setSpacingText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        spacingValue = math.max(0, math.min(1000, math.floor(v + 0.5)))
        if dm_handle then dm_handle.spacingValue = spacingValue end
    end,

    setHeightOffset = function(ev)
        local v = tonumber(ev.parameters.value) or 0
        heightOffset = math.max(0, math.min(1000, math.floor(v + 0.5)))
        if dm_handle then dm_handle.heightOffset = heightOffset end
    end,

    setHeightOffsetText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        heightOffset = math.max(0, math.min(1000, math.floor(v + 0.5)))
        if dm_handle then dm_handle.heightOffset = heightOffset end
    end,

    -- Projectile tuning setters
    setProjYaw = function(ev)
        local v = tonumber(ev.parameters.value) or 0
        projYaw = math.max(-180, math.min(180, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projYaw = projYaw end
    end,
    setProjYawText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        projYaw = math.max(-180, math.min(180, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projYaw = projYaw end
    end,

    setProjPitch = function(ev)
        local v = tonumber(ev.parameters.value) or 20
        projPitch = math.max(-45, math.min(80, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projPitch = projPitch end
    end,
    setProjPitchText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        projPitch = math.max(-45, math.min(80, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projPitch = projPitch end
    end,

    setProjSpeed = function(ev)
        local v = tonumber(ev.parameters.value) or 17
        projSpeed = math.max(0, math.min(600, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projSpeed = projSpeed end
    end,
    setProjSpeedText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        projSpeed = math.max(0, math.min(600, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projSpeed = projSpeed end
    end,

    -- Gravity: slider is integer -100..100 representing -1.00..1.00
    setProjGravity = function(ev)
        local vi = tonumber(ev.parameters.value) or 16
        vi = math.max(-100, math.min(100, math.floor(vi + 0.5)))
        projGravity = vi / 100.0
        if dm_handle then
            dm_handle.projGravityInt  = vi
            dm_handle.projGravityDisp = string.format("%.2f", projGravity)
        end
    end,
    setProjGravityText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        projGravity = math.max(-1.0, math.min(1.0, v))
        local vi = math.floor(projGravity * 100 + 0.5)
        if dm_handle then
            dm_handle.projGravityInt  = vi
            dm_handle.projGravityDisp = string.format("%.2f", projGravity)
        end
    end,

    setProjFwdOffset = function(ev)
        local v = tonumber(ev.parameters.value) or 0
        projFwdOffset = math.max(0, math.min(100, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projFwdOffset = projFwdOffset end
    end,
    setProjFwdOffsetText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        projFwdOffset = math.max(0, math.min(100, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projFwdOffset = projFwdOffset end
    end,

    setProjUpOffset = function(ev)
        local v = tonumber(ev.parameters.value) or 0
        projUpOffset = math.max(0, math.min(100, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projUpOffset = projUpOffset end
    end,
    setProjUpOffsetText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        projUpOffset = math.max(0, math.min(100, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projUpOffset = projUpOffset end
    end,

    setProjTTL = function(ev)
        local v = tonumber(ev.parameters.value) or 6
        projTTL = math.max(1, math.min(30, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projTTL = projTTL end
    end,
    setProjTTLText = function(ev)
        local v = tonumber(ev.parameters.value)
        if not v then return end
        projTTL = math.max(1, math.min(30, math.floor(v + 0.5)))
        if dm_handle then dm_handle.projTTL = projTTL end
    end,

    toggleAirburst = function(ev)
        projAirburst = not projAirburst
        if dm_handle then dm_handle.projAirburst = projAirburst and 1 or 0 end
    end,

    hoverCEG = function(ev, name)
        hoveredCEG = name or ""
    end,

    armGround = function(ev)
        groundArmed = not groundArmed
        if groundArmed then fireArmed = false end
        if dm_handle then
            dm_handle.groundArmed = groundArmed and 1 or 0
            dm_handle.fireArmed   = 0
        end
    end,

    armFire = function(ev)
        fireArmed = not fireArmed
        if fireArmed then groundArmed = false end
        if dm_handle then
            dm_handle.fireArmed   = fireArmed and 1 or 0
            dm_handle.groundArmed = 0
        end
    end,

    toggleInfo = function(ev)
        infoOpen = not infoOpen
        if infoOpen then soundsOpen = false end
        if dm_handle then
            dm_handle.infoOpen   = infoOpen and 1 or 0
            dm_handle.soundsOpen = 0
            if infoOpen then BuildInfoLines(selectedCEG) end
        end
    end,

    toggleSounds = function(ev)
        soundsOpen = not soundsOpen
        if soundsOpen then infoOpen = false end
        if dm_handle then
            dm_handle.soundsOpen = soundsOpen and 1 or 0
            dm_handle.infoOpen   = 0
        end
    end,

    resetAll = function(ev)
        spawnCount    = 1
        spacingValue  = 20
        heightOffset  = 0
        pattern       = "line"
        projYaw       = 0
        projPitch     = 20
        projSpeed     = 17
        projGravity   = 0.16
        projFwdOffset = 0
        projUpOffset  = 0
        projTTL       = 6
        projAirburst  = false
        if dm_handle then
            dm_handle.spawnCount      = 1
            dm_handle.spacingValue    = 20
            dm_handle.heightOffset    = 0
            dm_handle.patternLine     = 1
            dm_handle.patternRing     = 0
            dm_handle.patternScatter  = 0
            dm_handle.projYaw         = 0
            dm_handle.projPitch       = 20
            dm_handle.projSpeed       = 17
            dm_handle.projGravityInt  = 16
            dm_handle.projGravityDisp = "0.16"
            dm_handle.projFwdOffset   = 0
            dm_handle.projUpOffset    = 0
            dm_handle.projTTL         = 6
            dm_handle.projAirburst    = 0
        end
        SelectCEG("")
        selectedImpactCEGs = {}
        selectedMuzzleCEGs = {}
        RebuildList()
    end,

    toggleCollapse = function(ev)
        dm_handle.isCollapsed = not dm_handle.isCollapsed
    end,

    sendCheat = function(ev)
        local isSP = Spring.Utilities and Spring.Utilities.Gametype and
                     Spring.Utilities.Gametype.IsSinglePlayer and
                     Spring.Utilities.Gametype.IsSinglePlayer()
        spSendCommands(isSP and "cheat" or "say !cheat")
        -- Optimistically toggle; Update will sync from engine within ~1s
        if dm_handle then
            local newState = (dm_handle.cheatOn == 0) and 1 or 0
            dm_handle.cheatOn = newState
        end
    end,

    sendGlobalLOS = function(ev)
        if dm_handle then
            local newState = (dm_handle.globallosOn == 0) and 1 or 0
            dm_handle.globallosOn = newState
            spSendCommands("luarules globallos " .. newState)
        end
    end,

    reloadCEGs = function(ev)
        LoadAllCEGs()
        LoadAllSounds()
        pageIndex = 0
        soundPageIndex = 0
        currentFilter = ""
        soundFilter   = ""
        letterFilter  = ""
        soundLetterFilter = ""
        if dm_handle then
            dm_handle.filterText      = ""
            dm_handle.soundFilterText = ""
        end
        RebuildList()
        RebuildSoundList()
    end,

    onInputFocus = function(ev)
        Spring.SDLStartTextInput()
        if dm_handle then dm_handle.inputFocused = 1 end
    end,

    onInputBlur = function(ev)
        Spring.SDLStopTextInput()
        if dm_handle then dm_handle.inputFocused = 0 end
    end,

    closeWidget = function(ev)
        widgetHandler:RemoveWidget(widget)
    end,

    -- Sound panel functions
    soundApplyFilter = function(ev)
        soundFilter = (ev and ev.parameters and ev.parameters.value) or ""
        soundPageIndex = 0
        RebuildSoundList()
    end,

    soundClearFilter = function(ev)
        soundFilter = ""
        soundPageIndex = 0
        if dm_handle then dm_handle.soundFilterText = "" end
        RebuildSoundList()
    end,

    soundGotoLetter = function(ev, letter)
        soundLetterFilter = (letter or ""):lower()
        soundPageIndex = 0
        RebuildSoundList()
    end,

    soundNextPage = function(ev)
        soundPageIndex = soundPageIndex + 1
        RebuildSoundList()
    end,

    soundPrevPage = function(ev)
        soundPageIndex = soundPageIndex - 1
        RebuildSoundList()
    end,

    soundOnInputFocus = function(ev)
        Spring.SDLStartTextInput()
        soundInputFocused = true
        if dm_handle then dm_handle.soundInputFocused = 1 end
    end,

    soundOnInputBlur = function(ev)
        Spring.SDLStopTextInput()
        soundInputFocused = false
        if dm_handle then dm_handle.soundInputFocused = 0 end
    end,

    selectSound = function(ev, name)
        -- LMB selects fire sound; clicking same name deselects
        selectedFireSound = (selectedFireSound == name) and nil or name
        RebuildSoundList()
    end,

    resetSounds = function(ev)
        selectedFireSound   = nil
        selectedImpactSound = nil
        activeSoundCats     = { weapons = true }
        if dm_handle then
            dm_handle.catWeapons     = 1
            dm_handle.catEnvironment = 0
            dm_handle.catUnit        = 0
            dm_handle.catCritters    = 0
            dm_handle.catUI          = 0
            dm_handle.catBuildings   = 0
            dm_handle.catFunctions   = 0
        end
        LoadAllSounds()
        soundPageIndex = 0
        RebuildSoundList()
    end,

    hoverSound = function(ev, name)
        soundHoveredName = name or ""
    end,

    toggleSoundCat = function(ev, cat)
        if activeSoundCats[cat] then
            activeSoundCats[cat] = nil
        else
            activeSoundCats[cat] = true
        end
        -- Update model flags
        if dm_handle then
            dm_handle.catWeapons     = activeSoundCats.weapons     and 1 or 0
            dm_handle.catEnvironment = activeSoundCats.environment and 1 or 0
            dm_handle.catUnit        = activeSoundCats.unit        and 1 or 0
            dm_handle.catCritters    = activeSoundCats.critters    and 1 or 0
            dm_handle.catUI          = activeSoundCats.ui          and 1 or 0
            dm_handle.catBuildings   = activeSoundCats.buildings   and 1 or 0
            dm_handle.catFunctions   = activeSoundCats.functions   and 1 or 0
        end
        LoadAllSounds()
        soundPageIndex = 0
        RebuildSoundList()
    end,

    playFireSound = function(ev)
        if selectedFireSound and selectedFireSound ~= "" then
            spSendLuaRulesMsg("ceg_preview_sound:" .. selectedFireSound)
        end
    end,

    playImpactSound = function(ev)
        if selectedImpactSound and selectedImpactSound ~= "" then
            spSendLuaRulesMsg("ceg_preview_sound:" .. selectedImpactSound)
        end
    end,
}

----------------------------------------------------------------
-- Drag / tooltip state
----------------------------------------------------------------
local tooltipEl     = nil
local lastHovered   = ""

local dragState = {
    active  = false,
    offsetX = 0,
    offsetY = 0,
    rootEl  = nil,
    lastX   = -1,
    lastY   = -1,
}

local cheatSyncTimer = 0

function widget:Update()
    if not document then return end

    -- Sync cheat state from engine every 30 frames
    cheatSyncTimer = cheatSyncTimer + 1
    if cheatSyncTimer >= 30 then
        cheatSyncTimer = 0
        if dm_handle and spIsCheatingEnabled then
            dm_handle.cheatOn = spIsCheatingEnabled() and 1 or 0
        end
    end

    -- Drive window drag (titlebar mousedown -> Update moves container)
    if dragState.active and dragState.rootEl then
        local mx, my = Spring.GetMouseState()
        local vsx, vsy = Spring.GetViewGeometry()
        local rmlY = vsy - my
        local newX = math.floor(mx - dragState.offsetX)
        local newY = math.floor(rmlY - dragState.offsetY)
        local ew = dragState.rootEl.offset_width
        local eh = dragState.rootEl.offset_height
        if newX < 0 then newX = 0 elseif newX + ew > vsx then newX = vsx - ew end
        if newY < 0 then newY = 0 elseif newY + eh > vsy then newY = vsy - eh end
        if newX ~= dragState.lastX or newY ~= dragState.lastY then
            dragState.lastX = newX
            dragState.lastY = newY
            dragState.rootEl.style.left = newX .. "px"
            dragState.rootEl.style.top  = newY .. "px"
        end
    end

    -- Lazy-fetch tooltip element once
    if not tooltipEl then
        tooltipEl = document:GetElementById("ceg-alt-tooltip")
    end
    if not tooltipEl then return end

    local show = altHeld and hoveredCEG ~= ""

    if not show then
        if lastHovered ~= "" then
            tooltipEl:SetClass("alt-tooltip-hidden", true)
            lastHovered = ""
        end
        return
    end

    -- Update content only when hovered name changes
    if hoveredCEG ~= lastHovered then
        lastHovered = hoveredCEG
        -- Split at first hyphen or underscore: prefix in white, suffix in blue
        local pre, suf = hoveredCEG:match("^([^%-%_]+)([%-%_].+)$")
        local rml
        if pre and suf then
            rml = '<span class="tooltip-prefix">' .. pre .. '</span>'
                .. '<span class="tooltip-suffix">' .. suf .. '</span>'
        else
            rml = '<span class="tooltip-prefix">' .. hoveredCEG .. '</span>'
        end
        tooltipEl.inner_rml = rml
    end

    -- Position near mouse cursor using vw/vh (confirmed working pattern)
    -- rml-dom-escape: style writes deferred to Update
    local mx, my = Spring.GetMouseState()
    local vsx, vsy = Spring.GetViewGeometry()
    local leftPx = mx + 16
    local topPx  = (vsy - my) + 8
    if leftPx + 260 > vsx then leftPx = mx - 270 end
    leftPx = math.max(0, leftPx)
    topPx  = math.max(0, topPx)
    tooltipEl:SetAttribute("style", string.format("left: %.2fvw; top: %.2fvh;",
        (leftPx / vsx) * 100, (topPx / vsy) * 100))
    tooltipEl:SetClass("alt-tooltip-hidden", false)
end

function widget:Initialize()
    LoadAllCEGs()
    LoadAllSounds()
    local total     = #allCEGs
    local pageCount = math.max(1, math.ceil(total / pageSize))
    local displayList = RebuildList()

    init_model.cegList       = displayList
    init_model.pageDisplay   = "1 / " .. pageCount
    init_model.totalCount    = total .. " CEGs (filtered)"
    init_model.pageCount     = pageCount

    local ctx = RmlUi.GetContext("shared")
    if not ctx then return end

    dm_handle = ctx:OpenDataModel(MODEL_NAME, init_model)
    if not dm_handle then return end

    document = ctx:LoadDocument(RML_PATH, widget)
    if not document then return end

    document:Show()
    LoadPosition()
    RebuildSoundList()

    -- Wire up titlebar drag
    local titlebarEl  = document:GetElementById("ceg-titlebar")
    local containerEl = document:GetElementById("widget-container")
    if titlebarEl and containerEl then
        dragState.rootEl = containerEl
        titlebarEl:AddEventListener("mousedown", function(ev)
            local p = ev and ev.parameters
            if p and p.button and p.button ~= 0 then return end
            local mx, my = Spring.GetMouseState()
            local vsy = select(2, Spring.GetViewGeometry())
            dragState.active  = true
            dragState.offsetX = mx - containerEl.offset_left
            dragState.offsetY = (vsy - my) - containerEl.offset_top
            dragState.lastX   = -1
            dragState.lastY   = -1
            if ev then ev:StopPropagation() end
        end, false)
        document:AddEventListener("mouseup", function()
            if dragState.active then
                SavePosition()
                dragState.active = false
            end
        end, false)
    end

    -- Wire RMB and MMB on the CEG grid via AddEventListener
    -- (RmlUi consumes mouse events so widget:MousePress never fires over the widget)
    local gridEl = document:GetElementById("ceg-grid")
    if gridEl then
        gridEl:AddEventListener("mousedown", function(ev)
            local p = ev and ev.parameters
            if not p then return end
            local btn = p.button  -- RmlUi: 0=LMB, 1=RMB, 2=MMB
            if btn ~= 1 and btn ~= 2 then return end
            if hoveredCEG == "" then return end
            local ctrl = (p.ctrl_key == 1)
            if btn == 1 then  -- RMB
                if fireArmed then
                    SelectCEG(hoveredCEG, ctrl, "impact")
                end
            elseif btn == 2 then  -- MMB
                if fireArmed then
                    SelectCEG(hoveredCEG, ctrl, "muzzle")
                end
            end
            ev:StopPropagation()
        end, false)
    end

    -- Wire RMB on sound list for impact sound selection
    local soundListEl = document:GetElementById("sound-list")
    if soundListEl then
        soundListEl:AddEventListener("mousedown", function(ev)
            local p = ev and ev.parameters
            if not p or p.button ~= 1 then return end  -- RMB = button 1 in RmlUi
            if soundHoveredName == "" then return end
            selectedImpactSound = (selectedImpactSound == soundHoveredName) and nil or soundHoveredName
            RebuildSoundList()
            ev:StopPropagation()
        end, false)
    end
end

function widget:Shutdown()
    Spring.SDLStopTextInput()
    if document then document:Close() end
    local ctx = RmlUi.GetContext("shared")
    if ctx and dm_handle then ctx:RemoveDataModel(MODEL_NAME) end
    document  = nil
    dm_handle = nil
end

-- ALT key tracking for hover tooltip
local KEY_ALT  = 308

function widget:KeyPress(key, mods, isRepeat)
    if key == KEY_ALT and not isRepeat then
        altHeld = true
    end
    return false
end

function widget:KeyRelease(key, mods)
    if key == KEY_ALT then
        altHeld = false
    end
    return false
end

function widget:RecvLuaMsg(message, playerID)
    if not document then return end
    if message:sub(1, 19) == 'LobbyOverlayActive1' then
        document:Hide()
    elseif message:sub(1, 19) == 'LobbyOverlayActive0' then
        document:Show()
    end
end
