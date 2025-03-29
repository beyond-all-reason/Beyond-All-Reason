local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = "Unit Capture Decay",
        desc = "Decays capture progress if there was none done over the past 10 seconds",
        author = "Damgam",
        date = "2024",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local unitsWithCaptureProgress = {}

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    unitsWithCaptureProgress[unitID] = nil
end

function gadget:GameFrame(frame)
    for unitID, data in pairs(unitsWithCaptureProgress) do
        if unitID%30 == frame%30 then
            local captureLevel = select(4, Spring.GetUnitHealth(unitID))
            if captureLevel and captureLevel > 0 then
                if captureLevel <= data.previousCaptureProgress then
                    unitsWithCaptureProgress[unitID].ticksFromLastCapture = unitsWithCaptureProgress[unitID].ticksFromLastCapture+1
                else
                    unitsWithCaptureProgress[unitID].ticksFromLastCapture = 0
                    SendToUnsynced("unitCaptureFrame", unitID, math.max(captureLevel, 0))
                end
                unitsWithCaptureProgress[unitID].previousCaptureProgress = captureLevel
                if unitsWithCaptureProgress[unitID].ticksFromLastCapture >= 10 then -- with how things are set up, that will be about 10 seconds
                    Spring.SetUnitHealth(unitID, {capture = math.max(captureLevel-((unitsWithCaptureProgress[unitID].ticksFromLastCapture-10)*0.001), 0)})
                end
            else
                unitsWithCaptureProgress[unitID] = nil
            end
        end
    end
end


function gadget:AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part)
    if not unitsWithCaptureProgress[unitID] then
        unitsWithCaptureProgress[unitID] = {previousCaptureProgress = 0, ticksFromLastCapture = 999}
    end
    return true
end

function addUnitToCaptureDecay(unitID)
    if not unitsWithCaptureProgress[unitID] then
        unitsWithCaptureProgress[unitID] = {previousCaptureProgress = 0, ticksFromLastCapture = 999}
    end
end

GG.addUnitToCaptureDecay = addUnitToCaptureDecay