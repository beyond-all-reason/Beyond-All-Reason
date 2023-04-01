
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
		layer = 50,
		enabled = true
	}
end

local spCreateFeature         = Spring.CreateFeature
local spCreateUnit            = Spring.CreateUnit
local spDestroyUnit           = Spring.DestroyUnit
local spGetGameFrame          = Spring.GetGameFrame
local spGetProjectileDefID    = Spring.GetProjectileDefID
local spGetProjectileTeamID   = Spring.GetProjectileTeamID
local spGetUnitShieldState    = Spring.GetUnitShieldState
local spGiveOrderToUnit       = Spring.GiveOrderToUnit
local spSetFeatureDirection   = Spring.SetFeatureDirection
local spSetUnitRulesParam     = Spring.SetUnitRulesParam
local spGetUnitPosition       = Spring.GetUnitPosition
local SetUnitNoSelect         = Spring.SetUnitNoSelect
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spUseTeamResource = Spring.UseTeamResource --(teamID, "metal"|"energy", amount) return nil | bool hadEnough
local spGetTeamResources = Spring.GetTeamResources --(teamID, "metal"|"energy") return nil | currentLevel
local GetCommandQueue     = Spring.GetCommandQueue
local spSetUnitArmored = Spring.SetUnitArmored
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitDefID        = Spring.GetUnitDefID
local spSetUnitVelocity     = Spring.SetUnitVelocity
local spGetUnitHeading      = Spring.GetUnitHeading
local spGetUnitVelocity     = Spring.GetUnitVelocity


local mcSetVelocity         = Spring.MoveCtrl.SetVelocity
local mcSetPosition         = Spring.MoveCtrl.SetPosition

local mapsizeX 				  = Game.mapSizeX
local mapsizeZ 				  = Game.mapSizeZ

local random = math.random
local math_min = math.min
local sin    = math.sin
local cos    = math.cos

local GAME_SPEED = Game.gameSpeed
local TAU = 2 * math.pi
local PRIVATE = { private = true }
local CMD_WAIT = CMD.WAIT
local EMPTY_TABLE = {}

local noCreate = false

local spawnDefs = {}
local shieldCollide = {}
local wantedList = {}

local spawnList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}, subtables reused
local spawnCount = 0


GG.carrierDockingList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}, subtables reused
GG.carrierQueuedDockingCount = 0
local previousHealFrame = 0


GG.carrierMetaList = {}
GG.droneMetaList = {}


local DEFAULT_UPDATE_ORDER_FREQUENCY = 30--21 -- gameframes
local CARRIER_UPDATE_FREQUENCY = 20--11 -- gameframes
local DEFAULT_SPAWN_CHECK_FREQUENCY = 30 -- gameframes


local coroutine = coroutine
local Sleep     = coroutine.yield
local assert    = assert



--TEMPORARY
local healcount = 0
local heallist = {}
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





-- local firewhiledocked = false
-- local carriedUnitType
-- local dockingParts1 = {}

local spUnitAttach = Spring.UnitAttach  --can attach to  specific pieces using pieceID
local spUnitDetach = Spring.UnitDetach

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


local function GetDistance(x1, x2, y1, y2)
	if x1 and x2 then
		return ((x1-x2)^2 + (y1-y2)^2)^0.5
	else
		return
	end
end


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
	local angle = random(0, 2*math.pi)
	local distance = math.pow(random((startpointoffset/100), 1), 0.5)
	return math.cos(angle)*distance, math.sin(angle)*distance
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
		Spring.DestroyUnit(unitID, true)
	else
		Spring.SetUnitHealth(unitID, newHealth)
	end
end



local function DockUnitQueue(unitID, subUnitID) -- adds unit to docking queue, set returnedtoqueue if used to readd a unit that has been removed from the queue, but did not reach the dockerhelper stage.
	if not GG.carrierMetaList[unitID] then
		return
	elseif not GG.carrierMetaList[unitID].subUnitsList[subUnitID] then
		return
	elseif GG.carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking then
		return
	end
	GG.carrierQueuedDockingCount = GG.carrierQueuedDockingCount + 1
	local dockData = GG.carrierDockingList[GG.carrierQueuedDockingCount] or {}
	dockData.ownerID = unitID
	dockData.subunitID = subUnitID
	GG.carrierDockingList[GG.carrierQueuedDockingCount] = dockData
	GG.carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking = true
