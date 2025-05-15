--------------------------------------------------------------------------------
-- gui_emp_decloak_range.lua
-- v7: EMP ring gently fades/pulses between two colors in glow-pass
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name      = "EMP + decloak range",
        desc      = "When spy or gremlin is selected, displays emp range always and decloak range only while cloaked; EMP glow now pulses",
        author    = "[teh]decay, updated by IceXuick",
        date      = "14 May 2025",
        license   = "The BSD License",
        layer     = 0,
        version   = 7,
        enabled   = true,
    }
end

--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------
local onlyDrawRangeWhenSelected = true
local fadeOnCameraDistance      = true
local showLineGlow              = true
local opacityMultiplier         = 1.3
local fadeMultiplier            = 1.2  -- lower value: fades out sooner
local circleDivs                = 64   -- detail of range circle

-- pulse speed (radians per second) for glow color cycling
local pulseSpeed = math.pi * 1.5  -- speed of one full cycle 

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
    local decloakDist = ud.mincloakdistance or ud.decloakDistance
    if name:find("spy") or name:find("armamex") then
        local wdid = WeaponDefNames[lower(ud.selfDExplosion)].id
        isSpy[udid] = { decloakDist, WeaponDefs[wdid].damageAreaOfEffect }
    end
    if name:find("armgremlin") or name:find("armamb") or name:find("armpb") or name:find("armferret") or name:find("armckfus") then
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

    -- current time for pulsing
    local t = spGetGameSeconds()
    -- normalized pulse [0,1]
    local pulse = (math.sin(t * pulseSpeed) + 1) * 0.5

    for unitID, prop in pairs(units) do
        local dx, dy, dz = spGetUnitPosition(unitID)
        local maxRad = math.max(prop[1], prop[2])
        if ((not onlyDrawRangeWhenSelected) or spIsUnitSelected(unitID))
           and spIsSphereInView(dx, dy, dz, maxRad) then

            local distToCam = ((camX-dx)^2 + (camY-dy)^2 + (camZ-dz)^2)^0.5
            local alphaScale = fadeOnCameraDistance and math.min(1, (1100/distToCam)*fadeMultiplier) or 1
            if alphaScale > 0.15 then

                local cloaked = spGetUnitIsCloaked(unitID) == true

                -- glow pass
                if showLineGlow then
                    glLineWidth(10)
                    if prop[1] > 0 and cloaked then
                        glColor(0.6, 0.6, 1.0, 0.06 * alphaScale * opacityMultiplier)
                        glDrawGroundCircle(dx, dy, dz, prop[1], circleDivs)
                    end
                    -- if prop[2] > 0 then
                    --     -- interpolate color
                    --     local r = 0.3 * pulse + 0.7 * (1-pulse)
                    --     local g = 0.3 * pulse + 0.7 * (1-pulse)
                    --     local b = 1 * pulse + 1 * (1-pulse)
                    --     glColor(r, g, b, 0.15 * alphaScale * opacityMultiplier)
                    --     glDrawGroundCircle(dx, dy, dz, prop[2], circleDivs)
                    -- end
                end

                -- main pass (static colors)
                local lw = math.max(0.4, 2.6 - math.min(2, distToCam/2000))
                glLineWidth(lw)
                if prop[1] > 0 and cloaked then
                    glColor(0.28, 0.28, 1.0, 0.45 * alphaScale * opacityMultiplier)
                    glDrawGroundCircle(dx, dy, dz, prop[1], circleDivs)
                end
                if prop[2] > 0 then
                    -- interpolate color
                        local r = 0.3 * pulse + 0.8 * (1-pulse)
                        local g = 0.3 * pulse + 0.8 * (1-pulse)
                        local b = 1 * pulse + 1 * (1-pulse)
                        glColor(r, g, b, 0.25 * alphaScale * opacityMultiplier)
                        glDrawGroundCircle(dx, dy, dz, prop[2], circleDivs)
                end
            end
        end
    end

    glDepthTest(false)
end
