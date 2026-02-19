
if not gadgetHandler:IsSyncedCode() then
	return false
end

local gadget = gadget ---@type Gadget

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
local GetUnitCommands     		= Spring.GetUnitCommands
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
local spGetGameSeconds 			= Spring.GetGameSeconds
local spGetUnitIsBeingBuilt		= Spring.GetUnitIsBeingBuilt
local spGetUnitsInCylinder		= Spring.GetUnitsInCylinder
local spGetUnitAllyTeam			= Spring.GetUnitAllyTeam
local spGetUnitStockpile		= Spring.GetUnitStockpile
local spSetUnitStockpile		= Spring.SetUnitStockpile
local spCallCOBScript			= Spring.CallCOBScript
local spSetUnitCOBValue			= Spring.SetUnitCOBValue
local spGetUnitPiecePosDir		= Spring.GetUnitPiecePosDir
local spGetUnitPiecePosition	= Spring.GetUnitPiecePosition


local mcEnable 				= Spring.MoveCtrl.Enable
local mcDisable 			= Spring.MoveCtrl.Disable
local mcSetPosition         = Spring.MoveCtrl.SetPosition
local mcSetRotation         = Spring.MoveCtrl.SetRotation
local mcSetAirMoveTypeData  = Spring.MoveCtrl.SetAirMoveTypeData

local mapsizeX 				  = Game.mapSizeX
local mapsizeZ 				  = Game.mapSizeZ

local random = math.random
local mathMin = math.min
local sin    = math.sin
local cos    = math.cos
local diag = math.diag
local stringFind = string.find
local strSplit = string.split
local tonumber = tonumber
local pairsNext = next
local PI = math.pi
local GAME_SPEED = Game.gameSpeed
local PRIVATE = { private = true }
local CMD_CARRIER_SPAWN_ONOFF = GameCMD.CARRIER_SPAWN_ONOFF

local noCreate = false

local spawnDefs = {}
local shieldCollide = {}
local wantedList = {}


local spawnCmd = {
	id = CMD_CARRIER_SPAWN_ONOFF,
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
local inUnitDestroyed = false

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
	-- carried_unit = "unitname"     Name of the unit spawned by this carrier unit. For multiple different drones: "unitname1 unitname2 unitname3..."


	--	-- Optional:
	-- controlradius = 200,			The spawned units are recalled when exceeding this range. Radius = 0 to disable control range limit.
	-- engagementrange = 100, 		The spawned units will adopt any active combat commands within this range. Best paired with a weapon of equal range.
	-- spawns_surface = "LAND",     "LAND" or "SEA". If not enabled, any surface will be accepted.
	-- buildcostenergy = 0,			Custom spawn cost. If not set, it will inherit the cost from the carried_unit unitDef. "0 0 0..."
	-- buildcostmetal = 0,			Custom spawn cost. If not set, it will inherit the cost from the carried_unit unitDef. "0 0 0..."
	-- enabledocking = true,		If enabled, docking behavior is used.
	-- dockingarmor = 0.4, 			Multiplier for damage taken while docked. Does not work against napalm (this might be fixed now?).

	--	-- Has a default value, as indicated, if not chosen:
	-- spawnrate = 1, 				Spawnrate roughly in seconds. Different spawn rates for multiple drones is not yet implemented.
	-- maxunits = 3,				Will spawn units until this amount has been reached. "3 3 2..."
	-- dockingpieces = "1 2 3",		Model pieces to be used for docking. "1 2 3,5 7 8,11 12..."
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
	-- droneminimumidleradius = 0,	Defines the wandering distance of drones from the carrier when it otherwise would have docked the drones, but docking is not enabled.



	-- -- Experimental. Please ping Xehrath in the BAR discord if you encounter any issues while using any of these options, or would like some changes to any of them. These are all subject to change or removal depending on interest, and are not considered finished features.
	-- dronetype = "default" 		Experimental types: nano, bomber, fighter, turret
	-- dockingsections = strSplit(dockingpieces, ","),
	-- dronebombingruns = 2,		Defines the number of bombing runs a bomber drone initiates before returning to the carrier..
	-- dronebombingoffset,			Used to make bomber drones go off to the side before heading directly towards the target. Multiple bomber drones will alternate which side to move to. Given as a percentage of the distance to the target.
	-- dronebomberinterval,			Used to stagger the launch of multiple bomber drones.
	-- dronebomberminengagementrange = 200, Bomber drones will not launch to attack targets within this radius.
	-- manualdrones					Allows manual control of drones within the control radius
	-- stockpilelimit = 1			Used for stockpile weapons, but for carriers it also enables stockpile for dronespawning.
	-- stockpilemetal = 10			Set it to the same as the drone cost when using stockpile for drones
	-- stockpileenergy = 10			Set it to the same as the drone cost when using stockpile for drones



	-- },



	-- Notes:
	--todo:
	-- multiple different drones on one carrier. Partially implemented, but the current implementation is merely a proof of concept. End goal is to have each drone type tied to separate weapons for targeting.
    -- Performance updates
    -- clarity updates. Removing clutter, removing deprecated code bits, restructuring, adding comments

	--Known bugs:
		-- Land carriers struggling with the attack formations
		-- Drones occationally stuck hovering near the carrier instead of following the active command