end



local function UnDockUnit(unitID, subUnitID)
	if not GG.carrierMetaList[unitID] then
		return
	elseif not GG.carrierMetaList[unitID].subUnitsList[subUnitID] then
		return
	elseif GG.carrierMetaList[unitID].subUnitsList[subUnitID].docked == true and not GG.carrierMetaList[unitID].subUnitsList[subUnitID].stayDocked then
		spUnitDetach(subUnitID)
		Spring.MoveCtrl.Disable(subUnitID)
		SetUnitNoSelect(subUnitID, true)
		GG.carrierMetaList[unitID].subUnitsList[subUnitID].docked = false
		GG.carrierMetaList[unitID].activeDocking = false
		GG.carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking = false
		if GG.carrierMetaList[unitID].dockArmor then
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
			local y = Spring.GetGroundHeight(spawnData.x, spawnData.z)
			if string.find(spawnDef.surface, "LAND") and y > 0 then
				validSurface = true
			elseif string.find(spawnDef.surface, "SEA") and y <= 0 then
				validSurface = true
			end
		end
		

		local subUnitID = nil
		local ownerID = spawnData.ownerID
		if validSurface == true and ownerID then
			if GG.carrierMetaList[spawnData.ownerID].subUnitCount < GG.carrierMetaList[spawnData.ownerID].maxunits then
				local metalCost
				local energyCost
				if GG.carrierMetaList[spawnData.ownerID].metalCost and GG.carrierMetaList[spawnData.ownerID].energyCost then
					metalCost = GG.carrierMetaList[spawnData.ownerID].metalCost
					energyCost = GG.carrierMetaList[spawnData.ownerID].energyCost

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
					local subUnitCount = GG.carrierMetaList[ownerID].subUnitCount
					subUnitCount = subUnitCount + 1
					GG.carrierMetaList[ownerID].subUnitCount = subUnitCount
					local dockingpiece
					local dockingpieceindex
					for i = 1, #GG.carrierMetaList[ownerID].availablePieces do
						if GG.carrierMetaList[ownerID].availablePieces[i].dockingPieceAvailable then
							dockingpiece = GG.carrierMetaList[ownerID].availablePieces[i].dockingPiece
							dockingpieceindex = i
							GG.carrierMetaList[ownerID].availablePieces[i].dockingPieceAvailable = false
							break
						end
					end
					GG.carrierMetaList[ownerID].subUnitsList[subUnitID] = {
						active = true,
						docked = false, --
						stayDocked = false,
						activeDocking = false,
						engaged = false,
						dockingPiece = dockingpiece, --
						dockingPieceIndex = dockingpieceindex,
					}
					totalDroneCount = totalDroneCount + 1
				end


				Spring.MoveCtrl.Enable(subUnitID)
				Spring.MoveCtrl.SetPosition(subUnitID, spawnData.x, spawnData.y, spawnData.z)
				Spring.MoveCtrl.Disable(subUnitID)


				if GG.carrierMetaList[ownerID].docking and GG.carrierMetaList[ownerID].subUnitsList[subUnitID].dockingPiece then
					spUnitAttach(ownerID, subUnitID, GG.carrierMetaList[ownerID].subUnitsList[subUnitID].dockingPiece)
					spGiveOrderToUnit(subUnitID, CMD.STOP, {}, 0)
					Spring.MoveCtrl.Disable(subUnitID)
					spSetUnitVelocity(subUnitID, 0, 0, 0)
					SetUnitNoSelect(subUnitID, true)
					GG.carrierMetaList[ownerID].subUnitsList[subUnitID].docked = true
					GG.carrierMetaList[ownerID].subUnitsList[subUnitID].activeDocking = false
					if GG.carrierMetaList[ownerID].dockArmor then
						spSetUnitArmored(subUnitID, true, GG.carrierMetaList[ownerID].dockArmor)
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
			


			if GG.carrierMetaList[unitID] == nil then
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
				GG.carrierMetaList[unitID] = {
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
			end
			
		end
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)



	if GG.carrierMetaList[unitID] and (cmdID == CMD.STOP) then
		GG.carrierMetaList[unitID].subUnitsCommand.cmdID = nil
	 	GG.carrierMetaList[unitID].subUnitsCommand.cmdParams = nil
		for subUnitID,value in pairs(GG.carrierMetaList[unitID].subUnitsList) do
			if unitID == Spring.GetUnitRulesParam(subUnitID, "carrier_host_unit_id") then
				spGiveOrderToUnit(subUnitID, cmdID, cmdParams, cmdOptions)
				local px, py, pz = spGetUnitPosition(unitID)
				spGiveOrderToUnit(subUnitID, CMD.MOVE, {px, py, pz}, 0)
			end
		end
	elseif GG.carrierMetaList[unitID] and (cmdID ~= CMD.MOVE or cmdID ~= CMD.FIRE_STATE) then
		GG.carrierMetaList[unitID].activeRecall = false
		GG.carrierMetaList[unitID].subUnitsCommand.cmdID = cmdID
		GG.carrierMetaList[unitID].subUnitsCommand.cmdParams = cmdParams
		for subUnitID,value in pairs(GG.carrierMetaList[unitID].subUnitsList) do
			if unitID == Spring.GetUnitRulesParam(subUnitID, "carrier_host_unit_id") then
				--spGiveOrderToUnit(subUnitID, cmdID, cmdParams, cmdOptions)
			end
			
		end
	end
