local sounds = VFS.Include('luarules/mission_api/sounds.lua')
local tracking = VFS.Include('luarules/mission_api/tracking.lua')
local trackUnit = tracking.TrackUnit
local isNameUntracked = tracking.IsNameUntracked
local untrackUnitName = tracking.UntrackUnitName

local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs
local triggers = GG['MissionAPI'].Triggers
local broadcast = VFS.Include('luarules/mission_api/broadcast.lua')


----------------------------------------------------------------
--- Utility Functions:
----------------------------------------------------------------

local function generateGridPositions(center, quantity, xSpacing, zSpacing)
	local positions = {}
	local xGridSize = math.ceil(math.sqrt(quantity)) * xSpacing
	local zGridSize = math.ceil(math.sqrt(quantity)) * zSpacing
	local left = center.x - math.floor(xGridSize / 2)
	local top = center.z - math.floor(zGridSize / 2)
	local count = 0

	for x = left, left + xGridSize - xSpacing, xSpacing do
		for z = top, top + zGridSize - zSpacing, zSpacing do
			if count >= quantity then return positions end
			table.insert(positions, {x = x, z = z})
			count = count + 1
		end
	end
	return positions
end


----------------------------------------------------------------
--- Action Functions:
----------------------------------------------------------------

local function enableTrigger(triggerID)
	triggers[triggerID].settings.active = true
end

local function disableTrigger(triggerID)
	triggers[triggerID].settings.active = false
end

local function changeStage(stage)
	GG['MissionAPI'].CurrentStageID = stage
	broadcast.StageChanged(stage)
end

local function updateObjective(objectiveID, completed, text, unitName, featureName)
	local objective = GG['MissionAPI'].Objectives[objectiveID]

	if objective.completed then return end

	if text then
		objective.text = text
	end
	if unitName then
		objective.progress = #(trackedUnitIDs[unitName] or {})
	elseif featureName then
		-- TODO
	end

	if completed ~= nil then
		objective.completed = completed
	elseif objective.amount ~= nil then
		if objective.amount == 0 then
			objective.completed = objective.progress == 0
		else
			objective.completed = objective.progress >= objective.amount
		end
	end

	broadcast.ObjectiveUpdated(objectiveID, objective.text, objective.progress, objective.amount, objective.completed)
end

