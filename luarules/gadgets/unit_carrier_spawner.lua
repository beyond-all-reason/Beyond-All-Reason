
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

function gadget:GetInfo()
	return {
		name = "Unit Carrier Spawner",
		desc = "Spawns and controls units",
		author = "Xehrath, Inspiration taken from zeroK carrier authors: TheFatConroller, KingRaptor",
		date = "2007-11-18",
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

-- using a bunch of ([index] = number) tables instead of one ([index] = {number, number}) to reduce subtable allocations
local expireList = {} -- [index] = frame
local expireID = {} -- [index] = unitID
local expireByID = {} -- [unitID] = index
local expireCount = 0

local spawnList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}, subtables reused
local spawnCount = 0


local dockingList = {} -- [index] = {.spawnDef, .teamID, .x, .y, .z, .ownerID}, subtables reused
local dockingCount = 0
local dockingAvailable = true
local previousHealFrame = 0


local carrierMetaList = {}

local unitNewScript = {}

local DEFAULT_UPDATE_ORDER_FREQUENCY = 10 -- gameframes
local CARRIER_UPDATE_FREQUENCY = 10 -- gameframes
local DEFAULT_SPAWN_CHECK_FREQUENCY = 30 -- gameframes
local previousOrderUpdateFrame = 0


local coroutine = coroutine
local Sleep     = coroutine.yield
local assert    = assert

