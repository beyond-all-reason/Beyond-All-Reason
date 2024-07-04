if not Spring.Utilities.Gametype.IsScavengers() then
	return false
end

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

local aliveUnits = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    aliveUnits[unitID] = {previousCaptureProgress = 0, ticksFromLastCapture = 999}
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    aliveUnits[unitID] = nil
end

function gadget:GameFrame(frame)
    for unitID, data in pairs(aliveUnits) do
        if unitID%30 == frame%30 then
            local captureLevel = select(4, Spring.GetUnitHealth(unitID))
            if captureLevel > 0 then
                if captureLevel <= data.previousCaptureProgress then
                    aliveUnits[unitID].ticksFromLastCapture = aliveUnits[unitID].ticksFromLastCapture+1
                    SendToUnsynced("unitCaptureFrame", unitID, math.max(captureLevel, 0))
                else
                    aliveUnits[unitID].ticksFromLastCapture = 0
                    SendToUnsynced("unitCaptureFrame", unitID, math.max(captureLevel, 0))
                end
                aliveUnits[unitID].previousCaptureProgress = captureLevel
                if aliveUnits[unitID].ticksFromLastCapture >= 10 then -- with how things are set up, that will be about 10 seconds
                    Spring.SetUnitHealth(unitID, {capture = math.max(captureLevel-((aliveUnits[unitID].ticksFromLastCapture-10)*0.001), 0)})
                    SendToUnsynced("unitCaptureFrame", unitID, math.max(captureLevel-((aliveUnits[unitID].ticksFromLastCapture-10)*0.001), 0))
                end
            end
        end
    end
end