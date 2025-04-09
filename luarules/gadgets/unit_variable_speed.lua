local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit movement characteristics ", --TODO:Change
		desc = "",
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
local waterturnrate
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

local spSetGroundMoveTypeData = Spring.MoveCtrl.SetGroundMoveTypeData

--tables
local veryCoolUnits = {}
local veryCoolUnitWatcher = {}
local unitWaterMovementDefs = {}

spEcho("Hello World")
-- TODO: Uhh,need to save a table of all the cool unit's land statistics for hopefully easier restoration. No clue actually how the SetGroundMoveTypeData function works.
for unitDefID, unitDef in ipairs(UnitDefs) do
	spEcho(unitDef.name,unitDef.maxAcc)
		if unitDef.customParams.iswatervariable then
			veryCoolUnits[unitDefID] = true
			spEcho(unitDef.name.. " is very cool indeed!")
			spEcho("Unit Statcheck ".. unitDef.speed .. " " .. unitDef.turnRate.. " ".. unitDef.maxAcc .. " " ..unitDef.maxDec)
			waterSpeed = unitDef.customParams.waterSpeed or unitDef.speed
			waterturnrate = unitDef.customParams.waterturnrate or unitDef.turnRate
			waterwatermaxacc = unitDef.customParams.waterwatermaxacc or unitDef.maxAcc
			waterwatermaxdec = unitDef.customParams.waterwatermaxdec or unitDef.maxDec
			spEcho(waterSpeed,waterturnrate,waterwatermaxacc,waterwatermaxdec)
			unitWaterMovementDefs[unitDefID] = {
				speed = waterSpeed,
				turnrate = waterturnrate,
				maxAcc = waterwatermaxacc,
				maxDec = waterwatermaxdec,
			}
		end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	spEcho("Checking Unit ".. unitID)
	if veryCoolUnits[unitDefID] then
		spEcho("Unit ".. unitID .. " is fucking ballin.")
		veryCoolUnitWatcher[unitID] = true
	end
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if veryCoolUnits[unitDefID] then
		spEcho("Something cool is in the water")
		spEcho(unitWaterMovementDefs[unitDefID].speed, unitWaterMovementDefs[unitDefID].turnrate,unitWaterMovementDefs[unitDefID].maxAcc,unitWaterMovementDefs[unitDefID].maxDec)
		spSetGroundMoveTypeData(unitID, "maxSpeed" , 200)
		spSetGroundMoveTypeData(unitID,"turnRate",unitWaterMovementDefs[unitDefID].turnrate)
		spSetGroundMoveTypeData(unitID,"accRate",unitWaterMovementDefs[unitDefID].maxAcc)
		spSetGroundMoveTypeData(unitID,"decRate",unitWaterMovementDefs[unitDefID].maxDec)
		spEcho("Unit ".. unitID .. ", going dark.")
	end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if veryCoolUnits[unitDefID] then
		spEcho("Something cool left the water")
		spEcho("Setting maxSpeed")
		spSetGroundMoveTypeData(unitID,"maxSpeed",UnitDefs[unitDefID].speed)
		spEcho("Setting turnRate")
		spEcho(UnitDefs[unitDefID].turnRate)
		spEcho(type(UnitDefs[unitDefID].turnRate))
		spSetGroundMoveTypeData(unitID,"turnRate",UnitDefs[unitDefID].turnrate)
		spEcho("Setting accRate")
		spSetGroundMoveTypeData(unitID,"accRate",UnitDefs[unitDefID].maxAcc)
		spEcho("Setting decRate")
		spSetGroundMoveTypeData(unitID,"decRate",UnitDefs[unitDefID].maxDec)
		spEcho("Unit ".. unitID .. ", leaving the sea.")
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	veryCoolUnits[unitID] = nil
	veryCoolUnitWatcher[unitID] = nil
end