local coroutines = {}


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
	
	-- },							 

	-- Notes:
	--todo:
	-- multiple unit types
	-- test cost inheritance
	-- test all command states
	-- rearming stockpiles mechanic similarl to the healing behaviour





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
			expire = wdcp.spawns_expire and (tonumber(wdcp.spawns_expire) * GAME_SPEED),
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
			dockToHealThreshold = wdcp.docktohealthreshold,
		}
		if wdcp.spawn_blocked_by_shield then
			shieldCollide[weaponDefID] = WeaponDefs[weaponDefID].damages[Game.armorTypes.shield]
		end
		wantedList[#wantedList + 1] = weaponDefID
	end
end


local function GetDistance(x1, x2, y1, y2)
	return ((x1-x2)^2 + (y1-y2)^2)^0.5
end

local function GetDirectionalVector(speed, x1, x2, y1, y2, z1, z2)
	local magnitude
	local vx, vy, vz
	if z1 then
		vx, vy, vz = x2-x1, y2-y1, z2-z1
		magnitude = ((vx)^2 + (vy)^2 + (vz)^2)^0.5
		return speed*vx/magnitude, speed*vy/magnitude, speed*vz/magnitude
	else
		vx, vy = x2-x1, y2-y1
		magnitude = ((vx)^2 + (vy)^2)^0.5
		return speed*vx/magnitude, speed*vy/magnitude
	end
end

local function RandomPointInUnitCircle()
	local angle = random(0, 2*math.pi)
	local distance = math.pow(random(0, 1), 0.5)
	return math.cos(angle)*distance, math.sin(angle)*distance
end


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
	if resourceFrames <= 0 then
		return
	end
	local healthGain = healrate*resourceFrames
	local newHealth = math_min(h + healthGain, mh)
	if mh < newHealth then
		newHealth = mh
	end
	Spring.SetUnitHealth(unitID, newHealth)
end



local function DockUnitQueue(unitID, subUnitID) -- adds unit to docking queue
	if carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking then
		return
	end
	dockingCount = dockingCount + 1
	local dockData = dockingList[dockingCount] or {}
	dockData.ownerID = unitID
	dockData.subunitID = subUnitID
	dockingList[dockingCount] = dockData
	carrierMetaList[unitID].subUnitsList[subUnitID].activeDocking = true
end


local function DockUnits(dockingqueue, queuecount)
	for i = 1, queuecount do
		local unitID = dockingqueue[i].ownerID
		local subUnitID = dockingqueue[i].subunitID
		local subunitDefID	= spGetUnitDefID(subUnitID)
		local subunitDef = UnitDefs[subunitDefID]
		local unitblockingstate = Spring.GetUnitBlocking(subUnitID)
		local ox, oy, oz = spGetUnitPosition(unitID)
		local subx, suby, subz = spGetUnitPosition(subUnitID)
		local dockingSnapRange
		
		local pieceNumber = carrierMetaList[unitID].dockingPiece
		carrierMetaList[unitID].dockingPiece = carrierMetaList[unitID].dockingPiece + carrierMetaList[unitID].dockingInterval
		if carrierMetaList[unitID].dockingPiece > carrierMetaList[unitID].dockingCap then
			carrierMetaList[unitID].dockingPiece = carrierMetaList[unitID].dockingOffset
		end
		if carrierMetaList[unitID].dockingPiece then
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
					local distance = GetDistance(px, subx, pz, subz)
					local heightDifference = GetDistance(py, suby, 0, 0)
					

					
					
					if distance < 25 and subunitDef.isAirUnit then
						local landingspeed = carrierMetaList[unitID].dockHelperSpeed
						if 0.2*heightDifference > landingspeed then
							landingspeed = 0.2*heightDifference
						end
						local vx, vy, vz = GetDirectionalVector(landingspeed, subx, px, suby, py, subz, pz)
						spSetUnitVelocity(subUnitID, vx, vy, vz)

					elseif distance < carrierMetaList[unitID].dockRadius then
						local vx, vy, vz = GetDirectionalVector(carrierMetaList[unitID].dockHelperSpeed, subx, px, suby, py, subz, pz)
						Spring.MoveCtrl.Enable(subUnitID)
						mcSetPosition(subUnitID, subx+vx, suby, subz+vz)
						Spring.MoveCtrl.Disable(subUnitID)
						spSetUnitVelocity(subUnitID, vx, 0, vz)
						heightDifference = 0

					else
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
	spawnCount = 0
	dockingAvailable = true
	
end


local function UnDockUnit(unitID, subUnitID)
	if carrierMetaList[unitID].subUnitsList[subUnitID].docked == true and not carrierMetaList[unitID].subUnitsList[subUnitID].stayDocked then
		spUnitDetach(subUnitID)
		Spring.MoveCtrl.Disable(subUnitID)
		SetUnitNoSelect(subUnitID, true)
		carrierMetaList[unitID].subUnitsList[subUnitID].docked = false
		carrierMetaList[unitID].dockingPiece = carrierMetaList[unitID].dockingOffset
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
					carrierMetaList[ownerID].subUnitsList[subUnitID] = {
						active = true,
						docked = false,
						stayDocked = false,
						activeDocking = false,
						engaged = false,
						dockingPiece = carrierMetaList[ownerID].dockingPiece,
					}
				end


				Spring.MoveCtrl.Enable(subUnitID)
				Spring.MoveCtrl.SetPosition(subUnitID, spawnData.x, spawnData.y, spawnData.z)
				Spring.MoveCtrl.Disable(subUnitID)


				if carrierMetaList[ownerID].docking then
					DockUnitQueue(ownerID, subUnitID)
				else
					spGiveOrderToUnit(subUnitID, CMD.MOVE, {spawnData.x, spawnData.y, spawnData.z}, 0)
				end

				SetUnitNoSelect(subUnitID, true)


				if spawnDef.expire then
					expireCount = expireCount + 1
					expireByID[subUnitID] = expireCount
					expireID[expireCount] = subUnitID
					expireList[expireCount] = spGetGameFrame() + spawnDef.expire
				end
				
			end

		end
		


	
	end
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
				carrierMetaList[unitID] = {
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
					maxunits = tonumber(spawnDef.maxunits) or 1,
					metalCost = tonumber(spawnDef.metalPerUnit),
					energyCost = tonumber(spawnDef.energyPerUnit),
					docking = tonumber(spawnDef.docking),
					dockingOffset = tonumber(spawnDef.offset) or 1,
					dockingInterval = tonumber(spawnDef.interval) or 0,
					dockingCap = tonumber(spawnDef.dockingcap) or 1,
					dockingPiece = tonumber(spawnDef.offset) or 1,
					dockRadius = tonumber(spawnDef.dockingRadius) or 100,
					dockHelperSpeed = tonumber(spawnDef.dockingHelperSpeed) or 10,
					dockArmor = tonumber(spawnDef.dockingArmor),
					dockedHealRate = tonumber(spawnDef.dockingHealrate) or 0,
					dockToHealThreshold = tonumber(spawnDef.dockToHealThreshold) or 30,
					activeDocking = false, --currently not in use
				}
			end
			
		end
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)



	if carrierMetaList[unitID] and (cmdID == CMD.STOP) then
		for subUnitID,value in pairs(carrierMetaList[unitID].subUnitsList) do
			if unitID == Spring.GetUnitRulesParam(subUnitID, "carrier_host_unit_id") then
				DockUnitQueue(unitID, subUnitID)
				carrierMetaList[unitID].subUnitsCommand.cmdID = nil
				carrierMetaList[unitID].subUnitsCommand.cmdParams = nil
			end
		end
	elseif carrierMetaList[unitID] and cmdID ~= CMD.MOVE then
		carrierMetaList[unitID].subUnitsCommand.cmdID = cmdID
		carrierMetaList[unitID].subUnitsCommand.cmdParams = cmdParams
		for subUnitID,value in pairs(carrierMetaList[unitID].subUnitsList) do
			if unitID == Spring.GetUnitRulesParam(subUnitID, "carrier_host_unit_id") then
				--spGiveOrderToUnit(subUnitID, cmdID, cmdParams, cmdOptions)
			end
			
		end
	end
