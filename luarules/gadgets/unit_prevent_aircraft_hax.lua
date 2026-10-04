
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent outside-of-map hax",
		desc = "Prevent mobile unit outside-of-map hax (unless its gaia)",
		author = "Beherith",
		date = "3 27 2011",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local rangeLimit = 1800
local rangeLimitGaia = 20000

local gaiaTeamID = Spring.GetGaiaTeamID()
local mapX = Game.mapSizeX
local mapZ = Game.mapSizeZ
local allMobileUnits = {}
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spValidUnitID = Spring.ValidUnitID
local spIsPosInMap = Spring.IsPosInMap
local CMD_STOP = CMD.STOP
local CMD_GUARD = CMD.GUARD

local isMobileUnit = {}
local isBuilder = {}
for unitDefID, udef in pairs(UnitDefs) do
	if not (udef.isBuilding or udef.speed == 0) then
		isMobileUnit[unitDefID] = true
	end
	if udef.isBuilder and (udef.buildSpeed and udef.buildSpeed > 0) and (udef.buildDistance and udef.buildDistance > 0) then
		isBuilder[unitDefID] = true
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_STOP)
	gadgetHandler:RegisterAllowCommand(CMD_GUARD)
	for _, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), spGetUnitTeam(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isMobileUnit[unitDefID] then
		allMobileUnits[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	allMobileUnits[unitID] = nil
end

function gadget:GameFrame(f)
	if f % 69 == 0 then
		local minMap = -rangeLimit
		local maxMapX = mapX + rangeLimit
		local maxMapZ = mapZ + rangeLimit
		local minMapGaia = -rangeLimitGaia
		local maxMapXGaia = mapX + rangeLimitGaia
		local maxMapZGaia = mapZ + rangeLimitGaia
		for unitID, _ in pairs(allMobileUnits) do
			local x, y, z = spGetUnitPosition(unitID)
			if z then
				local unitTeam = spGetUnitTeam(unitID)
				if unitTeam == gaiaTeamID then
					if z < minMapGaia or x < minMapGaia or z > maxMapZGaia or x > maxMapXGaia then
						Spring.DestroyUnit(unitID, false, true)
					end
				else
					if z < minMap or x < minMap or z > maxMapZ or x > maxMapX then
						Spring.DestroyUnit(unitID, false, true)
					end
				end
			end
		end
	end
end

local function isInsideMap(unitID)
	local x,_,z = spGetUnitPosition(unitID)
	return spIsPosInMap(x, z)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, fromSynced, fromLua)
	if cmdID == CMD_STOP and isMobileUnit[unitDefID] then
		return isInsideMap(unitID)
	elseif cmdID == CMD_GUARD then
		-- To guard out of map both units must be builders
		local guardeeID = cmdParams[1]
		if guardeeID and spValidUnitID(guardeeID) and not isInsideMap(guardeeID) then
			local guardeeUnitDefID = spGetUnitDefID(guardeeID)
			if not (isBuilder[unitDefID] and isBuilder[guardeeUnitDefID]) then
				return false
			end
		end
	end
	return true
end
