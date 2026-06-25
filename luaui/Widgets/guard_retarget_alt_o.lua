include("keysym.h.lua")

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        -- This is the name shown in the widget list
        name    = "Guard Retarget (Alt+O)",

        -- Short explanation shown in the widget list
        desc    = "Alt+O arms special guard; click an allied unit to guard-retarget to nearby same-type units on death",

        author  = "26Projects",
        date    = "2026-04-07",
        license = "WTFPL",

        -- Very low layer means this widget runs early
        layer   = -999999,

        -- true = widget starts enabled
        enabled = true,
    }
end


----------------------------------------------------------------
-- 1) SHORTCUT NAMES FOR SPRING FUNCTIONS
----------------------------------------------------------------
-- These lines make long Spring names shorter and faster to type.
-- Example:
-- Spring.GetMyTeamID() becomes spGetMyTeamID()

local spGetGameFrame            = Spring.GetGameFrame
local spGetMyTeamID             = Spring.GetMyTeamID
local spGetSpectatingState      = Spring.GetSpectatingState
local spIsReplay                = Spring.IsReplay
local spIsUnitAllied            = Spring.IsUnitAllied
local spGetSelectedUnits        = Spring.GetSelectedUnits
local spGetTeamUnits            = Spring.GetTeamUnits
local spGetUnitCommands         = Spring.GetUnitCommands
local spGetUnitDefID            = Spring.GetUnitDefID
local spGetUnitPosition         = Spring.GetUnitPosition
local spGetUnitTeam             = Spring.GetUnitTeam
local spGetUnitIsDead           = Spring.GetUnitIsDead
local spValidUnitID             = Spring.ValidUnitID
local spGiveOrder               = Spring.GiveOrder
local spGiveOrderToUnit         = Spring.GiveOrderToUnit
local spGetUnitsInSphere        = Spring.GetUnitsInSphere
local spAreTeamsAllied          = Spring.AreTeamsAllied
local spTraceScreenRay          = Spring.TraceScreenRay
local spSendCommands            = Spring.SendCommands
local spEcho                    = Spring.Echo
local spGetMouseState           = Spring.GetMouseState
local spGetViewGeometry         = Spring.GetViewGeometry

local glColor                   = gl.Color
local glRect                    = gl.Rect
local glTexture                 = gl.Texture
local glTexRect                 = gl.TexRect
local glText                    = gl.Text


----------------------------------------------------------------
-- 2) IMPORTANT CONSTANTS
----------------------------------------------------------------

-- This is the engine command ID for Guard.
-- We use this when we want to tell a unit:
-- "Guard that other unit."
local CMD_GUARD = CMD.GUARD

-- This tries to get the keycode for O from the engine.
-- If for some reason KEYSYMS.O does not exist, it falls back to "o".
local KEY_O = (KEYSYMS and KEYSYMS.O) or string.byte("o")

-- BAR's normal camera flip action is "cameraflip".
-- Binding Alt+O directly to this widget's action keeps it reliable even
-- though action keybinds are processed before widget:KeyPress().
local ACTION_NAME = "guardretarget"

-- Drawn near the cursor while Alt+O special guard is armed.
local ARMED_ICON_TEXTURE = "LuaUI/Images/allycursor.dds"
local ARMED_ICON_SIZE = 34
local ARMED_ICON_OFFSET_X = 20
local ARMED_ICON_OFFSET_Y = -18

-- These are the search bubbles.
-- We try 400 first.
-- If no good unit is found, we try 550.
-- If still no good unit is found, we try 700.
local SEARCH_RADII = {400, 550, 700}

-- This says:
-- "The replacement unit must also be near where the dead unit was."
-- So the unit should be close to:
-- 1) the guarder
-- 2) the dead target area
local MAX_FROM_DEAD_TARGET = 600

-- Every 15 frames we re-check who is still guarding.
local UPDATE_FRAMES = 15


----------------------------------------------------------------
-- 3) STATE VARIABLES
----------------------------------------------------------------

-- This will hold "my team" number.
-- Example: team 1, team 2, etc.
local myTeamID

-- This becomes true after the actual match starts.
local gameStarted = false

-- This is our "special mode is armed" flag.
-- Press Alt+O -> this becomes true.
-- Then the NEXT left click on an allied unit uses special guard.
local awaitingSpecialGuard = false