end

function gadget:UnitDestroyed(unitID)
	local carrierUnitID = Spring.GetUnitRulesParam(unitID, "carrier_host_unit_id")
	if carrierUnitID then
		if carrierMetaList[carrierUnitID].subUnitsList[unitID] then
			carrierMetaList[carrierUnitID].subUnitsList[unitID] = nil
			carrierMetaList[carrierUnitID].subUnitCount = carrierMetaList[carrierUnitID].subUnitCount - 1
		end
	end


	if carrierMetaList[unitID] then
		for subUnitID,value in pairs(carrierMetaList[unitID].subUnitsList) do
			if carrierMetaList[unitID].subUnitsList[subUnitID] then
				Spring.DestroyUnit(subUnitID, true)
			end
		end
		carrierMetaList[unitID] = nil
	end

	local index = expireByID[unitID]
	if not index then
		return
	end

	local lastUnitID = expireID[expireCount]

	expireList[index] = expireList[expireCount]
	expireID[index] = lastUnitID
	expireByID[lastUnitID] = index
	expireByID[unitID] = nil
	expireCount = expireCount - 1

	-- last element not nil'd on purpose
	-- no point wasting time doing that as the array won't shrink anyway
end

local function UpdateCarrier(carrierID, frame)
	local cmdID, _, _, cmdParam_1, cmdParam_2, cmdParam_3 = Spring.GetUnitCurrentCommand(carrierID)
	local droneSendDistance = nil
	local ox, oy, oz
	local px, py, pz
	local target
	local recallDrones = false  -- Can be connected to a spesific command to recall the drones similarly to when they are out of range. 
	local attackOrder = false
	local fightOrder = false
	local setTargetOrder = false
	local carrierStates = spGetUnitStates(carrierID)


	
	

	local idleRadius = carrierMetaList[carrierID].radius
	if carrierStates.firestate == 0 or carrierStates.movestate == 0 then
		idleRadius = 0
	elseif carrierStates.movestate == 1 then
		idleRadius = 200
	end

	local minEngagementRadius = carrierMetaList[carrierID].minRadius

	if carrierMetaList[carrierID].subUnitsCommand.cmdID then
		cmdID = carrierMetaList[carrierID].subUnitsCommand.cmdID
		cmdParam_1 = carrierMetaList[carrierID].subUnitsCommand.cmdParams[1]
		cmdParam_2 = carrierMetaList[carrierID].subUnitsCommand.cmdParams[2]
		cmdParam_3 = carrierMetaList[carrierID].subUnitsCommand.cmdParams[3]
	end

	
	if dockingCount > 0 and dockingAvailable then  -- Initiate docking for units in the docking queue and reset the queue.
		dockingAvailable = false
		DockUnits(dockingList, dockingCount)
		dockingCount = 0
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
	for subUnitID,value in pairs(carrierMetaList[carrierID].subUnitsList) do
		ox, oy, oz = spGetUnitPosition(carrierID)
		local sx, sy, sz = spGetUnitPosition(subUnitID)
		local droneDistance = GetDistance(ox, sx, oz, sz)

		local stayDocked = false
		local h, mh = Spring.GetUnitHealth(subUnitID)
		if carrierMetaList[carrierID].dockedHealRate > 0 and carrierMetaList[carrierID].subUnitsList[subUnitID].docked then
			if h and h == mh then
				-- fully healed
				carrierMetaList[carrierID].subUnitsList[subUnitID].stayDocked = false
			elseif h then
				-- still needs healing
				carrierMetaList[carrierID].subUnitsList[subUnitID].stayDocked = true
				HealUnit(subUnitID, carrierMetaList[carrierID].dockedHealRate, resourceFrames, h, mh)
			end
		end
		
		if 100*h/mh < carrierMetaList[carrierID].dockToHealThreshold then
			DockUnitQueue(carrierID, subUnitID)
		end

		if attackOrder or setTargetOrder or fightOrder then
			-- drones fire at will if carrier has an attack/target order
			-- a drone bomber probably should not do this
			spGiveOrderToUnit(subUnitID, CMD.FIRE_STATE, 2, 0)
		end


		if recallDrones or (droneDistance > carrierMetaList[carrierID].controlRadius) then
			-- move drones to carrier
			px, py, pz = spGetUnitPosition(carrierID)
			rx, rz = RandomPointInUnitCircle()
			carrierMetaList[carrierID].subUnitsCommand.cmdID = nil
			carrierMetaList[carrierID].subUnitsCommand.cmdParams = nil
			if idleRadius == 0 then
				DockUnitQueue(carrierID, subUnitID)
			else
				spGiveOrderToUnit(subUnitID, CMD.MOVE, {px + rx*idleRadius, py, pz + rz*idleRadius}, 0)
				spGiveOrderToUnit(subUnitID, CMD.GUARD, carrierID, CMD.OPT_SHIFT)
			end
		elseif droneSendDistance and droneSendDistance < carrierMetaList[carrierID].radius then
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
		elseif not carrierMetaList[carrierID].subUnitsList[subUnitID].keepDocked then
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
			carrierMetaList[carrierID].subUnitsList[subUnitID].engaged = engaged
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
	previousHealFrame = frame


end

function gadget:GameFrame(f)
	UpdateCoroutines()
	if f % GAME_SPEED ~= 0 then
		return
	end

	local i = 1
	while i <= expireCount do -- not for-loop because Destroy decrements count
		if expireList[i] < f then
			spDestroyUnit(expireID[i], true)
		else
			i = i + 1 -- conditional because Destroy replaces current element with last
		end
	end

	if ((f % DEFAULT_SPAWN_CHECK_FREQUENCY) == 0) then
		for unitID, _ in pairs(carrierMetaList) do
			if ((f % carrierMetaList[unitID].spawnRateFrames) == 0) then

				local spawnData = carrierMetaList[unitID].subInitialSpawnData
				local x, y, z = spGetUnitPosition(unitID)
				spawnData.x = x
				spawnData.y = y
				spawnData.z = z

				SpawnUnit(spawnData)
			end
		end
	end

	if ((f % CARRIER_UPDATE_FREQUENCY) == 0) then
		for unitID, _ in pairs(carrierMetaList) do
			UpdateCarrier(unitID, f)
		end
	end
end







