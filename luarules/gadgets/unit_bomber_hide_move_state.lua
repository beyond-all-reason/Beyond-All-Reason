local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Bomber Move State",
		desc    = "Hides the Move State button for bombers",
		author  = "Pexo",
		date    = "2026-03-03",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc

local CMD_MOVE_STATE = CMD.MOVE_STATE

local isBomberDef = {}

local function isBomberUnitDef(ud)
	if not ud or not ud.weapons then
		return false
	end

	for i = 1, #ud.weapons do
		local weaponDef = WeaponDefs[ud.weapons[i].weaponDef]
		if weaponDef and weaponDef.type == "AircraftBomb" then
			return true
		end
	end

	return false
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if isBomberUnitDef(unitDef) then
		isBomberDef[unitDefID] = true
	end
end

local function hideMoveState(unitID)
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_MOVE_STATE)
	if cmdDescID then
		spRemoveUnitCmdDesc(unitID, cmdDescID)
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if isBomberDef[unitDefID] then
		hideMoveState(unitID)
	end
end

function gadget:UnitGiven(unitID, unitDefID)
	if isBomberDef[unitDefID] then
		hideMoveState(unitID)
	end
end

function gadget:UnitTaken(unitID, unitDefID)
	if isBomberDef[unitDefID] then
		hideMoveState(unitID)
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(spGetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		if isBomberDef[unitDefID] then
			hideMoveState(unitID)
		end
	end
end
