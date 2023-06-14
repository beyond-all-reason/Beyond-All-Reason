
if (not gadgetHandler:IsSyncedCode()) then
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

local spCreateFeature           = Spring.CreateFeature
local spCreateUnit              = Spring.CreateUnit
local spDestroyUnit             = Spring.DestroyUnit
local spGetGameFrame            = Spring.GetGameFrame
local spGetProjectileDefID      = Spring.GetProjectileDefID
local spGetProjectileTeamID     = Spring.GetProjectileTeamID
local spGetUnitShieldState      = Spring.GetUnitShieldState
local spGiveOrderToUnit         = Spring.GiveOrderToUnit
local spSetFeatureDirection     = Spring.SetFeatureDirection
local spSetUnitRulesParam       = Spring.SetUnitRulesParam
local spGetUnitPosition			= Spring.GetUnitPosition
local SetUnitNoSelect			= Spring.SetUnitNoSelect
local spGetUnitRulesParam		= Spring.GetUnitRulesParam
local spUseTeamResource 		= Spring.UseTeamResource
local spGetTeamResources 		= Spring.GetTeamResources
local GetCommandQueue     		= Spring.GetCommandQueue
local spSetUnitArmored 			= Spring.SetUnitArmored
local spGetUnitStates			= Spring.GetUnitStates
local spGetUnitBasePosition		= Spring.GetUnitBasePosition
local spGetUnitDefID        	= Spring.GetUnitDefID
local spSetUnitVelocity     	= Spring.SetUnitVelocity
local spGetUnitHeading      	= Spring.GetUnitHeading
local spGetUnitVelocity     	= Spring.GetUnitVelocity
local spUnitAttach 				= Spring.UnitAttach
local spUnitDetach 				= Spring.UnitDetach
local spSetUnitHealth 			= Spring.SetUnitHealth
local spGetGroundHeight 		= Spring.GetGroundHeight
local spGetUnitNearestEnemy		= Spring.GetUnitNearestEnemy
local spTransferUnit			= Spring.TransferUnit
local spGetUnitTeam 			= Spring.GetUnitTeam
local spGetUnitsInCylinder 		= Spring.GetUnitsInCylinder
local spGetUnitAllyTeam 		= Spring.GetUnitAllyTeam
local spGetUnitHealth 			= Spring.GetUnitHealth
local spGetUnitCurrentCommand 	= Spring.GetUnitCurrentCommand
local spGetUnitWeaponTarget		= Spring.GetUnitWeaponTarget

local mcEnable 				= Spring.MoveCtrl.Enable
local mcSetPosition 		= Spring.MoveCtrl.SetPosition
local mcDisable 			= Spring.MoveCtrl.Disable
local mcSetVelocity         = Spring.MoveCtrl.SetVelocity
local mcSetPosition         = Spring.MoveCtrl.SetPosition

local mapsizeX 				  = Game.mapSizeX
local mapsizeZ 				  = Game.mapSizeZ

local random = math.random
local math_min = math.min
local sin    = math.sin
local cos    = math.cos
local power = math.pow
local diag = math.diag

local PI = math.pi
local GAME_SPEED = Game.gameSpeed
local TAU = 2 * PI
local PRIVATE = { private = true }
local CMD_WAIT = CMD.WAIT
local EMPTY_TABLE = {}

local noCreate = false

local spawnDefs = {}
local shieldCollide = {}
local wantedList = {}

local spawnList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}
local spawnCount = 0


local carrierDockingList = {}
local carrierQueuedDockingCount = 0
local previousHealFrame = 0

local carrierActiveDockingList = {}
local carrierAvailableDockingCount = 1000   -- Limits the amount of drones that can dock simultaneously. Lowering this will increase overall game performance, but some drones might not be able to dock in time. Increasing this above 1500 could cause memory issues in large battles. 
local dockingQueueOffset = 0


local carrierMetaList = {}
local droneMetaList = {}



