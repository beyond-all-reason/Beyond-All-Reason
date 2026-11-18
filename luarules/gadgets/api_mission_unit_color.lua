local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission unit color",
		desc = "Gives a unit its own color from the custom palette, over its team's",
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
-- The last custom slot (palette 2047) is where features without a team land.
local LAST_SLOT = Engine.maxCustomPaletteID - 1

local spSetUnitPaletteIndex = Spring.SetUnitPaletteIndex

local slotOfColor = {} ---@type table<number, integer?>
local nextSlot = 0
local colored = {} ---@type table<integer, true?>

-- One slot per distinct color, shared by every unit that has it.
---@return integer? slot nil once the palette is full
local function slotFor(packed)
	local slot = slotOfColor[packed]
	if slot or nextSlot > LAST_SLOT then
		return slot
	end
	slot = nextSlot
	nextSlot = nextSlot + 1
	slotOfColor[packed] = slot
	local r, g, b = math.floor(packed / 65536), math.floor(packed / 256) % 256, packed % 256
	Spring.SetCustomPaletteColor(slot, r / 255, g / 255, b / 255)
	return slot
end

---@param packed number? 0 or nil for the team's color
local function apply(unitID, packed)
	local slot = packed and packed ~= 0 and slotFor(packed) or nil
	if not slot and not colored[unitID] then
		return
	end
	colored[unitID] = slot and true or nil
	spSetUnitPaletteIndex(unitID, slot)
	-- CUS holds the palette index in its own instance buffer until the unit is uploaded again.
	if GG.CUSGL4 and GG.CUSGL4.RefreshUnit then
		GG.CUSGL4.RefreshUnit(unitID)
	end
end

local function onUnitColor(_, unitID, packed)
	apply(unitID, packed)
	return true
end

function gadget:UnitDestroyed(unitID)
	colored[unitID] = nil
end

function gadget:Initialize()
	if not spSetUnitPaletteIndex or not Spring.GetGameRulesParam("inMission") then
		gadgetHandler:RemoveGadget()
		return
	end
	gadgetHandler:AddSyncAction(SYNC_ACTION, onUnitColor)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		apply(unitID, tonumber(Spring.GetUnitRulesParam(unitID, PARAM)))
	end
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction(SYNC_ACTION)
	for unitID in pairs(colored) do
		spSetUnitPaletteIndex(unitID, nil)
	end
end
