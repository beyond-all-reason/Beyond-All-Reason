local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Frame Time Broadcast",
		desc = "Broadcasts per-client sim and draw frame times into the demo packet stream",
		author = "bruno-dasilva",
		date = "2026-04",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

local sendPacketEverySeconds = 2

local GetLastUpdateSeconds = Spring.GetLastUpdateSeconds
local GetProfilerTimeRecord = Spring.GetProfilerTimeRecord
local SendLuaRulesMsg = Spring.SendLuaRulesMsg

local updateTimer = 0
local simN, simSum, simPeak = 0, 0, 0
local drawN, drawSum, drawPeak = 0, 0, 0

-- `total` (1st return) is a monotonic accumulator of time spent in the zone,
-- the per-frame cost is the delta between two reads.
local prevSimTotal, prevDrawTotal

function gadget:GameFrame(_)
	local simTotal = GetProfilerTimeRecord("Sim", false)
	if prevSimTotal then
		local simFrame = simTotal - prevSimTotal
		simN = simN + 1
		simSum = simSum + simFrame
		if simFrame > simPeak then
			simPeak = simFrame
		end
	end
	prevSimTotal = simTotal
end

function gadget:Update()
	updateTimer = updateTimer + GetLastUpdateSeconds()

	local drawTotal = GetProfilerTimeRecord("Draw", false)
	if prevDrawTotal then
		local drawFrame = drawTotal - prevDrawTotal
		drawN = drawN + 1
		drawSum = drawSum + drawFrame
		if drawFrame > drawPeak then
			drawPeak = drawFrame
		end
	end
	prevDrawTotal = drawTotal

	if updateTimer > sendPacketEverySeconds then
		local avgSim = simN > 0 and (simSum / simN) or 0
		local avgDraw = drawN > 0 and (drawSum / drawN) or 0
		SendLuaRulesMsg(string.format("#ft%d/%d/%.1f/%.1f/%.1f/%.1f", simN, drawN, avgSim, simPeak, avgDraw, drawPeak))
		updateTimer = 0
		simN, simSum, simPeak = 0, 0, 0
		drawN, drawSum, drawPeak = 0, 0, 0
	end
end
