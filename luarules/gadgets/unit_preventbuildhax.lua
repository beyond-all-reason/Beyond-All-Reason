local enablegadget = false
if Spring.GetModOptions and Spring.GetModOptions().unba then
    enablegadget = true
end

function gadget:GetInfo()
    return {
        name	= "Prevent build Hax",
        desc	= "Prevents the use of widgets to build disabled buildoptions",
        author	= "Doo",
        date	= "2018-01-23",
        license	= "GNU GPL, v2 or later",
        layer	= 0,
        enabled	= enablegadget,
    }
end

local com = {}
com[UnitDefNames["armcom"].id] = true
com[UnitDefNames["corcom"].id] = true

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID)
    if com[unitDefID] then
        local cmdIndex = Spring.FindUnitCmdDesc(unitID, cmdID)
        local cmdArrays = Spring.GetUnitCmdDescs(unitID, cmdIndex, cmdIndex)
        local cmdArray = cmdArrays[1]
        if cmdID < 0 and cmdArray.disabled == true then
            return false
        else
            return true
        end
    else
        return true
    end
end