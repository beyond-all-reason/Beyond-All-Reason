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

local CMD_ATTACK = CMD.ATTACK
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spMoveCtrlEnable = Spring.MoveCtrl.Enable
local spMoveCtrlIsEnabled = Spring.MoveCtrl.IsEnabled
local spMoveCtrlDisable = Spring.MoveCtrl.Disable
local spMoveCtrlSetAirMoveTypeData = Spring.MoveCtrl.SetAirMoveTypeData

local unitTurnRadius = {}
local Bombers = {}
local isFighter = {}
local isBomber = {}
local isBomb = {}
for id, wDef in pairs(WeaponDefs) do
	if wDef.type == "AircraftBomb" then
		isBomb[id] = true
	end
end
for udid, ud in pairs(UnitDefs) do
	if ud.customParams.fighter then
		isFighter[udid] = true
	end
	if (ud["weapons"] and ud["weapons"][1] and isBomb[ud["weapons"][1].weaponDef] == true) or (string.find(ud.name, 'armlance') or string.find(ud.name, 'cortitan')) then
		isBomber[udid] = true
	end
	unitTurnRadius[udid] = ud.turnRadius
end
isBomb = nil

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
	for ct, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if isBomber[unitDefID] and spGetUnitMoveTypeData(unitID).turnRadius then
		Bombers[unitID] = unitDefID
	end
	if isFighter[unitDefID] then
		local curMoveCtrl = spMoveCtrlIsEnabled(unitID)
		if curMoveCtrl then
			spMoveCtrlDisable(unitID)
		end
		spMoveCtrlSetAirMoveTypeData(unitID, "attackSafetyDistance", 300)
		if curMoveCtrl then
			spMoveCtrlEnable(unitID)
		end
	end
end

function gadget:UnitDestroyed(unitID)
	if Bombers[unitID] then
		Bombers[unitID] = nil
	end
end
function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if Bombers[unitID] and spGetUnitMoveTypeData(unitID).aircraftState == "crashing" then
		gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	end
end

local function processNextCmd(unitID, unitDefID, cmdID)
	if not cmdID or cmdID == CMD_ATTACK then
		local curMoveCtrl = spMoveCtrlIsEnabled(unitID)
		if curMoveCtrl then
			spMoveCtrlDisable(unitID)
		end
		spMoveCtrlSetAirMoveTypeData(unitID, "turnRadius", 500)
		if curMoveCtrl then
			spMoveCtrlEnable(unitID)
		end
	else--if spGetUnitMoveTypeData(unitID).turnRadius then -- checking this on UnitCreated now, cause this is expensive
		local curMoveCtrl = spMoveCtrlIsEnabled(unitID)
		if curMoveCtrl then
			spMoveCtrlDisable(unitID)
		end
		spMoveCtrlSetAirMoveTypeData(unitID, "turnRadius", unitTurnRadius[unitDefID])
		if curMoveCtrl then
			spMoveCtrlEnable(unitID)
		end
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
