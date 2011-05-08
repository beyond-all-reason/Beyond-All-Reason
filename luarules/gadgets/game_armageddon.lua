
function gadget:GetInfo()
    return {
        name      = 'Armageddon',
        desc      = 'Implements armageddon modoption',
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
-- Load?
----------------------------------------------------------------
local armageddonFrame = 1800 * (tonumber((Spring.GetModOptions() or {}).mo_armageddontime) or 0)

if armageddonFrame <= 0 then
    return false
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:GameFrame(n)
    if n >= armageddonFrame then
        local allUnits = Spring.GetAllUnits()
        for i = 1, #allUnits do
            Spring.DestroyUnit(allUnits[i], true)
        end
    end
end