-- specialGuardUnits[unitID] = true
-- Means:
-- "This unit is using the special smart-retarget guard behavior."
local specialGuardUnits = {}

-- guardData[guarderID] = {
--     targetID = ???,
--     targetDefID = ???
-- }
--
-- Example:
-- guarderID = the unit doing the guarding
-- targetID = the exact unit it is guarding right now
-- targetDefID = that unit's type (same as UnitDefID)
--
-- We store targetDefID so that when the target dies,
-- we can look for "another unit of the same type".
local guardData = {}


----------------------------------------------------------------
-- 4) WHO IS ALLOWED TO USE THIS FEATURE?
----------------------------------------------------------------
-- This table says which selected unit types are allowed
-- to use the special guard mode.
--
-- canUseSpecialGuard[unitDefID] = true
--
-- Right now:
-- if the unit can move and is not immobile,
-- we allow it.

local canUseSpecialGuard = {}

for unitDefID, ud in pairs(UnitDefs) do
    if ud.canMove and not ud.isImmobile then
        canUseSpecialGuard[unitDefID] = true
    end
end


----------------------------------------------------------------
-- 5) SMALL HELPER FUNCTIONS
----------------------------------------------------------------

local function MaybeRemoveSelf()
    -- If the player is spectating, remove the widget.
    -- We do not want spectator clients running this.
    if spGetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
        return true
    end
end


local function RebindKeys()
    -- While this widget is enabled, make Alt+O activate this widget.
    spSendCommands({
        "unbindkeyset Alt+o",
        "bind Alt+o luaui " .. ACTION_NAME,
    })
end


local function RestoreKeys()
    -- Put BAR camera flip back when the widget is disabled.
    spSendCommands({
        "unbindkeyset Alt+o",
        "bind Alt+o cameraflip",
    })
end


local function IsValidAliveUnit(unitID)
    -- Input:
    -- unitID = some unit number
    --
    -- Output:
    -- true if:
    --   - it exists
    --   - the ID is valid
    --   - the unit is not dead
    return unitID
        and spValidUnitID(unitID)
        and not spGetUnitIsDead(unitID)
end


local function DistSq(x1, z1, x2, z2)
    -- This gives distance squared on the map.
    -- We use X and Z because Spring maps use X/Z for ground position.
    --
    -- Why squared?
    -- Because it is faster than doing a square root.
    --
    -- Bigger number = farther away
    -- Smaller number = closer

    local dx = x1 - x2
    local dz = z1 - z2
    return dx * dx + dz * dz
end


local function WithinRangeSq(x1, z1, x2, z2, r)
    -- Input:
    -- point 1 = x1,z1
    -- point 2 = x2,z2
    -- r = allowed radius
    --
    -- Output:
    -- true if point 2 is within radius r of point 1
    local dx = x1 - x2
    local dz = z1 - z2
    return (dx * dx + dz * dz) <= (r * r)
end


local function ClearTrackingForUnit(unitID)
    -- This completely removes special mode for one unit.
    --
    -- We erase:
    -- 1) the "special unit" flag
    -- 2) the remembered target data
    specialGuardUnits[unitID] = nil
    guardData[unitID] = nil
end