-- These control the frequency, in gameframes, of different actions. Increasing these will improve overall game performance at the cost of this gadgets responsiveness.
local DEFAULT_UPDATE_ORDER_FREQUENCY = 60	-- Idle movement orders for drones. Must be a multiple of the CARRIER_UPDATE_FREQUENCY to be enabled.
local CARRIER_UPDATE_FREQUENCY = 30			-- Update dronestates and orders. 
local DEFAULT_SPAWN_CHECK_FREQUENCY = 30 	-- Controls the minimum possible spawnrate. Do not change. Todo: make changes to the spawnrate check to enable changing this value.
local DEFAULT_DOCK_CHECK_FREQUENCY = 30		-- Checks the docking queue. Increasing this will decrease docking responsiveness, and may cause some drones to dock too late. 


local coroutine = coroutine
local Sleep     = coroutine.yield
local assert    = assert

local coroutines = {}


--TEMPORARY for debugging
local totalDroneCount = 0

-- ZECRUS, values can be tuned in the unitdef file. Add the section below to a weaponDef list in the unitdef file.
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
	-- decayrate = 0,				health loss per second while not docked. 
	-- carrierdeaththroe = "death",	Behaviour for the drones when the carrier dies. "death": destroy the drones. "control": gain manual control of the drones. "capture": same as "control", but if an enemy is within control range, they get control of the drones instead. 
	
	-- },							 

	-- Notes:
	--todo:
	-- multiple unit types
	-- test all command states
	-- rearming stockpiles mechanic similarly to the healing behaviour
	-- add firewhiledocked as an option.

