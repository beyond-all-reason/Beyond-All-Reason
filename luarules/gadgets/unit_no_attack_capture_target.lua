function gadget:GetInfo()
	return {
		name		= "Don't attack capture target",
		desc		= "Stops your units from targeting your capture targets",
		author		= "Slouse",
		version		= 'v1.0',
		date		= "April 2025",
		license		= "GNU GPL, v2 or later",
		layer		= -1,
		enabled 	= true
	}
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local captureTargets = {}

local function activeCaptureCommand(unitID)
	local cmdQueue = Spring.GetUnitCommands(unitID, -1);
	if #cmdQueue > 0 then
		if cmdQueue[1].id == CMD.CAPTURE then
			return true
		else
			return false
		end
	end
end

--ToDo: Determine which units weapons need to be watched
--
--Watch all weapons so gadget:AllowWeaponTarget() works
for unitDefID, unitDef in pairs(UnitDefs) do
	local weapons = unitDef.weapons
	for i = 1, #weapons do
		for wid, weapon in ipairs(unitDef.weapons) do
			if weapon ~= nil then
				local weaponDef = weapon.weaponDef
				if weaponDef ~= nil then
					Script.SetWatchWeapon(weaponDef, true)
				end
			end
		end
	end
end

--Mark target for capture when capture command is accepted by unit
function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD.CAPTURE then
		local targetID = cmdParams[1]
		--If targetID is already in captureTargets table, ignore it
		if not captureTargets[targetID] then
			captureTargets[targetID] = {builderID = unitID, captureTeamID = teamID, captureProgress = 0}
		end
	end
end

--Remove target from captureTargets table when capture is completed
function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	if capture == true then
		if captureTargets ~= nil then
			if captureTargets[unitID] then
				captureTargets[unitID] = nil
			end
		end
	end
	return true
end

--Remove unit from captureTargets table if destroyed
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if captureTargets ~= nil then
		if captureTargets[unitID] then
			captureTargets[unitID] = nil
		end
	end
	return true
end

--Deny autotarget if target unit is being captured by player team
function gadget:AllowWeaponTarget(unitID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	if captureTargets ~= nil then
		local captureTarget = captureTargets[targetID]
		if captureTarget then
			local captureTeamID = Spring.GetUnitTeam(unitID)
			if captureTeamID == captureTarget.captureTeamID then
				return false, defPriority
			end 
		end
	end
	return true, defPriority
end

--Poll capture progress and remove targets that have 0 progress and no active capture command
function gadget:GameFrame(frame)
	if frame % 20 == 0 then
		if captureTargets ~= nil then
			for unitID, data in pairs(captureTargets) do
				captureTargets[unitID].captureProgress = select(4, Spring.GetUnitHealth(unitID))
				if data.captureProgress <= 0 then
					if not activeCaptureCommand(data.builderID) then
						captureTargets[unitID] = nil
					end
				end
			end
		end
	end
	--[[if frame % 5 == 0 then
		local cmdQueue = Spring.GetUnitCommands(unitID, -1)
		if #cmdQueue > 0 then 
			Spring.Echo("Command id:", cmdQueue[1].id)
		end
	end]]
end
