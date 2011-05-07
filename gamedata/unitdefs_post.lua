
-- Get modoptions (with some backwards compatibility)
local modOptions = Spring.GetModOptions and Spring.GetModOptions() or {}

-- Loop over unit defs
for unitName, unitDef in pairs(UnitDefs) do  
    
    -- Minimum build distance
    if unitDef.builddistance and unitDef.builddistance < 128 then
        unitDef.builddistance = 128
    end
end