local function issueOrders(unitName, orders)
    if isNameUntracked(unitName) then return end

	local commandsAcceptingName = { [CMD.GUARD] = true, [CMD.REPAIR] = true, [CMD.CAPTURE] = true,
									[CMD.ATTACK] = true, [CMD.LOAD_UNITS] = true, [CMD.RECLAIM] = true }

	-- Replace name param with unitIDs, duplicating order for each unitID
	local newOrders = {}
	for _, order in pairs(orders) do
		local commandID = order[1]
		local params = order[2] or {}
		local options = order[3] or {}
		if commandsAcceptingName[commandID] and type(params) == 'string' then
			local unitIDs = trackedUnitIDs[params] or {}
			local isFirstUnitID = true
			for _, unitID in ipairs(unitIDs) do
				newOrders[#newOrders + 1] = { commandID, unitID, table.copy(options) }
				if isFirstUnitID then
					table.insert(options, 'shift')
					isFirstUnitID = false
				end
			end
		else
			newOrders[#newOrders + 1] = order
		end
	end

	Spring.GiveOrderArrayToUnitArray(trackedUnitIDs[unitName], newOrders)
end

local function spawnUnits(unitName, unitDefName, teamID, position, quantity, facing, construction, spacing)

	spacing = spacing or 0

	local unitDef = UnitDefs[UnitDefNames[unitDefName].id]
	local xsize = unitDef.xsize * Game.squareSize + spacing
	local zsize = unitDef.zsize * Game.squareSize + spacing

	-- adjust for facing of non-square units
	if facing == 'e' or facing == 'w' then
		xsize, zsize = zsize, xsize
	end

	local positions = generateGridPositions(position, quantity or 1, xsize, zsize)

	for _, pos in pairs(positions) do
		pos.y = Spring.GetGroundHeight(pos.x, pos.z)
		local unitID = Spring.CreateUnit(unitDefName, pos.x, pos.y, pos.z, facing or 's', teamID, construction)
		trackUnit(unitName, unitID)
	end
end

----------------------------------------------------------------

local function despawnUnits(unitName, selfDestruct, reclaimed)
	if isNameUntracked(unitName) then return end

	-- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
	for _, unitID in pairs(table.copy(trackedUnitIDs[unitName])) do
		if Spring.GetUnitIsDead(unitID) == false then
			Spring.DestroyUnit(unitID, selfDestruct, reclaimed)
		end
	end
end

----------------------------------------------------------------

local function transferUnits(unitName, newTeam)
	if isNameUntracked(unitName) then return end

	-- Copying table as UnitExists trigger with TransferUnits with the same name could cause infinite loop.
	for _, unitID in pairs(table.copy(trackedUnitIDs[unitName])) do
		local given = Spring.GetUnitAllyTeam(unitID) == Spring.GetTeamAllyTeamID(newTeam)
		Spring.TransferUnit(unitID, newTeam, given)
	end
end

local function nameUnits(unitName, teamID, unitDefName, area)
	local hasFilterOtherThanTeamID = unitDefName or area

	local allUnitsOfTeam = {}
	if not hasFilterOtherThanTeamID then
		allUnitsOfTeam = Spring.GetTeamUnits(teamID)
	end

	local unitsFromDef = {}
	if unitDefName then
		if UnitDefNames[unitDefName] then
			local unitDefID = UnitDefNames[unitDefName].id
			if teamID then
				unitsFromDef = Spring.GetTeamUnitsByDefs(teamID, unitDefID)
			else
				for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
					for _, teamIDForAllyTeam in pairs(Spring.GetTeamList(allyTeamID)) do
						table.append(unitsFromDef, Spring.GetTeamUnitsByDefs(teamIDForAllyTeam, unitDefID))
					end
				end
			end
		end
	end

	local unitsInArea = {}
	if area.x1 and area.z1 and area.x2 and area.z2 then
		unitsInArea = Spring.GetUnitsInRectangle(area.x1, area.z1, area.x2, area.z2, teamID)
	elseif area.x and area.z and area.radius then
		unitsInArea = Spring.GetUnitsInCylinder(area.x, area.z, area.radius, teamID)
	end

	local unitsToName = {}
	if hasFilterOtherThanTeamID then
		unitsToName = table.valueIntersection(
			unpack(table.filterArray({ unitsFromDef, unitsInArea},
				function(tbl) return not table.isEmpty(tbl) end)))
	else
		unitsToName = allUnitsOfTeam
	end

	for _, unitID in pairs(unitsToName) do
		trackUnit(unitName, unitID)
	end
end

local function unnameUnits(unitName)
	untrackUnitName(unitName)
end

local function spawnExplosion(weaponDefName, position, direction)
	direction = direction or { x = 0, y = 0, z = 0 }
	local weaponDef = WeaponDefNames[weaponDefName]
	local params = {
		weaponDef = weaponDef.id,
		owner = -1,
		damages = weaponDef.damages,
		hitUnit = 1,
		hitFeature = 1,
		craterAreaOfEffect = weaponDef.craterAreaOfEffect,
		damageAreaOfEffect = weaponDef.damageAreaOfEffect,
		edgeEffectiveness = weaponDef.edgeEffectiveness,
		explosionSpeed = weaponDef.explosionSpeed,
		impactOnly = weaponDef.impactOnly,
		ignoreOwner = weaponDef.noSelfDamage,
		damageGround = true,
	}
	Spring.SpawnExplosion(position.x, position.y, position.z, direction.x, direction.y, direction.z, params)
end

local function playSound(soundfile, volume, position, enqueue)
	if enqueue then
		sounds.EnqueueSound(soundfile, volume, position)
	else
		sounds.PlaySound(soundfile, volume, position)
	end
end

local function sendMessage(message)
	Spring.Echo(message)
end

local markerNames = {}
local function addMarker(position, label, name)
	if name then
		markerNames[name] = position
	end
	Spring.MarkerAddPoint(position.x, position.y, position.z, label, false)
end

local function eraseMarker(name)
	local position = markerNames[name]

	if not position then return end

	markerNames[name] = nil
	Spring.MarkerErasePosition(position.x, position.y, position.z, nil, false, nil, true)
end

local function drawLines(positions)
	for i = 1, #positions - 1 do
		local pos1 = positions[i]
		local pos2 = positions[i + 1]
		Spring.MarkerAddLine(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, nil, false)
	end
end

local function clearAllMarkers()
	markerNames = {}
	Spring.SendCommands("clearmapmarks")
end

local function victory(winningAllyTeamIDs)
	Spring.GameOver({ unpack(winningAllyTeamIDs) })
end

local function defeat(losingAllyTeamIDs)
	local allAllyTeamIDs = Spring.GetAllyTeamList()
	local winningAllyTeamIDs = { }
	for _, allyTeamID in pairs(allAllyTeamIDs) do
		if not table.contains(losingAllyTeamIDs, allyTeamID) then
			table.insert(winningAllyTeamIDs, allyTeamID)
		end
	end
	Spring.GameOver({ unpack(winningAllyTeamIDs) })
end

local function custom(func)
	func()
end

return {
	-- Triggers
	EnableTrigger = enableTrigger,
	DisableTrigger = disableTrigger,

	-- Stages & Objectives
	ChangeStage = changeStage,
	UpdateObjective = updateObjective,

	-- Orders
	IssueOrders = issueOrders,

	-- Build Options

	-- Units
	SpawnUnits = spawnUnits,
	DespawnUnits = despawnUnits,
	TransferUnits = transferUnits,
	NameUnits = nameUnits,
	UnnameUnits = unnameUnits,

	-- SFX
	SpawnExplosion = spawnExplosion,

	-- Map

	-- Media
	PlaySound = playSound,
	SendMessage = sendMessage,
	AddMarker = addMarker,
	DrawLines = drawLines,
	EraseMarker = eraseMarker,
	ClearAllMarkers = clearAllMarkers,

	-- Win Condition
	Victory = victory,
	Defeat = defeat,

	-- Custom
	Custom = custom,
}
