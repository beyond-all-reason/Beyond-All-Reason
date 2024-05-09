
if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name = "Unit Carrier Spawner",
		desc = "Spawns and controls units",
		author = "Xehrath, Inspiration taken from zeroK carrier authors: TheFatConroller, KingRaptor",
		date = "2023-03-15",
		license = "None",
		layer = 55,
		enabled = true
	}
end

local spCreateUnit              = Spring.CreateUnit
local spDestroyUnit             = Spring.DestroyUnit
local spGiveOrderToUnit         = Spring.GiveOrderToUnit
local spSetUnitRulesParam       = Spring.SetUnitRulesParam
local spGetUnitPosition			= Spring.GetUnitPosition
local SetUnitNoSelect			= Spring.SetUnitNoSelect
local spGetUnitRulesParam		= Spring.GetUnitRulesParam
local spUseTeamResource 		= Spring.UseTeamResource
local spGetTeamResources 		= Spring.GetTeamResources
local GetCommandQueue     		= Spring.GetCommandQueue
local spSetUnitArmored 			= Spring.SetUnitArmored
local spGetUnitStates			= Spring.GetUnitStates
local spGetUnitDefID        	= Spring.GetUnitDefID
local spSetUnitVelocity     	= Spring.SetUnitVelocity
local spUnitAttach 				= Spring.UnitAttach
local spUnitDetach 				= Spring.UnitDetach
local spSetUnitHealth 			= Spring.SetUnitHealth
local spGetGroundHeight 		= Spring.GetGroundHeight
local spGetUnitNearestEnemy		= Spring.GetUnitNearestEnemy
local spTransferUnit			= Spring.TransferUnit
local spGetUnitTeam 			= Spring.GetUnitTeam
local spGetUnitHealth 			= Spring.GetUnitHealth
local spGetUnitCurrentCommand 	= Spring.GetUnitCurrentCommand
local spGetUnitWeaponTarget		= Spring.GetUnitWeaponTarget
local EditUnitCmdDesc			= Spring.EditUnitCmdDesc
local FindUnitCmdDesc			= Spring.FindUnitCmdDesc
local InsertUnitCmdDesc			= Spring.InsertUnitCmdDesc


local mcEnable 				= Spring.MoveCtrl.Enable
local mcDisable 			= Spring.MoveCtrl.Disable
local mcSetPosition         = Spring.MoveCtrl.SetPosition

local mapsizeX 				  = Game.mapSizeX
local mapsizeZ 				  = Game.mapSizeZ

local random = math.random
local math_min = math.min
local sin    = math.sin
local cos    = math.cos
local diag = math.diag

local PI = math.pi
local GAME_SPEED = Game.gameSpeed
local PRIVATE = { private = true }

local noCreate = false

local spawnDefs = {}
local shieldCollide = {}
local wantedList = {}

local spawnList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}
local spawnCount = 0
local spawnCmd = {
	id = 31200,
	name = "csSpawning",
	action = "csSpawning",
	type = CMDTYPE.ICON_MODE,
	tooltip = "Enable/Disable drone spawning",
	params = { '1', 'Spawning Disabled', 'Spawning Enabled' }
}


local carrierDockingList = {}
local carrierQueuedDockingCount = 0
local previousHealFrame = 0

local carrierAvailableDockingCount = 1000   -- Limits the amount of drones that can dock simultaneously. Lowering this will increase overall game performance, but some drones might not be able to dock in time. Increasing this above 1500 could cause memory issues in large battles.
local dockingQueueOffset = 0

local carrierMetaList = {}
local droneMetaList = {}

local lastCarrierUpdate = 0
local lastSpawnCheck = 0
local lastDockCheck = 0

local coroutine = coroutine
local Sleep     = coroutine.yield
local assert    = assert

local coroutines = {}

--TEMPORARY for debugging
local totalDroneCount = 0

-- For ZECRUS:

-- These control the frequency, in gameframes, of different actions. Increasing these will improve overall game performance at the cost of this gadgets responsiveness.
local DEFAULT_UPDATE_ORDER_FREQUENCY = 60	-- Idle movement orders for drones. How frequently the drones change direction when idling around the carrier.
local CARRIER_UPDATE_FREQUENCY = 15			-- Update dronestates and orders. Increasing this will decrease responsiveness when issuing new commands.
local DEFAULT_SPAWN_CHECK_FREQUENCY = 3 	-- Controls the minimum possible spawnrate. Increasing this will give less accurate spawnrates.
local DEFAULT_DOCK_CHECK_FREQUENCY = 15		-- Checks the docking queue. Increasing this will decrease docking responsiveness, and may cause some drones to dock too late.


-- These values can be tuned in the unitdef file. Add the section below to a weaponDef list in the unitdef file.
--customparams = {
	--	-- Required:
	-- carried_unit = "unitname"     Name of the unit spawned by this carrier unit.


	--	-- Optional:
	-- controlradius = 200,			The spawned units are recalled when exceeding this range. Radius = 0 to disable control range limit.
	-- engagementrange = 100, 		The spawned units will adopt any active combat commands within this range. Best paired with a weapon of equal range.
	-- spawns_surface = "LAND",     "LAND" or "SEA". If not enabled, any surface will be accepted.
	-- buildcostenergy = 0,			Custom spawn cost. If not set, it will inherit the cost from the carried_unit unitDef.
	-- buildcostmetal = 0,			Custom spawn cost. If not set, it will inherit the cost from the carried_unit unitDef.
	-- enabledocking = true,		If enabled, docking behavior is used.
	-- dockingarmor = 0.4, 			Multiplier for damage taken while docked. Does not work against napalm.

	--	-- Has a default value, as indicated, if not chosen:
	-- spawnrate = 1, 				Spawnrate roughly in seconds.
	-- maxunits = 1,				Will spawn units until this amount has been reached.
	-- dockingpiecestart = 1,		First model piece to be used for docking.
	-- dockingpieceinterval = 0,	Number of pieces to skip when docking the next unit.
	-- dockingpieceend = 1,			Last model piece used for docking. Will loop back to first when exceeded.
	-- dockingradius = 100,			The range at which the units are helped onto the carrier unit when docking.
	-- dockingHelperSpeed = 10,		The speed used when helping the unit onto the carrier. Set this to 0 to disable the helper and just snap to the carrier unit when within the docking range.
	-- dockinghealrate = 0,			Healing per second while docked.
	-- docktohealthreshold = 30,	If health percentage drops below the threshold the unit will attempt to dock for healing.
	-- attackformationspread = 0,	Used to spread out the drones when attacking from a docked state. Distance between each drone when spreading out.
	-- attackformationoffset = 0,	Used to spread out the drones when attacking from a docked state. Distance from the carrier when they start moving directly to the target. Given as a percentage of the distance to the target.
	-- decayrate = 0,				health loss per second while not docked.
	-- deathdecayrate = 0,			health loss per second while not docked, and no carrier to land on.
	-- carrierdeaththroe = "death",	Behaviour for the drones when the carrier dies. "death": destroy the drones. "control": gain manual control of the drones. "capture": same as "control", but if an enemy is within control range, they get control of the drones instead.
	-- holdfireradius = 0,			Defines the wandering distance of drones from the carrier when "holdfire" command is issued. If it isn't defined, 0 default will dock drones on holdfire by default.
	-- },

	-- Notes:
	--todo:
	-- multiple unit types
	-- test all command states
	-- rearming stockpiles mechanic similarly to the healing behaviour
	-- add firewhiledocked as an option.
	--Known bugs:
		-- Land carriers struggling with the attack formations
		-- Drones occationally stuck hovering near the carrier instead of following the active command

