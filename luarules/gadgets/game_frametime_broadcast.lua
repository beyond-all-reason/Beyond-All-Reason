local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Frame Time Broadcast",
		desc    = "Broadcasts per-client sim and draw frame times into the demo packet stream",
		author  = "bruno-dasilva",
		date    = "2026-04",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then return end

local sendPacketEverySeconds = 2

local GetLastUpdateSeconds  = Spring.GetLastUpdateSeconds
local GetProfilerTimeRecord = Spring.GetProfilerTimeRecord
local SendLuaRulesMsg       = Spring.SendLuaRulesMsg

local updateTimer = 0
local simN,  simSum,  simPeak  = 0, 0, 0
local drawN, drawSum, drawPeak = 0, 0, 0

function gadget:GameFrame(_)
	local _, simCurrent = GetProfilerTimeRecord("Sim", false)
	simN   = simN + 1
	simSum = simSum + simCurrent
	if simCurrent > simPeak then simPeak = simCurrent end
end

function gadget:Update()
	updateTimer = updateTimer + GetLastUpdateSeconds()

	local _, drawCurrent = GetProfilerTimeRecord("Draw", false)
	drawN   = drawN + 1
	drawSum = drawSum + drawCurrent
	if drawCurrent > drawPeak then drawPeak = drawCurrent end

	if updateTimer > sendPacketEverySeconds then
		local avgSim  = simN  > 0 and (simSum  / simN)  or 0
		local avgDraw = drawN > 0 and (drawSum / drawN) or 0
		SendLuaRulesMsg(string.format("#ft%d/%d/%.1f/%.1f/%.1f/%.1f",
			simN, drawN, avgSim, simPeak, avgDraw, drawPeak))
		updateTimer = 0
		simN,  simSum,  simPeak  = 0, 0, 0
		drawN, drawSum, drawPeak = 0, 0, 0
	end
end