local function GetSelectedSpecialGuardUnits()
    -- We look at all currently selected unit types.
    -- Only selected movable units are allowed to use special guard.
    local selectedUnits = spGetSelectedUnits()
    local usableUnits = {}

    if not selectedUnits then
        return usableUnits
    end

    for i = 1, #selectedUnits do
        local unitID = selectedUnits[i]
        local unitDefID = spGetUnitDefID(unitID)

        if unitDefID and canUseSpecialGuard[unitDefID] then
            usableUnits[#usableUnits + 1] = unitID
        end
    end

    return usableUnits
end


local function ArmSpecialGuard()
    local usableUnits = GetSelectedSpecialGuardUnits()

    if #usableUnits == 0 then
        awaitingSpecialGuard = false
        spEcho("[Guard Retarget] Select movable guard unit(s), then press Alt+O.")
        return false
    end

    awaitingSpecialGuard = true
    spEcho("[Guard Retarget] Armed. Left-click an allied unit to guard-retarget.")
    return true
end


local function DrawArmedGuardCue()
    local mx, my, _, _, _, offscreen = spGetMouseState()

    if offscreen then
        return
    end

    local size = ARMED_ICON_SIZE
    local x1 = mx + ARMED_ICON_OFFSET_X
    local y1 = my + ARMED_ICON_OFFSET_Y
    local vsx, vsy = spGetViewGeometry()

    if x1 + size + 60 > vsx then
        x1 = mx - size - ARMED_ICON_OFFSET_X - 60
    end
    if y1 < 8 then
        y1 = my + 18
    elseif y1 + size + 8 > vsy then
        y1 = vsy - size - 8
    end

    local x2 = x1 + size
    local y2 = y1 + size

    -- Small green command badge: "special guard is armed; click an ally".
    glColor(0, 0, 0, 0.45)
    glRect(x1 - 4, y1 - 4, x2 + 4, y2 + 4)

    glColor(0.15, 1.0, 0.25, 0.95)
    glTexture(ARMED_ICON_TEXTURE)
    glTexRect(x1, y1, x2, y2)
    glTexture(false)

    glColor(0.0, 0.95, 0.15, 0.95)
    glRect(x1 - 4, y1 - 4, x2 + 4, y1 - 1)
    glRect(x1 - 4, y2 + 1, x2 + 4, y2 + 4)
    glRect(x1 - 4, y1 - 4, x1 - 1, y2 + 4)
    glRect(x2 + 1, y1 - 4, x2 + 4, y2 + 4)

    glColor(0.85, 1.0, 0.85, 0.95)
    glText("GUARD", x1 + size + 7, y1 + 9, 12, "o")
    glColor(1, 1, 1, 1)
end


local function CanRetargetGuardNow(guarderID, oldTargetID)
    -- Input:
    -- guarderID = the unit that was guarding
    -- oldTargetID = the dead unit it used to guard
    --
    -- Output:
    -- true = okay to issue a new guard order
    -- false = do not touch it
    --
    -- Why do we do this?
    -- To avoid shoving a new Guard order into a unit
    -- that already has some other queue/command going on.

    if not IsValidAliveUnit(guarderID) then
        return false
    end

    -- Ask Spring for up to 2 commands from this unit's queue.
    local cmds = spGetUnitCommands(guarderID, 2)

    -- No commands at all? Fine, we can retarget.
    if not cmds or #cmds == 0 then
        return true
    end

    -- More than one command? That means there is already a queue.
    -- We do not want to mess with that.
    if #cmds > 1 then
        return false
    end

    local cmd1 = cmds[1]

    -- Weird empty first command? Treat as safe.
    if not cmd1 then
        return true
    end

    -- If the current command is NOT Guard,
    -- then do not interfere.
    if cmd1.id ~= CMD_GUARD then
        return false
    end

    -- cmd1.params[1] is usually the target unit ID for GUARD
    local guardedID = cmd1.params and cmd1.params[1]

    -- Safe only if:
    --   - guard target is now empty
    --   - or it is still the old dead target
    return guardedID == nil or guardedID == oldTargetID
end


local function FindReplacementTarget(guarderID, wantedDefID, deadTargetID, deadX, deadZ)
    -- Input:
    -- guarderID     = the unit that needs a new guard target
    -- wantedDefID   = the dead target's unit type
    -- deadTargetID  = exact unit that died
    -- deadX, deadZ  = where the dead unit was
    --
    -- Output:
    -- unitID of the best replacement target, or nil

    -- Get the guarder's current position
    local gx, _, gz = spGetUnitPosition(guarderID)
    if not gx then
        return nil
    end

    -- Try search circles from small to large
    for i = 1, #SEARCH_RADII do
        local radius = SEARCH_RADII[i]

        -- Ask engine:
        -- "Give me units within this sphere around the guarder"
        local nearby = spGetUnitsInSphere(gx, 0, gz, radius)

        local bestID = nil
        local bestScore = math.huge

        for j = 1, #nearby do
            local candidateID = nearby[j]

            -- We reject:
            --   - the guarder itself
            --   - the already dead unit
            --   - dead/invalid units
            --   - units not on our team
            --   - units of the wrong type
            if candidateID ~= guarderID
                and candidateID ~= deadTargetID
                and IsValidAliveUnit(candidateID)
                and spGetUnitTeam(candidateID) == myTeamID
                and spGetUnitDefID(candidateID) == wantedDefID
            then
                local cx, _, cz = spGetUnitPosition(candidateID)
                if cx then
                    -- Also require this candidate to be close enough
                    -- to where the dead unit was.
                    local allowed = true
                    if deadX and deadZ then
                        allowed = WithinRangeSq(deadX, deadZ, cx, cz, MAX_FROM_DEAD_TARGET)
                    end

                    if allowed then
                        -- Distance from guarder to candidate
                        local distGuardSq = DistSq(gx, gz, cx, cz)

                        -- Distance from dead target area to candidate
                        local distDeadSq = 0
                        if deadX and deadZ then
                            distDeadSq = DistSq(deadX, deadZ, cx, cz)
                        end

                        -- "Scaling logic":
                        -- lower score is better
                        -- this prefers units that are close to BOTH
                        -- the guarder and the dead target area
                        local score = distGuardSq + distDeadSq

                        if score < bestScore then
                            bestScore = score
                            bestID = candidateID
                        end
                    end
                end
            end
        end

        -- If we found a good one in the small radius,
        -- stop immediately and use it.
        if bestID then
            return bestID
        end
    end

    -- Nothing found in any radius
    return nil
end


local function RefreshGuardTracking()
    -- This re-checks all special guard units every UPDATE_FRAMES.
    -- It keeps guardData fresh and cleans up units that stopped guarding.

    local teamUnits = spGetTeamUnits(myTeamID)
    local stillAlive = {}

    for i = 1, #teamUnits do
        local unitID = teamUnits[i]

        if specialGuardUnits[unitID] then
            -- Remember that this special unit still exists
            stillAlive[unitID] = true

            -- Only look at the top command
            local cmds = spGetUnitCommands(unitID, 1)

            if cmds and cmds[1] and cmds[1].id == CMD_GUARD then
                local targetID = cmds[1].params and cmds[1].params[1]

                if IsValidAliveUnit(targetID) then
                    local targetDefID = spGetUnitDefID(targetID)

                    if targetDefID then
                        -- Save:
                        -- who this unit is guarding now
                        -- and what type that target is
                        guardData[unitID] = {
                            targetID = targetID,
                            targetDefID = targetDefID,
                        }
                    else
                        guardData[unitID] = nil
                    end
                else
                    guardData[unitID] = nil
                end
            else
                -- If this special unit is no longer actively guarding,
                -- stop tracking it.
                ClearTrackingForUnit(unitID)
            end
        end
    end

    -- Clean up special units that no longer exist on the team
    for unitID in pairs(specialGuardUnits) do
        if not stillAlive[unitID] then
            ClearTrackingForUnit(unitID)
        end
    end
end


----------------------------------------------------------------
-- 6) SPRING CALLINS
----------------------------------------------------------------

