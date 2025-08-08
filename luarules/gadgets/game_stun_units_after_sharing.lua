local gadget = gadget ---@type Gadget
function gadget:GetInfo()
    return {
        name    = 'Stun shared units',
        desc    = 'Stun units when they are shared to another team',
        author  = 'Hobo Joe, NortySpock',
        date    = 'August 2025',
        license = 'GNU GPL, v2 or later',
        layer   = 3,  -- the "Disable Unit Sharing" gadget has higher priority
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end


local stunnedUnits = {}
local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitHealth = Spring.SetUnitHealth
local spGiveOrderToUnit = Spring.GiveOrderToUnit


function gadget:AllowUnitTransfer(unitID, _, _, _, _)
	-- 5 seconds at 30 sim-frames-per-wall-clock-second
	local inputStunTime = 150
	local health, maxHealth, paralyzeDamage, captureProgress = spGetUnitHealth(unitID)
	local stunDuration = maxHealth + inputStunTime
	local updatedStunDuration = math.max(paralyzeDamage, stunDuration)
    stunnedUnits[unitID] = { stunTime = inputStunTime }
	spSetUnitHealth(unitID, {paralyze = updatedStunDuration})
	spGiveOrderToUnit(unitID, CMD.STOP, {}, 0)
    return true
end

function gadget:AllowCommand(unitID, _, _, _, _, _, _, _, _, _)
    if stunnedUnits[unitID] then
        return false
    end
    return true
end

function gadget:GameFrame(n)
    for unitId, data in pairs(stunnedUnits) do
        if data.stunTime and data.stunTime > 1 then
            data.stunTime = data.stunTime - 1
        else
            stunnedUnits[unitId] = nil
        end
    end
end