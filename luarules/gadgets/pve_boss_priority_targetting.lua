function gadget:GetInfo()
    return {
        name = "Raptor Queen Anti-Dgun behavior",
        desc = "Queen will prioritize targetting nearby commander so it doesn't let itself be dgunned",
        author = "Damgam",
        date = "2023",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local queenUnits = {
    [UnitDefNames["raptor_queen_veryeasy"].id] = true,
    [UnitDefNames["raptor_queen_easy"].id] = true,
    [UnitDefNames["raptor_queen_normal"].id] = true,
    [UnitDefNames["raptor_queen_hard"].id] = true,
    [UnitDefNames["raptor_queen_veryhard"].id] = true,
    [UnitDefNames["raptor_queen_epic"].id] = true,
    
    [UnitDefNames["raptor_matriarch_spectre"].id] = true,
	[UnitDefNames["raptor_matriarch_electric"].id] = true,
	[UnitDefNames["raptor_matriarch_acid"].id] = true,
	[UnitDefNames["raptor_matriarch_healer"].id] = true,
	[UnitDefNames["raptor_matriarch_basic"].id] = true,
	[UnitDefNames["raptor_matriarch_fire"].id] = true,

    [UnitDefNames["armscavengerbossv2_veryeasy"].id] = true,
    [UnitDefNames["armscavengerbossv2_easy"].id] = true,
    [UnitDefNames["armscavengerbossv2_normal"].id] = true,
    [UnitDefNames["armscavengerbossv2_hard"].id] = true,
    [UnitDefNames["armscavengerbossv2_veryhard"].id] = true,
    [UnitDefNames["armscavengerbossv2_epic"].id] = true,
}

local queenTargets = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.customParams.iscommander then
        queenTargets[unitDefID] = true
    end
end


local aliveQueens = {}
local aliveTargets = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if queenUnits[unitDefID] then
        aliveQueens[unitID] = true
    end
    if queenTargets[unitDefID] then
        aliveTargets[unitID] = true
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if aliveQueens[unitID] then
        aliveQueens[unitID] = nil
    end
    if aliveTargets[unitID] then
        aliveTargets[unitID] = nil
    end
end

function gadget:GameFrame(frame)
    if frame%30 == 21 then
        for queenID, _ in pairs(aliveQueens) do
            local queenx,queeny,queenz = Spring.GetUnitPosition(queenID)
            local surroundingUnits = Spring.GetUnitsInSphere(queenx, queeny, queenz, 750)
            for i = 1,#surroundingUnits do
                if aliveTargets[surroundingUnits[i]] then
                    Spring.GiveOrderToUnit(queenID, CMD.STOP, 0, 0)
                    Spring.GiveOrderToUnit(queenID, CMD.ATTACK, {surroundingUnits[i]}, 0)
                    break
                end
            end
        end
    end
end