end

function gadget:UnitDestroyed(unitID)
	local carrierUnitID = Spring.GetUnitRulesParam(unitID, "carrier_host_unit_id")
	
	if carrierUnitID then
		if GG.carrierMetaList[carrierUnitID].subUnitsList[unitID] then
			GG.carrierMetaList[carrierUnitID].availablePieces[GG.carrierMetaList[carrierUnitID].subUnitsList[unitID].dockingPieceIndex].dockingPieceAvailable = true
			GG.carrierMetaList[carrierUnitID].subUnitsList[unitID] = nil
			GG.carrierMetaList[carrierUnitID].subUnitCount = GG.carrierMetaList[carrierUnitID].subUnitCount - 1
			totalDroneCount = totalDroneCount - 1
		end
	end

	if GG.droneMetaList[unitID] then
		GG.droneMetaList[unitID] = nil
		totalDroneCount = totalDroneCount - 1
	end

	if GG.carrierMetaList[unitID] then
		for subUnitID,value in pairs(GG.carrierMetaList[unitID].subUnitsList) do
			if GG.carrierMetaList[unitID].subUnitsList[subUnitID] then
				local standalone = false
				if GG.carrierMetaList[unitID].carrierDeaththroe == "death" then
					Spring.DestroyUnit(subUnitID, true)
				
				elseif GG.carrierMetaList[unitID].carrierDeaththroe == "capture" then
					standalone = true
					local enemyunitID = Spring.GetUnitNearestEnemy(subUnitID, GG.carrierMetaList[unitID].controlRadius)
					if enemyunitID then
						Spring.TransferUnit(subUnitID, Spring.GetUnitTeam(enemyunitID), false)
					end
				elseif GG.carrierMetaList[unitID].carrierDeaththroe == "control" then
					standalone = true
				elseif GG.carrierMetaList[unitID].carrierDeaththroe == "parasite" then
					local newCarrier
					local ox, oy, oz = spGetUnitPosition(subUnitID)
					local newCarrierCandidates = Spring.GetUnitsInCylinder(ox, oz, GG.carrierMetaList[unitID].controlRadius)
					for _, newCarrierCandidate in pairs(newCarrierCandidates) do
						local existingCarrier = Spring.GetUnitRulesParam(newCarrierCandidate, "carrier_host_unit_id")
						if not existingCarrier then
							if GG.carrierMetaList[unitID].parasite == "ally" then
								if Spring.GetUnitAllyTeam(newCarrierCandidate) then
									newCarrier = newCarrierCandidate
								end
							elseif GG.carrierMetaList[unitID].parasite == "enemy" then
								if not Spring.GetUnitAllyTeam(newCarrierCandidate) then
									newCarrier = newCarrierCandidate
								end
								
							elseif GG.carrierMetaList[unitID].parasite == "all" then
								newCarrier = newCarrierCandidate
							end
						end

					end
					

					if newCarrier then
						if GG.carrierMetaList[newCarrier] then
							standalone = true
						else
							GG.carrierMetaList[newCarrier] = GG.carrierMetaList[unitID]
							
							GG.carrierMetaList[newCarrier].subUnitsList[subUnitID] = GG.carrierMetaList[unitID].subUnitsList[subUnitID] -- list of subUnitIDs owned by this unit.
							GG.carrierMetaList[newCarrier].subUnitCount = 1
							GG.carrierMetaList[newCarrier].spawnRateFrames = 0
								
							GG.carrierMetaList[newCarrier].docking = false
								
							GG.carrierMetaList[newCarrier].activeRecall = false
							
							spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", newCarrier, PRIVATE)
						end
					
					else
						standalone = true
					end

				end

				if standalone then
					SetUnitNoSelect(subUnitID, false)
					spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", nil, PRIVATE)
					GG.droneMetaList[subUnitID] = {
						active = true,
						docked = false, --
						stayDocked = false,
						activeDocking = false,
						engaged = false,
						decayRate = GG.carrierMetaList[unitID].decayRate,
					}
				end
				
			end
		end
		GG.carrierMetaList[unitID] = nil
	end

