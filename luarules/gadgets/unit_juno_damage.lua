
function gadget:GetInfo()
    return {
        name      = 'Juno Damage',
        desc      = 'Handles Juno damage',
        author    = 'Niobium',
        version   = 'v1.0',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
    return false
end

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local radarUnits = {
    [UnitDefNames.armarad.id] = true,
    [UnitDefNames.armaser.id] = true,
    [UnitDefNames.armason.id] = true,
    [UnitDefNames.armeyes.id] = true,
    [UnitDefNames.armfrad.id] = true,
    [UnitDefNames.armjam.id] = true,
    [UnitDefNames.armjamt.id] = true,
    [UnitDefNames.armmark.id] = true,
    [UnitDefNames.armrad.id] = true,
    [UnitDefNames.armseer.id] = true,
    [UnitDefNames.armsjam.id] = true,
    [UnitDefNames.armsonar.id] = true,
    [UnitDefNames.armveil.id] = true,
    [UnitDefNames.corarad.id] = true,
    [UnitDefNames.corason.id] = true,
    [UnitDefNames.coreter.id] = true,
    [UnitDefNames.coreyes.id] = true,
    [UnitDefNames.corfrad.id] = true,
    [UnitDefNames.corjamt.id] = true,
    [UnitDefNames.corrad.id] = true,
    [UnitDefNames.corshroud.id] = true,
    [UnitDefNames.corsjam.id] = true,
    [UnitDefNames.corsonar.id] = true,
    [UnitDefNames.corspec.id] = true,
    [UnitDefNames.corvoyr.id] = true,
    [UnitDefNames.corvrad.id] = true,
}

local junoWeapons = {
    [WeaponDefNames.ajuno_juno_pulse.id] = true,
    [WeaponDefNames.cjuno_juno_pulse.id] = true,
}

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spDestroyUnit = Spring.DestroyUnit

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:UnitDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, aID, aDefID, aTeam)
    if junoWeapons[weaponID] and radarUnits[uDefID] then
        spDestroyUnit(uID, false, false, aID)
    end
end
