function gadget:GetInfo()
	return {
		name    = "Unit Scale",
		desc    = "Scale all units",
		author  = "Floris",
		date    = "January 2022",
		license = "GNU LGPL, v2.1 or later",
		layer   = 0,
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

local updateTimer = 0

local glScale = gl.Scale
local spurSetUnitLuaDraw  = Spring.UnitRendering.SetUnitLuaDraw
local unitScale = tonumber(Spring.GetConfigFloat('unitScale', 1) or 1)

function gadget:UnitCreated(unitID, unitDefID, team)
	if unitScale ~= 1 then
		spurSetUnitLuaDraw(unitID, true)
	end
end

local function init()
	unitScale = tonumber(Spring.GetConfigFloat('unitScale', 1) or 1)
	if unitScale ~= 1 then
		local allUnits = Spring.GetAllUnits()
		for i = 1, #allUnits do
			spurSetUnitLuaDraw(allUnits[i], false)
		end
		for i = 1, #allUnits do
			gadget:UnitCreated(allUnits[i], Spring.GetUnitDefID(allUnits[i]), Spring.GetUnitTeam(allUnits[i]))
		end
	else
		gadget:Shutdown()
	end
end

function gadget:Update()
	updateTimer = updateTimer + Spring.GetLastUpdateSeconds()
	if updateTimer > 0.6 then
		updateTimer = 0
		if unitScale ~= Spring.GetConfigFloat('unitScale', 1) then
			unitScale = Spring.GetConfigFloat('unitScale', 1)
			init()
		end
	end
end

function gadget:Initialize()
	init()
end

function gadget:Shutdown()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		spurSetUnitLuaDraw(allUnits[i], false)
	end
end

function gadget:DrawUnit(unitID, drawMode)
	glScale(unitScale, unitScale, unitScale)
	return false
end
