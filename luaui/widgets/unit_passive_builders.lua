function widget:GetInfo()
    return {
        name      = "Passive builders v4",
        desc      = "Allows to set builders (nanos, labs and cons) on passive mode",
        author    = "[teh]decay",
        date      = "20 aug 2015",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        version   = 4,
        enabled   = true  -- loaded by default
    }
end

-- project page on github: https://github.com/SpringWidgets/passive-builders

-- Changelog:
-- v2 [teh]decay Fixed bug with rezz bots and spys
-- v3 [teh]decay exclude Commando from "passive" builders
-- v4 [teh]decay add ability to select which builders to put on passive mode: nanos, cons, labs

-- some code was used from "Wind Speed" widget. Thx to Jazcash and Floris!

local CMD_PASSIVE       = 34571
local spGetMyTeamID     = Spring.GetMyTeamID
local spGetTeamUnits    = Spring.GetTeamUnits
local spGetUnitDefID    = Spring.GetUnitDefID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetMyPlayerID	= Spring.GetMyPlayerID
local spGetPlayerInfo	= Spring.GetPlayerInfo

local glRect            = gl.Rect
local glTexRect         = gl.TexRect
local glText            = gl.Text
local glTexture         = gl.Texture
local glColor           = gl.Color
local glPushMatrix      = gl.PushMatrix
local glPopMatrix       = gl.PopMatrix
local glTranslate       = gl.Translate

local coreCommando = UnitDefNames["commando"]

local passiveLabs = false;
local passiveNanos = true;
local passiveCons = false;

local xPos;
local yPos;

local width = 80;
local heigth = 90;

local function isBuilder(ud)
    if not passiveCons and not passiveLabs and not passiveNanos then
        return false
    end

    --nano
    if ud and ud.isBuilder and not ud.canMove and not ud.isFactory then
        if passiveNanos then
            return true
        else
            return false
        end
    end

    --factory
    if ud and ud.isBuilder and ud.isFactory then
        if passiveLabs then
            return true
        else
            return false
        end
    end

    --cons
    if ud and ud.isBuilder and not ud.canManualFire and ud.canAssist
            and ud.id ~= coreCommando.id and not ud.isFactory and ud.canMove then
        if passiveCons then
            return true
        else
            return false
        end
    end

    return false
end

local function passivateBuilder(unitID)
    spGiveOrderToUnit(unitID, CMD_PASSIVE, {1}, {})
end

local function activateBuilder(unitID)
    spGiveOrderToUnit(unitID, CMD_PASSIVE, {0}, {})
end

function widget:DrawScreen()
    -- do not delete me or "widget:TweakDrawScreen()" will not be called
end

function widget:TweakDrawScreen()
    glColor(0.1, 0.1, 0.1, 1)
    glRect(xPos, yPos, xPos + width, yPos + heigth);
    glColor(1, 1, 1, 1)
    glText("Passive", xPos + 10, yPos + 70, 13, "n")
    glColor(1, 1, 1, 0.2)
    drawCheckbox(xPos + 10, yPos + 10, passiveCons,  "cons")
    drawCheckbox(xPos + 10, yPos + 30, passiveNanos, "nanos")
    drawCheckbox(xPos + 10, yPos + 50, passiveLabs,  "labs")
end

function drawCheckbox(x, y, state, text)
    glPushMatrix()
    glTranslate(x, y, 0)
    glColor(1, 1, 1, 0.2)
    glRect(0, 0, 16, 16)
    glColor(1, 1, 1, 1)
    if state then
        glTexture('LuaUI/Images/tick.png')
        glTexRect(0, 0, 16, 16)
        glTexture(false)
    end
    glText(text, 20, 4, 11, "n")
    glPopMatrix()
end

function widget:IsAbove(mx, my)
    return mx > xPos and my > yPos and mx < xPos + width and my < yPos + heigth
end

function widget:TweakMousePress(mx, my, mb)
    if mb == 2 then
        Spring.Echo("true", mx, my, mb)
        return true
    end

    if mb == 1 then
        if mb == 1 then
            if mx > xPos + 10 and my > yPos + 10 and mx < (xPos + 10 + 16) and my < (yPos + 10 + 16) then
                passiveCons = not passiveCons
                refreshUints()
            elseif mx > xPos + 10 and my > yPos + 30 and mx < (xPos + 10 + 16) and my < (yPos + 30 + 16) then
                passiveNanos = not passiveNanos
                refreshUints()
            elseif mx > xPos + 10 and my > yPos + 50 and mx < (xPos + 10 + 16) and my < (yPos + 50 + 16) then
                passiveLabs = not passiveLabs
                refreshUints()
            end
        end
    end
end

function widget:TweakMouseMove(mx, my, dx, dy)
    local vsx, vsy = gl.GetViewSizes()
    if mx < 50 or mx > vsx - 50 then
        return
    end

    if my < 50 or my > vsy - 50 then
        return
    end

    xPos = mx - width/2;
    yPos = my - heigth/2;
    processGuishader()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
    if (unitTeam ~= spGetMyTeamID()) then
        return
    end

    if (isBuilder(UnitDefs[unitDefID])) then
        passivateBuilder(unitID)
    end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam)
    widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:GetConfigData()
    return {
        passiveLabs = passiveLabs,
        passiveNanos = passiveNanos,
        passiveCons = passiveCons,
        xPos = xPos,
        yPos = yPos
    }
end

function widget:SetConfigData(data)
    if data.passiveLabs ~= nil then
        passiveLabs = data.passiveLabs
    else
        passiveLabs = false
    end

    if data.passiveNanos ~= nil then
        passiveNanos = data.passiveNanos
    else
        passiveNanos = true
    end

    if data.passiveCons ~= nil then
        passiveCons = data.passiveCons
    else
        passiveCons = false
    end

    if data.xPos ~= nil then
        xPos = data.xPos
        yPos = data.yPos
    else
        local vsx, vsy = gl.GetViewSizes()
        xPos = vsx/2
        yPos = vsy/2
    end

    refreshUints()
    processGuishader()
end

function refreshUints()
    local _, _, spec, _ = spGetPlayerInfo(spGetMyPlayerID())
    if spec then
        return
    end

    local myUnits = spGetTeamUnits(spGetMyTeamID())
    for _, unitID in ipairs(myUnits) do
        local unitDefID = spGetUnitDefID(unitID)
        local ud = UnitDefs[unitDefID];

        -- re-activate all builders
        if ud and ud.isBuilder and not ud.canManualFire and ud.canAssist and ud.id ~= coreCommando.id then
            activateBuilder(unitID)
        end

        -- passivate only required builders
        if (isBuilder(ud)) then
            passivateBuilder(unitID)
        end
    end
end

function processGuishader()
    if (WG['guishader_api'] ~= nil) then
        WG['guishader_api'].InsertRect(xPos, yPos, xPos + width, yPos + heigth, 'passivebuilders')
    end
end

function widget:Shutdown()
    if (WG['guishader_api'] ~= nil) then
        WG['guishader_api'].RemoveRect('passivebuilders')
    end
end