function widget:GameStart()
    gameStarted = true
    MaybeRemoveSelf()
end


function widget:PlayerChanged()
    MaybeRemoveSelf()
    myTeamID = spGetMyTeamID()
end


function widget:Initialize()
    -- If replay or already in game, maybe remove widget for spectators
    if spIsReplay() or spGetGameFrame() > 0 then
        if MaybeRemoveSelf() then
            return
        end
    end

    myTeamID = spGetMyTeamID()

    widgetHandler:AddAction(ACTION_NAME, ArmSpecialGuard, nil, "p")

    -- Move Flip Camera away from Alt+O
    -- so Alt+O is free for this widget
    RebindKeys()
end


function widget:Shutdown()
    widgetHandler:RemoveAction(ACTION_NAME)

    -- Put Flip Camera back when widget turns off
    RestoreKeys()
end


function widget:GameFrame(frame)
    -- Every UPDATE_FRAMES frames, refresh tracking
    if frame % UPDATE_FRAMES == 0 then
        RefreshGuardTracking()
    end
end


function widget:DrawScreen()
    if awaitingSpecialGuard then
        DrawArmedGuardCue()
    end
end


function widget:KeyPress(key, mods, isRepeat)
    -- Input:
    -- key      = which key was pressed
    -- mods     = table of modifier states, like mods.alt
    -- isRepeat = true if key is auto-repeating because held down
    --
    -- Output:
    -- true  = widget consumes this keypress
    -- false = widget does not care about this keypress

    if isRepeat then
        return false
    end

    -- If not O, ignore
    if key ~= KEY_O then
        return false
    end

    -- mods.alt means Alt is being held
    local alt = mods and mods.alt
    if not alt then
        return false
    end

    return ArmSpecialGuard()
