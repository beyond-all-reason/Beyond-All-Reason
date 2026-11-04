local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Idle Constructor Guard After Build",
		desc = "Constructors guard factories after building if they have nothing to do afterwards",
		author = "TheFutureKnight",
		date = "2025-1-27",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local spGetMyTeamID = Spring.GetLocalTeamID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitDefID = Spring.GetUnitDefID
local CMD_GUARD = CMD.GUARD
local OPT_SHIFT = CMD.OPT_SHIFT

local validGuardingBuilders = {}
for unitDefID, ud in pairs(UnitDefs) do
	validGuardingBuilders[unitDefID] = (ud.isBuilder and ud.canAssist and ud.canMove and not ud.isFactory)
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, _, _)
	if not validGuardingBuilders[unitDefID] then
		return
	end
	local isUnitRepair = cmdID == CMD.REPAIR and #cmdParams ~= 4
	if not (isUnitRepair or cmdID < 0) then
		return
	end
	if unitTeam ~= spGetMyTeamID() then
		return
	end
	if Spring.GetUnitCommandCount(unitID) > 0 then
		return
	end

	local buildeeDef = isUnitRepair and UnitDefs[spGetUnitDefID(cmdParams[1])] or UnitDefs[-cmdID]
	if not (buildeeDef and buildeeDef.isFactory) then
		return
	end

	if isUnitRepair then
		spGiveOrderToUnit(unitID, CMD_GUARD, cmdParams[1], OPT_SHIFT)
		return
	end

	local candidateUnits = spGetUnitsInSphere(cmdParams[1], cmdParams[2], cmdParams[3], 50)
	for _, candidateUnitID in ipairs(candidateUnits) do
		if spGetUnitDefID(candidateUnitID) == -cmdID then
			spGiveOrderToUnit(unitID, CMD_GUARD, candidateUnitID, OPT_SHIFT)
			break
		end
	end
end
