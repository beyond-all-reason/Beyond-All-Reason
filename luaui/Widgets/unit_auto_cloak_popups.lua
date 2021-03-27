function widget:GetInfo()
    return {
        name      = "Auto Cloak Popups",
        desc      = "Auto cloaks Pit Bull and Ambusher",
        author    = "[teh]decay",
        date      = "29 dec 2013",
        layer     = 0,
        enabled   = false  -- loaded by default
    }
end

local CMD_CLOAK = 37382

local cloakingUnitDefs = {[UnitDefNames["armpb"].id]=true, [UnitDefNames["armamb"].id]=true}
local cloakunits = {}
local gameStarted

function widget:UnitFinished(unitID, unitDefID, unitTeam)
    if cloakingUnitDefs[unitDefID] then
        cloakunits[unitID] = true
        Spring.GiveOrderToUnit(unitID, CMD_CLOAK, {1}, 0)
    end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if cloakunits[unitID] then
        cloakunits[unitID] = nil
    end
end

function widget:UnitCreated(unitID, unitDefID, teamID, builderID)
    if cloakingUnitDefs[unitDefID] then
        cloakunits[unitID] = true
        Spring.GiveOrderToUnit(unitID, CMD_CLOAK, {1}, 0)
    end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    if cloakingUnitDefs[unitDefID] then
        cloakunits[unitID] = true
        Spring.GiveOrderToUnit(unitID, CMD_CLOAK, {1}, 0)
    end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if cloakingUnitDefs[unitDefID] then
        cloakunits[unitID] = true
        Spring.GiveOrderToUnit(unitID, CMD_CLOAK, {1}, 0)
    end
end

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget(self)
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

--function addCloakingUnits()
--    local visibleUnits = spGetAllUnits()
--    if visibleUnits ~= nil then
--        for _, unitID in ipairs(visibleUnits) do
--            local udefId = GetUnitDefID(unitID)
--            if udefId ~= nil then
--                if cloakingUnitDefs[udefId] then
--                    cloakunits[unitID] = true
--                    cloakUnit(unitID, udefId)
--                end
--            end
--        end
--    end
--end