for weaponDefID = 1, #WeaponDefs do
	local wdcp = WeaponDefs[weaponDefID].customParams
	if wdcp.carried_unit then

			local dronetype = wdcp.dronetype or "default"
			local dockingpieces = wdcp.dockingpieces or "1"
			local maxunits = wdcp.maxunits or "1"
			local metalCost = wdcp.buildcostmetal or wdcp.metalcost or ""
			local energyCost = wdcp.buildcostenergy or wdcp.energycost or ""
		spawnDefs[weaponDefID] = {
			name = strSplit(wdcp.carried_unit),
			dronetype = strSplit(dronetype),
			feature = wdcp.spawns_feature,
			surface = wdcp.spawns_surface,
			spawnRate = wdcp.spawnrate,
			maxunits = strSplit(maxunits),
			metalPerUnit = strSplit(metalCost),
			energyPerUnit = strSplit(energyCost),
			radius = wdcp.controlradius,
			minRadius = wdcp.engagementrange,
			docking = wdcp.enabledocking,
			dockingsections = strSplit(dockingpieces, ","),
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
			holdfireRadius = wdcp.holdfireradius,
			droneminimumidleradius = wdcp.droneminimumidleradius,
			dronebombingruns = wdcp.dronebombingruns,
			dronebombingoffset = wdcp.dronebombingoffset,
			dronebomberinterval = wdcp.dronebomberinterval,
			dronebomberminengagementrange = wdcp.dronebomberminengagementrange,
			manualDrones = wdcp.manualdrones,
			stockpilelimit = wdcp.stockpilelimit,
			usestockpile = wdcp.dronesusestockpile,
			metalperstockpile = wdcp.stockpilemetal,
			energyperstockpile = wdcp.stockpileenergy,
			cobdockparam = wdcp.cobdockparam,
			cobundockparam = wdcp.cobundockparam,
			droneundocksequence = wdcp.droneundocksequence,

		}

		if wdcp.spawn_blocked_by_shield then
			shieldCollide[weaponDefID] = WeaponDefs[weaponDefID].damages[Game.armorTypes.shield]
		end
		wantedList[#wantedList + 1] = weaponDefID
	end
end




local function randomPointInUnitCircle(offset)
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



local function startScript(fn)
	local co = coroutine.create(fn)
	coroutines[#coroutines + 1] = co
end

local function updateCoroutines()
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


local function healUnit(unitID, healrate, resourceFrames, currentHealth, maxHealth)
	if (resourceFrames <= 0) or not currentHealth then
		return true
	end
	local healthGain = healrate*resourceFrames
	local newHealth = mathMin(currentHealth + healthGain, maxHealth)
	if maxHealth < newHealth then
		newHealth = maxHealth
	end
	if newHealth <= 0 then
		spDestroyUnit(unitID, true)
		return false	  
	else
		spSetUnitHealth(unitID, newHealth)
		return true	 
	end
end

local function validCarrierAndDrone(unitID, subUnitID)
	if not carrierMetaList[unitID] then
		return false
	elseif not carrierMetaList[unitID].subUnitsList[subUnitID] then
		return false
	else 
		return true
	end
end


local function dockUnitQueue(unitID, subUnitID)
	local validDrone = validCarrierAndDrone(unitID, subUnitID)
	if not validDrone then
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



local function undockUnit(unitID, subUnitID)
	local validDrone = validCarrierAndDrone(unitID, subUnitID)
	if not validDrone then
		return
	else
		local droneMetaData = carrierMetaList[unitID].subUnitsList[subUnitID]
		local dronetype = droneMetaData.dronetype
		if droneMetaData.docked == true and not droneMetaData.stayDocked and not droneMetaData.activeSpawnSequence and dronetype ~= "infantry" then
			spSetUnitCOBValue(subUnitID, COB.ACTIVATION, 1)
			spUnitDetach(subUnitID)
			mcDisable(subUnitID)
			if not carrierMetaList[unitID].manualDrones then
				SetUnitNoSelect(subUnitID, true)
			end
			droneMetaData.docked = false
			carrierMetaList[unitID].activeDocking = false
			droneMetaData.activeDocking = false
			droneMetaData.activeUndockSequence = false
			
			spCallCOBScript(subUnitID, "Undocked", 0, carrierMetaList[unitID].cobundockparam, droneMetaData.dockingPiece)
			if carrierMetaList[unitID].dockArmor then
				spSetUnitArmored(subUnitID, false, 1)
			end
			
			if dronetype == "printer" then
				SetUnitNoSelect(subUnitID, false)
				spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", nil, PRIVATE)
				RemoveDrone(unitID,subUnitID)
			end
		end
	end
end


local function undockSequence(unitID, subUnitID)
	local validDrone = validCarrierAndDrone(unitID, subUnitID)
	if not validDrone then
		return
	else
		local droneMetaData = carrierMetaList[unitID].subUnitsList[subUnitID]
		if droneMetaData.docked == true and not droneMetaData.stayDocked then
			if droneMetaData.activeUndockSequence == true then
				return
			elseif carrierMetaList[unitID].droneundocksequence then
				spCallCOBScript(unitID, "CarrierDroneUndockSequence", 0, subUnitID, droneMetaData.dockingPiece)
				spCallCOBScript(subUnitID, "DroneUndockSequence", 0, carrierMetaList[unitID].cobundockparam, droneMetaData.dockingPiece)
				droneMetaData.activeUndockSequence = true
			else
				undockUnit(unitID, subUnitID)
			end
		end
	end
end


local function CobUndockSequenceFinished(unitID, unitDefID, team, subUnitID)
	local validDrone = validCarrierAndDrone(unitID, subUnitID)
	if not validDrone then
		return
	else
		undockUnit(unitID, subUnitID)
		return
	end
end


local function droneSpawnSequence(unitID, subUnitID)
	local validDrone = validCarrierAndDrone(unitID, subUnitID)
	if not validDrone then
		return
	else
		local droneMetaData = carrierMetaList[unitID].subUnitsList[subUnitID]
		if droneMetaData.docked == true and not droneMetaData.stayDocked then
			if droneMetaData.activeUndockSequence == true then
				return
			elseif carrierMetaList[unitID].droneundocksequence then
				spCallCOBScript(unitID, "CarrierDroneSpawnSequence", 0, subUnitID, droneMetaData.dockingPiece)
				spCallCOBScript(subUnitID, "droneSpawnSequence", 0, carrierMetaList[unitID].cobundockparam, droneMetaData.dockingPiece)
				droneMetaData.activeUndockSequence = true
			else
				undockUnit(unitID, subUnitID)
			end
		end
	end
end


local function CobDroneSpawnSequenceFinished(unitID, unitDefID, team, subUnitID)
	local validDrone = validCarrierAndDrone(unitID, subUnitID)
	if not validDrone then
		return
	else
		local dockingPiece = carrierMetaList[unitID].subUnitsList[subUnitID].dockingPiece
		local _, pieceAngle  = spCallCOBScript(unitID, "DroneDocked", 5, pieceAngle, dockingPiece)
		spCallCOBScript(subUnitID, "Docked", 0, carrierMetaList[unitID].cobdockparam, dockingPiece, pieceAngle)
		return
	end
end



local function spawnUnit(spawnData)
	if spawnData then				 
		local validSurface = false
		if not spawnData.surface then
			validSurface = true
		elseif spawnData.x > 0 and spawnData.x < mapsizeX and spawnData.z > 0 and spawnData.z < mapsizeZ then
			local y = spGetGroundHeight(spawnData.x, spawnData.z)
			if stringFind(spawnData.surface, "LAND", 1, true) and y > 0 then
				validSurface = true
			elseif stringFind(spawnData.surface, "SEA", 1, true) and y <= 0 then
				validSurface = true
			end
		end


		local subUnitID = nil
		local ownerID = spawnData.ownerID
		local carrierData = carrierMetaList[spawnData.ownerID]
		if validSurface == true and ownerID then

			local stockpilecount = spGetUnitStockpile(spawnData.ownerID) or 0
			local stockpilechange = stockpilecount - carrierMetaList[spawnData.ownerID].stockpilecount
			local stockpiledMetal = 0
			local stockpiledEnergy = 0

			if stockpilechange > 0 then
				carrierData.stockpilecount = stockpilecount
				stockpiledMetal = carrierData.metalperstockpile * stockpilechange --TODO: Make this the actual set stockpile values
				stockpiledEnergy = carrierData.energyperstockpile * stockpilechange -- TODO: Make this the actual set stockpile values
			end

			for dronetypeIndex, dronename in pairsNext, carrierData.dronenames do
				local carriedDroneType = carrierData.dronetypes[dronetypeIndex]
				if not(carrierData.usestockpile) or carrierData.subUnitCount[dronetypeIndex] < stockpilecount then
					if carrierData.printerUnitDefID and carriedDroneType == "printer" then
						dronename = carrierData.printerUnitDefID
					end
					
					if dronename == "none" then
					elseif carrierData.subUnitCount[dronetypeIndex] < carrierData.maxunits[dronetypeIndex] then
						local metalCost
						local energyCost
						if carrierData.metalCost[dronetypeIndex] and carrierData.energyCost[dronetypeIndex] then
							metalCost = carrierData.metalCost[dronetypeIndex]
							energyCost = carrierData.energyCost[dronetypeIndex]

						else
							local subUnitDef = UnitDefNames[dronename]
							if subunitDef then
								metalCost = subUnitDef.metalCost
								energyCost = subUnitDef.energyCost
							else
								metalCost = 0
								energyCost = 0
							end
						end
						---
						if carrierData.usestockpile and stockpilecount > 0 then
							if stockpiledMetal >= metalCost and stockpiledEnergy >= energyCost then
								subUnitID = spCreateUnit(dronename, spawnData.x, spawnData.y, spawnData.z, 0, spawnData.teamID)
								stockpiledMetal = stockpiledMetal - metalCost
								stockpiledEnergy = stockpiledEnergy - energyCost
							end
						else
							local availableMetal = spGetTeamResources(spawnData.teamID, "metal")
							local availableEnergy = spGetTeamResources(spawnData.teamID, "energy")
							if availableMetal > metalCost and availableEnergy > energyCost then
								spUseTeamResource(spawnData.teamID, "metal", metalCost)
								spUseTeamResource(spawnData.teamID, "energy", energyCost)
								subUnitID = spCreateUnit(dronename, spawnData.x, spawnData.y, spawnData.z, 0, spawnData.teamID)
							end
						end


						------

						if not subUnitID then
							-- unit limit hit or invalid spawn surface
							return
						end


						local spareDock = false
						local dockingpiece
						if ownerID then
							spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", ownerID, PRIVATE)
							local subUnitCount = carrierData.subUnitCount[dronetypeIndex]
							local subunitDefID	= spGetUnitDefID(subUnitID)
							subUnitCount = subUnitCount + 1
							carrierData.subUnitCount[dronetypeIndex] = subUnitCount
							local dockingpieceindex
							for pieceIndex, piece in pairsNext, carrierData.availableSections[dronetypeIndex].availablePieces do
								if piece.dockingPieceAvailable then
									spareDock = true
									dockingpiece = piece.dockingPiece
									dockingpieceindex = pieceIndex
									carrierData.availableSections[dronetypeIndex].availablePieces[pieceIndex].dockingPieceAvailable = false
									break
								end
							end
							
							local droneData = {
								dronetype =  carriedDroneType,
								dronetypeIndex = dronetypeIndex,
								active = true,
								docked = false, --
								stayDocked = false,
								activeDocking = false,
								activeUndockSequence = false,
								activeSpawnSequence = false,
								inFormation = false,
								engaged = false,
								bomberStage = 0,
								lastBombing = 0,
								originalmaxrudder = UnitDefs[subunitDefID].maxRudder,
								fighterStage = 0,
								dockingPiece = dockingpiece,
								dockingPieceIndex = dockingpieceindex,
							}
							carrierData.subUnitsList[subUnitID] = droneData
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
							dockPointx,dockPointy, dockPointz = spGetUnitPiecePosition(ownerID, dockingpiece)--Spring.GetUnitPieceInfo (ownerID, dockingpieceindex)
							carrierx,carriery, carrierz = spGetUnitPosition(ownerID)
							mcSetPosition(subUnitID, carrierx+dockPointx, carriery+dockPointy, carrierz+dockPointz)
						end
						mcDisable(subUnitID)

						local droneMetaData = carrierData.subUnitsList[subUnitID]
						if carrierData.docking and droneMetaData.dockingPiece then
							spUnitAttach(ownerID, subUnitID, droneMetaData.dockingPiece)
							spGiveOrderToUnit(subUnitID, CMD.STOP, {}, 0)
							spGiveOrderToUnit(subUnitID, CMD.FIRE_STATE, 0, 0)
							mcDisable(subUnitID)
							spSetUnitVelocity(subUnitID, 0, 0, 0)
							if not carrierData.manualDrones then
								SetUnitNoSelect(subUnitID, true)
							end

							droneMetaData.docked = true
							droneMetaData.activeDocking = false
							if carrierData.dockArmor then
								spSetUnitArmored(subUnitID, true, carrierMetaList[ownerID].dockArmor)
							end
							Spring.SetUnitCOBValue(subUnitID, COB.ACTIVATION, 0)
							if carrierData.activeSpawnSequence then
								droneSpawnSequence(ownerID, subUnitID)
								droneMetaData.activeSpawnSequence = true
							else
								local _, pieceAngle = spCallCOBScript(ownerID, "DroneDocked", 5, pieceAngle, droneMetaData.dockingPiece)
								spCallCOBScript(subUnitID, "Docked", 0, carrierData.cobdockparam, droneMetaData.dockingPiece, pieceAngle)
							end
						else
							spGiveOrderToUnit(subUnitID, CMD.MOVE, {spawnData.x, spawnData.y, spawnData.z}, 0)
						end

						if not carrierData.manualDrones then
							SetUnitNoSelect(subUnitID, true)
						end
					elseif carriedDroneType == "printer" and carrierData.docking then
						for subUnitID,value in pairsNext, carrierData.subUnitsList do 
							if carrierData.subUnitsList[subUnitID] and carrierData.subUnitsList[subUnitID].dronetype == "printer" then
								undockSequence(ownerID, subUnitID)
							end
						end
					end
				end				
			end
		end
	end
end

local function attachToNewCarrier(newCarrier, subUnitID)

	if carrierMetaList[newCarrier] then
		spSetUnitRulesParam(subUnitID, "carrier_host_unit_id", newCarrier, PRIVATE)
		local subUnitCount = carrierMetaList[newCarrier].subUnitCount
		subUnitCount = subUnitCount + 1
		carrierMetaList[newCarrier].subUnitCount = subUnitCount
		local dockingpiece
		local dockingpieceindex
		if carrierMetaList[newCarrier].docking then
			for i = 1, #carrierMetaList[newCarrier].availablePieces do
				if carrierMetaList[newCarrier].availablePieces[i].dockingPieceAvailable then
					dockingpiece = carrierMetaList[newCarrier].availablePieces[i].dockingPiece
					dockingpieceindex = i
					carrierMetaList[newCarrier].availablePieces[i].dockingPieceAvailable = false
					break
				end
			end
		else
			dockingpiece = 1
			dockingpieceindex = 1
		end
		local droneData = {
			active = true,
			docked = false, 
			stayDocked = false,
			activeDocking = false,
			inFormation = false,
			engaged = false,
			dockingPiece = dockingpiece, 
			dockingPieceIndex = dockingpieceindex,
		}
		carrierMetaList[newCarrier].subUnitsList[subUnitID] = droneData
		totalDroneCount = totalDroneCount + 1
	else
		local oldCarrierID = Spring.GetUnitRulesParam(subUnitID, "carrier_host_unit_id")
		if oldCarrierID and carrierMetaList[oldCarrierID] then
			carrierMetaList[newCarrier] = carrierMetaList[oldCarrierID]
			carrierMetaList[newCarrier].docking = nil
			carrierMetaList[newCarrier].subInitialSpawnData.ownerID = newCarrier
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
			if spawnDef.radius then
							   
				local spawnData = {}								 
				local x, y, z = spGetUnitPosition(unitID)
				spawnData.x = x
				spawnData.y = y
				spawnData.z = z
				spawnData.ownerID = unitID
				spawnData.teamID = unitTeam
				spawnData.surface = spawnDef.surface


				if carrierMetaList[unitID] == nil then
					local dronenames = spawnDef.name
					local dronetypes = spawnDef.dronetype
					local dockingsections = spawnDef.dockingsections
					local maxunits = spawnDef.maxunits
					local metalCost = spawnDef.metalPerUnit
					local energyCost = spawnDef.energyPerUnit

					local availableSections = {}

					for sectionIndex, dockingpieces in pairs(dockingsections) do
						local availableSectionsData = {
							availablePieces = {}
						}
						local availablePieces = {}
						local piecenumbers = strSplit(dockingpieces)
						for pieceindex, piecenumber in pairs(piecenumbers) do
							availablePieces[pieceindex] = {
								dockingPieceAvailable = true,
								dockingPieceIndex = pieceindex,
								dockingPiece = tonumber(piecenumber),
							}
						end
						availableSectionsData.availablePieces = availablePieces
						availableSections[sectionIndex] = availableSectionsData

					end

					local carrierData = {
						dronenames = dronenames,
						dronetypes = dronetypes,
						radius = tonumber(spawnDef.minRadius) or 65535,
						controlRadius = tonumber(spawnDef.radius) or 65535,
						subUnitsList = {}, -- list of subUnitIDs owned by this unit.
						subUnitCount = {},
						subInitialSpawnData = spawnData,
						spawnRateFrames = tonumber(spawnDef.spawnRate) * 30 or 30,
						lastSpawn = 0,
						lastOrderUpdate = 0,
						maxunits = {},
						metalCost = {},
						energyCost = {},
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
						availableSections = availableSections,
						carrierDeaththroe =spawnDef.carrierdeaththroe or "death",
						parasite = "all",
						holdfireRadius = spawnDef.holdfireRadius or 0,
						droneminimumidleradius = spawnDef.droneminimumidleradius or 0,
						dronebombingruns = tonumber(spawnDef.dronebombingruns) or 1,
						dronebombingoffset = tonumber(spawnDef.dronebombingoffset) or 0.5,
						dronebombingside = 1,
						dronebomberinterval = tonumber(spawnDef.dronebomberinterval) or 2,
						dronebombertimer = 0,
						dronebomberminengagementrange = tonumber(spawnDef.dronebomberminengagementrange) or 200,
						manualDrones = tonumber(spawnDef.manualDrones),
						weaponNr = i,
						stockpilelimit = tonumber(spawnDef.stockpilelimit) or 0,
						usestockpile = tonumber(spawnDef.usestockpile),
						stockpilecount = 0,
						metalperstockpile = tonumber(spawnDef.metalperstockpile) or 0,
						energyperstockpile = tonumber(spawnDef.energyperstockpile) or 0,
						cobdockparam = tonumber(spawnDef.cobdockparam) or 0,
						cobundockparam = tonumber(spawnDef.cobundockparam) or 0,
						droneundocksequence = tonumber(spawnDef.droneundocksequence),
						printerUnitDefID = nil,
					}
					for dronetypeIndex, _ in pairs(carrierData.dronenames) do
						carrierData.subUnitCount[dronetypeIndex] = 0
						carrierData.maxunits[dronetypeIndex] = tonumber(maxunits[dronetypeIndex]) or 1
						carrierData.metalCost[dronetypeIndex] = tonumber(metalCost[dronetypeIndex])
						carrierData.energyCost[dronetypeIndex] = tonumber(energyCost[dronetypeIndex])
					end
					carrierMetaList[unitID] = carrierData
					--spSetUnitRulesParam(unitID, "is_carrier_unit", "enabled", PRIVATE)
					if not(carrierMetaList[unitID].usestockpile) then
						InsertUnitCmdDesc(unitID, 500, spawnCmd) --temporary
					end
				end
			end
		end
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if carrierMetaList[unitID] then
		carrierMetaList[unitID].subInitialSpawnData.teamID = newTeam
		for subUnitID,value in pairsNext, carrierMetaList[unitID].subUnitsList do
			spTransferUnit(subUnitID, newTeam, false)
		end
	end

end

function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	if carrierMetaList[unitID] then
		carrierMetaList[unitID].subInitialSpawnData.teamID = unitTeam
		for subUnitID,value in pairsNext, carrierMetaList[unitID].subUnitsList do
			spTransferUnit(subUnitID, unitTeam, false)
		end
	end
end


function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	local carrierUnitID = spGetUnitRulesParam(unitID, "carrier_host_unit_id")
	if carrierUnitID and carrierMetaList[carrierUnitID] then
		if carrierMetaList[carrierUnitID].subUnitsList[unitID] then
			local droneMetaData = carrierMetaList[carrierUnitID].subUnitsList[unitID]
			local bomberStage = droneMetaData.bomberStage
			local fighterStage = droneMetaData.fighterStage
			local droneType = droneMetaData.dronetype
			if droneType == "bomber" and (cmdID == CMD.MOVE or cmdID == CMD.ATTACK) and bomberStage > 0 then
				if droneMetaData.bomberStage == 1 then
				end
				if (not carrierMetaList[carrierUnitID].docking) and bomberStage >= 4 + carrierMetaList[carrierUnitID].dronebombingruns then
					bomberStage = 0
				elseif bomberStage < 3 then
					bomberStage = bomberStage + 1
				end
				droneMetaData.bomberStage = bomberStage
			elseif droneType == "fighter" and (cmdID == CMD.MOVE) and fighterStage > 0 then
				local rx = cos((fighterStage/4)*(-2)*PI)
				local rz = sin((fighterStage/4)*(-2)*PI)
				local carrierx,carriery, carrierz = Spring.GetUnitPosition(carrierUnitID)
				local idleRadius = 500
				spGiveOrderToUnit(unitID, CMD.MOVE, {carrierx + rx*idleRadius, carriery, carrierz + rz*idleRadius}, CMD.OPT_SHIFT)
				if fighterStage >= 4 then
					fighterStage = 0
				else
					fighterStage = fighterStage + 1
				end
				droneMetaData.fighterStage = fighterStage
			end
		end
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, proWeaponDefID)
	if proOwnerID then
	    local carrierUnitID = spGetUnitRulesParam(tonumber(proOwnerID), "carrier_host_unit_id")
	    if carrierUnitID and carrierMetaList[carrierUnitID] then
		    if carrierMetaList[carrierUnitID].subUnitsList[proOwnerID] then
				local droneMetaData = carrierMetaList[carrierUnitID].subUnitsList[proOwnerID]
				local bomberStage = droneMetaData.bomberStage
				local lastBombing = droneMetaData.lastBombing
			    if droneMetaData.dronetype == "bomber" and bomberStage > 0 then
				    local currentTime =  spGetGameSeconds()
				    if ((currentTime - lastBombing) >= 4) then
					    Spring.MoveCtrl.SetAirMoveTypeData(proOwnerID, "maxRudder", droneMetaData.originalmaxrudder)
					    bomberStage = bomberStage + 1
					    lastBombing = spGetGameSeconds()
				    end
					droneMetaData.bomberStage = bomberStage
					droneMetaData.lastBombing = lastBombing
			    end
		    end
		end
	end
end





function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD_CARRIER_SPAWN_ONOFF
	if carrierMetaList[unitID] then
		if not(carrierMetaList[unitID].usestockpile) then
			local cmdDescID = FindUnitCmdDesc(unitID, CMD_CARRIER_SPAWN_ONOFF)
			spawnCmd.params[1] = cmdParams[1]
			EditUnitCmdDesc(unitID, cmdDescID, spawnCmd)
			carrierMetaList[unitID].activeSpawning = cmdParams[1]
			spawnCmd.params[1] = 1
			return false
		end
	end
	return true
end


function RemoveDrone(carrierUnitID, unitID)
	
	if carrierMetaList[carrierUnitID].subUnitsList[unitID] then
		local droneMetaData = carrierMetaList[carrierUnitID].subUnitsList[unitID]
		local dronetypeIndex = droneMetaData.dronetypeIndex
		local dockingPieceIndex = droneMetaData.dockingPieceIndex
		if dronetypeIndex then
			if dockingPieceIndex then
				carrierMetaList[carrierUnitID].availableSections[dronetypeIndex].availablePieces[dockingPieceIndex].dockingPieceAvailable = true
			end
			carrierMetaList[carrierUnitID].subUnitCount[dronetypeIndex] = carrierMetaList[carrierUnitID].subUnitCount[dronetypeIndex] - 1
			if carrierMetaList[carrierUnitID].usestockpile and carrierMetaList[carrierUnitID].stockpilecount > 0 then
				local stockpile,_,stockpilepercentage = spGetUnitStockpile(carrierUnitID)
				if stockpile > 0 then
					stockpile = stockpile - 1
					spSetUnitStockpile(carrierUnitID, stockpile, stockpilepercentage)
					spGiveOrderToUnit(carrierUnitID, CMD.STOCKPILE, {}, 0)
				end
				carrierMetaList[carrierUnitID].stockpilecount = carrierMetaList[carrierUnitID].stockpilecount - 1
				
			end
		end
		if carrierMetaList[carrierUnitID] and carrierMetaList[carrierUnitID].subUnitsList and carrierMetaList[carrierUnitID].subUnitsList[unitID] then
			carrierMetaList[carrierUnitID].subUnitsList[unitID] = nil
			totalDroneCount = totalDroneCount - 1
		end
	end

end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	inUnitDestroyed = true
	local carrierUnitID = spGetUnitRulesParam(unitID, "carrier_host_unit_id")

	if carrierUnitID and carrierMetaList[carrierUnitID] then
		RemoveDrone(carrierUnitID, unitID)							
	end

	if droneMetaList[unitID] then
		droneMetaList[unitID] = nil
		totalDroneCount = totalDroneCount - 1
	end

	if carrierMetaList[unitID] then
		local evolvedCarrierID = spGetUnitRulesParam(unitID, "unit_evolved")

		if carrierMetaList[unitID].subUnitsList then
			for subUnitID,value in pairsNext, carrierMetaList[unitID].subUnitsList do
				if carrierMetaList[unitID].subUnitsList[subUnitID] then
					local standalone = false
					local wild = false
					if evolvedCarrierID then
						undockSequence(unitID, subUnitID)
						attachToNewCarrier(evolvedCarrierID, subUnitID)
					elseif carrierMetaList[unitID].carrierDeaththroe == "death" then
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
						local newCarrierCandidates = spGetUnitsInCylinder(ox, oz, carrierMetaList[unitID].controlRadius)
						for _, newCarrierCandidate in pairsNext, newCarrierCandidates do
							local existingCarrier = spGetUnitRulesParam(newCarrierCandidate, "carrier_host_unit_id")
							if not existingCarrier then
								if carrierMetaList[unitID].parasite == "ally" then
									if spGetUnitAllyTeam(newCarrierCandidate) then
										newCarrier = newCarrierCandidate
									end
								elseif carrierMetaList[unitID].parasite == "enemy" then
									if not spGetUnitAllyTeam(newCarrierCandidate) then
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
							docked = false, 
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
		end
		carrierMetaList[unitID] = nil
	end

	inUnitDestroyed = false
end


local function updateStandaloneDrones(frame)
	local resourceFrames = (frame - previousHealFrame) / 30
	for unitID, droneData in pairsNext, droneMetaList do
		if droneData.wild then
			-- move around unless in combat
			local cQueue = GetUnitCommands(unitID, -1)
			local engaged = false
			for j = 1, (cQueue and #cQueue or 0) do
				if cQueue[j].id == CMD.ATTACK then
					-- if currently fighting
					engaged = true
					break
				end
			end
			droneData.engaged = engaged
			if not engaged and ((DEFAULT_UPDATE_ORDER_FREQUENCY + droneData.lastOrderUpdate) < frame) then
				local idleRadius = droneData.idleRadius
				droneData.lastOrderUpdate = frame

				dronex, droney, dronez = spGetUnitPosition(unitID)
				if not dronez then	-- this can happen so make sure its dealt with
					gadget:UnitDestroyed(unitID)
				else
					rx, rz = randomPointInUnitCircle(5)
					spGiveOrderToUnit(unitID, CMD.MOVE, {dronex + rx*idleRadius, droney, dronez + rz*idleRadius}, 0)
				end
			end
		end

		if droneData.decayRate > 0 then
			local droneCurrentHealth, droneMaxHealth = spGetUnitHealth(unitID)
			healUnit(unitID, -droneData.decayRate, resourceFrames, droneCurrentHealth, droneMaxHealth)
		end
	end
end

local function updateCarrier(carrierID, carrierMetaData, frame)

	local carrierx, carriery, carrierz = spGetUnitPosition(carrierID)
	if not carrierx then
		if not inUnitDestroyed then
			gadget:UnitDestroyed(carrierID)
		end
		return
	end
	local cmdID, _, _, cmdParam_1, cmdParam_2, cmdParam_3 = spGetUnitCurrentCommand(carrierID)
	local droneSendDistance = nil
	local targetx, targety, targetz
	local target
	local idleTarget
	local recallDrones = carrierMetaData.activeRecall
	local attackOrder = false
	local fightOrder = false
	local setTargetOrder = false
	local agressiveDrones = false
	local carrierStates = spGetUnitStates(carrierID)

	local idleRadius = carrierMetaData.radius
	if carrierStates then
		if carrierStates.firestate == 0 then
			idleRadius = carrierMetaData.holdfireRadius
		elseif carrierStates.firestate == 2 then
			agressiveDrones = true
		end
		if carrierStates.movestate == 0 then
			idleRadius = 0
		elseif carrierStates.movestate == 1 and idleRadius > 0 then
			idleRadius = 200
		end
	end

	if carrierMetaData.docking then
	elseif idleRadius == 0 then
		idleRadius = carrierMetaData.droneminimumidleradius
	end

	

	local weapontargettype,_,weapontarget = Spring.GetUnitWeaponTarget(carrierID,carrierMetaData.weaponNr)

	--Handles an attack order given to the carrier.
	if not recallDrones and cmdID == CMD.ATTACK or weapontarget then
		if cmdID == CMD.ATTACK then
			if cmdParam_1 and not cmdParam_2 then
				target = cmdParam_1
				targetx, targety, targetz = spGetUnitPosition(cmdParam_1)
			else
				target = {cmdParam_1, cmdParam_2, cmdParam_3}
				targetx, targety, targetz = cmdParam_1, cmdParam_2, cmdParam_3
				fightOrder = true
			end
		elseif weapontargettype == 1 then
			target = weapontarget
			targetx, targety, targetz = spGetUnitPosition(weapontarget)
		end
		if targetx and carrierx then
			droneSendDistance = diag((carrierx-targetx), (carrierz-targetz))
		end
		attackOrder = true --attack order overrides set target
	end


	--Handles a fight order given to the carrier.
	if not recallDrones and cmdID == CMD.FIGHT then
		targetx, targety, targetz = cmdParam_1, cmdParam_2, cmdParam_3
		target = {cmdParam_1, cmdParam_2, cmdParam_3}
		if targetx and carrierx then
			droneSendDistance = diag((carrierx-targetx), (carrierz-targetz))
		end
		fightOrder = true
	end

	--Handles a setTarget order given to the carrier.
	if not recallDrones and not attackOrder then
		local targetType,_,setTarget = spGetUnitWeaponTarget(carrierID, 1)
		if targetType and targetType > 0 then
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
			if targetx and carrierx then
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
	if targetx and carrierx then
		magnitude = diag((carrierx-targetx), (carrierz-targetz))
		if magnitude == 0 then
			magnitude = 0.0001
		end
		targetvectorx, targetvectorz = targetx-carrierx, targetz-carrierz
		targetvectorx, targetvectorz = carrierMetaData.attackFormationOffset*targetvectorx/100, carrierMetaData.attackFormationOffset*targetvectorz/100
		perpendicularvectorx, perpendicularvectorz = -targetvectorz, targetvectorx
	end
	local orderUpdate = false
	for subUnitID,droneData in pairsNext, carrierMetaData.subUnitsList do
		local sx, sy, sz = spGetUnitPosition(subUnitID)
		if not sy then
			droneData = nil
		else
			local droneType = droneData.dronetype
			local droneDocked = droneData.docked
			local droneInFormation = droneData.inFormation
			local droneDistance = diag((carrierx-sx), (carrierz-sz))

			local droneCurrentHealth, droneMaxHealth = spGetUnitHealth(subUnitID)

			local droneAlive = true
			if droneCurrentHealth then
				if carrierMetaData.dockedHealRate > 0 and droneDocked then
					if droneCurrentHealth == droneMaxHealth then
						-- fully healed
						droneData.stayDocked = false
					else
						-- still needs healing
						droneData.stayDocked = true
						droneAlive = healUnit(subUnitID, carrierMetaData.dockedHealRate, resourceFrames, droneCurrentHealth, droneMaxHealth)
					end
				elseif droneData.activeDocking == false then
					droneAlive = healUnit(subUnitID, -carrierMetaData.decayRate, resourceFrames, droneCurrentHealth, droneMaxHealth)
				end
				if droneAlive and carrierMetaData.docking and 100*droneCurrentHealth/droneMaxHealth < carrierMetaData.dockToHealThreshold then
					dockUnitQueue(carrierID, subUnitID)
				end
			end
			if droneAlive and carrierMetaList[carrierID] then
				if droneType == "printer" or droneType == "passenger"  then
				elseif droneData and droneType == "turret" then
					spGiveOrderToUnit(subUnitID, CMD.FIRE_STATE, carrierStates.firestate, 0)
				elseif droneData and droneDistance then
					if (attackOrder or setTargetOrder or fightOrder) and not droneInFormation then
						-- drones fire at will if carrier has an attack/target order
						-- a drone bomber probably should not do this
						if droneType == "bomber" then
						else
							spGiveOrderToUnit(subUnitID, CMD.FIRE_STATE, 2, 0)
						end
					end
					if recallDrones or (droneDistance > carrierMetaData.controlRadius) and not (droneType == "bomber") then
						-- move drones to carrier when out of range
						carrierx, carriery, carrierz = spGetUnitPosition(carrierID)
						rx, rz = randomPointInUnitCircle(5)
						if carrierMetaData.docking and idleRadius == 0 then
							dockUnitQueue(carrierID, subUnitID)
						else
							spGiveOrderToUnit(subUnitID, CMD.MOVE, {carrierx + rx*idleRadius, carriery, carrierz + rz*idleRadius}, 0)
							spGiveOrderToUnit(subUnitID, CMD.GUARD, carrierID, CMD.OPT_SHIFT)
						end
					elseif carrierMetaData.manualDrones then
						return
					elseif droneSendDistance and droneSendDistance < carrierMetaData.radius or droneType == "bomber" then
						-- attacking
						if target and not (droneType == "nano") then
						    
							if droneType == "bomber" then
								local currenttime = spGetGameSeconds()
								local bomberStage = droneData.bomberStage
								if bomberStage == 0 and (currenttime - carrierMetaData.dronebombertimer) > carrierMetaData.dronebomberinterval and droneSendDistance > carrierMetaData.dronebomberminengagementrange then
									undockSequence(carrierID, subUnitID)

									local p2tvx, p2tvz = carrierMetaData.dronebombingside*carrierMetaData.dronebombingoffset*droneSendDistance*carrierMetaData.attackFormationSpread*perpendicularvectorx/magnitude, carrierMetaData.dronebombingside*carrierMetaData.dronebombingoffset*droneSendDistance*carrierMetaData.attackFormationSpread*perpendicularvectorz/magnitude

									local formationx, formationz = carrierx+targetvectorx+p2tvx, carrierz+targetvectorz+p2tvz

									spGiveOrderToUnit(subUnitID, CMD.MOVE, {formationx, targety, formationz}, 0)
									if not droneDocked then
										if carrierMetaData.dronebombingside == -1 then
											carrierMetaData.dronebombingside = 1
										elseif carrierMetaData.dronebombingside == 1 then
											carrierMetaData.dronebombingside = -1
										end
										Spring.MoveCtrl.SetAirMoveTypeData(subUnitID, "maxRudder", 0.05)
										carrierMetaData.dronebombertimer = spGetGameSeconds()
										bomberStage = 1
									end
								elseif bomberStage == 2 then
									spGiveOrderToUnit(subUnitID, CMD.ATTACK, target, 0)
									bomberStage = 3
								elseif bomberStage == 3 + carrierMetaData.dronebombingruns then
									spGiveOrderToUnit(subUnitID, CMD.MOVE, {carrierx, carriery, carrierz}, 0)
									if carrierMetaData.docking then
										dockUnitQueue(carrierID, subUnitID)
									end
								elseif bomberStage == 4 + carrierMetaData.dronebombingruns then
										rx, rz = randomPointInUnitCircle(5)
										spGiveOrderToUnit(subUnitID, CMD.MOVE, {carrierx + rx*idleRadius*0.2, carriery, carrierz + rz*idleRadius*0.2}, 0)
								end
								droneData.bomberStage = bomberStage
							else
								if droneDocked and magnitude then

									undockSequence(carrierID, subUnitID)
									droneInFormation = true

									local p2tvx, p2tvz = attackFormationPosition*attackFormationSide*perpendicularvectorx/magnitude, attackFormationPosition*attackFormationSide*perpendicularvectorz/magnitude

									local formationx, formationz = carrierx+targetvectorx+p2tvx, carrierz+targetvectorz+p2tvz

									spGiveOrderToUnit(subUnitID, CMD.MOVE, {formationx, targety, formationz}, 0)

									if fightOrder then
										local figthRadius = carrierMetaData.radius*0.2
										rx, rz = randomPointInUnitCircle(5)
										spGiveOrderToUnit(subUnitID, CMD.FIGHT, {targetx+rx*figthRadius, targety, targetz+rz*figthRadius}, CMD.OPT_SHIFT)
									else
										if droneType == "abductor" then
											spGiveOrderToUnit(subUnitID, CMD.LOAD_UNITS, target, CMD.OPT_SHIFT)
										else
											spGiveOrderToUnit(subUnitID, CMD.ATTACK, target, CMD.OPT_SHIFT)
										end
									end

									if attackFormationSide == -1 then
										attackFormationSide = 1
										attackFormationPosition = attackFormationPosition + carrierMetaData.attackFormationSpread
									elseif attackFormationSide == 1 then
										attackFormationSide = -1
									else
										attackFormationSide = 1
									end
								end

								if droneInFormation then
									if droneDistance > (magnitude*carrierMetaData.attackFormationOffset/100) then
										droneInFormation = false

									end
								else
									if fightOrder then
										local cQueue = GetUnitCommands(subUnitID, -1)
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
											rx, rz = randomPointInUnitCircle(5)
											spGiveOrderToUnit(subUnitID, CMD.FIGHT, {targetx+rx*figthRadius, targety, targetz+rz*figthRadius}, 0)
										end
									else
										if droneType == "abductor" then
											local transportedUnit = Spring.GetUnitIsTransporting(subUnitID)
											if transportedUnit[1] then
												dockUnitQueue(carrierID, subUnitID)
											else
												local targetMoveTypeData = Spring.GetUnitMoveTypeData(target)
												if targetMoveTypeData and targetMoveTypeData.maxSpeed and targetMoveTypeData.maxSpeed > 0 then
													spGiveOrderToUnit(subUnitID, CMD.LOAD_UNITS, target)
												end
											end
										else
											spGiveOrderToUnit(subUnitID, CMD.ATTACK, target, 0)
										end	
									end
								end
								droneData.inFormation = droneInFormation
							end
						elseif ((DEFAULT_UPDATE_ORDER_FREQUENCY + carrierMetaData.lastOrderUpdate) < frame) then
							orderUpdate = true
							if carrierMetaData.docking and (idleRadius == 0 or droneType == "bomber") then
								dockUnitQueue(carrierID, subUnitID)
							else
								undockSequence(carrierID, subUnitID)
								rx, rz = randomPointInUnitCircle(5)
								if droneType == "bomber" then
									spGiveOrderToUnit(subUnitID, CMD.MOVE, {carrierx + rx*idleRadius*0.2, carriery, carrierz + rz*idleRadius*0.2}, 0)
								elseif droneType == "nano" then
									spGiveOrderToUnit(subUnitID, CMD.REPAIR, {carrierx, carriery, carrierz, carrierMetaData.radius}, 0)
								elseif droneType == "fighter" then
									if droneData.fighterStage == 0 then
										spGiveOrderToUnit(subUnitID, CMD.FIGHT, {carrierx + rx*idleRadius, carriery, carrierz + rz*idleRadius}, 0)
									end
								else
									spGiveOrderToUnit(subUnitID, CMD.MOVE, {carrierx + rx*idleRadius, carriery, carrierz + rz*idleRadius}, 0)
								end
							end
						end
					elseif not droneData.stayDocked and not (droneType == "bomber") and not (droneType == "abductor") then
						-- return to carrier unless in combat
						local cQueue = GetUnitCommands(subUnitID, -1)
						local engaged = false
						for j = 1, (cQueue and #cQueue or 0) do
							if cQueue[j].id == CMD.ATTACK and carrierStates.firestate > 0 then
								-- if currently fighting AND not on hold fire
								engaged = true
								if agressiveDrones then
									idleTarget = cQueue[j].params
								end
								break
							elseif cQueue[j].id == CMD.REPAIR then
								engaged = true
								break
							end
						end
						droneData.engaged = engaged
						-- if not engaged and ((frame % DEFAULT_UPDATE_ORDER_FREQUENCY) == 0) then
						if not engaged and ((DEFAULT_UPDATE_ORDER_FREQUENCY + carrierMetaData.lastOrderUpdate) < frame) then
							orderUpdate = true
							if carrierMetaData.docking and idleRadius == 0 then
								dockUnitQueue(carrierID, subUnitID)
							else
								carrierx, carriery, carrierz = spGetUnitPosition(carrierID)
								rx, rz = randomPointInUnitCircle(5)
								undockSequence(carrierID, subUnitID)
								if droneType == "nano" then
									spGiveOrderToUnit(subUnitID, CMD.REPAIR, {carrierx, carriery, carrierz, carrierMetaData.radius}, 0)
									local cQueue = GetUnitCommands(subUnitID, -1)
									local engaged = false
									for j = 1, (cQueue and #cQueue or 0) do
										if cQueue[j].id == CMD.REPAIR then
											engaged = true
											break
										end
									end
									if not engaged then
										spGiveOrderToUnit(subUnitID, CMD.MOVE, {carrierx + rx*idleRadius, carriery, carrierz + rz*idleRadius}, 0)
									end
								else
									if idleTarget then
										spGiveOrderToUnit(subUnitID, CMD.ATTACK, idleTarget, 0)
									else
										if droneType == "fighter" then
											spGiveOrderToUnit(subUnitID, CMD.FIGHT, {carrierx + rx*idleRadius, carriery, carrierz + rz*idleRadius}, 0)
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
		end
	end
	if orderUpdate then
		carrierMetaData.lastOrderUpdate = frame
	end
end


local inUnitCommand = false

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if inUnitCommand then
		return
	end
	inUnitCommand = true
	if carrierMetaList[unitID] and cmdID == CMD.STOP then
		for subUnitID,value in pairsNext, carrierMetaList[unitID].subUnitsList do
			if unitID == spGetUnitRulesParam(subUnitID, "carrier_host_unit_id") then
				spGiveOrderToUnit(subUnitID, cmdID, cmdParams, cmdOptions)
				local px, py, pz = spGetUnitPosition(unitID)
				spGiveOrderToUnit(subUnitID, CMD.MOVE, {px, py, pz}, 0)
			end
		end
	elseif carrierMetaList[unitID] and (cmdID ~= CMD.MOVE and cmdID ~= CMD.FIRE_STATE and cmdID ~= CMD.STOCKPILE) then
		carrierMetaList[unitID].activeRecall = false
		local f = Spring.GetGameFrame()
		updateCarrier(unitID, carrierMetaList[unitID], f)
	end
	inUnitCommand = false
end

local function dockUnits(dockingqueue, queuestart, queueend)
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
				local droneMetaData = carrierMetaList[unitID].subUnitsList[subUnitID]
				if droneMetaData.dockingPiece then
					local pieceNumber = droneMetaData.dockingPiece
					local dronetype = droneMetaData.dronetype
					local droneDocked = droneMetaData.docked
					local function landLoop()
						if not carrierMetaList[unitID] then
							return
						elseif not droneMetaData then
							return
						end
						while not droneDocked do
							local px, py, pz = spGetUnitPiecePosDir(unitID, pieceNumber)
							subx, suby, subz = spGetUnitPosition(subUnitID)
							local distance = diag((px-subx), (pz-subz))
							local heightDifference = diag(py-suby)

							if not distance then
								return
							end
							if distance < 25 and subunitDef.isAirUnit then
								local landingspeed = carrierMetaList[unitID].dockHelperSpeed
								if 0.2*heightDifference > landingspeed then
									landingspeed = 0.2*heightDifference
								end
								local magnitude = diag((subx-px), (suby-py), (subz-pz))
								if magnitude == 0 then
									magnitude = 0.0001
								end
								local vx, vy, vz = px-subx, py-suby, pz-subz
								vx, vy, vz = landingspeed*vx/magnitude, landingspeed*vy/magnitude, landingspeed*vz/magnitude
								spSetUnitVelocity(subUnitID, vx, vy, vz)
							elseif distance < carrierMetaList[unitID].dockRadius then
								local landingspeed = carrierMetaList[unitID].dockHelperSpeed
								local magnitude = diag((subx-px), (suby-py), (subz-pz))
								if magnitude == 0 then
									magnitude = 0.0001
								end
								local vx, vy, vz = px-subx, py-suby, pz-subz
								vx, vy, vz = landingspeed*vx/magnitude, landingspeed*vy/magnitude, landingspeed*vz/magnitude
								Spring.MoveCtrl.Enable(subUnitID)
								mcSetPosition(subUnitID, subx+vx, suby, subz+vz)
								Spring.MoveCtrl.Disable(subUnitID)
								spSetUnitVelocity(subUnitID, vx, 0, vz)
								heightDifference = 0

							else
								if dronetype == "bomber" then
									spGiveOrderToUnit(subUnitID, CMD.MOVE, {px, py, pz}, 0)
								else
									spGiveOrderToUnit(subUnitID, CMD.STOP, {}, 0)
									spGiveOrderToUnit(subUnitID, CMD.MOVE, {px, py, pz}, 0)
								end
							end

							carrierMetaList[unitID].activeDocking = true
							if carrierMetaList[unitID].dockHelperSpeed == 0 then
								dockingSnapRange = carrierMetaList[unitID].dockRadius
							else
								dockingSnapRange = carrierMetaList[unitID].dockHelperSpeed
							end

							if distance < dockingSnapRange and heightDifference < dockingSnapRange and droneDocked ~= true then
								spUnitAttach(unitID, subUnitID, pieceNumber)
								spGiveOrderToUnit(subUnitID, CMD.STOP, {}, 0)
								spGiveOrderToUnit(subUnitID, CMD.FIRE_STATE, 0, 0)
								Spring.MoveCtrl.Disable(subUnitID)
								spSetUnitVelocity(subUnitID, 0, 0, 0)
								if not carrierMetaList[unitID].manualDrones then
									SetUnitNoSelect(subUnitID, true)
								end
								droneDocked = true
								droneMetaData.docked = true
								droneMetaData.activeDocking = false
								droneMetaData.bomberStage = 0
								if carrierMetaList[unitID].dockArmor then
									spSetUnitArmored(subUnitID, true, carrierMetaList[unitID].dockArmor)
								end
								local _, pieceAngle  = spCallCOBScript(unitID, "DroneDocked", 5, pieceAngle, pieceNumber)
								spCallCOBScript(subUnitID, "Docked", 0, carrierMetaList[unitID].cobdockparam, pieceNumber, pieceAngle)

								if dronetype == "abductor" then
									local transportedUnit = Spring.GetUnitIsTransporting(subUnitID)
									if transportedUnit[1] then
										local transportedUnitDefID = Spring.GetUnitDefID(transportedUnit[1])
										if transportedUnitDefID then
											for dronetypeIndex, dronename in pairs(carrierMetaList[unitID].dronenames) do
												if carrierMetaList[unitID].dronetypes[dronetypeIndex] == "printer" then
													carrierMetaList[unitID].printerUnitDefID = transportedUnitDefID
													spDestroyUnit(transportedUnit[1])
												end
											end
										end
									end
								end
								if dronetype == "turret" then
								else
									Spring.SetUnitCOBValue(subUnitID, COB.ACTIVATION, 0)
								end
							end

							Sleep()

							if not carrierMetaList[unitID] then
								return
							elseif not droneMetaData then
								return
							else
								local droneCurrentHealth = spGetUnitHealth(subUnitID)
								if not droneCurrentHealth then
									return
								elseif droneCurrentHealth <= 0 then
									return
								end
							end

						end
					end

					startScript(landLoop)
				end
			end
		end
	end
end

function gadget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	if carrierMetaList[unitID] then
		if carrierMetaList[unitID].usestockpile and newCount > oldCount then
			local spawnData = carrierMetaList[unitID].subInitialSpawnData
				local x, y, z = spGetUnitPosition(unitID)
				spawnData.x = x
				spawnData.y = y
				spawnData.z = z
				if x then
					spawnUnit(spawnData)
				end
		end
	end
end

function gadget:GameFrame(f)
	updateCoroutines()
	if f % GAME_SPEED ~= 0 then
		return
	end
	if ((DEFAULT_SPAWN_CHECK_FREQUENCY + lastSpawnCheck) < f) then
		lastSpawnCheck = f
		for unitID, _ in pairs(carrierMetaList) do
			local isDoneBuilding = not spGetUnitIsBeingBuilt(unitID)
			if carrierMetaList[unitID].spawnRateFrames == 0 then
			elseif ((carrierMetaList[unitID].spawnRateFrames + carrierMetaList[unitID].lastSpawn) < f and carrierMetaList[unitID].activeSpawning == 1 and isDoneBuilding) and not(carrierMetaList[unitID].usestockpile) then
				local spawnData = carrierMetaList[unitID].subInitialSpawnData
				local x, y, z = spGetUnitPosition(unitID)
				spawnData.x = x
				spawnData.y = y
				spawnData.z = z
				if x then
					spawnUnit(spawnData)
					carrierMetaList[unitID].lastSpawn = f
				end
			end
		end
	end

	if ((CARRIER_UPDATE_FREQUENCY + lastCarrierUpdate) < f) then
		lastCarrierUpdate = f
		for unitID, _ in pairsNext, carrierMetaList do
			updateCarrier(unitID, carrierMetaList[unitID], f)
		end
		updateStandaloneDrones(f)
		previousHealFrame = f
	end


	if ((DEFAULT_DOCK_CHECK_FREQUENCY + lastDockCheck) < f) then
		lastDockCheck = f
		if carrierQueuedDockingCount > 0 then -- Initiate docking for units in the docking queue and reset the queue.
			local availableDockingCount = (carrierAvailableDockingCount-#coroutines)
			local carrierActiveDockingList = {}
			local carrierDockingCount = 0
			if (carrierQueuedDockingCount - dockingQueueOffset) > availableDockingCount then
				carrierActiveDockingList = carrierDockingList
				dockUnits(carrierActiveDockingList, (dockingQueueOffset+1), (dockingQueueOffset+availableDockingCount))
				dockingQueueOffset = dockingQueueOffset+availableDockingCount
			else
				carrierActiveDockingList = carrierDockingList
				carrierDockingCount = carrierQueuedDockingCount
				carrierQueuedDockingCount = 0
				dockUnits(carrierActiveDockingList, (dockingQueueOffset+1), carrierDockingCount)
				dockingQueueOffset = 0
			end
		end
	end

end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_CARRIER_SPAWN_ONOFF)
	local allUnits = Spring.GetAllUnits()
	local unitCount = #allUnits
	for i = 1, unitCount do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
	end
	gadgetHandler:RegisterGlobal("CobUndockSequenceFinished", CobUndockSequenceFinished)
	gadgetHandler:RegisterGlobal("CobDroneSpawnSequenceFinished", CobDroneSpawnSequenceFinished)
	
end

function gadget:Shutdown()
	for unitID, _ in pairsNext, carrierMetaList do
		for subUnitID,value in pairsNext, carrierMetaList[unitID].subUnitsList do
			spDestroyUnit(subUnitID, true, true)
		end
	end
end
