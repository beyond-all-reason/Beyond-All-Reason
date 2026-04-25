local actionsSchema = VFS.Include('luarules/mission_api/actions_schema.lua')
local types = actionsSchema.Types
local loadout = VFS.Include('luarules/mission_api/loadout.lua')
local sounds = VFS.Include('luarules/mission_api/sounds.lua')
local tracking = VFS.Include('luarules/mission_api/tracking.lua')
local trackUnit = tracking.TrackUnit
local isUnitNameUntracked = tracking.IsUnitNameUntracked
local untrackUnitName = tracking.UntrackUnitName
local isFeatureNameUntracked = tracking.IsFeatureNameUntracked

local trackedUnitIDs = GG['MissionAPI'].trackedUnitIDs
local trackedFeatureIDs = GG['MissionAPI'].trackedFeatureIDs
local triggers = GG['MissionAPI'].Triggers


----------------------------------------------------------------
--- Action Functions:
----------------------------------------------------------------

local function enableTrigger(triggerID)
	triggers[triggerID].settings.active = true
end

local function disableTrigger(triggerID)
	triggers[triggerID].settings.active = false
end

local function issueOrders(unitName, orders)
	if isUnitNameUntracked(unitName) then return end

	local convertedOrders = loadout.ConvertOrdersTargetingNames(orders)
	Spring.GiveOrderArrayToUnitMap(trackedUnitIDs[unitName], convertedOrders)
end

local function spawnUnits(unitLoadout)
	loadout.SpawnUnitLoadout(unitLoadout)
end

----------------------------------------------------------------

local function despawnUnits(unitName, selfDestruct, reclaimed)
	if isUnitNameUntracked(unitName) then return end

	-- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
	for unitID in pairs(table.copy(trackedUnitIDs[unitName])) do
		if Spring.GetUnitIsDead(unitID) == false then
			Spring.DestroyUnit(unitID, selfDestruct, reclaimed)
		end
	end
end

----------------------------------------------------------------

local function transferUnits(unitName, newTeam)
	if isUnitNameUntracked(unitName) then return end

	-- Copying table as UnitExists trigger with TransferUnits with the same name could cause infinite loop.
	for unitID in pairs(table.copy(trackedUnitIDs[unitName])) do
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
			unpack(table.filterArray({ unitsFromDef, unitsInArea },
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

local function createFeatures(featureLoadout)
	loadout.SpawnFeatureLoadout(featureLoadout)
end

local function destroyFeatures(featureName)
	if isFeatureNameUntracked(featureName) then return end

	-- Copying table as FeatureDestroyed trigger with CreateFeatures with the same name could cause infinite loop.
	for featureID in pairs(table.copy(trackedFeatureIDs[featureName])) do
		if Spring.ValidFeatureID(featureID) then
			Spring.DestroyFeature(featureID)
		end
	end
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
	local winningAllyTeamIDs = {}
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

local function addResources(teamID, metal, energy)
	if metal then
		Spring.AddTeamResource(teamID, 'metal', metal)
	end
	if energy then
		Spring.AddTeamResource(teamID, 'energy', energy)
	end
end

return {
	-- Triggers
	[types.EnableTrigger]   = enableTrigger,
	[types.DisableTrigger]  = disableTrigger,

	-- Orders
	[types.IssueOrders]     = issueOrders,

	-- Build Options

	-- Units
	[types.SpawnUnits]      = spawnUnits,
	[types.DespawnUnits]    = despawnUnits,
	[types.TransferUnits]   = transferUnits,
	[types.NameUnits]       = nameUnits,
	[types.UnnameUnits]     = unnameUnits,

	-- Features
	[types.CreateFeatures]  = createFeatures,
	[types.DestroyFeatures] = destroyFeatures,

	-- SFX
	[types.SpawnExplosion]  = spawnExplosion,

	-- Map

	-- Media
	[types.PlaySound]       = playSound,
	[types.SendMessage]     = sendMessage,
	[types.AddMarker]       = addMarker,
	[types.DrawLines]       = drawLines,
	[types.EraseMarker]     = eraseMarker,
	[types.ClearAllMarkers] = clearAllMarkers,

	-- Win Condition
	[types.Victory]         = victory,
	[types.Defeat]          = defeat,

	-- Custom
	[types.Custom]          = custom,

	-- Other
	[types.AddResources]    = addResources,
}