for weaponDefID = 1, #WeaponDefs do
	local wdcp = WeaponDefs[weaponDefID].customParams

	if wdcp.carried_unit then
		spawnDefs[weaponDefID] = {
			name = wdcp.carried_unit,
			name2 = wdcp.carried_unit2,
			name3 = wdcp.carried_unit3,
			name4 = wdcp.carried_unit4,
			feature = wdcp.spawns_feature,
			surface = wdcp.spawns_surface,
			spawnRate = wdcp.spawnrate,
			maxunits = wdcp.maxunits,
			metalPerUnit = wdcp.buildcostmetal,
			energyPerUnit = wdcp.buildcostenergy,
			radius = wdcp.controlradius,
			minRadius = wdcp.engagementrange,
			docking = wdcp.enabledocking,
			offset = wdcp.dockingpiecestart,
			interval = wdcp.dockingpieceinterval,
			dockingcap = wdcp.dockingpieceend,
			dockingRadius = wdcp.dockingradius,
			dockingHelperSpeed = wdcp.dockinghelperspeed,
			dockingArmor = wdcp.dockingarmor,
			dockingHealrate = wdcp.dockinghealrate,
			attackFormationSpread = wdcp.attackformationspread,
			attackFormationOffset = wdcp.attackformationoffset,
			decayRate = wdcp.decayrate,
			deathdecayRate = wdcp.deathdecayrate,
			dockToHealThreshold = wdcp.docktohealthreshold,
			carrierdeaththroe = wdcp.carrierdeaththroe,
			holdfireRadius = wdcp.holdfireradius
		}
		if wdcp.spawn_blocked_by_shield then
			shieldCollide[weaponDefID] = WeaponDefs[weaponDefID].damages[Game.armorTypes.shield]
		end
		wantedList[#wantedList + 1] = weaponDefID
	end
end


-- local function GetDistance(x1, x2, y1, y2)
-- 	if x1 and x2 then
-- 		return ((x1-x2)^2 + (y1-y2)^2)^0.5
-- 	else
-- 		return
-- 	end
-- end


local function RandomPointInUnitCircle(offset)
	local startpointoffset = 0
	if offset then
		startpointoffset = offset
	end
	if startpointoffset > 100 then
		startpointoffset = 100
	elseif startpointoffset < 0 then
		startpointoffset = 0
	end
	local angle = random(0, 2*PI)
	--local distance = power(random((startpointoffset/100), 1), 0.5)
	local distance = (random(startpointoffset, 100)/100)^0.5
	return cos(angle)*distance, sin(angle)*distance
end


-- local function GetDirectionalVector(speed, x1, x2, y1, y2, z1, z2)
-- 	local magnitude
-- 	local vx, vy, vz
-- 	if z1 then
-- 		vx, vy, vz = x2-x1, y2-y1, z2-z1
-- 		magnitude = ((vx)^2 + (vy)^2 + (vz)^2)^0.5
-- 		return speed*vx/magnitude, speed*vy/magnitude, speed*vz/magnitude
-- 	else
-- 		vx, vy = x2-x1, y2-y1
-- 		magnitude = ((vx)^2 + (vy)^2)^0.5
-- 		return speed*vx/magnitude, speed*vy/magnitude
-- 	end
-- end


local function StartScript(fn)
	local co = coroutine.create(fn)
	coroutines[#coroutines + 1] = co
end

local function UpdateCoroutines()
	local newCoroutines = {}
	for i=1, #coroutines do
		local co = coroutines[i]
		if (coroutine.status(co) ~= "dead") then
			newCoroutines[#newCoroutines + 1] = co
		end
	end
	coroutines = newCoroutines
	for i=1, #coroutines do
		assert(coroutine.resume(coroutines[i]))
	end
end


function HealUnit(unitID, healrate, resourceFrames, h, mh)
	if (resourceFrames <= 0) or not h then
		return
	end
	local healthGain = healrate*resourceFrames
	local newHealth = math_min(h + healthGain, mh)
	if mh < newHealth then
		newHealth = mh
	end
	if newHealth <= 0 then
		spDestroyUnit(unitID, true)
	else
		spSetUnitHealth(unitID, newHealth)
	end
end



local function DockUnitQueue(unitID, subUnitID) -- adds unit to docking queue, set returnedtoqueue if used to readd a unit that has been removed from the queue, but did not reach the dockerhelper stage.
	if not carrierMetaList[unitID] then
		return
	elseif not carrierMetaList[unitID].subUnitsList[subUnitID] then
		return
	elseif carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking then
		return
	end
	carrierQueuedDockingCount = carrierQueuedDockingCount + 1
	local dockData = carrierDockingList[carrierQueuedDockingCount] or {}
	dockData.ownerID = unitID
	dockData.subunitID = subUnitID
	carrierDockingList[carrierQueuedDockingCount] = dockData
	carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking = true
end



local function UnDockUnit(unitID, subUnitID)
	if not carrierMetaList[unitID] then
		return
	elseif not carrierMetaList[unitID].subUnitsList[subUnitID] then
		return
	elseif carrierMetaList[unitID].subUnitsList[subUnitID].docked == true and not carrierMetaList[unitID].subUnitsList[subUnitID].stayDocked then
		Spring.SetUnitCOBValue(subUnitID, COB.ACTIVATION, 1)
		spUnitDetach(subUnitID)
		mcDisable(subUnitID)
		SetUnitNoSelect(subUnitID, true)
		carrierMetaList[unitID].subUnitsList[subUnitID].docked = false
		carrierMetaList[unitID].activeDocking = false
		carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking = false
		if carrierMetaList[unitID].dockArmor then
			spSetUnitArmored(subUnitID, false, 1)
		end
	end
end


local function SpawnUnit(spawnData)
	local spawnDef = spawnData.spawnDef
	if spawnDef then
		local validSurface = false
		if not spawnDef.surface then
			validSurface = true
		elseif spawnData.x > 0 and spawnData.x < mapsizeX and spawnData.z > 0 and spawnData.z < mapsizeZ then
			local y = spGetGroundHeight(spawnData.x, spawnData.z)
			if string.find(spawnDef.surface, "LAND") and y > 0 then
				validSurface = true
			elseif string.find(spawnDef.surface, "SEA") and y <= 0 then
				validSurface = true
			end
		end


		local subUnitID = nil
		local ownerID = spawnData.ownerID
		if validSurface == true and ownerID then
			if carrierMetaList[spawnData.ownerID].subUnitCount < carrierMetaList[spawnData.ownerID].maxunits then
				local metalCost
				local energyCost
				if carrierMetaList[spawnData.ownerID].metalCost and carrierMetaList[spawnData.ownerID].energyCost then
					metalCost = carrierMetaList[spawnData.ownerID].metalCost
					energyCost = carrierMetaList[spawnData.ownerID].energyCost

				else
					local subUnitDef = UnitDefNames[spawnDef.name]
					metalCost = subUnitDef.metalCost
					energyCost = subUnitDef.energyCost
				end

				local availableMetal = spGetTeamResources(spawnData.teamID, "metal")
				local availableEnergy = spGetTeamResources(spawnData.teamID, "energy")
				if availableMetal > metalCost and availableEnergy > energyCost then
					spUseTeamResource(spawnData.teamID, "metal", metalCost)
					spUseTeamResource(spawnData.teamID, "energy", energyCost)
					subUnitID = spCreateUnit(spawnDef.name, spawnData.x, spawnData.y, spawnData.z, 0, spawnData.teamID)
				end


				if not subUnitID then
					-- unit limit hit or invalid spawn surface
					return
				end


				local spareDock = false
				local dockingpiece
				if ownerID then
					spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", ownerID, PRIVATE)
					local subUnitCount = carrierMetaList[ownerID].subUnitCount
					subUnitCount = subUnitCount + 1
					carrierMetaList[ownerID].subUnitCount = subUnitCount
					local dockingpieceindex
					for i = 1, #carrierMetaList[ownerID].availablePieces do
						if carrierMetaList[ownerID].availablePieces[i].dockingPieceAvailable then
							spareDock = true
							dockingpiece = carrierMetaList[ownerID].availablePieces[i].dockingPiece
							dockingpieceindex = i
							carrierMetaList[ownerID].availablePieces[i].dockingPieceAvailable = false
							break
						end
					end
					local droneData = {
						active = true,
						docked = false, --
						stayDocked = false,
						activeDocking = false,
						inFormation = false,
						engaged = false,
						dockingPiece = dockingpiece, --
						dockingPieceIndex = dockingpieceindex,
					}
					carrierMetaList[ownerID].subUnitsList[subUnitID] = droneData
					totalDroneCount = totalDroneCount + 1
				end


				mcEnable(subUnitID)
				if spareDock == false then
					mcSetPosition(subUnitID, spawnData.x, spawnData.y, spawnData.z)
				else
					--try to spawn in free dock point (offset relative to unit)
					local dockPointx
					local dockPointy
					local dockPointz
					
					local carrierx
					local carriery
					local carrierz
					dockPointx,dockPointy, dockPointz = Spring.GetUnitPiecePosition(ownerID, dockingpiece)--Spring.GetUnitPieceInfo (ownerID, dockingpieceindex)
					carrierx,carriery, carrierz = Spring.GetUnitPosition(ownerID)
					--Spring.Echo(dockingpieceindex)
					--Spring.Debug.TableEcho(Spring.GetUnitPiecePosition(ownerID, dockingpiece))
					mcSetPosition(subUnitID, carrierx+dockPointx, carriery+dockPointy, carrierz+dockPointz)
				end
				mcDisable(subUnitID)


				if carrierMetaList[ownerID].docking and carrierMetaList[ownerID].subUnitsList[subUnitID].dockingPiece then
					spUnitAttach(ownerID, subUnitID, carrierMetaList[ownerID].subUnitsList[subUnitID].dockingPiece)
					spGiveOrderToUnit(subUnitID, CMD.STOP, {}, 0)
					mcDisable(subUnitID)
					spSetUnitVelocity(subUnitID, 0, 0, 0)
					SetUnitNoSelect(subUnitID, true)
					carrierMetaList[ownerID].subUnitsList[subUnitID].docked = true
					carrierMetaList[ownerID].subUnitsList[subUnitID].activeDocking = false
					if carrierMetaList[ownerID].dockArmor then
						spSetUnitArmored(subUnitID, true, carrierMetaList[ownerID].dockArmor)
					end
					Spring.SetUnitCOBValue(subUnitID, COB.ACTIVATION, 0)
				else
					spGiveOrderToUnit(subUnitID, CMD.MOVE, {spawnData.x, spawnData.y, spawnData.z}, 0)
				end

				SetUnitNoSelect(subUnitID, true)

			end

		end




	end
end

local function attachToNewCarrier(newCarrier, subUnitID)


end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local unitDef = UnitDefs[unitDefID]
	local weaponList = unitDef.weapons

	for i = 1, #weaponList do
		local weapon = weaponList[i]
		local weaponDefID = weapon.weaponDef
		if weaponDefID and spawnDefs[weaponDefID] then

			local spawnDef = spawnDefs[weaponDefID]

			spawnCount = spawnCount + 1
			local spawnData = spawnList[spawnCount] or {}
			spawnData.spawnDef = spawnDef
			local x, y, z = spGetUnitPosition(unitID)
			spawnData.x = x
			spawnData.y = y
			spawnData.z = z
			spawnData.ownerID = unitID
			spawnData.teamID = unitTeam



			if carrierMetaList[unitID] == nil then
				local maxunits = tonumber(spawnDef.maxunits) or 1
				local dockingOffset = tonumber(spawnDef.offset) or 1
				local dockingInterval = tonumber(spawnDef.interval) or 0
				local dockingCap = tonumber(spawnDef.dockingcap) or 1
				local dockingPiece = tonumber(spawnDef.offset) or 1
				local availablePieces = {}
				for i = 1, maxunits do
					availablePieces[i] = {
						dockingPieceAvailable = true,
						dockingPieceIndex = i,
						dockingPiece = dockingPiece,
					}
					dockingPiece = dockingPiece + dockingInterval
					if dockingPiece > dockingCap then
						dockingPiece = dockingOffset
					end
				end
				local carrierData = {
					radius = tonumber(spawnDef.minRadius) or 65535,
					controlRadius = tonumber(spawnDef.radius) or 65535,
					subUnitsList = {}, -- list of subUnitIDs owned by this unit.
					subUnitCount = 0,
					subUnitsCommand = {
						cmdID = nil,
						cmdParams = nil,
					},
					subInitialSpawnData = spawnData,
					spawnRateFrames = tonumber(spawnDef.spawnRate) * 30 or 30,
					lastSpawn = 0,
					lastOrderUpdate = 0,
					maxunits = maxunits,
					metalCost = tonumber(spawnDef.metalPerUnit),
					energyCost = tonumber(spawnDef.energyPerUnit),
					docking = tonumber(spawnDef.docking),
					dockRadius = tonumber(spawnDef.dockingRadius) or 100,
					dockHelperSpeed = tonumber(spawnDef.dockingHelperSpeed) or 10,
					dockArmor = tonumber(spawnDef.dockingArmor),
					dockedHealRate = tonumber(spawnDef.dockingHealrate) or 0,
					dockToHealThreshold = tonumber(spawnDef.dockToHealThreshold) or 30,
					attackFormationSpread = tonumber(spawnDef.attackFormationSpread) or 0,
					attackFormationOffset = tonumber(spawnDef.attackFormationOffset) or 0,
					decayRate = tonumber(spawnDef.decayRate) or 0,
					deathdecayRate = tonumber(spawnDef.deathdecayRate) or tonumber(spawnDef.decayRate) or 0,
					activeDocking = false, --currently not in use
					activeRecall = false,
					activeSpawning = 1,
					availablePieces = availablePieces,
					carrierDeaththroe =spawnDef.carrierdeaththroe or "death",
					parasite = "all",
					holdfireRadius = spawnDef.holdfireRadius or 0,
				}
				carrierMetaList[unitID] = carrierData
				--spSetUnitRulesParam(unitID, "is_carrier_unit", "enabled", PRIVATE)

				InsertUnitCmdDesc(unitID, 500, spawnCmd) --temporary
			end

		end
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if carrierMetaList[unitID] then
		carrierMetaList[unitID].subInitialSpawnData.teamID = newTeam
		for subUnitID,value in pairs(carrierMetaList[unitID].subUnitsList) do
			spTransferUnit(subUnitID, newTeam, false)
		end
	end

end

function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	if carrierMetaList[unitID] then
		carrierMetaList[unitID].subInitialSpawnData.teamID = unitTeam
		for subUnitID,value in pairs(carrierMetaList[unitID].subUnitsList) do
			spTransferUnit(subUnitID, unitTeam, false)
		end
	end
end


function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)



	if carrierMetaList[unitID] and (cmdID == CMD.STOP) then
		carrierMetaList[unitID].subUnitsCommand.cmdID = nil
	 	carrierMetaList[unitID].subUnitsCommand.cmdParams = nil
		for subUnitID,value in pairs(carrierMetaList[unitID].subUnitsList) do
			if unitID == Spring.GetUnitRulesParam(subUnitID, "carrier_host_unit_id") then
				spGiveOrderToUnit(subUnitID, cmdID, cmdParams, cmdOptions)
				local px, py, pz = spGetUnitPosition(unitID)
				spGiveOrderToUnit(subUnitID, CMD.MOVE, {px, py, pz}, 0)
			end
		end
	elseif carrierMetaList[unitID] and (cmdID ~= CMD.MOVE or cmdID ~= CMD.FIRE_STATE) then
		--Spring.Echo("hornetdebug unitID:", unitID, " command:", cmdID, " commandParam:", cmdParams)
		carrierMetaList[unitID].activeRecall = false
		carrierMetaList[unitID].subUnitsCommand.cmdID = cmdID
		carrierMetaList[unitID].subUnitsCommand.cmdParams = cmdParams
	end
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if (cmdID == 31200) and carrierMetaList[unitID] then
		local cmdDescID = FindUnitCmdDesc(unitID, 31200)
		spawnCmd.params[1] = cmdParams[1]
		EditUnitCmdDesc(unitID, cmdDescID, spawnCmd)
		carrierMetaList[unitID].activeSpawning = cmdParams[1]
		spawnCmd.params[1] = 1
		return false
	end
	return true
end


function gadget:UnitDestroyed(unitID)
	local carrierUnitID = spGetUnitRulesParam(unitID, "carrier_host_unit_id")

	if carrierUnitID then
		if carrierMetaList[carrierUnitID].subUnitsList[unitID] then
			carrierMetaList[carrierUnitID].availablePieces[carrierMetaList[carrierUnitID].subUnitsList[unitID].dockingPieceIndex].dockingPieceAvailable = true
			carrierMetaList[carrierUnitID].subUnitsList[unitID] = nil
			carrierMetaList[carrierUnitID].subUnitCount = carrierMetaList[carrierUnitID].subUnitCount - 1
			totalDroneCount = totalDroneCount - 1
		end
	end

	if droneMetaList[unitID] then
		droneMetaList[unitID] = nil
		totalDroneCount = totalDroneCount - 1
	end

	if carrierMetaList[unitID] then
		for subUnitID,value in pairs(carrierMetaList[unitID].subUnitsList) do
			if carrierMetaList[unitID].subUnitsList[subUnitID] then
				local standalone = false
				local wild = false
				if carrierMetaList[unitID].carrierDeaththroe == "death" then
					spDestroyUnit(subUnitID, true)

				elseif carrierMetaList[unitID].carrierDeaththroe == "capture" then
					standalone = true
					local enemyunitID = spGetUnitNearestEnemy(subUnitID, carrierMetaList[unitID].controlRadius)
					if enemyunitID then
						spTransferUnit(subUnitID, spGetUnitTeam(enemyunitID), false)
					end
				elseif carrierMetaList[unitID].carrierDeaththroe == "control" then
					standalone = true
				elseif carrierMetaList[unitID].carrierDeaththroe == "release" then
					standalone = true
					wild = true
				elseif carrierMetaList[unitID].carrierDeaththroe == "parasite" then
					local newCarrier
					local ox, oy, oz = spGetUnitPosition(subUnitID)
					local newCarrierCandidates = Spring.GetUnitsInCylinder(ox, oz, carrierMetaList[unitID].controlRadius)
					for _, newCarrierCandidate in pairs(newCarrierCandidates) do
						local existingCarrier = Spring.GetUnitRulesParam(newCarrierCandidate, "carrier_host_unit_id")
						if not existingCarrier then
							if carrierMetaList[unitID].parasite == "ally" then
								if Spring.GetUnitAllyTeam(newCarrierCandidate) then
									newCarrier = newCarrierCandidate
								end
							elseif carrierMetaList[unitID].parasite == "enemy" then
								if not Spring.GetUnitAllyTeam(newCarrierCandidate) then
									newCarrier = newCarrierCandidate
								end

							elseif carrierMetaList[unitID].parasite == "all" then
								newCarrier = newCarrierCandidate
							end
						end

					end


					if newCarrier then
						if carrierMetaList[newCarrier] then
							standalone = true
						else
							carrierMetaList[newCarrier] = carrierMetaList[unitID]

							carrierMetaList[newCarrier].subUnitsList[subUnitID] = carrierMetaList[unitID].subUnitsList[subUnitID] -- list of subUnitIDs owned by this unit.
							carrierMetaList[newCarrier].subUnitCount = 1
							carrierMetaList[newCarrier].spawnRateFrames = 0

							carrierMetaList[newCarrier].docking = false

							carrierMetaList[newCarrier].activeRecall = false

							spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", newCarrier, PRIVATE)
						end

					else
						standalone = true
					end

				end

				if standalone then
					if not wild then
						SetUnitNoSelect(subUnitID, false)
					end
					spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", nil, PRIVATE)
					local droneData = {
						active = true,
						docked = false, --
						stayDocked = false,
						inFormation = false,
						activeDocking = false,
						engaged = false,
						wild = wild,
						decayRate = carrierMetaList[unitID].deathdecayRate,
						idleRadius = carrierMetaList[unitID].radius,
						lastOrderUpdate = 0;
					}
					droneMetaList[subUnitID] = droneData
				end

			end
		end
		carrierMetaList[unitID] = nil
	end

end


local function UpdateStandaloneDrones(frame)
	local resourceFrames = (frame - previousHealFrame) / 30
	for unitID,value in pairs(droneMetaList) do
		if droneMetaList[unitID].wild then
			-- move around unless in combat
			local cQueue = GetCommandQueue(unitID, -1)
			local engaged = false
			for j = 1, (cQueue and #cQueue or 0) do
				if cQueue[j].id == CMD.ATTACK then
					-- if currently fighting
					engaged = true
					break
				end
			end
			droneMetaList[unitID].engaged = engaged
			if not engaged and ((DEFAULT_UPDATE_ORDER_FREQUENCY + droneMetaList[unitID].lastOrderUpdate) < frame) then
				local idleRadius = droneMetaList[unitID].idleRadius
				droneMetaList[unitID].lastOrderUpdate = frame
			
				dronex, droney, dronez = spGetUnitPosition(unitID)
				rx, rz = RandomPointInUnitCircle(5)
				spGiveOrderToUnit(unitID, CMD.MOVE, {dronex + rx*idleRadius, droney, dronez + rz*idleRadius}, 0)
			end
		end

		if droneMetaList[unitID].decayRate > 0 then
			local h, mh = spGetUnitHealth(unitID)
			HealUnit(unitID, -droneMetaList[unitID].decayRate, resourceFrames, h, mh)
		end
	end
end

local function UpdateCarrier(carrierID, carrierMetaData, frame)
	local cmdID, _, _, cmdParam_1, cmdParam_2, cmdParam_3 = spGetUnitCurrentCommand(carrierID)
	local droneSendDistance = nil
	local carrierx, carriery, carrierz
	local targetx, targety, targetz
	local target
	local idleTarget
	local recallDrones = carrierMetaData.activeRecall
	local attackOrder = false
	local fightOrder = false
	local setTargetOrder = false
	local agressiveDrones = false
	local carrierStates = spGetUnitStates(carrierID)
	local newOrder = true
	
	--Spring.Echo("hornetdebug carrier:", carrierID, " command:", cmdID, " commandParam:", cmdParam_1)

	--local activeSpawning = true
	local idleRadius = carrierMetaData.radius
	if carrierStates then
		if carrierStates.firestate == 0 then
			idleRadius = carrierMetaData.holdfireRadius
			--activeSpawning = false
		elseif carrierStates.firestate == 2 then
			agressiveDrones = true
		end
		if carrierStates.movestate == 0 then
			idleRadius = 0
		elseif carrierStates.movestate == 1 then
			idleRadius = 200
		end
	end

	-- local _, _, _, _, buildProgress = Spring.GetUnitHealth(carrierID)
	-- if not buildProgress or not carrierMetaList[carrierID] then
	-- 	return
	-- elseif buildProgress < 1 then
	-- 	--activeSpawning = false
	-- 	carrierMetaList[carrierID].activeSpawning = false
	-- end
	--carrierMetaList[carrierID].activeSpawning = activeSpawning

	local minEngagementRadius = carrierMetaData.minRadius
	if carrierMetaData.subUnitsCommand.cmdID then
		local prevcmdID = cmdID
		local prevcmdParam_1 = cmdParam_1
		local prevcmdParam_2 = cmdParam_2
		local prevcmdParam_3 = cmdParam_3

		cmdID = carrierMetaData.subUnitsCommand.cmdID
		cmdParam_1 = carrierMetaData.subUnitsCommand.cmdParams[1]
		cmdParam_2 = carrierMetaData.subUnitsCommand.cmdParams[2]
		cmdParam_3 = carrierMetaData.subUnitsCommand.cmdParams[3]

		if cmdID == prevcmdID and cmdParam_1 == prevcmdParam_1 and cmdParam_2 == prevcmdParam_2 and cmdParam_3 == prevcmdParam_3 then
			newOrder = false
		end
	end


	--Handles an attack order given to the carrier.
	if not recallDrones and cmdID == CMD.ATTACK then

		carrierx, carriery, carrierz = spGetUnitPosition(carrierID)
		if cmdParam_1 and not cmdParam_2 then
			target = cmdParam_1
			targetx, targety, targetz = spGetUnitPosition(cmdParam_1)
		else
			target = {cmdParam_1, cmdParam_2, cmdParam_3}
			targetx, targety, targetz = cmdParam_1, cmdParam_2, cmdParam_3
			fightOrder = true
		end
		if targetx then
			-- droneSendDistance = GetDistance(carrierx, targetx, carrierz, targetz)
			droneSendDistance = diag((carrierx-targetx), (carrierz-targetz))
		end
		attackOrder = true --attack order overrides set target
	end


	--Handles a fight order given to the carrier.
	if not recallDrones and cmdID == CMD.FIGHT then
		carrierx, carriery, carrierz = spGetUnitPosition(carrierID)
		targetx, targety, targetz = cmdParam_1, cmdParam_2, cmdParam_3
		target = {cmdParam_1, cmdParam_2, cmdParam_3}
		if targetx then
			-- droneSendDistance = GetDistance(carrierx, targetx, carrierz, targetz)
			droneSendDistance = diag((carrierx-targetx), (carrierz-targetz))
		end
		fightOrder = true
	end

	--Handles a setTarget order given to the carrier.
	if not recallDrones and not attackOrder then
		local targetType,_,setTarget = spGetUnitWeaponTarget(carrierID, 1)
		if targetType and targetType > 0 then
			carrierx, carriery, carrierz = spGetUnitPosition(carrierID)
			if targetType == 2 then --targeting ground
				targetx = setTarget[1]
				targety = setTarget[2]
				targetz = setTarget[3]
				target = setTarget
			end
			if targetType == 1 then --targeting units
				local target_id = setTarget
				target = target_id
				targetx, targety, targetz = spGetUnitPosition(target_id)
			end
			if targetx then
				-- droneSendDistance = GetDistance(carrierx, targetx, carrierz, targetz)
				droneSendDistance = diag((carrierx-targetx), (carrierz-targetz))
			end
			setTargetOrder = true
		end
	end

	local rx, rz
	local resourceFrames = (frame - previousHealFrame) / 30
	local attackFormationPosition = 0
	local attackFormationSide = 0

	local magnitude
	local targetvectorx, targetvectorz
	local perpendicularvectorx, perpendicularvectorz
	if targetx then
		magnitude = diag((carrierx-targetx), (carrierz-targetz))
		targetvectorx, targetvectorz = targetx-carrierx, targetz-carrierz
		targetvectorx, targetvectorz = carrierMetaData.attackFormationOffset*targetvectorx/100, carrierMetaData.attackFormationOffset*targetvectorz/100
		perpendicularvectorx, perpendicularvectorz = -targetvectorz, targetvectorx
	end
	carrierx, carriery, carrierz = spGetUnitPosition(carrierID)
	local orderUpdate = false
	for subUnitID,value in pairs(carrierMetaData.subUnitsList) do
		local sx, sy, sz = spGetUnitPosition(subUnitID)
		if not sy then
			carrierMetaData.subUnitsList[subUnitID] = nil
		else
			-- local droneDistance = GetDistance(carrierx, sx, carrierz, sz)
			local droneDistance = diag((carrierx-sx), (carrierz-sz))

			--local stayDocked = false
			local h, mh = spGetUnitHealth(subUnitID)

			if h then
				if carrierMetaData.dockedHealRate > 0 and carrierMetaData.subUnitsList[subUnitID].docked then
					if h == mh then
						-- fully healed
						carrierMetaData.subUnitsList[subUnitID].stayDocked = false
					else
						-- still needs healing
						carrierMetaData.subUnitsList[subUnitID].stayDocked = true
						HealUnit(subUnitID, carrierMetaData.dockedHealRate, resourceFrames, h, mh)
					end
				elseif carrierMetaData.subUnitsList[subUnitID].activeDocking == false then
					HealUnit(subUnitID, -carrierMetaData.decayRate, resourceFrames, h, mh)
				end
				if 100*h/mh < carrierMetaData.dockToHealThreshold then
					DockUnitQueue(carrierID, subUnitID)
				end
			end

			if carrierMetaList[carrierID] then
				if carrierMetaList[carrierID].subUnitsList[subUnitID] and droneDistance then
					if (attackOrder or setTargetOrder or fightOrder) and not carrierMetaData.subUnitsList[subUnitID].inFormation then
						-- drones fire at will if carrier has an attack/target order
						-- a drone bomber probably should not do this
						spGiveOrderToUnit(subUnitID, CMD.FIRE_STATE, 2, 0)
					end
					if recallDrones or (droneDistance > carrierMetaData.controlRadius) then
						-- move drones to carrier
						carrierx, carriery, carrierz = spGetUnitPosition(carrierID)
						rx, rz = RandomPointInUnitCircle(5)
						carrierMetaData.subUnitsCommand.cmdID = nil
						carrierMetaData.subUnitsCommand.cmdParams = nil
						if idleRadius == 0 then
							DockUnitQueue(carrierID, subUnitID)
						else
							spGiveOrderToUnit(subUnitID, CMD.MOVE, {carrierx + rx*idleRadius, carriery, carrierz + rz*idleRadius}, 0)
							spGiveOrderToUnit(subUnitID, CMD.GUARD, carrierID, CMD.OPT_SHIFT)
						end
					elseif droneSendDistance and droneSendDistance < carrierMetaData.radius then
						-- attacking
						if target then


							if carrierMetaData.subUnitsList[subUnitID].docked and magnitude then

								--if not stayDocked then
								UnDockUnit(carrierID, subUnitID)
								--end
								carrierMetaData.subUnitsList[subUnitID].inFormation = true

								local p2tvx, p2tvz = attackFormationPosition*attackFormationSide*perpendicularvectorx/magnitude, attackFormationPosition*attackFormationSide*perpendicularvectorz/magnitude

								local formationx, formationz = carrierx+targetvectorx+p2tvx, carrierz+targetvectorz+p2tvz

								spGiveOrderToUnit(subUnitID, CMD.MOVE, {formationx, targety, formationz}, 0)

								if fightOrder then
									local figthRadius = carrierMetaData.radius*0.2
									rx, rz = RandomPointInUnitCircle(5)
									spGiveOrderToUnit(subUnitID, CMD.FIGHT, {targetx+rx*figthRadius, targety, targetz+rz*figthRadius}, CMD.OPT_SHIFT)
								else
									spGiveOrderToUnit(subUnitID, CMD.ATTACK, target, CMD.OPT_SHIFT)
								end
								-- spGiveOrderToUnit(subUnitID, CMD.MOVE, {targetx, targety, targetz}, CMD.OPT_SHIFT)

								if attackFormationSide == -1 then
									attackFormationSide = 1
									attackFormationPosition = attackFormationPosition + carrierMetaData.attackFormationSpread
								elseif attackFormationSide == 1 then
									attackFormationSide = -1
								else
									attackFormationSide = 1
								end
							end

							if carrierMetaData.subUnitsList[subUnitID].inFormation then
								if droneDistance > (magnitude*carrierMetaData.attackFormationOffset/100) then
									carrierMetaData.subUnitsList[subUnitID].inFormation = false

								end
							else
								if fightOrder then
									local cQueue = GetCommandQueue(subUnitID, -1)
						            for j = 1, (cQueue and #cQueue or 0) do
							            if cQueue[j].id == CMD.ATTACK and carrierStates.firestate > 0 then
								                idleTarget = cQueue[j].params
								            break
							            end
									end

									if idleTarget then
								        spGiveOrderToUnit(subUnitID, CMD.ATTACK, idleTarget, 0)
									else
									    local figthRadius = carrierMetaData.radius*0.2
									    rx, rz = RandomPointInUnitCircle(5)
									    spGiveOrderToUnit(subUnitID, CMD.FIGHT, {targetx+rx*figthRadius, targety, targetz+rz*figthRadius}, 0)
									end
								else
									spGiveOrderToUnit(subUnitID, CMD.ATTACK, target, 0)
								end
							end
							-- elseif ((frame % DEFAULT_UPDATE_ORDER_FREQUENCY) == 0) then
						elseif ((DEFAULT_UPDATE_ORDER_FREQUENCY + carrierMetaData.lastOrderUpdate) < frame) then
							orderUpdate = true
							if idleRadius == 0 then
								DockUnitQueue(carrierID, subUnitID)
							else
								UnDockUnit(carrierID, subUnitID)
								rx, rz = RandomPointInUnitCircle(5)
								spGiveOrderToUnit(subUnitID, CMD.MOVE, {carrierx + rx*idleRadius, carriery, carrierz + rz*idleRadius}, 0)
							end
						end
					elseif not carrierMetaData.subUnitsList[subUnitID].keepDocked then
						-- return to carrier unless in combat
						local cQueue = GetCommandQueue(subUnitID, -1)
						local engaged = false
						for j = 1, (cQueue and #cQueue or 0) do
							if cQueue[j].id == CMD.ATTACK and carrierStates.firestate > 0 then
								-- if currently fighting AND not on hold fire
								engaged = true
								if agressiveDrones then
								    idleTarget = cQueue[j].params
								end
								break
							end
						end
						carrierMetaData.subUnitsList[subUnitID].engaged = engaged
						-- if not engaged and ((frame % DEFAULT_UPDATE_ORDER_FREQUENCY) == 0) then
						if not engaged and ((DEFAULT_UPDATE_ORDER_FREQUENCY + carrierMetaData.lastOrderUpdate) < frame) then
							orderUpdate = true
							if idleRadius == 0 then
								DockUnitQueue(carrierID, subUnitID)
							else
								carrierx, carriery, carrierz = spGetUnitPosition(carrierID)
								rx, rz = RandomPointInUnitCircle(5)
								UnDockUnit(carrierID, subUnitID)
								if idleTarget then
								    spGiveOrderToUnit(subUnitID, CMD.ATTACK, idleTarget, 0)
								else
								    spGiveOrderToUnit(subUnitID, CMD.MOVE, {carrierx + rx*idleRadius, carriery, carrierz + rz*idleRadius}, 0)
								    spGiveOrderToUnit(subUnitID, CMD.GUARD, carrierID, CMD.OPT_SHIFT)
								end
							end
						end
					end
				end
			end
		end
	end
	if orderUpdate then
		lastOrderUpdate = frame
	end
end


local function DockUnits(dockingqueue, queuestart, queueend)
	for i = queuestart, queueend do
		local unitID = dockingqueue[i].ownerID
		local subUnitID = dockingqueue[i].subunitID
		local subunitDefID	= spGetUnitDefID(subUnitID)
		local subunitDef = UnitDefs[subunitDefID]
		local ox, oy, oz = spGetUnitPosition(unitID)
		local subx, suby, subz = spGetUnitPosition(subUnitID)
		local dockingSnapRange

		if unitID and subUnitID and carrierMetaList[unitID] then

			if carrierMetaList[unitID].subUnitsList[subUnitID] then
				if carrierMetaList[unitID].subUnitsList[subUnitID].dockingPiece then
					local pieceNumber = carrierMetaList[unitID].subUnitsList[subUnitID].dockingPiece
					--local distance = GetDistance(ox, subx, oz, subz)
					local function LandLoop()
						if not carrierMetaList[unitID] then
							return
						elseif not carrierMetaList[unitID].subUnitsList[subUnitID] then
							return
						end
						while not carrierMetaList[unitID].subUnitsList[subUnitID].docked do

							local px, py, pz = Spring.GetUnitPiecePosDir(unitID, pieceNumber)
							--ox, oy, oz = spGetUnitPosition(unitID)
							subx, suby, subz = spGetUnitPosition(subUnitID)
							-- local distance = GetDistance(px, subx, pz, subz)
							local distance = diag((px-subx), (pz-subz))
							-- local heightDifference = GetDistance(py, suby, 0, 0)
							local heightDifference = diag(py-suby)

							if not distance then
								return
							end
							if distance < 25 and subunitDef.isAirUnit then
								local landingspeed = carrierMetaList[unitID].dockHelperSpeed
								if 0.2*heightDifference > landingspeed then
									landingspeed = 0.2*heightDifference
								end
								-- local vx, vy, vz = GetDirectionalVector(landingspeed, subx, px, suby, py, subz, pz)
								local magnitude = diag((subx-px), (suby-py), (subz-pz))
								local vx, vy, vz = px-subx, py-suby, pz-subz
								vx, vy, vz = landingspeed*vx/magnitude, landingspeed*vy/magnitude, landingspeed*vz/magnitude
								spSetUnitVelocity(subUnitID, vx, vy, vz)

							elseif distance < carrierMetaList[unitID].dockRadius then
								local landingspeed = carrierMetaList[unitID].dockHelperSpeed
								-- local vx, vy, vz = GetDirectionalVector(carrierMetaList[unitID].dockHelperSpeed, subx, px, suby, py, subz, pz)
								local magnitude = diag((subx-px), (suby-py), (subz-pz))
								local vx, vy, vz = px-subx, py-suby, pz-subz
								vx, vy, vz = landingspeed*vx/magnitude, landingspeed*vy/magnitude, landingspeed*vz/magnitude
								Spring.MoveCtrl.Enable(subUnitID)
								mcSetPosition(subUnitID, subx+vx, suby, subz+vz)
								Spring.MoveCtrl.Disable(subUnitID)
								spSetUnitVelocity(subUnitID, vx, 0, vz)
								heightDifference = 0

							else
								spGiveOrderToUnit(subUnitID, CMD.STOP, {}, 0)
								spGiveOrderToUnit(subUnitID, CMD.MOVE, {px, py, pz}, 0)
							end

							carrierMetaList[unitID].activeDocking = true
							if carrierMetaList[unitID].dockHelperSpeed == 0 then
								dockingSnapRange = carrierMetaList[unitID].dockRadius
							else
								dockingSnapRange = carrierMetaList[unitID].dockHelperSpeed
							end

							if distance < dockingSnapRange and heightDifference < dockingSnapRange and carrierMetaList[unitID].subUnitsList[subUnitID].docked ~= true then
								spUnitAttach(unitID, subUnitID, pieceNumber)
								spGiveOrderToUnit(subUnitID, CMD.STOP, {}, 0)
								Spring.MoveCtrl.Disable(subUnitID)
								spSetUnitVelocity(subUnitID, 0, 0, 0)
								SetUnitNoSelect(subUnitID, true)
								carrierMetaList[unitID].subUnitsList[subUnitID].docked = true
								carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking = false
								if carrierMetaList[unitID].dockArmor then
									spSetUnitArmored(subUnitID, true, carrierMetaList[unitID].dockArmor)
								end
								Spring.SetUnitCOBValue(subUnitID, COB.ACTIVATION, 0)
							end

							Sleep()
							
							if not carrierMetaList[unitID] then
								return
							elseif not carrierMetaList[unitID].subUnitsList[subUnitID] then
								return
							else
								local h = spGetUnitHealth(subUnitID)
								if not h then
									return
								elseif h <= 0 then
									return
								end
							end
							
						end
					end

					StartScript(LandLoop)
				end
			end
		end
	end
end


function gadget:GameFrame(f)
	UpdateCoroutines()
	if f % GAME_SPEED ~= 0 then
		return
	end

	-- if ((f % DEFAULT_SPAWN_CHECK_FREQUENCY) == 0) then
	if ((DEFAULT_SPAWN_CHECK_FREQUENCY + lastSpawnCheck) < f) then
		lastSpawnCheck = f
		for unitID, _ in pairs(carrierMetaList) do
			local isDoneBuilding = not Spring.GetUnitIsBeingBuilt(unitID)
			if carrierMetaList[unitID].spawnRateFrames == 0 then
				-- elseif ((f % carrierMetaList[unitID].spawnRateFrames) == 0 and carrierMetaList[unitID].activeSpawning == 1 and buildProgress == 1) then
			elseif ((carrierMetaList[unitID].spawnRateFrames + carrierMetaList[unitID].lastSpawn) < f and carrierMetaList[unitID].activeSpawning == 1 and isDoneBuilding) then
				local spawnData = carrierMetaList[unitID].subInitialSpawnData
				local x, y, z = spGetUnitPosition(unitID)
				spawnData.x = x
				spawnData.y = y
				spawnData.z = z

				if x then
					SpawnUnit(spawnData)
					carrierMetaList[unitID].lastSpawn = f
				end
			end
		end
	end

	-- if ((f % CARRIER_UPDATE_FREQUENCY) == 0) then
	if ((CARRIER_UPDATE_FREQUENCY + lastCarrierUpdate) < f) then
		lastCarrierUpdate = f
		for unitID, _ in pairs(carrierMetaList) do
			UpdateCarrier(unitID, carrierMetaList[unitID], f)
		end
		UpdateStandaloneDrones(f)
		previousHealFrame = f
	end


	-- if ((f % DEFAULT_DOCK_CHECK_FREQUENCY) == 0) then
	if ((DEFAULT_DOCK_CHECK_FREQUENCY + lastDockCheck) < f) then
		lastDockCheck = f
		if carrierQueuedDockingCount > 0 then -- Initiate docking for units in the docking queue and reset the queue.
			local availableDockingCount = (carrierAvailableDockingCount-#coroutines)
			local carrierActiveDockingList = {}
			local carrierDockingCount = 0
			if (carrierQueuedDockingCount - dockingQueueOffset) > availableDockingCount then
				carrierActiveDockingList = carrierDockingList
				DockUnits(carrierActiveDockingList, (dockingQueueOffset+1), (dockingQueueOffset+availableDockingCount))
				dockingQueueOffset = dockingQueueOffset+availableDockingCount
			else
				carrierActiveDockingList = carrierDockingList
				carrierDockingCount = carrierQueuedDockingCount
				carrierQueuedDockingCount = 0
				DockUnits(carrierActiveDockingList, (dockingQueueOffset+1), carrierDockingCount)
				dockingQueueOffset = 0
			end
		end
	end

end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
	end
end

function gadget:Shutdown()
	for unitID, _ in pairs(carrierMetaList) do
		for subUnitID,value in pairs(carrierMetaList[unitID].subUnitsList) do
			spDestroyUnit(subUnitID, true, true)
		end
	end
end
