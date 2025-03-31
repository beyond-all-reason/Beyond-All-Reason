
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Nano Radar Pos",
        desc      = "Removes radar icon wobble for nanos since these units are technically not buildings (no yardmap)",
        author    = "Floris",
        date      = "November 2019",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end


if (gadgetHandler:IsSyncedCode()) then

    local isNano = {}
    for unitDefID, defs in pairs(UnitDefs) do
        if string.find(defs.name, "nanotc") then
            isNano[unitDefID] = true
        end
    end

    function gadget:UnitCreated(uid, udid)
        if isNano[udid] then
            Spring.SetUnitPosErrorParams(udid, 0,0,0, 0,0,0, math.huge)
        end
    end

end
