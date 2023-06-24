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

local unbacoms = {
    [UnitDefNames["corcom"].id] = true,
    [UnitDefNames["armcom"].id] = true,
}

local aliveUnbaComs = {}

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

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
    if aliveUnbaComs[unitID] and attackerID and unitTeam ~= attackerTeam and select(6, Spring.GetTeamInfo(unitTeam)) ~= select(6, Spring.GetTeamInfo(attackerTeam)) then
        local curHealth, maxHealth = Spring.GetUnitHealth(unitID)
        Spring.SetUnitExperience(unitID, Spring.GetUnitExperience(unitID)+(0.005*(damage/curHealth)))
        --Spring.Echo("Added " .. (0.005*(damage/curHealth)) .. "XP from taking damage", frame)
    end
end

function gadget:GameFrame(frame)
    if frame%30 == 12 then
        for unitID, _ in pairs(aliveUnbaComs) do
            if Spring.GetUnitCurrentBuildPower(unitID) > 0 then
                Spring.SetUnitExperience(unitID, Spring.GetUnitExperience(unitID)+(0.0002*Spring.GetUnitCurrentBuildPower(unitID)))
                --Spring.Echo("Added " .. (0.0002*Spring.GetUnitCurrentBuildPower(unitID)) .. "XP from buildpower", frame)
            end
            local velx, vely, velz = Spring.GetUnitVelocity(unitID)
            if velx > 0 or velz > 0 or vely > 0 then
                Spring.SetUnitExperience(unitID, Spring.GetUnitExperience(unitID)+0.0001)
                --Spring.Echo("Added " .. 0.0001 .. "XP from walking", frame)
            end
            if Spring.GetUnitNearestEnemy(unitID, 1500) then
                Spring.SetUnitExperience(unitID, Spring.GetUnitExperience(unitID)+0.0001)
                --Spring.Echo("Added " .. 0.0001 .. "XP from nearby enemy", frame)
            end
        end
    end
end