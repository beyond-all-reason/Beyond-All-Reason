function gadget:GetInfo()
	return {
		name    = "Unit Rotation",
		desc    = "Rotate all buildings slightly randomly (visually only))",
		author  = "Floris",
		date    = "May 2021",
		license = "GNU LGPL, v2.1 or later",
		layer   = 0,
		enabled = true
	}
end

-- decals dont rotate along
-- cloaked units arent rendered, so have to be skipped
-- factories still produce non rotated units
-- wreckage dont inherit rotation (but is possible via method in unit_rez_xp.lua)
-- other gadgets/widgets dont know the active rotation value per unit

if gadgetHandler:IsSyncedCode() then
	return
end

local maxRotation = tonumber(Spring.GetConfigInt('unitRotation', 0) or 0)
local maxAllowedRotation = 10

local unitRotation = {}

local glRotate = gl.Rotate
local spurSetUnitLuaDraw  = Spring.UnitRendering.SetUnitLuaDraw

local rotateUnitDefs = {}
local limitedRotation = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if (unitDef.isBuilding or string.find(unitDef.name, "nanotc")) and not unitDef.canCloak then
		-- reduce rotation for larger buildings
		rotateUnitDefs[unitDefID] = 1 / math.max(1, math.max(unitDef.xsize-2, unitDef.zsize-2) * 0.2)

		-- limit rotation for factories
		if unitDef.isFactory and #unitDef.buildOptions > 0 then
			rotateUnitDefs[unitDefID] = rotateUnitDefs[unitDefID] * 0.5
			limitedRotation[unitDefID] = 4
		end
		-- limit rotation for winds/tidals
		if unitDef.tidalGenerator > 0 or unitDef.windGenerator > 0 then
			rotateUnitDefs[unitDefID] = rotateUnitDefs[unitDefID] * 0.5
			limitedRotation[unitDefID] = 4
		end
		-- nanos
		if string.find(unitDef.name, "nanotc") then
			rotateUnitDefs[unitDefID] = rotateUnitDefs[unitDefID] * 0.5
			limitedRotation[unitDefID] = 4
		end
		-- unit with weapons
		if #unitDef.weapons > 0 then
			rotateUnitDefs[unitDefID] = rotateUnitDefs[unitDefID] * 0.5
			limitedRotation[unitDefID] = 3
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, team)
	if maxRotation > 0 and rotateUnitDefs[unitDefID] then
		unitRotation[unitID] = (((unitID%(200))-100) * rotateUnitDefs[unitDefID]) * (maxRotation/100)
		if limitedRotation[unitDefID] then
			if unitRotation[unitID] > limitedRotation[unitDefID] then
				unitRotation[unitID] = limitedRotation[unitDefID]
			elseif unitRotation[unitID] < -limitedRotation[unitDefID] then
				unitRotation[unitID] = -limitedRotation[unitDefID]
			end
		end
		spurSetUnitLuaDraw(unitID, true)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, team)
	unitRotation[unitID] = nil
end

local function init()
	maxRotation = tonumber(Spring.GetConfigInt('unitRotation', 0) or 0)
	if maxRotation <= 0 then
		for unitID, rot in pairs(unitRotation) do
			spurSetUnitLuaDraw(unitID, false)
		end
	end
	unitRotation = {}
	if maxRotation > 0 then
		if maxRotation > 0 then
			local allUnits = Spring.GetAllUnits()
			for i = 1, #allUnits do
				gadget:UnitCreated(allUnits[i], Spring.GetUnitDefID(allUnits[i]), Spring.GetUnitTeam(allUnits[i]))
			end
		end
	end
end

local updateTimer = 0
function gadget:Update()
	updateTimer = updateTimer + Spring.GetLastUpdateSeconds()
	if updateTimer > 0.6 then
		updateTimer = 0
		if maxRotation ~= Spring.GetConfigInt('unitRotation', 0) then
			maxRotation = Spring.GetConfigInt('unitRotation', 0)
			init()
		end
	end
end

function gadget:Initialize()
	init()
end

function gadget:Shutdown()
	for unitID, rot in pairs(unitRotation) do
		spurSetUnitLuaDraw(unitID, false)
	end
end

function gadget:DrawUnit(unitID, drawMode)
	if unitRotation[unitID] then
		glRotate(unitRotation[unitID], 0,  1, 0 )
		return false
	end
end
