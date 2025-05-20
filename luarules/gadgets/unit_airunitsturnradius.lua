local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "TurnRadius",
		desc      = "Fixes TurnRadius Dynamically for bombers",
		author    = "Doo",
		date      = "Sept 19th 2017",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local attackTurnRadius = 500

local CMD_ATTACK = CMD.ATTACK
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spMoveCtrlEnable = Spring.MoveCtrl.Enable
local spMoveCtrlIsEnabled = Spring.MoveCtrl.IsEnabled
local spMoveCtrlDisable = Spring.MoveCtrl.Disable
local spMoveCtrlSetAirMoveTypeData = Spring.MoveCtrl.SetAirMoveTypeData

local Bombers = {}
local bomberTurnRadius = {}
for udid, ud in pairs(UnitDefs) do
	if ud.canFly then
		if not ud.hoverAttack and ud.weapons and ud.weapons[1] then
			for i = 1, #ud.weapons do
				local wDef = WeaponDefs[ud.weapons[i].weaponDef]
				if wDef.type == "AircraftBomb" or wDef.type == "TorpedoLauncher" then
					bomberTurnRadius[udid] = ud.turnRadius
					break
				end
			end
		end
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
	for ct, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if bomberTurnRadius[unitDefID] then
		Bombers[unitID] = unitDefID
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if Bombers[unitID] then
		Bombers[unitID] = nil
	end
end
function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if Bombers[unitID] and spGetUnitMoveTypeData(unitID).aircraftState == "crashing" then
		gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	end
end

local function processNextCmd(unitID, unitDefID, cmdID)
	local curMoveCtrl = spMoveCtrlIsEnabled(unitID)
	if curMoveCtrl then
		spMoveCtrlDisable(unitID)
	end
	local success = pcall(function()
		spMoveCtrlSetAirMoveTypeData(unitID, "turnRadius", (not cmdID or cmdID == CMD_ATTACK) and attackTurnRadius or bomberTurnRadius[unitDefID])
	end)
	if not success then
		Spring.Echo("Error: unit_airunitsturnradius incompatible movetype for unitdef "..UnitDefs[unitDefID].name)
	end
	if curMoveCtrl then
		spMoveCtrlEnable(unitID)
	end
end

function gadget:GameFrame(n)
	if n % 6 == 1 then
		for unitID, unitDefID in pairs(Bombers) do
			processNextCmd(unitID, unitDefID, spGetUnitCurrentCommand(unitID))
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if Bombers[unitID] then
		processNextCmd(unitID, unitDefID, cmdID)
	end
	return true
end
