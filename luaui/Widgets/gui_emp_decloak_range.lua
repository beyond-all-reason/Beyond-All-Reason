--------------------------------------------------------------------------------
-- gui_emp_decloak_range.lua
-- v8: EMP + decloak range with main-pass opacity pulsating per prop
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = "EMP + decloak range",
        desc      = "When spy/gremlin is selected, displays EMP range always and decloak range only while cloaked; main-pass opacity pulses per prop",
        author    = "[teh]decay, updated by ChatGPT",
        date      = "16 May 2025",
        license   = "The BSD License",
        layer     = 0,
        version   = 8,
        enabled   = true,
    }
end

--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------
local onlyDrawRangeWhenSelected = true
local fadeOnCameraDistance      = true
local showLineGlow              = true
local opacityMultiplier         = 1.0
local fadeMultiplier            = 1.2  -- lower value: fades out sooner
local circleDivs                = 64   -- detail of range circle

-- pulse speeds (radians per second) for main-pass opacity
local pulseSpeedDecloak = math.pi * 0.75   -- one cycle every 2s for decloak
local pulseSpeedEMP     = math.pi * 1.5 -- one cycle every 4s for EMP

-- opacity bounds for main-pass
local decloakAlphaMin = 0.25
local decloakAlphaMax = 0.85
local empAlphaMin     = 0.15
local empAlphaMax     = 0.6

--------------------------------------------------------------------------------
-- GLSL & Spring API LOCALS
--------------------------------------------------------------------------------
local glColor              = gl.Color
local glLineWidth          = gl.LineWidth
local glDepthTest          = gl.DepthTest
local glDrawGroundCircle   = gl.DrawGroundCircle

local spGetAllUnits        = Spring.GetAllUnits
local spGetCameraPosition  = Spring.GetCameraPosition
local spGetUnitPosition    = Spring.GetUnitPosition
local spIsSphereInView     = Spring.IsSphereInView
local spIsUnitSelected     = Spring.IsUnitSelected
local spValidUnitID        = Spring.ValidUnitID
local spGiveOrderToUnit    = Spring.GiveOrderToUnit
local spGetUnitDefID       = Spring.GetUnitDefID
local spGetUnitIsCloaked   = Spring.GetUnitIsCloaked
local spGetGameSeconds     = Spring.GetGameSeconds

--------------------------------------------------------------------------------
-- COMMAND CONSTANTS
--------------------------------------------------------------------------------
local CMD_MOVE_STATE       = CMD.MOVE_STATE
local CMD_FIRE_STATE       = CMD.FIRE_STATE

--------------------------------------------------------------------------------
-- GAME STATE
--------------------------------------------------------------------------------
local spec, fullview       = Spring.GetSpectatingState()
local chobbyInterface
local units                = {}  -- [unitID] = { decloakDist, empRadius }

--------------------------------------------------------------------------------
-- DETECT SPY / GREMLIN UNITS AND THEIR RADII
--------------------------------------------------------------------------------
local lower = string.lower
local isSpy, isGremlin = {}, {}
for udid, ud in pairs(UnitDefs) do
    local name = ud.name:lower()
    local decloakDist = ud.mincloakdistance or ud.decloakDistance or 0
    if name:find("spy") or name:find("armamex") then
        -- spy's EMP radius from its self-destruct weapon
        local wdefName = lower(ud.selfDExplosion)
        local wdef = WeaponDefNames[wdefName]
        if wdef then
            isSpy[udid] = { decloakDist, WeaponDefs[wdef.id].damageAreaOfEffect }
        else
            isSpy[udid] = { decloakDist, 0 }
        end
    end
    if name:find("armgremlin") or name:find("armamb") or name:find("armpb") or name:find("armferret")
       or name:find("armckfus") or name:find("armsnipe") or name:find("eyes") or name:find("mine")
       or name:find("armcom") or name:find("corcom") or name:find("legcom") then
        isGremlin[udid] = decloakDist
    end
end

local function addSpy(unitID, unitDefID)
    local props = isSpy[unitDefID]
    units[unitID] = { props[1], props[2] }
end

local function addGremlin(unitID, unitDefID)
    units[unitID] = { isGremlin[unitDefID], 0 }
    spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 0 }, 0)
    spGiveOrderToUnit(unitID, CMD_FIRE_STATE, { 0 }, 0)
end

--------------------------------------------------------------------------------
-- UNIT TRACKING CALLBACKS
--------------------------------------------------------------------------------
function widget:Initialize()
    units = {}
    for _, unitID in ipairs(spGetAllUnits()) do
        local udid = spGetUnitDefID(unitID)
        if isSpy[udid] then
            addSpy(unitID, udid)
        elseif isGremlin[udid] then
            addGremlin(unitID, udid)
        end
    end
