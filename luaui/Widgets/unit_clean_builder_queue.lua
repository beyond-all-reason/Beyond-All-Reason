function widget:GetInfo()
	return {
		name    = "Clean Builder Queue",
		desc    = "Removes completed buildings from all builders unit queue in case they werent there completing it (unless they have repeat enabled)",
		author  = "Floris",
		date    = "May 2025",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
	}
end

local GetUnitCmdDescs    = Spring.GetUnitCmdDescs
local GetUnitCommands    = Spring.GetUnitCommands
local GiveOrderToUnit    = Spring.GiveOrderToUnit
local GetUnitPosition    = Spring.GetUnitPosition
local GetUnitDefID       = Spring.GetUnitDefID
local GetTeamUnits       = Spring.GetTeamUnits
local GetMyTeamID        = Spring.GetMyTeamID
local GetSpectatingState = Spring.GetSpectatingState

local CMD_REMOVE         = CMD.REMOVE
local CMD_REPEAT         = CMD.REPEAT

local REMOVE_TOLERANCE   = 5 * 5 -- squared distance

local trackedBuilders    = {}
local isBuilding         = {}
local builderDefs        = {}
local myTeamID           = GetMyTeamID()

local function IsUnitRepeatOn(unitID)
	local cmdDescs = GetUnitCmdDescs(unitID)
	if not cmdDescs then return false end
	for _, desc in ipairs(cmdDescs) do
		if desc.id == CMD_REPEAT then
			return desc.params and desc.params[1] == "1"
		end
	end
	return false
end

local function coordsMatch(x1, z1, x2, z2, tolerance)
	local dx = x1 - x2
	local dz = z1 - z2
	return dx * dx + dz * dz <= tolerance
end

function widget:Initialize()
	if GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end

	for udid, ud in pairs(UnitDefs) do
		if ud.isBuilder then
			builderDefs[udid] = true
		end
		if ud.isBuilding or ud.speed == 0 then
			isBuilding[udid] = true
		end
	end

	local allUnits = GetTeamUnits(myTeamID)
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		if builderDefs[GetUnitDefID(unitID)] then
			trackedBuilders[unitID] = true
		end
	end
end

function widget:PlayerChanged(playerID)
	if GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID and builderDefs[unitDefID] then
		trackedBuilders[unitID] = true
	end
end

function widget:UnitDestroyed(unitID)
	trackedBuilders[unitID] = nil
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeamID or not isBuilding[unitDefID] then
		return
	end

	local x, _, z = GetUnitPosition(unitID)

	for builderID in pairs(trackedBuilders) do
		if not IsUnitRepeatOn(builderID) then
			local commands = GetUnitCommands(builderID, 32)
			for i = #commands, 1, -1 do
				local cmd = commands[i]
				if cmd.id < 0 and -cmd.id == unitDefID then
					local bx, bz = cmd.params[1], cmd.params[3]
					if coordsMatch(x, z, bx, bz, REMOVE_TOLERANCE) then
						GiveOrderToUnit(builderID, CMD_REMOVE, { cmd.tag }, {})
					end
				end
			end
		end
	end
end
