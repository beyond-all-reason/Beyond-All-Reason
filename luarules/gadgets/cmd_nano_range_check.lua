function gadget:GetInfo()
	return {
		name = "Construction Turrets Range Check",
		desc = "Stops construction turrets from getting assigned to guards, repair, reclaim and attacks out of reach.",
		author = "Nehroz",
		date = "2024.12.01",
		layer = 0,
		enabled = true,
	}
end


if not gadgetHandler:IsSyncedCode() then return end

--- key is the nano's ID, followed by a Set-like with the unitID of target currently inside the nano's range.
--- Used for CommandArray manipulation
---@type {[number] : {number : boolean}}
local trackingTable = {}

local constructionTurretsDefs = {}
for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.isFactory == false and unitDef.isStaticBuilder then
		constructionTurretsDefs[unitDefID] = {
			maxBuildDistance = unitDef.buildDistance + unitDef.radius,
			buildRange3D = unitDef.buildRange3D,
		}
	end
end


function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
	gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
	gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
end

function gadget:GameFrame(frame)
	for nanoID in pairs(trackingTable) do
		local nanoDefID = Spring.GetUnitDefID(nanoID)
		local maxDistance = constructionTurretsDefs[nanoDefID].maxBuildDistance
		local commands = Spring.GetUnitCommands(nanoID, -1)

		for i=#commands, 1, -1 do
			local unitID = commands[i].params[1]
			if Spring.ValidUnitID(unitID) then
				local distance = Spring.GetUnitSeparation(nanoID, unitID, constructionTurretsDefs[nanoDefID].buildRange3D, false)
				if distance < maxDistance then -- Inside range
					trackingTable[nanoID][unitID] = true
				elseif trackingTable[nanoID][unitID] then -- Outside range
					trackingTable[nanoID][unitID] = nil
					Spring.GiveOrderToUnit(nanoID, CMD.REMOVE, commands[i].tag, 0)
				end
			end
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID,	cmdParams, cmdOptions, cmdTag, synced, fromLua)
	if not constructionTurretsDefs[unitDefID] then return true end
	-- only handle ID targets, fallthrough for area selects; Let the intended scripts handle, catch resulting commands on ID.
	if #cmdParams ~= 1 then return true end
	local distance = math.huge
	local targetId = cmdParams[1]

	if targetId < Game.maxUnits then
		if not Spring.ValidUnitID(targetId) then return end
		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetId)]
		if targetUnitDef.canMove then
			if not trackingTable[unitID] then
				trackingTable[unitID] = {}
			end
			return true
		end
		distance = Spring.GetUnitSeparation(unitID, targetId, constructionTurretsDefs[unitDefID].buildRange3D, false)
	else
		targetId = targetId - Game.maxUnits
		if not Spring.ValidFeatureID(targetId) then return end
		distance = Spring.GetUnitFeatureSeparation(unitID, targetId, false)
	end

	if distance > constructionTurretsDefs[unitDefID].maxBuildDistance then
		return false
	end
	return true
end

function gadget:UnitDestroyed(unitID)
	trackingTable[unitID] = nil

	for nanoID, _ in pairs(trackingTable) do
		trackingTable[nanoID][unitID] = nil
	end
end