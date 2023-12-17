function gadget:GetInfo()
	return {
		name      = "Unba XP Bonuses",
		version   = "1",
		desc      = "",
		author    = "Damgam",
		date      = "2023",
		license   = "GNU GPL, v2 or later",
		layer     = -1,
		enabled   = Spring.GetModOptions().unba,
	}
end

-- synced only
if not (gadgetHandler:IsSyncedCode()) then
	return false
end

VFS.Include("unbaconfigs/stats.lua")

local unbacoms = {
    [UnitDefNames["corcom"].id] = true,
    [UnitDefNames["armcom"].id] = true,
    [UnitDefNames["cordecom"].id] = true,
    [UnitDefNames["armdecom"].id] = true,
    [UnitDefNames["legcom"].id] = true,
    [UnitDefNames["legcomlvl2"].id] = true,
    [UnitDefNames["legcomlvl3"].id] = true,
    [UnitDefNames["legcomlvl4"].id] = true,
}

local unbaRanks = {
	[1] = 0,
	[2] = 2,
	[3] = 5,
	[4] = 9,
	[5] = 15,
	[6] = 23,
	[7] = 32,
	[8] = 42,
	[9] = 54,
	[10] = 68,
	[11] = 83,
	[12] = 99,
	[13] = 117,
	[14] = 137,
	[15] = 158,
	[16] = 180,
	[17] = 204,
	[18] = 230,
}

local aliveUnbaComs = {}
local topCommanderXP = 0

local function getTopCommanderXP()
    local topXP = 0
    for unitID, _ in pairs(aliveUnbaComs) do
        local thisXP = Spring.GetUnitExperience(unitID)
        if thisXP > topXP then
            topXP = thisXP
        end
    end
    return topXP
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if unbacoms[unitDefID] then
        aliveUnbaComs[unitID] = true
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
    if unbacoms[unitDefID] then
        aliveUnbaComs[unitID] = nil
    end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
    if aliveUnbaComs[unitID] then
        local unbaCurrentRank = 1
        for i = 2,#unbaRanks do
            if unbaRanks[i] >= Spring.GetUnitExperience(unitID)*100 then
                break
            else
                unbaCurrentRank = i
            end
        end
        damage = damage * DamageMultiplierNoDgun[unbaCurrentRank]
    end
    return damage, 1
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
    if aliveUnbaComs[unitID] and attackerID and unitTeam ~= attackerTeam and select(6, Spring.GetTeamInfo(unitTeam)) ~= select(6, Spring.GetTeamInfo(attackerTeam)) then
        local curHealth, maxHealth = Spring.GetUnitHealth(unitID)
        local xpDifferenceToTop = topCommanderXP - Spring.GetUnitExperience(unitID)
        curHealth = math.max(curHealth, maxHealth*0.2)
        Spring.SetUnitExperience(unitID, Spring.GetUnitExperience(unitID)+((0.01*(damage/curHealth))*(1+xpDifferenceToTop)))
    end
end

function gadget:GameFrame(frame)
    if frame%30 == 12 then
        for unitID, _ in pairs(aliveUnbaComs) do
            local xpDifferenceToTop = topCommanderXP - Spring.GetUnitExperience(unitID)
            if Spring.GetUnitCurrentBuildPower(unitID) > 0 then
                Spring.SetUnitExperience(unitID, Spring.GetUnitExperience(unitID)+((0.0004*Spring.GetUnitCurrentBuildPower(unitID))*(1+xpDifferenceToTop)))
            end
            local velx, vely, velz = Spring.GetUnitVelocity(unitID)
            if velx > 0 or velz > 0 or vely > 0 then
                Spring.SetUnitExperience(unitID, Spring.GetUnitExperience(unitID)+((0.00005)*(1+xpDifferenceToTop)))
            end
            if Spring.GetUnitNearestEnemy(unitID, 1500) then
                Spring.SetUnitExperience(unitID, Spring.GetUnitExperience(unitID)+((0.0001)*(1+xpDifferenceToTop)))
            end
        end

        topCommanderXP = getTopCommanderXP()
    end
end