end


local function UpdateStandaloneDrones(frame)
	local resourceFrames = (frame - previousHealFrame) / 30
	for unitID,value in pairs(GG.droneMetaList) do
		if GG.droneMetaList[unitID].decayRate > 0 then
			local h, mh = Spring.GetUnitHealth(unitID)
			HealUnit(unitID, -GG.droneMetaList[unitID].decayRate, resourceFrames, h, mh)
		end
	end
end

local function UpdateCarrier(carrierID, carrierMetaList, frame)
	local cmdID, _, _, cmdParam_1, cmdParam_2, cmdParam_3 = Spring.GetUnitCurrentCommand(carrierID)
	local droneSendDistance = nil
	local ox, oy, oz
	local px, py, pz
	local target
	local recallDrones = carrierMetaList.activeRecall
	local attackOrder = false
	local fightOrder = false
	local setTargetOrder = false
	local carrierStates = spGetUnitStates(carrierID)
	local newOrder = true

	
	local activeSpawning = true
	local idleRadius = carrierMetaList.radius
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
	
	if buildProgress < 1 then
		activeSpawning = false
	end
	
	GG.carrierMetaList[carrierID].activeSpawning = activeSpawning
	
	local minEngagementRadius = carrierMetaList.minRadius
	if carrierMetaList.subUnitsCommand.cmdID then
		local prevcmdID = cmdID
		local prevcmdParam_1 = cmdParam_1
		local prevcmdParam_2 = cmdParam_2
		local prevcmdParam_3 = cmdParam_3
		
		cmdID = carrierMetaList.subUnitsCommand.cmdID
		cmdParam_1 = carrierMetaList.subUnitsCommand.cmdParams[1]
		cmdParam_2 = carrierMetaList.subUnitsCommand.cmdParams[2]
		cmdParam_3 = carrierMetaList.subUnitsCommand.cmdParams[3]

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
			droneSendDistance = GetDistance(ox, px, oz, pz)
		end
		attackOrder = true --attack order overrides set target
	end
	
	
	--Handles a fight order given to the carrier.
	if not recallDrones and cmdID == CMD.FIGHT then
		ox, oy, oz = spGetUnitPosition(carrierID)
		px, py, pz = cmdParam_1, cmdParam_2, cmdParam_3
		target = {cmdParam_1, cmdParam_2, cmdParam_3}
		if px then
			droneSendDistance = GetDistance(ox, px, oz, pz)
		end
		fightOrder = true 
	end
	
	--Handles a setTarget order given to the carrier.
	if not recallDrones and not attackOrder then
		local targetType,_,setTarget = Spring.GetUnitWeaponTarget(carrierID, 1)
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
				droneSendDistance = GetDistance(ox, px, oz, pz)
			end
			setTargetOrder = true
		end
	end

	local rx, rz
	local resourceFrames = (frame - previousHealFrame) / 30
	for subUnitID,value in pairs(carrierMetaList.subUnitsList) do
		ox, oy, oz = spGetUnitPosition(carrierID)
		local sx, sy, sz = spGetUnitPosition(subUnitID)
		local droneDistance = GetDistance(ox, sx, oz, sz)

		--local stayDocked = false
		local h, mh = Spring.GetUnitHealth(subUnitID)

		if h then
			if carrierMetaList.dockedHealRate > 0 and carrierMetaList.subUnitsList[subUnitID].docked then
				if h == mh then
					-- fully healed
					if heallist[subUnitID] then
						heallist[subUnitID] = nil
						healcount = healcount -1
					end
					carrierMetaList.subUnitsList[subUnitID].stayDocked = false
				else
					if not heallist[subUnitID] then
						healcount = healcount +1
						heallist[subUnitID] = true
					end	
					-- still needs healing
					carrierMetaList.subUnitsList[subUnitID].stayDocked = true
					HealUnit(subUnitID, carrierMetaList.dockedHealRate, resourceFrames, h, mh)
				end
			else
				HealUnit(subUnitID, -carrierMetaList.decayRate, resourceFrames, h, mh)
			end
			if 100*h/mh < carrierMetaList.dockToHealThreshold then
				DockUnitQueue(carrierID, subUnitID)
			end
		end

		if GG.carrierMetaList[carrierID] then
			if GG.carrierMetaList[carrierID].subUnitsList[subUnitID] and droneDistance then
				if attackOrder or setTargetOrder or fightOrder then
					-- drones fire at will if carrier has an attack/target order
					-- a drone bomber probably should not do this
					spGiveOrderToUnit(subUnitID, CMD.FIRE_STATE, 2, 0)
				end
				if recallDrones or (droneDistance > carrierMetaList.controlRadius) then
					-- move drones to carrier
					px, py, pz = spGetUnitPosition(carrierID)
					rx, rz = RandomPointInUnitCircle()
					carrierMetaList.subUnitsCommand.cmdID = nil
					carrierMetaList.subUnitsCommand.cmdParams = nil
					if idleRadius == 0 then
						DockUnitQueue(carrierID, subUnitID)
					else
						spGiveOrderToUnit(subUnitID, CMD.MOVE, {px + rx*idleRadius, py, pz + rz*idleRadius}, 0)
						spGiveOrderToUnit(subUnitID, CMD.GUARD, carrierID, CMD.OPT_SHIFT)
					end
				elseif droneSendDistance and droneSendDistance < carrierMetaList.radius then
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
							rx, rz = RandomPointInUnitCircle()
							spGiveOrderToUnit(subUnitID, CMD.MOVE, {px + rx*idleRadius, py, pz + rz*idleRadius}, 0)
						end
					end
				elseif not carrierMetaList.subUnitsList[subUnitID].keepDocked then
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
					carrierMetaList.subUnitsList[subUnitID].engaged = engaged
					if not engaged and ((frame % DEFAULT_UPDATE_ORDER_FREQUENCY) == 0) then
						if idleRadius == 0 then
							DockUnitQueue(carrierID, subUnitID)
						else
							px, py, pz = spGetUnitPosition(carrierID)
							rx, rz = RandomPointInUnitCircle()
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




function gadget:GameFrame(f)
	if f % GAME_SPEED ~= 0 then
		return
	end



	if ((f % DEFAULT_SPAWN_CHECK_FREQUENCY) == 0) then
		for unitID, _ in pairs(GG.carrierMetaList) do
			if GG.carrierMetaList[unitID].spawnRateFrames == 0 then
			elseif ((f % GG.carrierMetaList[unitID].spawnRateFrames) == 0 and GG.carrierMetaList[unitID].activeSpawning) then
				local spawnData = GG.carrierMetaList[unitID].subInitialSpawnData
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
		for unitID, _ in pairs(GG.carrierMetaList) do
			UpdateCarrier(unitID, GG.carrierMetaList[unitID], f)
		end
		UpdateStandaloneDrones(f)
		previousHealFrame = f
	end
end







