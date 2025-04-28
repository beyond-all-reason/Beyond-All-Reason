
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Stun Script",
        desc      = "makes unit stun status known to unit scripts",
        author    = "Floris",
        date      = "April 2020",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local stunnedUnits = {}

local hasSetStunned = {}
for udid, ud in pairs(UnitDefs) do
    if ud.customParams.paralyzemultiplier == 0 then
        hasSetStunned[udid] = false
    end
end

local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spCallCOBScript = Spring.CallCOBScript
local spGetCOBScriptID = Spring.GetCOBScriptID

function gadget:GameFrame(n)
    -- check if stunned units have become deparalyzed
    if n % 10 == 3 then
        for unitID, _ in pairs(stunnedUnits) do
            if not select(2, spGetUnitIsStunned(unitID)) then
                stunnedUnits[unitID] = nil
                spCallCOBScript(unitID, 'SetStunned', 0, false)
            end
        end
    end
end

function gadget:Initialize()
    for i, unitID in pairs(Spring.GetAllUnits()) do
        gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if hasSetStunned[unitDefID] == nil then
        hasSetStunned[unitDefID] = spGetCOBScriptID(unitID, 'SetStunned') and true or false
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if stunnedUnits[unitDefID] then
        stunnedUnits[unitID] = nil
	end
end

function gadget:UnitDamaged(unitID,unitDefID,unitTeam,damage,paralyzer,weaponDefID,projectileID,attackerID,attackerDefID,attackerTeam)
    if paralyzer and hasSetStunned[unitDefID] then
        if select(2, spGetUnitIsStunned(unitID)) then
            stunnedUnits[unitID] = true
            spCallCOBScript(unitID, 'SetStunned', 0, true)
        end
    end
end
