local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission unit color",
		desc = "Hands a unit's own color to the unit shader, over its team's",
		date = "2026-11-15",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local SYNC_ACTION = "MissionUnitColor"
local PARAM = "mission_unit_color"
-- userDefined[0].y in cus_gl4.vert.glsl. Features keep 0 to 1 there, so a color goes in negated.
local UNIFORM_INDEX = 1

local colored = {} ---@type table<integer, true?>
local uniformCache = { 0 }

local function write(unitID, packed)
	uniformCache[1] = -packed
	gl.SetUnitBufferUniforms(unitID, uniformCache, UNIFORM_INDEX)
end

---@param packed number? 0 or nil for the team's color
local function apply(unitID, packed)
	packed = packed or 0
	if packed == 0 and not colored[unitID] then
		return
	end
	colored[unitID] = packed ~= 0 or nil
	write(unitID, packed)
end

local function onUnitColor(_, unitID, packed)
	apply(unitID, packed)
	return true
end

function gadget:UnitDestroyed(unitID)
	apply(unitID, 0)
end

function gadget:Initialize()
	if not gl.SetUnitBufferUniforms or not Spring.GetGameRulesParam("inMission") then
		gadgetHandler:RemoveGadget()
		return
	end
	gadgetHandler:AddSyncAction(SYNC_ACTION, onUnitColor)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		apply(unitID, Spring.GetUnitRulesParam(unitID, PARAM))
	end
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction(SYNC_ACTION)
	for unitID in pairs(colored) do
		write(unitID, 0)
	end
end
