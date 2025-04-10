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
local waterWantedSpeed
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

local spSetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData

--tables
local veryCoolUnits = {}
local veryCoolUnitWatcher = {}
local unitWaterMovementDefs = {}

-- TODO: Uhh,need to save a table of all the cool unit's land statistics for hopefully easier restoration. No clue actually how the SetGroundMoveTypeData function works.
for unitDefID, unitDef in ipairs(UnitDefs) do
	--spEcho(unitDef.name,unitDef.maxAcc)
		if unitDef.customParams.iswatervariable then
			veryCoolUnits[unitDefID] = true
			waterSpeed = unitDef.customParams.waterSpeed or unitDef.speed
			waterWantedSpeed = unitDef.customParams.waterWantedSpeed or unitDef.maxWantedSpeed
			waterturnRate = unitDef.customParams.waterturnRate or unitDef.turnRate
			waterwatermaxacc = unitDef.customParams.waterwatermaxacc or unitDef.maxAcc
			waterwatermaxdec = unitDef.customParams.waterwatermaxdec or unitDef.maxDec
			unitWaterMovementDefs[unitDefID] = {
				speed = waterSpeed,
				maxWantedSpeed = waterWantedSpeed,
				turnRate = waterturnRate,
				maxAcc = waterwatermaxacc,
				maxDec = waterwatermaxdec,
			}
		end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if veryCoolUnits[unitDefID] then
		--TODO: Add a check for if the amphib unit was built underwater.
	end
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if veryCoolUnits[unitDefID] then
		spSetGroundMoveTypeData(unitID, "maxSpeed" , 200)
		spSetGroundMoveTypeData(unitID, "maxWantedSpeed" , 200)
		spSetGroundMoveTypeData(unitID,"turnRate",unitWaterMovementDefs[unitDefID].turnRate)
		spSetGroundMoveTypeData(unitID,"accRate",unitWaterMovementDefs[unitDefID].maxAcc)
		spSetGroundMoveTypeData(unitID,"decRate",unitWaterMovementDefs[unitDefID].maxDec)
		spEcho("Unit ".. unitID .. ", going dark.")
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if veryCoolUnits[unitDefID] then
		spSetGroundMoveTypeData(unitID,"maxSpeed",UnitDefs[unitDefID].speed)
		spSetGroundMoveTypeData(unitID,"maxWantedSpeed",UnitDefs[unitDefID].maxWantedSpeed)
		spSetGroundMoveTypeData(unitID,"turnRate",UnitDefs[unitDefID].turnRate)
		spSetGroundMoveTypeData(unitID,"accRate",UnitDefs[unitDefID].maxAcc)
		spSetGroundMoveTypeData(unitID,"decRate",UnitDefs[unitDefID].maxDec)
		spEcho("Unit ".. unitID .. ", leaving the sea.")
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	veryCoolUnits[unitID] = nil
end