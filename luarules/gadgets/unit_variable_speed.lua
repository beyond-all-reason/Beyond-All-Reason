local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Changing Amphibious Unit Movement Characteristics ", --TODO:Change
		desc = "Allows amphibious units to alter their maximum speed or turnRate between land and water.",
		author = "Tuerk",
		date = "2025.4.06",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

--if gadgetHandler:IsSyncedCode() then return end
if not gadgetHandler:IsSyncedCode() then return end

-- Set these in customParams to customize, otherwise will grab the standard value
local waterSpeed
local waterturnRate
local waterwatermaxacc
local waterwatermaxdec

--statics

--functions
local spGetUnitIsDead = Spring.GetUnitIsDead
local spValidUnitID = Spring.ValidUnitID
local spAddUnitDamage = Spring.AddUnitDamage
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetUnitPosition = Spring.GetUnitPosition
local spSpawnCEG = Spring.SpawnCEG
local spPlaySoundFile = Spring.PlaySoundFile
local spTestMoveOrder = Spring.TestMoveOrder
local spDestroyUnit = Spring.DestroyUnit

local spEcho = Spring.Echo
local spGetUnitCommands = Spring.GetUnitCommands
local spGiveOrderToUnit = Spring.GiveOrderToUnit
--FIXME: What is UpdateWantedMaxSpeed used for??
--local spUpdateWantedMaxSpeed = GG.ForceUpdateWantedMaxSpeed

local spSetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData

--tables
local Units = {}
local unitWaterDefs = {}

-- TODO: Uhh,need to save a table of all the cool unit's land statistics for hopefully easier restoration. No clue actually how the SetGroundMoveTypeData function works.
for unitDefID, unitDef in ipairs(UnitDefs) do
	--spEcho(unitDef.name,unitDef.maxAcc)
	--Remember to only look for *lowercase* params!
		if unitDef.customParams.iswatervariable then
			Units[unitDefID] = true
			--spEcho("Returning customParam waterspeed: ".. unitDef.customParams.waterspeed)
			waterSpeed = unitDef.customParams.waterspeed or unitDef.speed
			waterturnRate = unitDef.customParams.waterturnrate or unitDef.turnRate
			waterwatermaxacc = unitDef.customParams.waterwatermaxacc or unitDef.maxAcc
			waterwatermaxdec = unitDef.customParams.waterwatermaxdec or unitDef.maxDec
			unitWaterDefs[unitDefID] = {
				speed = waterSpeed,
				turnRate = waterturnRate,
				maxAcc = waterwatermaxacc,
				maxDec = waterwatermaxdec,
			}
		end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if Units[unitDefID] then
		--TODO: Spawning the unit underwater automatically triggers the call-in, but animations become really slow until the unit has a chace to CmdDone on land once. 
	end
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if Units[unitDefID] then
		spSetGroundMoveTypeData(unitID, "maxSpeed",unitWaterDefs[unitDefID].speed)
		spSetGroundMoveTypeData(unitID, "maxWantedSpeed" , unitWaterDefs[unitDefID].speed)
		spSetGroundMoveTypeData(unitID,"turnRate",unitWaterDefs[unitDefID].turnRate)
		spSetGroundMoveTypeData(unitID,"accRate",unitWaterDefs[unitDefID].maxAcc)
		spSetGroundMoveTypeData(unitID,"decRate",unitWaterDefs[unitDefID].maxDec)
		spEcho("Entering Water, returning customParam waterspeed: ".. unitWaterDefs[unitDefID].speed)
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if Units[unitDefID] then
		spSetGroundMoveTypeData(unitID,"maxSpeed",UnitDefs[unitDefID].speed)
		spSetGroundMoveTypeData(unitID,"maxWantedSpeed",UnitDefs[unitDefID].speed)
		spSetGroundMoveTypeData(unitID,"turnRate",UnitDefs[unitDefID].turnRate)
		spSetGroundMoveTypeData(unitID,"accRate",UnitDefs[unitDefID].maxAcc)
		spSetGroundMoveTypeData(unitID,"decRate",UnitDefs[unitDefID].maxDec)
		spEcho("Unit ".. UnitDefs[unitDefID].name .. ", leaving the sea. Returning customParam waterspeed: ".. unitWaterDefs[unitDefID].speed)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	Units[unitID] = nil
end