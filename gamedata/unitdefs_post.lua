
-- Get modoptions (with some backwards compatibility)
local modOptions = Spring.GetModOptions and Spring.GetModOptions() or {}

-- Loop over unit defs
for unitName, unitDef in pairs(UnitDefs) do  
    
    -- Com storage
    if unitName == 'armcom' or unitName == 'corcom' then
        unitDef.energystorage = modOptions.startenergy or 1000
        unitDef.metalstorage = modOptions.startmetal or 1000
    end
    
    -- Minimum build distance
    if unitDef.builddistance and unitDef.builddistance < 128 then
        unitDef.builddistance = 128
    end
    
    -- Boost terraform speed
    unitDef.terraformspeed = 5 * (unitDef.workertime or 0)
end