end


function widget:MousePress(x, y, button)
    -- Input:
    -- x,y    = mouse screen coordinates
    -- button = mouse button number
    --
    -- We only want:
    --   special mode armed
    --   left click
    --   allied unit under cursor

    if not awaitingSpecialGuard then
        return false
    end

    -- Only left click should use the armed special guard
    if button ~= 1 then
        -- cancel armed state if player clicked something else
        awaitingSpecialGuard = false
        return false
    end

    -- One-shot mode: consume the armed state now
    awaitingSpecialGuard = false

    local selectedUnits = GetSelectedSpecialGuardUnits()
    if #selectedUnits == 0 then
        spEcho("[Guard Retarget] Canceled: no movable guard unit selected.")
        return false
    end

    -- Ask engine what is under the mouse.
    -- This returns:
    -- hitType = "unit", "ground", "feature", etc.
    -- hitData = usually the ID of that thing
    local hitType, hitData = spTraceScreenRay(x, y, false, true)

    if hitType ~= "unit" or not hitData then
        spEcho("[Guard Retarget] Canceled: click an allied unit.")
        return false
    end

    local targetID = hitData

    -- Only allied units can be special-guard targets
    if not spIsUnitAllied(targetID) then
        spEcho("[Guard Retarget] Canceled: target is not allied.")
        return false
    end

    -- Mark all selected units as special guard units
    for i = 1, #selectedUnits do
        local unitID = selectedUnits[i]
        specialGuardUnits[unitID] = true
        guardData[unitID] = nil
    end

    -- Issue a NORMAL guard order to the clicked allied unit
    --
    -- spGiveOrder(commandID, params, options)
    --
    -- commandID = CMD_GUARD
    -- params    = {targetID}
    -- options   = {}
    spGiveOrder(CMD_GUARD, {targetID}, {})

    -- true = we consumed this click
    return true
end


function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
    -- This fires when the player gives commands.
    --
    -- We use it to say:
    -- if selected units get some other command that is NOT Guard,
    -- then stop treating them as special guard units.

    if cmdID ~= CMD_GUARD then
        local selectedUnits = spGetSelectedUnits()

        if selectedUnits and #selectedUnits > 0 then
            for i = 1, #selectedUnits do
                local unitID = selectedUnits[i]

                if specialGuardUnits[unitID] then
                    ClearTrackingForUnit(unitID)
                end
            end
        end
    end

    return false
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    -- Input:
    -- unitID   = exact unit that died
    -- unitDefID= type of unit that died
    -- unitTeam = team of the dead unit

    -- Ignore enemies / non-allied teams
    if not spAreTeamsAllied(unitTeam, myTeamID) then
        return
    end

    -- Get where the dead unit was
    local deadX, _, deadZ = spGetUnitPosition(unitID)

    -- Check every special guard unit we are tracking
    for guarderID, data in pairs(guardData) do
        -- If this guarder was guarding the dead unit...
        if data.targetID == unitID then
            -- Make sure it is still safe to retarget
            if specialGuardUnits[guarderID] and CanRetargetGuardNow(guarderID, unitID) then
                local newTargetID = FindReplacementTarget(
                    guarderID,        -- who needs a new target
                    data.targetDefID, -- must be same unit type as dead target
                    unitID,           -- exact dead target
                    deadX,            -- dead target X
                    deadZ             -- dead target Z
                )

                if newTargetID then
                    -- Tell JUST this one guarder to guard the new target
                    --
                    -- spGiveOrderToUnit(unitID, commandID, params, options)
                    --
                    -- unitID    = guarderID
                    -- commandID = CMD_GUARD
                    -- params    = {newTargetID}
                    -- options   = {}
                    spGiveOrderToUnit(guarderID, CMD_GUARD, {newTargetID}, {})

                    -- Update our memory so we now track the new target
                    guardData[guarderID] = {
                        targetID = newTargetID,
                        targetDefID = data.targetDefID,
                    }
                else
                    -- No replacement found -> stop tracking
                    ClearTrackingForUnit(guarderID)
                end
            else
                -- Not safe anymore -> stop tracking
                ClearTrackingForUnit(guarderID)
            end
        end
    end
end
