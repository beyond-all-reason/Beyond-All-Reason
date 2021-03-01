-- Remember to turn off engine xp bonuses
local gadgetEnabled = Spring.GetModOptions().experimentalxpsystem or "disabled" == "disabled"
if gadgetEnabled == "disabled" then
    gadgetEnabled = false
elseif gadgetEnabled == "enabled" then
    gadgetEnabled = true
else
    gadgetEnabled = false
end

XPLevel = {}

function gadget:GetInfo()
	return {
		name 	= "Unit XP Gadget",
		desc	= "Gadget based XP implementation that gives way more flexibility than engine one",
		author	= "Damgam",
		date	= "2021",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = gadgetEnabled,
	}
end

-- Generate levels table
levelsScale = 10 -- xp for each level
levelsCurrentExponent = 1 -- initial exponent multiplier
levelsExponent = 0.5 -- how much does the exponent multiplier increase with each level
levelsCount = 20
levelsTable = {}
for i = 1,levelsCount do
    --local level = i*levelsScale
    if i > 1 then
        local level = (math.ceil((math.ceil((i-1)*levelsScale*levelsCurrentExponent))/5))*5
        levelsCurrentExponent = levelsCurrentExponent+levelsExponent
        table.insert(levelsTable, level)
    elseif i == 1 then
        table.insert(levelsTable, 0)
    end
end

-- Levels check
for i = 1,#levelsTable do
    local level = levelsTable[i]
    if i == 1 then
        Spring.Echo("Gadget XP Level table")
    end
    Spring.Echo("Level "..i..": "..level.." xp.")
end


-- numbers mean % bonus from previous level. negative number = nerf, positive number = buff,
defaultConfig = {
    health = 10,            -- done
    reloadTime = 10,        -- done
    weaponDamage = 0,       -- not implemented yet
    weaponRange = 0,        -- not implemented yet
    maxSpeed = 0,           -- not implemented yet
    acceleration = 0,       -- not implemented yet (also affects braking)
    turnRate = 0,           -- not implemented yet
}

unitConfigs = { -- missing values default to 0
    -- example:
    -- armpw = {maxSpeed = 10, turnRate = 10,}

}

function ApplyBonuses(unitID, level)
    local oldLevel = XPLevel[unitID]
    local newLevel = oldLevel + 1
    local unitDefID = Spring.GetUnitDefID(unitID)
    local unitName = UnitDefs[unitDefID].name
    if unitConfigs[unitName] then
        
        if unitConfigs[unitName].health then
            local curhealth, curmaxhealth = Spring.GetUnitHealth(unitID)
            Spring.SetUnitMaxHealth(unitID, curmaxhealth*(1+(unitConfigs[unitName].health*0.01)))
            Spring.SetUnitHealth(unitID, curhealth*(1+(unitConfigs[unitName].health*0.01)))
        end

        local weapons = UnitDefs[unitDefID].weapons
        if weapons then
            for i = 1,#weapons do
                
                if unitConfigs[unitName].reloadTime then
                    local weaponReloadTime = Spring.GetUnitWeaponState(unitID, i, "reloadTime")
                    Spring.SetUnitWeaponState(unitID, i, "reloadTime", weaponReloadTime*(1-(unitConfigs[unitName].reloadTime*0.01)))
                end

            end
        end

    else
        
        if defaultConfig.health ~= 0 then
            local curhealth, curmaxhealth = Spring.GetUnitHealth(unitID)
            Spring.SetUnitMaxHealth(unitID, curmaxhealth*(1+(defaultConfig.health*0.01)))
            Spring.SetUnitHealth(unitID, curhealth*(1+(defaultConfig.health*0.01)))
        end

        local weapons = UnitDefs[unitDefID].weapons
        if weapons then
            for i = 1,#weapons do
                
                if defaultConfig.reloadTime ~= 0 then
                    local weaponReloadTime = Spring.GetUnitWeaponState(unitID, i, "reloadTime")
                    Spring.SetUnitWeaponState(unitID, i, "reloadTime", weaponReloadTime*(1-(defaultConfig.reloadTime*0.01)))
                end

            end
        end

    end
    
    

    local posx, posy, posz = Spring.GetUnitPosition(unitID)
    local footprintx = UnitDefs[unitDefID].footprintx
    local footprintz = UnitDefs[unitDefID].footprintz
    if footprintx and footprintz then
        if (footprintx >= footprintz) then
            if footprintx == 0 then
                Spring.SpawnCEG("levelup_fp3",posx,posy,posz,0,0,0)
            elseif footprintx == 1 then
                Spring.SpawnCEG("levelup_fp1",posx,posy,posz,0,0,0)
            elseif footprintx == 2 then
                Spring.SpawnCEG("levelup_fp2",posx,posy,posz,0,0,0)
            elseif footprintx == 3 then
                Spring.SpawnCEG("levelup_fp3",posx,posy,posz,0,0,0)
            elseif footprintx == 4 then
                Spring.SpawnCEG("levelup_fp4",posx,posy,posz,0,0,0)
            elseif footprintx >= 5 then
                Spring.SpawnCEG("levelup_fp5",posx,posy,posz,0,0,0)
            end

        elseif footprintx < footprintz then
            if footprintz == 0 then
                Spring.SpawnCEG("levelup_fp3",posx,posy,posz,0,0,0)
            elseif footprintz == 1 then
                Spring.SpawnCEG("levelup_fp1",posx,posy,posz,0,0,0)
            elseif footprintz == 2 then
                Spring.SpawnCEG("levelup_fp2",posx,posy,posz,0,0,0)
            elseif footprintz == 3 then
                Spring.SpawnCEG("levelup_fp3",posx,posy,posz,0,0,0)
            elseif footprintz == 4 then
                Spring.SpawnCEG("levelup_fp4",posx,posy,posz,0,0,0)
            elseif footprintz >= 5 then
                Spring.SpawnCEG("levelup_fp5",posx,posy,posz,0,0,0)
            end
        end
    else
        Spring.SpawnCEG("levelup_fp3",posx,posy,posz,0,0,0)
    end
    XPLevel[unitID] = newlevel
end


if gadgetHandler:IsSyncedCode() then -- Synced part
    function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
        XPLevel[unitID] = 1
    end
    function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
        XPLevel[unitID] = nil 
    end

    function gadget:GameFrame(n)
        units = Spring.GetAllUnits()
        for i = 1,#units do
            local unitID = units[i]
            if unitID%30 == n%30 then
                local xp = Spring.GetUnitExperience(unitID)
                local level = XPLevel[unitID]
                if level and xp > levelsTable[level + 1] then
                    ApplyBonuses(unitID, level)
                end
            end
        end
    end





else -- Unsynced part


end