for weaponDefID = 1, #WeaponDefs do
	local wdcp = WeaponDefs[weaponDefID].customParams
	
	if wdcp.carried_unit then
		spawnDefs[weaponDefID] = {
			name = wdcp.carried_unit,
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
			decayRate = wdcp.decayrate,
			dockToHealThreshold = wdcp.docktohealthreshold,
			carrierdeaththroe = wdcp.carrierdeaththroe
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
		end
		if spawnData.x > 0 and spawnData.x < mapsizeX and spawnData.z > 0 and spawnData.z < mapsizeZ then
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
	
				
				if ownerID then
					spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", ownerID, PRIVATE)
					local subUnitCount = carrierMetaList[ownerID].subUnitCount
					subUnitCount = subUnitCount + 1
					carrierMetaList[ownerID].subUnitCount = subUnitCount
					local dockingpiece
					local dockingpieceindex
					for i = 1, #carrierMetaList[ownerID].availablePieces do
						if carrierMetaList[ownerID].availablePieces[i].dockingPieceAvailable then
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
						engaged = false,
						dockingPiece = dockingpiece, --
						dockingPieceIndex = dockingpieceindex,
					}
					carrierMetaList[ownerID].subUnitsList[subUnitID] = droneData
					totalDroneCount = totalDroneCount + 1
				end


				mcEnable(subUnitID)
				mcSetPosition(subUnitID, spawnData.x, spawnData.y, spawnData.z)
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
					maxunits = maxunits,
					metalCost = tonumber(spawnDef.metalPerUnit),
					energyCost = tonumber(spawnDef.energyPerUnit),
					docking = tonumber(spawnDef.docking),
					dockRadius = tonumber(spawnDef.dockingRadius) or 100,
					dockHelperSpeed = tonumber(spawnDef.dockingHelperSpeed) or 10,
					dockArmor = tonumber(spawnDef.dockingArmor),
					dockedHealRate = tonumber(spawnDef.dockingHealrate) or 0,
					dockToHealThreshold = tonumber(spawnDef.dockToHealThreshold) or 30,
					decayRate = tonumber(spawnDef.decayRate) or 0,
					activeDocking = false, --currently not in use
					activeRecall = false,
					activeSpawning = false,
					availablePieces = availablePieces,
					carrierDeaththroe =spawnDef.carrierdeaththroe or "death",
					parasite = "all",
				}
				carrierMetaList[unitID] = carrierData
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
		carrierMetaList[unitID].activeRecall = false
		carrierMetaList[unitID].subUnitsCommand.cmdID = cmdID
		carrierMetaList[unitID].subUnitsCommand.cmdParams = cmdParams
	end
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
					SetUnitNoSelect(subUnitID, false)
					spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", nil, PRIVATE)
					local droneData = {
						active = true,
						docked = false, --
						stayDocked = false,
						activeDocking = false,
						engaged = false,
						decayRate = carrierMetaList[unitID].decayRate,
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
		if droneMetaList[unitID].decayRate > 0 then
			local h, mh = spGetUnitHealth(unitID)
			HealUnit(unitID, -droneMetaList[unitID].decayRate, resourceFrames, h, mh)
		end
	end
end

local function UpdateCarrier(carrierID, carrierMetaData, frame)
	local cmdID, _, _, cmdParam_1, cmdParam_2, cmdParam_3 = spGetUnitCurrentCommand(carrierID)
	local droneSendDistance = nil
	local ox, oy, oz
	local px, py, pz
	local target
	local recallDrones = carrierMetaData.activeRecall
	local attackOrder = false
	local fightOrder = false
	local setTargetOrder = false
	local carrierStates = spGetUnitStates(carrierID)
	local newOrder = true

	
	local activeSpawning = true
	local idleRadius = carrierMetaData.radius
	if carrierStates then
		if carrierStates.firestate == 0 then
			idleRadius = 0
			activeSpawning = false
		elseif carrierStates.movestate == 0 then
			idleRadius = 0
		elseif carrierStates.movestate == 1 then
			idleRadius = 200
		end
	end
	
	local _, _, _, _, buildProgress = Spring.GetUnitHealth(carrierID)
	
	if not buildProgress or not carrierMetaList[carrierID] then
		return
	elseif buildProgress < 1 then
		activeSpawning = false
	end
	
	carrierMetaList[carrierID].activeSpawning = activeSpawning
	
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
		ox, oy, oz = spGetUnitPosition(carrierID)
		if cmdParam_1 and not cmdParam_2 then
			target = cmdParam_1
			px, py, pz = spGetUnitPosition(cmdParam_1)
		else
			target = {cmdParam_1, cmdParam_2, cmdParam_3}
			px, py, pz = cmdParam_1, cmdParam_2, cmdParam_3
		end
		if px then
			-- droneSendDistance = GetDistance(ox, px, oz, pz)
			droneSendDistance = diag((ox-px), (oz-pz))
		end
		attackOrder = true --attack order overrides set target
	end
	
	
	--Handles a fight order given to the carrier.
	if not recallDrones and cmdID == CMD.FIGHT then
		ox, oy, oz = spGetUnitPosition(carrierID)
		px, py, pz = cmdParam_1, cmdParam_2, cmdParam_3
		target = {cmdParam_1, cmdParam_2, cmdParam_3}
		if px then
			-- droneSendDistance = GetDistance(ox, px, oz, pz)
			droneSendDistance = diag((ox-px), (oz-pz))
		end
		fightOrder = true 
	end
	
	--Handles a setTarget order given to the carrier.
	if not recallDrones and not attackOrder then
		local targetType,_,setTarget = spGetUnitWeaponTarget(carrierID, 1)
		if targetType and targetType > 0 then
			ox, oy, oz = spGetUnitPosition(carrierID)
			if targetType == 2 then --targeting ground
				px = setTarget[1]
				py = setTarget[2]
				pz = setTarget[3]
				target = setTarget
			end
			if targetType == 1 then --targeting units
				local target_id = setTarget
				target = target_id
				px, py, pz = spGetUnitPosition(target_id)
			end
			if px then
				-- droneSendDistance = GetDistance(ox, px, oz, pz)
				droneSendDistance = diag((ox-px), (oz-pz))
			end
			setTargetOrder = true
		end
	end

	local rx, rz
	local resourceFrames = (frame - previousHealFrame) / 30
	for subUnitID,value in pairs(carrierMetaData.subUnitsList) do
		ox, oy, oz = spGetUnitPosition(carrierID)
		local sx, sy, sz = spGetUnitPosition(subUnitID)
		-- local droneDistance = GetDistance(ox, sx, oz, sz)
		local droneDistance = diag((ox-sx), (oz-sz))

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
			else
				HealUnit(subUnitID, -carrierMetaData.decayRate, resourceFrames, h, mh)
			end
			if 100*h/mh < carrierMetaData.dockToHealThreshold then
				DockUnitQueue(carrierID, subUnitID)
			end
		end

		if carrierMetaList[carrierID] then
			if carrierMetaList[carrierID].subUnitsList[subUnitID] and droneDistance then
				if attackOrder or setTargetOrder or fightOrder then
					-- drones fire at will if carrier has an attack/target order
					-- a drone bomber probably should not do this
					spGiveOrderToUnit(subUnitID, CMD.FIRE_STATE, 2, 0)
				end
				if recallDrones or (droneDistance > carrierMetaData.controlRadius) then
					-- move drones to carrier
					px, py, pz = spGetUnitPosition(carrierID)
					rx, rz = RandomPointInUnitCircle(5)
					carrierMetaData.subUnitsCommand.cmdID = nil
					carrierMetaData.subUnitsCommand.cmdParams = nil
					if idleRadius == 0 then
						DockUnitQueue(carrierID, subUnitID)
					else
						spGiveOrderToUnit(subUnitID, CMD.MOVE, {px + rx*idleRadius, py, pz + rz*idleRadius}, 0)
						spGiveOrderToUnit(subUnitID, CMD.GUARD, carrierID, CMD.OPT_SHIFT)
					end
				elseif droneSendDistance and droneSendDistance < carrierMetaData.radius then
					-- attacking
					if target then
						if not stayDocked then
							UnDockUnit(carrierID, subUnitID)
						end
						if fightOrder then
							spGiveOrderToUnit(subUnitID, CMD.FIGHT, {px, py, pz}, 0)
						else
							spGiveOrderToUnit(subUnitID, CMD.ATTACK, target, 0)
						end
					elseif ((frame % DEFAULT_UPDATE_ORDER_FREQUENCY) == 0) then
						
						if idleRadius == 0 then
							DockUnitQueue(carrierID, subUnitID)
						else
							UnDockUnit(carrierID, subUnitID)
							rx, rz = RandomPointInUnitCircle(5)
							spGiveOrderToUnit(subUnitID, CMD.MOVE, {px + rx*idleRadius, py, pz + rz*idleRadius}, 0)
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
							break
						end
					end
					carrierMetaData.subUnitsList[subUnitID].engaged = engaged
					if not engaged and ((frame % DEFAULT_UPDATE_ORDER_FREQUENCY) == 0) then
						if idleRadius == 0 then
							DockUnitQueue(carrierID, subUnitID)
						else
							px, py, pz = spGetUnitPosition(carrierID)
							rx, rz = RandomPointInUnitCircle(5)
							UnDockUnit(carrierID, subUnitID)
							spGiveOrderToUnit(subUnitID, CMD.MOVE, {px + rx*idleRadius, py, pz + rz*idleRadius}, 0)
							spGiveOrderToUnit(subUnitID, CMD.GUARD, carrierID, CMD.OPT_SHIFT)
						end
					end
				end
			end
		end
		
	
		
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
								
			
			
								ox, oy, oz = spGetUnitPosition(unitID)
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
								end
			
								Sleep()
								if not carrierMetaList[unitID] then
									return
								elseif not carrierMetaList[unitID].subUnitsList[subUnitID] then
									return
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



	if ((f % DEFAULT_SPAWN_CHECK_FREQUENCY) == 0) then
		for unitID, _ in pairs(carrierMetaList) do
			if carrierMetaList[unitID].spawnRateFrames == 0 then
			elseif ((f % carrierMetaList[unitID].spawnRateFrames) == 0 and carrierMetaList[unitID].activeSpawning) then
				local spawnData = carrierMetaList[unitID].subInitialSpawnData
				local x, y, z = spGetUnitPosition(unitID)
				spawnData.x = x
				spawnData.y = y
				spawnData.z = z

				if x then
					SpawnUnit(spawnData)
				end
			end
		end
	end


	if ((f % CARRIER_UPDATE_FREQUENCY) == 0) then
		for unitID, _ in pairs(carrierMetaList) do
			UpdateCarrier(unitID, carrierMetaList[unitID], f)
		end
		UpdateStandaloneDrones(f)
		previousHealFrame = f
	end

	
	if ((f % DEFAULT_DOCK_CHECK_FREQUENCY) == 0) then
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