end

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
    if not spValidUnitID(unitID) then return end
    if isSpy[unitDefID] then
        addSpy(unitID, unitDefID)
    elseif isGremlin[unitDefID] then
        addGremlin(unitID, unitDefID)
    end
end

function widget:UnitFinished(unitID, unitDefID, teamID)
    if isSpy[unitDefID] then
        addSpy(unitID, unitDefID)
    elseif isGremlin[unitDefID] then
        addGremlin(unitID, unitDefID)
    end
end

function widget:UnitDestroyed(unitID)
    units[unitID] = nil
end

function widget:UnitEnteredLos(unitID, unitTeam)
    if not fullview then
        local udid = spGetUnitDefID(unitID)
        if isSpy[udid] then
            addSpy(unitID, udid)
        elseif isGremlin[udid] then
            addGremlin(unitID, udid)
        end
    end
end

function widget:UnitLeftLos(unitID)
    if not fullview then
        units[unitID] = nil
    end
end

function widget:RecvLuaMsg(msg)
    if msg:sub(1,18) == 'LobbyOverlayActive' then
        chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
    end
end

function widget:PlayerChanged(playerID)
    local prevTeam, prevFull = Spring.GetMyTeamID(), fullview
    spec, fullview = Spring.GetSpectatingState()
    if fullview ~= prevFull then
        widget:Initialize()
    end
end

--------------------------------------------------------------------------------
-- DRAWING
--------------------------------------------------------------------------------
function widget:DrawWorldPreUnit()
    if chobbyInterface or Spring.IsGUIHidden() then return end

    local camX, camY, camZ = spGetCameraPosition()
    glDepthTest(true)

    -- current time for pulses
    local t = spGetGameSeconds()
    local pulseD = (math.sin(t * pulseSpeedDecloak) + 1) * 0.5
    local pulseE = (math.sin(t * pulseSpeedEMP) + 1) * 0.5

    for unitID, prop in pairs(units) do
        local dx, dy, dz = spGetUnitPosition(unitID)
        local maxRad = math.max(prop[1], prop[2])
        if ((not onlyDrawRangeWhenSelected) or spIsUnitSelected(unitID))
           and spIsSphereInView(dx, dy, dz, maxRad) then

            local distToCam = ((camX-dx)^2 + (camY-dy)^2 + (camZ-dz)^2)^0.5
            local alphaScale = fadeOnCameraDistance and math.min(1, (1100/distToCam)*fadeMultiplier) or 1
            if alphaScale > 0.15 then

                local cloaked = spGetUnitIsCloaked(unitID) == true

                -- -- glow pass unchanged
                -- if showLineGlow then
                --     glLineWidth(12)
                --     if prop[1] > 0 and cloaked then
                --         glColor(0.6, 0.6, 1.0, 0.06 * alphaScale * opacityMultiplier)
                --         glDrawGroundCircle(dx, dy, dz, prop[1], circleDivs)
                --     end
                --     if prop[2] > 0 then
                --         local r = 0.3 * pulseD + 0.7 * (1-pulseD)
                --         local g = 0.3 * pulseD + 0.7 * (1-pulseD)
                --         local b = 1.0
                --         glColor(r, g, b, 0.15 * alphaScale * opacityMultiplier)
                --         glDrawGroundCircle(dx, dy, dz, prop[2], circleDivs)
                --     end
                -- end

                -- main pass with opacity pulses
                local lw = math.max(1.5, 2.5 - math.min(2, distToCam/2000))
                glLineWidth(lw)
                if prop[1] > 0 and cloaked then
                    local r = 0.09 * pulseE + 0.8 * (1-pulseE)
                    local g = 0.09 * pulseE + 0.8 * (1-pulseE)
                    local b = 0.09 * pulseE + 0.8 * (1-pulseE)
                    local alpha = decloakAlphaMin * (1-pulseD) + decloakAlphaMax * pulseD
                    glColor(r, g, b, alpha * alphaScale * opacityMultiplier)
                    glDrawGroundCircle(dx, dy, dz, prop[1], circleDivs)
                end
                if prop[2] > 0 then
                    local r = 0.7 * pulseE + 0.6 * (1-pulseE)
                    local g = 0.7 * pulseE + 0.6 * (1-pulseE)
                    local b = 1.0
                    local alpha = empAlphaMin * (1-pulseE) + empAlphaMax * pulseE
                    glColor(r, g, b, alpha * alphaScale * opacityMultiplier)
                    glDrawGroundCircle(dx, dy, dz, prop[2], circleDivs)
                end
            end
        end
    end

    glDepthTest(false)
end
